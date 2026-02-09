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
    input       XSDTS,    // Phase: 0 = DMA/list-build, 1 = display/list-consume
    input       ILD2,     // Display-phase strobe (~SDTS & DLHD)
    input       V1B,      // Line parity (0 even, 1 odd) for ping-pong buffer select
    input       NH2,      // Unused (kept for pin compatibility)
    input       H2,       // Unused (kept for pin compatibility)
    input       H2_2,     // Unused (kept for pin compatibility)
    input [8:4] H,        // Unused (kept for pin compatibility)

    output reg  OVER48,
    output reg  [5:0] DMA2_EA,
    output reg  [5:0] DMA2_OA
);

    // Two independent pointers
    reg [5:0] wr_ptr;
    reg [5:0] rd_ptr;

    // Edge detectors
    reg vfind_d;
    reg ild2_d;
    reg xsdts_d;
    reg rdclk_d;

    wire vfind_fall = (vfind_d == 1'b1) && (VFIND == 1'b0);
    wire ild2_rise  = (ild2_d  == 1'b0) && (ILD2  == 1'b1);
    wire xsdts_rise = (xsdts_d == 1'b0) && (XSDTS == 1'b1);
    wire xsdts_fall = (xsdts_d == 1'b1) && (XSDTS == 1'b0);
    wire rdclk_fall = (rdclk_d == 1'b1) && (RDCLK == 1'b0);

    // From trace analysis: VFIND activity is almost entirely when XSDTS=1,
    // so DMA/list-build phase is XSDTS=1 and display/list-consume phase is XSDTS=0.
    wire dma_phase   = (XSDTS == 1'b1);
    wire disp_phase  = (XSDTS == 1'b0);

    // Pointer control
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= 6'd0;
            rd_ptr   <= 6'd0;
            OVER48   <= 1'b0;
            vfind_d  <= 1'b1;
            ild2_d   <= 1'b0;
            xsdts_d  <= 1'b0;
            rdclk_d  <= 1'b0;
        end else begin
            vfind_d <= VFIND;
            ild2_d  <= ILD2;
            xsdts_d <= XSDTS;
            rdclk_d <= RDCLK;

            // Reset pointers at phase boundaries
            if (xsdts_rise) begin
                // Enter DMA/list-build phase (XSDTS: 0 -> 1)
                wr_ptr <= 6'd0;
                OVER48 <= 1'b0;
            end
            if (xsdts_fall) begin
                // Enter display/list-consume phase (XSDTS: 1 -> 0)
                rd_ptr <= 6'd0;
            end

            // Build list: increment on VFIND falling edge
            if (dma_phase && vfind_fall) begin
                if (wr_ptr < 6'd48)
                    wr_ptr <= wr_ptr + 6'd1;
                else
                    OVER48 <= 1'b1;
            end

            // Consume list: increment on ILD2 rising edge
            if (disp_phase && ild2_rise) begin
                rd_ptr <= rd_ptr + 6'd1;
            end
        end
    end

    // Ping-pong output mux, updated on RDCLK falling edge for stability
    always @(posedge clk) begin
        if (rst) begin
            DMA2_EA <= 6'd0;
            DMA2_OA <= 6'd0;
        end else if (rdclk_fall) begin
            if (V1B) begin
                // Odd line: write odd, read even
                DMA2_OA <= wr_ptr;
                DMA2_EA <= rd_ptr;
            end else begin
                // Even line: write even, read odd
                DMA2_EA <= wr_ptr;
                DMA2_OA <= rd_ptr;
            end
        end
    end
endmodule
