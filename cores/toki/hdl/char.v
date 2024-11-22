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
module scan_char_ram(
  input                 clk,
  input                 pxl_cen,
  input                 rst,

  input           [8:0] hpos,
  input           [8:0] vpos, 

  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] char_rom_data,
  input                 char_rom_ok,
  output reg     [16:1] char_rom_addr,

  output reg      [7:0] pixel
);

reg [1:0]  pix_index;
reg [3:0]  color;
reg [15:0] rom;

always @(posedge pxl_cen) begin 
  if (~hpos[8]) begin
    pixel <= {color[3:0], {rom[{2'b11, pix_index}], rom[{2'b10, pix_index}], rom[{2'b01, pix_index}], rom[{2'b0, pix_index}] }};
  end 
end 

wire [8:0] hpos_shift;
assign hpos_shift = hpos[8:0] + 8'd4; //we start 4 pix before to prefetch char rom

always @(posedge clk,  posedge rst) begin 
  if (rst) begin
    pix_index <= 0; 
    color[3:0] <= 4'd0;
    rom <= 16'd0;
    end 
  else if (clk) begin 
    if (~hpos[8]) begin 
      pix_index <= hpos[1:0]; 

      if (hpos_shift[2:0] == 3'd0 || hpos_shift[2:0] == 3'd4) begin 
        if (char_rom_ok) begin 
          color[3:0] <= ram_out[15:12];
          rom[15:0] <= char_rom_data[15:0]; 
          end 
      end 

      if (hpos_shift[2:0] > 0 && hpos_shift[2:0]  <= 3'd3) begin
        //do we need to change ram addr ? it's the same tile XXX
        //we may need to tile 0 
        ram_addr[10:1] <= {vpos[7:3], hpos_shift[7:3]};
        char_rom_addr[16:1] <= {ram_out[11:0], vpos[2:0], 1'd0};
        end
      else if (hpos_shift[2:0] >= 3'd5) begin 
        //do we need to change ram addr ? it's the same tile XXX
        ram_addr[10:1] <= {vpos[7:3], hpos_shift[7:3]};
        char_rom_addr[16:1] <= {ram_out[11:0], vpos[2:0], 1'd1};
        end 
    end
  end
end 

endmodule
