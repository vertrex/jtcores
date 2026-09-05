// color mixing clut page 10
///////// COLOR MIX & OUTPUT ////////////////////////////
//
// select the right pixel from the different line buffer 
// go from top layer (char) to background layer
// check background order
// check if pixel is transparent
// get first non-transparent pixel 
// get pixel final color from the palette
// output the pixel to the screen
//
// PCB provenance: sheet 10. PROM27 address wiring and the palette/mux contract
// are kept directly; SG0140 ABSEL is behavioral and palette SIS6091 storage is
// synchronous FPGA RAM. The UEC-51 plus resistor/DAC analogue output stage is
// intentionally represented as digital 4-bit RGB and blanking.
//
module CLUT(
  input             clk,
  input             N6M,
  input             P6M,
  input             WRN6M,
  input      [3:0]  S1PIC,
  input      [3:0]  S1COL,
  input      [3:0]  S4PIC,
  input      [3:0]  S4COL,
  input             S1CLLT,
  input             S4CLLT,
  input             S1MASK,
  input             S4MASK,
  input      [7:0]  SCRN2,
  input             OBJON,
  input             S2ON,
  input             PRIOR_A,
  input             PRIOR_B,
  input             PRIOR_C,
  input             PRIOR_D,
  input      [7:0]  OOD,
  input      [10:1] KDA,
  input             DMSL_GL,
  input      [15:0] MDB,
  input             MASK,

  input      [7:0]  prom_27_data, // XXX 4 bit wide ! 

  output     [7:0]  prom_27_addr,

  output      [3:0] R,
  output      [3:0] G,
  output      [3:0] B
);

// SEI0140 / SG0140  1H
wire [7:0] s1_s4_out;
wire S4ON, S1ON;

sg0140_absel    sg0140_absel_u(
  .clk(clk),
  //.rst(1'b0),
  // Sheet 10 ties SG0140 pins 41/38/26 to the physical N6M waveform.
  // Joint pin-22..27 captures show the mixed Q outputs publishing on the
  // falling edge of that waveform, after the source serializers change on
  // its rising edge. P6M is the common-clock enable for that opposite edge.
  .cen(P6M), //XXX N6M on schematics

  .PIC_A(S1PIC),
  .COL_A(S1COL), 
  .COL_A_EN(S1CLLT),
  .MASK_A(S1MASK),

  .PIC_B(S4PIC),
  .COL_B(S4COL), 
  .COL_B_EN(S4CLLT),
  .MASK_B(S4MASK),
  .MODE(2'b00), //  ABSEL

  //output 
  .Q(s1_s4_out),
  .ON_A(S1ON),
  .ON_B(S4ON)
); 

// PROM 27 3J. 
// U34 latch;
// Sheet 10 U102/82S129: A0=S1ON, A1=S4ON, A2=OBJON,
// A3=S2ON, then PRIOR A..D on A4..A7.
assign  prom_27_addr[7:0] = { PRIOR_D, PRIOR_C, PRIOR_B, PRIOR_A, S2ON, OBJON, S4ON, S1ON };
// 74LS257 2H, 3H 
// 74LS258 
// 74LS246 1C 
// SIS6091 5H

wire [10:1] palette_addr;
wire [15:0] palette_out;

assign palette_addr[10:1] =  
                             prom_27_data[0] == 1'b1 ?  { prom_27_data[3:2], OOD[7:0] } : 
                             prom_27_data[1] == 1'b0 ?  { prom_27_data[3:2], s1_s4_out[7:0] } :
                                                        { prom_27_data[3:2], SCRN2[7:0] };

///////// PALETTE RAM //////////
// palette RAM: 1024 x 16 bits
// populated by DMA 
sis6091 u_palette_ram(
  .clk(clk),
  .wr_cen(~WRN6M),
  .wr_en(~DMSL_GL), //DSML GL
  .wr_data(MDB[15:0]),
  .wr_addr(KDA[10:1]),

  .rd_cen(~P6M), //use N6M ? 
  .rd_addr(palette_addr[10:1]),
  .rd_data(palette_out[15:0])
);

// UEC-51  6H
assign R = ~MASK ? palette_out[3:0] : 4'b0;
assign G = ~MASK ? palette_out[7:4] : 4'b0;
assign B = ~MASK ? palette_out[11:8] : 4'b0;

endmodule
