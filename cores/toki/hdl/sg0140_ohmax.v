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

reg ctlt1_d;
reg ctlt2_d;
wire ctlt1_fall = (ctlt1_d == 1'b1) && (CTLT1 == 1'b0);
wire ctlt2_fall = (ctlt2_d == 1'b1) && (CTLT2 == 1'b0);
wire ctlt1_rise = (ctlt1_d == 1'b0) && (CTLT1 == 1'b1);
wire ctlt2_rise = (ctlt2_d == 1'b0) && (CTLT2 == 1'b1);

reg       ctlt1_active;
reg       ctlt2_active;
reg       ctlt1_ovd_seen;
reg       ctlt2_ovd_seen;
reg       ctlt2_noobj_seen;
reg [4:0] ctlt1_ovd_start;
reg [4:0] ctlt2_ovd_start;
reg       ctlt2_noobj_start;

always @(posedge clk) begin
    if (rst) begin
        OH        <= 5'b0;
        ADDR      <= 5'b0;
        NOOBJ_CT2 <= 1'b0;
        ctlt1_d   <= 1'b1;
        ctlt2_d   <= 1'b1;
        ctlt1_active     <= 1'b0;
        ctlt2_active     <= 1'b0;
        ctlt1_ovd_seen   <= 1'b0;
        ctlt2_ovd_seen   <= 1'b0;
        ctlt2_noobj_seen <= 1'b0;
        ctlt1_ovd_start  <= 5'b0;
        ctlt2_ovd_start  <= 5'b0;
        ctlt2_noobj_start <= 1'b1;
    end else begin
        ctlt1_d <= CTLT1;
        ctlt2_d <= CTLT2;

        if (ctlt1_fall) begin
            ctlt1_active    <= 1'b1;
            ctlt1_ovd_seen  <= 1'b0;
            ctlt1_ovd_start <= OVD[8:4];
        end

        if (ctlt2_fall) begin
            NOOBJ_CT2         <= 1'b0;
            ctlt2_active      <= 1'b1;
            ctlt2_ovd_seen    <= 1'b0;
            ctlt2_noobj_seen  <= 1'b0;
            ctlt2_ovd_start   <= OVD[8:4];
            ctlt2_noobj_start <= NOOBJ;
        end

        // Live MAD traces show the CTLT phase strobes go active before the
        // multiplexed OVD/NOOBJ bus settles. Capture the first real change
        // within the low phase, then ignore later bus collapse/noise.
        if (ctlt1_active && (CTLT1 == 1'b0) && !ctlt1_ovd_seen && (OVD[8:4] != ctlt1_ovd_start)) begin
            OH[8:4]        <= HREV ? ~OVD[8:4] : OVD[8:4];
            ctlt1_ovd_seen <= 1'b1;
        end

        if (ctlt2_active && (CTLT2 == 1'b0) && !ctlt2_ovd_seen && (OVD[8:4] != ctlt2_ovd_start)) begin
            ADDR[4:0]      <= OVD[8:4];
            ctlt2_ovd_seen <= 1'b1;
        end

        if (ctlt2_active && (CTLT2 == 1'b0) && !ctlt2_noobj_seen && (NOOBJ != ctlt2_noobj_start)) begin
            NOOBJ_CT2      <= ~NOOBJ;
            ctlt2_noobj_seen <= 1'b1;
        end

        if (ctlt1_rise) begin
            if (!ctlt1_ovd_seen)
                OH[8:4] <= HREV ? ~ctlt1_ovd_start : ctlt1_ovd_start;
            ctlt1_active   <= 1'b0;
            ctlt1_ovd_seen <= 1'b0;
        end

        if (ctlt2_rise) begin
            if (!ctlt2_ovd_seen)
                ADDR[4:0] <= ctlt2_ovd_start;
            if (!ctlt2_noobj_seen)
                NOOBJ_CT2 <= ~ctlt2_noobj_start;
            ctlt2_active      <= 1'b0;
            ctlt2_ovd_seen    <= 1'b0;
            ctlt2_noobj_seen  <= 1'b0;
        end
    end
end
   
endmodule
