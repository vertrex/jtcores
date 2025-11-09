module LS174(
    input  wire        CLK,    // Rising-edge clock
    input  wire        CLRn,   // Asynchronous clear, active LOW
    input  wire        CEN,    // Clock enable (active HIGH)
    input  wire [5:0]  D,      // Data inputs
    output reg  [5:0]  Q       // Data outputs
);

    always @(posedge CLK or negedge CLRn) begin
        if (!CLRn)
            Q <= 6'b000000;
        else if (CEN)
            Q <= D;
    end

endmodule

