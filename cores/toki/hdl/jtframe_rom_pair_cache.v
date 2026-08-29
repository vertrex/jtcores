// FPGA bridge for a packed pair of byte-wide asynchronous ROMs backed by one
// atomically acknowledged JTFrame SDRAM slot.
//
// This Toki-local copy is intentionally not part of JTFrame. The
// schematic-facing consumer presents one shared address. This bridge holds
// the external address until its acknowledgement and inserts a clock with CS
// low so JTFrame's latched OK cannot be reused by the next request. A tagged
// direct-mapped cache gives repeated accesses deterministic latency; a late
// miss deliberately leaves q unchanged, matching an asynchronous ROM whose
// new value did not arrive before the consumer's load edge.
//
// For Toki, DATA_W=16 and q[7:0]/q[15:8] are the U92/U93 byte lanes.
// ADDR_W must be greater than INDEX_W.
module jtframe_rom_pair_cache #(
    parameter ADDR_W  = 16,
    parameter DATA_W  = 16,
    parameter INDEX_W = 12
)(
    input                      clk,
    input                      rst,
    input                      cen,
    input      [ADDR_W-1:0]    addr,
    output reg [DATA_W-1:0]    q,

    input      [DATA_W-1:0]    rom_data,
    input                      rom_ok,
    output     [ADDR_W-1:0]    rom_addr,
    output                     rom_cs
);

localparam TAG_W     = ADDR_W - INDEX_W;
localparam CACHE_W   = 1 + TAG_W + DATA_W;
localparam CACHE_LEN = 1 << INDEX_W;

reg [ADDR_W-1:0] held_addr;
reg              req_active;
reg              req_gap;
reg              lookup_pending;

assign rom_addr = held_addr;
assign rom_cs   = req_active;

// Keep this array in a dedicated synchronous RAM process. Combining its
// accesses with the requester state machine makes Quartus 17 flatten a large
// cache into logic instead of inferring block RAM.
(* ramstyle = "M10K, no_rw_check" *)
reg [CACHE_W-1:0] pair_cache [0:CACHE_LEN-1];
reg [CACHE_W-1:0] cache_q;
reg [INDEX_W-1:0] cache_clear_addr;
reg               cache_init;

wire request_done = req_active && rom_ok;

// Clear one entry per clock. Resetting the complete array in one cycle would
// prevent block-RAM inference. With the default 4096 entries this takes about
// 85 us at 48 MHz, while the rest of the core is still starting.
always @(posedge clk) begin
    cache_q <= pair_cache[addr[INDEX_W-1:0]];

    if (rst) begin
        cache_clear_addr <= {INDEX_W{1'b0}};
        cache_init <= 1'b1;
    end else if (cache_init) begin
        pair_cache[cache_clear_addr] <= {CACHE_W{1'b0}};
        if (cache_clear_addr == {INDEX_W{1'b1}}) begin
            cache_clear_addr <= {INDEX_W{1'b0}};
            cache_init <= 1'b0;
        end else begin
            cache_clear_addr <= cache_clear_addr + {{(INDEX_W-1){1'b0}},1'b1};
        end
    end else if (request_done) begin
        pair_cache[held_addr[INDEX_W-1:0]] <= {
            1'b1, held_addr[ADDR_W-1:INDEX_W], rom_data
        };
    end
end

always @(posedge clk) begin
    if (rst) begin
        held_addr <= {ADDR_W{1'b1}};
        q <= {DATA_W{1'b1}};
        req_active <= 1'b0;
        req_gap <= 1'b0;
        lookup_pending <= 1'b0;
    end else if (cache_init) begin
        req_active <= 1'b0;
        req_gap <= 1'b0;
        lookup_pending <= 1'b0;
    end else if (req_active) begin
        if (rom_ok) begin
            q <= rom_data;
            req_active <= 1'b0;
            req_gap <= 1'b1;
        end
    end else if (req_gap) begin
        req_gap <= 1'b0;
    end else if (lookup_pending) begin
        lookup_pending <= 1'b0;
        if (cache_q[CACHE_W-1] &&
            (cache_q[CACHE_W-2:DATA_W] ==
             held_addr[ADDR_W-1:INDEX_W])) begin
            q <= cache_q[DATA_W-1:0];
        end else begin
            req_active <= 1'b1;
        end
    end else if (cen && (addr != held_addr)) begin
        held_addr <= addr;
        lookup_pending <= 1'b1;
    end
end

endmodule
