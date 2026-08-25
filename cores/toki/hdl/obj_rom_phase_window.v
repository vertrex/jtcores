`ifndef OBJ_ROM_PHASE_WINDOW_V
`define OBJ_ROM_PHASE_WINDOW_V

// Fixed-wiring extractor for four display-order pixels from a phase-packed
// planar row.
//
// obj_rom_row_phase stores a raw 16-pixel row at a caller-selected serializer
// phase.  This helper repacks display pixels START_PIXEL..START_PIXEL+3 into
// one word ready for the same serializer direction.  All source indices are
// elaboration-time constants; PHASE/START_PIXEL infer wiring, not dividers,
// modulo logic or a runtime row-address machine.
module obj_rom_phase_window #(
    parameter integer PHASE       = 0,
    parameter integer START_PIXEL = 0
)(
    input      [63:0] row_in,
    input             reverse,
    output     [15:0] word_out
);

genvar plane;
genvar bit_pos;
generate
    for (plane = 0; plane < 4; plane = plane + 1) begin : gen_plane
        for (bit_pos = 0; bit_pos < 4; bit_pos = bit_pos + 1) begin : gen_bit
            // Forward consumes word bits 0->3. Reverse consumes 3->0, so the
            // display-time index corresponding to a reverse destination bit
            // is (3-bit_pos).
            localparam integer FWD_SRC_PIXEL =
                (PHASE + START_PIXEL + bit_pos) % 16;
            localparam integer REV_SRC_PIXEL =
                (64 + 15 - PHASE - START_PIXEL - (3 - bit_pos)) % 16;
            localparam integer FWD_SRC_BIT =
                ((FWD_SRC_PIXEL / 4) * 16) + (plane * 4) +
                (FWD_SRC_PIXEL % 4);
            localparam integer REV_SRC_BIT =
                ((REV_SRC_PIXEL / 4) * 16) + (plane * 4) +
                (REV_SRC_PIXEL % 4);

            assign word_out[(plane * 4) + bit_pos] = reverse ?
                row_in[REV_SRC_BIT] : row_in[FWD_SRC_BIT];
        end
    end
endgenerate

endmodule

`endif
