module LS74 (
    input wire CLK,
    input wire CEN,// Clock input
    input wire  D, // Data inputs
    input wire PRE, // Preset inputs (active low)
    input wire  CLR, // Clear inputs (active low)
    output reg  Q, // Flip-flop outputs
    output QN // Inverted flip-flop outputs
);
    // Flip-flop logic for the first flip-flop
    //always @(posedge CLK or negedge PRE or negedge CLR) begin
    always @(posedge CEN or negedge PRE or negedge CLR) begin
        if (!CLR)
            Q <= 1'b0;
        else if (!PRE)
            Q <= 1'b1;
        else 
            Q <= D;
    end

    assign QN = ~Q;

endmodule


module LS74_CEN (
    input wire CLK,
    input wire CEN,// Clock input
    input wire  D, // Data inputs
    input wire PRE, // Preset inputs (active low)
    input wire  CLR, // Clear inputs (active low)
    output reg  Q, // Flip-flop outputs
    output QN // Inverted flip-flop outputs
);
    // Flip-flop logic for the first flip-flop
    //always @(posedge CLK or negedge PRE or negedge CLR) begin
    always @(posedge CLK or negedge PRE or negedge CLR) begin
        if (!CLR)
            Q <= 1'b0;
        else if (!PRE)
            Q <= 1'b1;
        else if (CEN)
        //else 
            Q <= D;
    end

    assign QN = ~Q;

endmodule
