////////// SCAN TILE RAM /////////////////////////////
//
// draw 16x16 tile line by line 
// RAM describe a 512x512 zone 
// current screen position is adjusted 
// by scroll_x & scroll_y register
//
module scrn_bk(
  input                 clk,
  input                 N6M,
  input                 WRN6M,
  input                 rst,

  input          [10:1] KDA,
  input                 DMSL,
  input          [17:1] MAB,
  input          [15:0] MDB,

  input                 RST_SH,
  input                 SEL_SH,
  input                 RST_SY,
  input                 SEL_SY,

  input           [7:0] hpos, 
  input           [7:0] vpos,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output         [18:1] gfx_rom_addr,
  output                gfx_rom_cs,

  output          [3:0] color,
  output          [3:0] code,
  output                sg_sync
);

wire [8:0] scrolled_hpos;
wire [8:0] scrolled_vpos;
wire s21_hsync; 

sei0021bu sei21bu_bk1_h(
   .clk(clk),
   .cen(N6M),
   .rst_n(RST_SH),
   .cs_n(SEL_SH),

   .pos(hpos[7:0]), //8 on board 
                      //SEL S1H or S2H
   .low(MAB[2]),
   .high(MAB[1]),

   .data(MDB[7:0]),
 
   .sync(s21_hsync),
   .scrolled(scrolled_hpos)
);

sei0021bu sei21bu_bk1_v(
   .clk(clk),
   .cen(N6M),
   .rst_n(RST_SY),
   .cs_n(SEL_SY),

   .pos(vpos[7:0]), //7 + T8H on board ???

   .low(MAB[2]),
   .high(MAB[1]),
   
   .data(MDB[7:0]),
   
   .sync(),
   .scrolled(scrolled_vpos)
);

assign sg_sync = scrolled_hpos[1];

jtframe_dual_ram16 #(.AW(10)) u_bk1_ram(
  .clk0(WRN6M),  //XXX NOT A REAL CLOCK ! 
  .data0(MDB[15:0]),
  .addr0(KDA[10:1]),
  .we0({~DMSL, ~DMSL}),//DMSL S1
  .q0(),

  .clk1(scrolled_hpos[0]), //XXX NOT A REAL CLOCK 
  .data1(),
  .addr1({scrolled_vpos[8:4], scrolled_hpos[8:4]}),  
  .we1(),
  .q1(ram_out)
);

// ??? CLOCK HERE  ? alwyas @ 
 //always @(clk)
   //if (scrolled_hpos[0])
     //...

assign gfx_rom_cs = 1'b1;
assign gfx_rom_addr[18:1] = {ram_out[11:0], scrolled_hpos[3], scrolled_vpos[3:0], scrolled_hpos[2]}; 

wire [15:0] ram_out;
wire s21_sync;

sei0010bu sei0010bu_u(
  .clk(N6M),
  .rst(rst),
  .load(s21_hsync),
  .rev(1'b0),
  .rom_data(gfx_rom_data),
  .color(color)
);

assign code = ram_out[15:12];

endmodule 
