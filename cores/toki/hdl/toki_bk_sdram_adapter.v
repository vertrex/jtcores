// Toki scrolling-background mask-ROM adapter for acknowledged FPGA SDRAM.
//
// This module has no PCB IC counterpart and is not a persistent graphics
// cache.  Sheets 7/8 connect each SIS6091 tile descriptor RAM to a local,
// continuously asynchronous 4-Mbit mask ROM and then to SEI0010.  JTFrame
// instead supplies that ROM through shared SDRAM with variable latency, while
// the raster and SEI0010 serializer cannot wait.  This adapter contains only
// the resulting FPGA transport policy: next-row scheduling, three transient
// four-word row buffers, held acknowledged requests, stale-OK suppression,
// coordinate tags, and scroll/reverse invalidation.
//
// The caller deliberately retains the schematic-facing SEI0021, SIS6091 and
// SEI0010 instances.  tile_rd_* drives the synchronous FPGA replacement for
// SIS6091's display port; serializer_data/render_code return one complete,
// coordinate-matched row to the unchanged SEI0010 path.
//
// scroll_change is a caller-qualified event.  It must include SEI0021 reset,
// effective scroll-register value changes and HREV/VREV changes.  An
// idempotent bus write is deliberately not an event: it does not move the
// address of the PCB's asynchronous ROM and must not retire useful FPGA work.
// The extra scroll_realign cycle below preserves the existing SEI0021
// nonblocking-update relationship.
module toki_bk_sdram_adapter #(
  // The synchronous FPGA RAM/SDRAM path reaches the serializer later than
  // the asynchronous mask ROM on the PCB. Keep that measured source phase
  // here, outside the schematic-mapped SEI0021 model.
  parameter [8:0] FPGA_H_SOURCE_PHASE = 9'd4
)(
  input                 clk,
  input                 rst,
  input                 N6M,

  // Normalized JTFrame coordinates are used only for SDRAM deadlines.
  input           [8:0] hpos,
  input           [8:0] vpos,

  // Literal coordinates from the schematic-facing SEI0021 path. pcb_hpos is
  // the raster operand presented to the horizontal IC before scroll addition;
  // pcb_vpos is the corresponding eight-bit vertical operand (pin 39 is T8H).
  input           [8:0] pcb_scrolled_hpos,
  input           [8:0] scrolled_vpos,
  input           [8:0] pcb_hpos,
  input           [8:0] pcb_vpos,
  input                 HREV,
  input                 VREV,
  input                 scroll_change,

  // Display port of the caller-owned SIS6091 tile descriptor RAM.
  input          [15:0] tile_ram_data,
  output                tile_rd_cen,
  output          [9:0] tile_rd_addr,

  // Acknowledged JTFrame mask-ROM port.
  input          [15:0] rom_data,
  input                 rom_ok,
  output         [18:1] rom_addr,
  output                rom_cs,

  // Completed row word and its matching descriptor color code.
  output         [15:0] serializer_data,
  output                serializer_load,
  output reg      [3:0] render_code,

  // The compensated horizontal coordinate is consumed by the caller's
  // schematic-facing SG timing path. Other transport coordinates remain
  // named internally so focused benches can observe them hierarchically.
  output          [8:0] scrolled_hpos
);

// Internal transport coordinates/events remain named for waveform and
// focused-bench observation without widening the production interface.
wire [8:0] render_line_vpos;
wire [8:0] next_line_vpos;
wire [8:0] next_raster_vpos;
wire [1:0] render_word;
wire       tile_boundary;
wire       line_descriptor;
wire       scroll_flush;

// Horizontal coordinate facade.
//
// SEI0021 now sees the literal sheet-7/8 H pins. The validated renderer,
// however, must request and select its registered SDRAM words at an earlier
// source phase. Subtract the physical raster operand from the literal
// scrolled result and add the sampled phase operand. Since both operands are
// captured on the same N6M edge as SEI0021, this changes only the FPGA memory
// schedule; the custom-IC model remains connected like the PCB.
wire [8:0] phase_hpos = hpos - FPGA_H_SOURCE_PHASE;
wire [8:0] phase_pcb_hpos = {
  phase_hpos[8], phase_hpos[7:0] ^ {8{HREV}}
};
reg  [8:0] sampled_pcb_hpos;
reg  [8:0] sampled_phase_pcb_hpos;
reg        sampled_hrev;

