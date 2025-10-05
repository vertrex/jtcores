module music2
(
    input           clk,
    input           SYS_RESET, //SYS_RESET
    // Z80 
    output          SRDB,
    output          SWRB, 

    //PLD238 
    output          SEL6295, 

    // SEI80BU 
    // input 14.13Mhz
    input           N1H,
    input           N6M, 

    // CONTROLLER SEI??
    input           MUSIC, 
    input           MWRLB, // MAIN WRITE R? L? BUS
    input           MRDLB, // MAIN READ  D? L? BUS
    input   [3:1]   MAB, // MAIN ADDRESS BUS 
    input   [7:0]   MDB_OUT, // MAIN DATA BUS
    output  [7:0]   MDB_IN, // MAIN DATA BUS
    input           IRQ3812,
    input           COIN1,
    input           COIN2, 
    output          COUNTER1, //output ? ? 
    output          COUNTER2, //? 
    output          CS3812,    //output 

    //74HC74
    output          CLK_3_6, 
    output          PRCLK1,
    output          SA0, 
    output   [7:0]  SD_OUT,
    // XXX SD / SA ?

/////////////////////////////////
////////////// OLD IO ///////////
/////////////////////////////////
  input             oki_cen,
/// ROM 
  input       [7:0] z80_rom_data,
  input             z80_rom_ok, 
  output reg [12:0] z80_rom_addr,
  output            z80_rom_cs_n,

  input       [7:0] bank_rom_data,
  input             bank_rom_ok, 
  output reg [15:0] bank_rom_addr,
  output            bank_rom_cs_n,
//// 

  //input             m68k_sound_cs_2,
  //input             m68k_sound_cs_4,
  //input             m68k_sound_cs_6,

  //SEIBU SOUND DEVICE MAIN READ
  //READ FROM MDB
  //input      [15:0] m68k_sound_latch_0,
  //input      [15:0] m68k_sound_latch_1,

  //SEIBU SOUND DEVICE MAIN WRITE
  //XXX WRITE TO MDB ! 
  //output reg   [15:0] z80_sound_latch_0,
  //output reg   [15:0] z80_sound_latch_1,
  //output reg   [15:0] z80_sound_latch_2,

  input         [7:0] oki_dout,
  input         [7:0] ym3812_dout
);

/////// TEMPORARY TO MUSIC1 work 
wire ym_cs_0, ym_cs_1;
assign SA0 = ym_cs_1; //should be on SA bus & selected by CS3812 ...

// WRB is used for ym-wr & oki wr .. ????
assign PRCLK1 = oki_cen;

///////// Z80 CPU  /////////////////////// 
// 
//
//
wire [7:0] SD_IN; //reg ?
wire z80_iorq_n;
wire z80_cen;
wire z80_busak_n;
//wire ym3812_irq_n; 

wire RFSH_n, Z80_INT;
wire [15:0] SA;

