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

//wire hblank;
//wire vblank;

//assign LHBL = ~hblank;
//assign LVBL = ~vblank;

wire  [8:0] hpos;
wire  [8:0] vpos;

wire [10:1] obj_addr;
wire [15:0] obj_out;
wire  [6:1] scroll_addr;
wire [15:0] scroll_out;
wire        bk1_hsync; 
wire        bk2_hsync;
wire        bg_order;

wire m68k_sound_cs_2;
wire m68k_sound_cs_4;
wire m68k_sound_cs_6;

wire [15:0] m68k_sound_latch_0;
wire [15:0] m68k_sound_latch_1;
wire [15:0] z80_sound_latch_0; 
wire [15:0] z80_sound_latch_1;
wire [15:0] z80_sound_latch_2;

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

wire P6M, N6M;
assign P6M = pxl_cen;
assign N6M = ~pxl_cen;

//wire vram_cs;
//wire bk1_cs;
//wire bk2_cs;
//wire obj_cs;

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
wire [15:0] MDB_IN;
wire [15:0] MDB_OUT;
wire DMSL_S1, DMSL_S2, DMSL_S4, DMSL_GL;
wire RST_S1H, SEL_S1H, RST_S1Y, SEL_S1Y;
wire RST_S2H, SEL_S2H, RST_S2Y, SEL_S2Y;
wire WRN6M;

//////// MAIN ////////////
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

  //Scroll latch
  .bg_order(bg_order),

  //Sound latch
  .sound_cs_2(m68k_sound_cs_2),
  .sound_cs_4(m68k_sound_cs_4),
  .sound_cs_6(m68k_sound_cs_6),

  .m68k_sound_latch_0(m68k_sound_latch_0),
  .m68k_sound_latch_1(m68k_sound_latch_1),

  //Sound input from z80
  .z80_sound_latch_0(z80_sound_latch_0),
  .z80_sound_latch_1(z80_sound_latch_1),
  .z80_sound_latch_2(z80_sound_latch_2),

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
  .MDB_IN(MDB_IN),
  .MDB_OUT(MDB_OUT),
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
  .rst(rst),

  .clk(clk),
  .P6M(P6M),
  .N6M(N6M),

  // Video signal
  .HS(HS),
  .VS(VS),
  .LHBL(LHBL),
  .LVBL(LVBL),
  .hpos(hpos),
  .vpos(vpos),
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
  .MDB_IN(MDB_IN),
  .MDB_OUT(MDB_OUT),

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
// 
toki_sound u_sound(
  .rst(rst),
  .clk(clk),

  .oki_cen(oki_cen),

  .coin_input(coin[1:0]),

  .snd(snd),
  .fxlevel(dip_fxlevel),
  .enable_fm(enable_fm),
  .enable_psg(enable_psg),

  .z80_rom_addr(z80_rom_addr),
  .z80_rom_data(z80_rom_data),
  .z80_rom_ok(z80_rom_ok),
  .z80_rom_cs(z80_rom_cs),

  .bank_rom_addr(bank_rom_addr),
  .bank_rom_data(bank_rom_data),
  .bank_rom_ok(bank_rom_ok),
  .bank_rom_cs(bank_rom_cs),

  .pcm_rom_addr(pcm_rom_addr),
  .pcm_rom_data(pcm_rom_data),
  .pcm_rom_ok(pcm_rom_ok),
  .pcm_rom_cs(pcm_rom_cs),

  .m68k_sound_cs_2(m68k_sound_cs_2),
  .m68k_sound_cs_4(m68k_sound_cs_4),
  .m68k_sound_cs_6(m68k_sound_cs_6),

  .m68k_sound_latch_0(m68k_sound_latch_0),
  .m68k_sound_latch_1(m68k_sound_latch_1),
  .z80_sound_latch_0(z80_sound_latch_0),
  .z80_sound_latch_1(z80_sound_latch_1),
  .z80_sound_latch_2(z80_sound_latch_2)
);

endmodule
