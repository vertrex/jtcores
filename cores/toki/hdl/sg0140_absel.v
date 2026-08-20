///////////////////////////////////////////////////
///////////// SG0140 ABSEL ////////////////////////
///////////////////////////////////////////////////

// SG0140
//
//priority / color mixer
// SG 0140 have 4 different mode
// mode is selected with pin 37/36

//        37,36
// MODE == 00 ABSEL (absolut selection or a b / select? )
// MODE == 10 VCHECK  ?
// MODE == 01 SORT4B  ?
// MODE == 11 OHMAX   ?

// The schematic exposes only SG0140 pins and mode selection. This is an
// externally compatible behavioral model, not a recovered internal netlist.

//sg0140_absel
module sg0140_absel(
  input       clk, //
  //input       rst,// pin 40
  input       cen, // pin 41, 38, 26 clock & enable

  //BK1
  input [3:0] PIC_A, //pin 9-12
  //input     PIC_A_EN //pin 38 6Mhz  enable color  ?
  input [3:0] COL_A, //pin 13-16
  input       COL_A_EN,// pin 39
  input       MASK_A,  // pin 3

  // CHAR
  input [3:0] PIC_B, //pin 28-31
  //input     PIC_B_EN //pin 26 6Mhz enable color  ?
  input [3:0] COL_B, //pin 32-35
  input       COL_B_EN,   // pin 27 enable
  input       MASK_B, // pin 2
  input [1:0] MODE, //pin 36,37

  output reg  [7:0] Q,  //17-20,23-25

  output reg  ON_A, //pin 8  active high
  output reg  ON_B //pin 7 active high
);

//  00   bk1 0 char 0 (e)
//  01   bk1 1 char 0 (8)
//  10   bk1 0 char 1 (4)
//  11   bk1 1 char 1 (4) //char > bk1 so ok

reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH;

// Sheet 10 presents each layer's color nibble before its CLLT capture phase.
// On that phase the same pixel must therefore use the nibble being captured.
// Reading only the nonblocking latch value below would retain the preceding
// tile's palette for one pixel in a synchronous FPGA implementation.
wire [3:0] COL_A_PIXEL = COL_A_EN ? COL_A : COL_A_LATCH;
wire [3:0] COL_B_PIXEL = COL_B_EN ? COL_B : COL_B_LATCH;

// Keep the current-pixel opacity terms separate from the registered ON pins.
// Reading ON_A/ON_B in the sequential block below would use the preceding
// pixel because nonblocking assignments do not publish until the clock event
// completes. In SG0140_6_21.dsl, physical S1ON pin 8 follows S1PIC opacity by
// 50/100 ns, consistent with N6M-falling publication rather than a direct
// wire. S4ON remains registered by the symmetric ABSEL path; that capture did
// not include S4PIC for an independent timing comparison.
wire A_OPAQUE = !MASK_A && (PIC_A[3:0] != 4'hf);
wire B_OPAQUE = !MASK_B && (PIC_B[3:0] != 4'hf);

always @(posedge clk) begin
  if (cen) begin
    if (COL_B_EN)
       COL_B_LATCH[3:0] <= COL_B[3:0];

    if (COL_A_EN)
       COL_A_LATCH[3:0] <= COL_A[3:0];

    // Pins 2/3 on the PCB are the per-layer mask inputs.  A masked input is
    // absent from both ON priority outputs and from the B-over-A selection,
    // exactly like a transparent F pixel.
    ON_A <= A_OPAQUE;
    ON_B <= B_OPAQUE;

    Q[7:0] <= B_OPAQUE ?
                 {COL_B_PIXEL[3:0], PIC_B[3:0]} :
               A_OPAQUE ?
                 {COL_A_PIXEL[3:0], PIC_A[3:0]} :
                 8'hff;
  end
end

endmodule
