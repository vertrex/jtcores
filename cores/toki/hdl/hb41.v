// Seibu HB-41 analogue filter/mixer replacement
//
// Sources:
//   - Toki PCB schematic, sheet 11
//   - seibu_hb41_schematic_color.pdf (reverse-engineered HB-41)
//   - OKI MSM6295 data sheet (15 kOhm typical DA output impedance)
//
// This block models the Toki-wired line-level path from the YM3014/MSM6295
// outputs to HB-41 pin 15.  That includes the external sheet-11 music loop
// through HB-41 pins 16 and 5, and the MSM6295's source impedance.  Other
// HB-41 applications may require different input-pole coefficients.
//
// The fixed coefficients require a 192 kHz sample enable. FRACN/FRACM
// default to 1/250 for Toki's 48 MHz master clock; the parameters exist for
// rate-equivalent verification and must not be changed without regenerating
// all filter coefficients.
//
// The two 2.2 uF input coupling capacitors have a 15.4 Hz corner and the
// pin-15 coupling network is below 2 Hz.  They are deliberately omitted:
// signed FPGA sources already lack analogue bias, and the remaining response
// difference is confined to deep bass (about -0.1 dB at 100 Hz, -2 dB at
// 20 Hz).  The volume control, LA4460 power amplifier and speaker are also
// outside this line-level model.
module hb41 #(
    parameter FRACW = 9,
    parameter FRACN = 1,
    parameter FRACM = 250
)(
    input                      rst,
    input                      clk,
    input      signed [15:0]   fm,
    input      signed [13:0]   fx,
    input             [ 1:0]   fxlevel,
    output     signed [15:0]   snd
);

// 48 MHz * 1/250 = 192 kHz.  A high audio-domain rate keeps the bilinear
// component models accurate while presenting a held sample to JTFrame.
wire cen_unused;
wire cen_192;

jtframe_frac_cen #(.W(2), .WC(FRACW)) u_cen192(
    .clk    ( clk                  ),
    .n      ( FRACN[FRACW-1:0]     ),
    .m      ( FRACM[FRACW-1:0]     ),
    .cen    ( {cen_unused, cen_192} ),
    .cenb   (                      )
);

