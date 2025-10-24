// scroll controller 
module sei0021bu(
   input            clk,

   input            cen,
   input            rst_n,
   input            cs_n,

   input            low, 
   input            high,
   input      [7:0] data,

   input      [8:0] pos, //XXX [8:0]

   output reg       sync,
   output reg [8:0] scrolled 
);

reg [7:0] scroll_low;
reg [8:0] scroll;

always @(posedge clk, negedge rst_n) begin
   if (rst_n == 1'b0) begin 
      scroll_low <= 8'b0;
      scroll <= 9'b0;
      end 
   else if (cen) begin
      if (~cs_n & low) //scroll_cs  
         scroll_low <=  { data[6:0], data[7] }; 
      else if (~cs_n & high)
         scroll <= { data[4],  scroll_low[7:0] };
    
      // update in sel_n && high ?  
      //scrolled[8:0] <= {pos[8:0]} + scroll[8:0];
      scrolled[8:0] <= {1'b0, pos[7:0]} + scroll[8:0]; //fix ? 

      //sync 
      if (pos[1:0] + scroll[1:0] == 2'b11) //11
         sync <= 1;
      else 
         sync <= 0;
   end 
end

endmodule 
