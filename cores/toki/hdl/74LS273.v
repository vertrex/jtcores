module LS273(
    input  wire        CLK,    // Rising-edge clock
    input  wire        CLRn,   // Asynchronous clear, active LOW
    input  wire        CEN,    // Clock Enable (active HIGH)
    input  wire [7:0]  D,      // Data inputs
    output reg  [7:0]  Q       // Data outputs
);

    // Behavior identical to 74LS273, but only latches data when CEN = 1
    always @(posedge CLK or negedge CLRn) begin
        if (!CLRn)
            Q <= 8'b00000000;  // Asynchronous clear
        else if (CEN)
            Q <= D;            // Latch inputs only when enabled
    end
endmodule
