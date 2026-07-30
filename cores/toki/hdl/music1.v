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
// |         |  |      |--------|YM3812|---->|       |
// |         |           \------/        \------/     \-------/
// \---------/               |
//                           |
//                    /----------------\
//                    | 7.m7 65536     |
//                    | z80 bank       |
//                    | encrypted      |
//                    \----------------/
//
// PCB provenance: sheet 11 (MUSIC1). jtopl2 and jt6295 are reusable digital
// replacements for the YM3812 and MSM6295. hb41 models the component-derived
// HB-41/Toki line-level filter and mixer separately from those sound chips.
// pcm_rom_ok is FPGA-only SDRAM validity handshaking; pcm_rom_addr retains
// the board sample-ROM address semantics.
//
module music1(
  input             clk,
  input             rst,
  input             CLK_3_6,
  input             CS3812,
  
  input             SA_0, // Sound Address
  input       [7:0] SD_OUT, // Sound data 
  output      [7:0] SD_IN,

  //input             RESET_A, //active low
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

//type 1 ou 2?
jtopl2   u_YM3812(
    .rst(rst),
    .clk(clk),
    .cen(CLK_3_6),
    .din(SD_OUT[7:0]),
    .addr(SA_0),
    .cs_n(CS3812),
    .wr_n(SWRB), //SWRB //NO RD ?  
    .dout(ym3812_dout), // separate so keep it or put on shared SD bus ?  
    .irq_n(IRQ3812), //IRQ3812
    .snd(opl_snd[15:0]), //? 
    .sample(opl_sample) //? 
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

// The PCB feeds the raw MSM6295 DAC into the HB-41 reconstruction filter.
// Enabling jt6295's interpolation FIR here would filter the signal twice.
jt6295 #(.INTERPOL(0))  u_adpcm(
    .rst(rst),
    .clk(clk),
    .cen(PRCLK1), // 1 MHz enable matching the MSM6295 PRCLK1 input
    .ss(1'b1), // pin 7 high: clock/132, about 7.58 kHz at 1 MHz
     //CPU interface
    .wrn(SWRB | SEL6295),   // wr selected // XX there is norCS 
    .din(SD_OUT[7:0]),  // input data from z80 
    .dout(oki_dout), // output data to z80 // put on shared SD 
     //ROM interface
    .rom_addr(adpcm_rom_addr), // output 18 memory address to read
    .rom_data(pcm_rom_data),   // input  data read
    .rom_ok(pcm_rom_ok),       // high when rom_data is valid and matches rom_addr //SRDB ?
     //Sound output
    .sound(oki_snd[13:0]), // sound output 
    .sample(oki_sample)    // sample rate  
);

assign SD_IN = ~CS3812 & ~SRDB   ? ym3812_dout :
               ~SEL6295 & ~SRDB  ? oki_dout :
               8'hff;

assign pcm_rom_cs = 1'b1;
// PCB continuity and MAME init_toki confirm MSM6295 A13/A15 are exchanged at
// sample ROM 9.m1, although sheet 11 draws them one-to-one. This is not an
// MSM6295 algorithm or an SDRAM cache transformation.
assign pcm_rom_addr = {
    adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14],
    adpcm_rom_addr[15], adpcm_rom_addr[12:0]
};

///////// HB-41 FILTER / MIXER /////////////////
//
// fxlevel remains an FPGA-side user trim. hb41.v documents which analogue
// components are represented and which sub-audible/output stages are omitted.
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
