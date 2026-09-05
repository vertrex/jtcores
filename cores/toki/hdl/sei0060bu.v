// SEI0060BU — sprite line-buffer X address generator.
//
// The photographed Caius Arcade replacement contains 2x HC161, HC174, HC86,
// LS04 and HCT139 devices. That component population does not expose their
// interconnect: in particular, two HC161s prove eight counter stages, not a
// particular nine-bit cascade or the roles of the remaining devices.
//
// The RTL below is a provisional behavioral model, not the recovered TTL
// reproduction. It uses one write counter and one beam/read counter per
// instance, but that abstraction is not claimed as the replacement board's
// internal topology. Captured PCB EA/OA are free-running rather than resetting
// at HBLB as this model does. Genuine OBJT2_7 remains unused; T8H participates
// in holding the next V1B address role until blank because captured EA/OA
// continue monotonically through the final active pixels after live V1B
// changes. The blank-only LD-selected write route below is likewise an
// external-behavior/FPGA-latency accommodation, not a claimed literal latch
// inside the chip: the available captures do not include ADDR together with
// EA/OA. Both instances are live in the promoted sheet-17 renderer; further
// internal reconstruction still requires a joint
// LD/clear/ADDR/EA/OA/OBJT2_7/N6M/HREV capture.
//
// Current coordinated FPGA bank routing (not a recovered internal polarity):
//       V1B = 0 : EVEN = displayed (beam), ODD  = written (write cnt)
//       V1B = 1 : ODD  = displayed (beam), EVEN = written (write cnt)
// The RTL complements both address buses when HREV is high. The exact custom-
// IC HREV equation remains unproven because the available attract trace held
// HREV low.
//
// EVNCLR / ODDCLR are active-low clear levels for the off-bank (next-line)
// line buffer. PCB captures hold the selected clear low throughout HBLB-low.

