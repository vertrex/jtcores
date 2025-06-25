////////// SCAN TILE RAM /////////////////////////////
//
// draw 16x16 tile line by line 
// RAM describe a 512x512 zone 
// current screen position is adjusted 
// by scroll_x & scroll_y register
//
module bk(
  input                 pxl_cen,
  input                 rst,

  input           [8:0] hpos, //scrolled pos 
  input           [8:0] vpos, //scrolled pos 
  input                 hpos_sync,

  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output         [18:1] gfx_rom_addr,
  output                gfx_rom_cs,

  output          [3:0] color,
  output          [3:0] code
  //output          reg [3:0] code
);

assign gfx_rom_cs = 1'b1;
assign gfx_rom_addr[18:1] = {ram_out[11:0], hpos[3], vpos[3:0], hpos[2]}; 

//16 bits
//2**17 131072

sei0010bu sei0010bu_u(
  .clk(pxl_cen),
  .rst(rst),
  //.g(hpos_sync), // XXX COM FROM SEI21B0
  .load(hpos_sync), // XXX COM FROM SEI21B0 XXX reset with scroll ?
  .rev(1'b0),
  .rom_data(gfx_rom_data),
  .color(color)
);

assign code = ram_out[15:12];

// XXX only on bk2 ? the other is latch by sg0140 ? 
//clock is output of sei21bu hpos[1] !
//always @(posedge hpos[1]) begin 
    //code <= ram_out[15:12];
//end 

endmodule 
