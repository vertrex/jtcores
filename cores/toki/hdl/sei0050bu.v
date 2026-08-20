// Sheet 5 opaque SEI0050BU timing generator.
//
// This is a trace-calibrated behavioral model, not a recovered internal
// netlist. HBL/L3/T3F/T4H/T8H/HD/VSYNC/VCLK reproduce the custom-IC pins.
// hpos/vpos rotate the physical counter ranges into 0..383 and 0..261 for
// JTFrame, and HS/VS are framework-only components derived from pin 28.
// Board logic outside the IC (notably sheet-5 U518) belongs in video.v.
module SEI0050BU(
  input clk, // 48 MHz FPGA master clock
  input P6M,
  input N6M, // pin 9 clock represented as a clock enable

  input rst, // pin 8
  input VBL_ROM, // pin 33, PROM26 D7

  // Video out
  // H/V are the literal sheet-5 counter-pin buses: H[0]/V[0] are the
  // schematic H1/V1 signals and H[8]/V[8] are H256/V256.  The physical
  // counters contain 384 x 262 states and run through 0x080..0x1ff and
  // 0x0fa..0x1ff respectively.
  output reg [8:0] H,
  output reg [8:0] V,

  // hpos/vpos rotate those physical ranges into the contiguous JTFrame
  // coordinates 0..383 and 0..261.  They remain available for framework
  // video output and FPGA memory scheduling; PCB-facing logic should
  // eventually consume H/V or the explicitly decoded pins above.
  output     [8:0] hpos,
  output     [8:0] vpos,

  output     N1H,
  output     T8H,  // pin 22
  output reg HBL,  // pin 23, active-high 256-pixel window
  output     L3,   // pin 24, delayed horizontal window and vertical gate
  output reg T3F,  // pin 25
  output     T4H,  // pin 26
  output     HD,   // pin 27, active-low one-pixel horizontal drive
  output     VSYNC,// pin 28, active-high composite sync
  output     VCLK, // pins 29/30, one pulse per line

  // JTFrame-only outputs; these are not additional SEI0050 pins.
  output reg HS,
  output reg VS
);

assign VSYNC = HS | VS;

localparam [8:0] RAW_H_FIRST     = 9'h080;
localparam [8:0] RAW_H_LAST      = 9'h1ff;
localparam [8:0] RAW_H_NORM_ZERO = 9'h102;
localparam [8:0] RAW_V_FIRST     = 9'h0fa;
localparam [8:0] RAW_V_LAST      = 9'h1ff;
localparam [8:0] RAW_V_NORM_ZERO = 9'h100;

// JTFrame coordinate adapter.
//
// The independently captured H bus establishes the 0x080..0x1ff range.  The
// adopted Toki integration phase places raw H=0x1ff at normalized hpos=253
// and the following raw H=0x080/VCLK count at hpos=254.  The physical V bus
// advances at that raw-H wrap, whereas normalized vpos does not advance until
// hpos wraps from 383 to 0.  Consequently V describes the next line over the
// final 130 normalized counts of each line.
//
// Physical V=0x100 is normalized line zero.  The six counts before it,
// 0x0fa..0x0ff, are normalized lines 256..261 and coincide with pin 28's
// six-line vertical-sync interval.  This phase is also fixed directly by
// PROM26 pin 33: its raw-V edges at 0x110/0x1f0 are normalized lines 16/240.
//
// H/V are the only free-running raster state.  During raw H=0x080..0x101,
// raw V has already advanced but the normalized framework line has not; the
// inverse adapter therefore subtracts one vertical count in that interval.
wire [8:0] raw_v_normalized = V >= RAW_V_NORM_ZERO
                            ? V - RAW_V_NORM_ZERO
                            : V + 9'd6;

assign hpos = H >= RAW_H_NORM_ZERO
            ? H - RAW_H_NORM_ZERO
            : H + 9'd126;
