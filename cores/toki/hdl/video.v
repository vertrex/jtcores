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
  output            N1H,

  // RGB out
  output [3:0]      r,
  output [3:0]      g,
  output [3:0]      b,

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

  input      [15:0] obj_rom_1_data,
  input             obj_rom_1_ok,
  output     [18:1] obj_rom_1_addr,
  output            obj_rom_1_cs,

  input      [15:0] obj_rom_2_data,
  input             obj_rom_2_ok,
  output     [18:1] obj_rom_2_addr,
  output            obj_rom_2_cs,

  input      [15:0] bk1_rom_data,
  input             bk1_rom_ok,
  output     [18:1] bk1_rom_addr,
  output            bk1_rom_cs,

  input      [15:0] bk2_rom_data,
  input             bk2_rom_ok,
  output     [18:1] bk2_rom_addr,
  output            bk2_rom_cs,

  input      [7:0]  prom_26_data,
  input             prom_26_ok,
  output reg [7:0]  prom_26_addr,
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
  input             VREV,

  input       [12:1] KDA,
  input       [17:1] MAB,
  input       [15:0] MDB_RAM_OUT,
  input       [15:0] MDB_CPU_OUT,
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
  input              BUSAK,
  
  output             OBUSDIR,
  output             OBUSRQ,
  input              ODMARQ,
  output             OIBDIR,
  output      [10:1] FDA
);

////////// VIDEO SYNC /////////////
//
wire HBL; 
wire L3;
wire HD;
wire VSYNC; //seems to be ~ sei0050bu XXX (page 5)

//XXX use them 
//REVERSE SCREEN X/Y HD74LS86P A1/2
wire [7:0] EXH = {hpos[7] ^ HREV, hpos[6] ^ HREV, hpos[5] ^ HREV, hpos[4] ^ HREV, hpos[3] ^ HREV, hpos[2] ^ HREV, hpos[1] ^ HREV, hpos[0] ^ HREV};
wire [7:0] EXV = {vpos[7] ^ VREV, vpos[6] ^ VREV, vpos[5] ^ VREV, vpos[4] ^ VREV, vpos[3] ^ VREV, vpos[2] ^ VREV, vpos[1] ^ VREV, vpos[0] ^ VREV};

// 
//PROM26 
//

//reg HBL;
wire OBJT1, OBJT2, STARTV, VORIGIN, VBL_ROM;

assign prom_26_cs = 1'b1;
//assign prom_26_addr[7:0] = vpos[7:0]; // generate CPU VBLANK on O5 (pin 6)  

always @(posedge clk)
  if (~N6M) begin 
    prom_26_addr[7:0] <= vpos[7:0]; // generate CPU VBLANK on O5 (pin 6)  
  end 


assign OBJT1 =   prom_26_data[0];
//assign OBJT2 =   prom_27_data[1]; //need to be latched 
assign STARTV =  prom_26_data[2];
assign VORIGIN = prom_26_data[3];
assign INT_T =   prom_26_data[4];
//nc
//nc 
assign VBL_ROM = prom_26_data[7];
// HV SYNC
wire T8H, T3F, T4H, VCLK;

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

reg [9:0] frame_counter = 0;

//if @always LVBL it glitch ? how that can work on miste ror pocket ?
always @(posedge clk) begin 
  if (LVBL)
    frame_counter = frame_counter + 10'b1;
end 

assign LVBL = VBL_ROM;
assign LHBL = HBL; // ?

reg OBJT2_7;
reg D1V_7; 
reg [2:0] EXV_7;

//CHAR_CEN IS T3F
always @(posedge clk) begin 
  if (T8H)
    OBJT2_7 <= prom_26_data[1];
    D1V_7 <= V1B;
//     HBLB <= sei50bu p23 // XXX where we get that Y10???
    HBLB <= HBL; //HBL sei50bu pin 23
    EXV_7[0] <= EXV[0];
    EXV_7[1] <= EXV[1];
    EXV_7[2] <= EXV[2];
end 

///////// SCREEN 4 : char tile //////////
//
// char : 8x8 tile 
//
wire [3:0] char_color;
wire [3:0] char_code;

