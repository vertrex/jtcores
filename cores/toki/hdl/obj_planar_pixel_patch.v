`ifndef OBJ_PLANAR_PIXEL_PATCH_V
`define OBJ_PLANAR_PIXEL_PATCH_V

// Generic combinational helper for phase-packed planar graphics words.
//
// Replace one complete pixel in base_word with an independently addressed
// pixel from patch_word.  A Toki object-ROM word has four pixels in each of
// four plane nibbles, but the parameters keep this transport primitive free
// of raster, descriptor, cache and PCB-IC policy.
module obj_planar_pixel_patch #(
    parameter integer PLANES  = 4,
    parameter integer PIXELS  = 4,
    parameter integer INDEX_W = 2
)(
    input      [(PLANES*PIXELS)-1:0] base_word,
    input      [(PLANES*PIXELS)-1:0] patch_word,
    input      [INDEX_W-1:0]         source_pixel,
    input      [INDEX_W-1:0]         destination_pixel,
    input                            patch_enable,
    output reg [(PLANES*PIXELS)-1:0] result_word
);

integer plane;
wire [31:0] source_pixel_ext =
    {{(32-INDEX_W){1'b0}}, source_pixel};
wire [31:0] destination_pixel_ext =
    {{(32-INDEX_W){1'b0}}, destination_pixel};

always @* begin
    result_word = base_word;
    // Execute the elaboration-bounded loop on every path. Keeping the enable
    // inside avoids an old Quartus warning which treats the simulation-only
    // loop variable itself as conditionally assigned (result_word was always
    // complete, but the warning obscured the no-latch transport contract).
    for (plane = 0; plane < PLANES; plane = plane + 1) begin
        if (patch_enable)
            result_word[(plane*PIXELS) + destination_pixel_ext] =
                patch_word[(plane*PIXELS) + source_pixel_ext];
    end
end

endmodule

`endif
