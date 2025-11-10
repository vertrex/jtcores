//24bit - shift reg
module sei0010bu(
  //p2 always set to 1 
  input  clk,
  input  rst,
  input  cen,  //p3 

  input  load, //p40
  input  rev,  //p38

  //p34 , p35 only used on 2 sei10bu on objps, is an enable ? it's 1'b0 on all
  //others
  input  [23:0] rom_data, //p5-20  seems to be 24 bit on doc XXX

  output reg [5:0]  color //p22-25 
);

reg [3:0] pixel_0; 
reg [3:0] pixel_1; 
reg [3:0] pixel_2; 
reg [3:0] pixel_3; 
reg [3:0] pixel_4; 
reg [3:0] pixel_5; 

always @(posedge clk, posedge rst) begin
    if (rst) begin
        pixel_0 <= 4'h0;
        pixel_1 <= 4'h0;
        pixel_2 <= 4'h0;
        pixel_3 <= 4'h0;
        pixel_4 <= 4'h0;
        pixel_5 <= 4'h0;
        end 
    else if (cen) begin
      if (load == 1'b1) begin 
          pixel_0[3:0] <= rom_data[3:0];
          pixel_1[3:0] <= rom_data[7:4];
          pixel_2[3:0] <= rom_data[11:8];
          pixel_3[3:0] <= rom_data[15:12];
          pixel_4[3:0] <= rom_data[19:16];
          pixel_5[3:0] <= rom_data[23:20];
          end 
      else if (rev == 1'b1) begin
          pixel_0 <= {pixel_0[3:1], 1'b0};
          pixel_1 <= {pixel_1[3:1], 1'b0};
          pixel_2 <= {pixel_2[3:1], 1'b0};
          pixel_3 <= {pixel_3[3:1], 1'b0};
          pixel_4 <= {pixel_4[3:1], 1'b0};
          pixel_5 <= {pixel_5[3:1], 1'b0};
          end 
      else begin
          pixel_0 <= {1'b0, pixel_0[3:1]};
          pixel_1 <= {1'b0, pixel_1[3:1]};
          pixel_2 <= {1'b0, pixel_2[3:1]};
          pixel_3 <= {1'b0, pixel_3[3:1]};
          pixel_4 <= {1'b0, pixel_4[3:1]};
          pixel_5 <= {1'b0, pixel_5[3:1]};
          end 
      color <= { pixel_5[0], pixel_4[0],  pixel_3[0], pixel_2[0], pixel_1[0], pixel_0[0] };
      end
end

endmodule
