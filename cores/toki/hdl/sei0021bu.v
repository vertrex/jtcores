// scroll controller 
module sei0021bu(
   input      clk,

   //take input from cpu_dout directly here 
   //and store the value directly
   //rather than getting them as input
input           rst, 
   input        sel, 

   input     [1:0] MAB,
   input     [7:0] MDB,

   input      [7:0] pos,
   //input      [8:0] scroll,

   output reg sync,
   output reg [8:0] scrolled 
);

reg [8:0] scroll = 9'b0;

always @(posedge clk) begin 
   if (rst)
      scroll <= 9'b0;

   //if (sel) begin  //scroll_cs ? 
      //if (MAB == 2'd1)
         //scroll <= { 1'b0, MDB[6:0], MDB[7] }; //use a temp 
      //else if (MAB == 2'd0) begin 
         //scroll <= { MDB[4],  scroll[7:0] } + {1'b0, pos[7:0]}; 
         //end
   //end 

   
   scrolled[8:0] <= {1'b0, pos[7:0]}  + scroll[8:0];
   if (pos[1:0] + scroll[1:0] == 2'b11)
      sync <= 1;
   else 
      sync <= 0;
end

endmodule 
