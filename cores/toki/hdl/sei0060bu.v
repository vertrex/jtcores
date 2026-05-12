// SEI0060BU — sprite line-buffer X address generator.
//
// TTL repro (Caius Arcade) = 2x HC161 + HC174 + HCT86 + HCT139 + LS04.
// Two cascaded HC161s form one 9-bit synchronous counter; the HC174 latches
// the load value / upper bits; HCT86 XORs the outputs with HREV; HCT139
// decodes V1B/HBLB/load strobes.
//
// Architecture (from schematic sheet 17 and repro analysis):
//   - ONE write counter per instance, loaded by EVN_LD or ODD_LD with ADDR,
//     increments on each cen (N6M pulse). No internal pixel-count limit —
//     the 16-pixel sprite extent is governed externally by OBJPS/PLD29.
//   - ONE beam (read) counter per instance, reset at start of each active
//     line (HBLB rising), increments on cen.
//   - The V1B/HBLB mux (HCT139) routes the two counters to the EA and OA
//     output pairs depending on which bank is being written this line and
//     which is being read for display:
//       V1B = 0 : EVEN = displayed (beam), ODD  = written (write cnt)
//       V1B = 1 : ODD  = displayed (beam), EVEN = written (write cnt)
//   - HREV XORs both address buses for cocktail/flip-screen mode.
//
// EVNCLR / ODDCLR are active-low clear strobes for the off-bank (next-line)
// line buffer, pulsed during HBLB.

module SEI0060BU(
    input  wire       clk,
    input  wire       cen,      // 6MHz pixel clock enable
    input  wire [8:0] ADDR,     // write base address (sprite X)
    input  wire       ODD_LD,   // load strobe, active low
    input  wire       EVN_LD,   // load strobe, active low
    input  wire       HBLB,     // H blank bar (high = active video)
    input  wire       OBJT2_7,  // unused in current pipeline
    input  wire       V1B,      // line-parity display select
    input  wire       T8H,      // unused in current pipeline
    input  wire       HREV,     // horizontal flip

    output wire [8:0] OA,       // odd buffer address
    output wire [8:0] EA,       // even buffer address
    output reg        EVNCLR,   // even bank clear (active low)
    output reg        ODDCLR    // odd bank clear (active low)
);

    // -----------------------------------------------------------
    // Write counter
    //
    // Hardware: two cascaded HC161 synchronous counters with parallel-load
    // on LD low at the CP rising edge. Here we model LD as a clk-domain
    // falling-edge strobe so a short pulse (less than a cen period) still
    // loads. Count increments are gated by cen (6MHz).
    // -----------------------------------------------------------
    reg [8:0] wr_cnt;
    reg       evn_ld_d;
    reg       odd_ld_d;
    wire      ld_fall = (evn_ld_d && !EVN_LD) || (odd_ld_d && !ODD_LD);

    always @(posedge clk) begin
        evn_ld_d <= EVN_LD;
        odd_ld_d <= ODD_LD;
        if (ld_fall)
            wr_cnt <= ADDR;
        else if (cen)
            wr_cnt <= wr_cnt + 9'd1;
    end



    // -----------------------------------------------------------
    // Beam counter (reset on HBLB rising edge, then increments)
    // -----------------------------------------------------------
    reg  [8:0] beam_cnt;
    reg        hblb_d;
    always @(posedge clk) begin
        if (cen) begin
            hblb_d <= HBLB;
            if (!hblb_d && HBLB)
                beam_cnt <= 9'd0;
            else
                beam_cnt <= beam_cnt + 9'd1;
        end
    end

    // -----------------------------------------------------------
    // HCT139 role mux + HCT86 HREV XOR
    //
    // V1B = 0 : EVEN displays (beam), ODD writes (wr_cnt)
    // V1B = 1 : ODD displays (beam),  EVEN writes (wr_cnt)
    // -----------------------------------------------------------
    // V1B mux: linecunt writes EVEN (u_181/u_182) when V1B=0 (EVNWREN active
    // only then) and writes ODD (u_183/u_184) when V1B=1. So:
    //   V1B=0 → EVEN bus carries wr_cnt (sprite X write addr)
    //   V1B=0 → ODD  bus carries beam_cnt (display read addr for ODD bank)
    //   V1B=1 → swapped
    // Previous polarity had even_raw = V1B ? wr_cnt : beam_cnt, which meant
    // when EVEN was being written (V1B=0) the EA port carried beam_cnt —
    // the display beam position — instead of the sprite X. Writes then
    // landed at the current beam X, not the sprite's target X. That was
    // the root cause of the X offset seen in sim (sprite at X=273 for a
    // CPU-set X=116) and the "X reversed / random" behavior.
    wire [8:0] even_raw = V1B ? beam_cnt : wr_cnt;
    wire [8:0] odd_raw  = V1B ? wr_cnt   : beam_cnt;
    assign EA = HREV ? ~even_raw : even_raw;
    assign OA = HREV ? ~odd_raw  : odd_raw;

    // -----------------------------------------------------------
    // Per-line clear pulses: erase the bank that will be *read*
    // on the NEXT line. During H-blank, target the bank opposite
    // the current write bank.
    // -----------------------------------------------------------
    always @(posedge clk) begin
        if (cen) begin
            EVNCLR <= 1'b1;
            ODDCLR <= 1'b1;
            if (!HBLB) begin
                if (V1B)  EVNCLR <= 1'b0;  // odd displays -> next even is rebuilt, clear it
                else      ODDCLR <= 1'b0;
            end
        end
    end

endmodule
