`ifndef OBJ_ROM_PAIR_BOUNDARY_V
`define OBJ_ROM_PAIR_BOUNDARY_V

// FPGA transport helper for one phase-packed cached-row handoff.
//
// Build the end of one display row followed by the beginning of the next from
// two complete cached rows. OLD_PIXELS=3 retains the original generic helper
// contract (old 13..15/new 0). The Toki sheet-16 physical T3F phases use
// OLD_PIXELS=2 (old 14..15/new 0..1). When direction changes, a new pixel can
// live at the opposite end of another physical word; extracting display-order
// windows avoids any assumption about word alignment.
//
// A delayed physical serializer loads the boundary twice around FIRST. On its
// second load, after ownership changes, it needs the next four new-row pixels
// rather than another old/new splice: new 1..4 for OLD_PIXELS=3, or new 2..5
// for the physical Toki OLD_PIXELS=2 contract.
//
// Word selection, row ownership and the decision that a load is the delayed
// reload remain caller policy.  This module contains no Toki raster state and
// does not model an unidentified PCB custom-IC function.
module obj_rom_pair_boundary #(
    parameter integer PHASE = 0,
    // Supported handoff shapes are 3-old/1-new and 2-old/2-new.
    parameter [1:0] OLD_PIXELS = 2'd3
)(
    input      [63:0] old_row,
    input      [63:0] new_row,
    input             old_reverse,
    input             new_reverse,
    input             delayed_reload,
    output     [15:0] word_out
);

wire [15:0] old_tail_word;
wire [15:0] new_first_word;
wire [15:0] new_continuation_word;
wire [15:0] boundary_p0_word;
wire [15:0] boundary_p1_word;
wire  [1:0] new_p0_slot = new_reverse ? 2'd3 : 2'd0;
wire  [1:0] new_p1_slot = new_reverse ? 2'd2 : 2'd1;
localparam [1:0] FWD_P0_SLOT = OLD_PIXELS;
localparam [1:0] REV_P0_SLOT = 2'd3 - OLD_PIXELS;
localparam integer OLD_START_PIXEL =
    (OLD_PIXELS == 2'd2) ? 14 : 13;
localparam integer CONTINUATION_START_PIXEL =
    (OLD_PIXELS == 2'd2) ? 2 : 1;
wire  [1:0] dst_p0_slot = old_reverse ? REV_P0_SLOT : FWD_P0_SLOT;
wire  [1:0] dst_p1_slot = old_reverse ? 2'd0 : 2'd3;
wire        mixed_direction = old_reverse ^ new_reverse;

obj_rom_phase_window #(
    .PHASE(PHASE),
    .START_PIXEL(OLD_START_PIXEL)
) old_tail_window_u (
    .row_in(old_row),
    .reverse(old_reverse),
    .word_out(old_tail_word)
);

obj_rom_phase_window #(
    .PHASE(PHASE),
    .START_PIXEL(0)
) new_first_window_u (
    .row_in(new_row),
    .reverse(new_reverse),
    .word_out(new_first_word)
);

obj_rom_phase_window #(
    .PHASE(PHASE),
    .START_PIXEL(CONTINUATION_START_PIXEL)
) new_continuation_window_u (
    .row_in(new_row),
    .reverse(new_reverse),
    .word_out(new_continuation_word)
);

obj_planar_pixel_patch #(
    .PLANES(4),
    .PIXELS(4),
    .INDEX_W(2)
) boundary_p0_u (
    .base_word(old_tail_word),
    .patch_word(new_first_word),
    .source_pixel(new_p0_slot),
    .destination_pixel(dst_p0_slot),
    .patch_enable(1'b1),
    .result_word(boundary_p0_word)
);

obj_planar_pixel_patch #(
    .PLANES(4),
    .PIXELS(4),
    .INDEX_W(2)
) boundary_p1_u (
    .base_word(boundary_p0_word),
    .patch_word(new_first_word),
    .source_pixel(new_p1_slot),
    .destination_pixel(dst_p1_slot),
    .patch_enable(OLD_PIXELS == 2'd2),
    .result_word(boundary_p1_word)
);

assign word_out = mixed_direction && delayed_reload ?
                  new_continuation_word : boundary_p1_word;

endmodule

`endif
