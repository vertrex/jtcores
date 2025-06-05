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

  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output         [18:1] gfx_rom_addr,
  output                gfx_rom_cs,

  //output          [7:0] pixel
  output          [3:0] color,
  output     reg  [3:0] code
);

// FOR BOTH CHIPS : 
// SEI21BU (scroll handling ?) -> RAM  (2x sis6091) ->  ROM (BK1 / BK2) -> SEI10BU -> SG140  ? 
// FOR EACH CHIPS : 
// SEI21BU -> RAM (sis6091) -> ROM BK -> SG140 (shared with char ?) -> PALETTE RAM (sis 6091) -> UEC51
//


assign gfx_rom_cs = 1'b1;
//we need to get the first word (even)
//then the odd word that follow
//then an even word at +16 words 
//then an odd words at +16 words
//if (rom_words_index <= 1)
  //gfx_rom_addr[18:1] <= rom_index[11:0]*64 + ((({0,line_number}+{0,scroll_y_latch})%16)*2) + ({0, rom_words_index});
//else
  //gfx_rom_addr[18:1] <= rom_index[11:0]*64 + ((({0, line_number}+{0,scroll_y_latch})%16)*2) + ({0, rom_words_index}%2) + 32;

//BK1/2 ROM are 23C4100
//assign gfx_rom_addr[18:1] = LHBL ? {ram_out[11:0], scrolled_hpos[3], scrolled_vpos[3:0], scrolled_hpos[2]} : 18'hff;

//always @(posedge )
   //gfx_rom_addr[18:1] <= {ram_out[11:0], hpos[3], vpos[3:0], hpos[2]}; 
                                        //this is updated every 2 clock cycle
                                        //if sei0021bu latch during 1 clock
                                        //cycle
  // ram_out take as inpu bk_vpos/ bk_hpos 
  // so it's at clock of  scroll hpos/vpos also 
  // plus the output time of theram chip 
  //
  //so gfx rom_addr is update every pixel clock if fast enough 
  //so before we output a pixel 

//always @(negedge gfx_rom_cen) 
assign gfx_rom_addr[18:1] = {ram_out[11:0], hpos[3], vpos[3:0], hpos[2]}; 

//16 bits
//2**17 131072

sei0010bu sei0010bu_u(
  .clk(pxl_cen),
  .rst(rst),
  //just get a reset at hblank ?
  .g(gfx_rom_cen), // XXX COM FROM SEI21B0
  .rom_data(gfx_rom_data),
  .color(color)
);

// XXX how that is done on board ? 
// is that from sei21bu or sei10bu ?

// XXX ON PCB OR MIXED BY SG0140 ??
always @(posedge clk)
  if (gfx_rom_cen == 1'b1)
    code <= ram_out[15:12];

/*
sg0140 sg0140_u(
  .clk(pxl_cen), 
  .char_color(color),
  .char_code(gfx_code), //char char must be updated only each char_rom_cen that's normal 
  //must look on pcb but it must be somehow latched as we put the other part
  //of ram out in char_rom addr to get the data from the rom then in sei10bu
  //to serialize and get only pixel, we must mix wiwth the same data of
  //ram_out 
  .palette_addr(pixel)
);
*/
/*


reg [3:0]  color;
reg [15:0] rom;

wire [3:0] pix_index_3, pix_index_2, pix_index_1, pix_index_0; 

assign pix_index_3 = {2'b11, scrolled_hpos[1:0]};
assign pix_index_2 = {2'b10, scrolled_hpos[1:0]};
assign pix_index_1 = {2'b01, scrolled_hpos[1:0]};
assign pix_index_0 = {2'b00, scrolled_hpos[1:0]};

wire [8:0] scrolled_vpos;
assign scrolled_vpos[8:0] = vpos[7:0] + scroll_y[8:0];

wire [8:0] scrolled_hpos; 
assign scrolled_hpos[8:0] = hpos[7:0] + scroll_x[8:0];// + 8'd4; // + 9'd6;

assign gfx_rom_cs = 1'b1;
assign gfx_rom_addr[18:1] = LHBL ? {ram_out[11:0], scrolled_hpos[3], scrolled_vpos[3:0], scrolled_hpos[2]} : 18'hff;

//pas de + 1 == 6 pixel trop tot 
//pos 8 / 14 => 6 diff 
assign pixel = {ram_out[15:12], {gfx_rom_data[pix_index_3], gfx_rom_data[pix_index_2], gfx_rom_data[pix_index_1], gfx_rom_data[pix_index_0]}};
//assign pixel = 'hff;

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
