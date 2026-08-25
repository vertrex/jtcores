`ifndef OBJ_LOAD_ALIGNED_REVERSE_V
`define OBJ_LOAD_ALIGNED_REVERSE_V

// FPGA serializer-phase adapter.
//
// On the PCB, asynchronous ROM data, the direction latch, SEI0010BU and the
// line RAM are separated by real propagation time.  In the common-clock FPGA
// replay path, changing direction between cached-word loads otherwise exposes
// the zero-filled opposite end of the behavioral shift register for one
// pixel.  Sample direction with a serializer load so every loaded word is
// consumed in one direction.  This helper owns no row, X, palette, priority or
// descriptor policy and is not a claim about an extra latch inside SEI0010BU.
module obj_load_aligned_reverse(
    input  clk,
    input  rst,
    input  cen,
    input  load,
    input  reverse_in,
    output reverse_out
);

reg reverse_r;

always @(posedge clk or posedge rst) begin
    if (rst)
        reverse_r <= 1'b0;
    else if (cen && load)
        reverse_r <= reverse_in;
end

assign reverse_out = reverse_r;

endmodule

`endif
