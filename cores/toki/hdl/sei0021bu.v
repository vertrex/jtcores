// scroll controller 
module sei0021bu(
   input      clk,

   input        rst,  // active_low ! 
   input        sel,  // active_low ! 

   input     [1:0] MAB, //XXX split in two if 1 is active .. if other is active 
                        //more logic as it's 10 & 01 ...
   input     [7:0] MDB_OUT,

   input      [7:0] pos,

   output reg sync,
   output reg [8:0] scrolled 
);


reg [8:0] scroll = 9'b0;

always @(posedge clk) begin 
   if (rst == 1'b0) // ? check signal 
      scroll <= 9'b0;

   if (sel == 1'b0) begin  //scroll_cs  
      if (MAB == 2'b10) 
         scroll <= { 1'b0, MDB_OUT[6:0], MDB_OUT[7] }; 
      else if (MAB == 2'b01) 
         scroll <= { MDB_OUT[4],  scroll[7:0] };
   end 
 
   // update on ly in 2'b01 ? 
   scrolled[8:0] <= {1'b0, pos[7:0]}  + scroll[8:0];
   if (pos[1:0] + scroll[1:0] == 2'b11)
      sync <= 1;
   else 
      sync <= 0;
end

endmodule 
