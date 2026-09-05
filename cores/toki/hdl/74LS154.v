module LS154(
    input [3:0]      A,   // 4-bit input
    input           G1,   // Enable 1 (active-low)
    input           G2,   // Enable 2 (active-low)
    output [15:0]    Y    // 16 active-low outputs
);

wire enable;

assign enable = ~(G1 | G2);  // Device is enabled when both G1 and G2 are low

assign   Y[0] = (enable && (A == 4'h0)) ? 1'b0 : 1'b1;
assign   Y[1] = (enable && (A == 4'h1)) ? 1'b0 : 1'b1;
assign   Y[2] = (enable && (A == 4'h2)) ? 1'b0 : 1'b1;
assign   Y[3] = (enable && (A == 4'h3)) ? 1'b0 : 1'b1;
assign   Y[4] = (enable && (A == 4'h4)) ? 1'b0 : 1'b1;
assign   Y[5] = (enable && (A == 4'h5)) ? 1'b0 : 1'b1;
assign   Y[6] = (enable && (A == 4'h6)) ? 1'b0 : 1'b1;
assign   Y[7] = (enable && (A == 4'h7)) ? 1'b0 : 1'b1;
assign   Y[8] = (enable && (A == 4'h8)) ? 1'b0 : 1'b1;
assign   Y[9] = (enable && (A == 4'h9)) ? 1'b0 : 1'b1;
assign Y['ha] = (enable && (A == 4'ha)) ? 1'b0 : 1'b1;
assign Y['hb] = (enable && (A == 4'hb)) ? 1'b0 : 1'b1;
assign Y['hc] = (enable && (A == 4'hc)) ? 1'b0 : 1'b1;
assign Y['hd] = (enable && (A == 4'hd)) ? 1'b0 : 1'b1;
assign Y['he] = (enable && (A == 4'he)) ? 1'b0 : 1'b1;
assign Y['hf] = (enable && (A == 4'hf)) ? 1'b0 : 1'b1;

endmodule 
