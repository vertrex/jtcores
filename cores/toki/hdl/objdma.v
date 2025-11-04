/** 
*
* This module handle object (sprite) DMA 
* It incrementaly goes through all main CPU RAM address from: 
* 0x6c00  to 0x6fff (1024) (0x36c00 to 0x36fff if we had ram offset for the CPU which start at 0x3000)
* and copy the output MDB through the HVPOS module
* copy start when XOBDIR is set to 1
*
* XXX also send DMA2_EA & DMA2_OA to scndma ??
* copy DMA to this ram + the 3 ram of scndma while decoding in parallel via
* HVPOS ? 
*  then linecunt get data from scndma calculate intersection 
*  use objps to decode and get current pixel that are decode and send to
*  linebuf ?
*
*  then one line on the other the data from linebuffer is read and sent to the
*  screen ?
*/
module OBJDMA(
    input           clk,
    input           STARTV,
    input           VCLK,
    input           RDCLK,
    input           RD_VPOS,
    input   [10:1]  FDA,
    input    [3:0]  ND1,
    input    [8:4]  ND2,
    input           HREVD_1, //_1 ? 
    input           VREVD_1, //_1 ? 
    input           SPR1_1, //_1 
    input           SPR2_1, //_1 
    input           OBJEN_1, //_1 
    //input           ODH, //?
    //input           SPR1_1, out or bidir ? 
    //input           SPR2_1,  out  or bidir ?
    input           DMLD, 
    input           VFIND,
    input           ODMARQ,
    input           OBUSAK,
    input           VORIGIN,
    input     [8:0] H_POS, 
    input           VREV,
    input           NV256,
    input           H_128,
    input           H_256,
    input           V1, //? 
    //output 
    output          MATCHV,
    output          XOBDIR,
    output          RAM2VLD,
    output   [10:1] FDA_OUT,
    output   [15:1] MAB_OUT, 
    output          DMARD,
    output    [3:0] VMT,
    output          EVNWR2, 
    output          ODDWR2,
    output          OIBDIR,
    output          OBUSRQ,
    output          OBUSDIR,
    output    [5:0] DMA2_EA,
    output    [5:0] DMA2_OA
);

/// NOT DRIVEN TO DRIVE 
assign MATCHV = 1'b0;
assign XOBDIR = 1'b0;
assign RAM2VLD = 1'b0;
assign MAB_OUT[15:1] = 15'b0;
assign DMARD = 1'b0;
assign VMT[3:0] = 4'b0;
assign EVNWR2 = 1'b0;
assign ODDWR2 = 1'b0;
assign OIBDIR = 1'b0;
assign OBUSRQ = 1'b0;  
assign OBUSDIR = 1'b1; //active low ? 
assign DMA2_EA[5:0] = 6'b0;
assign DMA2_OA[5:0] = 6'b0;

wire [7:0] VPD;
wire ODH; 
wire VREVD_2; 
wire SPR1_2, SPR2_2;
//////////// 


wire SDTS, XSDTS;

