// Sheet-14 U1411 SG0140 VCHECK operating mode: object-bus arbitration,
// vertical visibility checking, sprite-row generation and even/odd secondary-
// list write control.
//
// PCB captures prove that the selected physical list receives exactly 48 WR2
// transfers per line: visible descriptors first, followed by invalid padding
// until SORT48 reaches OVER48. This behavioral model instead emits one
// active-low VFIND/WR2 pulse for each admitted descriptor. SORT48 still exposes
// the recovered physical 16..63 address window; unwritten rows are suppressed
// by the FPGA validity epoch in obj_secondary_list_bridge.v. The sparse pulse
// protocol below is not claimed as recovered SG0140 logic.
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
  output reg        VFIND   // pin 5: physical active-low level; behavioral RTL uses a pulse
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
    
    // VPD!=0 is a non-PCB compatibility heuristic: the FPGA epoch-valid gate
    // rejects stale/unwritten U141 entries, but a freshly copied all-zero CPU
    // slot can still assert OBJEN_3 in the current inferred enable model. MAD
    // leaves such slots behind; admitting them fills the 48-entry list at Y=0
    // and breaks stock/MAD frames. Keep this until the physical unused-slot or
    // object-enable rule is recovered. It currently excludes legitimate Y=0.
    wire visible = (diff_y < 9'd16) && (VPD != 8'h00);
   
    // Current inferred global/per-object vertical-reverse equation.  The pins
    // are physical, but the XOR and complemented-row update phase still need a
    // joint VPD/VMT/flip capture to be called recovered SG0140 behavior.
    wire screen_flip = VREV ^ VREVD_2;

    // RDCLK edge detector for single-cycle strobes
    reg rdclk_d;
    reg over256_d;
    wire rdclk_fall = (rdclk_d == 1'b1) && (RDCLK == 1'b0);

    // Current sparse-admission build gate. It is not the physical WR2 padding
    // protocol: PCB captures also show WR2 transfers in the terminal/padding
    // interval. U141's registered FPGA read output trails the FDA/OVER256 chain
    // by one system clock, so delay only this gate to suppress the priming tuple
    // while retaining entry 255. The PCB RAM has no registered-output delay.
    wire list_phase = ~SDTS & over256_d;

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
        end else begin
            // Defaults (inactive)
            VFIND  <= 1'b1;
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;

            // U141 is synchronous FPGA RAM.  Its pre-advance output is valid
            // on the clock that detects RDCLK falling; U141 advances to the
            // next entry through a nonblocking update on that same clock.
            // Consume the current entry here before the new value is visible.
            if (list_phase && rdclk_fall) begin
                if (visible && OBJEN_3 && !OVER48) begin
                    VFIND <= 1'b0;
                    VMT   <= screen_flip ? ~diff_y[3:0] : diff_y[3:0];

                    // current_y is the next physical raster row being
                    // assembled. Sheet 15 hard-wires EVNWR2 to U151/EA and
                    // ODDWR2 to U152/OA; SORT48 puts its sequential build
                    // address on EA for an even row and OA for an odd row.
                    // The former opposite selection only worked with the
                    // normalized-H/V compatibility phase: under literal V1B
                    // it wrote through SORT48's display/read address and
                    // collapsed many matches onto the same few RAM slots.
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
