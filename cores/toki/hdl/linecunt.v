module LINECUNT(
   input         clk,
   input  [15:0] OVD, //Object Video Data (is it metadata positon for object ?)
   input   [3:0] VA,
   input         ODHREV,
   input         RESETA,
   input         SPR1_3,
   input         SPR2_3,
   input         CTLT1,
   input         CTLT2,
   input         HREV,
   input         OBJ_N6M,
   input         ODD_LD, //odd line data ? odd load ?
   input         EVN_LD,
   input         HBLB,    //hblank
   input         OBJT2_7,
   input         V1B,  //use to switch odd / even ?
   input         T8H,  // cen
   input         VH4,  // cen
   input         VH8,  // cen
   input         NOOBJ,  // ?
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
   output        ODDWREN, // ~EVNCLR
   output        EVNWREN, // ~ODDCLR
   output  [8:0] O2A,     // odd 2 address
   output  [8:0] E2A,     // even 2 address
output        NOOBJ_CT2
);

wire [4:0] ADDR_live;
wire       ROM_CE_live;
wire       NOOBJ_CT2_live;
wire [3:0] OBJCOL_live;
wire       OBJ_HREV_live;
wire       OSP1_live;
wire       OSP2_live;

reg        meta_hold_valid;
reg [11:0] rom_index_hold;
reg [3:0]  line_sel_hold;
reg        rom_ce_hold;
reg [3:0]  objcol_hold;
reg        obj_hrev_hold;
reg        osp1_hold;
reg        osp2_hold;
reg        noobj_ct2_hold;
reg [8:0]  oh_hold;
reg [8:0]  fh_hold;
wire [8:0] OH;
wire [8:0] FH;
wire       evn_ld_scan;
wire       odd_ld_scan;

wire [11:0] rom_index_live;
wire [11:0] rom_index_eff;
wire [3:0]  line_sel_live;
wire [3:0]  line_sel_eff;
wire [11:0] rom_index_cap;
wire [3:0]  line_sel_cap;
wire        rom_ce_cap;
wire [3:0]  objcol_cap;
wire        obj_hrev_cap;
wire        osp1_cap;
wire        osp2_cap;
wire [8:0]  oh_cap;
wire [8:0]  fh_cap;
wire [4:0]  ADDR_eff;
wire        ROM_CE_eff;
wire        NOOBJ_CT2_eff;
wire [8:0]  OH_eff;
wire [8:0]  FH_eff;

assign ADDR_eff      = meta_hold_valid ? rom_index_hold[8:4] : ADDR_live;
assign ROM_CE_eff    = meta_hold_valid ? rom_ce_hold : ROM_CE_live;
assign NOOBJ_CT2_eff = meta_hold_valid ? noobj_ct2_hold : NOOBJ_CT2_live;
assign OBJCOL        = meta_hold_valid ? objcol_hold : OBJCOL_live;
assign OBJ_HREV      = meta_hold_valid ? obj_hrev_hold : OBJ_HREV_live;
assign OSP1          = meta_hold_valid ? osp1_hold : OSP1_live;
assign OSP2          = meta_hold_valid ? osp2_hold : OSP2_live;
assign OH_eff        = meta_hold_valid ? oh_hold : OH;
assign FH_eff        = meta_hold_valid ? fh_hold : FH;
assign NOOBJ_CT2     = NOOBJ_CT2_eff;

// 74LS174 20F
wire [5:0] u171_Q;

LS174 u171_20F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(~CTLT1),
   .D({OVD[10:9], OVD[3:0]}),
   .Q(u171_Q[5:0])
);

// 74LS174 21F
wire [5:0] u172_Q;
wire NC;

