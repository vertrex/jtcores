////////// char ram  //////////////////////////////////
//
// State machine that draw a line of 8x8 tile
// each time line number change.
// RAM is fully scanned, address in ram give 
// tile position on screen, there is 32 tiles by line
// RAM data describe a tile :
//  -  [3:0] color
//  - [11:0] index of tile in ROM 
//  
//  Tile data are DWORD stored in ROM as 4 bit planes 
//  second dword of each data is at address + 0x8000
//
//  each pixel of tile are 8 bits : 
//    4 bits color, 4 bits index (rom data)
//  pixel are transparent if ROM data is 0xf
//  pixel value is an index into the video palette 
//
module char_ram(
  input                 clk,
  input                 pxl_cen,
  input                 char_cen,
  input                 char_rom_cen,
  input                 rst,

  input                 LHBL,

  input           [7:0] hpos, //8:0
  input           [7:0] vpos, //8:0

  //output reg     [10:1] ram_addr, //vram_addr 
  input          [15:0] ram_out,  //code [11:0], pal 15:12

  //input          [15:0] char_rom_data,
  //input                 char_rom_ok,
  //output         [16:1] char_rom_addr,
  //output                char_rom_cs,

  input          [7:0]  char_rom_1_data,
  input                 char_rom_1_ok,
  output         [15:0] char_rom_1_addr,
  output                char_rom_1_cs,


  input          [7:0]  char_rom_2_data,
  input                 char_rom_2_ok,
  output         [15:0] char_rom_2_addr,
  output                char_rom_2_cs,

  output          [7:0] pixel
);

// SEI50BU -> RAM (sis6091) -> ROM -> SEI10BU -> SG0140 -> PALETTE RAM -> UEC51 

wire [3:0] color;
reg [3:0] palette;
reg [2:0] vpos_latch;

//latch line number, why ??? we would latch x the hpos but we latch of 4 
//maybe to be on the right line2 when at the start or end of the screen
//if yes it mean that hpos in ram is latched too
always @(posedge char_cen) begin
  vpos_latch[2:0] <= vpos[2:0];
end 

//reg [7:0] hpos_shift_0 = 0;

//shift by 2 ??
//hpos_shift_0 = hpos[7:2] ?
//always @(pxl_cen) begin 
   //if (LHBL == 1'b0) //or hblank simply ?
     //hpos_shift_0[7:0] <= 8'd0;
     //vpos_shift = vpos + 1 ; ? 
   //else
     //hpos_shift_0[7:0] <= hpos[7:0] + 8'd4; //better way to calculate ? add 1 to rom addr ? <<2 ?  
     //hpos_shift_0[7:0] <= hpos[7:0]; //better way to calculate ? add 1 to rom addr ? <<2 ?  
     //vpos_shift <= vpos 
//end 

//

//if tile number is late it mean ram_addr in main.v is late 
//and should be populated before

                             //tile number , line number (8), rom 1 or 2 every 8 pix
//assign char_rom_addr[16:1] = {ram_out[11:0], vpos_latch[2:0], hpos_shift_0[2]}; //latch vpos/hpos ? because ram_out use vpos/hpos so it must way 
//
//after analyzing hpos[2]
//it seem to start 50ns after ~hpos[2] and finish at the same time but not
//every time ! so it may be clocked some where with the cpu clock 

//74LS368 P15 near cpu  hex inverter
//wire rom_a0;
//assign rom_a0 = ~hpos[2];

assign char_rom_1_cs = 1'b1;
assign char_rom_2_cs = 1'b1;
//on mobo it's ~hpos[2] why ? maybe cpu write in memory in 16 bits in reverse
//byte order ?
//tile addr => tile_number + v line number + 16/2  bits ? 
assign char_rom_1_addr[15:0] = LHBL ? {ram_out[11:0], vpos_latch[2:0], hpos[2]} : 16'hff; //latch vpos/hpos ? because ram_out use vpos/hpos so it must way 
assign char_rom_2_addr[15:0] = LHBL ? {ram_out[11:0], vpos_latch[2:0], hpos[2]} : 16'hff; //latch vpos/hpos ? because ram_out use vpos/hpos so it must way 


// latch / serialize pixel
sei0010bu sei0010bu_u(
  .clk(pxl_cen),
  .rst(rst),
  .g(char_rom_cen),
  //.rom_data(char_rom_data[15:0]),
  //.rom_data({char_rom_2_data[7:0], char_rom_1_data[7:0]}),
  .rom_data({char_rom_2_data[7:0], char_rom_1_data[7:0]}),
  .color(color)
);

//XXX still 9:14 shift (6 pix off) with latch
//without latch there is also 6 ??? 
//74LS174
//hpos[2] ?? seem always up on the mobo ... check it 
//ram_out from 6091 what clocking ?
//on board ~hpos[2] (vpos_latch seems equal to vpos ...)
//maybe ram take one more cycle that's why we have ~hpos2
//assign pixel = {ram_out[15:12], color};

//color mixer ? 
//sg0140 ?  seems good sg0140 take color and output from ram 
//and have different clock and enable !
//  
//assign pixel = {palette, color};
//always @(posedge clk)
  //if (char_rom_cen == 1'b1) // ?
    //this not really palette but half a code of the palette 
    //palette <= ram_out[15:12]; //not in original !!! XXX 

//XXX LOOK ON PCB char char must be updated only each char_rom_cen that's normal 
//must look on pcb but it must be somehow latched as we put the other part
//of ram out in char_rom addr to get the data from the rom then in sei10bu
//to serialize and get only pixel, we must mix wiwth the same data of
//ram_out

reg [3:0] char_code;

always @(posedge clk)
  if (char_rom_cen == 1'b1)
    char_code <= ram_out[15:12];


sg0140 sg0140_u(
  .clk(pxl_cen), 
  .char_color(color),
  .char_code(char_code), //char char must be updated only each char_rom_cen that's normal 
  //must look on pcb but it must be somehow latched as we put the other part
  //of ram out in char_rom addr to get the data from the rom then in sei10bu
  //to serialize and get only pixel, we must mix wiwth the same data of
  //ram_out 
  .palette_addr(pixel)
);

endmodule
