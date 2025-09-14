module music2
(
    input           SYS_RESET, //SYS_RESET
    // Z80 
    output          SRDB,
    output          SWRB, 

    //PLD23 
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
    output          SA, 
    output   [7:0]  SD,
    // XXX SD / SA ?

/////////////////////////////////
////////////// OLD IO ///////////
/////////////////////////////////
  input             clk,

  input       [7:0] z80_rom_data,
  input             z80_rom_ok, 
  output reg [12:0] z80_rom_addr,
  output            z80_rom_cs,

  input       [7:0] bank_rom_data,
  input             bank_rom_ok, 
  output reg [15:0] bank_rom_addr,
  output            bank_rom_cs,

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
  output        [7:0] z80_dout,
  output              oki_wr,
  output              cen_fm,
  output              ym_cs_0,
  output              ym_cs_1,
  output              ym_wr,
  input         [7:0] ym3812_dout,
  input               ym3812_irq_n
);



//Z80

//PLD 23

// 2kx8 slim package
// Z80 RAM

// 64kx8 rom

// SEI 01 ?? 
// 2151/5205 controller 

// SEI0080 SCRAMBLER 

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
wire z80_ram_cs, //ym_cs_0, ym_cs_1, 
     m68k_latch0_cs, m68k_latch1_cs, main_data_pending_cs, 
     read_coin_cs, z80_wr_n, 
     oki_rd;

//wire [7:0]  ym3812_dout;
wire [15:0] z80_addr;
//wire [7:0]  z80_dout;
wire        z80_rd_n;

z80_cs u_z80cs(
  .z80_addr(z80_addr),
  .z80_wr_n(z80_wr_n),
  .z80_rd_n(z80_rd_n),
  .z80_rom_cs(z80_rom_cs),
  .bank_rom_cs(bank_rom_cs),
  .z80_ram_cs(z80_ram_cs),

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
wire       z80_wait_n;

sei80bu u_sei80bu(
  .clk(clk),
  .z80_rom_addr({3'd0, z80_rom_addr}),
  .z80_rom_data(z80_rom_data),
  .z80_rom_ok(z80_rom_ok), 
  .z80_rom_cs(z80_rom_cs),
  .z80_m1(~z80_m1_n),
  .decrypt_rom_data(decrypt_rom_data),
  .decrypt_rom_ok(decrypt_rom_ok)
);

///////// Z80 CLOCK /////////////////////////////
//
// Generate 3.579545 MHz clock
//
wire cen_fm2; // XXX replace by 3_6M

jtframe_cen3p57 u_fmcen(
    .clk(clk),      // 48 MHz
    .cen_3p57(cen_fm),
    .cen_1p78(cen_fm2)
);

///////// Z80 WAIT ///////////////////////
// 
// make z80 bus wait if rom or banked rom
// is selected and not available  
// 
reg  wait_n;

always @(posedge clk, posedge SYS_RESET) begin
  if (SYS_RESET)
    wait_n <= 1'b1;
  else begin
    if (z80_rom_cs & ~z80_rom_ok)
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

always @(posedge clk) begin
    // ROM & bank handling
    if (z80_addr[15:0] < 16'h2000)
      z80_rom_addr[12:0] <= z80_addr[12:0];
    // bank size is 0x10000 
    // z80 address from 0x8000  to 0x10000 is read directly from the rom 
    // z80 address from 0x10000 to 0x18000 is read after switching bank
    if (z80_addr[15:0] == 16'h4007) // switch bank usage 
      bank_selected <= z80_dout[0];
    if (z80_addr[15:0] >= 16'h8000 && bank_selected == 1'b0)
      bank_rom_addr[15:0] <= (z80_addr[15:0] - 16'h8000); //0x2000 first bytes
    else if (z80_addr[15:0] >= 16'h8000 && bank_selected == 1'b1)
      bank_rom_addr[15:0] <= z80_addr[15:0];
end

///////// Z80 CPU  /////////////////////// 
// 
//
//
reg  [7:0] z80_din;
wire z80_iorq_n;
wire z80_cen;
wire z80_busak_n;
//wire ym3812_irq_n; 

jtframe_z80 u_z80(
    .rst_n(~SYS_RESET),
    .clk(clk),
    .cen(cen_fm),

    .wait_n(wait_n),
    .int_n(~(irq_rst10|irq_rst18)), // sound interrupt
    .nmi_n(1'b1),
    .busrq_n(1'b1),

    .m1_n(z80_m1_n),
    .mreq_n(z80_mreq_n),
    .iorq_n(z80_iorq_n),
    .rd_n(z80_rd_n), 
    .wr_n(z80_wr_n),
    .rfsh_n(),
    .halt_n(), 
    .busak_n(),

    .A(z80_addr[15:0]),

    .din(z80_din),
    .dout(z80_dout) 
);

////// SOUND ////////////////////
//
// sound latch
//
//

//done by the controlelr ?
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
    if (z80_addr[15:0] == 16'h4018) 
      z80_sound_latch_0 <= {8'b0, z80_dout[7:0]};
    if (z80_addr[15:0] == 16'h4019)
      z80_sound_latch_1 <= {8'b0, z80_dout[7:0]};

    // data from z80 is pending read from 68k
    if (z80_addr[15:0] == 16'h4000) begin
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
wire irq_ack;
assign irq_ack = ~z80_iorq_n & ~z80_m1_n;

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
      if (~irq_ack & stop_irq_10) begin
        irq_rst10 <= 1'b0;
        stop_irq_10 <= 1'b0;
        end
      else if (~irq_ack & stop_irq_18) begin
        stop_irq_18 <= 1'b0;
        irq_rst18 <= 1'b0;
        end
      else if (ym3812_irq_n == 1'b0)
        irq_rst10 <= 1'b1;
      else if (oki6295_irq_n == 1'b0) //~m68k_sound_cs_4
        irq_rst18 <= 1'b1;
          
      if (irq_ack & irq_rst10)
        stop_irq_10 <= 1'b1;
      else if (irq_ack & irq_rst18)
        stop_irq_18 <= 1'b1;

      z80_din <= irq_ack & irq_rst10                      ? 8'hd7 : 
                 irq_ack & irq_rst18                      ? 8'hdf :
                 main_data_pending_cs &  sub2main_pending ? 8'b1  :
                 main_data_pending_cs & ~sub2main_pending ? 8'b0 :
                 ym_cs_0 & ~z80_rd_n                      ? ym3812_dout :
                 oki_rd                                   ? oki_dout :
                 bank_rom_cs                              ? bank_rom_data :
                 m68k_latch0_cs                           ? m68k_sound_latch_0[7:0] :
                 m68k_latch1_cs                           ? m68k_sound_latch_1[7:0] :
                 read_coin_cs                             ? {6'b0, ~COIN2, ~COIN1} :
                 z80_ram_cs                               ? z80_ram_dout :
                 z80_rom_cs                               ? decrypt_rom_data :
                                                            8'hff;
    end 
  end
end

////// Z80 RAM  ///////////////////////
//
//  8bits ram  (2048)
//
wire [7:0] z80_ram_dout;

jtframe_ram #(.AW(11)) u_z80_cpu_ram(
    .clk(clk),
    .cen(1'b1),
    .data(z80_dout[7:0]),
    .addr(z80_addr[10:0]), 
    .we(z80_ram_cs & ~z80_wr_n), //& ~z80_mreq_n ?
    .q(z80_ram_dout[7:0])
);

endmodule 
