module hypos(
  input    [15:0] MDB,
  input     [1:0] FDA,
  input           RDCLK,
  input           OIBDIR,
  //input         POS_8,
  //input         CARY_M,
  //input         XC4, 
  input           BUSAK,
  input           OBUSRQ,
  //ouput 
  //
  output    [8:0] ND2,//XXX
  output          OBUSAK,
  output
  [15:0] OBJ_DB,
  output          HREYD,
  output          VREYD,
  output          SPR1,
  output          SPR2,
  output          OBJEN,
  //output    XC4,
  output  [4:0]   ND1,

  input           XOBDIR


);

//74LS244P 10J 
//74LS22P 19J
//both are bus driver with enable = 1
assign OBJ_DB[15:0] = MDB[15:0]; 

//PLD25 
// XXX 
wire ORIGIN; 

wire CTRL_LT, RD_VPOS, RD_HPOS, LT_VPOS, LT_HPOS, ND2_8, RD_CHAR;

PLD25 pld25_u(
    FDA_1(FDA[0]), //0 or 1 ???
    FDA_2(FDA[1]),
    RDCLK(RDCLK),
    ORIGIN(ORIGIN),
    OIBDIR(OIBDIR),
    POS_8(), //XXX 
    CARY_M(), //XXX loop from other 
    XC4(), // XXX 
    BUSAK(BUSAK),
    OBUSRQ(OBUSRQ),

    CTRL_LT(CTRL_LT),
    RD_VPOS(RD_VPOS),
    RD_HPOS(RD_HPOS),
    LT_VPOS(LT_VPOS),
    LT_HPOS(LT_HPOS),
    ND2_8(ND2_8),
    OBUSAK(OBUSAK),
    RD_CHAR(RD_CHAR)
);

//74LS174 U134  
reg OBJEN_1, SPR2_1, SPR1_1, YVRED_1, HREVD_1;

always @(posedge CTRL_LT or negedge XOBDIR) begin
    if (!XOBDIR)
        { OBJEN_1, ORIGIN, SPR2_1, SPR1_1, YVRED_1, HREVD_1} <= 6'b000000;   // asynchronous clear
    else
        // MAME IS A BIT WRONG FOR THAT WE MAY WANT TO EXPLAIN AND CORRECT IT ?
        //15        /13    /11      /10    /9       /8 (flipx)
        { OBJEN_1, ORIGIN, SPR2_1, SPR1_1, YVRED_1, HREVD_1} <= { OBJ_DB[15], OBJ_DB[13], OBJ_DB[11:8] }; 
end

//74LS173 9H
//74LS173 10H 

//OFFSET X or OFFSET Y ! 
//mame is exact : offset y [3:0]  offset x [7:4]
wire   [3:0] OFST;
assign OFST[3:0] = ~RD_VPOS ? OBJ_DB[3:0] : RD_HPOS ? OBJ_DB[7:4] : 4'b00;

//74F841 11H 

//74F841 12H 

//74F827 13H

//74F283 14H 

endmodule 
