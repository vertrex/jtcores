// Must check on pcb -> must do what is done in main.v 
// is that just a adder ? 
module sei0021bu(
   input      clk,

   //take input from cpu_dout directly here 
   //and store the value directly
   //rather than getting them as input

   input      [7:0] pos,
   input      [8:0] scroll,

   output reg sync,
   output reg [8:0] scrolled 
);

always @(posedge clk) begin 
   scrolled[8:0] <= {1'b0, pos[7:0]} + scroll[8:0];
   if (pos[1:0] + scroll[1:0] == 2'b11)
      sync <= 1;
   else 
      sync <= 0;
end

endmodule 
