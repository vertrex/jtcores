//serializer ? 
//take 8 or  16 bits ? 
//and return 4 bits / 1 pixel ?? 
//

module sei0010bu(
  input  clk,
  input  rst,
  input  g, //latch data when enable 

  input  [15:0] rom_data, 
  output [3:0]  color 
);

reg [3:0] pixel_0; 
reg [3:0] pixel_1; 
reg [3:0] pixel_2; 
reg [3:0] pixel_3; 

always @(posedge clk, posedge rst) begin 
   if (rst) begin 
      pixel_0 <= 4'h0;
      pixel_1 <= 4'h0;
      pixel_2 <= 4'h0;
      pixel_3 <= 4'h0;
   end else if (g) begin
      pixel_0[3:0] <= rom_data[3:0];
      pixel_1[3:0] <= rom_data[7:4];
      pixel_2[3:0] <= rom_data[11:8];
      pixel_3[3:0] <= rom_data[15:12];
   end else begin
      pixel_0 <= {1'b0, pixel_0[3:1]};
      pixel_1 <= {1'b0, pixel_1[3:1]};
      pixel_2 <= {1'b0, pixel_2[3:1]};
      pixel_3 <= {1'b0, pixel_3[3:1]};
   end 
end 

assign color = { pixel_3[0], pixel_2[0], pixel_1[0], pixel_0[0] };


endmodule