assign vpos = H >= RAW_H_NORM_ZERO
            ? raw_v_normalized
            : (raw_v_normalized == 9'd0 ? 9'd261
                                         : raw_v_normalized - 9'd1);

// Historical external monitor notes; these are observations, not the RTL
// timing contract below.
// Retro tink :
// input lines 261p 
// H-freg 15.56 khz  
// V-freq 59.61 hz 
// Samples/lines 1754
// ADC Clock : 27.29Mhz 
// buffer lag : 2.0ms (31)
// The displayed H figure is consistent with the same 261-line classifier:
// 59.61 Hz * 261 = 15.55821 kHz. Direct PCB sync captures show 262 periods.

// MAME source comments:
// VSync - 59.6094Hz (agrees with the long PCB vertical capture)
// HSync - 15.31996kHz (stale/inconsistent; it implies only ~257 lines)

// CALC ON SEI0050BU
// Long PCB captures average 59.609220 Hz vertically and 15.6175..15.6177 kHz
// horizontally. With the recovered 384x262 totals this is a ~5.99716 MHz
// pixel cadence; the exact-48-MHz FPGA runs nominally at 59.637405 Hz.
// vertical-sync pulse width: 6 horizontal periods
// vblank : 37 cycle de hsync ! 
// vblank generated via PROM, 82S135 @ 59.61 hz 
// PROM generate different 59.61hz 

// Pin 23 is captured by sheet-5 U518 on T8H. U511D combines that
// registered HBLB with pin 24 to produce the final video MASK.

// Historical phase experiments retained for review; they do not describe the
// trace-backed contract implemented below.
//parameter HBLANK_START  = 265; //high [265, 137]     | 265  
//parameter HBLANK_START  = 266; //high [265, 137]     | 265   //WORK FOR CHAR BUT NOT BK ...
//parameter HBLANK_END 	  = 9; //10 tick so stop at 9  | 9  we shift 3 to align but there's maybe a latch somewhere
//parameter HBLANK_END 	  = 10; //10 tick so stop at 9  | 9  we shift 3 to align but there's maybe a latch somewhere
// JTFrame HS/VS components are decoded from the canonical physical counters.
// These raw constants are exactly the former normalized hpos 304/336 and the
// six-line vpos 256..261 interval; using them avoids feeding the coordinate
// adapter back into SEI0050's internal timing state.
localparam [8:0] RAW_HSYNC_START = 9'h0b2;
localparam [8:0] RAW_HSYNC_END   = 9'h0d2;

parameter H_TOTAL			  = 384; //384 ??
//512-268
//244

//40-128
//12

// Vertical blank is decoded by PROM26 and returned to SEI0050 on pin 33;
// it is not decoded from V internally by this behavioral model.
//244 + 12 lines = 256 lines 
//parameter LVBLANK_START  = 240; //rom blank  | 239   
//parameter LVBLANK_END		= 16; //15 ??? if 224 , only 223 line ? | 16
// Pin 28's vertical component rises at v=256 and falls at v=0 at the same
// horizontal phase. The interval crosses the 261->0 seam and is exactly six
// complete line periods, as measured on the PCB.
localparam [8:0] RAW_VSYNC_START = 9'h0fb;
localparam [8:0] RAW_VSYNC_END   = 9'h101;
parameter V_TOTAL			  = 262;

// Additional commented snippets below are retained only as analysis history;
// none describes the active trace-backed implementation.
//assign LHBL = HBL;
// it look like what we got before so can be ok 
// the are not really @hpos1 it's betwee nedge ....
// half 11 half 00 @negedge ? 

//parameter HBLANK_START  = 265; 
//parameter HBLANK_END 	  = 9; 

// MEASURED ON BOARD ! 
//Working but there is a shift of 3 pixel  (work for bk not for char)
//always @(posedge P6M) begin
  //if (hpos[1:0] == 2'b11)
    //T3F <= 1'b1;
  //if (hpos[1:0] == 2'b00)
    //T3F <= 1'b0;
//end 

//assign T4H = (hpos[2:0] == 3'b100);
//assign T8H = (hpos[2:0] == 3'b000); //ichar cen check on board 

//on other measure it look like that ... but it's the merged one 
//assign T3F = (hpos[1:0] == 2'b01);
//assign T4H = (hpos[2:0] == 3'b101);
//assign T8H = (hpos[2:0] == 3'b001);

// CHAR + BK is aligned but it create graphic glitches 
//parameter HBLANK_START  = 262; 
//parameter HBLANK_END 	  = 6; 
//assign T3F = (hpos[1:0] == 2'b00); // || hcnt == HBLANK_END ?  hpos[1:0] == 2'b00);
//assign T4H = (hpos[2:0] == 3'b01);
//assign T8H = (hpos[2:0] == 3'b110);

// old char rom cen 
// -> se0010bu -> load  (load char rom_data before serializing it !) 
    // -> must be stable (eg rom_cs must be 1 )?
//assign T3F = (hpos[1:0] == 2'b00); // || hcnt == HBLANK_END ?  hpos[1:0] == 2'b00);
//CLOCK ENABLE for ram out 
//ram get vpos and return the tile to ram_out that is used for address 
//(must be before T3F at leaest one cycle)
//assign T4H = (hpos[2:0] == 3'b01);
// vpos_latch for ram addr every 4 pix? 
// sync HBLB
// S4CLLT  -> sg0140 COL_B_EN  -> LATCH COL_B (PALETTE) 

// Direct simultaneous pin-22/23/24 capture establishes the sub-pixel
// ordering. The FPGA quantizes the measured 50-100 ns pin-23 lead onto P6M:
//   pin 23 changes on the selected P6M phase;
//   T8H rises on the following N6M edge (about 50-100 ns later);
//   pin 24 follows pin 23 after two P6M periods (about 333 ns).
// U518 consequently publishes HBLB over normalized hpos 6..261. HBL itself
// remains the literal pin-23 signal and is decoded from the raw counter bus.
localparam [8:0] HBL_RISE_H = 9'h107;
localparam [8:0] HBL_FALL_H = 9'h087;

reg hbl_delay_1;
reg hbl_delay_2;

always @(posedge clk) begin
  if (rst) begin
    HBL         <= 1'b0;
    hbl_delay_1 <= 1'b0;
    hbl_delay_2 <= 1'b0;
  end else if (P6M) begin
    if (H == HBL_RISE_H)
      HBL <= 1'b1;
    else if (H == HBL_FALL_H)
      HBL <= 1'b0;

    hbl_delay_1 <= HBL;
    hbl_delay_2 <= hbl_delay_1;
  end
end

assign L3 = VBL_ROM & hbl_delay_2;

// Pin 25 is a one-pixel pulse clocked on P6M.
always @(posedge clk) begin
  if (rst) begin
    T3F <= 1'b0;
  end else if (P6M) begin
    if (H[1:0] == 2'b11)
      T3F <= 1'b1;
    else if (H[1:0] == 2'b00)
      T3F <= 1'b0;
  end 
end

// Pins 26 and 22 are one-pixel strobes separated by four counts. A direct
// H<2:0>/pin-22/pin-26 capture places them at raw low counts 4 and 0.
assign T4H = (H[2:0] == 3'b100);
assign T8H = (H[2:0] == 3'b000);

// A joint H256/pin-23/VCLK capture places both VCLK pins on the raw
// 0x1ff->0x080 reload, normalized hpos 253->254, eight counts before U518 HBLB
// falls. Both VCLK outputs rise on that reload in 957/1000 sampled lines; the
// remainder are one 50 ns analyser sample later.
assign VCLK = (H == RAW_H_FIRST);

// Direct pin-22..28 capture shows pin 27 low for one pixel and releasing on
// the T8H group immediately preceding the pin-23 boundary. In this normalized
// phase HD is low at 253 and T8H/VCLK follow at 254.
assign HD = ~(H == RAW_H_LAST);
assign N1H = ~H[0];

// PROM26 supplies the vertical blank qualification separately on pin 33.
always @(posedge clk) begin 
    if (rst) begin
      // The physical IC has no normalized zero state.  These deterministic
      // FPGA reset values correspond to hpos=0/vpos=0 through the adapter
      // above and enter the trace-observed counter cycles immediately.
      H  <= RAW_H_NORM_ZERO;
      V  <= RAW_V_NORM_ZERO;
      HS <= 1'b0;
      VS <= 1'b0;
    end else if (N6M) begin 
      if (H == RAW_H_LAST) begin
        H <= RAW_H_FIRST;
        V <= V == RAW_V_LAST ? RAW_V_FIRST : V + 9'd1;
      end else begin
        H <= H + 9'd1;
      end

      //if (hpos[1:0] + 1'd1 == 2'b11 || hcnt == HBLANK_END)
        //char_rom_cen <= 1'b1;
      //else 
        //char_rom_cen <= 1'b0;
   
      //if (hpos[2:0] + 1'd1 == 3'b000 || hcnt == HBLANK_END) //we nneed 0 too but 384 + 1 is not 0
        //T8H <= 1'b1; 
       //else 
        //T8H <= 1'b0;

      if (H == RAW_HSYNC_START) begin
        HS <= 1'b1;
        if (V == RAW_VSYNC_START)
          VS <= 1'b1;
        else if (V == RAW_VSYNC_END)
          VS <= 1'b0;
      end else if (H == RAW_HSYNC_END) begin
        HS <= 1'b0;
      end
      end
end 

endmodule
