`ifndef TOKI_OBJ_SDRAM_ADAPTER_V
`define TOKI_OBJ_SDRAM_ADAPTER_V

// FPGA transport adapter between Toki's sheet-17 asynchronous object-ROM
// renderer and JTFrame's acknowledged SDRAM ports.
//
// This module is deliberately Toki-specific. Descriptor pairing, CTLT/H2
// ownership, V1B epochs, dense-pair seams and the fixed write lifetime all
// reflect this PCB. The schematic TTL/custom-IC shell remains in LINECUNT.
module toki_obj_sdram_adapter(
    input         clk,
    input         RESETA,
    input  [15:0] OVD,
    input   [3:0] VA,
    input         ODHREV,
    input         SPR1_3,
    input         SPR2_3,
    input         CTLT1,
    input         CTLT2,
    input         HREV,
    input         OBJ_N6M,
    input         HBLB,
    input         V1B,
    input         T8H,
    input         VH4,
    input         VH8,
    input         NOOBJ,
    input         ctlt1_capture_d,
    input         ctlt2_capture_cen,
    input   [8:0] FH,
    input   [3:0] OBJCOL_live,
    input         OBJ_HREV_live,
    input         OSP1_live,
    input         OSP2_live,
    input         NOOBJ_CT2_live,
    input         EVNCLR,
    input         ODDCLR,
    input  [17:0] live_rom_addr,
    input  [15:0] obj_rom_1_data,
    input         obj_rom_1_ok,
    input  [15:0] obj_rom_2_data,
    input         obj_rom_2_ok,

    output [17:0] obj_rom_1_addr,
    output        obj_rom_1_cs,
    output [17:0] obj_rom_2_addr,
    output        obj_rom_2_cs,
    output  [3:0] OBJCOL,
    output        OBJ_HREV,
    output        OSP1,
    output        OSP2,
    output [15:0] PD,
    output        NOOBJ_CT2,
    output        FPGA_REPLAY_REV,
    output  [8:0] draw_h2_1_addr_eff,
    output  [8:0] draw_h2_0_addr_eff,
    output        evn_ld_scan,
    output        odd_ld_scan,
    output        ODDWREN,
    output        EVNWREN
);

wire [8:0]  fh_cap;
wire [8:0]  FH_eff;
wire [17:0] draw_pair_eff;

// FPGA-only metadata queue and two-row fill scheduler. The packed descriptor
// format is owned by obj_desc_pair_fifo; this adapter only unpacks the fields
// needed at the asynchronous-ROM boundary and at the physical serializer
// phases. None of this replaces a PCB IC: it absorbs the registered U153 and
// acknowledged SDRAM latency which do not exist on the board.
wire        desc_pair_valid;
wire        desc_pair_ready;
wire [80:0] desc_pair_context;
wire  [5:0] desc_pair_occupancy;
wire        desc_pair_overflow;
wire        desc_pair_protocol_error;
wire        desc_pair_cap_char;
wire        desc_pair_cap_hpos;

localparam [2:0] PAIR_IDLE  = 3'd0;
localparam [2:0] PAIR_PUSH0 = 3'd1;
localparam [2:0] PAIR_WAIT0 = 3'd2;
localparam [2:0] PAIR_PUSH1 = 3'd3;
localparam [2:0] PAIR_WAIT1 = 3'd4;
localparam [2:0] PAIR_READY = 3'd5;

reg  [2:0] pair_fetch_state;
reg [80:0] pair_fetch_context;
reg        pair_fill_bank;
reg        pair_next_bank;
reg [39:0] pair_lane0_ctx [0:1];
reg [39:0] pair_lane1_ctx [0:1];
reg        pair_line_bank [0:1];
reg        pair_render_active;
reg        pair_render_bank;
reg        pair_attr_first_seen;
reg        pair_row_ready;
reg        pair_even_arm;
reg        pair_odd_arm;
reg        pair_draw_started;
reg        pair_draw_seen_active;
reg        pair_seam_primed;
// FPGA acknowledged-ROM publication marker. PAIR_READY means both cached rows
// are complete, so an isolated pair is published as soon as it becomes the
// active render bank. That gives T3F/T3F_2 asynchronous-ROM-like setup before
// FIRST/SECND; line-RAM writing is still held until the matching attributes and
// X counter have transferred. This is transport state, not an extra PCB latch.
reg        pair_replay_armed;
// An acknowledged row request may outlive the raster generation which issued
// it.  The PCB's local ROM cannot do that; this flag retires the completed
// transport response without ever publishing it to the physical serializers.
reg        pair_fetch_discard;
// V1B exchanges list banks near the raster wrap. In the active compact SORT48
// protocol the final old-bank pair is lane 0/slot 46 plus lane 1/slot 47; its
// serializers can still have a legitimate tail after that exchange. They may
// drain through horizontal blank; only the following HBLB rising edge is the
// hard FPGA deadline, when the tagged line RAM becomes visible.
reg        pair_deadline_passed;
// The FPGA line-RAM facade performs an immediate whole-bank clear on the
// physical clear edge. Remember that the current V1B target has seen that
// edge; new-tag rows may then refill it during the remainder of blanking even
// while the schematic active-low clear level stays asserted.
reg        pair_current_bank_cleared;
// Proven normalized FPGA object-scheduling phase. It classifies descriptor
// lanes and acknowledged-ROM replay together, as in the hardware-good build.
reg  [1:0] draw_hphase;
wire       pair_overlap_candidate;
reg        fetch_v1b_d;
wire       fetch_v1b_change = fetch_v1b_d != V1B;

