// Sheet-17 object metadata/ROM-address/line-counter path. This drives both
// physical serializer lanes. Acknowledged-ROM queue/cache/replay policy lives
// in toki_obj_sdram_adapter rather than this schematic-facing shell.
module LINECUNT(
   input         clk,
   input  [15:0] OVD, // multiplexed object descriptor data
   input   [3:0] VA,
   input         ODHREV,
   input         RESETA,
   input         SPR1_3,
   input         SPR2_3,
   input         CTLT1,
   input         CTLT2,
   input         HREV,
   input         OBJ_N6M,
   // Physical PLD22 load pins retained as part of the sheet-17 interface.
   // Acknowledged SDRAM requires regenerated committed-row loads below.
   input         ODD_LD,
   input         EVN_LD,
   input         HBLB,    //hblank
   input         OBJT2_7,
   input         V1B,  //use to switch odd / even ?
   input         T8H,  // cen
   input         VH4,  // cen
   input         VH8,  // cen
   input         NOOBJ,
   input  [15:0] obj_rom_1_data,
   input         obj_rom_1_ok,
   input  [15:0] obj_rom_2_data,
   input         obj_rom_2_ok,
//output
   output [17:0] obj_rom_1_addr,
   output        obj_rom_1_cs,
   output [17:0] obj_rom_2_addr,
   output        obj_rom_2_cs,
   output  [3:0] OBJCOL,
   output        OBJ_HREV,
   output        OSP1,
   output        OSP2,
   output [15:0] PD,      // pixel data output from ROM
   output        EVNCLR,  // clear evn ram ?
   output        ODDCLR,
   output  [8:0] O1A,     // odd 1 address
   output  [8:0] E1A,     // even 1 address
   // PCB U1713D/U1714E continuously form these as ~EVNCLR/~ODDCLR.
   // The FPGA adapter instead emits tagged, finite active-low write windows.
   output        ODDWREN,
   output        EVNWREN,
   output  [8:0] O2A,     // odd 2 address
   output  [8:0] E2A,     // even 2 address
   output        NOOBJ_CT2,
   // FPGA-only cached-row direction selected for the current serializer load.
   // This is not a sheet-17 pin; see the SDRAM adapter's replay_opsrev.
   output        FPGA_REPLAY_REV
);

wire [4:0] ADDR_live;
wire       NOOBJ_CT2_live;
wire [3:0] OBJCOL_live;
wire       OBJ_HREV_live;
wire       OSP1_live;
wire       OSP2_live;

wire [8:4] OH;
wire [8:0] FH;
wire       evn_ld_scan;
wire       odd_ld_scan;

wire [11:0] rom_index_live;
wire [3:0]  line_sel_live;
wire [17:0] live_rom_addr;
wire [8:0]  draw_h2_1_addr_eff;
wire [8:0]  draw_h2_0_addr_eff;

// CTLT1/CTLT2 are physical clocks on sheet 17. Their PLD outputs stay low for
// several 48 MHz clocks, while each TTL register captures once on the decoded
// clock's rising edge. One common-clock enable preserves the PCB old-Q chain.
reg ctlt1_capture_d;
reg ctlt2_capture_d;

always @(posedge clk) begin
   if (RESETA) begin
      ctlt1_capture_d <= 1'b1;
      ctlt2_capture_d <= 1'b1;
   end else begin
      ctlt1_capture_d <= CTLT1;
      ctlt2_capture_d <= CTLT2;
   end
end

wire ctlt1_capture_cen = CTLT1 && !ctlt1_capture_d;
wire ctlt2_capture_cen = CTLT2 && !ctlt2_capture_d;

// OHMAX historically accepts active-low phase clocks. Feeding the same
// qualified pulse keeps it and the TTL registers on one logical PCB edge.
wire ohmax_ctlt1_n = ~ctlt1_capture_cen;
wire ohmax_ctlt2_n = ~ctlt2_capture_cen;

