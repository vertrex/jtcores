//Toki MiSTer
//Copyright (C) 2023 Solal Jacob 

//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.

//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.

//You should have received a copy of the GNU General Public License
//along with this program.  If not, see <http://www.gnu.org/licenses/>.

////////// toki game main module /////////////////////
//
// This is Toki main module that init and wire :
//  - main module 
//  - video module
//  - sound module 
//
module jttoki_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
  );

wire P6M, N6M;

/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk(clk),
    .cen12(),
    .cen12b(),
    .cen8(),
    .cen6(P6M),
    .cen6b(N6M),
    .cen3(),
    .cen1p5()
);

wire  [8:0] hpos;
wire  [8:0] vpos;

wire [10:1] obj_addr;
wire [15:0] obj_out;
wire  [6:1] scroll_addr;
wire [15:0] scroll_out;
wire        bk1_hsync; 
wire        bk2_hsync;


assign debug_view = 0;
assign sample     = 0;
assign dip_flip   = 0;

wire [8:0] bk1_hpos;
wire [8:0] bk1_vpos;
wire [8:0] bk2_hpos;
wire [8:0] bk2_vpos;

wire HBLB;
wire INT_T;
wire T4H;

wire S1MASK;
wire S2MASK;
wire OBJMASK;
wire S4MASK;
wire PRIOR_A;
wire PRIOR_B;
wire HREV;
wire YREV;
wire [12:1] KDA;
wire [17:1] MAB;
//wire [15:0] MDB_OUT;
wire [15:0] MDB_RAM_OUT;
wire [15:0] MDB_CPU_OUT;
wire MWRLB, MRDLB; 
wire DMSL_S1, DMSL_S2, DMSL_S4, DMSL_GL;
wire RST_S1H, SEL_S1H, RST_S1Y, SEL_S1Y;
wire RST_S2H, SEL_S2H, RST_S2Y, SEL_S2Y;
wire WRN6M;
wire MUSIC;
wire N1H;

wire m68k_sound_cs_2, m68k_sound_cs_4, m68k_sound_cs_6;
wire [15:0] m68k_sound_latch_0, m68k_sound_latch_1;
wire [15:0] z80_sound_latch_0, z80_sound_latch_1, z80_sound_latch_2;

//////// MAIN ////////////
//
//
// main module 
// - 68k cpu
// - cpu ram & video ram
// - scroll latch
// - sound latch
//
toki_main  u_main(
  .rst(rst),

  // Clock
  .clk(clk),
  .P6M(P6M),
  .N6M(N6M),

  // Video 
  //.LVBL(prom_26_data[6]), //CPU VBLANK IS TRIGGERED BY 82S135 pin 11
  .LVBL(LVBL), //CPU VBLANK IS TRIGGERED BY 82S135 pin 11
  .HBLB(HBLB),
  .INT_T(INT_T),
  .hpos(hpos),
  .vpos(vpos),

  // Input
  .start_button(cab_1p[1:0]),
  .joystick1(joystick1),
  .joystick2(joystick2),

  // DIP switches
  .dipsw(dipsw),
  .dip_pause(dip_pause),
  .service(service),

  // 68K rom
  .cpu_rom_addr(cpu_rom_addr),
  .cpu_rom_cs(cpu_rom_cs),
  .cpu_rom_ok(cpu_rom_ok),
  .cpu_rom_data(cpu_rom_data),

  //Shared video RAM 
  .obj_addr(obj_addr),
  .obj_out(obj_out),

  //Sound latch
  .MUSIC(MUSIC),

  .S1MASK(S1MASK),
  .S2MASK(S2MASK),
  .OBJMASK(OBJMASK),
  .S4MASK(S4MASK),
  .PRIOR_A(PRIOR_A),
  .PRIOR_B(PRIOR_B),
  .HREV(HREV),
  .YREV(YREV),

  .KDA(KDA),
  .MAB(MAB),
  //.MDB_OUT(MDB_OUT),
  .MDB_RAM_OUT(MDB_RAM_OUT),
  .MDB_CPU_OUT(MDB_CPU_OUT),
  .SEI0100_MDB_IN(SEI0100_MDB_IN),
  .MWRLB(MWRLB),
  .MRDLB(MRDLB),
  .DMSL_S1(DMSL_S1),
  .DMSL_S2(DMSL_S2),
  .DMSL_S4(DMSL_S4),
  .DMSL_GL(DMSL_GL),
  
  .RST_S1H(RST_S1H), 
  .SEL_S1H(SEL_S1H), 
  .RST_S1Y(RST_S1Y), 
  .SEL_S1Y(SEL_S1Y),
  .RST_S2H(RST_S2H), 
  .SEL_S2H(SEL_S2H), 
  .RST_S2Y(RST_S2Y), 
  .SEL_S2Y(SEL_S2Y),

  .WRN6M(WRN6M)
);