wire [39:0] pair_fetch_lane0 = pair_fetch_context[39:0];
wire [39:0] pair_fetch_lane1 = pair_fetch_context[79:40];
wire        pair_push_lane = pair_fetch_state == PAIR_PUSH1;
wire [39:0] pair_push_desc = pair_push_lane ?
                              pair_fetch_lane1 : pair_fetch_lane0;
wire        pair_push_req = OBJ_N6M && !fetch_v1b_change &&
                            !pair_fetch_discard &&
                            ((pair_fetch_state == PAIR_PUSH0) ||
                             (pair_fetch_state == PAIR_PUSH1));
wire [17:0] pair_push_base = {
    pair_push_desc[11:0], 1'b0, pair_push_desc[35:32], 1'b0
};
wire [39:0] pair_render_lane0 = pair_lane0_ctx[pair_render_bank];
wire [39:0] pair_render_lane1 = pair_lane1_ctx[pair_render_bank];
wire        pair_use_pending_attrs;
wire        pair_attr_bank = pair_use_pending_attrs ?
                             pair_fill_bank : pair_render_bank;
wire [39:0] pair_attr_lane0 = pair_lane0_ctx[pair_attr_bank];
wire [39:0] pair_attr_lane1 = pair_lane1_ctx[pair_attr_bank];
// FIRST captures delayed lane 1 at phase 1 and SECND captures direct lane 0
// at phase 3. Their XOR is therefore the attribute-latch lane selector.
// Serializer ROM/reverse selection is separate below: the corrected physical
// T3F phase makes its load coincide with the decoded attribute edge in the
// common-clock model, while the PCB resolves the two paths by propagation.
wire        pair_phase_lane = draw_hphase[1] ^ draw_hphase[0];
wire [39:0] pair_phase_desc = pair_phase_lane ?
                              pair_attr_lane1 : pair_attr_lane0;

wire  [1:0] render_word;

// Shared-SDRAM transport is kept outside the sheet-17 control model. This
// replay store owns two caller-tagged banks with two lanes each, emulating the
// continuously available independent U168/U162 source words after complete
// rows have returned from SDRAM. The PCB has no corresponding fill/replay RAM.
wire        row_replay_ready;
wire        row_replay_busy;
wire        row_replay_cs;
wire        row_replay_rom_select;
wire [17:0] row_replay_addr;
wire        row_replay_done;
wire  [1:0] row_replay_done_ctx;
wire [15:0] row_replay_pd;
wire [15:0] row_replay_rom_data = row_replay_rom_select ?
                                  obj_rom_2_data : obj_rom_1_data;
wire row_replay_rom_ok = row_replay_rom_select ?
                         obj_rom_2_ok : obj_rom_1_ok;
wire row_replay_req = pair_push_req;
wire row_replay_present = pair_push_desc[39];
wire row_replay_lane = pair_push_lane;
wire row_replay_pair_bank = pair_fill_bank;
wire row_replay_rom_select_in = pair_push_desc[31];
wire row_replay_reverse_in = pair_push_desc[38] ^ HREV;
wire [17:0] row_replay_base = pair_push_base;
// With the literal SEI0050 T3F phase, direct T3F loads at draw_hphase=1 and
// delayed T3F_2 at phase 3. Bit 1 still distinguishes direct lane 0 from
// delayed lane 1 independently of the attribute old-Q selector above.
wire row_replay_lane_out = draw_hphase[1];
// During a dense-pair handoff the delayed U162 serializer loads the following
// pair at phase 3 as SECND transfers registered ownership.
// Select the completed fill bank for that early lane-1 load; all other loads
// retain the render bank. pair_use_pending_attrs is based only on registered
// PAIR_READY state and decoded PCB edges, avoiding a ROM-OK -> flip/address
// combinational loop.
wire row_replay_early_lane1 = pair_use_pending_attrs &&
                              (draw_hphase == 2'b11);
wire row_replay_active_bank = row_replay_early_lane1 ?
                              pair_fill_bank : pair_render_bank;
wire [39:0] pair_replay_lane0 =
    pair_lane0_ctx[row_replay_active_bank];
wire [39:0] pair_replay_lane1 =
    pair_lane1_ctx[row_replay_active_bank];
wire [39:0] pair_replay_desc = row_replay_lane_out ?
                               pair_replay_lane1 : pair_replay_lane0;
wire row_replay_seam_valid = pair_overlap_candidate;
wire row_replay_seam_old_bank = pair_render_bank;
wire row_replay_seam_new_bank = pair_fill_bank;
wire row_replay_seam_reverse = row_replay_lane_out ?
                               (pair_render_lane1[38] ^ HREV) :
                               (pair_render_lane0[38] ^ HREV);
// Lane 0 crosses at word 0 forward / word 3 reverse. Lane 1 crosses at
// word 3 forward / word 0 reverse. The XOR captures both mappings.
wire [1:0] row_replay_seam_word =
    (row_replay_lane_out ^ row_replay_seam_reverse) ? 2'd3 : 2'd0;
wire row_replay_fire = row_replay_req && row_replay_ready;

// Cached rows enter two different physical serializer cadences. With the
// trace-backed SEI0050 T3F phase, replay-to-SIS6091 writes are +2 pixels for
// direct U168/OBJ2 (lane 0) and -2 pixels for delayed U162/U166/OBJ1 (lane 1).
// Pre-rotate by the inverse at this FPGA transport boundary; the
// schematic-mapped OBJPS logic stays exact.
obj_dual_row_replay #(
    .LANE0_PHASE_SHIFT(2),
    .LANE1_PHASE_SHIFT(14)
) row_replay_u(
    .clk(clk),
    .rst(RESETA),
    .push_valid(row_replay_req),
    .push_ready(row_replay_ready),
    .push_present(row_replay_present),
    .push_lane(row_replay_lane),
    .push_pair_bank(row_replay_pair_bank),
    .push_rom_select(row_replay_rom_select_in),
    .push_reverse(row_replay_reverse_in),
    .push_row_base(row_replay_base),
    .rom_cs(row_replay_cs),
    .rom_select(row_replay_rom_select),
    .rom_addr(row_replay_addr),
    .rom_data(row_replay_rom_data),
    .rom_ok(row_replay_rom_ok),
    .active_pair_bank(row_replay_active_bank),
    .replay_lane(row_replay_lane_out),
    .word_sel(render_word),
    .seam_valid(row_replay_seam_valid),
    .seam_old_pair_bank(row_replay_seam_old_bank),
    .seam_new_pair_bank(row_replay_seam_new_bank),
    .seam_word_sel(row_replay_seam_word),
    .seam_reverse(row_replay_seam_reverse),
    .pair_ready(),
    .ready_map(),
    .replay_pd(row_replay_pd),
    .slot_done(row_replay_done),
    .slot_done_ctx(row_replay_done_ctx),
    .busy(row_replay_busy)
);

