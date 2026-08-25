// FPGA-safe representation of Toki sheet-6 U654A.
//
// The PCB uses this 74LS74 only through its asynchronous /PRE and /CLR pins;
// D and CLK are inactive.  Cyclone V cannot implement both independent
// asynchronous controls in one native flip-flop, so a literal LS74 instance
// becomes an untimed LUT-feedback latch with undefined power-up state.
//
// Keep that unavoidable FPGA accommodation outside the schematic-facing
// MDMA module.  SET_LEVEL is the asserted physical /PRE condition.  RETIRE is
// the FPGA's post-KDA=0xfff terminal event corresponding to physical /CLR.
// Q_FOR_SAMPLE includes the live set condition so U655B can observe a grant
// on the same master-clock edge; it is only valid for same-clock decisions
// and is not a clock-domain synchronizer.
module toki_mdma_u654a_fpga(
    input  wire clk,
    input  wire rst,
    input  wire SET_LEVEL,
    input  wire RETIRE,
    output reg  Q,
    output wire Q_FOR_SAMPLE
);

assign Q_FOR_SAMPLE = Q | SET_LEVEL;

always @(posedge clk) begin
    if (rst || RETIRE)
        Q <= 1'b0;
    else if (SET_LEVEL)
        Q <= 1'b1;
end

endmodule
