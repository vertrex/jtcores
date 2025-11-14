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

//sg0140_absel 
module sg0140(
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

  output reg  ON_A, //pin 8 
  output reg  ON_B //pin 7
); 

//  00   bk1 0 char 0 (e)
//  01   bk1 1 char 0 (8)   
//  10   bk1 0 char 1 (4)
//  11   bk1 1 char 1 (4) //char > bk1 so ok

reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH; 

always @(posedge clk) begin 
  if (cen) begin 
    if (COL_B_EN)
       COL_B_LATCH[3:0] <= COL_B[3:0];

    if (COL_A_EN)
       COL_A_LATCH[3:0] <= COL_A[3:0];

    ON_A <= (PIC_A[3:0] == 4'hf) ? 1'b0 : 1'b1;
    ON_B <= (PIC_B[3:0] == 4'hf) ? 1'b0 : 1'b1;

    Q[7:0] <= PIC_B[3:0] != 'hf ?  {COL_B_LATCH[3:0], PIC_B[3:0]} :
                                   {COL_A_LATCH[3:0], PIC_A[3:0]};
  end
end

endmodule

///////////////////////////////////////////////////
///////////// SG0140 OHMAX ////////////////////////
///////////////////////////////////////////////////

// MODE == 11 OHMAX   ? 

//sg0140_absel 
module sg0140_ohmax(
  input       clk,
  input       rst, //pin 40
  input       cen,
  input [1:0] MODE,

  input [5:0] D, 
  input HREV, //pin 3 (MASK_A ?)
  input A_EN, //pin 38 //
  input B_EN, //pin 39 //PIC_A_EN (6mhz)
  

  output reg [10:0] Q 

  

//  output reg  ON_A, 
//  output reg  ON_B, 
); 

always @(posedge clk or posedge rst)
  if (rst)
    Q <= 11'b0;
  else 
    Q <= { D[5:0], D[4:0]};

endmodule

///////////////////////////////////////////////////
///////////// SG0140 VCHECK ///////////////////////
///////////////////////////////////////////////////

module sg0140_vcheck(
  input             clk,
  input             rst, //pin 40
  input       [7:0] VPD,      //
  input             ODMARQ,   // 
  input             OBUSAK,   // ? 
  input             SDTS,     //? 
  input             VORIGIN,  // ? 
  input             OVER256,  // vpos >256 ? ou hpos ?  ~nv256 ? 
  input             OVER48,   //48*8 => 384 (hpos max) 224 pix h ? 
  input             VREVD_2,  //? 
  input             OBJEN_3,  //? 
  input             H2,      //every 4 pixel ?  
  input             VCLK,    //6mhz ? 
  input             VREV,    // screen rev ?
  input             NV256,   // < hpos 256 pix ?
  //output 
  output reg  [3:0] VMT,
  output reg        EVNWR2,
  output reg        ODDWR2,
  output reg        OIBDIR,
  output reg        OBUSRQ
);

reg [19:0] UNUSED;

always @(posedge clk or posedge rst) begin 
  if (rst) begin 
    end 
  else if (clk) begin  //cen ? 
      VMT <= 4'b0; //XXX 
      EVNWR2 <= 1'b1; //XXX 
      ODDWR2<= 1'b1; //XXX 
      OIBDIR <= 1'b1; //XXX 
      OBUSRQ <= 1'b1;
  end

  UNUSED <= {NV256, VREV, VCLK, H2, OBJEN_3, VREVD_2, OVER48, OVER256, VORIGIN, SDTS, OBUSAK, ODMARQ, VPD[7:0]}; 

end 


endmodule

///////////////////////////////////////////////////
///////////// SG0140 SORT 40///////////////////////
///////////////////////////////////////////////////

module sg0140_sort40(
  input       clk,
  input       rst //pin 40
  //input       cen,
  //input [1:0] MODE,

  //input [5:0] D, 
  //input HREV, //pin 3 (MASK_A ?)
  //input A_EN, //pin 38 //
  //input B_EN, //pin 39 //PIC_A_EN (6mhz)
  

  //output reg [10:0] Q 
);



endmodule 
