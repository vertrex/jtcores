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
    input       clk,      // Clock:  (48MHz)
    input       rst,      // 
    input       RDCLK,    // Read Clock: Used as the timing reference for address outputs.
 
    input       VFIND,    // Input: "Sprite Found" strobe (Active Low) from sg0140_vcheck.
                          //        Indicates a visible and valid sprite attribute is available.
    input       XSDTS,    // Input: Phase Control. (Active Low = DMA/Sorting Phase, Active High = Display/Scan Phase).
                          //        Determines if the module is building the display list or reading it.
    input       ILD2,     // Input: ???
                          // XXX Some per‑slot strobe tied to DMA phase or serializer timing.
                          //    Might be the real “advance slot” pulse.
                          //        Likely a timing or control signal related to DMA, possibly for interlacing.
    input       V1B,      // Input: Vertical Position Bit 0 (LSB of current scanline).
                          //        Used for ping-pong buffering (0=Even Line, 1=Odd Line).
    input       NH2,      // Input: Inverted H_POS[1]. (Used in read_addr generation).
    input       H2,       // Input: H_POS[1]. (Used in read_addr generation).
    input       H2_2,     // Input: H_POS[1] again. (Redundant or for internal fanout/timing on PCB).
    input [8:4] H,        // Input: Higher bits of Horizontal Position (H_POS[8:4]).
                          //        Used for generating the display scan address.
    
    output reg  OVER48,   // Output: "Overflow" flag (Active High). Set if more than 48 sprites are found.
    output reg  [5:0] DMA2_EA, // Output: Address for the Even Secondary DMA buffer.
    output reg  [5:0] DMA2_OA  // Output: Address for the Odd Secondary DMA buffer. 
);
    
    // -------------------------------------------------------------------------
    // 1. Read Address Generation (Scan Mode)
    //    This address is used to read sprite attributes from the secondary DMA
    //    buffer during the active display phase. It is driven by the horizontal
    //    scan position.
    // -------------------------------------------------------------------------
    // The 'read_addr' combines bits of the current horizontal position (H_POS).
    // This forms a sequential scan that reads sprite data as the beam moves across the screen.
    wire [5:0] read_addr = {H[8:7], H2, H[6:4]};
    
    // -------------------------------------------------------------------------
    // 2. Write Address Generation (Stack Mode)
    //    This address acts as a stack pointer, incrementing for each new sprite
    //    found by sg0140_vcheck. It generates sequential addresses to store
    //    sprite attributes in the secondary DMA buffer during the sorting phase.
    // -------------------------------------------------------------------------
    reg [5:0] stack_ptr;      // Internal counter, representing the next available slot in the display list.
    reg vfind_prev;           // Previous state of VFIND, used for edge detection.
    
    always @(negedge clk) begin
        if (rst) begin
            stack_ptr <= 6'b0;      // Reset stack pointer to the beginning of the list.
            OVER48 <= 1'b0;         // Clear the overflow flag.
            vfind_prev <= 1'b1;     // Initialize for VFIND falling edge detection.
            end
        else begin
            vfind_prev <= VFIND; // Capture previous VFIND state.
    
        // Reset the stack pointer when NOT in the DMA/Sorting Phase (XSDTS High).
        // This prepares the stack for building a new list for the next line.
        if (XSDTS) begin
            stack_ptr <= 6'b0;  // Reset stack pointer.
            OVER48 <= 1'b0;     // Clear overflow flag.
            end
        else begin // XSDTS is Low (Active DMA/Sorting Phase)
                   // Detect a falling edge of VFIND, indicating a new visible sprite.
            if (vfind_prev && !VFIND) begin // (vfind_prev == 1 && VFIND == 0)
                                            // Increment the stack pointer for the new sprite.
                if (stack_ptr < 6'd48) begin // Check against the 48-sprite limit.
                    stack_ptr <= stack_ptr + 1'b1;
                end
                else begin
                    //   wire limit = (hslot >= 6'd48);
                    OVER48 <= 1'b1; // Assert overflow flag if limit is reached.
                    end
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Ping-Pong Address Multiplexing
    //    This logic selects which address (stack_ptr or read_addr) goes to
    //    which buffer (Even or Odd) based on the current line's parity (V1B).
    //    It implements the double-buffering scheme:
    //    - While one buffer is being read for display, the other is being written for the next line.
    //    - Based on LINEBUF/SCNDDMA analysis:
    //      - On an Even Line (V1B=0), display reads from Odd Buffer, so write to Even Buffer.
    //      - On an Odd Line (V1B=1), display reads from Even Buffer, so write to Odd Buffer.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin // XXX negedge ?
        //Synchronized address updates with RDCLK for stability.
        if (rst) begin
            DMA2_EA <= 6'b0;
            DMA2_OA <= 6'b0;
            end
        else begin
            // Logic based on V1B (current line parity):
            if (V1B) begin // Current Scanline is Odd (V1B=1)
            // On Odd line, display reads from Even Buffer (DMA2_EA gets read_addr).
            // So, we must write to the Odd Buffer (DMA2_OA gets stack_ptr).
            DMA2_OA <= stack_ptr;   // Output to Odd Buffer address is Stack Pointer (for Writing)
            DMA2_EA <= read_addr;   // Output to Even Buffer address is Read Address (for Reading)
            end
        else begin // Current Scanline is Even (V1B=0)
            // On Even line, display reads from Odd Buffer (DMA2_OA gets read_addr).
            // So, we must write to the Even Buffer (DMA2_EA gets stack_ptr).
            DMA2_EA <= stack_ptr;   // Output to Even Buffer address is Stack Pointer (for Writing)
            DMA2_OA <= read_addr;   // Output to Odd Buffer address is Read Address (for Reading)
            end
        end
    end
endmodule
