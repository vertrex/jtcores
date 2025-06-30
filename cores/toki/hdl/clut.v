module CLUT(
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

//
// SG0140 out ? 
//
// MIX MUST ASSIGN ? 
// there is no clcok
// it only use rom27 for stuff ?? 
// and simple chip select 
// to assign to ram

///////// PALETTE RAM //////////
// 
// palette ram (2048)
// palette is read and checked by main cpu 
// H4 on PCB behind UEC-51
//wire [15:0]  palette_do;

wire [10:1] palette_addr;
wire [15:0] palette_out;

jtframe_dual_ram16 #(.AW(10)) u_palette_ram(
  .clk0(WRN6M),
  .data0(MDB[15:0]),
  .addr0(KDA[10:1]),
  .we0({~DMSL_GL, ~DMSL_GL}), //DSML GL
  .q0(),

  .clk1(P6M), 
  .data1(),
  .addr1(palette_addr[10:1]),
  .we1(),
  .q1(palette_out[15:0])
);

wire [7:0] sg_palette_addr;
wire [1:0] pri;

sg0140    sg0140_u(
  .clk(N6M), 

  .char_color(S4PIC),
  .char_code(S4COL), 
  .char_en(S4CLLT),
  .char_mask(S4MASK),

  .bk1_color(S1PIC),
  .bk1_code(S1COL), 
  .bk1_en(S1CLLT),
  .bk1_mask(S1MASK),

  .pri(pri),
  .palette_addr(sg_palette_addr) 
); 

// XXX OFFSET IS GIVEN BY ROM27 ! 
//give us PALETTE_OFFSET rom27_addr <- sg0x140 
//palette_offset <= 
wire [1:0] palette_offset;
wire unknown_a2 = 1'b0;
wire [1:0] unknown_a6_a7 = 2'b0;


//s1 sc1 => bk1 ? 
//sc2 s2 => bk2
//sc4 s4 => char 

//color mixing clut page 10
// XXX BK2 is latched before input into palette page 8 with P6M clck 

//74LS20P check if color != 'hf XXX used latched value
//page 10
assign prom_27_cs = 1'b1;
assign prom_27_addr[7:0] = { PRIOR_D, PRIOR_C, PRIOR_B, PRIOR_A, S2ON, OBJON, pri[1:0] };

//74LS257  2H/3h 
//74LS20   2J 
//assign palette_addr[10:1] =  prom_27_data[0] == 1'b1 ?  {prom_27_data[3:2], obj[7:0] } : // XXX REAL
assign palette_addr[10:1] =  OBJON ?  {prom_27_data[3:2], OOB[7:0] } :
                                       prom_27_data[1] == 1'b0 ?  {prom_27_data[3:2], sg_palette_addr[7:0]} :
                                                                  {prom_27_data[3:2], SCRN2[7:0]};

// UEC-51 
assign R = palette_out[3:0];
assign G = palette_out[7:4];
assign B = palette_out[11:8];

//parameter VRAM_PALETTE_OFFSET = 10'h100; 256   0b1 0000 0000  (high bit de 4 ) 
//parameter BG1_PALETTE_OFFSET = 10'h200;  512  0b10 0000 0000  (hight bit de 8 )
//parameter BG2_PALETTE_OFFSET = 10'h300;  768      0b1100000000  (hight bit de e)
// one on two on the file are 0 and the other 4 8 or e et par faois 1 
// mais on utilise que les hight bits sur 4 bits donc -> 01 pour 10 pour 8 11
// pour e et 0 pour 1 donc ok puisuq on a palette a 0 / 1 , 10 , 11 
// ca suffit a select la palette, le low bits est utiliser pour select 
// entre d'autre offset qui vont rentrer dans la ram ?? ca sert a quoi ? 
// comprendre ca
// laisser des notes si non personne va rien comprendrendre dans le futur meme
// avec le schema
// maintenant comment savoir commnet select le sg 0140 ? 
// il utilise que 2 bits d'adresse don il peux renvoyer 00, 01, 10, 11 
// et ca doit mapper sur un 4 pour vram/char et un 8 pour bg mais a3 et aussi
// up parfois i lfaudrer verifier pour tous pour cocmprendre 
// on peux imaginier que la prio est donner 0 char, 1 char, 0 bk, 1 bk ? 
// si les 2 sont a 1 ca va select le bk ? donc envoyez 11 ?

//color mix 
//must use rom27
//+ sg1040 -> one sg0140 got char + prom27 + bk1 

//assign palette_addr[10:1] = 
          //char_pixel[3:0] != 'hf ? {2'd0, char_pixel} + VRAM_PALETTE_OFFSET :
          //obj_line_buffer_out[3:0] != 'hf ? {2'd0, obj_line_buffer_out} : 
          //bg_order == 1'b0 & (bk1_pixel[3:0] != 'hf) ? {2'd0, bk1_pixel} + BG1_PALETTE_OFFSET :
          //bg_order == 1'b0 & (bk2_pixel[3:0] != 'hf) ? {2'd0, bk2_pixel} + BG2_PALETTE_OFFSET :
          //bg_order == 1'b1 & (bk2_pixel[3:0] != 'hf) ? {2'd0, bk2_pixel} + BG2_PALETTE_OFFSET :
          //bg_order == 1'b1 & (bk1_pixel[3:0] != 'hf) ? {2'd0, bk1_pixel} + BG1_PALETTE_OFFSET :
          //10'h3ff; //3ff 0x400 -1???



endmodule
