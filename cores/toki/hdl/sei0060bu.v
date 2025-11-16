module SEI0060BU(
    //FH or OH
   input clk,
   input cen, 

   input [8:0] ADDR,
   input ODD_LD,
   input EVN_LD,
   input HBLB,
   input OBJT2_7,
   input V1B,
   input T8H,
   input HREV,
   // ouput
   output reg [8:0] OA,
   output reg [8:0] EA,

   output reg EVNCLR,
   output reg ODDCLR
);

always @(posedge clk) begin 
    if (cen) begin 
        if (ODD_LD)
            OA[8:0] <= ADDR[8:0];

        if (EVN_LD)
            EA[8:0] <= ADDR[8:0]; 

        if (~HBLB) begin //low or high ?  
            EVNCLR <= 1'b0;
            ODDCLR <= 1'b0; 
            end 
    end 
end 


endmodule 