LS74 u142(
   .CLK(clk),
   .CEN(VCLK),
   .D(STARTV),
   .PRE(1'b1),
   .CLR(1'b1),
   .Q(SDTS),
   .QN(XSDTS)
);

wire LSBLD;

LS161 u143(
    .clk(clk),
    .rst(XOBDIR), //XXX == clr 
    .CEN(RDCLK),
    .LOAD_n(LSBLD),
    .ENP(1'b1),
    .ENT(1'b1),
    .D({1'b0, 1'b1, 1'b0,1'b0}),
    .Q({FDA_OUT[2], FDA_OUT[1]}), //2NC
    .RCO()//NC
);

wire OBJEN_2;
wire OBJEN_3; 
wire MSBLD;
wire MSBET; 
wire ILD2; 
wire OVER256;

PLD24 u_pld24(
   .FDA_1(FDA[1]),
   .FDA_2(FDA[2]),
   .SDTS(SDTS),
   .DMLD(DMLD),
   .OIBDIR(OIBDIR),
   .OVER256(OVER256),
   .INSCRN(INSCRN),
   .OBJEN_2(OBJEN_2),
   .VFIND(VFIND),
/// 
   .MATCHV(MATCHV),
   .OBJEN_3(),
   .LSBLD(LSBLD),
   .XOBDIR(XOBDIR),
   .RAM2VLD(RAM2VLD),
   .MSBLD(MSBLD),
   .MSBET(MSBET),
   .ILD2(ILD2)
);

wire [1:0] NC;
wire INSCRN;

sis6091 u_141(
  .clk0(clk),
  .cen0(RDCLK),
  .data0({2'b0, OBJEN_1,SPR2_1, SPR1_1,VREVD_1, HREVD_1,ND2[8:4] , ND1[3:0]}),
  .addr0({2'b0, FDA[10:3]}),
  .we0({RD_VPOS, RD_VPOS}),
  .q0(),

  .clk1(clk),
  .cen1(),
  .data1(),
  .addr1(), 
  .we1({1'b0, 1'b0}),
  .q1({NC[1:0], OBJEN_2, SPR2_2, SPR1_2, VREVD_2, ODH, INSCRN ,VPD[7:0]}) //xxx check that
);

wire TC;
wire Q_144;

LS74 u144(
    .CLK(clk),
    .CEN(RDCLK),// Clock input
    .D(TC), // Data inputs
    .PRE(1'b1), // Preset inputs (active low)
    .CLR(1'b1), // Clear inputs (active low)
    .Q(Q_144), // Flip-flop outputs
    .QN() // Inverted flip-flop outputs
);

wire Q_146;

LS74 u146(
    .CLK(clk),
    .CEN(RDCLK),// Clock input
    .D(MSBLD), // Data inputs
    .PRE(1'b1), // Preset inputs (active low)
    .CLR(1'b1), // Clear inputs (active low)
    .Q(Q_146), // Flip-flop outputs
    .QN() // Inverted flip-flop outputs
);

wire Q_148;

LS74 u148(
    .CLK(clk),
    .CEN(1'b0),// Clock input
    .D(1'b0), // Data inputs
    .PRE(Q_144), // Preset inputs (active low)
    .CLR(Q_146), // Clear inputs (active low)
    .Q(Q_148), // Flip-flop outputs
    .QN(OVER256) // Inverted flip-flop outputs
);

//74F268 //269 ??? XXX 
// DMA COUNTER ? 8bits !
// output fda {FDA[10:3], 2'b11} => {DMARD, MAB[15:1]} 
// 256 value au final calculer les addresses reel 
// car en sortie des 2 bus driver 
ttl_74F269 u147(
    .CP(RDCLK),  //goes out from QUADBUFFER XXX 74LS244 which is not yet impl but it's justu a buffer
    .PE_n(MSBLD),     // Parallel Enable (active LOW) -> charge quand 0
    .CEP_n(MSBET),    // Count Enable Parallel (active LOW)
    .CET_n(Q_148),    // Count Enable Trickle (active LOW)
    .U_D(1'b1),      // Up/Down control: 1 = UP, 0 = DOWN
    .P(8'b0),        // Parallel data inputs P0..P7
    .Q(FDA_OUT[10:3]),        // Outputs Q0..Q7
    .TC_n(TC)      // Terminal Count (active LOW)
);

//74LS244P u149 16J 
//74LS244P u1418 15J 

// 011011??_????????  
// 0x6c00 - 0x6fff = 1024 * 2 (16bits) => 2048 => 1 sis6091 2**10 *2
//
// !!!>> hex(0b1101100_00000000)
//'0x6c00' !!!
//>>> bin(0x36c00)
//'0b11_01101100_00000000'
//obj_cs     = ~cpu_as_n & (cpu_a[23:1] >= 23'h36c00 && cpu_a[23:1] < 23'h37000);
assign {DMARD, MAB_OUT[15:1]} = !OIBDIR ? { 6'b011011 , FDA_OUT[10:1]} : {16'b0};

//2x SG0140 special mode !
// XXX easier to create an other sg0140 ? 
sg0140 u1411(
  .clk(),
  .cen(), 
  .MODE(),

  //BK1 
  .PIC_A(), 
  //input     PIC_A_EN 6Mhz //enable color  ? 
  .COL_A(),  
  .COL_A_EN(),// LATCH PALETTE 
  .MASK_A(), // CLEAR COLOR ? 

  // CHAR
  .PIC_B(),
  //input     PIC_B_EN 6Mhz //enable color  ? 
  .COL_B(),
  .COL_B_EN(),   // LATCH PALETTE 
  .MASK_B(), //CLEAR COLOR ? 

  //out 
  .ON_A(), //pin 8 
  .ON_B(), //pin 7
  .Q() 
);

// XXX easiter to create an other sg0140 impl ?
sg0140 u1412(
  .clk(),
  .cen(), 
  .MODE(),

  //BK1 
  .PIC_A(), 
  //input     PIC_A_EN 6Mhz //enable color  ? 
  .COL_A(),  
  .COL_A_EN(),// LATCH PALETTE 
  .MASK_A(), // CLEAR COLOR ? 

  // CHAR
  .PIC_B(),
  //input     PIC_B_EN 6Mhz //enable color  ? 
  .COL_B(),
  .COL_B_EN(),   // LATCH PALETTE 
  .MASK_B(), //CLEAR COLOR ? 

  //out 
  .ON_A(), //pin 8 
  .ON_B(), //pin 7
  .Q() 
);

//74LS244 u1413 22K
// XXX IMPL THAT out goes tothe counter 269  
//assign Y1_4 = (!OE1_n) ? A1_4 : 4'bz;  // Tri-state si OE1_n = 1
//assign {RDCLK_, OBUSDIR ,OBUSRQ, OIBDIR} can assign directly to sg0140
//output

endmodule
