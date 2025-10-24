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
wire RD_VPOS;
wire RD_HPOS;


//74LS174 U134  
reg OBJEN_1, ORIGIN, SPR2_1, SPR1_1, YVRED_1, HREVD_1;
wire CTRL_LT;

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
wire   [3:0] OFST;
assign OFST[3:0] = ~RD_VPOS ? OBJ_DB[3:0] : RD_HPOS ? OBJ_DB[7:4] : 4'b00;

//74F841 11H 

//74F841 12H 

//74F827 13H

//74F283 14H 

endmodule 
