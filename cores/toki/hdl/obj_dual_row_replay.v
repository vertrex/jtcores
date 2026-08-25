`ifndef OBJ_DUAL_ROW_REPLAY_V
`define OBJ_DUAL_ROW_REPLAY_V

// FPGA-only four-row replay store for the acknowledged object-ROM adapter.
//
// This is transport/storage support, not a model of a Toki PCB custom IC.  It
// lets a caller collect the two independently tagged rows consumed by the two
// physical serializers while alternating between two caller-owned pair
// banks. Lane numbers are deliberately opaque here: their H2/U162/U168
// mapping belongs to the sheet-16 scheduler and must not be guessed in a
// transport block. ROM requests are serialized through obj_rom_row_bridge so
// sticky/stale OK behavior is handled once at the SDRAM boundary.
//
// Caller ownership contract:
//   * push_pair_bank must name a bank that is not being replayed or otherwise
//     retained by the caller;
//   * this module deliberately does not reject writes to active_pair_bank;
//   * each accepted push replaces the selected lane's readiness state;
//   * push fields remain valid through an accepted push_valid/push_ready beat.
//
// pair_ready is for active_pair_bank only. Bit 0 is the direct lane and bit 1
// is the delayed lane. A descriptor with push_present=0 completes immediately
// with 16'hffff in all four words, matching transparent object data.
module obj_dual_row_replay #(
    // Optional caller-defined replay phases. Lane meaning remains opaque to
    // this transport block; the sheet scheduler supplies its measured values.
    parameter integer LANE0_PHASE_SHIFT = 0,
    parameter integer LANE1_PHASE_SHIFT = 0
)(
    input             clk,
    input             rst,

    input             push_valid,
    output            push_ready,
    input             push_present,
    input             push_lane,
    input             push_pair_bank,
    input             push_rom_select,
    input             push_reverse,
    input      [17:0] push_row_base,

    output            rom_cs,
    output            rom_select,
    output     [17:0] rom_addr,
    input      [15:0] rom_data,
    input             rom_ok,

    input             active_pair_bank,
    input             replay_lane,
    input      [1:0]  word_sel,
    // Optional continuous-stream seam. The caller supplies both banks, the
    // one word which crosses its row boundary, and the consume direction.
    // Lane meaning and the decision to overlap remain caller policy.
    input             seam_valid,
    input             seam_old_pair_bank,
    input             seam_new_pair_bank,
    input      [1:0]  seam_word_sel,
    input             seam_reverse,
    output     [1:0]  pair_ready,
    output     [3:0]  ready_map,
    output     [15:0] replay_pd,
    // slot_done is the accepted completion beat. For a present descriptor it
    // is the bridge's final ROM-word cycle; an absent descriptor completes on
    // its accepted push beat. Capture slot_done_ctx on the closing clk edge.
    output            slot_done,
    output     [1:0]  slot_done_ctx,
    output            busy
);

reg [63:0] rows [0:3];
reg [3:0]  lane_ready;
reg [3:0]  lane_reverse;
wire       row_cache_ready;
wire       row_cache_done;
wire [63:0] row_cache_data;
wire [1:0] row_cache_ctx;
wire       row_cache_busy;
wire       row_cache_hit;
wire [1:0] push_ctx = {push_pair_bank, push_lane};
wire [1:0] replay_ctx = {active_pair_bank, replay_lane};
wire [1:0] seam_old_ctx = {seam_old_pair_bank, replay_lane};
wire [1:0] seam_new_ctx = {seam_new_pair_bank, replay_lane};
wire       push_fire = push_valid && push_ready;
wire [63:0] replay_row = rows[replay_ctx];
wire [63:0] seam_old_row = rows[seam_old_ctx];
wire [63:0] seam_new_row = rows[seam_new_ctx];
wire [63:0] phased_direct_row;
wire [63:0] phased_delayed_row;
wire [63:0] phased_cache_row = row_cache_ctx[0] ?
                               phased_delayed_row : phased_direct_row;
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
wire        seam_new_reverse = lane_reverse[seam_new_ctx];
wire seam_delayed_reload = replay_lane &&
                           (active_pair_bank == seam_new_pair_bank);