// The local PCB mask ROMs need no request scheduler. JTFrame stores them behind
// acknowledged SDRAM, so the explicitly FPGA-only adapter snapshots descriptor
// pairs, obtains complete rows, and replays them on the physical CTLT/SEI0060
// schedule. LINECUNT retains the sheet-17 TTL, OHMAX and SEI0060 boundaries.
//
// Sheet 17 wires PLD22 EVN_LD/ODD_LD directly to the SEI0060s. With delayed
// SDRAM that edge can arrive before a complete row exists, so the adapter emits
// evn_ld_scan/odd_ld_scan at the matching committed SECND edge. The original
// ports remain visible above as the PCB pin contract; bypassing this one timing
// facade would reintroduce partial-row and dense-list corruption.
toki_obj_sdram_adapter sdram_adapter_u(
   .clk(clk),
   .RESETA(RESETA),
   .OVD(OVD),
   .VA(VA),
   .ODHREV(ODHREV),
   .SPR1_3(SPR1_3),
   .SPR2_3(SPR2_3),
   .CTLT1(CTLT1),
   .CTLT2(CTLT2),
   .HREV(HREV),
   .OBJ_N6M(OBJ_N6M),
   .HBLB(HBLB),
   .V1B(V1B),
   .T8H(T8H),
   .VH4(VH4),
   .VH8(VH8),
   .NOOBJ(NOOBJ),
   .ctlt1_capture_d(ctlt1_capture_d),
   .ctlt2_capture_cen(ctlt2_capture_cen),
   .FH(FH),
   .OBJCOL_live(OBJCOL_live),
   .OBJ_HREV_live(OBJ_HREV_live),
   .OSP1_live(OSP1_live),
   .OSP2_live(OSP2_live),
   .NOOBJ_CT2_live(NOOBJ_CT2_live),
   .EVNCLR(EVNCLR),
   .ODDCLR(ODDCLR),
   .live_rom_addr(live_rom_addr),
   .obj_rom_1_data(obj_rom_1_data),
   .obj_rom_1_ok(obj_rom_1_ok),
   .obj_rom_2_data(obj_rom_2_data),
   .obj_rom_2_ok(obj_rom_2_ok),
   .obj_rom_1_addr(obj_rom_1_addr),
   .obj_rom_1_cs(obj_rom_1_cs),
   .obj_rom_2_addr(obj_rom_2_addr),
   .obj_rom_2_cs(obj_rom_2_cs),
   .OBJCOL(OBJCOL),
   .OBJ_HREV(OBJ_HREV),
   .OSP1(OSP1),
   .OSP2(OSP2),
   .PD(PD),
   .NOOBJ_CT2(NOOBJ_CT2),
   .FPGA_REPLAY_REV(FPGA_REPLAY_REV),
   .draw_h2_1_addr_eff(draw_h2_1_addr_eff),
   .draw_h2_0_addr_eff(draw_h2_0_addr_eff),
   .evn_ld_scan(evn_ld_scan),
   .odd_ld_scan(odd_ld_scan),
   .ODDWREN(ODDWREN),
   .EVNWREN(EVNWREN)
);

// 74LS174 20F
wire [5:0] u171_Q;

LS174 u171_20F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(ctlt1_capture_cen),
   .D({OVD[10:9], OVD[3:0]}),
   .Q(u171_Q[5:0])
);

// 74LS174 21F
wire [5:0] u172_Q;
wire NC;

LS174 u172_21F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(ctlt1_capture_cen),
   .D({1'b0, OVD[15:11]}),
   .Q({NC, u172_Q[4:0]})
);

// 74LS273 20E
wire [6:0] u174_Q;

LS273 u174_20E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(ctlt2_capture_cen),
   // Data flow analysis (deep trace, 2026-05-09):
   //   u_153 writes: word 1 (CHAR) at FDA[2:1]=01 → LSB=0;
   //                 word 2 (HPOS) at FDA[2:1]=10 → LSB=1
   //   u_153 reads:  H1=0 (CTLT1 phase) → LSB=0 → OVD = CHAR
   //                 H1=1 (CTLT2 phase) → LSB=1 → OVD = HPOS
   // rom_index's low 4 bits need tile_lo[3:0] (= CHAR[3:0] at CTLT1).
   // Use u171_Q[3:0] (latched at CTLT1) instead of live OVD[3:0] at CTLT2
   // which would wrongly capture HPOS[3:0] and make X affect tile index.
   .D({u172_Q[1:0], u171_Q[5:4], u171_Q[3:0]}),
   .Q({OBJCOL_live[0], u174_Q[6:0]})
);

// 74LS273 21E
wire [3:0] u175_Q;

LS273 u175_21E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(ctlt2_capture_cen),
   //.D({ODHREV, VA8, VA4, VA2, VA1, u172_Q[4:2]}),
   .D({ODHREV, VA[3:0], u172_Q[4:2]}),
   .Q({OBJ_HREV_live, u175_Q[3:0], OBJCOL_live[3:1]})
);

// Sheet 17 forms the live asynchronous-ROM address directly from the physical
// U174/U175/OHMAX latch chain. The FPGA adapter uses it as the idle/fallback
// address and substitutes an acknowledged row request only while transport is
// active.
assign rom_index_live = {u174_Q[6:4], ADDR_live[4:0], u174_Q[3:0]};
assign line_sel_live  = u175_Q[3:0];
assign live_rom_addr = {rom_index_live, VH8, line_sel_live, VH4};

