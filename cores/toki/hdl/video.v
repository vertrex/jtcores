////////// VIDEO ////////////////////////////////////////////
//
// - video synchronization (hsync, vsync, vblank, hblank)
// - char, bk1, bk2, obj drawing
// - char, bk1, bk2, obj mixing & output
//
// PCB provenance: structural integration of sheet 5 timing, sheets 7-9
// tile/character paths, sheet 10 palette mixer, and sheets 13-18 objects.
// This wrapper is not itself a PCB IC. Registered PROM access and external
// ROM *_ok handshakes are FPGA memory-interface adaptations.
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
  output     [17:0] obj_rom_1_addr,
  output            obj_rom_1_cs,

  input      [15:0] obj_rom_2_data,
  input             obj_rom_2_ok,
  output     [17:0] obj_rom_2_addr,
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
  output     [7:0]  prom_26_addr,

  input      [7:0]  prom_27_data, // XXX 4 bit wide !
  output     [7:0]  prom_27_addr,


  output            INT_T,
  output            HBLB,

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
wire VSYNC; // SEI0050 pin 28 composite-sync level (sheet 5)
wire [8:0] H;
wire [8:0] V;

// Sheet 5 U53/U54 HD74LS86 banks.  These buses feed sheets 7, 8 and
// 9 directly.  H/V are the literal SEI0050 counter-pin buses; hpos/vpos are
// retained separately for JTFrame and acknowledged-memory scheduling.
wire [7:0] PCB_EXH = H[7:0] ^ {8{HREV}};
wire [7:0] PCB_EXV = V[7:0] ^ {8{VREV}};

//
//PROM26
//

wire OBJT1, OBJT2, STARTV, VORIGIN, VBL_ROM;

// Sheet 5 connects SEI0050 V<1:128> directly to PROM26 A<0:7>. The FPGA PROM
// is synchronous BRAM, so it already contributes one registered read; adding
// another normalized-vpos address register shifted every decoded PCB event to
// framework H=0. Direct captures fix V=0x100 as raster line zero and show the
// PROM blanking edges at raw V=0x110/0x1f0 (normalized lines 16/240).
assign prom_26_addr = V[7:0];

assign OBJT1 =   prom_26_data[0];
assign STARTV =  prom_26_data[2];
assign VORIGIN = prom_26_data[3];
assign INT_T =   prom_26_data[4];
assign VBL_ROM = prom_26_data[7];


// HV SYNC
wire T8H, T3F, T4H, VCLK;

