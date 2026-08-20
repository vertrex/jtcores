////////// char ram  //////////////////////////////////
//
// Sheet 9 character path: SIS6091 -> paired mask ROMs -> SEI0010.
// The PCB ROM pair is asynchronous. The acknowledged pair collector, stale-OK
// gap and tagged cache live in a separate FPGA-only SDRAM bridge; the VRAM
// address and serializer remain the schematic-facing shell.
//
// Draw a line of 8x8 tiles each time the line number changes.
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
module scrn4(
  input                 clk,
  input                 rst,
  input                 N6M,
  input                 WRN6M,
  input                 T4H,
  input                 T8H, // retained interface; not wired on sheet 9
  input                 T3F, // SEI0050 pin 25, character serializer timing

  input          [10:1] KDA,
  input                 DMSL_S4,
  input          [15:0] MDB,

  input           [7:0] EXH,  // sheet 5 XORed horizontal coordinate
  input           [7:0] EXV,  // sheet-9 bus: raw high, U518-buffered low bits
  input                 HREV, // U94 SEI0010 pin 38

  input          [7:0]  char_rom_1_data,
  input                 char_rom_1_ok,
  output         [15:0] char_rom_1_addr,
  output                char_rom_1_cs,

  input          [7:0]  char_rom_2_data,
  input                 char_rom_2_ok,
  output         [15:0] char_rom_2_addr,
  output                char_rom_2_cs,

  output         [3:0]  char_color, //pic  
  output         [3:0]  char_code   //col


);

///////// VIDEO RAM //////////
wire [15:0] ram_out;

sis6091 u_vram_ram(
  .clk(clk),

  .wr_cen(~WRN6M), //clock is active low on schematics
  .wr_en(~DMSL_S4), //DSML S4  DMA Select ?
  //.data0(ram_do[15:0]), 
  .wr_data(MDB[15:0]), 
  .wr_addr(KDA[10:1]),    // KDA [1,10]

  .rd_cen(T4H),
  .rd_addr({EXV[7:3], EXH[7:3]}),
  .rd_data(ram_out[15:0])
);

// Sheet 9 wires the sheet-5 U518 EXV1/2/4 `/7` outputs to A1..A3 of both
// character ROMs. video.v folds those three T8H-buffered PCB lanes into
// EXV[2:0], while EXV[7:3] remains the raw tile-map row address. T8H itself
// does not enter this sheet; it continues to SG0140 pin 27 on sheet 10.
// Sheet 6 U652A is a permanently enabled inverting 74LS368 driver.  Its
// `EXH<4>/4` output is therefore the complement of sheet-5 EXH<4>, not an
// additional registered phase like the U518 `/7` vertical lanes.
wire EXH4_BUF_N = ~EXH[2];
wire [15:0] char_addr_next = {ram_out[11:0], EXV[2:0], EXH4_BUF_N};

// U92/U93 are independent asynchronous byte ROMs on the PCB.  JTFrame backs
// them with independently acknowledged SDRAM slots, so the FPGA-only bridge
// holds and joins a complete pair, rejects stale latched OKs, and caches
// repeated rows to meet the fixed four-pixel serializer deadline.  Keeping
// that transport mechanism in its own reusable module leaves this file as the
// sheet-9 VRAM/address/serializer shell.
wire [15:0] char_data_hold;

jtframe_rom_pair_cache #(
  .ADDR_W (16),
  .DATA_W (8),
  .INDEX_W(12)
) u_char_rom_bridge (
  .clk       (clk),
  .rst       (rst),
  .cen       (~N6M),
  .addr      (char_addr_next),
  .q         (char_data_hold),

  .rom_0_data(char_rom_1_data),
  .rom_0_ok  (char_rom_1_ok),
  .rom_0_addr(char_rom_1_addr),
  .rom_0_cs  (char_rom_1_cs),

  .rom_1_data(char_rom_2_data),
  .rom_1_ok  (char_rom_2_ok),
  .rom_1_addr(char_rom_2_addr),
  .rom_1_cs  (char_rom_2_cs)
);

wire [1:0] NC;

sei0010bu sei0010bu_u(
  .clk(clk), 
  .rst(rst),
  .cen(N6M),
  .load(T3F), //load new pixel
  .rev(HREV),
  .rom_data({8'b0, char_data_hold}),
  .color({NC[1:0], char_color})
);
    
//seem like that on the sch
assign char_code = ram_out[15:12];

endmodule