//////// VIDEO ////////////
//
// video module 
// - char, tile & obj drawing 
// - vga sync 
//
toki_video u_video(
  .clk(clk),
  .rst(rst),
  .P6M(P6M),
  .N6M(N6M),

  // Video signal
  .HS(HS),
  .VS(VS),
  .LHBL(LHBL),
  .LVBL(LVBL),
  .hpos(hpos),
  .vpos(vpos),
  .N1H(N1H),
  .gfx_en(gfx_en),

  .r(red),
  .g(green),
  .b(blue),

  //Shared video RAM
  .obj_addr(obj_addr),
  .obj_out(obj_out),

  //GFX ROM 
  //.gfx1_rom_data(gfx1_rom_data),
  //.gfx1_rom_ok(gfx1_rom_ok),
  //.gfx1_rom_addr(gfx1_rom_addr),
  //.gfx1_rom_cs(gfx1_rom_cs),
  //
  //.char_rom_data(char_rom_data),
  //.char_rom_ok(char_rom_ok),
  //.char_rom_addr(char_rom_addr),
  //.char_rom_cs(char_rom_cs),
  
  .char_rom_1_data(char_rom_1_data),
  .char_rom_1_ok(char_rom_1_ok),
  .char_rom_1_addr(char_rom_1_addr),
  .char_rom_1_cs(char_rom_1_cs),

  .char_rom_2_data(char_rom_2_data),
  .char_rom_2_ok(char_rom_2_ok),
  .char_rom_2_addr(char_rom_2_addr),
  .char_rom_2_cs(char_rom_2_cs),

  .gfx2_rom_data(gfx2_rom_data),
  .gfx2_rom_ok(gfx2_rom_ok),
  .gfx2_rom_addr(gfx2_rom_addr),
  .gfx2_rom_cs(gfx2_rom_cs),

  .gfx3_rom_data(gfx3_rom_data),
  .gfx3_rom_ok(gfx3_rom_ok),
  .gfx3_rom_addr(gfx3_rom_addr),
  .gfx3_rom_cs(gfx3_rom_cs),

  .gfx4_rom_data(gfx4_rom_data),
  .gfx4_rom_ok(gfx4_rom_ok),
  .gfx4_rom_addr(gfx4_rom_addr),
  .gfx4_rom_cs(gfx4_rom_cs),

  .prom_26_data(prom_26_data),
  .prom_26_ok(prom_26_ok),
  .prom_26_cs(prom_26_cs),
  .prom_26_addr(prom_26_addr),

  .prom_27_data(prom_27_data),
  .prom_27_ok(prom_27_ok),
  .prom_27_cs(prom_27_cs),
  .prom_27_addr(prom_27_addr),

  .HBLB(HBLB),
  .INT_T(INT_T),

  .S1MASK(S1MASK),
  .S2MASK(S2MASK),
  .OBJMASK(OBJMASK),
  .S4MASK(S4MASK),
  .PRIOR_A(PRIOR_A),
  .PRIOR_B(PRIOR_B),
  .HREV(HREV),
  .YREV(YREV),

  .KDA(KDA),
  .MAB(MAB),
  //.MDB(MDB_OUT),
  .MDB_RAM_OUT(MDB_RAM_OUT),
  .MDB_CPU_OUT(MDB_CPU_OUT),

  .DMSL_S1(DMSL_S1),
  .DMSL_S2(DMSL_S2),
  .DMSL_S4(DMSL_S4),
  .DMSL_GL(DMSL_GL),

  .RST_S1H(RST_S1H), 
  .SEL_S1H(SEL_S1H), 
  .RST_S1Y(RST_S1Y), 
  .SEL_S1Y(SEL_S1Y),
  .RST_S2H(RST_S2H), 
  .SEL_S2H(SEL_S2H), 
  .RST_S2Y(RST_S2Y), 
  .SEL_S2Y(SEL_S2Y),

  .WRN6M(WRN6M)
);

