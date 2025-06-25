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
module char(
  input                 clk,
  input                 rst,
  input                 T8H,  //T8H char_cen 
  input                 T3F, //T3F char_rom_cen

  input           [7:0] hpos, //8:0
  input           [7:0] vpos, //8:0
  input                 hrev,

  input          [15:0] ram_out,  //code [11:0], pal 15:12

  input          [7:0]  char_rom_1_data,
  input                 char_rom_1_ok,
  output         [15:0] char_rom_1_addr,
  output                char_rom_1_cs,

  input          [7:0]  char_rom_2_data,
  input                 char_rom_2_ok,
  output         [15:0] char_rom_2_addr,
  output                char_rom_2_cs,

  output         [3:0]  char_color, //pic  
  output         [3:0]  char_code   //col
);

// SEI50BU -> RAM (sis6091) -> ROM -> SEI10BU -> SG0140 -> PALETTE RAM -> UEC51 
reg [2:0] vpos_latch;

//74LS74 8B clock T8H
always @(posedge T8H) begin
   vpos_latch[2:0] <= vpos[2:0];
end
//hpos2 is latched too ? (hpos/4)

assign char_rom_1_cs = 1'b1;
assign char_rom_2_cs = 1'b1;

//page 6 
//74LS368  exh<4> -> exh<4>/4
assign char_rom_1_addr[15:0] =  {ram_out[11:0], vpos_latch[2:0], ~hpos[2]} ;  
assign char_rom_2_addr[15:0] =  {ram_out[11:0], vpos_latch[2:0], ~hpos[2]} ; 
//assign char_rom_1_addr[15:0] =  {ram_out[11:0], vpos_latch[2:0], hpos[2]} ;  
//assign char_rom_2_addr[15:0] =  {ram_out[11:0], vpos_latch[2:0], hpos[2]} ; 

// latch / serialize pixel
sei0010bu sei0010bu_u(
  .clk(clk),
  .rst(rst),
  .load(T3F), //load new pixel
  .rev(),
  .rom_data({char_rom_2_data[7:0], char_rom_1_data[7:0]}),
  .color(char_color)
);
    
//seem like that on the sch
assign char_code = ram_out[15:12];

endmodule
