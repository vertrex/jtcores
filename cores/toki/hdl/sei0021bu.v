// Must check on pcb -> must do what is done in main.v 
// is that just a adder ? 
module sei0021bu(
   input      [7:0] pos,
   input      [8:0] scroll, 

   output     [8:0] scrolled 
);

assign scrolled[8:0] = pos[7:0] + scroll[8:0];

endmodule 
