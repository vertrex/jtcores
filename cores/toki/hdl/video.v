////////// VIDEO ////////////////////////////////////////////
//
// - video synchronization (hsync, vsync, vblank, hblank)
// - char, bk1, bk2, obj drawing  
// - char, bk1, bk2, obj mixing & output 
//
module toki_video(
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

  // RGB out
  output [3:0]      r,
  output [3:0]      g,
  output [3:0]      b,

  // Shared video RAM
  output     [10:1] palette_addr,
  input      [15:0] palette_out,

  output     [10:1] obj_addr,
  input      [15:0] obj_out,

  // ROM data
  //input      [15:0] gfx1_rom_data,
  //input             gfx1_rom_ok,
  //output     [16:1] gfx1_rom_addr,
  //output            gfx1_rom_cs,

  //input      [15:0] char_rom_data,
  //input             char_rom_ok,
  //output     [16:1] char_rom_addr,
  //output            char_rom_cs,
  
  input       [7:0] char_rom_1_data,
  input             char_rom_1_ok,
  output     [15:0] char_rom_1_addr,
  output            char_rom_1_cs,

  input       [7:0] char_rom_2_data,
  input             char_rom_2_ok,
  output     [15:0] char_rom_2_addr,
  output            char_rom_2_cs,

  input      [15:0] gfx2_rom_data,
  input             gfx2_rom_ok,
  output     [19:1] gfx2_rom_addr,
  output            gfx2_rom_cs,

  input      [15:0] gfx3_rom_data,
  input             gfx3_rom_ok,
  output     [18:1] gfx3_rom_addr,
  output            gfx3_rom_cs,

  input      [15:0] gfx4_rom_data,
  input             gfx4_rom_ok,
  output     [18:1] gfx4_rom_addr,
  output            gfx4_rom_cs,

  input      [7:0]  prom_26_data,
  input             prom_26_ok,
  output     [7:0]  prom_26_addr,
  output            prom_26_cs,

  input      [7:0]  prom_27_data, // XXX 4 bit wide ! 
  input             prom_27_ok,
  output     [7:0]  prom_27_addr,
  output            prom_27_cs,

  output            INT_T,
  output  reg       HBLB,

  input             S1MASK,
  input             S2MASK,
  input             OBJMASK,
  input             S4MASK,
  input             PRIOR_A,
  input             PRIOR_B,
  input             HREV,
  input             YREV,

  input       [12:1] KDA,
  input       [15:0] MDB,
  input              DMSL_S1,
  input              DMSL_S2,
  input              DMSL_S4,
  input              WRN6M,

  input  signed      [8:0] bk1_scroll_x,
  input  signed      [8:0] bk2_scroll_x,
  input  signed      [8:0] bk1_scroll_y,
  input  signed      [8:0] bk2_scroll_y
);

////////// VIDEO SYNC /////////////
//
wire T4H;
wire HBL; 
wire L3;
wire HD;
wire VSYNC;

//REVERSE SCREEN X/Y HD74LS86P A1/2
wire [7:0] exh = {hpos[7] ^ HREV, hpos[6] ^ HREV, hpos[5] ^ HREV, hpos[4] ^ HREV, hpos[3] ^ HREV, hpos[2] ^ HREV, hpos[1] ^ HREV, hpos[0] ^ HREV};
wire [7:0] exv = {vpos[7] ^ YREV, vpos[6] ^ YREV, vpos[5] ^ YREV, vpos[4] ^ YREV, vpos[3] ^ YREV, vpos[2] ^ YREV, vpos[1] ^ YREV, vpos[0] ^ YREV};

// 
//PROM26 
//

//reg HBL;

wire OBJT1, OBJT2, STARTY, VORIGIN, VBL_ROM;

assign prom_26_cs = 1'b1;
assign prom_26_addr[7:0] = vpos[7:0];// generate CPU VBLANK on O5 (pin 6)  

