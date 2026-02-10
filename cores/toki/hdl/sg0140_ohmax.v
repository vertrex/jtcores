//  “Object H‑position + ROM index latch” for the sprite pipeline.
//  This module acts as a specialized latch and demultiplexer
//
//  1. Latch the sprite X position (OH) from the object list entry, so the SEI0060BU can generate pixel addresses.
//  2. Latch the ROM address fragment (ADDR) for the sprite tile line fetch.
//  3. Latch the “no‑object” mask (NOOBJ_CT2) so downstream OBJ serializer knows if pixels should be output or masked.

//  This is a two‑phase latch, driven by CTLT1/CTLT2.
//  OVD (Object Video Data) is a multiplexed bus that carries different data in each phase.

module sg0140_ohmax(
    input            clk,      // Clock: System clock (e.g., 48MHz) for synchronous operations.
    input            rst,      // Reset: Global reset signal (e.g., RESETA) for module initialization.
    
    input            NOOBJ,    // Input: Sprite validity flag from SCNDDMA. 
                               // Typically active high for 'no object' or active low for 'object found'.
                               // Indicates if the current sprite slot is active.
    input      [8:4] OVD,      // Input: 5-bit slice of Object Video Data from SCNDDMA. 
                               // Contains horizontal position bits for the current sprite or ROM index.
    input            HREV,     // Input: Horizontal flip flag. 
    input            CTLT1,    // Input: Control Latch 1 (Active Low). Timing signal for latching OH.
    input            CTLT2,    // Input: Control Latch 2 (Active Low). Timing signal for latching ADDR and NOOBJ_CT2.
   
    output reg [8:4] OH,       // Output: Object X Position (5 Higher bits). Latched during CTLT1. Used by SEI0060BU
    output reg [4:0] ADDR,     // Output: ROM Address Offset. Latched during CTLT2. Combined with linecunt LS174/LS273 to build full index of obj_rom_addr 
    output reg       NOOBJ_CT2 // Output: Synchronized NOOBJ flag (obj valid if low). Latched during CTLT2 for OBJPS (Object Pixel Serializer).
   );

//    XXX is it that or the inverse ? 
//    | Phase | OVD[8:4] meaning |
//    |-------|------------------|
//    | CTLT1 (H1=0) | ROM index bits for the sprite (tile address) |
//    | CTLT2 (H1=1) | X position high bits (OH[8:4]) |

// XXX negedge ?
always @(posedge clk) begin // All operations are synchronized to the falling edge of the clock.
    if (rst) begin // Asynchronous or synchronous reset.
        OH        <= 5'b0;      // Initialize Object Horizontal Position to 0.
        ADDR      <= 5'b0;      // Initialize ROM Address Offset to 0.
        NOOBJ_CT2 <= 1'b0;      // Initialize synchronized NOOBJ flag to inactive/false.
        end
   else begin
       // Phase 1 (CTLT1 low): latch ROM index bits (tile address fragment)
       if (!CTLT1) begin
            ADDR[4:0] <= OVD[8:4];
       end

       // Phase 2 (CTLT2 low): latch X position and NOOBJ
       if (!CTLT2) begin
            // Invert only X position on HREV, do NOT invert ROM index.
            OH[8:4] <= HREV ? ~OVD[8:4] : OVD[8:4];
            NOOBJ_CT2 <= NOOBJ;
       end
       end
    end
   
endmodule
