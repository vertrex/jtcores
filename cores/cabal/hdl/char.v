////////// char ram  //////////////////////////////////
//
// Cabal text layout (MAME text_layout):
//   8x8, 2bpp, plane offsets {0,4}
//   x offsets {3,2,1,0,8+3,8+2,8+1,8+0}
//   y offsets {0*16..7*16}
//
// char RAM word:
//   [15:10] color
//   [ 9: 0] tile index
//
// output pixel:
//   [7:2] color
//   [1:0] pen
//
module scrn_char(
  input                 clk,
  input                 rst,
  input                 pxl_cen,

  input           [8:0] vpos,
  input           [8:0] hpos,

  output reg     [10:1] char_ram_addr,
  input          [15:0] char_ram_out,

  input          [15:0] char_rom_data,
  input                 char_rom_ok,
  output reg     [13:1] char_rom_addr,

  output reg      [7:0] pixel
);

reg  [5:0] color;
reg [15:0] row_bits;

always @(posedge pxl_cen) begin
    pixel <= {color, { row_bits[{hpos[2], 1'b1, hpos[1:0]}],
                       row_bits[{hpos[2], 1'b0, hpos[1:0]}]} };
end

always @(posedge clk or posedge rst) begin
  if (rst) begin
      color         <= 6'd0;
      row_bits      <= 16'd0;
      char_ram_addr <= 10'd0;
      char_rom_addr <= 13'd0;
  end else if (clk) begin
      if (hpos[2:0] > 3'd1) begin 
        char_ram_addr <= {vpos[7:3], hpos[7:3]};
        char_rom_addr <= {char_ram_out[9:0], vpos[2:0]};
      end 

      if (hpos[2:0] == 3'd0 && char_rom_ok) begin
        color    <= char_ram_out[15:10];
        row_bits <= char_rom_data[15:0];
      end
  end
end

endmodule
