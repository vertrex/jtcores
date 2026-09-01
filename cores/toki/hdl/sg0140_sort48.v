///////////////////////////////////////////////////
///////////// SG0140 SORT 48///////////////////////
///////////////////////////////////////////////////

// Sheet-14 U1412 SG0140 SORT48 operating mode: per-line object-list address
// generation, 48-entry terminal count and even/odd list-bank exchange.
//
// PCB captures prove a physical 16..63 write range and a two-half read
// permutation. Those recovered package-address equations are implemented
// literally here. The write counter now follows the captured level protocol:
// VCHECK holds VFIND low through an RDCLK-low WR2 aperture, and the address
// advances only on the following RDCLK rise. Exact internal use of NH2/H2_2
// remains unknown, so this is a pin-visible timing model rather than a
// recovered custom-IC netlist.

/* 
    1. Sorting/Stacking: During the per-line list phase it receives VFIND's active-low transfer level from VCHECK. Each visible descriptor, followed by each terminal padding transfer, advances one sequential address in the temporary display-list RAM. Visible descriptors therefore retain discovery order; this mode stacks rather than priority-sorts them.
    2. Limiting: It enforces exactly 48 physical list transfers per scanline. Up to 48 of those can be visible descriptors; VCHECK fills the unused tail with MATCHV=1 words. OVER48 stops both further candidates and padding when the list is full.
    3. Scanning/Reading: During the active video display phase, it acts as a "scanner," generating addresses based on the horizontal position (H) of the CRT beam. These addresses are used to read the pre-sorted sprite attributes from the display list RAM, feeding them to the pixel generation logic.
    4. Ping-Pong Buffering: It implements a double-buffering (ping-pong) mechanism, typically using two separate RAM banks (Even and Odd). While one buffer is being written to (stacked) for the next scanline, the other is simultaneously being read from (scanned) for the current scanline. This ensures smooth, glitch-free sprite display.
*/

module sg0140_sort48(
    input       clk,      // Master clock
    input       rst,
    input       RDCLK,    // Physical pin 27; transfer retires on its rising phase

    input       VFIND,    // Active-low transfer level from VCHECK
    input       XSDTS,    // From objdma: XSDTS = ~SDTS
    input       ILD2,     // From PLD24: active-low pulse; trailing rise resets list
    input       V1B,      // Line parity (0 even, 1 odd) for ping-pong buffer select
    input       NH2,      // Physical pin 10; internal qualification unrecovered
    input       H2,       // Literal raw SEI0050 H2 pin
    input       H2_2,     // Second physical H2 pin; internal use unrecovered
    input [8:4] H,        // Literal raw SEI0050 H16..H256 pins

    output reg  OVER48,
    output reg  [5:0] DMA2_EA,
    output reg  [5:0] DMA2_OA
);

    reg [5:0] wr_ptr;
    reg rdclk_d;
    reg ild2_d;
    reg transfer_pending;
    reg vfind_released;

    wire rdclk_rise = (rdclk_d == 1'b0) && (RDCLK == 1'b1);
    wire ild2_rise  = (ild2_d  == 1'b0) && (ILD2  == 1'b1);

    // Captured PCB representation:
    //   B = raw H[8:4], 8..31
    //   write = 16+i, i=0..47
    //   read  = raw H2 ? B+8 : B+32
    // This divides chronological entries 0..23 into addresses 16..39 and
    // entries 24..47 into addresses 40..63.
    wire list_phase = (XSDTS == 1'b1);
    wire [5:0] read_slot = H2 ? ({1'b0, H[8:4]} + 6'd8) :
                                ({1'b0, H[8:4]} + 6'd32);
    wire transfer_level = list_phase && vfind_released && !VFIND && !OVER48 &&
                          (wr_ptr < 6'd48);
    // The physical package bus advances continuously with the logical
    // 0..48 counter. Its six-bit sum wraps to zero after entry 47; OVER48
    // prevents that wrapped address from being written.
    wire [5:0] write_slot_eff = wr_ptr + 6'd16;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= 6'd0;
            OVER48   <= 1'b0;
            rdclk_d  <= 1'b0;
            ild2_d   <= 1'b0;
            transfer_pending <= 1'b0;
            vfind_released <= 1'b0;
        end else begin
            rdclk_d <= RDCLK;
            ild2_d  <= ILD2;

            // ILD2 is the PCB active-low list-load cadence; its trailing rise
            // occurs immediately before the first new VFIND sequence. V1B
            // changes much later on crowded boundary lines; resetting there
            // stores the first match at the previous line's slot 0x20, then
            // restarts the list after
            // that descriptor has already been lost.
            if (ild2_rise) begin
                wr_ptr <= 6'd0;
                OVER48 <= 1'b0;
                transfer_pending <= 1'b0;
                // Captured VCHECK pins retain the terminal active-low VFIND
                // level through OVER48 and release it shortly after the next
                // list reset. Do not interpret that carried level as entry 0
                // of the new list: first observe VFIND released high once.
                // This is the pin-visible epoch delimiter used in lieu of an
                // unrecovered internal SG0140 reset equation.
                vfind_released <= VFIND;
            end else begin
                if (VFIND)
                    vfind_released <= 1'b1;

                // VFIND becomes visible one FPGA master clock after VCHECK
                // detects RDCLK falling. Arm anywhere inside the represented
                // low aperture, then retire exactly once at the next rise.
                // This keeps write_slot_eff stable while U151/U152 capture
                // their active-low WR2 request.
                if (!RDCLK && transfer_level)
                    transfer_pending <= 1'b1;

                if (!list_phase) begin
                    transfer_pending <= 1'b0;
                end else if (rdclk_rise) begin
                    transfer_pending <= 1'b0;
                    // A full core has several 48 MHz clocks in the represented
                    // RDCLK-low interval, while focused benches may present
                    // only the assertion and retirement edges. VFIND itself
                    // is still low on the retirement edge in both cases, so
                    // accept either the aperture latch or the live level.
                    if (transfer_pending || transfer_level) begin
                        // The logical 0..47 counter produces physical 16..63.
                        // Completing entry 47 raises the terminal level; the
                        // combinational build address then wraps to zero, but
                        // no 49th transfer can be armed.
                        wr_ptr <= wr_ptr + 6'd1;
                        if (wr_ptr == 6'd47)
                            OVER48 <= 1'b1;
                    end
                end
            end
        end
    end

    always @(*) begin
        // V1B selects the bank being built; the other bank is consumed using
        // the H-derived display slot.  Both are combinational because SCNDDMA
        // samples the address on the same edge as WR2/read activity.
        if (V1B) begin
            DMA2_EA = read_slot;
            DMA2_OA = write_slot_eff;
        end else begin
            DMA2_EA = write_slot_eff;
            DMA2_OA = read_slot;
        end
    end
endmodule
