module LS175(
    input  wire       CLK,
    input  wire       CLR_n,
    input  wire       CEN,
    input  wire [3:0] D,
    output reg  [3:0] Q,
    output wire [3:0] Qn
);

    always @(posedge CLK or negedge CLR_n) begin
        if (!CLR_n)
            Q <= 4'b0000;
        else if (CEN)
            Q <= D;
    end

    assign Qn = ~Q;

endmodule

