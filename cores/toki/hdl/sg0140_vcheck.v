///////////////////////////////////////////////////
///////////// SG0140 VCHECK ///////////////////////
///////////////////////////////////////////////////
// gemini : 
//
// Vertical Visibility Checker & Ping-Pong Buffer Controller
// This is the heart of the Sprite DMA engine.
// 1. Tracks the CRT Scanline (current_y).
// 2. Checks if the sprite currently on the bus (VPD) intersects the scanline.
// 3. Generates the Texture Line Offset (VMT).
// 4. Manages the Write Strobes for the Ping-Pong Line Buffers.
//
// codex : 
// 1. Visibility test: Compare the current scanline with each sprite’s Y position and produce a 4‑bit line‑within‑sprite offset
//     (VMT) if visible.
// 2. List write strobes: Generate EVNWR2/ODDWR2 to store the sprite’s per‑line metadata into the line list RAMs (SIS6091B in
//     SCNDDMA).
//  3. DMA handshaking: Generate OBUSRQ and OIBDIR to request/hold the object RAM bus during the DMA scan.

module sg0140_vcheck(
  input             clk,      // main clk 48Mhz
  input             rst,      // reset signal 
  input       [7:0] VPD,      // Sprite Y Position (Lower 8 bits) + offset (objdma -> hvpos -> SIS6091 -> VPD)
  input             ODMARQ,   // DMA Request (Bus Arbitration) Assertion should drive OBUSRQ low
  input             OBUSAK,   // Bus Acknowledge from CPU. When asserted, OIBDIR becomes active (bus granted).
  input             SDTS,     // Serial Data Timing Strobe : "Scan DMA" start / sprite processing start(from STARTV) 59.61khz frequency 
  input             VORIGIN,  // Vertical Origin (Frame Reset) PROM‑derived visible vertical origin 
  input             OVER256,  // DMA Window Limit (Active Low = In Window) or "DMA active/done" flag 
  input             OVER48,   // List overflow (from sort48), stop to writes and VFIND 
  input             VREVD_2,  // Sprite Vertical Flip Flag
  input             OBJEN_3,  // Sprite Slot Valid Flag (sprite enable after PLD24 gating (~INSCRN & OBJEN_2))
  input             H2,       // Horizontal Timing used for ? (every 8 pixel? 2**3? to validate) 
  input             RDCLK,    // Read Clock (6MHz Strobe) from Object DMA. 
  input             VCLK,     // Line tick (≈15.6 kHz) (Increments Y /internal scanline counter)
  input             VREV,     // Screen Vertical Flip (Cocktail Mode)
  input             NV256,    // Vertical Blanking/MSB or "in-visible-area"/active display flag (reset scanline counter?) > 256pixel

  output reg  [3:0] VMT,    // Vertical Map Texture/ Vertical Metadata (Line Offset 0-15) used to fetch correct row from ROM
  output reg        EVNWR2, // Write Enable for Even Buffer (Active Low) write strobes into SCNDMA list RAMs
  output reg        ODDWR2, // Write Enable for Odd Buffer (Active Low)
  output reg        OIBDIR, // Bus direction enable (Active low , 0 = object DMA own the bus)
  output reg        OBUSRQ, // Bus Request Output to the CPU (Active low)
  output reg        VFIND   // Sprite Found Strobe (Active Low) consumed by sort48 and PLD24 to generate MATCHV
);

    // -------------------------------------------------------------------------
    // 1. Line Counter
    // -------------------------------------------------------------------------
    reg [8:0] current_y;
    reg old_vclk;
    reg old_vorigin;
    
    always @(posedge clk) begin
        if (rst) begin
            current_y  <= 0;
            old_vclk   <= 0;
            old_vorigin<= 0;
        end else begin
            old_vclk    <= VCLK;
            old_vorigin <= VORIGIN;

            // Frame Reset on rising edge of VORIGIN
            if (!old_vorigin && VORIGIN) begin
                current_y <= 9'd0;
            end
            // Line Increment
            else if (VCLK && !old_vclk) begin
                current_y <= current_y + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. Bus Arbitration
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            OBUSRQ <= 1'b1; 
            OIBDIR <= 1'b1; 
        end
        else begin
            // busrequest 
            if (!ODMARQ) 
                OBUSRQ <= 1'b0;
            
            if (!OBUSAK && !OBUSRQ) begin
                OIBDIR <= 1'b0; // bus granted
                OBUSRQ <= 1'b1; 
            end

            // Release bus when DMA window ends
            if (!OVER256) 
                OIBDIR <= 1'b1;

        // SDTS could also gate request/ownership
        end
    end

    // -------------------------------------------------------------------------
    // 3. Visibility Calculation
    // -------------------------------------------------------------------------
    // Extended Y to 9 bits for calculation logic
    wire [8:0] sprite_y = {1'b0, VPD};
    //wire [8:0] sprite_y = {VREVD_2, VPD};

    // Distance from current scanline
    // Unsigned subtraction handles wrapping correctly for this logic
    wire [8:0] diff_y = current_y - sprite_y;
    
    // Sprite is visible if scanline is within [Y, Y+15]
    wire visible = (diff_y < 9'd16);
   
    // Flip Logic:
    // Screen Flip (VREV) XOR Sprite Flip (VREVD_2)
    wire screen_flip = VREV ^ VREVD_2;

    // Ping-Pong Logic:
    // If we are displaying Line N, we must prepare the buffer for Line N+1.
    // Line N Even (LSB=0) -> Next is Odd. Write to Odd.
    // Line N Odd  (LSB=1) -> Next is Even. Write to Even.
    //wire target_is_even = current_y[0]; // If 1 (Odd), next is Even.
    
    // RDCLK edge detector for single-cycle strobes
    reg rdclk_d;
    wire rdclk_fall = (rdclk_d == 1'b1) && (RDCLK == 1'b0);

    // List-build phase: during display (SDTS=0). Do not gate by OIBDIR.
    wire list_phase = ~SDTS;

    always @(posedge clk) begin
        rdclk_d <= RDCLK;
        if (rst) begin
            VFIND <= 1'b1;
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
            VMT <= 4'h0;
        end else begin
            // Defaults (inactive)
            VFIND  <= 1'b1;
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;

            if (list_phase && rdclk_fall) begin
                if (visible && OBJEN_3 && !OVER48) begin
                    VFIND <= 1'b0;
                    VMT   <= screen_flip ? ~diff_y[3:0] : diff_y[3:0];

                    // Choose list RAM by line parity.
                    // Use current_y[0] which is aligned to VORIGIN/VCLK.
                    if (current_y[0]) begin
                        ODDWR2 <= 1'b0;
                    end else begin
                        EVNWR2 <= 1'b0;
                    end
                end else begin
                    VFIND <= 1'b1;
                    VMT   <= 4'h0;
                end
            end
        end
    end

endmodule