// Vertical SEI0021 pin 39 is T8H, not V256. The normalized facade holds the
// current JTFrame raster row after physical V has already advanced at H=254.
wire [7:0] normalized_EXV = vpos[7:0] ^ {8{VREV}};
wire [8:0] normalized_pcb_vpos = {1'b0, normalized_EXV};
reg  [8:0] sampled_pcb_vpos;

always @(posedge clk) begin
  if (rst) begin
    sampled_pcb_hpos       <= 9'd0;
    sampled_phase_pcb_hpos <= 9'd0;
    sampled_hrev           <= 1'b0;
    sampled_pcb_vpos       <= 9'd0;
  end else if (N6M) begin
    sampled_pcb_hpos       <= pcb_hpos;
    sampled_phase_pcb_hpos <= phase_pcb_hpos;
    sampled_hrev           <= HREV;
    sampled_pcb_vpos       <= pcb_vpos;
  end
end

assign scrolled_hpos = pcb_scrolled_hpos - sampled_pcb_hpos +
                       sampled_phase_pcb_hpos;

// SEI0021 pin 2 really drives SEI0010 pin 40. Its opaque decode is not yet
// recovered, and the existing helper must follow the compensated FPGA source
// coordinate to preserve the hardware-tested serializer phase.
assign serializer_load = sampled_hrev ?
                         (scrolled_hpos[1:0] == 2'b00) :
                         (scrolled_hpos[1:0] == 2'b11);

// Preserve the line currently being rendered after physical V advances at
// H=254.  The real SEI0021 remains on the raw EXV phase; this normalized
// facade keeps the old row through the final eight visible pixels.
assign render_line_vpos = scrolled_vpos - sampled_pcb_vpos +
                          normalized_pcb_vpos;

wire [4:0] tile_step = HREV ? 5'h1f : 5'h01;
wire [4:0] next_tile_x = scrolled_hpos[8:4] + tile_step;
wire       tile_start = HREV ? (scrolled_hpos[3:0] == 4'he) :
                               (scrolled_hpos[3:0] == 4'h1);
assign tile_boundary = HREV ? (scrolled_hpos[3:0] == 4'hf) :
                              (scrolled_hpos[3:0] == 4'h0);

// SEI0010 loads one registered SEI0021 phase after its source selection.
// Select a completed next-tile row on the preceding low N6M half-cycle.
wire tile_render_start = HREV ? (scrolled_hpos[3:0] == 4'h0) :
                                (scrolled_hpos[3:0] == 4'hf);

// The 384-pixel raster is not an integer 512-pixel tile-map line.  Two late
// blanking windows explicitly prepare the following raster's partial origin
// tile and the tile after it instead of carrying map tile 24 into tile 0.
assign next_raster_vpos = (vpos == 9'd261) ? 9'd0 : vpos + 9'd1;
wire [7:0] next_normalized_EXV =
             next_raster_vpos[7:0] ^ {8{VREV}};
wire [8:0] next_normalized_pcb_vpos = {1'b0, next_normalized_EXV};
wire [8:0] visible_origin_hpos = HREV ? 9'd253 : 9'd2;
wire [8:0] line_origin_hpos = scrolled_hpos - phase_pcb_hpos +
                              visible_origin_hpos;

// A plain scrolled_vpos+1 is wrong at the physical 261->0 wrap.  Recover the
// following world row from the SEI0021 scroll displacement instead.
assign next_line_vpos = (scrolled_vpos - sampled_pcb_vpos) +
                        next_normalized_pcb_vpos;

wire       line_prefetch_window = (hpos >= 9'd288) && (hpos < 9'd320);
assign line_descriptor = tile_boundary && line_prefetch_window;
wire       line_descriptor_origin = line_descriptor && (hpos < 9'd304);
wire       line_descriptor_second = line_descriptor && (hpos >= 9'd304);
wire [4:0] line_prefetch_tile_x = line_origin_hpos[8:4] +
                                  (line_descriptor_second ? tile_step : 5'd0);

assign tile_rd_cen = tile_boundary;
assign tile_rd_addr = line_descriptor ?
                      {next_line_vpos[8:4], line_prefetch_tile_x} :
                      {render_line_vpos[8:4], next_tile_x};

// These are transient row stores, not a retained graphics cache.  Two banks
// let a future ordinary row fill without overwriting the row being shifted;
// the third preserves the next-line origin while its following row is fetched.
reg [15:0] row_buffer_0 [0:3];
reg [15:0] row_buffer_1 [0:3];
reg [15:0] line_origin_buffer [0:3];
reg  [3:0] code_buffer_0;
reg  [3:0] code_buffer_1;
reg  [3:0] line_origin_code;
reg        line_origin_ready;
reg        fetch_bank;
reg        row_ready;
reg        row_ready_bank;
reg  [4:0] row_ready_target_x;
reg        render_valid;
reg        render_bank;
reg        render_line_origin;
reg        tile_start_d;
reg        descriptor_line;
reg        descriptor_line_origin;
reg        descriptor_pending;
reg  [3:0] descriptor_row;
reg  [4:0] descriptor_target_x;
reg        fetch_line;
reg        fetch_line_origin;
reg  [4:0] fetch_target_x;
reg  [8:0] fetch_target_line;
reg  [8:0] fetch_target_vpos;
reg        fetch_discard;
reg        fetch_revalidate;
reg  [8:0] descriptor_target_line;
reg  [8:0] descriptor_target_vpos;
reg  [8:0] row_ready_target_line;
reg  [8:0] row_ready_target_vpos;
reg  [8:0] line_origin_target_line;
reg  [8:0] line_origin_target_vpos;
reg        scroll_realign;

assign scroll_flush = scroll_change || scroll_realign;

wire tile_start_rise = tile_start && !tile_start_d;

// Install the prefetched origin at H=0 while output is still blank.  Waiting
// for active H=6 races the first serializer load and repeats the old edge.
wire line_render_start = hpos == 9'd0;
wire [8:0] line_render_vpos = render_line_vpos;

// The mask ROM exposes the following four-pixel word while SEI0010 shifts the
// current one.  +1 is the normal registered load phase; +3 is -1 in reverse.
assign render_word = {scrolled_hpos[3], scrolled_hpos[2]} +
                     (HREV ? 2'd3 : 2'd1);
assign serializer_data = !render_valid ? 16'hffff :
                         render_line_origin ? line_origin_buffer[render_word] :
                         render_bank ? row_buffer_1[render_word] :
                                       row_buffer_0[render_word];

wire       fetch_active;
wire [1:0] fetch_word;
wire       fetch_word_valid;
wire [15:0] fetch_word_data;
wire       fetch_done;
wire       fetch_req_ready;

// The PCB mask ROM is asynchronous.  Keep only the unavoidable JTFrame
// acknowledged-ROM sequencing in the reusable transport leaf; coordinate
// tags, transient row banks, deadlines and scroll invalidation remain here.
wire fetch_launch = tile_start_rise && descriptor_pending && !scroll_flush &&
                    fetch_req_ready && !row_ready && !fetch_revalidate;
wire [17:0] fetch_base = {
  tile_ram_data[11:0], 1'b0, descriptor_row, 1'b0
};

jtframe_rom_fetch4 #(
  .AW(18),
  .DW(16),
  .CTX_W(1)
) row_fetch_u (
  .clk(clk),
  .rst(rst),
  .req_valid(fetch_launch),
  .req_ready(fetch_req_ready),
  .req_base(fetch_base),
  .req_ctx(1'b0),
  .rom_cs(rom_cs),
  .rom_addr(rom_addr),
  .rom_data(rom_data),
  .rom_ok(rom_ok),
  .word_valid(fetch_word_valid),
  .word_index(fetch_word),
  .word_data(fetch_word_data),
  .word_ctx(),
  .done(fetch_done),
  .busy(fetch_active)
);

integer row_index;
always @(posedge clk) begin
  tile_start_d <= tile_start;

  if (rst) begin
    fetch_bank      <= 1'b0;
    row_ready       <= 1'b0;
    row_ready_bank  <= 1'b0;
    row_ready_target_x <= 5'h00;
    line_origin_ready <= 1'b0;
    render_valid    <= 1'b0;
    render_bank     <= 1'b0;
    render_line_origin <= 1'b0;
    render_code     <= 4'h0;
    tile_start_d    <= 1'b0;
    descriptor_line <= 1'b0;
    descriptor_line_origin <= 1'b0;
    descriptor_pending <= 1'b0;
    descriptor_row  <= 4'h0;
    descriptor_target_x <= 5'h00;
    descriptor_target_line <= 9'h000;
    descriptor_target_vpos <= 9'h000;
    fetch_line      <= 1'b0;
    fetch_line_origin <= 1'b0;
    fetch_target_x  <= 5'h00;
    fetch_target_line <= 9'h000;
    fetch_target_vpos <= 9'h000;
    fetch_discard   <= 1'b0;
    fetch_revalidate <= 1'b0;
    row_ready_target_line <= 9'h000;
    row_ready_target_vpos <= 9'h000;
    line_origin_target_line <= 9'h000;
    line_origin_target_vpos <= 9'h000;
    scroll_realign   <= 1'b0;
    code_buffer_0   <= 4'h0;
    code_buffer_1   <= 4'h0;
    line_origin_code <= 4'h0;
    for (row_index = 0; row_index < 4; row_index = row_index + 1) begin
      row_buffer_0[row_index] <= 16'hffff;
      row_buffer_1[row_index] <= 16'hffff;
      line_origin_buffer[row_index] <= 16'hffff;
    end
  end else begin
    // SEI0021 commits coordinates with nonblocking assignments.  Hold the
    // adapter invalid through the next N6M edge, when scrolled_* adopts them.
    if (scroll_change)
      scroll_realign <= 1'b1;
    else if (N6M && scroll_realign)
      scroll_realign <= 1'b0;

    // Ordinary descriptors remain valid through the active-line tail.  In
    // blanking admit only the two explicit following-line prefetch windows.
    if (tile_boundary &&
        ((hpos < 9'd262) || line_descriptor) &&
        !scroll_flush) begin
      descriptor_line <= line_descriptor;
      descriptor_line_origin <= line_descriptor_origin;
      descriptor_pending <= 1'b1;
      descriptor_row  <= line_descriptor ? next_line_vpos[3:0] :
                                           render_line_vpos[3:0];
      descriptor_target_x <= tile_rd_addr[4:0];
      descriptor_target_line <= line_descriptor ? next_raster_vpos : vpos;
      descriptor_target_vpos <= line_descriptor ? next_line_vpos :
                                                  render_line_vpos;
    end

    // Expire completed rows which missed their immutable raster deadline.
    if (line_render_start) begin
      if (row_ready && row_ready_target_line != vpos)
        row_ready <= 1'b0;
      if (line_origin_ready && line_origin_target_line != vpos)
        line_origin_ready <= 1'b0;
    end

    if (scroll_flush) begin
      descriptor_pending <= 1'b0;
      // A completed ordinary row already carries immutable X, raster-line
      // and scrolled-V tags.  Keep it until tile_render_start, where those
      // tags are checked against the post-write SEI0021 coordinates before
      // publication.  This is the FPGA equivalent of a completed read from
      // the PCB's continuously asynchronous ROM: a genuine scroll change
      // does not erase data which still names the requested tile.  A stale
      // row is dropped at that same deadline and cannot block the following
      // descriptor.  The separately buffered origin has no X tag and must
      // still be invalidated here.
      line_origin_ready   <= 1'b0;
      if (fetch_active) begin
        // A normal current-line fetch owns the inactive row bank.  It can
        // safely finish while SEI0021 realigns, then use its immutable tags
        // to decide whether the returned row still names the next tile.  The
        // separately buffered next-line/origin requests do not share this
        // current-line publication contract and remain discard-only.
        if (!fetch_line && !fetch_line_origin &&
            fetch_bank != render_bank)
          fetch_revalidate <= 1'b1;
        else begin
          fetch_discard    <= 1'b1;
          fetch_revalidate <= 1'b0;
        end
      end
    end

    // A sequential post-prefetch descriptor belongs to the old 512-pixel map
    // line rather than the new 384-pixel raster origin.
    if (line_render_start)
      descriptor_pending <= 1'b0;

    // The synchronous tile descriptor has settled by tile_start_rise.  Hold
    // each external ROM word address until its acknowledgement arrives.
    if (fetch_launch) begin
      // Ordinary rows always fill the inactive half of the two-bank
      // serializer store.  line-origin rows have their own third buffer, so
      // they do not disturb this ownership invariant.  fetch_bank latches the
      // chosen bank across the complete four-word acknowledged transaction;
      // line-origin writes ignore it.
      fetch_bank      <= ~render_bank;
      fetch_line      <= descriptor_line;
      fetch_line_origin <= descriptor_line && descriptor_line_origin;
      fetch_target_x  <= descriptor_target_x;
      fetch_target_line <= descriptor_target_line;
      fetch_target_vpos <= descriptor_target_vpos;
      fetch_discard   <= 1'b0;
      fetch_revalidate <= 1'b0;
      descriptor_pending <= 1'b0;
      if (descriptor_line && descriptor_line_origin)
        line_origin_code <= tile_ram_data[15:12];
      else if (~render_bank)
        code_buffer_1 <= tile_ram_data[15:12];
      else
        code_buffer_0 <= tile_ram_data[15:12];
    end

    // jtframe_rom_fetch4 rejects the stale OK interval after each address
    // change.  A current-line request which still owns the inactive bank may
    // continue across a coordinate change; its complete result is held for a
    // post-realignment tag check below.  All other interrupted requests are
    // consumed without modifying storage.  The explicit bank test also keeps
    // the historical live-bank counterfactual safe.
    if (fetch_word_valid && !fetch_discard &&
        ((!scroll_flush && !fetch_revalidate) ||
         (!fetch_line && !fetch_line_origin &&
          fetch_bank != render_bank))) begin
      if (fetch_line_origin)
        line_origin_buffer[fetch_word] <= fetch_word_data;
      else if (fetch_bank)
        row_buffer_1[fetch_word] <= fetch_word_data;
      else
        row_buffer_0[fetch_word] <= fetch_word_data;

      if (fetch_done) begin
        if (fetch_line_origin && !fetch_discard && !scroll_flush &&
            ((vpos == fetch_target_line) ||
             (next_raster_vpos == fetch_target_line))) begin
          line_origin_ready <= 1'b1;
          line_origin_target_line <= fetch_target_line;
          line_origin_target_vpos <= fetch_target_vpos;
        end else if (!fetch_line_origin && !fetch_discard &&
                     !fetch_revalidate && !scroll_flush &&
                     ((!fetch_line && vpos == fetch_target_line) ||
                      (fetch_line &&
                       ((vpos == fetch_target_line) ||
                        (next_raster_vpos == fetch_target_line))))) begin
          row_ready      <= 1'b1;
          row_ready_bank <= fetch_bank;
          row_ready_target_x <= fetch_target_x;
          row_ready_target_line <= fetch_target_line;
          row_ready_target_vpos <= fetch_target_vpos;
        end
      end
    end

    // An interrupted ordinary fetch may finish before SEI0021's new value is
    // sampled.  Wait until both the held ROM transaction and realignment are
    // complete, then admit it only if it is still the upcoming tile and its
    // bank is still inactive.  Rejecting tile_render_start itself prevents a
    // response which completed just after its publication edge from lingering
    // until the following tile and blocking the replacement descriptor.
    if (fetch_revalidate && !fetch_active && !scroll_flush) begin
      fetch_revalidate <= 1'b0;
      if (!tile_render_start && fetch_bank != render_bank &&
          fetch_target_line == vpos &&
          fetch_target_vpos == render_line_vpos &&
          fetch_target_x == next_tile_x) begin
        row_ready      <= 1'b1;
        row_ready_bank <= fetch_bank;
        row_ready_target_x <= fetch_target_x;
        row_ready_target_line <= fetch_target_line;
        row_ready_target_vpos <= fetch_target_vpos;
      end
    end

    // Publish only complete coordinate-matched rows.  The serializer keeps
    // its fixed PCB load/shift phases and never waits for SDRAM.
    if (~N6M && !scroll_flush && line_origin_ready && line_render_start &&
        line_origin_target_line == vpos &&
        line_origin_target_vpos == line_render_vpos) begin
      render_valid       <= 1'b1;
      render_line_origin <= 1'b1;
      render_code        <= line_origin_code;
      line_origin_ready  <= 1'b0;
    end else if (~N6M && !scroll_flush && row_ready && hpos >= 9'd6 &&
                 tile_render_start && row_ready_target_line == vpos) begin
      // This is the row's only legal tile deadline.  A mismatch means the
      // coordinate was passed or changed; drop it rather than blocking later
      // rows.  H=1..5 deliberately retains the prefetched second row.
      row_ready <= 1'b0;
      if (row_ready_target_vpos == render_line_vpos &&
          ((scrolled_hpos[8:4] + tile_step) == row_ready_target_x)) begin
        render_valid <= 1'b1;
        render_bank  <= row_ready_bank;
        render_line_origin <= 1'b0;
        render_code  <= row_ready_bank ? code_buffer_1 : code_buffer_0;
      end
    end
  end
end

endmodule
