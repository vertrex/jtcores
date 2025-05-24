////////// SCAN TILE RAM /////////////////////////////
//
// draw 16x16 tile line by line 
// RAM describe a 512x512 zone 
// current screen position is adjusted 
// by scroll_x & scroll_y register
//
module scan_tile_ram(
  input                 clk,
  input                 pxl_cen,
  input                 rst,

  input                 LHBL,

  input           [7:0] vpos, //7:0 ? 
  input           [7:0] hpos, //7:0 ?

  //output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output         [18:1] gfx_rom_addr,
  output                gfx_rom_cs,

  input           [8:0] scroll_x,
  input           [8:0] scroll_y,

  output          [7:0] pixel
);

// FOR BOTH CHIPS : 
// SEI21BU (scroll handling ?) -> RAM  (2x sis6091) ->  ROM (BK1 / BK2) -> SEI10BU -> SG140  ? 
// FOR EACH CHIPS : 
// SEI21BU -> RAM (sis6091) -> ROM BK -> SG140 (shared with char ?) -> PALETTE RAM (sis 6091) -> UEC51



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

endmodule 
