module LS161 (
    input             CLK,      // Clock input
    input             CLR_n,    // Asynchronous clear (active low)
    input             LOAD_n,   // Synchronous load (active low)
    input             ENP,      // Count enable P
    input             ENT,      // Count enable T
    input         [3:0] D,        // Parallel data input
    output  reg   [3:0] Q,        // Counter output
    output            RCO       // Ripple Carry Output
);

    // Asynchronous clear
    //always @(posedge CLK or negedge CLR_n) begin
    always @(posedge CLK) begin
        if (!CLR_n)
            Q <= 4'b0000;
        //else if (!LOAD_n && ENP)
        else if (!LOAD_n) 
            Q <= D;
        else if (ENT && ENP)
        //else if (ENT) 
            Q <= Q + 1;
                        //end else if (ENT) begin
    end

    // Ripple Carry Output: high when Q == 4'b1111 and ENT == 1 and ENP == 1
    assign RCO = (Q == 4'b1111); // && ENT && ENP;
    //assign RCO = (Q == 4'b1111) && ENT; // RCO is high when Q is 15 and counting is enabled
endmodule

