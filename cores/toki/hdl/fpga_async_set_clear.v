// FPGA-safe retained state with live active-low preset and clear overrides.
//
// This is not a general replacement for a physical asynchronous SR latch or
// 74LS74: PRE_N/CLR_N must be master-clock-domain levels which remain asserted
// through at least one clk edge.  The combinational outputs preserve their
// immediate level effect, while q_state records the result in a native FPGA
// flip-flop.  CLEAR has priority when both controls are active, matching the
// established Toki LS74 behavioral model for that otherwise-illegal condition.
module fpga_async_set_clear #(
    parameter RESET_Q = 1'b0
) (
    input  wire clk,
    input  wire rst,
    input  wire PRE_N,
    input  wire CLR_N,
    output wire Q,
    output wire QN
);

reg q_state;

wire q_live = rst    ? RESET_Q :
              !CLR_N ? 1'b0    :
              !PRE_N ? 1'b1    : q_state;

assign Q  = q_live;
assign QN = ~q_live;

always @(posedge clk) begin
    if (rst)
        q_state <= RESET_Q;
    else if (!CLR_N)
        q_state <= 1'b0;
    else if (!PRE_N)
        q_state <= 1'b1;
end

endmodule
