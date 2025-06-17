// Must check on pcb -> must do what is done in main.v 
// is that just a adder ? 
module sei0021bu(
   input      clk,
   input      [7:0] pos,
   input      [8:0] scroll,

   output reg sync,
   output reg [8:0] scrolled 
);

//XXX check on board
//if the adder take one cycle 
//it take as input a pos + scroll 
//and how many clk tick it take to output the updated stuff 
//or the clock if used only to update scroll or something else ? 
//because those will induce delay 1clk delay on eerything related to bk rom 
//sei0021bu certainly as in input the CPU address but so maybe only that is
//cloked bu this is constnat ? 
//always @(posedge clk)
   //assign scrolled[8:0] = pos[7:0] + scroll[8:0];

always @(posedge clk) begin 
   scrolled[8:0] <= {1'b0, pos[7:0]} + scroll[8:0];
   //or every 4 clock ???? 
   //we need to measure that or find a way to make that like on the board 
   //it's only one wire but it will change or reset serialization
   //if scroll %4 and need to reset realign sei10bu serialization ?
   if (pos[1:0] + scroll[1:0] == 2'b11)
      sync <= 1;
   else 
      sync <= 0;
   //if (scrolled[8:0] != ({1'b0, pos[7:0]} + scroll[8:0]) )
      //sync <= 1;
   //else 
      //sync <= 0;
end
endmodule 
