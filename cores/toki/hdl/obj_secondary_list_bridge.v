// FPGA-only synchronous-memory bridge around the sheet-15 object lists.
//
// Physical U141 is instantiated in OBJDMA; U151/U152/U153 remain instantiated
// in SCNDDMA. This helper contains only the timing and stale-validity adaptation
// required when those local opaque RAMs use registered/retentive FPGA storage:
// the pre-advance U141 tuple, FDA-1 pointer, two compact-list validity epochs,
// and the one-write U153 phase enable. It does not own SORT48 addressing,
// object priority, visibility or any claimed SIS6091 internal behavior.
// SCNDDMA has no reset pin in the mapped interface, so declaration-time
// initialization deliberately preserves the previous FPGA power-up contract.
module obj_secondary_list_bridge (
    input          clk,
    input   [10:3] FDA,
    input    [3:0] VMT,
    input          ODH,
    input          EVNWR2,
    input    [5:0] DMA2_EA,
    input          D1V_2,
    input    [5:0] DMA2_OA,
    input          ODDWR2,
    input          RAM2VLD,
    input          RDCLK,
    input          SPR2_2,
    input          SPR1_2,
    input          MATCHV,

    output  [15:0] list_data,
    output         slot_valid,
    output reg     u153_wr_edge = 1'b0
);

reg evnwr2_hold_d = 1'b1;
reg oddwr2_hold_d = 1'b1;

wire [7:0] fda_ptr = FDA - 8'd1;
wire [15:0] list_data_live = {
    SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], fda_ptr
};
reg [15:0] list_data_hold = 16'h0000;
reg list_data_valid = 1'b0;

wire evnwr2_hold_fall = evnwr2_hold_d && !EVNWR2;
wire oddwr2_hold_fall = oddwr2_hold_d && !ODDWR2;

// U141's old descriptor remains stable through RDCLK high. Preserve its
// physical flag tuple while taking MATCHV/VMT/FDA from the consume result.
always @(posedge clk) begin
    evnwr2_hold_d <= EVNWR2;
    oddwr2_hold_d <= ODDWR2;

    if (RDCLK) begin
        list_data_hold  <= list_data_live;
        list_data_valid <= 1'b1;
    end else if (evnwr2_hold_fall || oddwr2_hold_fall) begin
        list_data_valid <= 1'b0;
    end
end

wire [15:0] list_data_held = {
    list_data_hold[15:13], MATCHV, VMT[3:0], fda_ptr
};
assign list_data = RDCLK ? list_data_live :
                   list_data_valid ? list_data_held : list_data_live;

wire even_write_active = !EVNWR2;
wire odd_write_active = !ODDWR2;
reg d1v2_d = 1'b0;
reg even_write_d = 1'b0;
reg odd_write_d = 1'b0;
reg [63:0] even_valid = 64'b0;
reg [63:0] odd_valid = 64'b0;
reg even_build_started = 1'b0;
reg odd_build_started = 1'b0;

wire d1v2_rise = !d1v2_d && D1V_2;
wire d1v2_fall = d1v2_d && !D1V_2;
wire even_write_rise = !even_write_d && even_write_active;
wire odd_write_rise = !odd_write_d && odd_write_active;

// Each compact-list bank keeps an FPGA-only validity epoch. Statement order
// intentionally preserves the boundary-write precedence of the inline
// implementation: a write on the D1V transition retains its slot but does
// not arm the following build epoch.
always @(posedge clk) begin
    d1v2_d         <= D1V_2;
    even_write_d   <= even_write_active;
    odd_write_d    <= odd_write_active;

    if (d1v2_rise) begin
        if (!even_build_started)
            even_valid <= 64'b0;
        even_build_started <= 1'b0;
    end

    if (d1v2_fall) begin
        if (!odd_build_started)
            odd_valid <= 64'b0;
        odd_build_started <= 1'b0;
    end

    if (odd_write_rise) begin
        if (odd_build_started)
            odd_valid <= odd_valid | (64'b1 << DMA2_OA);
        else
            odd_valid <= 64'b1 << DMA2_OA;
        odd_build_started <= d1v2_fall ? 1'b0 : 1'b1;
    end

    if (even_write_rise) begin
        if (even_build_started)
            even_valid <= even_valid | (64'b1 << DMA2_EA);
        else
            even_valid <= 64'b1 << DMA2_EA;
        even_build_started <= d1v2_rise ? 1'b0 : 1'b1;
    end
end

assign slot_valid = D1V_2 ? even_valid[DMA2_EA] : odd_valid[DMA2_OA];

// U153 is physically enabled through the active-low RDCLK phase. Convert the
// first combined valid phase into the same delayed single BRAM write formerly
// implemented inline in SCNDDMA.
wire u153_wr_phase = ~RDCLK && ~RAM2VLD;

reg u153_wr_phase_d = 1'b0;
always @(posedge clk) begin
    u153_wr_phase_d <= u153_wr_phase;
    u153_wr_edge    <= u153_wr_phase && !u153_wr_phase_d;
end

endmodule
