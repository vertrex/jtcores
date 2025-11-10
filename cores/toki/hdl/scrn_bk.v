////////// SCAN TILE RAM /////////////////////////////
//
// draw 16x16 tile line by line 
// RAM describe a 512x512 zone 
// current screen position is adjusted 
// by scroll_x & scroll_y register
//
module scrn_bk(
  input                 clk,
  input                 rst,
  input                 N6M,
  input                 WRN6M,

  input          [10:1] KDA,
  input                 DMSL,
  input          [17:1] MAB,
  input          [15:0] MDB_RAM_OUT,
  input          [15:0] MDB_CPU_OUT,

  input                 RST_SH,
  input                 SEL_SH,
  input                 RST_SY,
  input                 SEL_SY,

  input           [8:0] hpos, 
  input           [8:0] vpos,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output  reg    [18:1] gfx_rom_addr,
  output                gfx_rom_cs,

  output          [3:0] color,
  output          [3:0] code,
  output                sg_sync
);

wire [8:0] scrolled_hpos;
wire [8:0] scrolled_vpos;
wire s21_hsync; 

//XXX SHIFT BY 3 PIXEL 

sei0021bu sei21bu_bk1_h(
   .clk(clk),
   .cen(N6M),
   .rst_n(RST_SH),
   .cs_n(SEL_SH),

   .pos(hpos[8:0]), //8 on board 
                      //SEL S1H or S2H
   .low(MAB[2]),
   .high(MAB[1]),

   .data(MDB_CPU_OUT[7:0]),
 
   .sync(s21_hsync),
   .scrolled(scrolled_hpos)
);

sei0021bu sei21bu_bk1_v(
   .clk(clk),
   .cen(N6M),
   .rst_n(RST_SY),
   .cs_n(SEL_SY),

   .pos(vpos[8:0]), //7 + T8H on board ???

   .low(MAB[2]),
   .high(MAB[1]),
   
   .data(MDB_CPU_OUT[7:0]),
   
   .sync(),
   .scrolled(scrolled_vpos)
);

assign sg_sync = scrolled_hpos[1];

wire [15:0] ram_out;

sis6091 #(.AW(10)) u_bk1_ram(
  .clk0(clk),
  .cen0(WRN6M),
  .data0(MDB_RAM_OUT[15:0]),
  .addr0(KDA[10:1]),
  .we0({~DMSL, ~DMSL}),//DMSL S1
  .q0(),

  .clk1(clk),
  .cen1(scrolled_hpos[1:0] == 2'b00), //X?? 
  .data1(),
  .addr1({scrolled_vpos[8:4], scrolled_hpos[8:4]}),  
  .we1({1'b0, 1'b0}),
  .q1(ram_out)
);

assign gfx_rom_cs = 1'b1;
//ram_out clock :  scrolled_hpos[0] 
//scrolled_hpos clock : N6M 
//scrolled_vpos clock : N6M 

always @(posedge clk) begin 
  if (~N6M) begin  //bcp moins de glitch ! 
     if (scrolled_hpos[1:0] == 2'b01) begin // XXX THIS WHAT MAKE GLITCH !!!!!!h
       //IF s21_hsync on voie clairemnet les bar sans le gitch au dcebut donc
       //decalage de 128 trouver la bonne vlaue ici ou dans le sei021bu
      //put only gfx_rom_cs here ? 
      gfx_rom_addr[18:1] <= {ram_out[11:0], scrolled_hpos[3], scrolled_vpos[3:0], scrolled_hpos[2]}; 
    end
  end 
end 

reg [15:0] data; 

//it some time glitch because there is not enough throughptu ?
always @(posedge clk) begin 
  if (gfx_rom_ok)
    data <= gfx_rom_data;
  else 
    data <= 16'hffff;
end 

wire [1:0] NC;

sei0010bu sei0010bu_u(
  .clk(clk),
  .rst(rst),
  .cen(N6M),
  .load(s21_hsync),
  .rev(1'b0),
  .rom_data({8'b0, data}),
  .color({NC[1:0], color})
);

assign code = ram_out[15:12];

endmodule 
