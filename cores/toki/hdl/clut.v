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
  input      [7:0]  OOB,
  input      [10:1] KDA,
  input             DMSL_GL,
  input      [15:0] MDB,
  input             MASK,

  input      [7:0]  prom_27_data, // XXX 4 bit wide ! 
  input             prom_27_ok,

  output     [7:0]  prom_27_addr,
  output            prom_27_cs,

  output      [3:0] R,
  output      [3:0] G,
  output      [3:0] B
);

// SEI0140 / SG0140  1H
wire [7:0] s1_s4_out;
wire S4ON, S1ON;

sg0140    sg0140_u(
  .clk(clk),
  .cen(N6M), 
  .MODE(2'b00), //  ABSEL

  .PIC_A(S1PIC),
  .COL_A(S1COL), 
  .COL_A_EN(S1CLLT),
  .MASK_A(S1MASK),

  .PIC_B(S4PIC),
  .COL_B(S4COL), 
  .COL_B_EN(S4CLLT),
  .MASK_B(S4MASK),

  .ON_A(S1ON),
  .ON_B(S4ON),
  
  .Q(s1_s4_out) 
); 

// PROM 27 3J
assign prom_27_cs = 1'b1;
// XXX PRIOR_A IS WRONG AT TLEAST ON THE POCKET THAT MAKE STRANGE THINGS 
// IT's some time 0 when it should be 1 (it's active low) 
// it seems because of  MDB_IN on main.v that switch ram/cpu 
// may be make two different bus  rather than one shared ? 
// tryied to switch to cpu by default may be better

                                                                  //s2on      //OBJON //S4ON
assign  prom_27_addr[7:0] = { PRIOR_D, PRIOR_C, PRIOR_B, PRIOR_A, S2ON, 1'b0, S4ON, S1ON };
//assign  prom_27_addr[7:0] = { PRIOR_D, PRIOR_C, PRIOR_B, PRIOR_A, 1'b0, 1'b0, S4ON, S1ON };
// 74LS257 2H, 3H 
// 74LS258 
// 74LS246 1C 
// SIS6091 5H
  //palette_addr[10:1] <=  //OBJON ? { prom_27_data[3:2], OOB[7:0] } :

  /* 
always @(posedge clk) begin
   //N6M ? 
   if (prom_27_data[0]) begin 
     if (prom_27_data[1] == 1'b0)  
       palette_addr <= { prom_27_data[3:2], s1_s4_out[7:0] }; 
     else 
       palette_addr <= { prom_27_data[3:2], SCRN2[7:0] };
   end 
 end
 */

//* 
//always @(posedge clk) begin
   //N6M ? 
   //if (prom_27_data[0]) begin 
     //if (prom_27_data[1] == 1'b0)  
       //palette_addr <= { prom_27_data[3:2], s1_s4_out[7:0] }; 
     //else 
       //palette_addr <= { prom_27_data[3:2], SCRN2[7:0] };
   //end 
 //end
 //*/

assign palette_addr[10:1] =   //prom_27_data[0] == 1'b1 ?  { prom_27_data[3:2], OOB[7:0] } : 
                             prom_27_data[1] == 1'b0 ?  { prom_27_data[3:2], s1_s4_out[7:0] } :
                                                        { prom_27_data[3:2], SCRN2[7:0] };



wire [10:1] palette_addr;
wire [15:0] palette_out;

///////// PALETTE RAM //////////
// palette ram (2048)
// populated by DMA 
sis6091 #(.AW(10)) u_palette_ram(
  .clk0(clk),
  //.cen0(WRN6M),
  .cen0(WRN6M),
  .data0(MDB[15:0]),
  .addr0(KDA[10:1]),
  .we0({~DMSL_GL, ~DMSL_GL}), //DSML GL
  .q0(),

  .clk1(clk),
  .cen1(P6M), 
  .data1(),
  .addr1(palette_addr[10:1]),
  .we1({1'b0, 1'b0}),
  .q1(palette_out[15:0])
);

// UEC-51  6H
assign R = ~MASK ? palette_out[3:0] : 4'b0;
assign G = ~MASK ? palette_out[7:4] : 4'b0;
assign B = ~MASK ? palette_out[11:8] : 4'b0;

endmodule
