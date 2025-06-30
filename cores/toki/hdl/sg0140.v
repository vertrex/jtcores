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

module sg0140(
  input [1:0] MODE,
  input clk, //n6m 

  //BK1 
  input [3:0] PIC_A, 
  //input     PIC_A_EN 6Mhz //enable color  ? 
  input [3:0] COL_A,  
  input       COL_A_EN,// LATCH PALETTE 
  input       MASK_A, // CLEAR COLOR ? 

  // CHAR
  input [3:0] PIC_B,
  //input     PIC_B_EN 6Mhz //enable color  ? 
  input [3:0] COL_B,
  input       COL_B_EN,   // LATCH PALETTE 
  input       MASK_B, //CLEAR COLOR ? 

  output reg  ON_A, //pin 8 
  output reg  ON_B, //pin 7

  output reg  [7:0] Q 
); 

//  00   bk1 0 char 0 (e)
//  01   bk1 1 char 0 (8)   
//  10   bk1 0 char 1 (4)
//  11   bk1 1 char 1 (4) //char > bk1 so ok

reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH; 

always @(posedge clk) begin 
  if (COL_B_EN)
     COL_B_LATCH[3:0] <= COL_B[3:0];

  if (COL_A_EN)
     COL_A_LATCH[3:0] <= COL_A[3:0];

  ON_A <= PIC_A[3:0] == 'hf ? 1'b0 : 1'b1;
  ON_B <= PIC_B[3:0] == 'hf ? 1'b0 : 1'b1;

  Q[7:0] <= PIC_B[3:0] != 'hf ?  {COL_B_LATCH[3:0], PIC_B[3:0]} :
                                 {COL_A_LATCH[3:0], PIC_A[3:0]};
end

endmodule
