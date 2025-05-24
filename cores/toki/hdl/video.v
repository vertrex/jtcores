////////// VIDEO ////////////////////////////////////////////
//
// - video synchronization (hsync, vsync, vblank, hblank)
// - char, bg1, bg2, sprite drawing  
// - char, bg1, bg2, sprite mixing & output 
//
module toki_video(
  input             rst,

  // Clock
  input             clk,
  input             cpu_cen,
  input             pxl_cen,
  input             pxl2_cen,

  // Video out
  input       [3:0] gfx_en, // debug : graphical layer enable

  output            HS,
  output            VS, 
  output            LHBL, 
  output            LVBL,
  output      [8:0] hpos,
  output      [8:0] vpos, 

  // RGB out
  output [3:0]      r,
  output [3:0]      g,
  output [3:0]      b,

  // Shared video RAM
  output     [10:1] palette_addr,
  input      [15:0] palette_out,

  //output     [10:1] vram_addr,
  input      [15:0] vram_out,

  //output     [10:1] bg1_addr,
  input      [15:0] bg1_out,

  //output     [10:1] bg2_addr,
  input      [15:0] bg2_out,

  output     [10:1] sprite_addr,
  input      [15:0] sprite_out,

  // ROM data
  //input      [15:0] gfx1_rom_data,
  //input             gfx1_rom_ok,
  //output     [16:1] gfx1_rom_addr,
  //output            gfx1_rom_cs,

  //input      [15:0] char_rom_data,
  //input             char_rom_ok,
  //output     [16:1] char_rom_addr,
  //output            char_rom_cs,
  
  input       [7:0] char_rom_1_data,
  input             char_rom_1_ok,
  output     [15:0] char_rom_1_addr,
  output            char_rom_1_cs,

  input       [7:0] char_rom_2_data,
  input             char_rom_2_ok,
  output     [15:0] char_rom_2_addr,
  output            char_rom_2_cs,

  input      [15:0] gfx2_rom_data,
  input             gfx2_rom_ok,
  output     [19:1] gfx2_rom_addr,
  output            gfx2_rom_cs,

  input      [15:0] gfx3_rom_data,
  input             gfx3_rom_ok,
  output     [18:1] gfx3_rom_addr,
  output            gfx3_rom_cs,

  input      [15:0] gfx4_rom_data,
  input             gfx4_rom_ok,
  output     [18:1] gfx4_rom_addr,
  output            gfx4_rom_cs,

  // Scroll latch
  input      [8:0]  bg1_scroll_x,
  input      [8:0]  bg1_scroll_y,
  input      [8:0]  bg2_scroll_x,
  input      [8:0]  bg2_scroll_y,
  input             bg_order,

  output            char_cen,

  input      [7:0]  prom_26_data,
  input             prom_26_ok,
  output     [7:0]  prom_26_addr,
  output            prom_26_cs,

  input      [7:0]  prom_27_data,
  input             prom_27_ok,
  output     [7:0]  prom_27_addr,
  output            prom_27_cs

);

////////// VIDEO SYNC /////////////
//
wire char_rom_cen;

assign prom_26_cs = 1'b1;
assign prom_27_cs = 1'b1;

assign prom_26_addr[7:0] = vpos[7:0]; // generate CPU VBLANK on O5 (pin 6)  
assign prom_27_addr[7:0] = vpos[7:0]; // ?? use for color mixing 

//cpu_irq = prom_26_addr[6]; cpu lvbl irq

// HV SYNC
SEI0050BU sei0050bu_u(
  .clk(clk),
  .pxl_cen(pxl_cen),
  .rst(rst),

  .HS(HS),
  .VS(VS),
  .LHBL(LHBL),
  .LVBL(LVBL),

  .hpos(hpos),
  .vpos(vpos),
  .char_cen(char_cen),
  .char_rom_cen(char_rom_cen)
);

///////// CHAR DRAWING //////////
//
// char : 8x8 tile 
//
parameter VRAM_PALETTE_OFFSET = 10'h100;

wire [7:0] char_pixel;

char_ram char_ram_u(
  .clk(clk),
  .pxl_cen(pxl_cen),
  .char_cen(char_cen),
  .char_rom_cen(char_rom_cen),

  .rst(rst),

  .LHBL(LHBL), //XXX is that this one ?

  .hpos(hpos[7:0]),
  .vpos(vpos[7:0]),
  
  .ram_out(vram_out),

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

  .pixel(char_pixel)
);


///////// BG1 DRAWING /////////////////
//
// background 1 : 16x16 tile 
//
parameter BG1_PALETTE_OFFSET = 10'h200;