module SEI0060BU(
    input  wire       clk,      // FPGA master clock; no package-pin equivalent
    input  wire       cen,      // pin 18 OBJ N6M, represented as a 6MHz enable
    input  wire [8:0] ADDR,     // pins 2-9 = [7:0], pin 11 = [8] (FHK or OHK)
    input  wire       ODD_LD,   // pin 10 active-low load phase
    input  wire       EVN_LD,   // pin 24 active-low load phase
    input  wire       HBLB,     // pin 13; high = active video
    input  wire       OBJT2_7,  // pin 14; observed ~38-line vertical phase
    input  wire       V1B,      // pin 15 line-parity phase
    input  wire       T8H,      // pin 16; eight-pixel V1B-to-HBLB phase
    input  wire       HREV,     // pin 17; exact internal transform unrecovered

    output wire [8:0] OA,       // [7:0] pins 34-41, [8] pin 19
    output wire [8:0] EA,       // [7:0] pins 25-32, [8] pin 20
    output reg        EVNCLR,   // pin 22 even-bank clear, active low
    output reg        ODDCLR    // pin 33 odd-bank clear, active low
);

    // -----------------------------------------------------------
    // Write counter
    //
    // Behavioral write-address counter. The photographed HC161 population
    // supports a counter role, but its interconnect, ninth bit and exact load
    // clock are unrecovered. Here LD becomes a clk-domain falling-edge command
    // so a pulse shorter than one cen period is not lost; increments remain
    // gated by physical OBJ N6M's 6MHz cadence.
    // -----------------------------------------------------------
    reg [8:0] wr_cnt;
    reg       evn_ld_d;
    reg       odd_ld_d;
    reg       write_bank_v1b = 1'b0;
    wire      evn_ld_fall = evn_ld_d && !EVN_LD;
    wire      odd_ld_fall = odd_ld_d && !ODD_LD;
    wire      ld_fall = evn_ld_fall || odd_ld_fall;

    always @(posedge clk) begin
        evn_ld_d <= EVN_LD;
        odd_ld_d <= ODD_LD;
        if (ld_fall) begin
            wr_cnt <= ADDR;
            // PLD22 names the load phase, while sheet 18 names the physical
            // RAM. The coordinated FPGA renderer routes EVN_LD to ODD/OA and
            // ODD_LD to EVEN/EA. Separate PCB captures without ADDR cannot
            // establish that physical polarity directly, so do not change
            // this mapping apart from LINEBUF/OBJPS/WREN. Remember the decoded
            // route independently of live V1B so the final physical-list slot
            // can drain in horizontal blank after V1B has advanced. This
            // register is not a recovered internal SEI0060BU storage element.
            if (evn_ld_fall)
                write_bank_v1b <= 1'b0;
            else
                write_bank_v1b <= 1'b1;
        end else if (cen)
            wr_cnt <= wr_cnt + 9'd1;
    end


    // -----------------------------------------------------------
    // Beam counter (normalized to visible X=0 at the HBLB rising edge).
    //
    // HBLB can rise between N6M enables. Sampling that edge only inside the
    // cen branch recognizes it one pixel late, although the captured PCB
    // address bus rephases on the same sample as HBLB. Detect this external
    // coordinate boundary on the master clock while leaving increments on
    // N6M. This is a phase normalization for the provisional two-counter
    // model, not a claim that the custom IC contains a resettable beam counter.
    // -----------------------------------------------------------
    reg  [8:0] beam_cnt;
    reg        hblb_d = 1'b0;
    reg        beam_hblb_d = 1'b0;
    reg        clear_v1b = 1'b0;
    always @(posedge clk) begin
        beam_hblb_d <= HBLB;
        if (cen)
            hblb_d <= HBLB;

        if (!beam_hblb_d && HBLB)
            beam_cnt <= 9'd0;
        else if (cen)
            beam_cnt <= beam_cnt + 9'd1;
    end

    // -----------------------------------------------------------
    // Inferred address-role selection and HREV transform
    //
    // V1B changes eight pixels before HBLB falls, while sheet 18 keeps the
    // current display bank selected through D1V_7P. Raw PCB EA/OA captures
    // likewise keep counting the current display address through that tail;
    // they do not jump to the write counter on the live V1B edge. T8H is the
    // physical phase input shared with the upstream V1B latch: capture the
    // next role at H=254, then publish it when the following T8H rising edge
    // and HBLB fall coincide at the normalized H=262 boundary.
    //
    // bank_v1b = 0 : EVEN displays (beam), ODD writes (wr_cnt)
    // bank_v1b = 1 : ODD displays (beam),  EVEN writes (wr_cnt)
    // -----------------------------------------------------------
    // Current Pocket/MiSTer-validated coordinated FPGA routing:
    //   V1B=0 -> EA is the free-running display beam, OA is the loaded write
    //            counter (EVN_LD is the phase name, not the RAM-bank name).
    //   V1B=1 -> OA is the display beam, EA is the loaded write counter.
    // Independent PCB EA and OA captures prove continuity at the active tail,
    // but without ADDR they do not establish which bus is the loaded counter.
    // LINECUNT crosses its EVN/ODD phase windows onto the physical ODD/EVEN
    // RAM enables. Keeping both sides of that crossing is essential; changing
    // only this selection writes pixels at the beam position.
    reg bank_v1b = 1'b0;
    reg next_bank_v1b = 1'b0;
    // Common-clock level sampling while T8H is high. This is not claimed as a
    // literal T8H-edge register inside the custom IC.
    always @(posedge clk) begin
        if (T8H)
            next_bank_v1b <= V1B;
        if (beam_hblb_d && !HBLB)
            // If the physical T8H and HBLB edges coincide, live V1B is the
            // value already held since the preceding eight-pixel boundary.
            bank_v1b <= T8H ? V1B : next_bank_v1b;
    end

    // Active video always gives the held display role priority. During
    // horizontal blank there is no display read to preserve, so the most
    // recent physical LD phase owns the write-counter route. This is needed
    // for the final old-bank SORT48 pair (lane 0/slot 47 and lane 1/slot 23):
    // it is captured before the V1B edge but can complete its fixed write
    // burst after it, entirely in blanking. Clear selection below deliberately
    // remains on live V1B.
    wire address_bank_v1b = HBLB ? bank_v1b : write_bank_v1b;
    wire [8:0] even_raw = address_bank_v1b ? wr_cnt   : beam_cnt;
    wire [8:0] odd_raw  = address_bank_v1b ? beam_cnt : wr_cnt;
    assign EA = HREV ? ~even_raw : even_raw;
    assign OA = HREV ? ~odd_raw  : odd_raw;

    // -----------------------------------------------------------
    // Per-line clear levels prepare the physical write/back bank during
    // blanking. PCB captures show V1B=0 clears ODD and V1B=1 clears EVEN.
    // -----------------------------------------------------------
    always @(posedge clk) begin
        if (cen) begin
            EVNCLR <= 1'b1;
            ODDCLR <= 1'b1;
            if (hblb_d && !HBLB) begin
                // Hold the selected physical clear pin throughout blanking.
                // LINEBUF converts its first falling edge into one atomic FPGA
                // validity-clear command; changing target with live V1B would
                // issue a second command and invalidate both banks. This hold
                // is an FPGA contract, not a recovered internal chip latch.
                clear_v1b <= V1B;
                if (V1B)
                    EVNCLR <= 1'b0;
                else
                    ODDCLR <= 1'b0;
            end else if (!HBLB) begin
                if (clear_v1b)
                    EVNCLR <= 1'b0;
                else
                    ODDCLR <= 1'b0;
            end
        end
    end

endmodule
