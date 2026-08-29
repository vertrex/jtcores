`ifndef OBJ_DUAL_ROW_REPLAY_V
`define OBJ_DUAL_ROW_REPLAY_V

// FPGA-only four-row replay store for the acknowledged object-ROM adapter.
//
// This is transport/storage support, not a model of a Toki PCB custom IC.  It
// lets a caller collect the two independently tagged rows consumed by the two
// physical serializers while alternating between two caller-owned pair
// banks. Lane numbers are deliberately opaque here: their H2/U162/U168
// mapping belongs to the sheet-16 scheduler and must not be guessed in a
// transport block. ROM requests are serialized through jtframe_rom_cache4 so
// sticky/stale OK behavior is handled once at the SDRAM boundary.
//
// Caller ownership contract:
//   * push_pair_bank must name a bank that is not being replayed or otherwise
//     retained by the caller;
//   * this module deliberately does not reject writes to active_pair_bank;
//   * push fields remain valid through an accepted push_valid/push_ready beat.
//
// A descriptor with push_present=0 completes immediately with 16'hffff in all
// four words, matching transparent object data. Completion and ownership are
// reported through slot_done/slot_done_ctx; the former per-lane ready map was
// not consumed by the production scheduler and has been removed.
//
// Literal raw FIRST/SECND timing now supplies the physical lane displacement in
// the caller. Rows therefore remain in mask-ROM word order here; the obsolete
// normalized-raster phase rotation and cross-bank word splice are deliberately
// absent from this storage block.
module obj_dual_row_replay(
    input             clk,
    input             rst,

    input             push_valid,
    output            push_ready,
    input             push_present,
    input             push_lane,
    input             push_pair_bank,
    input             push_rom_select,
    input      [17:0] push_row_base,

    output            rom_cs,
    output            rom_select,
    output     [17:0] rom_addr,
    input      [15:0] rom_data,
    input             rom_ok,

    input             active_pair_bank,
    input             replay_lane,
    input      [1:0]  word_sel,
    output     [15:0] replay_pd,
    // slot_done is the accepted completion beat. For a present descriptor it
    // is the bridge's final ROM-word cycle; an absent descriptor completes on
    // its accepted push beat. Capture slot_done_ctx on the closing clk edge.
    output            slot_done,
    output     [1:0]  slot_done_ctx
);

reg [63:0] rows [0:3];
wire       row_cache_ready;
wire       row_cache_done;
wire [63:0] row_cache_data;
wire [2:0] row_cache_ctx;
wire [2:0] row_rom_ctx;
wire [1:0] push_ctx = {push_pair_bank, push_lane};
wire [2:0] push_cache_ctx = {
    push_rom_select, push_pair_bank, push_lane
};
wire [1:0] replay_ctx = {active_pair_bank, replay_lane};
wire       push_fire = push_valid && push_ready;
wire [63:0] replay_row = rows[replay_ctx];
// Logical key order matches the original adapter: ROM/tile[11:0]/row[3:0].
// push_row_base is {tile,1'b0,row,1'b0}; the two zero word-select bits are not
// part of the row identity.
wire [16:0] push_row_key = {
    push_rom_select, push_row_base[17:6], push_row_base[4:1]
};

function [15:0] select_word;
    input [63:0] row;
    input  [1:0] select;
    begin
        case (select)
            2'd0: select_word = row[15:0];
            2'd1: select_word = row[31:16];
            2'd2: select_word = row[47:32];
            default: select_word = row[63:48];
        endcase
    end
endfunction

wire [15:0] replay_word = select_word(replay_row, word_sel);

// Invalid descriptors use the same single-entry admission point as ROM
// requests. This prevents a later response from an outstanding request from
// overwriting a locally completed invalid descriptor in the same slot.
assign push_ready = row_cache_ready;
assign slot_done  = row_cache_done || (push_fire && !push_present);
assign slot_done_ctx = row_cache_done ? row_cache_ctx[1:0] : push_ctx;
assign rom_select = row_rom_ctx[2];

jtframe_rom_cache4 #(
    .AW(18),
    .DW(16),
    .CTX_W(3),
    .KEY_W(17),
    .INDEX_W(12)
) row_cache_u (
    .clk(clk),
    .rst(rst),
    .req_valid(push_valid && push_present),
    .req_ready(row_cache_ready),
    .req_base(push_row_base),
    .req_key(push_row_key),
    .req_ctx(push_cache_ctx),
    .rom_cs(rom_cs),
    .rom_addr(rom_addr),
    .rom_ctx(row_rom_ctx),
    .rom_data(rom_data),
    .rom_ok(rom_ok),
    .rsp_valid(row_cache_done),
    .rsp_data(row_cache_data),
    .rsp_ctx(row_cache_ctx),
    .busy(),
    .cache_hit()
);

assign replay_pd = replay_word;

integer row_index;
always @(posedge clk) begin
    if (rst) begin
        for (row_index = 0; row_index < 4; row_index = row_index + 1)
            rows[row_index] <= 64'hffff_ffff_ffff_ffff;
    end else begin
        if (push_fire && !push_present)
            rows[push_ctx] <= 64'hffff_ffff_ffff_ffff;

        if (row_cache_done)
            rows[row_cache_ctx[1:0]] <= row_cache_data;
    end
end

endmodule

`endif
