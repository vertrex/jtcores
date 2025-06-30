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
  input [3:0] COL_A,  
  input       EN_A,// S1 CLLT hpos 0
  input       MASK_A, // ? S1MASK page 3 address selection   bk2 select ? 

  // CHAR
  input [3:0] PIC_B,
  input [3:0] COL_B, 
  input       EN_B, //? S4CLLT T8H 
  input       MASK_B, // S4MASK ? char_cs ?  page 3 address selection 

  output reg  ON_A, //pin 8 
  output reg  ON_B, //pin 7

  output      [7:0] Q 
); 

//it seem sg0140 get other input like clk from other module like bk 1 output
//scroll pos0 etc 
//it certainly do other stuff like partial mixing
//


//always @(posedge clk) begin 
  //met pri a 1 si un des deux et differ de hf ?
  //if (EN_B)
//always @(posedge EN_B)
    //char_latch[7:0] <= {COL_B[3:0], PIC_B[3:0]};

//always @(posedge EN_A)
  //if (bk_en)
    //bk_latch[7:0] <= {COL_A[3:0], PIC_A[3:0]};

//  00   bk1 0 char 0 (e)
//  01   bk1 1 char 0 (8)   
//  10   bk1 0 char 1 (4)
//  11   bk1 1 char 1 (4) //char > bk1 so ok
//
reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH; 

always @(posedge clk) begin 
  if (EN_B)
     COL_B_LATCH[3:0] <= COL_B[3:0];

  if (EN_A)
     COL_A_LATCH[3:0] <= COL_A[3:0];
    //char_latch[7:0] <= {COL_B[3:0], PIC_B[3:0]};

  ON_A <= PIC_A[3:0] == 'hf ? 1'b0 : 1'b1;
  ON_B <= PIC_B[3:0] == 'hf ? 1'b0 : 1'b1;

  Q[7:0] <= PIC_B[3:0] != 'hf ?  {COL_B_LATCH[3:0], PIC_B[3:0]} :
                                 {COL_A_LATCH[3:0], PIC_A[3:0]};
end

//assign Q[7:0] = ON_B ?  {COL_B[3:0], PIC_B[3:0]} :
                        //{COL_A[3:0], PIC_A[3:0]};

endmodule