// MUSIC path:
//   HB17 -> unity buffers -> HB16/R8 270R -> Toki R111 47k/R112
//   47k divider -> HB5/C1 1n -> unity buffer -> the final summer.
//
// The divider is 0.4986 at DC.  Its Thevenin resistance and C1 form a
// 6.753 kHz pole.  A divide by two is within 0.3% of the resistor ratio.
wire signed [15:0] fm_divided = fm >>> 1;
wire signed [19:0] fm_guarded = {fm_divided, 4'b0};
wire signed [19:0] fm_pole_guarded;
wire signed [19:0] fm_pole_rounded =
    fm_pole_guarded
    + (fm_pole_guarded[19] ? 20'sd7 : 20'sd8);
wire signed [15:0] fm_filtered = fm_pole_rounded[19:4];

jtframe_pole #(.WS(20), .WA(15)) u_fm_pole(
    .rst    ( rst             ),
    .clk    ( clk             ),
    .sample ( cen_192         ),
    .a      ( 15'h666e        ), // 6.753 kHz at 192 kHz
    .sin    ( fm_guarded      ),
    .sout   ( fm_pole_guarded )
);

// EFFECTS path:
//   MSM6295 Rout 15k/HB C8 10n -> R10 4.7k + R7 22k ->
//   R6 4.7k, C10 10n, C3 1n and U2D.
//
// Its exact ideal-op-amp denominator is:
//   1 + 1.964e-4*s + 6.6699e-9*s^2 + 1.88235e-13*s^3
// This factors into a 979.54 Hz real pole followed by a complex pair at
// 4.67594 kHz, Q=1.00343.  Two independent RC poles cannot reproduce that
// pair, hence the small fixed biquad below.
wire signed [15:0] fx_full = {fx, 2'b0};
wire signed [19:0] fx_guarded = {fx_full, 4'b0};
wire signed [19:0] fx_pole_guarded;
wire signed [19:0] fx_pole_rounded =
    fx_pole_guarded
    + (fx_pole_guarded[19] ? 20'sd7 : 20'sd8);
wire signed [15:0] fx_first_pole = fx_pole_rounded[19:4];
wire signed [15:0] fx_filtered;

jtframe_pole #(.WS(20), .WA(15)) u_fx_pole(
    .rst    ( rst             ),
    .clk    ( clk             ),
    .sample ( cen_192         ),
    .a      ( 15'h7bf5        ), // 979.54 Hz at 192 kHz
    .sin    ( fx_guarded      ),
    .sout   ( fx_pole_guarded )
);

hb41_biquad u_fx_biquad(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .sample ( cen_192       ),
    .sin    ( fx_first_pole ),
    .sout   ( fx_filtered   )
);

// fxlevel is a JTFrame user adjustment rather than an HB-41 pin.  Keep the
// established Toki choices: 50%, 75%, 100% and 200%.
reg signed [16:0] fx_scaled;
wire signed [16:0] fx_for_gain =
    {fx_filtered[15], fx_filtered};

always @* begin
    case (fxlevel)
        2'd0: fx_scaled = fx_for_gain >>> 1;
        2'd1: fx_scaled = (fx_for_gain >>> 1)
                           + (fx_for_gain >>> 2);
        2'd2: fx_scaled = fx_for_gain;
        default:
              fx_scaled = $signed({fx_filtered, 1'b0});
    endcase
end

// U2A is the common inverting summer.  R4, R5 and R12 are all 4.7k, so
// both paths have unity magnitude.  C9=1.5n across R4 adds a 22.575 kHz
// common pole.  Absolute inversion is not retained because snd has no
// phase-related consumer. Both paths retain their relative polarity; the
// synchronous effects cascade has one extra 192 kHz delay (5.2 us), which
// is negligible compared with the analogue network's own group delay.
wire signed [17:0] fm_extended =
    {{2{fm_filtered[15]}}, fm_filtered};
wire signed [17:0] fx_extended =
    {{1{fx_scaled[16]}}, fx_scaled};
wire signed [17:0] mixed_pre = fm_extended + fx_extended;
wire signed [21:0] mixed_guarded = {mixed_pre, 4'b0};
wire signed [21:0] common_pole_guarded;
wire signed [21:0] common_pole_rounded =
    common_pole_guarded
    + (common_pole_guarded[21] ? 22'sd7 : 22'sd8);
wire signed [17:0] mixed_filtered = common_pole_rounded[21:4];

jtframe_pole #(.WS(22), .WA(15)) u_common_pole(
    .rst    ( rst                 ),
    .clk    ( clk                 ),
    .sample ( cen_192             ),
    .a      ( 15'h388c            ), // 22.575 kHz at 192 kHz
    .sin    ( mixed_guarded       ),
    .sout   ( common_pole_guarded )
);

wire signed [15:0] mixed_limited = saturate16(mixed_filtered);

// The compact fixed-point poles can retain a +/-1 output code after a
// one-sided impulse.  Remove only that terminal quantization residue so the
// FPGA DAC receives true digital silence; real programme samples are
// otherwise untouched.
assign snd = (mixed_filtered >= -18'sd1 && mixed_filtered <= 18'sd1)
           ? 16'sd0 : mixed_limited;

function signed [15:0] saturate16;
    input signed [17:0] value;
    begin
        if (value > 18'sd32767)
            saturate16 = 16'sh7fff;
        else if (value < -18'sd32768)
            saturate16 = 16'sh8000;
        else
            saturate16 = value[15:0];
    end
endfunction

endmodule

// Fixed, reset-safe direct-form-I realization of the HB-41 effects-path
// complex pole pair.  Coefficients are Q2.15 and come from a bilinear
// transform pre-warped at 4.67594 kHz:
//   b = 0.00542995, 0.01085990, 0.00542995
//   a = 1, -1.83710108, 0.85882087
//
// Quantization was selected so numerator and denominator have identical DC
// sums (712/712), preserving unity DC gain without a correction multiplier.
// Products and additions are pipelined across four 48 MHz clocks.  This is
// only an FPGA timing implementation detail: all four clocks fit inside the
// 250-clock interval between 192 kHz samples, so the filter still advances
// exactly once per audio sample and gains no additional sample delay.
module hb41_biquad(
    input                       rst,
    input                       clk,
    input                       sample,
    input      signed [15:0]    sin,
    output reg signed [15:0]    sout
);

localparam signed [16:0] B0 =  17'sd178;
localparam signed [16:0] B1 =  17'sd356;
localparam signed [16:0] B2 =  17'sd178;
localparam signed [16:0] A1 = -17'sd60198;
localparam signed [16:0] A2 =  17'sd28142;

// Eight guard-fraction bits are retained in the delay elements.  Feeding
// back a 16-bit rounded y value can otherwise sustain a several-LSB idle
// tone; the analogue op-amp naturally decays to zero.
localparam STATE_FRAC = 8;

wire signed [23:0] x0 = {sin, {STATE_FRAC{1'b0}}};
reg  signed [23:0] x1, x2;
reg  signed [23:0] y1, y2;

wire signed [40:0] xb0 = $signed(x0) * B0;
wire signed [40:0] xb1 = $signed(x1) * B1;
wire signed [40:0] xb2 = $signed(x2) * B2;
wire signed [40:0] ya1 = $signed(y1) * A1;
wire signed [40:0] ya2 = $signed(y2) * A2;

reg signed [23:0] x0_pipe;
reg signed [40:0] xb0_pipe, xb1_pipe, xb2_pipe;
reg signed [40:0] ya1_pipe, ya2_pipe;
reg signed [43:0] feedforward_pipe, feedback_pipe;
reg signed [43:0] accumulator_pipe;
reg               product_valid;
reg               sum_valid;
reg               accumulator_valid;

// Round before dropping the Q15 fractional bits.  A plain arithmetic shift
// biases every negative result downward and can leave a small zero-input
// limit cycle in this high-Q section.
wire signed [43:0] rounded =
    accumulator_pipe
    + (accumulator_pipe[43] ? 44'sd16383 : 44'sd16384);
wire signed [43:0] scaled = rounded >>> 15;
wire signed [23:0] next_y_state = saturate_state(scaled);

wire signed [24:0] output_extended =
    {next_y_state[23], next_y_state};
wire signed [24:0] output_rounded =
    output_extended
    + (next_y_state[23] ? 25'sd127 : 25'sd128);
wire signed [24:0] output_scaled = output_rounded >>> STATE_FRAC;
wire signed [15:0] next_y = saturate_biquad(output_scaled);

always @(posedge clk) begin
    if (rst) begin
        x1   <= 0;
        x2   <= 0;
        y1   <= 0;
        y2   <= 0;
        sout <= 0;
        product_valid     <= 0;
        sum_valid         <= 0;
        accumulator_valid <= 0;
    end else begin
        product_valid     <= sample;
        sum_valid         <= product_valid;
        accumulator_valid <= sum_valid;

        if (sample) begin
            x0_pipe  <= x0;
            xb0_pipe <= xb0;
            xb1_pipe <= xb1;
            xb2_pipe <= xb2;
            ya1_pipe <= ya1;
            ya2_pipe <= ya2;
        end

        if (product_valid) begin
            feedforward_pipe <=
                {{3{xb0_pipe[40]}}, xb0_pipe}
              + {{3{xb1_pipe[40]}}, xb1_pipe}
              + {{3{xb2_pipe[40]}}, xb2_pipe};
            feedback_pipe <=
                {{3{ya1_pipe[40]}}, ya1_pipe}
              + {{3{ya2_pipe[40]}}, ya2_pipe};
        end

        if (sum_valid)
            accumulator_pipe <= feedforward_pipe - feedback_pipe;

        if (accumulator_valid) begin
            x2   <= x1;
            x1   <= x0_pipe;
            y2   <= y1;
            y1   <= next_y_state;
            sout <= next_y;
        end
    end
end

function signed [23:0] saturate_state;
    input signed [43:0] value;
    begin
        if (value > 44'sd8388607)
            saturate_state = 24'sh7fffff;
        else if (value < -44'sd8388608)
            saturate_state = 24'sh800000;
        else
            saturate_state = value[23:0];
    end
endfunction

function signed [15:0] saturate_biquad;
    input signed [24:0] value;
    begin
        if (value > 25'sd32767)
            saturate_biquad = 16'sh7fff;
        else if (value < -25'sd32768)
            saturate_biquad = 16'sh8000;
        else
            saturate_biquad = value[15:0];
    end
endfunction

endmodule
