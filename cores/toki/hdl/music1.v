////////// seibu sound system  /////////////////////////////
//
// seibu sound system is composed of :
// - Z80 @3.579545 MHz
// - YM3812 OPL2 @3.579545 MHz
// - MSM6295 @1Mhz 
// - YM3014 DAC and analogue output network (approximated digitally)
//
// z80 communicate with the main 68k cpu :
//   - recv  command for the MSM6295
//   - recv  data for the YM3812
//   - send  ack of cmd/data
//
// /-----------\         /-------\
// | z80  rom  |         |68k    |
// | encrypted |         |       |      
// | 8.m3 8192 |         |       |
// |           |         \-------/
// |           |             |
// \-----------/        /---------\     /--------\
//      |               |  latch  |     |ROM 9.m1|
//      |               |         |     |131072  |
//      |               \---------/     \--------/
//      |                    |              |
// /---------\           /------\        /-------\ 
// |         |           |      |------- |MSM6295|--->/-------\
// | sei80bu | z80 rom   | z80  |        \-------/    | sound |
// |         |---------->|      |        /------\     | mixer |--> sound out
// |         |           |      |--------|YM3812|---->|       |
// |         |           \------/        \------/     \-------/
// \---------/               |
//                           |
//                    /----------------\
//                    | 7.m7 65536     |
//                    | z80 bank       |
//                    | encrypted      |
//                    \----------------/
//
module music1(
  input             clk,
  input             rst,
  input             CLK_3_6,
  input             CS3812,
  
  input             SA_0,   // Sound Address
  input       [7:0] SD_OUT, // Sound data 
  output      [7:0] SD_IN,

  output            IRQ3812, //active low

  input             PRCLK1,
  input             SRDB,
  input             SWRB, 
  input             SEL6295,

  /////// fpga specific 
  output     [15:0] snd,
  input       [1:0] fxlevel,

  // OKI 6295 ADPCM 
  input       [7:0] pcm_rom_data,
  input             pcm_rom_ok, 
  output     [16:0] pcm_rom_addr,
  output            pcm_rom_cs
);


////////// YM3812 //////////////////////
//
// MUSIC
//
reg                 ym3812_addr;
wire                opl_sample;
wire signed [15:0]  opl_snd;
wire         [7:0]  ym3812_dout;

jtopl2   u_YM3812(
    .rst(rst),
    .clk(clk),
    .cen(CLK_3_6),
    .din(SD_OUT[7:0]),
    .addr(SA_0),
    .cs_n(CS3812),
    .wr_n(SWRB),
    .dout(ym3812_dout),
    .irq_n(IRQ3812),
    .snd(opl_snd[15:0]),
    .sample(opl_sample)
);

///////// OKIM6295   /////////////////////// 
//
// MSM6295GS 
// ADPCM sound effects 
//
wire                oki_sample;
wire signed [13:0]  oki_snd;
wire        [17:0]  adpcm_rom_addr;
wire         [7:0]  oki_dout;

// INTERPOL 0 because original hardware filter MSM6295 via the HB-41
jt6295 #(.INTERPOL(0))  u_adpcm(
    .rst(rst),
    .clk(clk),
    .cen(PRCLK1), // @1 MHz MSM6295 
    .ss(1'b1),    // pin 7 high
     //CPU interface
    .wrn(SWRB | SEL6295),  // wr selected
    .din(SD_OUT[7:0]),     // input data from z80 
    .dout(oki_dout),       // output data to z80
     //ROM interface
    .rom_addr(adpcm_rom_addr), // output 18 memory address to read
    .rom_data(pcm_rom_data),   // input  data read
    .rom_ok(pcm_rom_ok),       // high when rom_data is valid and matches rom_addr
     //Sound output
    .sound(oki_snd[13:0]), // sound output 
    .sample(oki_sample)    // sample rate  
);

assign SD_IN = ~CS3812 & ~SRDB   ? ym3812_dout :
               ~SEL6295 & ~SRDB  ? oki_dout :
               8'hff;

assign pcm_rom_cs = 1'b1;

// pcm rom byte 13 and 15 are swapped, that could be a simple encryption 
// that doesn't appear on schematics (XXX check again ??)
assign pcm_rom_addr = {
    adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14],
    adpcm_rom_addr[15], adpcm_rom_addr[12:0]
};

///////// HB-41 FILTER / MIXER /////////////////
//
hb41 u_hb41(
    .rst     ( rst      ),
    .clk     ( clk      ),
    .fm      ( opl_snd  ),
    .fx      ( oki_snd  ),
    .fxlevel ( fxlevel  ),
    .snd     ( snd      )
);

endmodule
