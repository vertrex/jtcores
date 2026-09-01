// Sheet-14 U1411 SG0140 VCHECK operating mode: object-bus arbitration,
// vertical visibility checking, sprite-row generation and even/odd secondary-
// list write control.
//
// PCB captures prove that the selected physical list receives exactly 48 WR2
// transfers per line: visible descriptors first while OVER256 is high, then
// invalid padding after OVER256 falls until SORT48 reaches OVER48.  VFIND is
// active low throughout each RDCLK-qualified transfer; PLD24 consequently
// generates MATCHV=0 for the valid prefix and MATCHV=1 for the padding tail,
// which U151/U152 store with the descriptor tuple.
//
// The 48 MHz implementation asserts WR2 during the represented RDCLK-low
// aperture and retires it on the following RDCLK rise.  This preserves the
// measured package-pin ordering and holds SORT48's address stable through the
// synchronous FPGA RAM write.  The precise internal SG0140 gate equations are
// still opaque and are not claimed by this pin-visible protocol model.
//
// The 48 MHz clk, edge detectors and registered-U141 phase compensation are
// FPGA infrastructure. Pin 39 is selected by the board's JP141 VCC/GND jumper,
// but its custom-IC function is unrecovered and it is intentionally omitted
// from this interface. Physical pin 7 fans out through two U1413 buffer
// channels as both OIBDIR and OBUSDIR, so OBJDMA's external OBUSDIR=OIBDIR
// connection matches the schematic.