wire  [7:0] bg1_pixel;

scan_tile_ram bg1_scan_tile_ram_u(
  .clk(clk),
  .pxl_cen(pxl_cen),

  .gfx_cen(char_cen),  // XXX check signal on board 
  .gfx_rom_cen(char_rom_cen),  // XXX check signal on board 

  .rst(rst),

  .LHBL(LHBL), //XXX
  .hpos(hpos[7:0]),
  .vpos(vpos[7:0]),

  //.ram_addr(bg1_addr),
  .ram_out(bg1_out),

  .gfx_rom_data(gfx3_rom_data),
  .gfx_rom_ok(gfx3_rom_ok),
  .gfx_rom_addr(gfx3_rom_addr),
  .gfx_rom_cs(gfx3_rom_cs),

  .scroll_x(bg1_scroll_x),
  .scroll_y(bg1_scroll_y),

  .pixel(bg1_pixel)
);

///////// BG2 DRAWING /////////////////
//
// background 2 : 16x16 tile 
//
parameter BG2_PALETTE_OFFSET = 10'h300;

wire    [7:0] bg2_pixel;

scan_tile_ram bg2_scan_tile_ram_u(
  .clk(clk),
  .pxl_cen(pxl_cen),

  .gfx_cen(char_cen), // XXX check signal on board 
  .gfx_rom_cen(char_rom_cen), // XXX check signal on board

  .rst(rst),

  .LHBL(LHBL), //XXX
  .hpos(hpos[7:0]),
  .vpos(vpos[7:0]),

  //.ram_addr(bg2_addr),
  .ram_out(bg2_out),

  .gfx_rom_data(gfx4_rom_data),
  .gfx_rom_ok(gfx4_rom_ok),
  .gfx_rom_addr(gfx4_rom_addr),
  .gfx_rom_cs(gfx4_rom_cs),

  .scroll_x(bg2_scroll_x),
  .scroll_y(bg2_scroll_y),

  .pixel(bg2_pixel)
);

///////// SPRITE DRAWING /////////////////
//
// sprite : 16x16 tile 
//
//wire        sprite_used;
wire  [7:0] sprite_line_buffer_out;
reg   [8:0] sprite_line_buffer_addr;

scan_sprite_ram scan_sprite_ram_u(
  .clk(clk),
  .pxl_cen(pxl_cen),
  
  .rst(rst),

  .LHBL(LHBL), //XXX

  .vpos(vpos), //we calculate 1 line head because of buffering , hpos + 2??

  .ram_addr(sprite_addr),
  .ram_out(sprite_out),

  .gfx_rom_data(gfx2_rom_data),
  .gfx_rom_ok(gfx2_rom_ok),
  .gfx_rom_addr(gfx2_rom_addr),
  .gfx_rom_cs(gfx2_rom_cs),

  .line_buffer_addr(hpos), //+ 1 ?
  .line_buffer_out(sprite_line_buffer_out)
);

///////// COLOR MIX & OUTPUT ////////////////////////////
//
// select the right pixel from the different line buffer 
// go from top layer (char) to background layer
// check background order
// check if pixel is transparent
// get first non-transparent pixel 
// get pixel final color from the palette
// output the pixel to the screen
//

//
// SG0140 out ? 
//
// MIX MUST ASSIGN ? 
// there is no clcok
// it only use rom27 for stuff ?? 
// and simple chip select 
// to assign to ram

//color mix 
//must use rom27
assign palette_addr = 
          char_pixel[3:0] != 'hf ? {2'd0, char_pixel} + VRAM_PALETTE_OFFSET :
          sprite_line_buffer_out[3:0] != 'hf ? {2'd0, sprite_line_buffer_out} : 
          bg_order == 1'b0 & bg1_pixel[3:0] != 'hf ? {2'd0, bg1_pixel} + BG1_PALETTE_OFFSET :
          bg_order == 1'b0 & bg2_pixel[3:0] != 'hf ? {2'd0, bg2_pixel} + BG2_PALETTE_OFFSET :
          bg_order == 1'b1 & bg2_pixel[3:0] != 'hf ? {2'd0, bg2_pixel} + BG2_PALETTE_OFFSET :
          bg_order == 1'b1 & bg1_pixel[3:0] != 'hf ? {2'd0, bg1_pixel} + BG1_PALETTE_OFFSET :
          'h3ff;

// UEC-51 
assign r = palette_out[3:0];
assign g = palette_out[7:4];
assign b = palette_out[11:8];

endmodule
