// FPGA-only synchronous-memory bridge around the sheet-15 object lists.
//
// Physical U141 and U153 remain instantiated in OBJDMA/SCNDDMA; U151/U152 keep
// their sheet addresses around explicit FPGA storage in SCNDDMA. This helper
// contains only the timing adaptation required when those local opaque RAMs
// use registered FPGA storage: the pre-advance U141 tuple, FDA-1 pointer,
// one-cycle list write requests and the one-write U153 phase enable. List
// presence is the physical MATCHV bit stored in U151/U152; no FPGA validity
// epoch remains here. It does not own SORT48 address equations, object
// priority, visibility or any claimed SIS6091 internal behavior.
// SCNDDMA has no reset pin in the mapped interface, so declaration-time
// initialization deliberately preserves the previous FPGA power-up contract.
module obj_secondary_list_bridge (
    input          clk,
    input   [10:3] FDA,
    input    [3:0] VMT,
    input          ODH,
    input          EVNWR2,
    input    [5:0] DMA2_EA,
    input    [5:0] DMA2_OA,
    input          ODDWR2,
    input          RAM2VLD,
    input          RDCLK,
    input          SPR2_2,
    input          SPR1_2,
    input          MATCHV,

    output  [15:0] list_data,
    output         even_write_req,
    output         odd_write_req,
    output reg     u153_wr_edge = 1'b0
);

reg evnwr2_hold_d = 1'b1;
reg oddwr2_hold_d = 1'b1;

wire [7:0] fda_ptr = FDA - 8'd1;
wire [15:0] list_data_live = {
    SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], fda_ptr
};
// Only the three U141 descriptor flags must survive RDCLK. MATCHV, VMT and
// FDA belong to the current VCHECK result and deliberately remain live below.
// Keeping the full 16-bit list word here obscured that old-Q boundary;
// Quartus already pruned its unused thirteen bits, so this is a
// source-fidelity cleanup.
reg [2:0] descriptor_flags_hold = 3'b000;
reg list_data_valid = 1'b0;

wire evnwr2_hold_fall = evnwr2_hold_d && !EVNWR2;
wire oddwr2_hold_fall = oddwr2_hold_d && !ODDWR2;

// U141's old descriptor remains stable through RDCLK high. Preserve its
// physical flag tuple while taking MATCHV/VMT/FDA from the consume result.
always @(posedge clk) begin
    evnwr2_hold_d <= EVNWR2;
    oddwr2_hold_d <= ODDWR2;

    if (RDCLK) begin
        descriptor_flags_hold <= list_data_live[15:13];
        list_data_valid       <= 1'b1;
    end else if (evnwr2_hold_fall || oddwr2_hold_fall) begin
        list_data_valid <= 1'b0;
    end
end

wire [15:0] list_data_held = {
    descriptor_flags_hold, MATCHV, VMT[3:0], fda_ptr
};
assign list_data = RDCLK ? list_data_live :
                   list_data_valid ? list_data_held : list_data_live;

wire even_addr_legal = (DMA2_EA >= 6'd16);
wire odd_addr_legal = (DMA2_OA >= 6'd16);

// Normalize each active-low package WR2 assertion into exactly one FPGA RAM
// write. The physical SORT48 window is 16..63; rows 0..15 are never written,
// including during the raw-counter gap.
// The falling-edge detectors above already retain the previous active-low
// WR2 levels for the tuple hold. Reuse those exact events for the RAM writes;
// a second pair of complementary history registers has identical state.
assign even_write_req = evnwr2_hold_fall && even_addr_legal;
assign odd_write_req  = oddwr2_hold_fall && odd_addr_legal;

// U153 is physically enabled through the active-low RDCLK phase. Convert the
// first combined active phase into the same delayed single BRAM write formerly
// implemented inline in SCNDDMA.
wire u153_wr_phase = ~RDCLK && ~RAM2VLD;

reg u153_wr_phase_d = 1'b0;
always @(posedge clk) begin
    u153_wr_phase_d <= u153_wr_phase;
    u153_wr_edge    <= u153_wr_phase && !u153_wr_phase_d;
end

endmodule
