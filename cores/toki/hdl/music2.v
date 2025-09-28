module music2
(
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
    input           MWRLB,
    input           MRDLB,
    input   [3:1]   MAB,
    input   [7:0]   MDB,
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
    output   [7:0]  SD,
    // XXX SD / SA ?

/////////////////////////////////
////////////// OLD IO ///////////
/////////////////////////////////
  input             clk,
  input             oki_cen,
/// ROM 
  input       [7:0] z80_rom_data,
  input             z80_rom_ok, 
  output reg [12:0] z80_rom_addr,
  output            z80_rom_cs_n,

  input       [7:0] bank_rom_data,
  input             bank_rom_ok, 
  output reg [15:0] bank_rom_addr,
  output            bank_rom_cs,
//// 

  input             m68k_sound_cs_2,
  input             m68k_sound_cs_4,
  input             m68k_sound_cs_6,

  //SEIBU SOUND DEVICE MAIN READ
  input      [15:0] m68k_sound_latch_0,
  input      [15:0] m68k_sound_latch_1,

  //SEIBU SOUND DEVICE MAIN WRITE
  output reg   [15:0] z80_sound_latch_0,
  output reg   [15:0] z80_sound_latch_1,
  output reg   [15:0] z80_sound_latch_2,

  input         [7:0] oki_dout,
  input         [7:0] ym3812_dout
);

/////// TEMPORARY TO MUSIC1 work 
wire ym_cs_0, ym_cs_1;
assign SA0 = ym_cs_1; //should be on SA bus & selected by CS3812 ...

wire ym_wr;
assign CS3812 = ~ym_wr;

// WRB is used for ym-wr & oki wr .. ????
assign PRCLK1 = oki_cen;
wire oki_wr;

///////// Z80 CPU  /////////////////////// 
// 
//
//
reg  [7:0] z80_din;
wire z80_iorq_n;
wire z80_cen;
wire z80_busak_n;
//wire ym3812_irq_n; 

wire z80_int_n;
assign z80_int_n = ~(irq_rst10|irq_rst18);

wire RFSH_n;

jtframe_z80 u_z80(
    .rst_n(~SYS_RESET),
    .clk(clk),
    .cen(CLK_3_6),

    .wait_n(wait_n), //XXX was wait_n because of ROM like for 68k  
    .int_n(z80_int_n), //DRIVE BY CONTROLER PIN 23  // sound interrupt
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

    .din(z80_din),
    .dout(SD) 
);

///// PLD 23 //////////////////////////
//
//  Chip select 
//

wire irq_ack_n;
//assign irq_ack_n = ~(~z80_iorq_n & ~z80_m1_n); // === PLD B3 !!!!!  

wire B0, B1, B3, B4, z80_ram_cs_n;

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

  .B0(B0), //-> SEI0100BU addrs ? XXX 41 
  .B1(B1), // -> SEU100BU addrs ? XXX 48 
  .SEL6295(SEL6295),
  .irq_ack_n(irq_ack_n), // SEI0100BU ? XXX 54 
  .B4(B4), // EPROM CE Z80 64k / (CS) 
  .z80_ram_cs_n(z80_ram_cs_n), // Z80 RAM CS      
  .z80_rom_cs_n(z80_rom_cs_n) // SEI080 BU ? XXX addrs cs ? 
  //.B7(B7)  // Z80 8KX8 EPROM  OE (CS) addrs SPRC0 / SRPG0 ?? (SELECT ROM ? CPU 0)
);

//assign SEL6295 = ~oki_wr;

////// Z80 RAM  ///////////////////////
//
//  2kx8bits ram  (2048)
//
wire [7:0] SD_OUT;

jtframe_ram #(.AW(11), .CEN_RD(1)) u_z80_cpu_ram(
    .clk(clk),
    //.cen(~z80_ram_cs_n), //~SRDB & ~SWRB ?
    .cen(1'b1), //~SRDB & ~SWRB ?
    .data(SD[7:0]),
    .addr(SA[10:0]), 
    .we(~z80_ram_cs_n & ~SWRB), //PLD23 19
//    .we(~SWRB), //PLD23 17 XXX DO THAT 
    //XXX DO THAT 
    .q(SD_OUT[7:0])
);


// SEI 01 ?? 
// 2151/5205 controller 
//SEI0100BU - Custom chip marked 'SEI0100BU YM3931' (SDIP64)

//XXX MOVE CODE HERE / CREATE MODULE 

// SEI0080 SCRAMBLER 

// XXX MOVE TO MODUEL 

// 74HC74
// -> clk 3.6M
//

// 74HC74 
// PRCLK1 -> clk1 mhz ?

////////////////////////////////////////////
///////////////// OLD CODE ///////////////// 
////////////////////////////////////////////


/////// Z80 address bus ///////////////////////////////////
//
//wire z80_ram_cs_n, //ym_cs_0, ym_cs_1, 
wire m68k_latch0_cs, m68k_latch1_cs, main_data_pending_cs, 
     read_coin_cs,  
     oki_rd;

//wire [7:0]  ym3812_dout;
wire [15:0] SA;
//wire [7:0]  SD;

