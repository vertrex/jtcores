// FPGA-safe representation of Toki sheet-14 U148B.
//
// The PCB 74LS74 half is used only as asynchronous set/clear storage: U144A Q
// drives /PRE, U145B Q drives /CLR, D and its physical clock are grounded.
// Cyclone V has no native register with both independent asynchronous controls,
// so the literal wiring is retained as commented schematic code in objdma.v and
// this facade contains the implementation accommodation.
//
// Both controls are generated in the 48 MHz master-clock domain and remain at
// their active level through a master-clock edge. fpga_async_set_clear therefore
// preserves the live pin effect and then retains it in a native FPGA register.
module toki_objdma_u148_fpga(
    input  wire clk,
    input  wire rst,
    input  wire PRE_N,
    input  wire CLR_N,
    output wire Q,
    output wire QN
);

fpga_async_set_clear #(
    .RESET_Q(1'b0)
) u_state (
    .clk  (clk),
    .rst  (rst),
    .PRE_N(PRE_N),
    .CLR_N(CLR_N),
    .Q    (Q),
    .QN   (QN)
);

endmodule
