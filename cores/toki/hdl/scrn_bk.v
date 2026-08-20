////////// SCAN TILE RAM /////////////////////////////
//
// Draw one 16x16 scrolling background from the sheet-7/8 chain:
//
//   SEI0021 H/V -> SIS6091 tile RAM -> mask ROM -> SEI0010
//
// The PCB-facing custom-IC/RAM/serializer blocks remain here.  The physical
// mask ROM is continuously asynchronous; all scheduling, transient row
// storage and acknowledged-SDRAM handling needed by the FPGA live in the
// explicitly non-PCB toki_bk_sdram_adapter module.
module scrn_bk #(
  // FPGA-only source-phase compensation for the registered ROM/serializer
  // facade. S1 uses 5 at the P6M ABSEL boundary; S2 uses 4 at its sheet-8
  // latch boundary. This parameter is passed only to the external FPGA
  // adapter, not to either schematic-mapped SEI0021 instance.
  parameter [8:0] FPGA_H_SOURCE_PHASE = 9'd4
)(
  input                 clk,
  input                 rst,
  input                 N6M,
  input                 WRN6M,

  input          [10:1] KDA,
  input                 DMSL,
  input          [17:1] MAB,
  input          [15:0] MDB_RAM_OUT,
  input          [15:0] MDB_CPU_OUT,

  input                 RST_SH,
  input                 SEL_SH,
  input                 RST_SY,
  input                 SEL_SY,

  input           [8:0] hpos,
  input           [8:0] vpos,
  input           [7:0] EXH,
  input           [7:0] EXV,
  input                 H128,
  input                 H256,
  input                 T8H,
  input                 HREV,
  input                 VREV,

  input          [15:0] rom_data,
  input                 rom_ok,
  output         [18:1] rom_addr,
  output                rom_cs,

  output          [3:0] color,
  output          [3:0] code,
  output                sg_sync
);

wire [8:0] pcb_scrolled_hpos;
wire [8:0] scrolled_hpos;
wire [8:0] scrolled_vpos;
wire       pcb_serializer_load;
wire       serializer_load;

// Literal sheet-7/8 raster operands. U71/U81 pin 38 is raw H128, unlike
// pins 31..37 which have passed through the sheet-5 HREV XOR bank. Vertical
// U72/U82 takes all eight EXV bits; its pin 39 is the separate T8H phase.
wire [8:0] pcb_hpos = {H256, H128 ^ HREV, EXH[6:0]};
wire [8:0] pcb_vpos = {1'b0, EXV};

sei0021bu #(
  .PIN39_IS_MSB(1'b1),
  .PIN38_IS_RAW_H128(1'b1)
) sei21bu_bk1_h(
  .clk(clk),
  .cen(N6M),
  .rst_n(RST_SH),
  .cs_n(SEL_SH),
  .pos({H128, EXH[6:0]}),
  .pin39(H256),
  .rev(HREV),
  .low(MAB[2]),
  .high(MAB[1]),
  .data(MDB_CPU_OUT[7:0]),
  .sync(pcb_serializer_load),
  .scrolled(pcb_scrolled_hpos)
);

sei0021bu #(.PIN39_IS_MSB(1'b0)) sei21bu_bk1_v(
  .clk(clk),
  .cen(N6M),
  .rst_n(RST_SY),
  .cs_n(SEL_SY),
  .pos(EXV),
  .pin39(T8H),
  .rev(VREV),
  .low(MAB[2]),
  .high(MAB[1]),
  .data(MDB_CPU_OUT[7:0]),
  .sync(),
  .scrolled(scrolled_vpos)
);

// SEI0021 horizontal output pin 16 feeds S1CLLT (sheet 7) or the sheet-8
// color latch clock. PCB capture proves a 1-high/7-low waveform, whereas the
// sg_sync interface remains the hardware-tested 2-high/2-low FPGA facade
// until its absolute phase is recovered. Keeping the facade avoids inventing
// an unproven decode.
assign sg_sync = scrolled_hpos[1];

// The asynchronous PCB follows scroll/reverse changes immediately.  Only the
// FPGA row adapter needs invalidation while its registered coordinate and any
// in-flight SDRAM response realign.
reg hrev_d;
reg vrev_d;
always @(posedge clk) begin
  if (rst) begin
    hrev_d <= HREV;
    vrev_d <= VREV;
  end else begin
    hrev_d <= HREV;
    vrev_d <= VREV;
  end
end

wire scroll_selected = !SEL_SH || !SEL_SY;
wire scroll_commit = scroll_selected &&
                     (MAB[2:1] == 2'b10 || MAB[1]);
wire reverse_change = (HREV != hrev_d) || (VREV != vrev_d);
wire scroll_change = !RST_SH || !RST_SY || scroll_commit || reverse_change;

wire [15:0] ram_out;
wire        tile_rd_cen;
wire  [9:0] tile_rd_addr;

sis6091 u_bk1_ram(
  .clk(clk),
  .wr_cen(~WRN6M),
  .wr_en(~DMSL),
  .wr_data(MDB_RAM_OUT[15:0]),
  .wr_addr(KDA[10:1]),
  .rd_cen(tile_rd_cen),
  .rd_addr(tile_rd_addr),
  .rd_data(ram_out[15:0])
);

wire [15:0] data;
wire  [3:0] render_code;

// Named aliases are retained for focused waveform comparison while the large
// FPGA-only implementation now resides behind one explicit boundary.
wire [8:0] render_line_vpos;
wire [8:0] next_line_vpos;
wire [8:0] next_raster_vpos;
wire [1:0] render_word;
wire       tile_boundary;
wire       line_descriptor;
wire       scroll_flush;

toki_bk_sdram_adapter #(
  .FPGA_H_SOURCE_PHASE(FPGA_H_SOURCE_PHASE)
) u_sdram_adapter(
  .clk(clk),
  .rst(rst),
  .N6M(N6M),
  .hpos(hpos),
  .vpos(vpos),
  .pcb_scrolled_hpos(pcb_scrolled_hpos),
  .scrolled_vpos(scrolled_vpos),
  .pcb_hpos(pcb_hpos),
  .pcb_vpos(pcb_vpos),
  .HREV(HREV),
  .VREV(VREV),
  .scroll_change(scroll_change),
  .tile_ram_data(ram_out),
  .tile_rd_cen(tile_rd_cen),
  .tile_rd_addr(tile_rd_addr),
  .rom_data(rom_data),
  .rom_ok(rom_ok),
  .rom_addr(rom_addr),
  .rom_cs(rom_cs),
  .serializer_data(data),
  .serializer_load(serializer_load),
  .render_code(render_code),
  .render_line_vpos(render_line_vpos),
  .scrolled_hpos(scrolled_hpos),
  .next_line_vpos(next_line_vpos),
  .next_raster_vpos(next_raster_vpos),
  .render_word(render_word),
  .tile_boundary(tile_boundary),
  .line_descriptor(line_descriptor),
  .scroll_flush(scroll_flush)
);

wire [1:0] NC;

sei0010bu sei0010bu_u(
  .clk(clk),
  .rst(rst),
  .cen(N6M),
  .load(serializer_load),
  .rev(HREV),
  .rom_data({8'b0, data}),
  .color({NC[1:0], color})
);

assign code = render_code;

endmodule