z80_cs u_z80cs(
  .z80_addr(SA),
  .z80_wr_n(SWRB),
  .z80_rd_n(SRDB),
  //.z80_rom_cs(z80_rom_cs),
  .bank_rom_cs(bank_rom_cs),
  //.z80_ram_cs(~z80_ram_cs_n),

  .ym_cs_0(ym_cs_0),
  .ym_cs_1(ym_cs_1),

  .m68k_latch0_cs(m68k_latch0_cs),
  .m68k_latch1_cs(m68k_latch1_cs),

  .main_data_pending_cs(main_data_pending_cs),
  .read_coin_cs(read_coin_cs),

  .ym_wr(ym_wr),
  .oki_wr(oki_wr),
  .oki_rd(oki_rd)
);

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

always @(posedge CLK_3_6, posedge SYS_RESET) begin
  if (SYS_RESET)
    wait_n <= 1'b1;
  else begin
    if (~z80_rom_cs_n & ~z80_rom_ok)
      wait_n <= 1'b0;
    else if (bank_rom_cs & ~bank_rom_ok)
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
      bank_selected <= SD[0];
    if (SA[15:0] >= 16'h8000 && bank_selected == 1'b0)
      bank_rom_addr[15:0] <= (SA[15:0] - 16'h8000); //0x2000 first bytes
    else if (SA[15:0] >= 16'h8000 && bank_selected == 1'b1)
      bank_rom_addr[15:0] <= SA[15:0];
end


////// SOUND ////////////////////
//
// sound latch
//
//

// XXX done by the controlelr ?
reg oki6295_irq_n;
reg sub2main_pending;


always @(posedge clk, posedge SYS_RESET) begin //XXX speed must be same than 68k din ?
  if (SYS_RESET) begin
    z80_sound_latch_0 <= 16'b0;
    z80_sound_latch_1 <= 16'b0;
    sub2main_pending  <= 1'b0;
    oki6295_irq_n     <= 1'b1;
    end
  else begin
    // send z80 data to 68k cpu
    if (SA[15:0] == 16'h4018) 
      z80_sound_latch_0 <= {8'b0, SD[7:0]};
    if (SA[15:0] == 16'h4019)
      z80_sound_latch_1 <= {8'b0, SD[7:0]};

    // data from z80 is pending read from 68k
    if (SA[15:0] == 16'h4000) begin
      z80_sound_latch_2 <= 16'b0;
      sub2main_pending <= 1'b1;
      end
    else if (m68k_sound_cs_6 == 1'b1 || m68k_sound_cs_2 == 1'b1) begin //? it's used as cpu din too
      z80_sound_latch_2 <= 16'b1;
      sub2main_pending <= 1'b0;
      end

    // main cpu assert irq for oki6295
    if (m68k_sound_cs_4 == 1'b1) 
      oki6295_irq_n <= 1'b0; 
    else
      oki6295_irq_n <= 1'b1;
    end
end

////// Z80 databus input   /////////////////////// 
//
//  IRQ use z80 interrupt mode 0 :
//  After interrupt is asserted, the cpu signal it's 
//  ready by putting iorq and m1 high 
//  it then read on the databus 
//  this data is directly executed by the cpu as an opcode 
//
//  - ym3821 assert irq and put 0xd7 (rst10) on the bus 
//  - 68k main cpu assert irq and put 0xdf (rst18) on the bus 
// 
//  both interrupt are needed to handle sound and coin input
//
reg irq_rst10;
reg irq_rst18;
reg stop_irq_10; 
reg stop_irq_18; 

// XXX ??? BUS SHARED ? + CONTROLLER ?

always @(posedge clk, posedge SYS_RESET) begin
  if (SYS_RESET) begin
    z80_din     <= 8'hff;
    irq_rst10 <= 1'b0;
    irq_rst18 <= 1'b0;
    stop_irq_10 <= 1'b0;
    stop_irq_18 <= 1'b0;
    end
  else begin
    if (clk) begin
      if (irq_ack_n & stop_irq_10) begin
        irq_rst10 <= 1'b0;
        stop_irq_10 <= 1'b0;
        end
      else if (irq_ack_n & stop_irq_18) begin
        stop_irq_18 <= 1'b0;
        irq_rst18 <= 1'b0;
        end
      else if (IRQ3812 == 1'b0)
        irq_rst10 <= 1'b1;
      else if (oki6295_irq_n == 1'b0) //~m68k_sound_cs_4
        irq_rst18 <= 1'b1;
          
      if (~irq_ack_n & irq_rst10)
        stop_irq_10 <= 1'b1;
      else if (~irq_ack_n & irq_rst18)
        stop_irq_18 <= 1'b1;

      z80_din <= ~irq_ack_n & irq_rst10                      ? 8'hd7 : 
                 ~irq_ack_n & irq_rst18                      ? 8'hdf :
                 main_data_pending_cs &  sub2main_pending ? 8'b1  :  //MWRLB  + DATA BUS ?
                 main_data_pending_cs & ~sub2main_pending ? 8'b0 :   //MRLB + DATA BUS ? 
                 ym_cs_0 & ~SRDB                          ? ym3812_dout :  //0 onlyt ???it's rarrely used aslone CS3812 ? 
                 oki_rd                                   ? oki_dout :
                 bank_rom_cs                              ? bank_rom_data :
                 m68k_latch0_cs                           ? m68k_sound_latch_0[7:0] :
                 m68k_latch1_cs                           ? m68k_sound_latch_1[7:0] :
                 read_coin_cs                             ? {6'b0, ~COIN2, ~COIN1} :
                 ~z80_ram_cs_n                            ? SD_OUT :
                 ~z80_rom_cs_n                            ? decrypt_rom_data :
                                                            8'hff;
    end 
  end
end

endmodule 