jtframe_z80 u_z80(
    .clk(clk),
    .cen(CLK_3_6),
    .rst_n(~SYS_RESET),

    .wait_n(wait_n), //XXX was wait_n because of ROM like for 68k  
    .int_n(Z80_INT), //DRIVE BY CONTROLER PIN 23  // sound interrupt
    .nmi_n(1'b1),
    .busrq_n(1'b1),

    .m1_n(z80_m1_n),
    .mreq_n(z80_mreq_n),
    .iorq_n(z80_iorq_n),
    .rd_n(SRDB), 
    .wr_n(SWRB),
    .rfsh_n(RFSH_n), //ram refresh
    .halt_n(), 
    .busak_n(),

    .A(SA[15:0]),

    .din(SD_IN), //SD_IN ? 
    .dout(SD_OUT) //SD_OUT  XXX share bus with sei0100bu  
);

///// PLD 23 //////////////////////////
//
//  Chip select 
//

wire irq_ack_n;
//assign irq_ack_n = ~(~z80_iorq_n & ~z80_m1_n); // === PLD B3 !!!!!  

wire SEI0100_CS_N, B1, z80_ram_cs_n;

pld23 pld23_u(
  .SA_3(SA[3]),
  .SA_13(SA[13]),
  .SA_14(SA[14]),
  .SA_15(SA[15]),
  .MEMRQ_n(z80_mreq_n),
  .IORQ_n(z80_iorq_n),
  .RD_n(SRDB),
  .RFSH_n(RFSH_n),
  .M1_n(z80_m1_n),

  .SEI0100_CS_N(SEI0100_CS_N), //-> SEI0100BU addrs ? XXX 41 
  .B1(B1), // -> SEU100BU addrs ? XXX 48 
  .SEL6295(SEL6295),
  .irq_ack_n(irq_ack_n), // SEI0100BU ? XXX 54 
  .bank_rom_cs_n(bank_rom_cs_n), // EPROM CE Z80 64k / (CS) 
  .z80_ram_cs_n(z80_ram_cs_n), // Z80 RAM CS      
  .z80_rom_cs_n(z80_rom_cs_n) // SEI080 BU ? XXX addrs cs ? 
  //.B7(B7)  // Z80 8KX8 EPROM  OE (CS) addrs SPRC0 / SRPG0 ?? (SELECT ROM ? CPU 0)
);

////// Z80 RAM  ///////////////////////
//
//  2kx8bits ram  (2048)
//
wire [7:0] RAM_SD_IN;

jtframe_ram #(.AW(11), .CEN_RD(1)) u_z80_cpu_ram(
    .clk(clk),
    //.cen(~z80_ram_cs_n), //~SRDB & ~SWRB ?
    .cen(1'b1), //~SRDB & ~SWRB ?
    .data(SD_OUT[7:0]),
    .addr(SA[10:0]), 
    .we(~z80_ram_cs_n & ~SWRB), //PLD23 19
//  .we(~SWRB), //PLD23 17 XXX DO THAT 
    .q(RAM_SD_IN[7:0])
);

///// SEI0100BU ////////////////////////////
//
// 2151/5205 controller 
// YM3931 (SDIP64)

wire [7:0] SEI0100_SD_IN;

sei0100bu sei0100bu_u(
  .clk(clk),
  .SYS_RST(SYS_RESET),
  .MUSIC(MUSIC),
  .MWRLB(MWRLB),
  .MRDLB(MRDLB),
  .MAB(MAB),  
  .MDB_OUT(MDB_OUT),
  .MDB_IN(MDB_IN),
  .irq_ack_n(irq_ack_n),
  .IRQ3812(IRQ3812),
  .CLK_3_6(CLK_3_6),
  .COIN1(COIN1),
  .COIN2(COIN1),
  .SEI0100_CS_N(SEI0100_CS_N),
  .SWRB(SWRB),
  .B1(B1),
  .SA(SA[4:0]), //32 + sei0100_cs => z80_cs selection 
   // output 
  .pin35(), 
  .COUNTER1(COUNTER1),
  .COUNTER2(COUNTER1),
  .Z80_INT(Z80_INT),
  .CS3812(CS3812),
  .SD_OUT(SD_OUT),
  .SD_IN(SEI0100_SD_IN)
); 


//XXX IN AND OUT HERE MUST BE MORE CLEART ! AND HOW TO SEND ALL IN IN CPU ?
//selected by the PLD finally ?
// we need to simulate a bus 
assign SD_IN = (~irq_ack_n | ~SEI0100_CS_N)  ? SEI0100_SD_IN : 
               ~z80_ram_cs_n                 ? RAM_SD_IN : 
               ~z80_rom_cs_n                 ? decrypt_rom_data :
               ~SEL6295 & ~SRDB              ? oki_dout :
               ~bank_rom_cs_n                ? bank_rom_data :
               //ym_cs_0 & ~SRDB             ? ym3812_dout :  //0 onlyt ???it's rarrely used aslone CS3812 ? 
               CS3812 & ~SRDB                ? ym3812_dout :  //0 onlyt ???it's rarrely used aslone CS3812 ? 
                                               8'hff;

// SEI0080 SCRAMBLER 

// 74HC74
// -> clk 3.6M
//

// 74HC74 
// PRCLK1 -> clk1 mhz ?

////////////////////////////////////////////
///////////////// OLD CODE ///////////////// 
////////////////////////////////////////////


///////// SEIBU80 //////////
//
// Decypher z80 ROM 8.m3
//
wire [7:0] decrypt_rom_data;
wire       decrypt_rom_ok;
reg        decrypt_rom_cs_seibu;

wire       z80_m1_n;   //m1 low => opcode
wire       z80_mreq_n;

sei80bu u_sei80bu(
    //N1H ?? ~hpos[0] ?/
  .clk(clk),
  //cen ?
  .z80_rom_addr({3'd0, z80_rom_addr}),
  .z80_rom_data(z80_rom_data),
  .z80_rom_ok(z80_rom_ok), 
  .z80_rom_cs(~z80_rom_cs_n),
  .z80_m1(~z80_m1_n),
  .decrypt_rom_data(decrypt_rom_data),
  .decrypt_rom_ok(decrypt_rom_ok)
);

///////// Z80 CLOCK /////////////////////////////
//
// Generate 3.579545 MHz clock
//
wire cen_fm2;

// XXX MOVE TO SEI80BU ! 
jtframe_cen3p57 u_fmcen(
    .clk(clk),      // 48 MHz
    .cen_3p57(CLK_3_6),
    .cen_1p78(cen_fm2)
);

///////// Z80 WAIT ///////////////////////
// 
// make z80 bus wait if rom or banked rom
// is selected and not available  
// 
//

/// XXX NEEDED ONLY BECAUE OF SDRAM ? NOT ON ORIGINAL BOARD
reg wait_n;

always @(posedge clk, posedge SYS_RESET) begin
  if (SYS_RESET)
    wait_n <= 1'b1;
  else if (CLK_3_6) begin
    if (~z80_rom_cs_n & ~z80_rom_ok)
      wait_n <= 1'b0;
    else if (~bank_rom_cs_n & ~bank_rom_ok)
      wait_n <= 1'b0;
    else 
      wait_n <= 1'b1;
  end 
end

////// Z80 ROM & bank switch /////////////////////
//
//
reg bank_selected = 1'b0; // switch to data bank

/// XXX ? HADNLED BY PLD ? 
always @(posedge clk) begin
    // ROM & bank handling
    if (SA[15:0] < 16'h2000)
      z80_rom_addr[12:0] <= SA[12:0];
    // bank size is 0x10000 
    // z80 address from 0x8000  to 0x10000 is read directly from the rom 
    // z80 address from 0x10000 to 0x18000 is read after switching bank
    if (SA[15:0] == 16'h4007) // switch bank usage 
      bank_selected <= SD_OUT[0];
    if (SA[15:0] >= 16'h8000 && bank_selected == 1'b0)
      bank_rom_addr[15:0] <= (SA[15:0] - 16'h8000); //0x2000 first bytes
    else if (SA[15:0] >= 16'h8000 && bank_selected == 1'b1)
      bank_rom_addr[15:0] <= SA[15:0];
end



endmodule 
