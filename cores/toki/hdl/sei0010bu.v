// Serializer 
module sei0010bu(
  input  clk,
  input  rst,

  input  g, //latch data when enable 

  input  [15:0] rom_data, 
  output reg [3:0]  color 
);

reg [3:0] pixel_0; 
reg [3:0] pixel_1; 
reg [3:0] pixel_2; 
reg [3:0] pixel_3; 

always @(posedge clk) begin
        if (rst) begin
            pixel_0 <= 4'h0;
            pixel_1 <= 4'h0;
            pixel_2 <= 4'h0;
            pixel_3 <= 4'h0;
        end else if (g) begin //load
            pixel_0[3:0] <= rom_data[3:0];
            pixel_1[3:0] <= rom_data[7:4];
            pixel_2[3:0] <= rom_data[11:8];
            pixel_3[3:0] <= rom_data[15:12];
            color <= { pixel_3[0], pixel_2[0], pixel_1[0], pixel_0[0] };
        end else begin
            pixel_0 <= {1'b0, pixel_0[3:1]};
            pixel_1 <= {1'b0, pixel_1[3:1]};
            pixel_2 <= {1'b0, pixel_2[3:1]};
            pixel_3 <= {1'b0, pixel_3[3:1]};
            color <= { pixel_3[0], pixel_2[0], pixel_1[0], pixel_0[0] };
        end
end

endmodule
