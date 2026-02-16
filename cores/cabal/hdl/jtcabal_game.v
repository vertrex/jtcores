//Cabal MiSTer
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

module jtcabal_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
  );

assign debug_view = 0;
assign sample     = 0;
assign dip_flip   = 0;

wire P6M, N6M;

// clock 
/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk(clk),
    .cen12(),
    .cen12b(),
    .cen8(),
    .cen6(P6M),
    .cen6b(N6M),
    //.cen6b(),
    .cen3(),
    .cen1p5()
);

// main cpu 
assign cpu_rom_cs = 1'b1; 
assign cpu_rom_addr = 17'b0;

// video 
wire [8:0] vpos;
wire [8:0] hpos;

cabal_video u_video(
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

  //chars rom 
  .chars_rom_data(chars_rom_data),
  .chars_rom_ok(chars_rom_ok),
  .chars_rom_cs(chars_rom_cs),
  .chars_rom_addr(chars_rom_addr),
  //tiles rom 
  .tiles_rom_data(tiles_rom_data),
  .tiles_rom_ok(tiles_rom_ok),
  .tiles_rom_cs(tiles_rom_cs),
  .tiles_rom_addr(tiles_rom_addr),
  //sprite rom 
  .sprite_rom_data(sprite_rom_data),
  .sprite_rom_ok(sprite_rom_ok),
  .sprite_rom_cs(sprite_rom_cs),
  .sprite_rom_addr(sprite_rom_addr),
  //prom 05 
  .prom_05_data(prom_05_data),
  .prom_05_ok(prom_05_ok),
  .prom_05_cs(prom_05_cs),
  .prom_05_addr(prom_05_addr),
  //prom 10 
  .prom_10_data(prom_10_data),
  .prom_10_ok(prom_10_ok),
  .prom_10_cs(prom_10_cs),
  .prom_10_addr(prom_10_addr),
  
  .r(red),
  .g(green),
  .b(blue)
);

// music
assign snd = 16'b0;

assign audiocpu_rom_cs = 1'b0;
assign audiocpu_rom_addr = 13'b0;
assign bank_rom_cs = 1'b0;
assign bank_rom_addr = 15'b0;
assign adpcm1_rom_cs = 1'b0;
assign adpcm1_rom_addr = 16'b0;
assign adpcm2_rom_cs = 1'b0;
assign adpcm2_rom_addr = 16'b0;

endmodule