// Once a cached pair owns replay, the live list scanner may already be showing
// another descriptor. Keep all committed attributes associated with the replay
// row for its complete active/tail lifetime; fall back to the schematic live
// latches only when no cached pair owns the serializers.
assign OBJCOL        = pair_render_active ? pair_phase_desc[15:12] :
                                           OBJCOL_live;
assign OBJ_HREV      = pair_render_active ? pair_phase_desc[38] :
                                           OBJ_HREV_live;
assign OSP1          = pair_render_active ? pair_phase_desc[36] : OSP1_live;
assign OSP2          = pair_render_active ? pair_phase_desc[37] : OSP2_live;
assign NOOBJ_CT2     = pair_render_active ? pair_phase_desc[39] :
                                           NOOBJ_CT2_live;
assign FH_eff        = FH;
//ROM 20C / 22C, HN62404
//
// The PCB ROMs are asynchronous, but the FPGA graphics ROM is behind an
// acknowledged SDRAM port. Hold each request until all four words in a sprite
// row have returned, then present the complete row at its matching later
// serializer/write opportunity. The retained X counters preserve the visible
// position; this transport scheduling is not a fixed one-slot screen delay.
assign obj_rom_1_cs = row_replay_cs && !row_replay_rom_select;
assign obj_rom_2_cs = row_replay_cs &&  row_replay_rom_select;
// Sheet 17 selects one of the two 16-bit mask ROMs through U176 Q7 and U177;
// both devices otherwise see the same 18-bit word address. One 16x16 sprite
// tile occupies 64 16-bit words: 16 rows * 4 words/row. Fetch them as:
//   row*2 + word[0]           for words 0/1
//   32 + row*2 + word[0]      for words 2/3
// so the low six offset bits are packed as {word[1], row[3:0], word[0]}.
// Therefore the live sheet address packs them as {VH8, line_sel, VH4}.
assign obj_rom_1_addr[17:0] = row_replay_cs ? row_replay_addr : live_rom_addr;
assign obj_rom_2_addr[17:0] = row_replay_cs ? row_replay_addr : live_rom_addr;
// FPGA reconstruction for registered U153: capture its settled HPOS response
// directly. On the PCB U1716 instead captures the old OH bus at CTLT2 after the
// OHMAX path. Waiting for that sequential chain here either copies the previous
// high nibble or misses the acknowledged-ROM scheduling deadline.
wire [8:0] hpos_cap = {HREV ? ~OVD[8:4] : OVD[8:4], OVD[3:0]};
assign fh_cap         = hpos_cap;
// The physical ROM may be read for an off-screen descriptor with no visible
// consequence.  On FPGA those reads consume shared SDRAM/cache service time.
// Reuse the established legacy admission rule at the settled HPOS response:
// ordinary X=0x100..0x1f1 cannot reach the 256-pixel line RAM, while
// 0x1f2..0x1ff can wrap its final pixels onto the left edge.  This is an
// FPGA-only scheduling qualification; NOOBJ and all PCB list logic remain
// unchanged.
wire pair_cap_visible_h = !fh_cap[8] || (fh_cap > 9'h1f1);

assign PD[15:0] = pair_render_active && pair_replay_armed ?
                  row_replay_pd : 16'hffff;
// U177's 74LS04 gates generate active-low write enables on sheet 17. The FPGA
// adapter starts a finite 16-pixel burst only after a complete row and its
// effective counter load are committed. Using the whole HBLB-active phase
// repaints garbage before any valid sprite slot is armed.
reg hblb_d;
reg ctlt2_d;
reg even_wren_active;
reg odd_wren_active;
// The hardware-good FPGA object island uses normalized hpos for PLD22, VH4/VH8
// and SORT48. T8H anchors the adapter's matching four-phase scheduler without
// adding an H port to sheet-17 LINECUNT, which has none on the PCB. This is not
// a claim that draw_hphase exposes the literal raw U52 counter pins.
reg [3:0] even_wren_pix;
reg [3:0] odd_wren_pix;
wire hblb_rise   = (hblb_d == 1'b0) && (HBLB == 1'b1);
wire ctlt2_fall  = (ctlt2_d == 1'b1) && (CTLT2 == 1'b0);
wire burst_active   = even_wren_active || odd_wren_active;
// Recover the compatibility H4/H8 classification from the normalized VH4/VH8
// XOR buses. The first CTLT2 sample in each 16-pixel bucket is the stable
// per-slot metadata point, including dense lists where NOOBJ never returns
// high.
wire opsrev_eff = HREV ^ OBJ_HREV;
wire h4_phase = ~(VH4 ^ opsrev_eff);
wire h8_phase = VH8 ^ ~h4_phase ^ opsrev_eff;
// VH4/VH8 retain the sheet-16 shared-bus equations but are currently generated
// from normalized hpos. They follow the attribute old-Q lane at FIRST/SECND,
// while the acknowledged replay store may simultaneously feed the opposite
// serializer lane. Recover the common H4/H8 classification above, then apply
// the replay lane's own direction only at this FPGA ROM-address boundary.
// This keeps the external sheet-16 OPSREV wiring literal while preventing a
// mixed-flip row from addressing its neighbour's word order.
wire replay_opsrev = HREV ^ pair_replay_desc[38];
wire replay_vh4 = ~h4_phase ^ replay_opsrev;
wire replay_vh8 = h8_phase ^ ~h4_phase ^ replay_opsrev;
assign render_word = {replay_vh8, replay_vh4};
assign FPGA_REPLAY_REV = replay_opsrev;

// U153 is a registered FPGA RAM. Start capture at the decoded CTLT falling
// edge, then obj_desc_pair_fifo samples OVD one master clock later. Restrict
// capture to the settled normalized H=4/5 (lane 0) and H=6/7 (lane 1) repeat
// used by the hardware-good FPGA renderer; draw_hphase[1] selects the lane.
assign desc_pair_cap_char = ctlt1_capture_d && !CTLT1 &&
                            h4_phase && !h8_phase;
assign desc_pair_cap_hpos = ctlt2_fall && h4_phase && !h8_phase;

// Once active video begins, an opposite-bank head has missed the only blanking
// interval in which it could finish. Pop it without publishing it to the ROM
// scheduler. FIFO order places every expired old-bank head before the new-bank
// slots captured after V1B, so one-clock stale pops preserve all fresh work.
// pair_deadline_passed still contains the preceding epoch on the clock which
// toggles V1B.  Suppress it on that edge: V1B starts the new grace interval,
// it does not expire the old tail immediately.
wire pair_deadline_window = !fetch_v1b_change &&
                            (pair_deadline_passed || hblb_rise);
wire desc_pair_stale = pair_deadline_window && desc_pair_valid &&
                       (desc_pair_context[80] != V1B);
wire pair_fetch_stale = pair_fetch_context[80] != V1B;
wire pair_render_stale = pair_render_active &&
                         (pair_line_bank[pair_render_bank] != V1B);
// During the V1B-to-HBLB-rise grace, preceding/opposite-tag work may finish.
// Current-tag work may publish as soon as the target bank's global-clear edge
// has been observed. This retains the PCB's usable blanking bandwidth while
// making the FPGA BRAM clear operation explicit and atomic.
wire pair_fill_is_current = pair_line_bank[pair_fill_bank] == V1B;
wire pair_fill_epoch_window = pair_fill_is_current ?
                              pair_current_bank_cleared :
                              !pair_deadline_window;
wire pair_fill_writable = !fetch_v1b_change &&
                          pair_fill_epoch_window;
// Expired FIFO heads are independent of an admitted transport request. Pop
// them even while that request waits, otherwise an old head can survive until
// V1B parity aliases back and be mistaken for current work two lines later.
assign desc_pair_ready = desc_pair_stale ||
                         ((pair_fetch_state == PAIR_IDLE) &&
                          !fetch_v1b_change);

obj_desc_pair_fifo desc_pair_fifo_u(
   .clk(clk),
   .rst(RESETA),
   // A consume epoch straddles V1B: the final old-bank compact {46,47} pair can
   // drain in blanking while the first new-bank {0,1} pair queues behind it. A
   // raw V1B flush therefore destroys valid work. Expiration is selective
   // above.
   .flush(1'b0),
   .cap_char(desc_pair_cap_char),
   .cap_hpos(desc_pair_cap_hpos),
   .cap_lane(draw_hphase[1]),
   .cap_present(!NOOBJ && pair_cap_visible_h),
   .cap_row(VA),
   .cap_flip(ODHREV),
   .cap_spr1(SPR1_3),
   .cap_spr2(SPR2_3),
   .cap_bank(V1B),
   .ovd(OVD),
   .out_valid(desc_pair_valid),
   .out_ready(desc_pair_ready),
   .out_context(desc_pair_context),
   .occupancy(desc_pair_occupancy),
   .overflow(desc_pair_overflow),
   .protocol_error(desc_pair_protocol_error)
);
// Classify each active-low CTLT2 pulse at its falling edge, before a pending
// pair's flip/attribute bus is presented. Using the saved classification at
// the rising capture edge both mirrors the decoded-clock pulse and avoids a
// combinational path from OBJ_HREV through VH4/VH8 back into attribute-bank
// selection.
reg pair_ctlt2_first_phase;
reg pair_ctlt2_second_phase;

always @(posedge clk) begin
   if (RESETA) begin
      pair_ctlt2_first_phase  <= 1'b0;
      pair_ctlt2_second_phase <= 1'b0;
   end else if (ctlt2_fall) begin
      pair_ctlt2_first_phase  <= h4_phase && !h8_phase &&
                                 !draw_hphase[1];
      pair_ctlt2_second_phase <= h4_phase && !h8_phase &&
                                  draw_hphase[1];
   end
end

// At normalized scheduler phase H=5, the CTLT2/FIRST rising edge transfers the
// preceding H2=1 descriptor. SG0140 and U176 still expose that old complete OH
// bus on the RHS of this edge, the X context belonging to U162/U1711.
wire pair_h2_1_capture_evt = ctlt2_capture_cen &&
                             pair_ctlt2_first_phase;
wire pair_h2_0_transfer_evt = ctlt2_capture_cen &&
                              pair_ctlt2_second_phase;
// The active-low FIRST/CTLT2 pulse begins before T3F rises. Retain its qualified
// falling edge as an explicit replay-setup event for the asynchronous-ROM
// timing contract. PAIR_READY currently publishes an isolated complete row
// earlier; attribute old-Q transfer still occurs at the pulse's rising edge.
wire pair_h2_1_replay_prime_evt = ctlt2_fall &&
                                  h4_phase && !h8_phase &&
                                  !draw_hphase[1];
// Only a registered PAIR_READY may affect the live attribute bus. Feeding a
// combinational SDRAM/cache completion into this decision creates a path from
// ROM OK through OBJ_HREV and the graphics address back to ROM OK. Cache hits
// complete several 48 MHz clocks before the following FIRST slot, so the
// registered boundary preserves full raster throughput without that loop.
wire pair_pending_ready = pair_fetch_state == PAIR_READY;
// The PCB primes the following descriptor pair while the current serializers
// shift their final pixels. FIRST receives pending lane 1; SECND transfers it
// and captures pending lane 0 after the old replay bank's last T3F_2 load.
// Keep this overlap only within the live target line-bank epoch. The FPGA
// replay boundary handles equal and mixed serializer directions separately,
// so a flip change no longer needs a half-rate isolated-pair fallback.
assign pair_overlap_candidate = pair_render_active && pair_draw_started &&
                                burst_active && pair_pending_ready &&
                                pair_fill_writable &&
                                (pair_line_bank[pair_fill_bank] ==
                                 pair_line_bank[pair_render_bank]);
// Lane 1's boundary word is consumed two pixels before FIRST. Require that
// splice to have happened before allowing FIRST/SECND to overlap the pair.
// A late cache completion falls back to an isolated pair start instead of
// exposing a partially primed serializer.
wire pair_overlap_eligible = pair_overlap_candidate && pair_seam_primed;
// FIRST primes pending lane 1.  Keep that same tagged descriptor on the
// shared attribute bus through its phase-3 T3F_2 load; SECND then moves
// the registered render bank and captures pending lane 0.  Limiting the mux
// to the two edge pulses made the bus fall back to the old pair between them.
assign pair_use_pending_attrs = pair_overlap_eligible &&
                                (pair_h2_1_capture_evt ||
                                 pair_attr_first_seen);
wire pair_overlap_handoff = pair_overlap_eligible &&
                            pair_h2_0_transfer_evt &&
                            pair_attr_first_seen;
wire pair_normal_counter_load = pair_render_active &&
                                pair_h2_0_transfer_evt &&
                                pair_attr_first_seen &&
                                !pair_row_ready && !pair_draw_started;
wire pair_counter_load = pair_overlap_handoff ||
                         pair_normal_counter_load;
wire pair_counter_bank = pair_overlap_handoff ?
                         pair_fill_bank : pair_render_bank;
wire [39:0] pair_counter_lane0 = pair_lane0_ctx[pair_counter_bank];
wire [39:0] pair_counter_lane1 = pair_lane1_ctx[pair_counter_bank];
wire [17:0] pair_counter_x = {
    pair_counter_lane1[24:16], pair_counter_lane0[24:16]
};
wire pair_counter_line_bank = pair_line_bank[pair_counter_bank];
// The descriptor's captured list-bank tag chooses the physical writer. V1B
// can change before the final old-bank pair begins, so qualifying these arms
// with the live selector would strand that legitimate blanking tail.
wire evn_ld_start = pair_even_arm && pair_row_ready &&
                    !even_wren_active;
wire odd_ld_start = pair_odd_arm && pair_row_ready &&
                    !odd_wren_active;

// Retain the registered epoch detector used by the FIFO, transport and
// serializer stale-work guards.
always @(posedge clk) begin
   if (RESETA)
      fetch_v1b_d <= 1'b0;
   else
      fetch_v1b_d <= V1B;
end

// The complete ROM row is prefetched before the serializer starts. Only the
// two OBJPS output registers remain between the effective LD/start event and
// the pixel presented to the line buffer. Delaying by a full 16-pixel ROM
// cadence catches the next repetition instead of the intended row. The adapter
// therefore regenerates the sheet-equivalent counter load at SECND and owns the
// finite WREN lifetime. The former thirteen-beat delay left the first pair's X
// counter active after SECND had selected the next replay row, associating
// dense data with the preceding 32-pixel pair.
wire even_draw_active = even_wren_active;
wire odd_draw_active  = odd_wren_active;
// On the PCB PLD22 SECND/EVN_LD/ODD_LD loads the physical SEI0060 counter. The
// adapter generates the equivalent load only after the row is ready, and its
// explicit write lifetime begins on the following scheduler arm. Starting it
// on the same common-clock edge writes the preceding pixel twice and drops
// pixel 15.
wire evn_draw_load = pair_counter_load && !pair_counter_line_bank;
wire odd_draw_load = pair_counter_load &&  pair_counter_line_bank;

assign draw_pair_eff = evn_draw_load ?
                       pair_counter_x :
                       odd_draw_load ?
                       pair_counter_x :
                       {FH_eff, FH_eff};
assign draw_h2_1_addr_eff = draw_pair_eff[17:9];
assign draw_h2_0_addr_eff = draw_pair_eff[8:0];
// Load the physical X counter only when the delayed serializer pixels reach
// the line-buffer window. Loading it at evn/odd_ld_start as well lets the next
// dense sprite reset the counter while the previous sprite is still writing,
// producing non-monotonic addresses such as X+0, X+1, X-15.
assign evn_ld_scan = ~evn_draw_load;
assign odd_ld_scan = ~odd_draw_load;

// Two-lane acknowledged-ROM fill and render ownership. One pair bank may be
// active in the serializers while the other is filled. A bank is never
// exposed until both lane pushes have completed, including an explicit
// transparent completion for an absent descriptor.
integer pair_bank_index;
always @(posedge clk) begin
   if (RESETA) begin
      pair_fetch_state       <= PAIR_IDLE;
      pair_fetch_context     <= 81'b0;
      pair_fill_bank         <= 1'b0;
      pair_next_bank         <= 1'b0;
      pair_render_active     <= 1'b0;
      pair_render_bank       <= 1'b0;
      pair_attr_first_seen   <= 1'b0;
      pair_row_ready         <= 1'b0;
      pair_even_arm          <= 1'b0;
      pair_odd_arm           <= 1'b0;
      pair_draw_started      <= 1'b0;
      pair_draw_seen_active  <= 1'b0;
      pair_seam_primed       <= 1'b0;
      pair_replay_armed      <= 1'b0;
      pair_fetch_discard     <= 1'b0;
      pair_deadline_passed   <= 1'b0;
      pair_current_bank_cleared <= 1'b0;
      for (pair_bank_index = 0; pair_bank_index < 2;
           pair_bank_index = pair_bank_index + 1) begin
         pair_lane0_ctx[pair_bank_index] <= 40'b0;
         pair_lane1_ctx[pair_bank_index] <= 40'b0;
         pair_line_bank[pair_bank_index] <= 1'b0;
      end
   end else begin
      // V1B opens a short physical tail interval.  HBLB rises only after the
      // raster has wrapped, at which point the tagged RAM becomes visible and
      // any remaining old-bank work is no longer safe to publish.
      if (fetch_v1b_change)
         pair_deadline_passed <= 1'b0;
      else if (hblb_rise)
         pair_deadline_passed <= 1'b1;

      if (fetch_v1b_change)
         pair_current_bank_cleared <= 1'b0;
      else if ((V1B && !EVNCLR) || (!V1B && !ODDCLR))
         pair_current_bank_cleared <= 1'b1;

      if (desc_pair_valid && desc_pair_ready && !desc_pair_stale) begin
         pair_fetch_context <= desc_pair_context;
         pair_fill_bank     <= pair_next_bank;
         pair_lane0_ctx[pair_next_bank] <= desc_pair_context[39:0];
         pair_lane1_ctx[pair_next_bank] <= desc_pair_context[79:40];
         pair_line_bank[pair_next_bank] <= desc_pair_context[80];
         pair_fetch_state   <= PAIR_PUSH0;
         pair_fetch_discard <= 1'b0;
      end else begin
         // A stale FIFO handshake deliberately falls through here: it pops
         // only the queue head while this admitted fetch FSM keeps running.
         case (pair_fetch_state)
            PAIR_PUSH0: begin
               if (row_replay_fire) begin
                  if (pair_fetch_lane0[39])
                     pair_fetch_state <= PAIR_WAIT0;
                  else
                     pair_fetch_state <= PAIR_PUSH1;
               end
            end

            PAIR_WAIT0: begin
               if (row_replay_done &&
                   (row_replay_done_ctx == {pair_fill_bank, 1'b0})) begin
                  if (pair_fetch_discard) begin
                     pair_fetch_state   <= PAIR_IDLE;
                     pair_fetch_discard <= 1'b0;
                  end else begin
                     pair_fetch_state <= PAIR_PUSH1;
                  end
               end
            end

            PAIR_PUSH1: begin
               if (row_replay_fire) begin
                  if (pair_fetch_lane1[39])
                     pair_fetch_state <= PAIR_WAIT1;
                  else
                     pair_fetch_state <= PAIR_READY;
               end
            end

            PAIR_WAIT1: begin
               if (row_replay_done &&
                   (row_replay_done_ctx == {pair_fill_bank, 1'b1})) begin
                  if (pair_fetch_discard) begin
                     pair_fetch_state   <= PAIR_IDLE;
                     pair_fetch_discard <= 1'b0;
                  end else begin
                     pair_fetch_state <= PAIR_READY;
                  end
               end
            end

            PAIR_READY: begin
               // Keep the completed bank reserved while the prior pair is
               // still feeding PD. A delayed line-buffer tail no longer owns
               // the replay row, so it must not add a 16-pixel dead slot.
               if (!pair_render_active && !burst_active &&
                   !even_wren_active && !odd_wren_active &&
                   pair_fill_writable) begin
                  pair_render_active   <= 1'b1;
                  pair_render_bank     <= pair_fill_bank;
                  pair_attr_first_seen <= 1'b0;
                  pair_row_ready       <= 1'b0;
                  pair_even_arm        <= 1'b0;
                  pair_odd_arm         <= 1'b0;
                  pair_draw_started    <= 1'b0;
                  pair_draw_seen_active <= 1'b0;
                  pair_seam_primed     <= 1'b0;
                  // Both cached rows are complete before PAIR_READY. Publish
                  // the isolated bank immediately so its serializers can
                  // pre-load before FIRST/SECND, matching the setup already
                  // provided by asynchronous mask ROM on the PCB. No line-RAM
                  // write is armed until the physical attribute/X edges.
                  pair_replay_armed    <= 1'b1;
                  pair_next_bank       <= ~pair_fill_bank;
                  pair_fetch_state     <= PAIR_IDLE;
               end
            end

            default: begin
               // PAIR_IDLE changes state only on the FIFO handshake above.
            end
         endcase
      end

      // FIRST at normalized H=5 primes delayed OBJ1/lane 1. SECND at normalized
      // H=7 transfers it through U165 and captures direct OBJ2/lane 0 through
      // U169. Only after both old-Q edges may the shared write burst start.
      if (pair_render_active && pair_h2_1_replay_prime_evt)
         pair_replay_armed <= 1'b1;

      if (pair_render_active && pair_h2_1_capture_evt)
         pair_attr_first_seen <= 1'b1;

      // The delayed lane's critical boundary word loads at phase 3. The seam
      // mux is already combinationally valid on this beat; remember that it
      // completed so the later FIRST/SECND handoff may proceed safely.
      if (pair_overlap_candidate && OBJ_N6M &&
          (draw_hphase == 2'b11) &&
          (render_word == row_replay_seam_word))
         pair_seam_primed <= 1'b1;

      // Dense lists require one pair every 16 pixels. At SECND the old bank
      // has supplied its final delayed serializer load, while U165/U169 see
      // the pending attributes primed at FIRST. Switch replay/context banks
      // atomically and arm the next source burst without deasserting ACTIVE.
      if (pair_overlap_handoff) begin
         pair_render_bank       <= pair_fill_bank;
         pair_next_bank         <= ~pair_fill_bank;
         pair_fetch_state       <= PAIR_IDLE;
         pair_row_ready         <= 1'b1;
         pair_even_arm          <= !pair_line_bank[pair_fill_bank];
         pair_odd_arm           <= pair_line_bank[pair_fill_bank];
         pair_draw_started      <= 1'b0;
         pair_draw_seen_active  <= 1'b0;
         pair_seam_primed       <= 1'b0;
         pair_attr_first_seen   <= 1'b0;
      end else if (pair_render_active && pair_h2_0_transfer_evt &&
          pair_attr_first_seen && !pair_row_ready &&
          !pair_draw_started) begin
         pair_row_ready <= 1'b1;
         if (pair_line_bank[pair_render_bank])
            pair_odd_arm <= 1'b1;
         else
            pair_even_arm <= 1'b1;
      end

      if (evn_ld_start || odd_ld_start) begin
         pair_row_ready <= 1'b0;
         pair_even_arm <= 1'b0;
         pair_odd_arm <= 1'b0;
         pair_draw_started <= 1'b1;
         pair_attr_first_seen <= 1'b0;
      end

      if (pair_draw_started && burst_active)
         pair_draw_seen_active <= 1'b1;

      // Once the sixteen source beats have loaded OBJPS, replay data and
      // metadata are no longer needed by the delayed line-buffer tail.
      if (pair_draw_started && pair_draw_seen_active &&
          !burst_active && !pair_overlap_handoff) begin
         pair_render_active <= 1'b0;
         pair_draw_started <= 1'b0;
         pair_draw_seen_active <= 1'b0;
         pair_attr_first_seen <= 1'b0;
         pair_seam_primed <= 1'b0;
         pair_replay_armed <= 1'b0;
      end

      // HBLB's following rising edge, rather than raw V1B, is the physical
      // publication deadline.  This block is intentionally last so expiry
      // wins over coincident fetch, handoff and serializer-prime events.
      // An admitted transport request must finish to keep the reusable ROM
      // bridge coherent; pair_fetch_discard makes that retirement sticky even
      // if V1B parity aliases back before the delayed response returns.
      if (pair_deadline_window && pair_fetch_stale) begin
         case (pair_fetch_state)
            PAIR_PUSH0: begin
               if (row_replay_fire && pair_fetch_lane0[39]) begin
                  pair_fetch_state   <= PAIR_WAIT0;
                  pair_fetch_discard <= 1'b1;
               end else begin
                  pair_fetch_state   <= PAIR_IDLE;
                  pair_fetch_discard <= 1'b0;
               end
            end
            PAIR_PUSH1: begin
               if (row_replay_fire && pair_fetch_lane1[39]) begin
                  pair_fetch_state   <= PAIR_WAIT1;
                  pair_fetch_discard <= 1'b1;
               end else begin
                  pair_fetch_state   <= PAIR_IDLE;
                  pair_fetch_discard <= 1'b0;
               end
            end
            PAIR_READY: begin
               pair_fetch_state   <= PAIR_IDLE;
               pair_fetch_discard <= 1'b0;
            end
            PAIR_WAIT0: begin
               if (row_replay_done &&
                   (row_replay_done_ctx == {pair_fill_bank, 1'b0})) begin
                  pair_fetch_state   <= PAIR_IDLE;
                  pair_fetch_discard <= 1'b0;
               end else begin
                  pair_fetch_discard <= 1'b1;
               end
            end
            PAIR_WAIT1: begin
               if (row_replay_done &&
                   (row_replay_done_ctx == {pair_fill_bank, 1'b1})) begin
                  pair_fetch_state   <= PAIR_IDLE;
                  pair_fetch_discard <= 1'b0;
               end else begin
                  pair_fetch_discard <= 1'b1;
               end
            end
            default: pair_fetch_discard <= 1'b0;
         endcase
      end

      // READY, pre-draw and an overlong active serializer all name the same
      // captured line-bank. None may survive into that bank's visible phase.
      if (pair_deadline_window && pair_render_stale) begin
         pair_render_active      <= 1'b0;
         pair_attr_first_seen    <= 1'b0;
         pair_row_ready          <= 1'b0;
         pair_even_arm           <= 1'b0;
         pair_odd_arm            <= 1'b0;
         pair_draw_started       <= 1'b0;
         pair_draw_seen_active   <= 1'b0;
         pair_seam_primed        <= 1'b0;
         pair_replay_armed       <= 1'b0;
      end
   end
end

always @(posedge clk) begin
   hblb_d   <= HBLB;
   ctlt2_d  <= CTLT2;
   if (RESETA) begin
      even_wren_active <= 1'b0;
      odd_wren_active  <= 1'b0;
      draw_hphase      <= 2'b00;
      even_wren_pix    <= 4'd0;
      odd_wren_pix     <= 4'd0;
   end else begin
      if (OBJ_N6M) begin
         if (T8H)
            draw_hphase <= 2'b11;
         else
            draw_hphase <= draw_hphase + 2'b01;
      end

      // The counter load and serializer transfer occur at SECND. Commit the
      // FPGA line-RAM lifetime on the following scheduler arm, when pixel 0
      // is present at the sheet-18 input.
      if (evn_ld_start) begin
         even_wren_active <= 1'b1;
         even_wren_pix    <= 4'd0;
      // The selected bank is latched in even_wren_active. Do not also gate the
      // 16-pixel lifetime with live V1B: V1B can change while a queued burst is
      // still draining, which otherwise freezes the burst for the next line
      // and blocks all following slot captures through burst_active.
      end else if (OBJ_N6M && even_wren_active) begin
         even_wren_pix <= even_wren_pix + 4'd1;
         if (even_wren_pix == 4'd15)
            even_wren_active <= 1'b0;
      end

      if (odd_ld_start) begin
         odd_wren_active <= 1'b1;
         odd_wren_pix    <= 4'd0;
      end else if (OBJ_N6M && odd_wren_active) begin
         odd_wren_pix <= odd_wren_pix + 4'd1;
         if (odd_wren_pix == 4'd15)
            odd_wren_active <= 1'b0;
      end

      // The old tagged writer may legitimately run after V1B and through
      // horizontal blank.  At the following active-video edge it must stop
      // unconditionally; this ordering makes the deadline win over a start or
      // pixel increment on the same master clock.
      if (pair_deadline_window && pair_render_stale) begin
         even_wren_active <= 1'b0;
         odd_wren_active  <= 1'b0;
         even_wren_pix    <= 4'd0;
         odd_wren_pix     <= 4'd0;
      end
   end
end

// PLD22 names EVN_LD/ODD_LD for the alternating V1B phases, not for the
// physical RAM that receives the pixels. Original-board SEI0060 captures show
// the crossing explicitly: V1B=0/EVN_LD routes the write counter to OA, while
// V1B=1/ODD_LD routes it to EA. Drive the matching sheet-18 active-low enable.
// A final visible sprite may drain into horizontal blank; the latched phase
// keeps that 16-pixel burst on the same physical bank.
// pair_even_arm/pair_odd_arm already captured the target line-bank. Keep the
// physical RAM enable tied to that stored writer for its complete lifetime;
// live V1B is a read-role selector and changes before the legal old-bank tail.
assign EVNWREN = ~odd_draw_active;
assign ODDWREN = ~even_draw_active;

endmodule

`endif