assign OBJT1 =   prom_26_data[0];
assign OBJT2 =   prom_27_data[1]; //need to be latched 
assign STARTY =  prom_27_data[2];
assign VORIGIN = prom_27_data[3];
assign INT_T =   prom_26_data[4];
//nc
//nc 
assign VBL_ROM = prom_26_data[7];
// HV SYNC
//

wire T8H, T3F;

SEI0050BU sei0050bu_u(
  //.clk(clk),
  .pxl_cen(N6M),
  .rst(rst),

  .VBL_ROM(VBL_ROM),
  .hpos(hpos),
  .vpos(vpos),

  .T8H(T8H), //char cen
  .HBL(HBL),
  .L3(L3),
  .T3F(T3F),
  .T4H(T4H),
  .HD(HD),
  .VSYNC(VSYNC),

  .HS(HS),
  .VS(VS)
  //.LHBL(LHBL),
  //.LVBL()

  //.hcnt(hcnt),
  //.char_cen(char_cen),
  //.char_rom_cen(char_rom_cen)
);

assign LVBL = VBL_ROM;
assign LHBL = HBL; // ?
          //CHAR_CEN IS T3F
always @(posedge T8H) begin 
   HBLB <= HBL; //HBL sei50bu pin 23 
end 

///////// SCREEN 4 : char tile //////////
//
// char : 8x8 tile 
//
parameter VRAM_PALETTE_OFFSET = 10'h100;

wire [3:0] char_color;
wire [3:0] char_code;

scrn4 scrn4_u(
  .clk(N6M),
  .rst(rst),
  .WRN6M(WRN6M),
  .T4H(T4H),
  .T8H(T8H), //char_cen T8H
  .T3F(T3F), //char rom cen T3F 

  .KDA(KDA[10:1]),
  .DMSL_S4(DMSL_S4),
  .MDB(MDB),
  
  .hpos(hpos[7:0]),
  .vpos(vpos[7:0]),
  .hrev(HREV),

  .char_rom_1_data(char_rom_1_data),
  .char_rom_1_ok(char_rom_1_ok),
  .char_rom_1_addr(char_rom_1_addr),
  .char_rom_1_cs(char_rom_1_cs),

  .char_rom_2_data(char_rom_2_data),
  .char_rom_2_ok(char_rom_2_ok),
  .char_rom_2_addr(char_rom_2_addr),
  .char_rom_2_cs(char_rom_2_cs),

  .char_color(char_color),
  .char_code(char_code)
);


///////// BG1 DRAWING /////////////////
//
// background 1 : 16x16 tile 
//
wire [3:0] bk1_color;
wire [3:0] bk1_code;
wire sg_sync_bk1;

bk bk1_u(
  .N6M(N6M),
  .WRN6M(WRN6M),
  .rst(rst),
  .DMSL(DMSL_S1),
  .KDA(KDA[10:1]),
  .MDB(MDB),

  .hpos(hpos[7:0]),
  .vpos(vpos[7:0]),

  .scroll_x(bk1_scroll_x),
  .scroll_y(bk1_scroll_y),

  .gfx_rom_data(gfx3_rom_data),
  .gfx_rom_ok(gfx3_rom_ok),
  .gfx_rom_addr(gfx3_rom_addr),
  .gfx_rom_cs(gfx3_rom_cs),

  .color(bk1_color),
  .code(bk1_code),
  .sg_sync(sg_sync_bk1)
);

///////// BG2 DRAWING /////////////////
//
// background 2 : 16x16 tile 
//
wire [3:0] bk2_color;
wire [3:0] bk2_code;
wire sg_sync_bk2;

