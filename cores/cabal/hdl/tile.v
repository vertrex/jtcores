////////// bk ram  //////////////////////////////////
//
//
module scrn_bk(
  input                 clk,
  input                 rst,
  input                 pxl_cen,

  input           [8:0] vpos,
  input           [8:0] hpos,

  output reg      [8:1] tile_ram_addr,
  input          [15:0] tile_ram_out,

  input          [15:0] bk_rom_data,
  input                 bk_rom_ok,
  output reg     [18:1] bk_rom_addr,

  output          [3:0] color,
  output reg      [3:0] code
);


always @(posedge clk) begin
  //reload tile every 16 pixel
  if (hpos[1:0] == 2'b00) begin
      tile_ram_addr <= {vpos[7:4], hpos[7:4]};
  end 
end 

always @(posedge clk) begin 
  if (~pxl_cen) begin 
     //we fetch rom every 4 pixel 
     if (hpos[1:0] == 2'b01) begin
        bk_rom_addr[18:1] <= {tile_ram_out[11:0], hpos[3], vpos[3:0], hpos[2]};
    end
  end 
end 

wire [1:0] NC;
reg load; 

always @(posedge clk) 
  if (pxl_cen)
    load <= (hpos[1:0] == 2'b11);

sei0010bu sei0010bu_u(
  .clk(clk),
  .rst(rst),
  .cen(pxl_cen),
  .load(load),
  .rev(1'b0),
  .rom_data({8'b0, bk_rom_data}),
  .color({NC[1:0], code})
);

assign color = tile_ram_out[15:12];

endmodule