SEI0050BU sei0050bu_u(
  .clk(clk),
  .rst(rst),
  .P6M(P6M),
  .N6M(N6M),

  .VBL_ROM(VBL_ROM),
  .H(H),
  .V(V),
  .hpos(hpos),
  .vpos(vpos),

  .N1H(N1H),
  .T8H(T8H), // physical pin 22 timing phase
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



// PROM26 changes its physical VBL output at the H/V counter seam, eight
// pixels before HBLB falls.  That phase is correct for the PCB mixer and must
// remain live in L3/MASK below, but JTFrame requires vertical blank to change
// between complete output lines.  Sample only the exported framework blank
// at the end of active video so its 224-line capture cannot lose the final
// HUD row depending on the target's video sampling phase.
reg frame_lvbl;
always @(posedge clk) begin
  if (rst)
    frame_lvbl <= 1'b0;
  else if (N6M && hpos == 9'd261)
    frame_lvbl <= VBL_ROM;
end

assign LVBL = frame_lvbl;
assign LHBL = HBLB;

// Page 5: V1B is the VCLK-buffered SEI0050BU V<1> counter output. In this
// common-clock model V changes on the H wrap and VCLK becomes visible after
// that edge, so this register retains the physical old-Q interval for one
// 48 MHz clock before publishing the new raw V<1> state.
reg V1B;
always @(posedge clk) begin
  if (rst)
    V1B <= 1'b0;
  else if (VCLK)
    V1B <= V[0];
end

// Sheet 5 U518 is a 74LS174 clocked by the rising edge of T8H. At the
// 48 MHz common-clock boundary, raw H still ends in 3'b111 immediately before
// the N6M edge which advances it to pin 22's H[2:0]=3'b000 level. This
// one-cycle enable preserves TTL old-Q ordering and avoids treating the full
// T8H level as a transparent latch. It is also the common-clock
// representation of the same physical T8H edge at SG0140 pin 27 on sheet 10.
//
// U518 CLR is tied high on the PCB. Driving it from the framework reset is an
// FPGA-only deterministic-start aid. Q[5:3] are the sheet-5 EXV4/2/1 `/7`
// outputs used by the sheet-9 character-ROM row address. A PCB capture shows
// the ROM A1 lane changing with the matching U518 Q output, about one T8H
// group after its raw EXV D input; feeding raw EXV directly here corrupts the
// final character when the physical H/V counters wrap eight active pixels
// before HBLB falls.
wire       t8h_rise_cen = N6M && (H[2:0] == 3'b111);
// FPGA compatibility event used by the last Pocket-hardware-good object
// pipeline. It changes U5A once on the normalized H2 edge. The literal raw-H2
// migration moved this coupled object-scheduling island by two pixels and is
// being kept out of the live path until its fitted-hardware failure is traced.
wire       u5a_h2_compat_cen = N6M && (hpos[1:0] == 2'b01);
wire [5:0] u518_q;

LS174 u518(
    .CLK (clk),
    .CLRn(~rst),
    .CEN (t8h_rise_cen),
    .D   ({PCB_EXV[2:0], HBL, V1B, prom_26_data[1]}),
    .Q   (u518_q)
);

wire OBJT2_7 = u518_q[0];
wire D1V_7   = u518_q[1];
assign HBLB  = u518_q[2];
wire [7:0] SCR4_EXV = {PCB_EXV[7:3], u518_q[5:3]};

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
  .T8H(T8H), // retained sheet-9 interface; SCRN4 does not consume it
  .T3F(T3F), //char rom cen T3F

  .KDA(KDA[10:1]),
  .DMSL_S4(DMSL_S4),
  .MDB(MDB_RAM_OUT),

  .EXH(PCB_EXH),
  .EXV(SCR4_EXV),
  .HREV(HREV),

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

scrn_bk #(.FPGA_H_SOURCE_PHASE(9'd5)) bk1_u(
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
  .EXH(PCB_EXH),
  .EXV(PCB_EXV),
  .H128(H[7]),
  .H256(H[8]),
  .T8H(T8H),
  .HREV(HREV),
  .VREV(VREV),

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

scrn_bk #(.FPGA_H_SOURCE_PHASE(9'd4)) bk2_u(
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
  .EXH(PCB_EXH),
  .EXV(PCB_EXV),
  .H128(H[7]),
  .H256(H[8]),
  .T8H(T8H),
  .HREV(HREV),
  .VREV(VREV),

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

// FPGA object scheduling retains the Pocket-hardware-good normalized phase.
// Raw H/V remain on the literal SCR4/background paths above. The PCB wires
// PLD22 to raw pins, but the coupled raw object migration (U5A, PLD22,
// VH4/VH8, SORT48 and LINECUNT) regressed descriptor/flip behavior on Pocket.
PLD22 pld22_u(
    .N6M(N6M),
    .H1(hpos[0]),
    .H2(hpos[1]),
    .H4(hpos[2]),
    .H8(hpos[3]),
    .V1B(V1B),
    .OBJT1(OBJT1),
    .V256(~vpos[8]),

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


// Keep U5A on the proven one-shot compatibility phase. A level enable would
// repeatedly sample V1B; the raw-H2 event exposes the next list bank two
// pixels earlier than this FPGA scheduling contract.
LS74 u_5a(
  .CLK(clk),
  .CEN(u5a_h2_compat_cen),
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

obj obj_u(
  .clk(clk),
  .rst(rst),

  .MDB_RAM_OUT(MDB_RAM_OUT[15:0]),
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

// Sheet 5 U511D combines U518's T8H-registered pin 23 with SEI0050 pin 24.
// Pin 24 already contains both the two-P6M horizontal delay and PROM26's
// vertical qualification. CLUT's MASK port has the opposite polarity
// (one means black), so invert the PCB video-enable term.
wire MASK = ~(HBLB & L3);

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
    // Sheet 8: S2MASK drives the active-low output enable of U187.  The
    // resistor network leaves a disabled SCRN2 at transparent F, and S2ON
    // must be low so the priority PROM cannot select it.
    s2on <= !S2MASK && (bk2_color[3:0] != 4'hf);
    bk2[7:0] <= S2MASK ? 8'hff :
                              {bk2_code_latch[3:0], bk2_color[3:0]};
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
  // Sheet 10 wires physical T8H directly to SG0140 pin 27. T8H remains high
  // from the N6M rising edge through the P6M/falling-edge ABSEL capture.
  // t8h_rise_cen remains the separate U518 common-clock edge enable.
  .S4CLLT(T8H),
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
  .prom_27_addr(prom_27_addr),

  .R(r),
  .G(g),
  .B(b)
);



/////////// SIMULATION CODE HELPER //////////////////////////////
/////// RAM DUMP ////////
//
//
//

`ifdef SIMULATION

`define dump_ram16_split(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE; i = i + 1) begin \
       $fwrite(fd, "%c%c", MEM_PATH.u_hi.mem[i], MEM_PATH.u_lo.mem[i]); \
    end \
    $fclose(fd); \
end
  
`define dump_ram16(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE; i = i + 1) begin \
       $fwrite(fd, "%c%c", MEM_PATH[i][15:8], MEM_PATH[i][7:0]); \
    end \
    $fclose(fd); \
end

`define dump_linebuf_ram(FILE_NAME, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    reg [15:0] word16; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, 1024); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < 512; i = i + 1) begin \
       word16 = {6'b0, MEM_PATH[i][9:0]}; \
       $fwrite(fd, "%c%c", word16[15:8], word16[7:0]); \
    end \
    $fclose(fd); \
end

// Macro pour dumper une RAM 8 bits (si jamais tu en as besoin pour le SIS6091 standard)
`define dump_ram8(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE; i = i + 1) begin \
      $fwrite(fd, "%c", MEM_PATH[i]); \
    end \
    $fclose(fd); \
end

// sis6091B packs the "used" flag as bit 16 of a 17-bit mem word
`define dump_sis6091b_used(FILE_NAME, SIZE, MEM_PATH) \
begin \
    integer fd; \
    integer i; \
    $display("Snapshot: Dumping %s (Size: %0d)", FILE_NAME, SIZE); \
    fd = $fopen(FILE_NAME, "wb"); \
    for (i = 0; i < SIZE; i = i + 1) begin \
       $fwrite(fd, "%c", MEM_PATH[i][16]); \
    end \
    $fclose(fd); \
end

parameter DUMP_START_FRAME = 38;

integer  frame_counter = 0;
always @(posedge VS) begin
   frame_counter = frame_counter + 1;
end

reg dump_done = 0;

always @(posedge clk) begin 
  if (frame_counter == DUMP_START_FRAME && !dump_done) begin
     $display("DUMPING");

     `dump_ram16("scnddma_u151.bin", 64, obj_u.scnddma_u.u_151.mem)
     `dump_ram16("scnddma_u152.bin", 64, obj_u.scnddma_u.u_152.mem)
     `dump_sis6091b_used("scnddma_u151_used.bin", 64, obj_u.scnddma_u.u_151.mem)
     `dump_sis6091b_used("scnddma_u152_used.bin", 64, obj_u.scnddma_u.u_152.mem)
     `dump_ram16_split("scnddma_u153.bin", 1024, obj_u.scnddma_u.u_153)
     `dump_ram16_split("objdma_u141.bin", 1024, obj_u.objdma_u.u_141);
     `dump_linebuf_ram("linebuf_u181.bin", obj_u.linebuf_u.u_181.mem)
     `dump_linebuf_ram("linebuf_u182.bin", obj_u.linebuf_u.u_182.mem)
     `dump_linebuf_ram("linebuf_u183.bin", obj_u.linebuf_u.u_183.mem)
     `dump_linebuf_ram("linebuf_u184.bin", obj_u.linebuf_u.u_184.mem)
     // Fast line RAM clears its separate FIND plane in one edge; BRAM bit 16
     // is stale by design after that command, so dump the simulation mirror.
     `dump_ram8("linebuf_u181_used.bin", 512, obj_u.linebuf_u.u_181.used)
     `dump_ram8("linebuf_u182_used.bin", 512, obj_u.linebuf_u.u_182.used)
     `dump_ram8("linebuf_u183_used.bin", 512, obj_u.linebuf_u.u_183.used)
     `dump_ram8("linebuf_u184_used.bin", 512, obj_u.linebuf_u.u_184.used)

     `dump_ram16_split("cpu_ram.bin", 32768, $root.game_test.u_game.u_game.u_main.u_cpu_ram)

     dump_done <= 1;
     end 
end

`endif
endmodule
