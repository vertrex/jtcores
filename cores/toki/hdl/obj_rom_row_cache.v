`ifndef OBJ_ROM_ROW_CACHE_V
`define OBJ_ROM_ROW_CACHE_V

// Tagged cache for complete four-word object-ROM rows.
//
// This is FPGA transport support, not a model of a Toki PCB IC.  The board's
// mask ROM is local and asynchronous, so the four words selected while OBJPS
// shifts one row do not contend with the background and sound buses.  JTFRAME
// stores those ROMs in acknowledged SDRAM.  A cache hit restores the local-ROM
// property; a miss is held and collected by obj_rom_row_bridge.
//
// req_key is deliberately supplied by the caller instead of being inferred
// from req_base.  That keeps address-layout knowledge out of this module and
// makes it reusable for another four-word ROM layout.  The low INDEX_W bits
// select a direct-mapped entry and the remaining bits are its collision tag.
// Only complete acknowledged rows are installed.
module obj_rom_row_cache #(
    parameter AW = 18,
    parameter DW = 16,
    parameter CTX_W = 2,
    parameter KEY_W = 17,
    parameter INDEX_W = 12
)(
    input                         clk,
    input                         rst,

    input                         req_valid,
    output                        req_ready,
    input                         req_rom_select,
    input      [AW-1:0]            req_base,
    input      [KEY_W-1:0]         req_key,
    input      [CTX_W-1:0]         req_ctx,

    output                        rom_cs,
    output                        rom_select,
    output     [AW-1:0]            rom_addr,
    input      [DW-1:0]            rom_data,
    input                         rom_ok,

    output                        row_done,
    output     [(4*DW)-1:0]        row_data,
    output     [CTX_W-1:0]         row_ctx,
    output                        busy,
    output                        cache_hit
);

localparam TAG_W = KEY_W - INDEX_W;
localparam ENTRY_W = 1 + TAG_W + (4*DW);
localparam [2:0] CACHE_INIT        = 3'd0;
localparam [2:0] CACHE_IDLE        = 3'd1;
localparam [2:0] CACHE_LOOKUP_WAIT = 3'd2;
localparam [2:0] CACHE_LOOKUP      = 3'd3;
localparam [2:0] CACHE_MISS_REQ    = 3'd4;
localparam [2:0] CACHE_MISS_WAIT   = 3'd5;

(* ramstyle = "M10K, no_rw_check" *)
reg [ENTRY_W-1:0] cache_mem [0:(1<<INDEX_W)-1];
reg [ENTRY_W-1:0] cache_q;
reg [INDEX_W-1:0] cache_addr;
reg [INDEX_W-1:0] clear_addr;

reg [2:0] state;
reg [AW-1:0] base_r;
reg [KEY_W-1:0] key_r;
reg [CTX_W-1:0] ctx_r;
reg rom_select_r;

wire bridge_ready;
wire bridge_done;
wire [(4*DW)-1:0] bridge_row;
wire [CTX_W-1:0] bridge_ctx;
wire bridge_busy;
wire bridge_req = state == CACHE_MISS_REQ;
wire bridge_fire = bridge_req && bridge_ready;
wire hit = cache_q[ENTRY_W-1] &&
           (cache_q[ENTRY_W-2:4*DW] == key_r[KEY_W-1:INDEX_W]);

assign req_ready  = state == CACHE_IDLE;
assign busy       = state != CACHE_IDLE;
assign rom_select = rom_select_r;
assign cache_hit  = (state == CACHE_LOOKUP) && hit;
assign row_done   = cache_hit || bridge_done;
assign row_data   = cache_hit ? cache_q[(4*DW)-1:0] : bridge_row;
assign row_ctx    = cache_hit ? ctx_r : bridge_ctx;

obj_rom_row_bridge #(
    .AW(AW),
    .DW(DW),
    .CTX_W(CTX_W)
) row_bridge_u (
    .clk(clk),
    .rst(rst),
    .req_valid(bridge_req),
    .req_ready(bridge_ready),
    .req_base(base_r),
    .req_ctx(ctx_r),
    .rom_cs(rom_cs),
    .rom_addr(rom_addr),
    .rom_data(rom_data),
    .rom_ok(rom_ok),
    .row_done(bridge_done),
    .row_data(bridge_row),
    .row_ctx(bridge_ctx),
    .busy(bridge_busy)
);

always @(posedge clk) begin
    cache_q <= cache_mem[cache_addr];

    if (rst) begin
        state        <= CACHE_INIT;
        cache_addr   <= {INDEX_W{1'b0}};
        clear_addr   <= {INDEX_W{1'b0}};
        base_r       <= {AW{1'b0}};
        key_r        <= {KEY_W{1'b0}};
        ctx_r        <= {CTX_W{1'b0}};
        rom_select_r <= 1'b0;
    end else begin
        case (state)
            CACHE_INIT: begin
                cache_mem[clear_addr] <= {ENTRY_W{1'b0}};
                if (clear_addr == {INDEX_W{1'b1}}) begin
                    clear_addr <= {INDEX_W{1'b0}};
                    state <= CACHE_IDLE;
                end else begin
                    clear_addr <= clear_addr + {{(INDEX_W-1){1'b0}}, 1'b1};
                end
            end

            CACHE_IDLE: begin
                if (req_valid) begin
                    base_r       <= req_base;
                    key_r        <= req_key;
                    ctx_r        <= req_ctx;
                    rom_select_r <= req_rom_select;
                    cache_addr   <= req_key[INDEX_W-1:0];
                    state        <= CACHE_LOOKUP_WAIT;
                end
            end

            // cache_mem is inferred as synchronous block RAM.  One state
            // launches its address and the next consumes cache_q.
            CACHE_LOOKUP_WAIT: state <= CACHE_LOOKUP;

            CACHE_LOOKUP: begin
                if (hit)
                    state <= CACHE_IDLE;
                else
                    state <= CACHE_MISS_REQ;
            end

            CACHE_MISS_REQ: begin
                if (bridge_fire)
                    state <= CACHE_MISS_WAIT;
            end

            CACHE_MISS_WAIT: begin
                if (bridge_done) begin
                    cache_mem[key_r[INDEX_W-1:0]] <= {
                        1'b1, key_r[KEY_W-1:INDEX_W], bridge_row
                    };
                    state <= CACHE_IDLE;
                end
            end

            default: state <= CACHE_INIT;
        endcase
    end
end

endmodule

`endif
