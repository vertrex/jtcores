////////// SCAN TILE RAM /////////////////////////////
//
// draw 16x16 tile line by line 
// RAM describe a 512x512 zone 
// current screen position is adjusted 
// by scroll_x & scroll_y register
//
module bk(
  input                 clk,
  input                 pxl_cen,

  input                 gfx_cen,
  input                 gfx_rom_cen,

  input                 rst,

  input                 LHBL,

  input           [8:0] hpos, //scrolled pos 
  input           [8:0] vpos, //scrolled pos 
  input                 hpos_sync,

  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output         [18:1] gfx_rom_addr,
  output                gfx_rom_cs,

  output          [3:0] color,
  output     reg  [3:0] code
);

assign gfx_rom_cs = 1'b1;
//we need to get the first word (even)
//then the odd word that follow
//then an even word at +16 words 
//then an odd words at +16 words
//if (rom_words_index <= 1)
  //gfx_rom_addr[18:1] <= rom_index[11:0]*64 + ((({0,line_number}+{0,scroll_y_latch})%16)*2) + ({0, rom_words_index});
//else
  //gfx_rom_addr[18:1] <= rom_index[11:0]*64 + ((({0, line_number}+{0,scroll_y_latch})%16)*2) + ({0, rom_words_index}%2) + 32;

assign gfx_rom_addr[18:1] = {ram_out[11:0], hpos[3], vpos[3:0], hpos[2]}; 

//16 bits
//2**17 131072

sei0010bu sei0010bu_u(
  .clk(pxl_cen),
  .rst(rst),
  //just get a reset at hblank ?
  //.g(hpos_sync), // XXX COM FROM SEI21B0
  .load(gfx_rom_cen), // XXX COM FROM SEI21B0 XXX reset with scroll ?
  .rev(1'b0),
  .rom_data(gfx_rom_data),
  .color(color)
);


//clock is output of sei21bu hpos[1] !
always @(posedge hpos[1]) begin 
    code <= ram_out[15:12];
end 

/*
always @(posedge pxl_cen) begin 
  if (LHBL) begin 
    //pixel <= {color[3:0], {rom[pix_index_3],rom[pix_index_2],rom[pix_index_1],rom[pix_index_0]} };
    if (scrolled_hpos[1:0] == 2'd3) begin //every 4 pix we need to load
       if (gfx_rom_ok) begin
        color[3:0] <= ram_out[15:12];
        rom[15:0] <= gfx_rom_data[15:0]; 
        end
      end 
    end
    //else
    //pixel <= 'hff;
end 


*/
endmodule 
