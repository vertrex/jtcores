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
    input             clk,
    input             rst,
    input             STARTV,
    input             VCLK,
    input             RDCLK,
    input             RD_VPOS,
    //input   [10:1]  FDA,
    input      [3:0]  ND1,
    input      [8:4]  ND2,
    input             HREVD_1, //_1 ? 
    input             VREVD_1, //_1 ? 
    input             SPR1_1, //_1 
    input             SPR2_1, //_1 
    input             OBJEN_1, //_1 
    input             DLHD, 
    input             ODMARQ,
    input             OBUSAK,
    input             VORIGIN,
    input       [8:0] H_POS, 
    input             VREV,
    input             NV256,
    input             H_128,
    input             H_256,
    input             V1, //? 
    //output 
    output            MATCHV, // == NOOBJ 
    output            XOBDIR,  //~OIBDIR 
    output            RAM2VLD,
    output     [10:1] FDA,
    output            DMARD,
    output      [3:0] VMT,
    output            EVNWR2, 
    output            ODDWR2,
    output            OIBDIR,  //~XOBDIR
    output            OBUSRQ,
    output            OBUSDIR,
    output      [5:0] DMA2_EA,
    output      [5:0] DMA2_OA,
    output            ODH, // == ODHREV
    output            SPR1_2, 
    output            SPR2_2
);

wire [7:0] VPD;
wire VREVD_2; 
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
wire [1:0] NC2;