// SG0140 U173, 16D, OHMAX mode.
// ADDR[4:0] captures object-ROM tile-index bits and OH[8:4] captures the
// coarse sprite X position from the multiplexed OVD bus.

sg0140_ohmax sg0140_u173_16D(
   //input
   .clk(clk),
   .rst(RESETA), // pin 40
   // Pins 28..35 are tied low. Pins 36/37 are tied high for OHMAX mode.
   // Physical pins 38/39 are the active-low CTLT1/CTLT2 phase inputs.
   .CTLT1(ohmax_ctlt1_n),
   .CTLT2(ohmax_ctlt2_n),
   //.Q({NOOBJ_CT2, ADDR[4:0] ,OH[8:4]})

   //.MODE(2'b11), //OHMAX mode
   .NOOBJ(NOOBJ),
   .OVD(OVD[8:4]),
   .HREV(HREV),
   //output
   .OH(OH[8:4]),
   .ADDR(ADDR_live[4:0]),
   .NOOBJ_CT2(NOOBJ_CT2_live)
   //.D({OVD[7:4], NOOBJ, OVD[8]}),  //11-16
);


//74LS273
//22E
wire [7:0] u176_Q;

LS273 u176(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(ctlt2_capture_cen),
   // Sheet 17 U176 pins 3/4/7/8 are OVD[0:3] directly. At CTLT2 this
   // is HPOS[3:0]; using the CTLT1 tile-low latch couples tile number to X.
   .D({OH[8], OVD[15], SPR2_3, SPR1_3, OVD[3:0]}),
   .Q(u176_Q)
);

assign FH[8]     = u176_Q[7];
assign OSP2_live = u176_Q[5];
assign OSP1_live = u176_Q[4];

// U176 physical Q7 (u176_Q[6]) is ROM_CE. On the PCB it selects U178
// directly and U179 through U177C. The acknowledged-ROM adapter retains the
// same OVD[15] selection with each descriptor and issues the delayed CS.

//74LS273
//14D
// Sheet 17 wires U1716 D=OH[7:0], Q=FH[7:0]. OH[3:0] is U176's Q while
// OH[7:4] comes from U173. Because U176 and U1716 share CTLT2, U1716 sees
// both old Q values and retains the preceding H2 descriptor.
//
// A previous FPGA workaround fed live OVD[3:0] here. That removed the
// 16-pixel X granularity symptom but bypassed the physical old-Q transfer;
// using u176_Q[3:0] restores the literal sheet-17 chain.
wire [7:0] u1716_d = {OH[7:4], u176_Q[3:0]};

LS273 u1716(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(ctlt2_capture_cen),
   .D(u1716_d),
   .Q(FH[7:0])
);

// U1711/U1712 turn the captured sprite X bases into per-pixel odd/even
// line-buffer write addresses for the two SEI0010/OBJPS serializer lanes.

//SEI0060BU
//12CD
SEI0060BU sei60bu_u1711(
   .clk(clk),
   .cen(OBJ_N6M),
   .ADDR(draw_h2_1_addr_eff[8:0]),
   .ODD_LD(odd_ld_scan),
   .EVN_LD(evn_ld_scan),
   .HBLB(HBLB),
   .OBJT2_7(OBJT2_7),
   .V1B(V1B),
   .T8H(T8H),
   .HREV(HREV),
   .OA(O1A[8:0]),
   .EA(E1A[8:0]),
   .EVNCLR(EVNCLR),
   .ODDCLR(ODDCLR)
);

//SEI0060BU
//16CD
// Sheet 17 feeds U1711 from FH (the preceding H2=1 descriptor) and U1712
// from OH (the current H2=0 descriptor). Cached-row replay happens after the
// live chain has advanced, so the adapter supplies those two retained X bases
// separately as draw_h2_1_addr_eff and draw_h2_0_addr_eff.
SEI0060BU sei60bu_u1712(
   .clk(clk),
   .cen(OBJ_N6M),
   .ADDR(draw_h2_0_addr_eff[8:0]),
   .ODD_LD(odd_ld_scan),
   .EVN_LD(evn_ld_scan),
   .HBLB(HBLB),
   .OBJT2_7(OBJT2_7),
   .V1B(V1B),
   .T8H(T8H),
   .HREV(HREV),
   .OA(O2A[8:0]),
   .EA(E2A[8:0]),
   .EVNCLR(),
   .ODDCLR()
);


endmodule
