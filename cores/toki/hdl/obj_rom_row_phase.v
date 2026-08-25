`ifndef OBJ_ROM_ROW_PHASE_V
`define OBJ_ROM_ROW_PHASE_V

// Combinational phase adapter for one four-word, four-plane object-ROM row.
//
// This is FPGA replay timing support, not a PCB custom IC. The physical ROM
// is already driving the serializer before the H=8 line-RAM write window.
// A row returned from acknowledged SDRAM becomes active at a registered pair
// boundary instead. With the behavioral SEI0010 edge model, an unadjusted row
// appears as pixels 3..15,0..2 during that window. Repacking the cached row by
// PHASE pixels restores pixels 0..15 without delaying WREN across the next
// descriptor pair. Reverse mode needs the opposite raw rotation because both
// the ROM-word order and serializer shift direction are reversed.
//
// Raw format is the Toki four-word planar layout returned by the live
// dual-row replay facade:
// pixel p selects bit p%4 from bit groups 12,8,4,0 of word p/4.
module obj_rom_row_phase #(
    parameter integer PHASE = 3
)(
    input      [63:0] row_in,
    input             reverse,
    output     [63:0] row_out
);

wire [3:0] raw_pixel [0:15];
wire [3:0] phased_pixel [0:15];

genvar pixel;
generate
    for (pixel = 0; pixel < 16; pixel = pixel + 1) begin : gen_pixel
        localparam integer WORD_BASE = (pixel / 4) * 16;
        localparam integer WORD_BIT  = pixel % 4;
        localparam integer FWD_SRC = (pixel + 16 - PHASE) % 16;
        localparam integer REV_SRC = (pixel + PHASE) % 16;

        assign raw_pixel[pixel] = {
            row_in[WORD_BASE + 12 + WORD_BIT],
            row_in[WORD_BASE +  8 + WORD_BIT],
            row_in[WORD_BASE +  4 + WORD_BIT],
            row_in[WORD_BASE +      WORD_BIT]
        };
        assign phased_pixel[pixel] = reverse ?
                                             raw_pixel[REV_SRC] :
                                             raw_pixel[FWD_SRC];

        assign row_out[WORD_BASE + 12 + WORD_BIT] =
               phased_pixel[pixel][3];
        assign row_out[WORD_BASE +  8 + WORD_BIT] =
               phased_pixel[pixel][2];
        assign row_out[WORD_BASE +  4 + WORD_BIT] =
               phased_pixel[pixel][1];
        assign row_out[WORD_BASE +      WORD_BIT] =
               phased_pixel[pixel][0];
    end
endgenerate

endmodule

`endif
