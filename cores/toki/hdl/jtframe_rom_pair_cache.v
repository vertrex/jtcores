// FPGA bridge for a pair of byte-wide asynchronous ROMs backed by two
// independently acknowledged JTFrame SDRAM slots.
//
// The schematic-facing consumer presents one shared address.  This bridge
// holds both external addresses until their individual acknowledgements,
// publishes only a complete atomic pair, and inserts a clock with both CS
// outputs low so JTFrame's latched OK cannot be reused by the next request.
// A tagged direct-mapped cache gives repeated accesses deterministic latency;
// a late miss deliberately leaves q unchanged, matching an asynchronous ROM
// whose new value did not arrive before the consumer's load edge.
//
// Lane 0 becomes q[DATA_W-1:0] and lane 1 becomes q[2*DATA_W-1:DATA_W].
// ADDR_W must be greater than INDEX_W.
module jtframe_rom_pair_cache #(
    parameter ADDR_W  = 16,
    parameter DATA_W  = 8,
    parameter INDEX_W = 12
)(
    input                       clk,
    input                       rst,
    input                       cen,
    input      [ADDR_W-1:0]     addr,
    output reg [2*DATA_W-1:0]   q,

    input      [DATA_W-1:0]     rom_0_data,
    input                       rom_0_ok,
    output reg [ADDR_W-1:0]     rom_0_addr,
    output reg                  rom_0_cs,

    input      [DATA_W-1:0]     rom_1_data,
    input                       rom_1_ok,
    output reg [ADDR_W-1:0]     rom_1_addr,
    output reg                  rom_1_cs
);

localparam TAG_W    = ADDR_W - INDEX_W;
localparam PAIR_W   = 2 * DATA_W;
localparam CACHE_W  = 1 + TAG_W + PAIR_W;
localparam CACHE_LEN = 1 << INDEX_W;

reg [DATA_W-1:0] byte_0;
reg [DATA_W-1:0] byte_1;
reg              got_0;
reg              got_1;
reg              req_active;
reg              req_gap;
reg              lookup_pending;
reg [TAG_W-1:0]  lookup_tag;

// Keep this array in a dedicated synchronous RAM process.  Combining its
// accesses with the requester state machine makes Quartus 17 flatten a large
// cache into logic instead of inferring block RAM.
(* ramstyle = "M10K, no_rw_check" *)
reg [CACHE_W-1:0] pair_cache [0:CACHE_LEN-1];
reg [CACHE_W-1:0] cache_q;
reg [INDEX_W-1:0] cache_clear_addr;
reg               cache_init;

wire [PAIR_W-1:0] pair_complete = {
    rom_1_ok ? rom_1_data : byte_1,
    rom_0_ok ? rom_0_data : byte_0
};
wire pair_done = req_active &&
                 (got_0 || rom_0_ok) &&
                 (got_1 || rom_1_ok);

// Clear one entry per clock.  Resetting the complete array in one cycle would
// prevent block-RAM inference.  With the default 4096 entries this takes about
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
    end else if (pair_done) begin
        pair_cache[rom_0_addr[INDEX_W-1:0]] <= {
            1'b1, rom_0_addr[ADDR_W-1:INDEX_W], pair_complete
        };
    end
end

always @(posedge clk) begin
    if (rst) begin
        rom_0_addr <= {ADDR_W{1'b1}};
        rom_1_addr <= {ADDR_W{1'b1}};
        rom_0_cs <= 1'b0;
        rom_1_cs <= 1'b0;
        q <= {PAIR_W{1'b1}};
        byte_0 <= {DATA_W{1'b1}};
        byte_1 <= {DATA_W{1'b1}};
        got_0 <= 1'b0;
        got_1 <= 1'b0;
        req_active <= 1'b0;
        req_gap <= 1'b0;
        lookup_pending <= 1'b0;
        lookup_tag <= {TAG_W{1'b1}};
    end else if (cache_init) begin
        rom_0_cs <= 1'b0;
        rom_1_cs <= 1'b0;
        req_active <= 1'b0;
        req_gap <= 1'b0;
        lookup_pending <= 1'b0;
    end else if (req_active) begin
        if (rom_0_ok && !got_0) begin
            byte_0 <= rom_0_data;
            got_0 <= 1'b1;
            rom_0_cs <= 1'b0;
        end

        if (rom_1_ok && !got_1) begin
            byte_1 <= rom_1_data;
            got_1 <= 1'b1;
            rom_1_cs <= 1'b0;
        end

        if ((got_0 || rom_0_ok) && (got_1 || rom_1_ok)) begin
            q <= pair_complete;
            rom_0_cs <= 1'b0;
            rom_1_cs <= 1'b0;
            req_active <= 1'b0;
            req_gap <= 1'b1;
        end
    end else if (req_gap) begin
        rom_0_cs <= 1'b0;
        rom_1_cs <= 1'b0;
        req_gap <= 1'b0;
    end else if (lookup_pending) begin
        lookup_pending <= 1'b0;
        if (cache_q[CACHE_W-1] &&
            (cache_q[CACHE_W-2:PAIR_W] == lookup_tag)) begin
            q <= cache_q[PAIR_W-1:0];
        end else begin
            rom_0_cs <= 1'b1;
            rom_1_cs <= 1'b1;
            got_0 <= 1'b0;
            got_1 <= 1'b0;
            req_active <= 1'b1;
        end
    end else if (cen && (addr != rom_0_addr)) begin
        rom_0_addr <= addr;
        rom_1_addr <= addr;
        rom_0_cs <= 1'b0;
        rom_1_cs <= 1'b0;
        lookup_tag <= addr[ADDR_W-1:INDEX_W];
        lookup_pending <= 1'b1;
    end
end

endmodule
