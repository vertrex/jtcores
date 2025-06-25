module LS161 (
    input  wire       CLK,      // Clock input
    input  wire       CLR_n,    // Asynchronous clear (active low)
    input  wire       LOAD_n,   // Synchronous load (active low)
    input  wire       ENP,      // Count enable P
    input  wire       ENT,      // Count enable T
    input  wire [3:0] D,        // Parallel data input
    output reg  [3:0] Q,        // Counter output
    output wire       RCO       // Ripple Carry Output
);

    // Asynchronous clear
    always @(posedge CLK or negedge CLR_n) begin
        if (!CLR_n)
            Q <= 4'b0000;
        else if (!LOAD_n)
        //else if (!LOAD_n && ENP) 
            Q <= D;
        else if (ENP && ENT)
        //else if (ENT) 
            Q <= Q + 1;
                        //end else if (ENT) begin
    end

    // Ripple Carry Output: high when Q == 4'b1111 and ENT == 1 and ENP == 1
    //assign RCO = (Q == 4'b1111); // && ENT && ENP;
    assign RCO = (Q == 4'b1111) && ENT; // RCO is high when Q is 15 and counting is enabled
endmodule

