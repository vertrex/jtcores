//  74LS138
//  3-to-8 line decoder/demultiplexer with active-low outputs

module LS138 (
    input  wire S0,
    input  wire S1,
    input  wire S2,

    input  wire E1,
    input  wire E2,
    input  wire E3,
    output wire [7:0] Q  // Active-low outputs
);

    wire enable;

    assign enable = E3 & ~E1 & ~E2;

    assign Q[0] = ~(enable & ({S2, S1, S0} == 3'b000));
    assign Q[1] = ~(enable & ({S2, S1, S0} == 3'b001));
    assign Q[2] = ~(enable & ({S2, S1, S0} == 3'b010));
    assign Q[3] = ~(enable & ({S2, S1, S0} == 3'b011));
    assign Q[4] = ~(enable & ({S2, S1, S0} == 3'b100));
    assign Q[5] = ~(enable & ({S2, S1, S0} == 3'b101));
    assign Q[6] = ~(enable & ({S2, S1, S0} == 3'b110));
    assign Q[7] = ~(enable & ({S2, S1, S0} == 3'b111));

endmodule