LS174 u172_21F(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(~CTLT1),
   .D({1'b0, OVD[15:11]}),
   .Q({NC, u172_Q[4:0]})
);

// 74LS273 20E
wire [6:0] u174_Q;

LS273 u174_20E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(~CTLT2),
   // CTLT1 captures the X-position word into u171/u172. CTLT2 then carries
   // the ROM/index word, so the ROM low nibble must come from the current
   // CTLT2 OVD nibble rather than the CTLT1-captured X low nibble.
   .D({u172_Q[1:0], u171_Q[5:4], OVD[3:0]}),
   .Q({OBJCOL_live[0], u174_Q[6:0]})
);

// 74LS273 21E
wire [3:0] u175_Q;

LS273 u175_21E(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(~CTLT2),
   //.D({ODHREV, VA8, VA4, VA2, VA1, u172_Q[4:2]}),
   .D({ODHREV, VA[3:0], u172_Q[4:2]}),
   .Q({OBJ_HREV_live, u175_Q[3:0], OBJCOL_live[3:1]})
);


//ROM 20C
//HN62404
//4M-bit
assign obj_rom_1_cs = ~ROM_CE_eff;

//ROM 22C
//HN62404
//4M-bit
assign obj_rom_2_cs = ROM_CE_eff;
//split in two ? on original use two separated rom of 16bits
//read same address on the two but enable one or the other with an inverter
//U177 22F
//WE USE ONE ROM NOT TWO SO IT WILL NOT WORK AS IT WE NEED TO << 1 ?
//assign obj_rom_addr[19:1] = {u174_Q[6:4], SG0140_Q[4:0], u174_Q[3:0], VH8, u175_Q[3:0], VH4};
//          rom_index[12:0] << 6
//                           12 bits       6 bits
//                       u174,   addr, u174  |vh8  u175_q, vh4)
                            //3 , 5, 4,     | 1,    4, 1
                            // rom index | line number + rom words index 4bits1
                            // 4 bits => line number * 2 < + rom_words+index

//                                        va[3:0] => line number / 16 ligne of
//                                        pixel
//
//           rom_index[12:0] <= {ram_words[2][15], ram_words[1][11:0]};
//                                                    ADDR ???
//
// One 16x16 sprite tile occupies 64 16-bit words: 16 rows * 4 words/row.
// The old working sprite model fetches them as:
//   row*2 + word[0]           for words 0/1
//   32 + row*2 + word[0]      for words 2/3
// so the low six offset bits are packed as {word[1], row[3:0], word[0]}.
// Using {line_sel, VH8, VH4} makes OFFSET Y act like part of the sprite index
// and breaks the second half of each row. The correct packing is
// {VH8, line_sel, VH4}.
assign obj_rom_1_addr[17:0] = {rom_index_eff, VH8, line_sel_eff, VH4};
assign obj_rom_2_addr[17:0] = {rom_index_eff, VH8, line_sel_eff, VH4};

//XXX just here to check our indexs value is ok 
wire [11:0] rom_index = rom_index_eff;

//rom_index << 7 == obj_rom_addr 
// one tile is 128 byte 

//rom bus  16 bits  (pas 8 bits )
//donc on lit par groupe de 64 bytes pour un tile complet 
//  6 bits pour le current pixel qui doivent etre incrementer 1 par 1 pour
//  lire le sprite ( 16 par ligne pui switch )
//  VH8, u175_Q[3:0], VH4 -> sprite pos 64 
//  le reste c'est l 'index ? (every 64 bits ? )
//
//

//addr IS OK (avec la rom d'origine ca affiche toki pendant un moment)
//
wire [17:0] obj_rom_1_addr_toki = {12'h40, VH8, u175_Q[3:0], VH4};
wire [17:0] obj_rom_2_addr_toki = {12'h40, VH8, u175_Q[3:0], VH4};

assign rom_index_live = {u174_Q[6:4], ADDR_live[4:0], u174_Q[3:0]};
assign rom_index_eff  = meta_hold_valid ? rom_index_hold : rom_index_live;
assign line_sel_live  = u175_Q[3:0];
assign line_sel_eff   = meta_hold_valid ? line_sel_hold : line_sel_live;
assign rom_index_cap  = {u172_Q[0], u171_Q[5:4], ADDR_live[4:0], u174_Q[3:0]};
assign line_sel_cap   = VA[3:0];
assign rom_ce_cap     = OVD[15];
assign objcol_cap     = {u172_Q[4:1]};
assign obj_hrev_cap   = ODHREV;
assign osp1_cap       = SPR1_3;
assign osp2_cap       = SPR2_3;
assign oh_cap         = {OH[8:4], u171_Q[3:0]};
assign fh_cap         = {OH[8:4], u171_Q[3:0]};

// The object ROMs sit behind SDRAM, so data is not stable on every cycle.
// Hold the last valid selected word; otherwise OBJPS can reload the serializer
// with transient 0xffff/garbage between the four fetches that make one sprite row.
wire        pd_use_rom1 = obj_rom_1_cs;
wire [15:0] pd_sel_dual = pd_use_rom1 ? obj_rom_1_data[15:0] : obj_rom_2_data[15:0];
wire        pd_sel_ok   = pd_use_rom1 ? obj_rom_1_ok : obj_rom_2_ok;
reg  [15:0] pd_latch;

always @(posedge clk) begin
   if (RESETA)
      pd_latch <= 16'hffff;
   else if (pd_sel_ok)
      pd_latch <= pd_sel_dual;
end

assign PD[15:0] = pd_latch;

//SEI0140 16D
//MODE=OHMAX
// Object H position extracted from OVD metadata.
//to get data from rom we need the ROM_INDEX which is stored in some of the
//RAM and then the line_number % .. need to translate that

sg0140_ohmax sg0140_u174_16D(
   //input
   .clk(clk),
   .rst(RESETA), // pin 40
   //41, 9, 10, 28-36 1'b0
   .CTLT1(CTLT1),
   .CTLT2(CTLT2),
   //38 CLT1 clk   / ?
   //39 CLT2 clk 2 / en2 ?
   //36,37 1'b1 OHMAX mode
   //.Q({NOOBJ_CT2, ADDR[4:0] ,OH[8:4]})

   //.MODE(2'b11), //OHMAX mode
   .NOOBJ(NOOBJ),
   .OVD(OVD[8:4]),
   .HREV(HREV),
   //output
   //high address were pixel will be written [8:4] (position on screen)
   //the other part 3:0 => 16pixel  is generated  by the sei60bu to draw each
   // of the 16 pixel
   .OH(OH[8:4]),
   .ADDR(ADDR_live[4:0]),
   .NOOBJ_CT2(NOOBJ_CT2_live)
   //.D({OVD[7:4], NOOBJ, OVD[8]}),  //11-16
);


//74LS273
//22E
LS273 u176(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(~CTLT2),
   .D({OH[8], OVD[15],  SPR2_3, SPR1_3 ,u171_Q[3:0]}),
   .Q({FH[8], ROM_CE_live, OSP2_live ,OSP1_live ,OH[3:0]})
);

//74LS04 U177
//wire ROM_CE_N = ~ROM_CE;

//74LS273
//14D
LS273 u1716(
   .CLK(clk),
   .CLRn(1'b1),
   .CEN(~CTLT2),
   .D({OH[7:4], u171_Q[3:0]}),
   .Q(FH[7:0])
);

// transform object H position into an address that will match the line buffer
// position ? so we can get the data via the address ?
// it's storead as 4 bytes blob that will then be deserialzied by objps
// before been stored in ram
// so each ram address effectively store a pixel that's why sei0060bu
// may have two 4 bits counter, it count for each pixel because each one is
// deserialized by the other part objps and thten stored  in ram
//


// act as X pos counter for the line buffer
// so we have the position to store the pixel deserialized by the SEI0010BU (see objps)  in the line buffer

//SEI0060BU
//12CD
SEI0060BU sei60bu_u1711(
   .clk(clk),
   .cen(OBJ_N6M),
   .ADDR(FH_eff[8:0]),
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

//74LS04 22F on schematics generates active-low write enables.
// Start a 16-pixel write burst from the real LD edge, not from the whole
// HBLB-active phase. The broad HBLB model repaints garbage before any valid
// sprite slot is armed.
reg evn_ld_d;
reg odd_ld_d;
reg hblb_d;
reg ctlt2_d;
reg noobj_d;
reg noobj_ct2_d;
reg preload_hold;
reg even_ld_arm;
reg odd_ld_arm;
reg even_ld_pending;
reg odd_ld_pending;
reg even_wren_active;
reg odd_wren_active;
reg [3:0] even_wren_pix;
reg [3:0] odd_wren_pix;
reg        capture_sig_valid;
reg [22:0] capture_sig_last;
reg        slot_shadow_valid;
reg [22:0] slot_sig_shadow;
reg [11:0] rom_index_shadow;
reg [3:0]  line_sel_shadow;
reg        rom_ce_shadow;
reg [3:0]  objcol_shadow;
reg        obj_hrev_shadow;
reg        osp1_shadow;
reg        osp2_shadow;
reg [8:0]  oh_shadow;
reg [8:0]  fh_shadow;
wire evn_ld_fall = (evn_ld_d == 1'b1) && (EVN_LD == 1'b0);
wire odd_ld_fall = (odd_ld_d == 1'b1) && (ODD_LD == 1'b0);
wire hblb_fall   = (hblb_d == 1'b1) && (HBLB == 1'b0);
wire ctlt2_fall  = (ctlt2_d == 1'b1) && (CTLT2 == 1'b0);
// Live MAD traces show the sprite write burst happening while HBLB is low.
// The previous active-high model let bursts arm correctly but never asserted
// EVNWREN/ODDWREN on hardware-consistent waveforms.
wire hblank_active = ~HBLB;
wire burst_active   = even_wren_active || odd_wren_active;
wire [22:0] capture_sig_cur = {OVD[15:0], VA[3:0], ODHREV, SPR1_3, SPR2_3};
wire preload_evt = (noobj_d == 1'b1) && (NOOBJ == 1'b0) &&
                   meta_hold_valid && capture_sig_valid &&
                   (capture_sig_cur == capture_sig_last) &&
                   (rom_index_live != 12'h000) && !burst_active &&
                   !preload_hold;
wire noobj_rise = (noobj_d == 1'b0) && (NOOBJ == 1'b1);
wire noobj2_rise = (noobj_ct2_d == 1'b0) && (NOOBJ_CT2_live == 1'b1);
wire slot_capture_evt = noobj2_rise && !burst_active && slot_shadow_valid &&
                        (!capture_sig_valid || (slot_sig_shadow != capture_sig_last));
wire evn_ld_start = (EVN_LD == 1'b0 || even_ld_pending) &&
                    !V1B && even_ld_arm && !even_wren_active;
wire odd_ld_start = (ODD_LD == 1'b0 || odd_ld_pending) &&
                     V1B &&  odd_ld_arm && !odd_wren_active;
// The write burst can start either from a raw LD pulse that overlaps the armed
// slot, or from a previously seen LD pulse that is held in *_ld_pending until
// the slot is armed. Feed the actual start event to SEI0060BU so it always
// sees a real active-low load edge and captures the held X base.
assign evn_ld_scan = ~evn_ld_start;
assign odd_ld_scan = ~odd_ld_start;

always @(posedge clk) begin
   evn_ld_d <= EVN_LD;
   odd_ld_d <= ODD_LD;
   hblb_d   <= HBLB;
   ctlt2_d  <= CTLT2;
   noobj_d  <= NOOBJ;
   noobj_ct2_d <= NOOBJ_CT2_live;
   if (RESETA) begin
      preload_hold     <= 1'b0;
      even_ld_arm      <= 1'b0;
      odd_ld_arm       <= 1'b0;
      even_ld_pending  <= 1'b0;
      odd_ld_pending   <= 1'b0;
      even_wren_active <= 1'b0;
      odd_wren_active  <= 1'b0;
      even_wren_pix    <= 4'd0;
      odd_wren_pix     <= 4'd0;
      capture_sig_valid <= 1'b0;
      capture_sig_last  <= 23'h0;
      slot_shadow_valid <= 1'b0;
      slot_sig_shadow   <= 23'h0;
      rom_index_shadow  <= 12'h000;
      line_sel_shadow   <= 4'h0;
      rom_ce_shadow     <= 1'b0;
      objcol_shadow     <= 4'h0;
      obj_hrev_shadow   <= 1'b0;
      osp1_shadow       <= 1'b0;
      osp2_shadow       <= 1'b0;
      oh_shadow         <= 9'h000;
      fh_shadow         <= 9'h000;
      noobj_ct2_d       <= 1'b0;
   end else begin
      if (hblb_fall) begin
         preload_hold     <= 1'b0;
         even_ld_arm      <= 1'b0;
         odd_ld_arm       <= 1'b0;
         even_ld_pending  <= 1'b0;
         odd_ld_pending   <= 1'b0;
         even_wren_active <= 1'b0;
         odd_wren_active  <= 1'b0;
         even_wren_pix    <= 4'd0;
         odd_wren_pix     <= 4'd0;
         slot_shadow_valid <= 1'b0;
      end

      if (ctlt2_fall && !NOOBJ) begin
         slot_shadow_valid <= 1'b1;
         slot_sig_shadow   <= capture_sig_cur;
         rom_index_shadow  <= rom_index_live;
         line_sel_shadow   <= line_sel_cap;
         rom_ce_shadow     <= rom_ce_cap;
         objcol_shadow     <= objcol_cap;
         obj_hrev_shadow   <= obj_hrev_cap;
         osp1_shadow       <= osp1_cap;
         osp2_shadow       <= osp2_cap;
         oh_shadow         <= oh_cap;
         fh_shadow         <= fh_cap;
      end

      if (evn_ld_fall && !even_wren_active)
         even_ld_pending <= 1'b1;
      if (odd_ld_fall && !odd_wren_active)
         odd_ld_pending <= 1'b1;

      if (preload_evt)
         preload_hold <= 1'b1;
      if (noobj_rise || hblb_fall)
         capture_sig_valid <= 1'b0;
      if (slot_capture_evt) begin
         capture_sig_valid <= 1'b1;
         capture_sig_last  <= slot_sig_shadow;
         slot_shadow_valid <= 1'b0;
         if (V1B && !odd_wren_active)
            odd_ld_arm <= 1'b1;
         else if (!V1B && !even_wren_active)
            even_ld_arm <= 1'b1;
      end

      if (evn_ld_start) begin
         even_wren_active <= 1'b1;
         even_wren_pix    <= 4'd0;
         even_ld_arm      <= 1'b0;
         even_ld_pending  <= 1'b0;
      end else if (OBJ_N6M && hblank_active && !V1B && even_wren_active) begin
         preload_hold  <= 1'b0;
         even_wren_pix <= even_wren_pix + 4'd1;
         if (even_wren_pix == 4'd15)
            even_wren_active <= 1'b0;
      end

      if (odd_ld_start) begin
         odd_wren_active <= 1'b1;
         odd_wren_pix    <= 4'd0;
         odd_ld_arm      <= 1'b0;
         odd_ld_pending  <= 1'b0;
      end else if (OBJ_N6M && hblank_active && V1B && odd_wren_active) begin
         preload_hold <= 1'b0;
         odd_wren_pix <= odd_wren_pix + 4'd1;
         if (odd_wren_pix == 4'd15)
            odd_wren_active <= 1'b0;
      end
   end
end

always @(posedge clk) begin
   if (RESETA) begin
      meta_hold_valid <= 1'b0;
      rom_index_hold  <= 12'h000;
      line_sel_hold   <= 4'h0;
      rom_ce_hold     <= 1'b0;
      objcol_hold     <= 4'h0;
      obj_hrev_hold   <= 1'b0;
      osp1_hold       <= 1'b0;
      osp2_hold       <= 1'b0;
      noobj_ct2_hold  <= 1'b0;
      oh_hold         <= 9'h000;
      fh_hold         <= 9'h000;
   end else begin
      if (hblb_fall) begin
         meta_hold_valid <= 1'b0;
      end else if (preload_evt) begin
         // Repeated NOOBJ falls before the LD edge must preserve the already
         // captured slot metadata. The preload path only keeps that held slot
         // alive; it must not overwrite X/index/row with whatever happens to
         // be on the live bus at the later NOOBJ edge.
         meta_hold_valid <= 1'b1;
         noobj_ct2_hold  <= 1'b1;
      // Capture the live metadata on the same clock edge that detects the new
      // slot. A registered request delays the copy by one cycle, which is too
      // late in MAD: the good ADDR/index window is already gone by then.
      end else if (slot_capture_evt && !burst_active) begin
         line_sel_hold   <= line_sel_shadow;
         meta_hold_valid <= 1'b1;
         rom_index_hold  <= rom_index_shadow;
         rom_ce_hold     <= rom_ce_shadow;
         objcol_hold     <= objcol_shadow;
         obj_hrev_hold   <= obj_hrev_shadow;
         osp1_hold       <= osp1_shadow;
         osp2_hold       <= osp2_shadow;
         noobj_ct2_hold  <= 1'b1;
         oh_hold         <= oh_shadow;
         fh_hold         <= fh_shadow;
      end else if (!burst_active && !even_ld_arm && !odd_ld_arm && !preload_hold) begin
         meta_hold_valid <= 1'b0;
      end
   end
end

assign EVNWREN = ~(even_wren_active && hblank_active && !V1B);
assign ODDWREN = ~(odd_wren_active  && hblank_active &&  V1B);

//SEI0060BU
//16CD
SEI0060BU sei60bu_u1712(
   .clk(clk),
   .cen(OBJ_N6M),
   .ADDR(OH_eff[8:0]),
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
