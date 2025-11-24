/**
*
*  Sprite generation subsystem : Fetch sprite attributes from main memory,
*  process them, fetch graphics data and output sprite pixel and priority via
*  a double line buffer
*/ 
module obj(
  input         clk,
  input         rst,

  input [15:0]  MDB_RAM_OUT,
  input [15:0]  MDB_CPU_OUT,
  input         BUSAK,
  input         STARTV,
  input         ODMARQ,
  input         VORIGIN,
  input  [8:0]  H_POS,
  input         VREV,  //reverse Y axis
  input         HBLB,
  input         T3F,
  input         T8H, 
  input         RESETA, 
  input         FIRST_LD,
  input         SECND_LD,
  input         CTLT1,
  input         CTLT2,
  input         EVN_LD,
  input         ODD_LD,
  input         NV256, //~V8
  input         VCLK,
  input         OBJ_P6M,
  input         OBJ_N6M,
  input         RDCLK,
  input         V1B,  //vpos[0] 
  input         D1V_2,  //V1B @hpos[1]
  input         OBJMASK, 
  input         HREV, 
  input         HD, 
  input         OBJT2_7,
  input         D1V_7,  //V1B @T8H
  input         OPSREV,
  input         VH4,
  input         VH8,
  input  [15:0] obj_rom_1_data,
  input         obj_rom_1_ok,
  input  [15:0] obj_rom_2_data,
  input         obj_rom_2_ok,
//output 
  output [18:1] obj_rom_1_addr,
  output        obj_rom_1_cs,
  output [18:1] obj_rom_2_addr,
  output        obj_rom_2_cs,
  output        OBUSDIR,
  output        OBUSRQ,
  output        OBJON,
  output [7:0]  OOD,
  output        PRIOR_C,
  output        PRIOR_D,
  output        OIBDIR,
  output [10:1] FDA,
  output        OBJ_HREV
);

//obj_cs     = ~cpu_as_n & (cpu_a[23:1] >= 23'h36c00 && cpu_a[23:1] < 23'h37000); //2048
wire XOBDIR, OBUSAK;
wire HREVD_1, VREVD_1, SPR1_1, SPR2_1, OBJEN_1;
wire [15:0] OBJ_DB;
wire [3:0]  ND1;

wire [8:0] ND2; // XXX ??????
wire       RD_VPOS;


////// Horizontal & Vertical position ///// 
// Sprite attribute decoder and latch 
// During objdma it read MDB to get and decode sprite information 
// (Position X, Y, tile code, color, flip, ...) 
// and send that data to the objdma module  
HVPOS hvpos_u(
    .clk(clk),
    .MDB(MDB_CPU_OUT[15:0]), // XXX RAM OR CPU READ ?
    .FDA(FDA[2:1]),
    .RDCLK(RDCLK),
    .OIBDIR(OIBDIR),
    .BUSAK(BUSAK),
    .OBUSRQ(OBUSRQ),
    .XOBDIR(XOBDIR),
    //output 
    .ND2(ND2[8:0]), //{OBJ POS + OFFSET,  ??} 
    .OBUSAK(OBUSAK),
    .OBJ_DB(OBJ_DB[15:0]), //OBJ_DB = MDB_OUT it's just a driver 
    .HREVD_1(HREVD_1),  //sprite flip x 
    .VREVD_1(VREVD_1),  // ? 
    .SPR1_1(SPR1_1),   //? SPR1[0] or [1] ? 
    .SPR2_1(SPR2_1),   //?  
    .OBJEN_1(OBJEN_1), //skip or enable sprite  
    .ND1(ND1[3:0]), // ? 
    .RD_VPOS(RD_VPOS)
); 

wire MATCHV;
wire OBNE, ODH, SPR1_2;
wire RAM2VLD;
//wire DMARD;
wire [3:0] VMT;
wire EVNWR2, ODDWR2;
wire [5:0] DMA2_EA;
wire [5:0] DMA2_OA;
wire SPR2_2; 
wire DLHD;
//////////////////////////////////////



