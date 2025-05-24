//serializer ? 
//take 8 or  16 bits ? 
//and return 4 bits / 1 pixel ?? 
//

module sei0010bu(
  input  clk,
  input  rst,
  input  g, //latch data when enable 

  input  [15:0] rom_data, 
  //output reg [3:0]  color 
  output [3:0]  color 
);

reg [1:0] pos, posg;

wire [3:0] pix_index_3, pix_index_2, pix_index_1, pix_index_0; 

//this take 4 cycle 
assign pix_index_3 = {2'b11, posg[1:0]};
assign pix_index_2 = {2'b10, posg[1:0]};
assign pix_index_1 = {2'b01, posg[1:0]};
assign pix_index_0 = {2'b00, posg[1:0]};

assign color = {rom[pix_index_3], rom[pix_index_2], rom[pix_index_1], rom[pix_index_0]};

reg [15:0] q_reg;
//take 4 cycle to latch each pix so palette is off is not assigned here 
//+2 cycle to get  palettre_adr and final pix value 
//assign pixel = {palette[3:0], {rom_data[pix_index_3], rom_data[pix_index_2], rom_data[pix_index_1], rom_data[pix_index_0]}};

always @(posedge clk, posedge rst) begin
  if (rst) begin
      //color[3:0] <= 'hf;
      //rom[15:0] <= rom_data[15:0];
      rom[15:0] <= 'h0;
      //posg[1:0] <= 2'b0;
    end 
  else begin 
      //one clock cycle more ! 
      //can assign to output directly ?
      //color[3:0] <= {rom[pix_index_3], rom[pix_index_2], rom[pix_index_1], rom[pix_index_0]};
      if (g == 1'b1) begin  //0b11 //XXX must check real value en sei50bu 
        posg[1:0] <= 2'b00;
        rom[15:0] <= rom_data[15:0];
        end 
      else 
        posg[1:0] <= posg + 1;
      //stop serialize if not reset by g after 4 pix ?
  end 
end 

//always @(g)
   //rom[15:0] <= rom_data[15:0];

//always @(posedge clk, posedge LHBL) begin
    //if (~LHBL)
      //pos[1:0] <= 2'b0;
    //else 
      //pos[1:0] <= pos[1:0] + 2'b1;
//end 

//reg [15:0] data;
//reg [3:0]  pal;

//always @(posedge pxl_cen) begin 
  //if (en) begin //every 4 pixel ?  
    //data[15:0] <= rom_data[15:0];
    //pal[3:0] <= palette;
  //end 

  //tmp <= (tmp >> 8);
  //data <= data >> 4;
//end 

//assign pixel = {pal[3:0], data[3:0]};


endmodule
