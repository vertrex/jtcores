///////////////////////////////////////////////////
///////////// SG0140 SORT 48///////////////////////
///////////////////////////////////////////////////

// Sprite Display List Management
// acting as the display list  manager for sprites visible on the current scanline
// “horizontal list scheduler / slot mapper” for the per‑line object list.

/* 
    1. Sorting/Stacking: During a dedicated "sorting" or DMA phase (typically during horizontal blanking or a sprite DMA      window), it receives "sprite found" signals (VFIND) from sg0140_vcheck. For each found sprite, it generates a sequential address (like a stack pointer) where the sprite's attributes can be stored in a temporary "display list" RAM. This ensures that sprites are stored in the order they are found (or potentially sorted by priority, though this module just stacks).
    2. Limiting: It enforces a hardware limit of 48 sprites per scanline. If more than 48 sprites are detected as visible, it  signals an overflow (OVER48) so VCHECK stops writing when the list is full
    3. Scanning/Reading: During the active video display phase, it acts as a "scanner," generating addresses based on the horizontal position (H) of the CRT beam. These addresses are used to read the pre-sorted sprite attributes from the display list RAM, feeding them to the pixel generation logic.
    4. Ping-Pong Buffering: It implements a double-buffering (ping-pong) mechanism, typically using two separate RAM banks (Even and Odd). While one buffer is being written to (stacked) for the next scanline, the other is simultaneously being read from (scanned) for the current scanline. This ensures smooth, glitch-free sprite display.
*/

module sg0140_sort48(
    input       clk,      // Master clock
    input       rst,
    input       RDCLK,    // Read clock for list RAMs

    input       VFIND,    // Active-low “sprite found” from vcheck (DMA/list-build phase)
    input       XSDTS,    // From objdma: XSDTS = ~SDTS
    input       ILD2,     // From PLD24: ILD2 = ~SDTS & DLHD (line cadence)
    input       V1B,      // Line parity (0 even, 1 odd) for ping-pong buffer select
    input       NH2,      // Kept for pin compatibility
    input       H2,       // H slot bit
    input       H2_2,     // Kept for pin compatibility
    input [8:4] H,        // H slot bits

    output reg  OVER48,
    output reg  [5:0] DMA2_EA,
    output reg  [5:0] DMA2_OA
);

    // Write pointer for per-line visible-sprite list.
    reg [5:0] wr_ptr;
    // Kept for debug visibility in VCD.
    reg [5:0] rd_ptr;

    // Edge detectors
    reg vfind_d;
    reg ild2_d;
    reg rdclk_d;

    wire vfind_fall = (vfind_d == 1'b1) && (VFIND == 1'b0);
    wire ild2_rise  = (ild2_d  == 1'b0) && (ILD2  == 1'b1);
    wire rdclk_fall = (rdclk_d == 1'b1) && (RDCLK == 1'b0);

    // H-based consume slot (0..63), limited to hardware list depth (48).
    wire [5:0] hslot = {H[8:7], H2, H[6:4]};
    wire [5:0] read_slot = (hslot < 6'd48) ? hslot : 6'd0;

    // Trace-backed: VFIND pulses are in XSDTS=1 phase.
    wire list_phase = (XSDTS == 1'b1);

    // Pointer and overflow control
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= 6'd0;
            rd_ptr   <= 6'd0;
            OVER48   <= 1'b0;
            vfind_d  <= 1'b1;
            ild2_d   <= 1'b0;
            rdclk_d  <= 1'b0;
        end else begin
            vfind_d <= VFIND;
            ild2_d  <= ILD2;
            rdclk_d <= RDCLK;

            // New line: restart list build and clear overflow budget.
            if (ild2_rise) begin
                wr_ptr <= 6'd0;
                OVER48 <= 1'b0;
            end

            // List build: one slot consumed per VFIND pulse.
            if (list_phase && vfind_fall) begin
                if (wr_ptr < 6'd48)
                    wr_ptr <= wr_ptr + 6'd1;
                else
                    OVER48 <= 1'b1;
            end

            if (rdclk_fall) begin
                rd_ptr <= read_slot;
            end
        end
    end

    // Ping-pong address mux:
    // - one RAM port receives write slot (wr_ptr)
    // - the other RAM port receives consume slot (read_slot from H timing)
    always @(posedge clk) begin
        if (rst) begin
            DMA2_EA <= 6'd0;
            DMA2_OA <= 6'd0;
        end else if (rdclk_fall) begin
            if (V1B) begin
                // Odd line: write odd, read even
                DMA2_OA <= wr_ptr;
                DMA2_EA <= read_slot;
            end else begin
                // Even line: write even, read odd
                DMA2_EA <= wr_ptr;
                DMA2_OA <= read_slot;
            end
        end
    end
endmodule
