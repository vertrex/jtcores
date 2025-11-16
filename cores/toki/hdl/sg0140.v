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

  //input [5:0] D, 
  input NOOBJ,
  input [4:0] OVD,
  input HREV, //pin 3 (MASK_A ?)
  input CTLT1 , //pin 38 //
  input CTLT2, //pin 39 //PIC_A_EN (6mhz)
  
  //Q 
  output reg [8:4] OH ,
  output reg [4:0] ADDR,
  output reg NOOBJ_CT2
); 

always @(posedge clk or posedge rst) begin 
  if (rst) begin 
    OH <= 5'b0;
    ADDR  <= 5'b0;
    end 

  if (CTLT1)
    OH[8:4]  <= OVD[4:0]; 

  if (CTLT2)
    ADDR[4:0] <= OVD[4:0]; 

  if (CTLT2)
    NOOBJ_CT2 <= NOOBJ;
  //Q <= { NOOBJ_CT2, D[4:0], D[4:0]};
  end 
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
  output reg  [3:0] VMT, // == VA address of obj in rom (rom_words_index)  
  //address is 19:1 
  output reg        EVNWR2, // use DMA2_EA of other sg0140 ? 
  output reg        ODDWR2, // use DMA2_OA of other sg0140 in scndma

  output reg        OIBDIR,
  output reg        OBUSRQ,
  output reg        VFIND //update other sg140 to find next ? 
);

reg [19:0] UNUSED;

always @(posedge clk or posedge rst) begin 
  if (rst) begin 
    end 
  else if (VCLK) begin  //cen ? 
      //OUTPUT VMT (part of address in rom ) dpeending on other paramter 
      //make some calculus if ver256, have origin, bus 
      //is on etc . 
      //
      //if VPD > odd or evn ?
      //OBUSAK , SDTDS, VORIGIN, OVER256, OVER48 
      //OBJEN <VREVD, VREV TO CHECK 
      //if all is ok we can write ?

      if (~NV256 & ~ODMARQ) begin 
        if (H2 == 1'b1) begin 
          VMT <= VPD[3:0];  //ND1 [3:0 ]
          EVNWR2 <= 1'b0; 
          OIBDIR <= 1'b0; 
          VFIND <= 1'b0; 
          OBUSRQ <= 1'b0;
          end 
        else  begin 
          VMT <= VPD[7:4]; //ND2[8:4]
          ODDWR2 <= 1'b0;
          OIBDIR <= 1'b0; 
          VFIND <= 1'b0;
          OBUSRQ <= 1'b0; 
          end 
        end 

      else begin 
        EVNWR2 <= 1'b1; //active low  //XXX 
        ODDWR2<= 1'b1; //active low XXX 
        OIBDIR <= 1'b1; //XXX 
        OBUSRQ <= 1'b1;
        end 
  end
end 


endmodule

///////////////////////////////////////////////////
///////////// SG0140 SORT 40///////////////////////
///////////////////////////////////////////////////

module sg0140_sort40(
  input       clk,
  input       rst, //pin 40

  input   RDCLK, //main clk ? 

  // condition ? 
  //input   OVER48, //active high 
  input   VFIND,
  input   XSDTS,
  input   ILD2,
  input   NH2,  //~h_pos[1] 

  //clk & enable ? 
  input   V1B,  //vpos[0]
  input   H2,   // 38 A_EN ?  //h_pos[1]
  input   H2_2, //h_pos[1] EN ? 
  
  // 5 output signal do DMA2 ???? 
  input   H16,  //h_pos[4]
  input   H32,  //h_pos[5]
  input   H64,  //h_pos[6]
  input   H128, //h_pos[7]
  input   H256, //h_pos[8]
  
  output reg  OVER48,
  output reg  [5:0] DMA2_EA,
  output reg  [5:0] DMA2_OA
);


always @(posedge clk, posedge rst) begin 
  if (rst) begin 
      DMA2_EA <= 6'b0; 
      DMA2_OA <= 6'b0;
      end 
  else if (RDCLK) begin 
    if (~VFIND & ~XSDTS & ~ILD2) begin 
      if (V1B == 1'b1)  begin  //ligne impair  ? 
        DMA2_OA <= {H256, H128, H64, H32, H16, NH2}; 
        end 
      else begin 
        DMA2_EA <= {H256, H128, H64, H32, H16, NH2};
        end 
      OVER48 <= 1'b1; 
      end
    else 
      OVER48 <= 1'b0;
  end 

end 
  

endmodule 