module sg0140_vcheck(
  input             clk,      // FPGA 48 MHz common clock; not an SG0140 pin
  input             rst,      // FPGA reset abstraction for RESETA pins 40/41

  input       [7:0] VPD,      // pins 9..16: descriptor vertical-position bus from U141
  input             ODMARQ,   // pin 28: active-low object-DMA request
  input             OBUSAK,   // pin 29: active-low 68000 bus grant/acknowledge
  input             SDTS,     // pin 30: STARTV sampled by VCLK in U142; frame-phase level
  input             VORIGIN,  // pin 31: PROM26-derived vertical-origin timing
  input             OVER256,  // pin 32: OBJDMA 256-entry terminal/window level
  input             OVER48,   // pin 34: SORT48 48-entry terminal level
  input             VREVD_2,  // pin 33: per-descriptor vertical reverse
  input             OBJEN_3,  // pin 35: PLD24 admitted-object level
  input             H2,       // pin 38: physical H2 timing input; internal role unrecovered
  input             RDCLK,    // pin 26: physical read timing input; exact SG edge unrecovered
  input             VCLK,     // pin 27: one-line timing level (about 15.6 kHz)
  input             VREV,     // pin 3: global/cocktail vertical reverse
  input             NV256,    // pin 2: PLD22 /V256 vertical-MSB timing

  output reg  [3:0] VMT,    // pins 17..20: 1/2/4/8 sprite row within the 16-line object
  output reg        EVNWR2, // pin 23: active-low even-list write control
  output reg        ODDWR2, // pin 24: active-low odd-list write control
  output reg        OIBDIR, // pin 7 via U1413: active-low object-bus ownership/direction
  output reg        OBUSRQ, // pin 6 via U1413: active-low CPU bus request
  output reg        VFIND   // pin 5: physical active-low transfer level
);

    // -------------------------------------------------------------------------
    // 1. Line Counter
    // -------------------------------------------------------------------------
    reg [8:0] current_y;
    reg old_vclk;
    reg old_vorigin;
    reg old_nv256;
    
    always @(posedge clk) begin
        if (rst) begin
            current_y  <= 0;
            old_vclk   <= 0;
            old_vorigin<= 0;
            old_nv256  <= 0;
        end else begin
            old_vclk    <= VCLK;
            old_vorigin <= VORIGIN;
            old_nv256   <= NV256;

            // Current inferred phase: restart on the rising edge of VORIGIN.
            if (!old_vorigin && VORIGIN) begin
                current_y <= 9'd0;
            end
            // NV256 is the PCB's vertical-MSB input to VCHECK.  Its falling
            // edge is the 261->0 raster wrap.  The object list is a
            // ping-pong line buffer, so VCHECK must assemble beam line + 1:
            // preload one here, then let VCLK advance it once per line.
            // Ignoring this pin let the six post-VORIGIN blanking lines leak
            // into the counter and displayed every sprite five lines early.
            else if (old_nv256 && !NV256) begin
                current_y <= 9'd1;
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
    reg dma_pending;

    // The former FPGA recovery guard released a request after 131072 master
    // clocks. The PCB has no corresponding timeout: once granted, ownership
    // ends only at U147/U148's 256-entry terminal count. Follow that physical
    // contract here and let an incomplete transfer remain observable instead
    // of silently converting it into a partial object snapshot.

    always @(posedge clk) begin
        if (rst) begin
            OBUSRQ <= 1'b1; 
            OIBDIR <= 1'b1; 
            dma_pending <= 1'b0;
        end
        else begin
            // ODMARQ is only a short active-low CPU write strobe. Latch that
            // request until the 68000 acknowledges it; the grant normally
            // arrives after ODMARQ has already returned high.
            if (!ODMARQ)
                dma_pending <= 1'b1;

            if (!OVER256) begin
                // End DMA ownership and release the RAM bus. A new short
                // ODMARQ can coincide with this idle/terminal interval, so
                // preserve BR if either the live pulse or its pending latch is
                // active instead of discarding that frame's refresh request.
                OIBDIR <= 1'b1;
                OBUSRQ <= (dma_pending || !ODMARQ) ? 1'b0 : 1'b1;
            end else if (!OBUSAK && !OBUSRQ) begin
                // The 68000 granted the bus.  Keep BR asserted until the whole
                // 256-entry transfer completes; BG remains valid throughout
                // this ownership window on the PCB.
                OIBDIR <= 1'b0;
                OBUSRQ <= 1'b0;
                dma_pending <= 1'b0;
            end else if ((dma_pending || !ODMARQ) && OIBDIR) begin
                OBUSRQ <= 1'b0;
            end else if (!OIBDIR) begin
                OBUSRQ <= 1'b0;
            end

        end
    end

    // Extended Y to 9 bits for calculation logic
    wire [8:0] sprite_y = {1'b0, VPD};

    // Global/cocktail reverse must move the 16x16 object's top-left origin as
    // well as reverse its row order.  The external board-compatible relation
    // is y' = 240-y: 240 is the last possible top-left coordinate of a
    // 16-pixel object on a 256-line raster.  This relation is corroborated by
    // the game behavior/MAME renderer; it is not claimed as a recovered
    // internal SG0140 gate equation because no sustained-VREV PCB capture is
    // available yet.
    wire [8:0] sprite_y_eff = VREV ? (9'd240 - sprite_y) : sprite_y;

    // current_y names the physical secondary-list bank being assembled.
    // With WR2 routed to the literal even/odd RAM (rather than the former
    // normalized-phase opposite bank), the descriptor crosses two physical
    // line boundaries: U151/U152 secondary-list build-to-read, followed by
    // U181-U184 pixel-line write-to-display. Visibility and VMT must therefore
    // describe current_y+2. Keep the WR2 bank choice below on current_y[0];
    // using display_y parity there would write through SORT48's live address.
    wire [8:0] display_y = current_y + 9'd2;
    wire [8:0] diff_y = display_y - sprite_y_eff;
    
    // VPD!=0 is a non-PCB compatibility heuristic. The complete 256-entry
    // refresh prevents stale U141 snapshot data, but a freshly copied all-zero
    // CPU slot can still assert OBJEN_3 in the current inferred enable model.
    // MAD leaves such slots behind; admitting them fills the 48-entry list at
    // Y=0 and breaks stock/MAD frames. Physical MATCHV padding protects the
    // downstream secondary list; it does not identify unused primary slots.
    // Keep this until the physical unused-slot or object-enable rule is
    // recovered. It currently excludes a legitimate enabled object at Y=0.
    wire visible = (diff_y < 9'd16) && (VPD != 8'h00);
   
    // Current inferred global/per-object vertical-reverse equation.  The pins
    // are physical, but the XOR and complemented-row update phase still need a
    // joint VPD/VMT/flip capture to be called recovered SG0140 behavior.
    wire screen_flip = VREV ^ VREVD_2;

    // RDCLK edge detector for the physical transfer aperture. RDCLK is carried
    // as a one-master-clock JTFrame enable, so its low interval is longer than
    // the square-wave PCB pin. Only the ordering is significant here: assert
    // during low, write once, then let SORT48 advance on the following rise.
    reg rdclk_d;
    reg over256_d;
    reg padding_active;
    wire rdclk_rise = (rdclk_d == 1'b0) && (RDCLK == 1'b1);
    wire rdclk_fall = (rdclk_d == 1'b1) && (RDCLK == 1'b0);
    wire over256_rise = !over256_d && OVER256;
    wire over256_fall = over256_d && !OVER256;

    // This OVER256 input is OBJDMA's registered-U141 timing facade, not raw
    // U148 /Q. OBJDMA keeps it high through descriptor 255's WR2-to-U151/U152
    // capture, then retires it on an RDCLK rise. Keep one local history bit to
    // suppress the priming tuple and detect that compensated boundary. The
    // following RDCLK fall starts padding with PLD24 MATCHV=1, while a visible
    // terminal descriptor was already stored with MATCHV=0.
    wire list_phase = ~SDTS & over256_d;
    wire scan_phase = list_phase & OVER256;

    always @(posedge clk) begin
        rdclk_d <= RDCLK;
        over256_d <= OVER256;
        if (rst) begin
            rdclk_d <= 1'b0;
            over256_d <= 1'b0;
            VFIND <= 1'b1;
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
            VMT <= 4'h0;
            padding_active <= 1'b0;
        end else begin
            // SDTS is outside the per-line discovery phase. A new live
            // OVER256 window similarly closes any completed padding phase.
            if (SDTS || over256_rise) begin
                VFIND         <= 1'b1;
                EVNWR2        <= 1'b1;
                ODDWR2        <= 1'b1;
                VMT           <= 4'h0;
                padding_active <= 1'b0;
            end else begin
                // Release the active-low RAM strobe only after its RDCLK-low
                // aperture. SORT48 observes the still-low VFIND on this same
                // rise and advances the physical build address afterwards.
                if (rdclk_rise) begin
                    EVNWR2 <= 1'b1;
                    ODDWR2 <= 1'b1;
                    if (!padding_active)
                        VFIND <= 1'b1;
                end

                // OVER256 falling changes PLD24 MATCHV to one. Hold VFIND low
                // across the fill tail; WR2 still pulses once per RDCLK-low
                // phase. OVER48 stops writes, but captures allow VFIND to stay
                // low until the next scan window begins.
                if (over256_fall && !OVER48) begin
                    padding_active <= 1'b1;
                    VFIND          <= 1'b0;
                end

                if (OVER48) begin
                    EVNWR2 <= 1'b1;
                    ODDWR2 <= 1'b1;
                    VFIND  <= padding_active ? 1'b0 : 1'b1;
                end else if (rdclk_fall) begin
                    // U141 is synchronous FPGA RAM. Its pre-advance output is
                    // valid on this edge; consume it before the nonblocking
                    // U141 update becomes visible. Once scanning terminates,
                    // the same cadence writes invalid padding instead.
                    if (scan_phase && visible && OBJEN_3) begin
                        VFIND <= 1'b0;
                        VMT   <= screen_flip ? ~diff_y[3:0] : diff_y[3:0];

                        // current_y is the next physical raster row being
                        // assembled. Sheet 15 hard-wires EVNWR2 to U151/EA
                        // and ODDWR2 to U152/OA; SORT48 selects which address
                        // bus carries its sequential build slot.
                        if (current_y[0])
                            ODDWR2 <= 1'b0;
                        else
                            EVNWR2 <= 1'b0;
                    end else if (padding_active || over256_fall) begin
                        VFIND <= 1'b0;
                        VMT   <= 4'h0;
                        if (current_y[0])
                            ODDWR2 <= 1'b0;
                        else
                            EVNWR2 <= 1'b0;
                    end else begin
                        VFIND  <= 1'b1;
                        EVNWR2 <= 1'b1;
                        ODDWR2 <= 1'b1;
                        VMT    <= 4'h0;
                    end
                end
            end
        end
    end

endmodule
