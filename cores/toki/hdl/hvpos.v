/*
*  THIS MODULE DECODE OBJ COORDINATE / POS OFFSET 
*  IF OBJ IS USED ...
*  XXX DOCUMENT THAT 
*/
module HVPOS(
  input           clk,
  input    [15:0] MDB,
  input     [2:1] FDA,
  input           RDCLK,
  input           OIBDIR,
  input           BUSAK,
  input           OBUSRQ,
  input           XOBDIR,
  //ouput 
  output    [8:0] ND2,     // Nibble data 2 (Y[8:4])
  output          OBUSAK,
  output   [15:0] OBJ_DB,
  output          HREVD_1,
  output          VREVD_1,
  output          SPR1_1,
  output          SPR2_1,
  output          OBJEN_1,
  output  [3:0]   ND1,     // Nibble data 1 (Y[3:0]) 
  output          RD_VPOS  // Read vertical position
);

//74LS244P 10J 
//74LS22P 19J
//both are bus driver with enable = 1
assign OBJ_DB[15:0] = MDB[15:0]; 

//PLD25 
wire ORIGIN;
wire CTRL_LT; // Control latch (latch sprite attribute : palette, flip, priority)
wire RD_HPOS; // Read Horizontal position 
wire LT_VPOS; // Latch vertical position 
wire LT_HPOS; // Latch horizontal position
wire RD_CHAR; // Read char 
wire CARY_M;
wire XC4;     // X clock, 4 bit counter

PLD25 pld25_u(
    .FDA(FDA[2:1]), //0 or 1 ???
    .RDCLK(RDCLK),
    .ORIGIN(ORIGIN),
    .OIBDIR(OIBDIR),
    .POS_8(POS[8]),
    .CARY_M(CARY_M), //XXX loop from other 
    .XC4(XC4), // XXX 
    .BUSAK(BUSAK),
    .OBUSRQ(OBUSRQ),

    .CTRL_LT(CTRL_LT),
    .RD_VPOS(RD_VPOS),  // page 14 objdma
    .RD_HPOS(RD_HPOS),
    .LT_VPOS(LT_VPOS),
    .LT_HPOS(LT_HPOS),
    .ND2_8(ND2[8]),
    .OBUSAK(OBUSAK),
    .RD_CHAR(RD_CHAR)
);

//74LS174 U134  
LS174 u134(
  .CLK(clk),
  .CLRn(XOBDIR),
  .CEN(CTRL_LT),
  .D({ OBJ_DB[15], OBJ_DB[13], OBJ_DB[11:8] }),
 // MAME IS A BIT WRONG FOR THAT WE MAY WANT TO EXPLAIN AND CORRECT IT ?
 //15        /13    /11      /10    /9       /8 (flipx)
  .Q({OBJEN_1, ORIGIN, SPR2_1, SPR1_1, VREVD_1, HREVD_1})
);

//74LS173 9H
//74LS173 10H 
wire [8:0] POS;

//XXX COMBINE ALL TOGETHER ? 

//OFFSET X or OFFSET Y ! 
//mame is exact : offset y [3:0]  offset x [7:4]
reg [3:0] OFST;

always @(posedge clk) begin 
  if (CTRL_LT)                                                  // XXX 4'b0 or RD_VPOS ? 
    OFST[3:0] <= ~RD_VPOS ? OBJ_DB[3:0] : ~RD_HPOS ? OBJ_DB[7:4] : 4'b0;
end 

//74F841 11H 
reg [9:0] H11_qreg;

always @(posedge clk) begin //@* originally
    if (LT_HPOS) // & RDCLK ? 
      H11_qreg <= {1'b1, OBJ_DB[8:0]};
    end

//assign {CARY_M, POS[8:4], ND2[3:0]} = (!RD_HPOS) ? H11_qreg : 10'b00000000;
//assign ND2[3:0] = (!RD_HPOS) ? H11_qreg[3:0] : 4'b0;
//assign POS[8:4] = (!RD_HPOS) ? H11_qreg[8:4] : 5'b0;
//assign CARY_M = (!RD_HPOS) ? H11_qreg[9] : 1'b0;

//74F841 12H 

reg [9:0] H12_qreg;

always @(posedge clk) begin //@* origina.ly
    if (LT_VPOS)  // & RDCLK ?
      H12_qreg <= {1'b1, OBJ_DB[8:0]};
    end

//assign {CARY_M, POS[8:4], ND1[3:0]} = (!RD_VPOS) ? H12_qreg[3:0] : 10'b00000000;

assign ND1[3:0] = (!RD_VPOS) ? H12_qreg[3:0] : 4'b0;
//assign POS[8:4] = (!RD_VPOS) ? H12_qreg[8:4] : 5'b0;
assign POS[8:5] = (!RD_HPOS) ? H11_qreg[8:5] : (!RD_VPOS) ? H12_qreg[8:5] : OBJ_DB[8:5];
assign POS[4] = (!RD_HPOS) ? H11_qreg[4] : (!RD_VPOS) ? H12_qreg[4] : (!RD_CHAR) ? OBJ_DB[4] : 1'b0;

//assign CARY_M = (!RD_VPOS) ? H12_qreg[9] : 1'b0;
//74F827 13H

////OE assign ot 1
//assign {POS[4], ND2[3:0]} = (!RD_CHAR) ? OBJ_DB[4:0] : 5'b0;
//assign ND2[3:0] = (!RD_CHAR) ? OBJ_DB[3:0] : 4'b0;

assign ND2[3:0] = (!RD_CHAR) ? OBJ_DB[3:0] : (!RD_HPOS) ? H11_qreg[3:0] : 4'b0; 
//assign POS[4] = (!RD_CHAR) ? OBJ_DB[4] : 1'b0;

//assign {CARY_M, POS[8:5]} = OBJ_DB[9:5];
//assign POS[8:5] = OBJ_DB[8:5];
//assign CARY_M = OBJ_DB[9];

assign CARY_M = (!RD_HPOS) ? H11_qreg[9] : (!RD_VPOS) ? H12_qreg[9] : OBJ_DB[9];

//74F283 14H 
assign {XC4, ND2[7:4]} = {3'b0, CARY_M} + POS[7:4] + OFST[3:0];


endmodule 
