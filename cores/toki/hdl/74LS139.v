//  74LS139
//  dual 2-to-4 line decoder/demultiplexer with active-low outputs
//
module LS139(
    // First decoder inputs
    input        E1,
    input        A1,
    input        B1,
    output [3:0] Y1,

    // Second decoder inputs
    input        E2,
    input        A2,
    input        B2,
    output [3:0] Y2
);

    // Decoder 1 logic
    assign Y1[0] = (~E1 & ({B1, A1} == 2'b00)) ? 1'b0 : 1'b1;
    assign Y1[1] = (~E1 & ({B1, A1} == 2'b01)) ? 1'b0 : 1'b1;
    assign Y1[2] = (~E1 & ({B1, A1} == 2'b10)) ? 1'b0 : 1'b1;
    assign Y1[3] = (~E1 & ({B1, A1} == 2'b11)) ? 1'b0 : 1'b1;

    // Decoder 2 logic
    assign Y2[0] = (~E2 & ({B2, A2} == 2'b00)) ? 1'b0 : 1'b1;
    assign Y2[1] = (~E2 & ({B2, A2} == 2'b01)) ? 1'b0 : 1'b1;
    assign Y2[2] = (~E2 & ({B2, A2} == 2'b10)) ? 1'b0 : 1'b1;
    assign Y2[3] = (~E2 & ({B2, A2} == 2'b11)) ? 1'b0 : 1'b1;

endmodule