bk bk2_u(
  .N6M(N6M),
  .WRN6M(WRN6M),
  .rst(rst),
  .DMSL(DMSL_S2),
  .KDA(KDA[10:1]),
  .MDB(MDB),

  .hpos(hpos[7:0]),
  .vpos(vpos[7:0]),

  .scroll_x(bk2_scroll_x),
  .scroll_y(bk2_scroll_y),

  .gfx_rom_data(gfx4_rom_data),
  .gfx_rom_ok(gfx4_rom_ok),
  .gfx_rom_addr(gfx4_rom_addr),
  .gfx_rom_cs(gfx4_rom_cs),

  .color(bk2_color),
  .code(bk2_code),
  .sg_sync(sg_sync_bk2)
);

///////// SPRITE DRAWING /////////////////
//
// obj : 16x16 tile 
//
wire  [7:0] obj;
reg   [8:0] obj_line_buffer_addr;

scan_obj_ram scan_obj_ram_u(
  .clk(clk),
  .rst(rst),
  .pxl_cen(P6M), // P6M on board
  
  .LHBL(HBLB), //XXX

  .vpos(vpos[7:0]), //we calculate 1 line head because of buffering , hpos + 2??

  .ram_addr(obj_addr),
  .ram_out(obj_out),

  .gfx_rom_data(gfx2_rom_data),
  .gfx_rom_ok(gfx2_rom_ok),
  .gfx_rom_addr(gfx2_rom_addr),
  .gfx_rom_cs(gfx2_rom_cs),

  //.line_buffer_addr(hcnt - 5), //-5 make it work if I shift hblank by 5 end finish hblank at 5 
  .line_buffer_addr(hpos[8:0]), //-5 make it work if I shift hblank by 5 end finish hblank at 5 
  .line_buffer_out(obj)
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

wire [7:0] sg_palette_addr;
wire [1:0] pri;

sg0140    sg0140_u(
  .clk(N6M), 

  .char_color(char_color),
  .char_code(char_code), 
  .char_en(T8H),
  .char_mask(S4MASK),

  .bk1_code(bk1_code), 
  .bk1_color(bk1_color),
  .bk1_en(sg_sync_bk1),
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

wire prior_c = 1'b0; //obj linebuf page 18 
wire prior_d = 1'b0; //obj linebuf page 18
//s1 sc1 => bk1 ? 
//sc2 s2 => bk2
//sc4 s4 => char 

//color mixing clut page 10
// XXX BK2 is latched before input into palette page 8 with P6M clck 

//74LS174 8H page 8
reg  [7:0] bk2_r;//clock is output of sei21bu hpos[1] !
wire [7:0] bk2;
reg  [3:0] bk2_code_latch;

always @(posedge sg_sync_bk2) begin 
    bk2_code_latch <= bk2_code[3:0];
end 

//74LS374 7FH page 8
always @(posedge P6M) 
    if (~S2MASK) 
     bk2_r[7:0] <= { bk2_code_latch[3:0], bk2_color[3:0] };

assign bk2 = S2MASK ? 8'bz : bk2_r;

wire s2on = ~(bk2[3] & bk2[2] & bk2[1] & bk2[0]); //sch page 8 
wire obj_on = ~(obj[3] & obj[2] & obj[1] & obj[0]); //XXX:

//74LS20P check if color != 'hf XXX used latched value
//page 10
assign prom_27_cs = 1'b1;
assign prom_27_addr[7:0] = { prior_d, prior_c, PRIOR_B, PRIOR_A, s2on, obj_on, pri[1:0] };

//74LS257  2H/3h 
//74LS20   2J 
//assign palette_addr[10:1] =  prom_27_data[0] == 1'b1 ?  {prom_27_data[3:2], obj[7:0] } : // XXX REAL
assign palette_addr[10:1] =  obj_on  ?  {prom_27_data[3:2], obj[7:0] } :
                             prom_27_data[1] == 1'b0 ?  {prom_27_data[3:2], sg_palette_addr[7:0]} :
                                                        {prom_27_data[3:2], bk2[7:0]};

// UEC-51 
assign r = palette_out[3:0];
assign g = palette_out[7:4];
assign b = palette_out[11:8];

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