wire [15:0] seam_lane0_word;
wire [15:0] seam_lane1_word;
wire [15:0] seam_word = replay_lane ? seam_lane1_word : seam_lane0_word;

// Invalid descriptors use the same single-entry admission point as ROM
// requests. This prevents a later response from an outstanding request from
// overwriting a locally completed invalid descriptor in the same slot.
assign push_ready = row_cache_ready;
assign pair_ready = active_pair_bank ? lane_ready[3:2] : lane_ready[1:0];
assign ready_map  = lane_ready;
assign slot_done  = row_cache_done || (push_fire && !push_present);
assign slot_done_ctx = row_cache_done ? row_cache_ctx : push_ctx;
assign busy       = row_cache_busy;

obj_rom_row_cache #(
    .AW(18),
    .DW(16),
    .CTX_W(2),
    .KEY_W(17),
    .INDEX_W(12)
) row_cache_u (
    .clk(clk),
    .rst(rst),
    .req_valid(push_valid && push_present),
    .req_ready(row_cache_ready),
    .req_rom_select(push_rom_select),
    .req_base(push_row_base),
    .req_key(push_row_key),
    .req_ctx(push_ctx),
    .rom_cs(rom_cs),
    .rom_select(rom_select),
    .rom_addr(rom_addr),
    .rom_data(rom_data),
    .rom_ok(rom_ok),
    .row_done(row_cache_done),
    .row_data(row_cache_data),
    .row_ctx(row_cache_ctx),
    .busy(row_cache_busy),
    .cache_hit(row_cache_hit)
);

obj_rom_row_phase #(
    .PHASE(LANE0_PHASE_SHIFT)
) lane0_row_phase_u (
    .row_in(row_cache_data),
    .reverse(lane_reverse[row_cache_ctx]),
    .row_out(phased_direct_row)
);

obj_rom_row_phase #(
    .PHASE(LANE1_PHASE_SHIFT)
) lane1_row_phase_u (
    .row_in(row_cache_data),
    .reverse(lane_reverse[row_cache_ctx]),
    .row_out(phased_delayed_row)
);

obj_rom_pair_boundary #(
    .PHASE(LANE0_PHASE_SHIFT),
    // Literal SEI0050 T3F/T3F_2 phases cross the dense handoff after two
    // old-row pixels; the following two pixels already belong to the new row.
    .OLD_PIXELS(2)
) seam_lane0_boundary_u (
    .old_row(seam_old_row),
    .new_row(seam_new_row),
    .old_reverse(seam_reverse),
    .new_reverse(seam_new_reverse),
    .delayed_reload(seam_delayed_reload),
    .word_out(seam_lane0_word)
);

obj_rom_pair_boundary #(
    .PHASE(LANE1_PHASE_SHIFT),
    .OLD_PIXELS(2)
) seam_lane1_boundary_u (
    .old_row(seam_old_row),
    .new_row(seam_new_row),
    .old_reverse(seam_reverse),
    .new_reverse(seam_new_reverse),
    .delayed_reload(seam_delayed_reload),
    .word_out(seam_lane1_word)
);

assign replay_pd = seam_valid && (word_sel == seam_word_sel) ?
                   seam_word : replay_word;

integer row_index;
always @(posedge clk) begin
    if (rst) begin
        lane_ready  <= 4'b0000;
        lane_reverse <= 4'b0000;
        for (row_index = 0; row_index < 4; row_index = row_index + 1)
            rows[row_index] <= 64'hffff_ffff_ffff_ffff;
    end else begin
        if (push_fire) begin
            lane_reverse[push_ctx] <= push_reverse;
            if (push_present) begin
                lane_ready[push_ctx] <= 1'b0;
            end else begin
                rows[push_ctx]       <= 64'hffff_ffff_ffff_ffff;
                lane_ready[push_ctx] <= 1'b1;
            end
        end

        if (row_cache_done) begin
            rows[row_cache_ctx]       <= phased_cache_row;
            lane_ready[row_cache_ctx] <= 1'b1;
        end
    end
end

endmodule

`endif
