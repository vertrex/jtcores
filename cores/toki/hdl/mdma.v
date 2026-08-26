///////////// Memory DMA - schematic sheet 6 //////////////////
// Copies 4096 16-bit CPU-work-RAM words to four 1024-word video
// destinations: palette, background 1, background 2 and SCR4.
module MDMA(
    input clk,
    input rst,
    // 6 MHz phase enables. P6M is retained for the sheet-6 interface;
    // WRN6M/counting use its complementary N6M phase in this clock domain.
    input P6M,
    input N6M,
    // System reset 
    //input SYS_RESET,

    // Memory DMA Request 
    input MDMARQ,
    // Bus Acknowledge 
    input BUSAK,
    // X pos 4 
    input EXH_4,

    // ~X pos 4 
    output EXH_4_n,
    // ~ P6M 
    output WRN6M,
    // Memory Bus Request, active low
    output reg MBUSRQ,

    // Memory Bus Direction (R/W) , DMA Arbitration
    output MBUSDIR,
    // DMA select palette 
    output DMSL_GL,
    // DMA select background 1
    output DMSL_S1, 
    // DMA select background 2
    output DMSL_S2,
    // DMA select char
    output DMSL_S4,

    // DMA counter (0..4095)
    output [12:1] KDA,
    // Memory Address Bus  
    //output MAB[15:1],
    // DMA Ready (DMA copy is finished)
    //output [15:1] MAB,
    output DMARD
);

// The PCB sequencer is U653A/U654A/U655B/U656B (four 74LS74 halves), followed
// by U657/U658/U659 (three cascaded 74LS161 counters).  Generated PCB clocks
// are represented as enables in the 48-MHz domain.  Only U654A cannot map to
// a native FPGA flip-flop; its documented replacement is kept in a separate
// module.  Positive internal state names represent the active form of the
// PCB's active-low inter-stage paths.  The externally visible sequence is
// unchanged.
reg        dma_active;       // U656B: counter/bus ownership stage
reg        dma_pending;      // retained U653A request state
reg        mdmarq_d;         // U653A positive-edge representation
reg        grant_first_n6m;  // U655B: first WRN6M grant stage
reg [11:0] dma_count;        // U659:U658:U657 counter outputs

wire [3:0] u657_q = dma_count[3:0];
wire [3:0] u658_q = dma_count[7:4];
wire [3:0] u659_q = dma_count[11:8];
wire       copy_end = &{u659_q, u658_q, u657_q};
wire       dma_retire = dma_active && N6M && copy_end;

wire q_6k1 = ~dma_active; // active-low enable used by PCB decoder U7L
wire mdmarq_rise = MDMARQ && !mdmarq_d;

// U654A uses only asynchronous /PRE and /CLR on the PCB; D and CLK are
// inactive. Cyclone V cannot map both controls into one native flip-flop, so
// use the shared FPGA retained-state primitive. PRE_N is the sheet-6
// MBUSRQ|BUSAK equation and CLR_N is the terminal-count retirement. Its live
// Q preserves the physical preset visibility into U655B on a coincident N6M
// edge without a Toki-specific transport facade.
wire grant_now;
fpga_async_set_clear u654a_fpga(
    .clk   (clk),
    .rst   (rst),
    .PRE_N (MBUSRQ | BUSAK),
    .CLR_N (!dma_retire),
    .Q     (grant_now),
    .QN    ()
);

wire start_dma = !dma_active && N6M && grant_now && grant_first_n6m;

assign MBUSDIR = ~dma_active;
assign EXH_4_n = ~EXH_4;
assign WRN6M = N6M;
assign KDA = dma_count;

// U653A request FF.  The PCB clocks this part from MDMARQ itself; sampling the
// rising edge in the master domain avoids introducing that generated clock.
always @(posedge clk) begin
  if (rst) begin
    MBUSRQ      <= 1'b1;
    dma_pending <= 1'b0;
    mdmarq_d    <= 1'b1;
  end else begin
    mdmarq_d <= MDMARQ;

    if (dma_active || start_dma) begin
      MBUSRQ      <= 1'b1;
      dma_pending <= 1'b0;
    end else begin
      // D is tied low on the PCB, so the active-low request asserts on the
      // rising/release edge of MDMARQ, not while the write decode is low.
      if (mdmarq_rise) begin
        dma_pending <= 1'b1;
        MBUSRQ      <= 1'b0;
      end else if (dma_pending) begin
        MBUSRQ <= 1'b0;
      end else begin
        MBUSRQ <= 1'b1;
      end
    end
  end
end

// U655B and U656B: two WRN6M-clocked grant stages.  Besides matching the PCB,
// these hold KDA=0 long enough for the synchronous FPGA source RAM to return
// its first word.  Keep their terminal action clock-qualified: a literal
// asynchronous U655B /PRE driven by cascaded FPGA RCO logic can pulse during
// the 0xeff->0xf00 transition and terminate before the last SCR4 quarter.
// The PCB's C861 (2800 pF) on U659 RCO and TTL propagation are not represented
// by the zero-delay LS161 wrappers.
always @(posedge clk) begin
  if (rst) begin
    grant_first_n6m <= 1'b0;
    dma_active      <= 1'b0;
  end else if (dma_active) begin
    if (dma_retire) begin
      grant_first_n6m <= 1'b0;
      dma_active      <= 1'b0;
    end
  end else if (N6M && grant_now) begin
    if (!grant_first_n6m)
      grant_first_n6m <= 1'b1;
    else
      dma_active <= 1'b1;
  end
end

// U657/U658/U659: the three cascaded 74LS161 counters.  A single 12-bit FPGA
// carry chain has the same observable KDA/RCO sequence without exposing the
// physical cascade's propagation skew to an asynchronous fabric control.
always @(posedge clk) begin
  if (rst || !dma_active) begin
    dma_count <= 12'h000;
  end else if (N6M) begin
    if (copy_end)
      dma_count <= 12'h000;
    else
      dma_count <= dma_count + 12'd1;
  end
end

// PCB U7L: active-low destination-quarter decode.
LS139 LS139_7L_u(
    .E1(q_6k1), //counter start 
    .A1(KDA[11]),
    .B1(KDA[12]),
    .Y1({DMSL_S4, DMSL_S2, DMSL_S1, DMSL_GL}),

    .E2(),
    .A2(),
    .B2(),
    .Y2()
);

// PCB U8L/U9L are tri-state bus drivers.  main.v performs the FPGA address
// mux explicitly, and DMARD has no consumer, so use its high idle level.
assign DMARD = MBUSDIR == 1'b0 ? 1'b0 : 1'b1;

endmodule
