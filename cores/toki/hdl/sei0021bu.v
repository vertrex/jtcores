// scroll controller 
module sei0021bu(
   input      clk,

   //take input from cpu_dout directly here 
   //and store the value directly
   //rather than getting them as input
   input        rst,  // active_low ! 
   input        sel,  // active_low ! 

   input     [1:0] MAB, //XXX split in two if 1 is active .. if other is active 
                        //more logic as it's 10 & 01 ...
   input     [7:0] MDB_OUT,

   input      [7:0] pos,
   input      [8:0] scroll,

   output reg sync,
   output reg [8:0] scrolled 
);


reg [7:0] scroll_lo = 8'b0;
reg [8:0] scroll_new = 9'b0;

always @(posedge clk) begin 
   if (rst == 1'b0) // ? check signal 
      scroll_new <= 9'b0;

   // == main .v ?
   if (sel == 1'b0) begin  //scroll_cs  
      if (MAB == 2'b10) begin 
         scroll_lo <= MDB_OUT[7:0];
         //scroll <= { 1'b0, MDB[6:0], MDB[7] }; //use a temp 
         end
      else if (MAB == 2'b01) begin 
         //scroll <= { MDB[4],  scroll[7:0] };
         scroll_new <= { MDB_OUT[4],  scroll_lo[6:0], scroll_lo[7] };
         //scroled <= MDB[4], scroll   + pos ? 
         end
   end 
  
   //code original 
   scrolled[8:0] <= {1'b0, pos[7:0]}  + scroll_new[8:0];
   if (pos[1:0] + scroll[1:0] == 2'b11)
      sync <= 1;
   else 
      sync <= 0;
end

endmodule 