LS161 u143(
    .clk(clk),
    .rst(XOBDIR), //XXX == clr ?  
    .CEN(RDCLK),
    .LOAD_n(LSBLD), 
    .ENP(1'b1),
    .ENT(1'b1),
    .D({1'b0, 1'b1, 1'b0,1'b0}),
    .Q({NC2[1:0], FDA[2], FDA[1]}), //2NC
    .RCO()//NC
);

wire OBJEN_2;
wire OBJEN_3; 
wire MSBLD;
wire MSBET; 
wire ILD2; 
wire OVER256;
wire VFIND;
wire INSCRN;

PLD24 u_pld24(
   .FDA_1(FDA[1]),
   .FDA_2(FDA[2]),
   .SDTS(SDTS),
   .DLHD(DLHD),
   .OIBDIR(OIBDIR),
   .OVER256(OVER256),
   .INSCRN(INSCRN),
   .OBJEN_2(OBJEN_2),
   .VFIND(VFIND),
/// 
   .MATCHV(MATCHV), // ==NOOBJ 
   .OBJEN_3(OBJEN_3),
   .LSBLD(LSBLD),
   .XOBDIR(XOBDIR),
   .RAM2VLD(RAM2VLD),
   .MSBLD(MSBLD), //start dma counter Memory Start B? Load ?
   .MSBET(MSBET),
   .ILD2(ILD2)
);

wire [1:0] NC;

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

/** 
*  Obj DMA genreate FDA[10:3] addr to copy obj from cpu ram to sis6091 
*/ 

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
    .D(MSBLD), // Data inputs   //START DMA COUNTER ? 
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
    .Q(FDA[10:3]),        // Outputs Q0..Q7
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
//impl directly in main.v !  XXX exlain that in MAIN_V ! 
//assign {DMARD, MAB_OUT[15:1]} = !OIBDIR ? { 6'b011011 , FDA[10:1]} : {16'b0};
assign DMARD = !OIBDIR ? 1'b0 : 1'b1; //z ? 


// check if sprite intersect with current line ? 
// sprite is 16x16 
// 
wire OVER48;

//2x SG0140 special mode !
// XXX easier to create an other sg0140 ?
//

//FIRST SG0140 GENERATE DATA  : VMT that is stored with other dataq like FDA
//(generated one by one by the DMA counter) 
//to address generated by the second sg0140 
//
//vmt become VA1,VA2, ... which is use in linecunt  as u175_q 
//so part of the  entry of rom address   it has 16 value so certainly some
//pixel related value it's the low 
//
//in sprite we have rom_index[12:0] *64 so {rom_index[12:0], 000000}  13+6 => 19 we have [19:1] so it look ok 

//gfx_rom_addr[19:1] <= rom_index[12:0]*19'd64 + (({11'b0, line_number} - {10'b0, y})*19'd2) + ({17'b0, rom_words_index});
// {rom_index[12:0], 0 0000 0 }  (vmt /va is at the end after vh4 we have only  18:1 on the board as rom is split in two 

// the other part we do line_number -y*2 (y is the current pos but we check
// we're more or less at 16 from current line number  and we multiply by 2 so
// we shift by 1  
//
// so it's actually : 
//
// {rom_index[12:0], 0, line_number-y%16, 0 } 
//
// the last 0 is determined by rom_words_index so we now if talke first or
// second so last byte is rom_words_index 
//
//
// {rom_index[12:0], 0, line_number-y%16, rom_words_index  } 
// then we have a *32 because before the two rom a consecutive and we need to
// choose which one here is 
// bin(32)
 // '0b1 0000 0'
 //  so it's the lacking bit  
 //  {rom_index[12:0], rom_words_index, line_number-y%16, rom_words_index } 
 //  so THIS SG140 IS TO CALCULATE line_number-y%16 and know which pixel the
 //  line intersect !!!!!!!!!!!!!!!!!!!!!!!!!!!!!! solved ! 
 //wire VH4 = ~hpos[2] ^ OPSREV; 
 //wire VH8 = hpos[3] ^ ~hpos[2] ^ OPSREV;
// {rom_index[12:0], VH8, line_number-y%16, VH4 } 
// {rom_index[12:0], VH8, VTM, VH4 } 

// {rom_index[12:0], VH8  VTM[3:0]/VA*  , VA4
//  174_q[3:0],ADDR,174_Q[3:0]                    VH8,  0000        0
//  so addr is rom_index 
// 174_Q ==  172_Q[0]     171_q[5:0] 
//  172_Q[0] + ADDR + 171_Q[5:0] 
//  OVD[11]  + addr? + OVD[10:9] OVD[3:0] 
//   add is got by an sg0140 by getting OVD 
//   original code ram-words[2][15], ram_words[1][11:0] 
//   so is OVD ram_words ? OVD is OBJ_DB so is MDA so it's ram_words 
//   it's just not [15] bthe other seems to be partially from ram too OVD ...
//   but addr is a different part 
//  
//  the other 

//
//
//
//scndma entry is address of second sg0140 data of first 
//so we can see both as a splitted stuff to create 
//what is stored in scndma ram 


// THIS SG0140 calculate line_number-y%16 
// it let know which line of the 16x16 pixel we want 
// for that we actually need the pixel Y pos 
// and the current line number 
// or the current address as it's buffered ? 
// do we really get aht or is the calcul here more complexe ???? 
// in my code to calcualte Y[8:0] I used this code ... 
// y[8:0] <= ram_words[3][8:0] + (ram_words[0][3:0] * 8'd16);
// so we do 
// {ram_words[0][3:0], 0000} + ram_words[3][8:0] // maybe the low part is only
// needed ? 
// so ram-words[0] is ND2 and the other part is ND1 ? 
// which make the VPD ? but it lack one bits ... is that over256 or nv256 ? 
// {NV256, ND2[], ND1[] } 
// then we still need to substract current lione number or address .... 
//  does the other sg0140 play a role here ? 
// need to check at which moment we get the line number ... via vpos ?
// but never pass sei050bu vpos ... so I don't really get how we know 
// our posiution...

//from hvpos ND2 == offset 
//does that is synchronze to get the line number ? 
//it ocund line itself with the @clk, and vclk, vorigin ? sdts ? 
//then it cound 4 bits to be able to know which line ? 
//and synchronize itself ? 
//maybe all the clocking is only to count line 

sg0140_vcheck u1411(
  .clk(clk),
  .rst(rst),
  .VPD(VPD[7:0]), // {ND2[8:4], ND1[3:0]} //ND2 OFFS y (some time x some time y ?)  
  .ODMARQ(ODMARQ),
  .OBUSAK(OBUSAK),
  .SDTS(SDTS),
  .VORIGIN(VORIGIN),
  .OVER256(OVER256),  
  .OVER48(OVER48), //??
  .VREVD_2(VREVD_2),  // sprite 1 or sprite 2 (to know to which ram send it ?)
  .OBJEN_3(OBJEN_3), //obj metadata sprite valid ? 
  .H2(H_POS[2]),
  //.SW(1'b0),
  .RDCLK(RDCLK),
  .VCLK(VCLK),
  .VREV(VREV),
  .NV256(NV256),
  //output 
  .VMT(VMT[3:0]), // == VA1,2,3,4 address oj obj  in ROM  
  .EVNWR2(EVNWR2),  // enable other sg0140 DMA2_EA 
  .ODDWR2(ODDWR2),  //enable other sg0140 DMA2_OA 
  .OIBDIR(OIBDIR), //change bus dir to activate dma? 
  .OBUSRQ(OBUSRQ), //addres bus request to activate dma ?
  .VFIND(VFIND)  //activate other SG140 
);
//74LS244 u1413 22K
// XXX IMPL THAT out goes tothe counter 269  
//assign Y1_4 = (!OE1_n) ? A1_4 : 4'bz;  // Tri-state si OE1_n = 1
//assign {RDCLK_, OBUSDIR ,OBUSRQ, OIBDIR} can assign directly to sg0140
//output

assign OBUSDIR = OIBDIR; // check that on board ?

// XXX easiter to create an other sg0140 impl ?
sg0140_sort40 u1412(
  .clk(clk),
  .rst(rst),
  //.cen(),
  .RDCLK(RDCLK),
  .VFIND(VFIND),
  .XSDTS(XSDTS),
  .ILD2(ILD2),
  .NH2(~H_POS[1]),
  .V1B(V1),
  .H2(H_POS[1]),
  .H2_2(H_POS[1]),
  .H16(H_POS[4]),
  .H32(H_POS[5]),
  .H64(H_POS[6]),
  .H128(H_POS[7]),
  .H256(H_POS[8]),

  .OVER48(OVER48), //activate other sg0140 
  .DMA2_EA(DMA2_EA),
  .DMA2_OA(DMA2_OA)
);

endmodule
