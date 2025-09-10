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
  input       [17:1] MAB,
  input       [15:0] MDB,
  input              DMSL_S1,
  input              DMSL_S2,
  input              DMSL_S4,
  input              DMSL_GL,
  input              RST_S1H, 
  input              SEL_S1H, 
  input              RST_S1Y, 
  input              SEL_S1Y,
  input              RST_S2H, 
  input              SEL_S2H, 
  input              RST_S2Y, 
  input              SEL_S2Y,
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
assign prom_26_addr[7:0] = vpos[7:0]; // generate CPU VBLANK on O5 (pin 6)  

assign OBJT1 =   prom_26_data[0];
assign OBJT2 =   prom_27_data[1]; //need to be latched 
assign STARTY =  prom_27_data[2];
assign VORIGIN = prom_27_data[3];
assign INT_T =   prom_26_data[4];
//nc
//nc 
assign VBL_ROM = prom_26_data[7];
// HV SYNC
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
wire S1CLLT; //S1 col latch 

scrn_bk bk1_u(
  .N6M(N6M),
  .WRN6M(WRN6M),
  .rst(rst),
  .DMSL(DMSL_S1),
  .KDA(KDA[10:1]),
  .MAB(MAB),
  .MDB(MDB),
  .RST_SH(RST_S1H),
  .SEL_SH(SEL_S1H),
  .RST_SY(RST_S1Y),
  .SEL_SY(SEL_S1Y),

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
  .sg_sync(S1CLLT)
);

///////// BG2 DRAWING /////////////////
//
// background 2 : 16x16 tile 
//
wire [3:0] bk2_color;
wire [3:0] bk2_code;
wire S2CLLT; // S2 COL latch

scrn_bk bk2_u(
  .N6M(N6M),
  .WRN6M(WRN6M),
  .rst(rst),
  .DMSL(DMSL_S2),
  .KDA(KDA[10:1]),
  .MAB(MAB),
  .MDB(MDB),

  .RST_SH(RST_S2H),
  .SEL_SH(SEL_S2H),
  .RST_SY(RST_S2Y),
  .SEL_SY(SEL_S2Y),

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
  .sg_sync(S2CLLT)
);

///////// SPRITE DRAWING /////////////////
//
// obj : 16x16 tile 
//
wire  [7:0] obj;
reg   [8:0] obj_line_buffer_addr;

wire swap = hpos[8:0] == 9'd383 ? 1'b0 : 1'b1; //+1 ? //swap a 10

scan_obj_ram scan_obj_ram_u(
  .clk(clk),
  .rst(rst),
  .pxl_cen(P6M), // P6M on board
  
  .LHBL(swap), //XXX

  .vpos(vpos[7:0] + 1), //we calculate 1 line head because of buffering , hpos + 2??

  .ram_addr(obj_addr),
  .ram_out(obj_out),

  .gfx_rom_data(gfx2_rom_data),
  .gfx_rom_ok(gfx2_rom_ok),
  .gfx_rom_addr(gfx2_rom_addr),
  .gfx_rom_cs(gfx2_rom_cs),

  .line_buffer_addr(hpos[7:0] + 1), //+ 1 to latch the pixel ? 
  .line_buffer_out(obj)
);

wire obj_on = ~(obj[3] & obj[2] & obj[1] & obj[0]); //XXX:
wire prior_c = 1'b0; //obj linebuf page 18  XXX 
wire prior_d = 1'b0; //obj linebuf page 18  XXX

wire MASK =  HBLB & L3;//XXX; L3 IS NOT GOOD in sei50bu.v !

reg  [3:0] bk2_code_latch;

//74LS174 8H page 8
reg  [7:0] bk2;
reg  [7:0] bk2_r;//clock is output of sei21bu hpos[1] !

always @(posedge S2CLLT) begin 
    bk2_code_latch <= bk2_code[3:0];
end

//74LS374 7FH page 8
always @(posedge P6M) 
    if (~S2MASK) 
     bk2[7:0] <= { bk2_code_latch[3:0], bk2_color[3:0] };

//assign bk2 = S2MASK ? 8'bz : bk2_r; //XXX ????
wire s2on = ~(bk2[3] & bk2[2] & bk2[1] & bk2[0]); //sch page 8 XXX

// COLOR OUTPUT
CLUT CLUT_u(
  .N6M(N6M),
  .P6M(P6M),
  .WRN6M(WRN6M),
  .S1PIC(bk1_color), //inversed ?
  .S1COL(bk1_code), 
  .S4PIC(char_color),
  .S4COL(char_code),
  .S1CLLT(S1CLLT), // ?
  .S4CLLT(T8H), // ?
  .S1MASK(S1MASK),
  .S4MASK(S4MASK),
  .SCRN2(bk2),
  .OBJON(obj_on),
  .S2ON(s2on),
  .PRIOR_A(PRIOR_A),
  .PRIOR_B(PRIOR_B),
  .PRIOR_C(prior_c),
  .PRIOR_D(prior_d),
  .OOB(obj[7:0]), //XXX
  .KDA(KDA[10:1]),
  .DMSL_GL(DMSL_GL),
  .MDB(MDB[15:0]),
  .MASK(MASK),

  .prom_27_data(prom_27_data),
  .prom_27_ok(prom_27_ok),
  .prom_27_addr(prom_27_addr),
  .prom_27_cs(prom_27_cs),

  .R(r),
  .G(g),
  .B(b)
);

endmodule
