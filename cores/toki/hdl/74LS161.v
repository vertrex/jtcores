module LS161 (
    input               clk,
    input               rst,
    input               CEN,
    input               CLR_n,
    input               LOAD_n,
    input               ENP,
    input               ENT,
    input         [3:0] D,
    output  reg   [3:0] Q,
    output              RCO
);

always @(posedge clk or posedge rst or negedge CLR_n) begin
    if (rst)
        Q <= 4'b0000;
    else if (!CLR_n)
        Q <= 4'b0000;
    else if (CEN) begin
        if (!LOAD_n) begin
            Q <= D;
            end
        else if (ENP && ENT) begin
            Q <= Q + 4'b1;
            end
    end
end

assign RCO = (Q == 4'b1111) && ENT;

endmodule