/////////// SPRITE DMA & VISBILITY CHECK ////////// 
//  At start (STARTV/ODMARQ), take control of memory bus 
//  Scan the object in main RAM (sprite X, Y, code, color, flip attributes)
//  Filter sprite using sg0140 vheck, to determine which one are visible on 
//  current scanline 
OBJDMA objdma_u(
    .clk(clk),
    .rst(rst),
    .STARTV(STARTV),
    .VCLK(VCLK),
    .RDCLK(RDCLK),
    .RD_VPOS(RD_VPOS),
    .ND1(ND1[3:0]),
    .ND2(ND2[8:4]),
    .HREVD_1(HREVD_1), //_1 ? 
    .VREVD_1(VREVD_1), //_1 ? 
    .SPR1_1(SPR1_1), //_1 
    .SPR2_1(SPR2_1), //_1 
    .OBJEN_1(OBJEN_1), //_1 
    .DLHD(DLHD), 
    .ODMARQ(ODMARQ),
    .OBUSAK(OBUSAK),
    .VORIGIN(VORIGIN),
    .H_POS(H_POS[8:0]), 
    .VREV(VREV),
    .NV256(NV256), //V[8] ? or ~V[8] ?
    .H_128(H_POS[7]), //H[7] ? 
    .H_256(H_POS[8]),//h[8]?
    .V1(1), //? //V_POS ?  
    //output 
    .MATCHV(MATCHV),
    .XOBDIR(XOBDIR),
    .RAM2VLD(RAM2VLD),
    .FDA(FDA[10:1]),
    //.DMARD(DMARD),
    .VMT(VMT[3:0]),
    .EVNWR2(EVNWR2), 
    .ODDWR2(ODDWR2),
    .OIBDIR(OIBDIR),
    .OBUSRQ(OBUSRQ),
    .OBUSDIR(OBUSDIR),
    .DMA2_EA(DMA2_EA[5:0]),
    .DMA2_OA(DMA2_OA[5:0]),
    .ODH(ODH),
    .SPR1_2(SPR1_2),
    .SPR2_2(SPR2_2)
);

wire NOOBJ, ODHREV, SPR1_3, SPR2_3;
wire [15:0] OVD;
wire [3:0] VA;

////// Secondary buffering /// 
// Attributes of the visibile sprite found by the DMA are stored in
// intermidate memory 
// This create a display list containing only the sprite relevant to the line 
// being rendered 
SCNDDMA scnddma_u(
    .clk(clk),
    .FDA(FDA[10:2]),
    .VMT(VMT[3:0]),
    .ODH(ODH),
    .EVNWR2(EVNWR2),
    .DMA2_EA(DMA2_EA[5:0]),
    .XOBDIR(XOBDIR),
    .D1V_2(D1V_2),
    .DMA2_OA(DMA2_OA[5:0]),
    .ODDWR2(ODDWR2),
    .RAM2VLD(RAM2VLD),
    .RDCLK(RDCLK),
    .H1(H_POS[0]), //HPOS_ 1 ??
    .OIBDIR(OIBDIR),
    .ND2(ND2[8:0]),
    .OBJ_DB(OBJ_DB[15:9]),
    .SPR2_2(SPR2_2),
    .SPR1_2(SPR1_2),
    .MATCHV(MATCHV),
    //output 
    .OVD(OVD[15:0]),
    .VA(VA[3:0]),
    .NOOBJ(NOOBJ),
    .ODHREV(ODHREV), 
    .SPR1_3(SPR1_3),
    .SPR2_3(SPR2_3)
);

wire E1FIND, E2FIND, O1FIND, O2FIND;
wire D1V_7P, ND1V_7P;
wire [15:0] PD;
wire [3:0]  OBJCOL;
wire [9:0]  OBJ1; 
wire [9:0]  OBJ2; 


///// Object Pixel Serializer /////
// Retrieve data from the graphical ROM, deserialize data, 
// applies horizontal/vertical flipping (HREV/VREV) and applies color palette
// index
OBJPS objps_u(
    .clk(clk),
    .rst(rst),
    .OBJ_P6M(OBJ_P6M),
    .T3F(T3F),
    .D1V_7(D1V_7),
    .PD(PD[15:0]),
    .OBJ_N6M(OBJ_N6M),
    .FIRST_LD(FIRST_LD),
    .SECND_LD(SECND_LD),
    .OPSREV(OPSREV),
    .OBJCOL(OBJCOL[3:0]), //from linecunt
    .OSP1(OSP1), 
    .OSP2(OSP2),
    .NOOBJ_CT2(NOOBJ),  //no obj XXX ? 
    .HREV(HREV), // horizontal reverse, reverse screen from dipswitch
    .HD(HD),  // from sei50bu !
    .E1FIND(E1FIND),
    .E2FIND(E2FIND),
    .O1FIND(O1FIND),
    .O2FIND(O2FIND),
    .OBJMASK(OBJMASK),
    //output 
    .D1V_7P(D1V_7P),
    .ND1V_7P(ND1V_7P),
    .OBJ1(OBJ1[9:0]),
    .OBJON(OBJON),
    .OBJ2(OBJ2[9:0]),
    .DLHD(DLHD)
);