//////// SOUND ////////////
//
// sound module
// seibu sound system: 
// - z80 
// - sei80bu z80 rom decypher
// - oki6295 / pcm 
// - ym3812 / fm 
// - coin input 

//music2 output 
//XXX all to music 1 ? 

wire SRDB, SWRB;
wire SEL6295;
wire COUNTER1;
wire COUNTER2; 
wire CS3812;
wire CLK_3_6;
wire PRCLK1;
wire SA_0; //should be on SA bus 
wire [7:0] SD_OUT;
// OLD 
wire [7:0] oki_dout;
wire [7:0] z80_dout;
wire ym_cs_0;
wire ym_cs_1; 
wire [7:0] ym3812_dout;

//wire  RESET_A;  //from where not driven ?
wire  IRQ3812;

music1 u_music1(
  .clk(clk),
  .rst(rst),
  .CLK_3_6(CLK_3_6),
  .CS3812(CS3812),
  .SA_0(SA_0),
  .SD_OUT(SD_OUT),
  //.RESET_A(RESET_A), // ?? ~SYS_RESET or = SYS_RESET ?
  .IRQ3812(IRQ3812),
  .PRCLK1(PRCLK1),
  .SRDB(SRDB),
  .SWRB(SWRB),
  .SEL6295(SEL6295),
  //// 

  .snd(snd),
  .fxlevel(dip_fxlevel),
  .enable_fm(enable_fm),
  .enable_psg(enable_psg),

  .pcm_rom_addr(pcm_rom_addr),
  .pcm_rom_data(pcm_rom_data),
  .pcm_rom_ok(pcm_rom_ok),
  .pcm_rom_cs(pcm_rom_cs),

  .oki_dout(oki_dout),
  .ym3812_dout(ym3812_dout)
);

wire z80_rom_cs_n;
assign z80_rom_cs = ~z80_rom_cs_n;
wire bank_rom_cs_n; 
assign bank_rom_cs = ~bank_rom_cs_n;

wire [7:0] SEI0100_MDB_IN;

music2 u_music2(
  .clk(clk),
  .rst(rst),
  //.SYS_RESET(rst),

  .SRDB(SRDB),
  .SWRB(SWRB), 

  .SEL6295(SEL6295),

  .N1H(N1H),
  .N6M(N6M),

  .MUSIC(MUSIC),
  .MWRLB(MWRLB),
  .MRDLB(MRDLB),
  .MAB(MAB[3:1]),
  .MDB_CPU_OUT(MDB_CPU_OUT[7:0]),
  .MDB_IN(SEI0100_MDB_IN[7:0]),
  .IRQ3812(IRQ3812),
  .COIN1(coin[0]), 
  .COIN2(coin[1]),

  .COUNTER1(COUNTER1), //to jamma ->  mister ? 
  .COUNTER2(COUNTER2), //to jamma -> mister 
  .CS3812(CS3812),

  .CLK_3_6(CLK_3_6),
  .PRCLK1(PRCLK1),
  .SA_0(SA_0),
  .SD_OUT(SD_OUT),
  ////////////////////////////////
  .oki_cen(oki_cen),

  .z80_rom_data(z80_rom_data),
  .z80_rom_ok(z80_rom_ok),
  .z80_rom_addr(z80_rom_addr),
  .z80_rom_cs_n(z80_rom_cs_n),

  .bank_rom_data(bank_rom_data),
  .bank_rom_ok(bank_rom_ok),
  .bank_rom_addr(bank_rom_addr),
  .bank_rom_cs_n(bank_rom_cs_n),

  .oki_dout(oki_dout),
  .ym3812_dout(ym3812_dout)
);


endmodule
