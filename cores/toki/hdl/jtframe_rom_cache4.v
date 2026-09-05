`ifndef JTFRAME_ROM_CACHE4_V
`define JTFRAME_ROM_CACHE4_V

`timescale 1ns/1ps

// Direct-mapped cache for complete four-word acknowledged-ROM responses.
//
// This is a generic FPGA transport primitive.  A caller supplies the logical
// key separately from the physical base address, so ROM layout and bank
// selection remain outside.  Only complete groups are installed or exposed;
// misses are streamed by jtframe_rom_fetch4 and assembled atomically here.
// Opaque context accompanies both cache hits and misses.  rom_ctx exposes the
// active miss context so a caller can select one of several external ROMs.
// INDEX_W must be at least 2: its top bit selects one of the two physical
// memories and the remaining bits address an entry inside that memory.
module jtframe_rom_cache4 #(
    parameter AW = 18,
    parameter DW = 16,
    parameter CTX_W = 1,
    parameter KEY_W = 17,
    parameter INDEX_W = 12,
    parameter [AW-1:0] WORD1_MASK = {{(AW-1){1'b0}}, 1'b1},
    parameter [AW-1:0] WORD2_MASK = {{(AW-6){1'b0}}, 6'b100000},
    parameter [AW-1:0] WORD3_MASK = {{(AW-6){1'b0}}, 6'b100001}
)(
    input                         clk,
    input                         rst,

    input                         req_valid,
    output                        req_ready,
    input      [AW-1:0]           req_base,
    input      [KEY_W-1:0]        req_key,
    input      [CTX_W-1:0]        req_ctx,

    output                        rom_cs,
    output     [AW-1:0]           rom_addr,
    output     [CTX_W-1:0]        rom_ctx,
    input      [DW-1:0]           rom_data,
    input                         rom_ok,

    output                        rsp_valid,
    output     [(4*DW)-1:0]       rsp_data,
    output     [CTX_W-1:0]        rsp_ctx,
    output                        busy,
    output                        cache_hit
);

localparam TAG_W = KEY_W - INDEX_W;
localparam ENTRY_W = 1 + TAG_W + (4*DW);
localparam BANK_AW = INDEX_W - 1;
localparam BANK_DEPTH = 1 << BANK_AW;
localparam [2:0] CACHE_INIT        = 3'd0;
localparam [2:0] CACHE_IDLE        = 3'd1;
localparam [2:0] CACHE_LOOKUP_WAIT = 3'd2;
localparam [2:0] CACHE_LOOKUP      = 3'd3;
localparam [2:0] CACHE_MISS_REQ    = 3'd4;
localparam [2:0] CACHE_MISS_WAIT   = 3'd5;

// Splitting the index across two physical memories keeps the same logical
// direct-map cache while matching the useful depth/width aspect ratio of an
// M10K.  The selected bank bit is registered with both synchronous reads, so
// lookup latency is identical to the former single 4096-entry array.
(* ramstyle = "M10K, no_rw_check" *)
reg [ENTRY_W-1:0] cache_mem_0 [0:BANK_DEPTH-1];
(* ramstyle = "M10K, no_rw_check" *)
reg [ENTRY_W-1:0] cache_mem_1 [0:BANK_DEPTH-1];
reg [ENTRY_W-1:0] cache_q_0;
reg [ENTRY_W-1:0] cache_q_1;
reg               cache_bank_q;
reg [INDEX_W-1:0] cache_addr;
reg [INDEX_W-1:0] clear_addr;

reg [2:0] state;
reg [AW-1:0] base_r;
reg [KEY_W-1:0] key_r;
reg [CTX_W-1:0] ctx_r;

reg [DW-1:0] word_0;
reg [DW-1:0] word_1;
reg [DW-1:0] word_2;

wire fetch_ready;
wire fetch_word_valid;
wire [1:0] fetch_word_index;
wire [DW-1:0] fetch_word_data;
wire [CTX_W-1:0] fetch_word_ctx;
wire fetch_done;
wire fetch_req = state == CACHE_MISS_REQ;
wire fetch_fire = fetch_req && fetch_ready;
wire [ENTRY_W-1:0] cache_q = cache_bank_q ? cache_q_1 : cache_q_0;
wire hit = cache_q[ENTRY_W-1] &&
           (cache_q[ENTRY_W-2:4*DW] == key_r[KEY_W-1:INDEX_W]);
wire [(4*DW)-1:0] fetched_group = {
    fetch_word_data, word_2, word_1, word_0
};

assign req_ready = state == CACHE_IDLE;
assign busy      = state != CACHE_IDLE;
assign cache_hit = (state == CACHE_LOOKUP) && hit;
assign rsp_valid = cache_hit || fetch_done;
assign rsp_data  = cache_hit ? cache_q[(4*DW)-1:0] : fetched_group;
assign rsp_ctx   = cache_hit ? ctx_r : fetch_word_ctx;
assign rom_ctx   = fetch_word_ctx;

jtframe_rom_fetch4 #(
    .AW(AW),
    .DW(DW),
    .CTX_W(CTX_W),
    .WORD1_MASK(WORD1_MASK),
    .WORD2_MASK(WORD2_MASK),
    .WORD3_MASK(WORD3_MASK)
) fetch_u (
    .clk(clk),
    .rst(rst),
    .req_valid(fetch_req),
    .req_ready(fetch_ready),
    .req_base(base_r),
    .req_ctx(ctx_r),
    .rom_cs(rom_cs),
    .rom_addr(rom_addr),
    .rom_data(rom_data),
    .rom_ok(rom_ok),
    .word_valid(fetch_word_valid),
    .word_index(fetch_word_index),
    .word_data(fetch_word_data),
    .word_ctx(fetch_word_ctx),
    .done(fetch_done),
    .busy()
);

always @(posedge clk) begin
    cache_q_0   <= cache_mem_0[cache_addr[BANK_AW-1:0]];
    cache_q_1   <= cache_mem_1[cache_addr[BANK_AW-1:0]];
    cache_bank_q <= cache_addr[INDEX_W-1];

    if (rst) begin
        state      <= CACHE_INIT;
        cache_addr <= {INDEX_W{1'b0}};
        clear_addr <= {INDEX_W{1'b0}};
        base_r     <= {AW{1'b0}};
        key_r      <= {KEY_W{1'b0}};
        ctx_r      <= {CTX_W{1'b0}};
    end else begin
        case (state)
            CACHE_INIT: begin
                if (clear_addr[INDEX_W-1])
                    cache_mem_1[clear_addr[BANK_AW-1:0]] <=
                        {ENTRY_W{1'b0}};
                else
                    cache_mem_0[clear_addr[BANK_AW-1:0]] <=
                        {ENTRY_W{1'b0}};
                if (clear_addr == {INDEX_W{1'b1}}) begin
                    clear_addr <= {INDEX_W{1'b0}};
                    state <= CACHE_IDLE;
                end else begin
                    clear_addr <= clear_addr +
                                  {{(INDEX_W-1){1'b0}}, 1'b1};
                end
            end

            CACHE_IDLE: begin
                if (req_valid) begin
                    base_r     <= req_base;
                    key_r      <= req_key;
                    ctx_r      <= req_ctx;
                    cache_addr <= req_key[INDEX_W-1:0];
                    state      <= CACHE_LOOKUP_WAIT;
                end
            end

            // Both cache memories are synchronous block RAM. One state
            // launches their shared low address and the next consumes the
            // output selected by the registered high index bit.
            CACHE_LOOKUP_WAIT: state <= CACHE_LOOKUP;

            CACHE_LOOKUP: begin
                if (hit)
                    state <= CACHE_IDLE;
                else
                    state <= CACHE_MISS_REQ;
            end

            CACHE_MISS_REQ: begin
                if (fetch_fire)
                    state <= CACHE_MISS_WAIT;
            end

            CACHE_MISS_WAIT: begin
                if (fetch_done) begin
                    if (key_r[INDEX_W-1])
                        cache_mem_1[key_r[BANK_AW-1:0]] <= {
                            1'b1, key_r[KEY_W-1:INDEX_W], fetched_group
                        };
                    else
                        cache_mem_0[key_r[BANK_AW-1:0]] <= {
                            1'b1, key_r[KEY_W-1:INDEX_W], fetched_group
                        };
                    state <= CACHE_IDLE;
                end
            end

            default: state <= CACHE_INIT;
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        word_0 <= {DW{1'b1}};
        word_1 <= {DW{1'b1}};
        word_2 <= {DW{1'b1}};
    end else if (fetch_word_valid) begin
        case (fetch_word_index)
            2'd0: word_0 <= fetch_word_data;
            2'd1: word_1 <= fetch_word_data;
            2'd2: word_2 <= fetch_word_data;
            default: begin end
        endcase
    end
end

endmodule

`endif