wire OSP1, OSP2;
wire EVNCLR, ODDCLR, ODDWREN, EVNREN;
wire [8:0] O1A;
wire [8:0] O2A;
wire [8:0] E1A;
wire [8:0] E2A;
wire EVNWREN;

/////////// Line counter ///////// 
// Iterates through the sprites store in the secondary buffer 
// Calculate Memory address for the ROM 
LINECUNT linecunt_u(
   .clk(clk),
   .OVD(OVD[15:0]),
   .VA(VA[3:0]),
   .ODHREV(ODHREV),
   .RESETA(RESETA),
   .SPR1_3(SPR1_3),
   .SPR2_3(SPR2_3),
   .CTLT1(CTLT1),
   .CTLT2(CTLT2),
   .HREV(HREV),
   .OBJ_N6M(OBJ_N6M),
   .ODD_LD(ODD_LD),
   .EVN_LD(EVN_LD),
   .HBLB(HBLB),
   .OBJT2_7(OBJT2_7),
   .V1B(V1B),
   .T8H(T8H),
   .VH4(VH4),
   .VH8(VH8),
   .NOOBJ(NOOBJ),
   .obj_rom_1_data(obj_rom_1_data),
   .obj_rom_1_ok(obj_rom_1_ok),
   .obj_rom_2_data(obj_rom_2_data),
   .obj_rom_2_ok(obj_rom_2_ok),
   //
   .obj_rom_1_addr(obj_rom_1_addr),
   .obj_rom_1_cs(obj_rom_1_cs),
   .obj_rom_2_addr(obj_rom_2_addr),
   .obj_rom_2_cs(obj_rom_2_cs),
   .OBJCOL(OBJCOL[3:0]),
   .OBJ_HREV(OBJ_HREV),
   .OSP1(OSP1),
   .OSP2(OSP2),
   .PD(PD[15:0]),
   .EVNCLR(EVNCLR),
   .ODDCLR(ODDCLR),
   .O1A(O1A[8:0]),
   .E1A(E1A[8:0]),
   .ODDWREN(ODDWREN),
   .EVNWREN(EVNWREN),
   .O2A(O2A),
   .E2A(E2A)
);


/////////// Line Buffering /////////////////
// Manage two buffer Even and Odd that are swapped at end of each scanline
// (HBLANK) 
//
// Write phase : pixel generated by OPS are written into the back buffer
// using the X-position counters (SEI0060BU) 
// Read phase : Simultaneously, the Front Buffer is read in sync with video
// signal to display the sprite on the creen 

LINEBUF linebuf_u(
    .clk(clk),
    .EVNWREN(EVNWREN),//Even write en 
    .OBJ_N6M(OBJ_N6M),
    .OBJ1(OBJ1[9:0]),//Obj 1 
    .OBJ2(OBJ2[9:0]),//Obj 2 
    .E1A(E1A[8:0]),  //Even 1 Addr 
    .EVNCLR(EVNCLR), //Even clr  
    .D1V_7P(D1V_7P),
    .OBJ_P6M(OBJ_P6M),
    .E2A(E2A[8:0]),  //Even 2 addr 
    .O1A(O1A[8:0]),  //Odd 1 addr 
    .ODDCLR(ODDCLR), //Odd clr 
    .ND1V_7P(ND1V_7P),
    .O2A(O2A[8:0]),  //Odd 2 addr 
    //output 
    .E1FIND(E1FIND),  //Even 1 find 
    .E2FIND(E2FIND),  //Even 2 find 
    .O1FIND(O1FIND),  //Odd 1 find 
    .O2FIND(O2FIND),  //Odd 2 find 
    .OOD(OOD[7:0]),   //object out data
    .PRIOR_C(PRIOR_C),//prior c 
    .PRIOR_D(PRIOR_D) //prior d 
);

endmodule 
