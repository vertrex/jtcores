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

  input           [8:0] vpos,
  input           [8:0] hpos, 

  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output reg     [18:1] gfx_rom_addr,
  //output                gfx_rom_cs,

  input           [8:0] scroll_x,
  input           [8:0] scroll_y,

  output reg      [7:0] pixel
);

//assign gfx_rom_cs = 1'b1;
reg [1:0]  pix_index;
reg [3:0]  color;
reg [15:0] rom;

always @(posedge pxl_cen) begin 
  if (~hpos[8]) begin
    pixel <= {color[3:0], { rom[{2'b0, pix_index} + 4'd12], rom[{2'b0, pix_index} + 4'd8], 
                            rom[{2'b0, pix_index} +  4'd4], rom[{2'b0, pix_index}] }};
  end
end 

wire [8:0] hpos_shift;
assign hpos_shift = hpos[8:0] + 8'd4; //we start 4 pix before to prefetch char rom

wire [8:0] scrolled_vpos;
assign scrolled_vpos[8:0] = vpos[8:0] + scroll_y[8:0];

wire [8:0] scrolled_hpos; 
assign scrolled_hpos[8:0] = hpos_shift[8:0] + scroll_x[8:0];

always @(posedge clk,  posedge rst) begin 
  if (rst) begin
    pix_index <= 0; 
    color[3:0] <= 4'd0;
    rom <= 16'd0;
    end 
  else if (clk) begin 
    if (~hpos[8]) begin 
      //pix_index <= scrolled_hpos[1:0]; // ok 
      pix_index <= hpos[1:0] + scroll_x[1:0]; //ok 

      if (scrolled_hpos[3:0] == 4'd0 || scrolled_hpos[3:0] == 4'd4 || 
          scrolled_hpos[3:0] == 4'd8 || scrolled_hpos[3:0] == 4'd12) begin 
        if (gfx_rom_ok) begin
          color[3:0] <= ram_out[15:12];
          rom[15:0] <= gfx_rom_data[15:0]; 
          end
      end 

      if (scrolled_hpos[3:0] >= 4'd1 && scrolled_hpos[3:0]  <= 4'd3) begin
        ram_addr[10:1] <= {scrolled_vpos[8:4], scrolled_hpos[8:4]};  //+X 
        gfx_rom_addr[18:1] <= {ram_out[11:0], 1'd0, scrolled_vpos[3:0], 1'b0}; // + y
        end
      else if (scrolled_hpos[3:0] >= 4'd5 && scrolled_hpos[3:0] <= 4'd7) begin 
        ram_addr[10:1] <= {scrolled_vpos[8:4], scrolled_hpos[8:4]};  //+X 
        gfx_rom_addr[18:1] <= {ram_out[11:0], 1'd0, scrolled_vpos[3:0], 1'b1}; // + y
        end
     else if (scrolled_hpos[3:0] >= 4'd9 && scrolled_hpos[3:0] <= 4'd11) begin 
        ram_addr[10:1] <= {scrolled_vpos[8:4], scrolled_hpos[8:4]};  //+X 
        gfx_rom_addr[18:1] <= {ram_out[11:0], 1'd1, scrolled_vpos[3:0], 1'b0}; // y + x 
        end
     else if (scrolled_hpos[3:0] >= 4'd13) begin
        ram_addr[10:1] <= {scrolled_vpos[8:4], scrolled_hpos[8:4]};
        gfx_rom_addr[18:1] <= {ram_out[11:0], 1'd1, scrolled_vpos[3:0], 1'b1}; // y + x 
        end
    end
  end
end 

endmodule 
