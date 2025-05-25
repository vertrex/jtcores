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

  output          [7:0] pixel
);

// FOR BOTH CHIPS : 
// SEI21BU (scroll handling ?) -> RAM  (2x sis6091) ->  ROM (BK1 / BK2) -> SEI10BU -> SG140  ? 
// FOR EACH CHIPS : 
// SEI21BU -> RAM (sis6091) -> ROM BK -> SG140 (shared with char ?) -> PALETTE RAM (sis 6091) -> UEC51
//

wire [3:0] color;
reg [3:0] palette;
//SEI21BU ??? 
//
// 
assign gfx_rom_cs = 1'b1;
//assign gfx_rom_addr[18:1] = LHBL ? {ram_out[11:0], scrolled_hpos[3], scrolled_vpos[3:0], scrolled_hpos[2]} : 18'hff;
assign gfx_rom_addr[18:1] = {ram_out[11:0], hpos[3], vpos[3:0], hpos[2]};

sei0010bu sei0010bu_u(
  .clk(pxl_cen),
  .rst(rst),
  .g(gfx_rom_cen),
  //.rom_data(char_rom_data[15:0]),
  //.rom_data({char_rom_2_data[7:0], char_rom_1_data[7:0]}),
  .rom_data(gfx_rom_data),
  .color(color)
);

reg [3:0] gfx_code;

always @(posedge clk)
  if (gfx_rom_cen == 1'b1)
    gfx_code <= ram_out[15:12];


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
