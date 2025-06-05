// priority / color mixer 
module sg0140(
  input clk, 

  input [3:0] char_color,
  input [3:0] char_code, 

  input [3:0] bk1_color,
  input [3:0] bk1_code, 

  output reg [1:0]     pri, 

  output reg [7:0] palette_addr
); 

//it seem sg0140 get other input like clk from other module like bk 1 output
//scroll pos0 etc 
//it certainly do other stuff like partial mixing
always @(posedge clk) begin 
  //met pri a 1 si un des deux et differ de hf ?
  pri <= {  
           char_color[3:0] == 'hf ? 1'b0: 1'b1,
           bk1_color[3:0] == 'hf ? 1'b0 : 1'b1
         };

  //  00   bk1 0 char 0 (e)
  //  01   bk1 1 char 0 (8)   
  //  10   bk1 0 char 1 (4)
  //  11   bk1 1 char 1 (4) //char > bk1 so ok

  //pri <= { bk1_color[3:0] != 'hf ? 1'b0 : 1'b1, 
           //char_color[3:0] != 'hf ? 1'b0: 1'b1 };
  palette_addr[7:0] <= char_color[3:0] != 'hf ?  {char_code, char_color} :
                                                 {bk1_code,  bk1_color};
end

endmodule
