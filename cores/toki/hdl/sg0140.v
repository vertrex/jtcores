module sg0140(
  input clk, 

  input [3:0] char_code, 
  input [3:0] char_color,

  output reg [7:0] palette_addr
); 

//it seem sg0140 get other input like clk from other module like bk 1 pos etc 
//it certainly do other stuff like partial mixing
always @(posedge clk) begin 
    palette_addr[7:0] <= {char_code, char_color};
end

endmodule
