// scroll controller 
module sei0021bu(
   input            clk,
   input            rst_n,
   input            cs_n,

   input            low, 
   input            high,
   input      [7:0] data,

   input      [7:0] pos,

   output reg       sync,
   output reg [8:0] scrolled 
);

reg [8:0] scroll = 9'b0;

always @(posedge clk) begin 
   if (rst_n == 1'b0) 
      scroll <= 9'b0;

   if (cs_n == 1'b0 && low == 1'b1) //scroll_cs  
      scroll <= { 1'b0, data[6:0], data[7] }; 
   if (cs_n && high == 1'b1) 
      scroll <= { data[4],  scroll[7:0] };
 
   // update in sel_n && high ?  
   scrolled[8:0] <= {1'b0, pos[7:0]}  + scroll[8:0];

   //sync 
   if (pos[1:0] + scroll[1:0] == 2'b11)
      sync <= 1;
   else 
      sync <= 0;
end

endmodule 
