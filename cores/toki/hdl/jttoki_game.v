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
wire [10:1] palette_addr;
wire [15:0] palette_out;

//wire [10:1] vram_addr;
wire [15:0] vram_out;

//wire [10:1] bk1_addr;
wire [15:0] bk1_out;

//wire [10:1] bk2_addr;
wire [15:0] bk2_out;

wire [10:1] sprite_addr;
wire [15:0] sprite_out;

wire  [6:1] scroll_addr;
wire [15:0] scroll_out;

wire [8:0]  bk1_scroll_x;
wire [8:0]  bk1_scroll_y;
wire        bk1_hsync; 
wire [8:0]  bk2_scroll_x;
wire [8:0]  bk2_scroll_y;
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
//reg  div = 1'b0;

// don't work with jtframe_obj_buffer because of rd 
//assign pxl2_cen = pixel_cen;
//assign pxl_cen = div;

//always @(posedge pixel_cen)
  //div <= ~div;

//assign pxl_cen = pixel_cen;

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
  .pxl_cen(pxl_cen),
  //.pxl2_cen(pxl2_cen),

  // Video 
  //.LVBL(prom_26_data[6]), //CPU VBLANK IS TRIGGERED BY 82S135 pin 11
  //.LVBL(LVBL), //CPU VBLANK IS TRIGGERED BY 82S135 pin 11
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
  .palette_addr(palette_addr),
  .palette_out(palette_out),

  //.vram_addr(vram_addr),
  .vram_out(vram_out),

  //.bk1_addr(bk1_addr),
  .bk1_out(bk1_out),

  //.bk2_addr(bk2_addr),
  .bk2_out(bk2_out),

  .sprite_addr(sprite_addr),
  .sprite_out(sprite_out),

  //Scroll latch
  .bk1_scroll_x(bk1_scroll_x),
  .bk1_scroll_y(bk1_scroll_y),
  .bk2_scroll_x(bk2_scroll_x),
  .bk2_scroll_y(bk2_scroll_y),
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

  .bk1_hpos(bk1_hpos),
  .bk1_hsync(bk1_hsync),
  .bk1_vpos(bk1_vpos),
  .bk2_hpos(bk2_hpos),
  .bk2_hsync(bk2_hsync),
  .bk2_vpos(bk2_vpos)
);

//////// VIDEO ////////////
//
// video module 
// - char, tile & sprite drawing 
// - vga sync 
//
toki_video u_video(
  .rst(rst),

  .clk(clk),
  .pxl_cen(pxl_cen),
  .pxl2_cen(pxl2_cen),

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
  .palette_addr(palette_addr),
  .palette_out(palette_out),

  //.vram_addr(vram_addr),
  .vram_out(vram_out),

  //.bk1_addr(bk1_addr),
  .bk1_out(bk1_out),

  //.bk2_addr(bk2_addr),
  .bk2_out(bk2_out),

  .sprite_addr(sprite_addr),
  .sprite_out(sprite_out),

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

  // scroll latch
  .bk1_hpos(bk1_hpos),
  .bk1_vpos(bk1_vpos),
  .bk1_hsync(bk1_hsync),
  .bk2_hpos(bk2_hpos),
  .bk2_vpos(bk2_vpos),
  .bk2_hsync(bk2_hsync),
  .bg_order(bg_order),

  .prom_26_data(prom_26_data),
  .prom_26_ok(prom_26_ok),
  .prom_26_cs(prom_26_cs),
  .prom_26_addr(prom_26_addr),

  .prom_27_data(prom_27_data),
  .prom_27_ok(prom_27_ok),
  .prom_27_cs(prom_27_cs),
  .prom_27_addr(prom_27_addr),

  .HBLB(HBLB),
  .INT_T(INT_T)
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
