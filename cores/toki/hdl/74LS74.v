module LS74 (
    input wire CLK, // Clock input
    input wire  D, // Data inputs
    input wire PRE, // Preset inputs (active low)
    input wire  CLR, // Clear inputs (active low)
    output reg  Q, // Flip-flop outputs
    output QN // Inverted flip-flop outputs
);

    // Flip-flop logic for the first flip-flop
    always @(posedge CLK or negedge PRE or negedge CLR) begin
        if (!PRE)
            Q <= 1'b1;
        else if (!CLR)
            Q <= 1'b0;
        else
            Q <= D;
    end

    // Inverted output for the first flip-flop
    assign QN = ~Q;

    // Flip-flop logic for the second flip-flop
    //always @(posedge CLK or negedge PRE[1] or negedge CLR[1]) begin
        //if (!PRE[1])
            //Q[1] <= 1'b1;
        //else if (!CLR[1])
            //Q[1] <= 1'b0;
        //else
            //Q[1] <= D[1];
    //end

     //Inverted output for the second flip-flop
    //assign QN[1] = ~Q[1];

endmodule
