////////// sis6091 /////////////////////
//
// 16-bits dual ram that use two 8-bits ram module
// it copy it's content to a seconday ram @posedge  
// of trigger
// there was no reverse of the sis6091 it's only guessing 
// and certainly totally wrong
//
module sis6091 #(parameter W=10) 
(
	input         clk,
  input         trigger_n, // trigger high to copy ram content 

  input  [1:0]  we,      // 1st ram write enable
  input  [W:1]  addr_in, // 1st ram address
  input  [15:0] data,    // 1st ram data 
  output [15:0] q_in,    // 1st ram data out 
  
  input  [W:1]  addr_out,// 2nd ram addr 
  output [15:0] q        // 2nd ram data out
);

// low-byte of the 16 bits ram
dual_ram_buffer #(.W(W)) u_low 
(
  .clk(clk),
  .trigger_n(trigger_n),
  .we(we[0]),
  .addr_in(addr_in),
  .data(data[7:0]),
  .q_in(q_in[7:0]),
  .addr_out(addr_out),
  .q(q[7:0])
);

// high-byte of the 16 bits ram
dual_ram_buffer #(.W(W)) u_high
(
  .clk(clk),
  .trigger_n(trigger_n),
  .we(we[1]),
  .addr_in(addr_in),
  .data(data[15:8]),
  .q_in(q_in[15:8]),
  .addr_out(addr_out),
  .q(q[15:8])
);

endmodule