scrn4 scrn4_u(
  .clk(clk),
  .rst(rst),
  .N6M(N6M),
  .WRN6M(WRN6M),
  .T4H(T4H),
  .T8H(T8H), //char_cen T8H
  .T3F(T3F), //char rom cen T3F 

  .KDA(KDA[10:1]),
  .DMSL_S4(DMSL_S4),
  .MDB(MDB_RAM_OUT),
  
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
  .clk(clk),
  .rst(rst),
  .N6M(N6M),
  .WRN6M(WRN6M),
  .DMSL(DMSL_S1),
  .KDA(KDA[10:1]),
  .MAB(MAB),
  .MDB_RAM_OUT(MDB_RAM_OUT),
  .MDB_CPU_OUT(MDB_CPU_OUT),
  .RST_SH(RST_S1H),
  .SEL_SH(SEL_S1H),
  .RST_SY(RST_S1Y),
  .SEL_SY(SEL_S1Y),

  .hpos(hpos[8:0]),
  .vpos(vpos[8:0]),

  .rom_data(bk1_rom_data),
  .rom_ok(bk1_rom_ok),
  .rom_addr(bk1_rom_addr),
  .rom_cs(bk1_rom_cs),

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
  .clk(clk),
  .rst(rst),
  .N6M(N6M),
  .WRN6M(WRN6M),
  .DMSL(DMSL_S2),
  .KDA(KDA[10:1]),
  .MAB(MAB),
  .MDB_RAM_OUT(MDB_RAM_OUT),
  .MDB_CPU_OUT(MDB_CPU_OUT),

  .RST_SH(RST_S2H),
  .SEL_SH(SEL_S2H),
  .RST_SY(RST_S2Y),
  .SEL_SY(SEL_S2Y),

  .hpos(hpos[8:0]),
  .vpos(vpos[8:0]),

  .rom_data(bk2_rom_data),
  .rom_ok(bk2_rom_ok), //glitch if at same time than sound because not enoughtrouput XXX !
  .rom_addr(bk2_rom_addr),
  .rom_cs(bk2_rom_cs),

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

wire FIRST_LD, SECND_LD, CTLT1, CTLT2, EVN_LD, ODD_LD, NV256;

//page 5 osc 
wire V1B = vpos[0];

PLD22 pld22_u(
    .N6M(N6M),
    .H1(hpos[0]),
    .H2(hpos[1]),
    .H4(hpos[3]),
    .H8(hpos[4]),
    .V1B(V1B),
    .OBJT1(OBJT1),  
    .V256(~vpos[8]), // ????? does v256 is inversed in sei50bu ? 
    //because NV256 signal is not good for what we have

    .FIRST_LD(FIRST_LD),
    .SECND_LD(SECND_LD),
    .CTLT1(CTLT1),
    .CTLT2(CTLT2),
    .EVN_LD(EVN_LD),
    .ODD_LD(ODD_LD),
    .NV256(NV256)
    //.VCLK(VCLK) //this is just driven
);

wire OBJON;
wire [7:0] OOD;
wire PRIOR_C, PRIOR_D;
wire D1V_2;


LS74 u_5a(
  .CLK(clk),
  .CEN(hpos[1]),
  .D(V1B),
  .PRE(1'b1),
  .CLR(1'b1),
  .Q(D1V_2),
  .QN()
);

wire OBJ_HREV;
wire OPSREV = HREV ^ OBJ_HREV;
wire VH4 = ~hpos[2] ^ OPSREV; 
wire VH8 = hpos[3] ^ ~hpos[2] ^ OPSREV;
//wire NH2 = ~hpos[1];

obj obj_u(
  .clk(clk),
  .rst(rst),

  .MDB_RAM_OUT(MDB_RAM_OUT[15:0]),
  .MDB_CPU_OUT(MDB_RAM_OUT[15:0]),
  .BUSAK(BUSAK),
  .STARTV(STARTV),
  .ODMARQ(ODMARQ),
  .VORIGIN(VORIGIN), 
  .H_POS(hpos[8:0]),
  .VREV(VREV),
  .HBLB(HBLB),
  .T3F(T3F),
  .T8H(T8H),
  .RESETA(rst), //RST or ~RST ?
  .FIRST_LD(FIRST_LD),
  .SECND_LD(SECND_LD),
  .CTLT1(CTLT1),
  .CTLT2(CTLT2),
  .EVN_LD(EVN_LD),
  .ODD_LD(ODD_LD),
  .NV256(NV256),
  .VCLK(VCLK),
  .OBJ_P6M(P6M),
  .OBJ_N6M(N6M),
  .RDCLK(N6M),
  .V1B(V1B),
  .D1V_2(D1V_2),
  .OBJMASK(OBJMASK), 
  .HREV(HREV),
  .HD(HD),
  .OBJT2_7(OBJT2_7),
  .D1V_7(D1V_7),
  .OPSREV(OPSREV),
  .VH4(VH4),
  .VH8(VH8),
  .obj_rom_1_data(obj_rom_1_data),
  .obj_rom_1_ok(obj_rom_1_ok),
  .obj_rom_2_data(obj_rom_2_data),
  .obj_rom_2_ok(obj_rom_2_ok),

  //output
  .obj_rom_1_cs(obj_rom_1_cs),
  .obj_rom_1_addr(obj_rom_1_addr),
  .obj_rom_2_cs(obj_rom_2_cs),
  .obj_rom_2_addr(obj_rom_2_addr),
  .OBUSRQ(OBUSRQ),
  .OBUSDIR(OBUSDIR),
  .OBJON(OBJON),
  .OOD(OOD[7:0]),
  .PRIOR_C(PRIOR_C),
  .PRIOR_D(PRIOR_D),
  .OIBDIR(OIBDIR),
  .FDA(FDA[10:1]),
  .OBJ_HREV(OBJ_HREV)
);

// XXX @ ... ?
wire MASK =  HBLB & L3;//XXX; L3 IS NOT GOOD in sei50bu.v !

//74LS174 8H page 8
//74LS374 7FH page 8
//(equivalent sg0140?)
reg  [7:0] bk2;
reg  [3:0] bk2_code_latch;
reg        s2on;

always @(posedge clk) begin 
  if (~N6M) begin 
    if (S2CLLT) begin // COL_B_EN ?
      bk2_code_latch <= bk2_code[3:0]; 
    end 
//if    (~S2MASK )
    s2on <= (bk2_color[3:0] == 4'hf) ? 1'b0: 1'b1; //sch page 8 XXX
    bk2[7:0] <= { bk2_code_latch[3:0], bk2_color[3:0]};
  end 
end 

// COLOR OUTPUT
CLUT CLUT_u(
  .clk(clk),
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
  .OBJON(OBJON),
  .S2ON(s2on),
  .PRIOR_A(PRIOR_A),
  .PRIOR_B(PRIOR_B),
  .PRIOR_C(PRIOR_C),
  .PRIOR_D(PRIOR_D),
  .OOD(OOD[7:0]), //XXX
  .KDA(KDA[10:1]),
  .DMSL_GL(DMSL_GL),
  .MDB(MDB_RAM_OUT[15:0]),
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
