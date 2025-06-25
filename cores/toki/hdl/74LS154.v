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

// XXX 
//              WRARDS && MWRLB 
//assign enable = !cpu_wr && !cpu_lds_n && !cpu_uds_n;
//assign enable = scroll_cs; //XXX MUST DECODE PLD but seems scroll CS 
//assign enable = 1'b1;

// CHECK IMPLEMENTATION @cpu ??  decoder don't have clock @always scroll_cs
// ? enable choose 
//always @(cpu_a[6:3]) begin 

/*
always @(posedge clk) begin 
      //if (enable) begin 
      if (scroll_cs == 1'b1) begin 
        case (cpu_a[6:3])
          4'd0 : select[15:0] <= 16'b0000_0000_0000_0001; // RST_S1H 
          4'd1 : select[15:0] <= 16'b0000_0000_0000_0010; // SEL_S1H
          4'd2 : select[15:0] <= 16'b0000_0000_0000_0100; // RST_S1Y
          4'd3 : select[15:0] <= 16'b0000_0000_0000_1000; // SEL_S1Y

          4'd4 : select[15:0] <= 16'b0000_0000_0001_0000; // RST_S2H
          4'd5 : select[15:0] <= 16'b0000_0000_0010_0000; // SEL_S2H
          4'd6 : select[15:0] <= 16'b0000_0000_0100_0000; // RST S2Y 
          4'd7 : select[15:0] <= 16'b0000_0000_1000_0000; // SEL S2Y
          
          4'd8 : select[15:0] <= 16'b0000_0001_0000_0000; // MDMARQ
          4'd9 : select[15:0] <= 16'b0000_0010_0000_0000; // ODMARQ 
          4'ha : select[15:0] <= 16'b0000_0100_0000_0000; // MASKS -> scroll_cs  1010 (== 0x28 -> cpu_a[6:1]) 'bg order' & rev in mame

          //unused 
          4'hb : select[15:0] <= 16'b0000_1000_0000_0000; 

          4'hc : select[15:0] <= 16'b0001_0000_0000_0000;  
          4'hd : select[15:0] <= 16'b0010_0000_0000_0000;
          4'he : select[15:0] <= 16'b0100_0000_0000_0000;
          4'hf : select[15:0] <= 16'b1000_0000_0000_0000;  
        endcase
        end 
      else 
        select[15:0] <= 16'b1111_1111_1111_1111;
end 
*/

endmodule 
