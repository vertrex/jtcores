///////////////////////////////////////////////////
///////////// SG0140 SORT 48///////////////////////
///////////////////////////////////////////////////

// Sheet-14 U1412 SG0140 SORT48 operating mode: per-line object-list address
// generation, 48-entry terminal count and even/odd list-bank exchange.
//
// PCB captures prove a physical write counter preloaded to 16, a 16..63 write
// range and a two-half read permutation. They do not recover the exact
// RDCLK/WR2 address-data aperture. The active 0..47 adjacent-pair schedule is
// therefore the last Pocket-hardware-good FPGA compatibility protocol, not a
// claim about the SG0140's internal equations.

/* 
    1. Sorting/Stacking: During a dedicated "sorting" or DMA phase (typically during horizontal blanking or a sprite DMA      window), it receives "sprite found" signals (VFIND) from sg0140_vcheck. For each found sprite, it generates a sequential address (like a stack pointer) where the sprite's attributes can be stored in a temporary "display list" RAM. This ensures that sprites are stored in the order they are found (or potentially sorted by priority, though this module just stacks).
    2. Limiting: It enforces a hardware limit of 48 sprites per scanline. If more than 48 sprites are detected as visible, it  signals an overflow (OVER48) so VCHECK stops writing when the list is full
    3. Scanning/Reading: During the active video display phase, it acts as a "scanner," generating addresses based on the horizontal position (H) of the CRT beam. These addresses are used to read the pre-sorted sprite attributes from the display list RAM, feeding them to the pixel generation logic.
    4. Ping-Pong Buffering: It implements a double-buffering (ping-pong) mechanism, typically using two separate RAM banks (Even and Odd). While one buffer is being written to (stacked) for the next scanline, the other is simultaneously being read from (scanned) for the current scanline. This ensures smooth, glitch-free sprite display.
*/

module sg0140_sort48(
    input       clk,      // Master clock
    input       rst,
    input       RDCLK,    // Physical pin 27 timing input; unused by compact protocol

    input       VFIND,    // Current FPGA protocol: one active-low pulse per admission
    input       XSDTS,    // From objdma: XSDTS = ~SDTS
    input       ILD2,     // From PLD24: ILD2 = ~SDTS & DLHD (line cadence)
    input       V1B,      // Line parity (0 even, 1 odd) for ping-pong buffer select
    input       NH2,      // Physical pin 10; internal qualification unrecovered
    input       H2,       // Compact lane bit; currently normalized hpos[1]
    input       H2_2,     // Second physical H2 pin; internal use unrecovered
    input [8:4] H,        // Current compatibility coordinates hpos[8:4]

    output reg  OVER48,
    output reg  [5:0] DMA2_EA,
    output reg  [5:0] DMA2_OA
);

    reg [5:0] wr_ptr;
    reg [5:0] write_slot;

    reg vfind_d;
    reg ild2_d;

    wire vfind_fall = (vfind_d == 1'b1) && (VFIND == 1'b0);
    wire ild2_rise  = (ild2_d  == 1'b0) && (ILD2  == 1'b1);

    // Current FPGA representation: the two serializers consume adjacent
    // descriptors in each normalized 16-pixel bucket, giving 48 compact slots
    // over the 384-pixel raster.
    //
    // Captured PCB representation, retained here for comparison:
    //   B = raw H[8:4], 8..31
    //   write = 16+i, i=0..47
    //   read  = raw H2 ? B+8 : B+32
    wire list_phase = (XSDTS == 1'b1);
    wire [5:0] read_slot = {H[8:4], H2};
    wire find_event = list_phase && vfind_fall;
    wire admit_find = find_event && !OVER48 && (wr_ptr < 6'd48);
    wire [5:0] write_slot_eff = admit_find ? wr_ptr : write_slot;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= 6'd0;
            write_slot <= 6'd0;
            OVER48   <= 1'b0;
            vfind_d  <= 1'b1;
            ild2_d   <= 1'b0;
        end else begin
            vfind_d <= VFIND;
            ild2_d  <= ILD2;

            // ILD2 is the PCB list-load cadence and rises immediately before
            // the first VFIND of a new scanline. V1B changes much later on
            // crowded boundary lines; resetting there stores the first match
            // at the previous line's slot 0x20, then restarts the list after
            // that descriptor has already been lost.
            if (ild2_rise) begin
                wr_ptr <= 6'd0;
                OVER48 <= 1'b0;
            end

            // The compact equivalent of the physical 16..63 counter admits
            // slots 0..47. Accepting slot 47 raises the terminal level so a
            // candidate 49 cannot publish address 48 or reach SCNDDMA.
            if (admit_find) begin
                write_slot <= wr_ptr;
                wr_ptr <= wr_ptr + 6'd1;
                if (wr_ptr == 6'd47)
                    OVER48 <= 1'b1;
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
