////////// char ram  //////////////////////////////////
//
// State machine that draw a line of 8x8 tile
// each time line number change.
// RAM is fully scanned, address in ram give 
// tile position on screen, there is 32 tiles by line
// RAM data describe a tile :
//  -  [3:0] color
//  - [11:0] index of tile in ROM 
//  
//  Tile data are DWORD stored in ROM as 4 bit planes 
//  second dword of each data is at address + 0x8000
//
//  each pixel of tile are 8 bits : 
//    4 bits color, 4 bits index (rom data)
//  pixel are transparent if ROM data is 0xf
//  pixel value is an index into the video palette 
//
module char_ram(
  input                 clk,
  input                 pxl_cen,
  input                 char_cen,
  input                 char_rom_cen,
  input                 rst,

  input                 LHBL,

  input           [7:0] hpos, //8:0
  input           [7:0] vpos, //8:0

  //output reg     [10:1] ram_addr, //vram_addr 
  input          [15:0] ram_out,  //code [11:0], pal 15:12

  input          [15:0] char_rom_data,
  input                 char_rom_ok,
  output         [16:1] char_rom_addr,
  output                char_rom_cs,

  output          [7:0] pixel
);
assign char_rom_cs = 1'b1;

reg [3:0] palette;
wire [3:0] color;

sei0010bu sei0010bu_u(
  .clk(pxl_cen),
  .rst(rst),
  .pos(hpos[1:0]),
  .g(char_rom_cen),
  .rom_data(char_rom_data[15:0]),
  .color(color)
);


//XXX still 9:14 shift (6 pix off) with latch
//without latch there is also 6 ??? 
//74LS174
reg [2:0] vpos_latch;

always @(posedge char_cen) begin
  vpos_latch[2:0] <= vpos[2:0];
  palette <= ram_out[15:12]; //not in original !!! XXX 
end 
//hpos[2] ?? seem always up on the mobo ... check it 
//ram_out from 6091 what clocking ?
//on board ~hpos[2] (vpos_latch seems equal to vpos ...)
//maybe ram take one more cycle that's why we have ~hpos2
//assign pixel = {ram_out[15:12], color};
assign pixel = {palette, color};
//assign char_rom_addr[16:1] = {ram_out[11:0], vpos_latch[2:0], ~hpos[2]}; //latch vpos/hpos ? because ram_out use vpos/hpos so it must way 
assign char_rom_addr[16:1] = {ram_out[11:0], vpos_latch[2:0], hpos[2]}; //latch vpos/hpos ? because ram_out use vpos/hpos so it must way 


endmodule
