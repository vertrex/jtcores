module cabal_video(
  input             rst,

  // Clock
  input             clk,
  input             P6M,
  input             N6M,

  // Video out
  input       [3:0] gfx_en, // debug : graphical layer enable

  output            HS,
  output            VS,
  output            LHBL,
  output            LVBL,
  output      [8:0] hpos,
  output      [8:0] vpos,

  //chars rom
  input      [15:0] chars_rom_data,
  input             chars_rom_ok,
  output reg [12:0] chars_rom_addr,
  output            chars_rom_cs,
  //chars rom
  input      [15:0] tiles_rom_data,
  input             tiles_rom_ok,
  output reg [17:0] tiles_rom_addr,
  output            tiles_rom_cs,
   //chars rom
  input      [15:0] sprite_rom_data,
  input             sprite_rom_ok,
  output reg [17:0] sprite_rom_addr,
  output            sprite_rom_cs, 
  //prom 05
  input      [7:0]  prom_05_data,
  input             prom_05_ok,
  output reg [7:0]  prom_05_addr,
  output            prom_05_cs,
  //prom 10
  input      [7:0]  prom_10_data,
  input             prom_10_ok,
  output reg [7:0]  prom_10_addr,
  output            prom_10_cs,

  // RGB out
  output [3:0]      r,
  output [3:0]      g,
  output [3:0]      b
);

////////// VIDEO SYNC /////////////
//
wire HBL;
wire L3;
wire HD;
wire VSYNC; //seems to be ~ sei0050bu XXX (page 5)
wire T8H;
wire T3F;
wire T4H;
wire VCLK;
wire N1H;

SEI0050BU sei0050bu_u(
  .clk(clk),
  .rst(rst),
  .P6M(P6M),
  .N6M(N6M),

  .VBL_ROM(VBL_ROM),
  .hpos(hpos),
  .vpos(vpos),

  .N1H(N1H),
  .T8H(T8H), //char cen
  .HBL(HBL),
  .L3(L3),
  .T3F(T3F),
  .T4H(T4H),
  .HD(HD),
  .VSYNC(VSYNC),
  .VCLK(VCLK),
  .HS(HS),
  .VS(VS)
);


wire VBL_ROM;

assign prom_05_cs = 1'b1;

always @(posedge clk)
  if (~N6M) begin
    prom_05_addr[7:0] <= vpos[7:0]; // generate CPU VBLANK on O5 (pin 6)
  end


// XXX we use that one like in Toki 
assign VBL_ROM = prom_05_data[7];
assign VBL_ROM = VSYNC; 

assign LVBL = VBL_ROM;
assign LHBL = HBL; // ?

// rom 
assign chars_rom_addr = 13'b0; 
assign chars_rom_cs = 1'b0;
assign tiles_rom_addr = 18'b0;
assign tiles_rom_cs = 1'b0;
assign sprite_rom_addr = 18'b0;
assign sprite_rom_cs = 1'b0;
assign prom_10_addr = 8'b0;
assign prom_10_cs = 1'b0;

//DAC  output 
assign r = 4'hf;
assign g = 4'h0;
assign b = 4'h0;

endmodule
