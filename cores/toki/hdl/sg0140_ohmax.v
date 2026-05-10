//  "Object H-position + ROM index latch" for the sprite pipeline.
//  Two-phase latch, driven by CTLT1/CTLT2.
//
//  OVD (Object Video Data) is a multiplexed bus that carries different data
//  in each phase:
//    - CTLT1 phase (H1=0): OVD = CHAR word (tile + color)
//    - CTLT2 phase (H1=1): OVD = HPOS word (X coord + tile_hi)
//
//  This module latches:
//    - OH[8:4]  = sprite X position high bits (for SEI0060BU) → latch at CTLT2
//    - ADDR[4:0] = ROM tile address bits (for linecunt rom_index)    → latch at CTLT1
//    - NOOBJ_CT2 = sprite-valid flag (for OBJPS) → latch at CTLT2
//
//  Previous version latched OH at CTLT1 and ADDR at CTLT2 — wrong because
//  that captures CHAR bits into OH (X path) and HPOS bits into ADDR (tile
//  path), producing the "X changes sprite number" bug seen on FPGA.

module sg0140_ohmax(
    input            clk,
    input            rst,

    input            NOOBJ,
    input      [8:4] OVD,
    input            HREV,
    input            CTLT1,    // Active low, latches ADDR at falling edge
    input            CTLT2,    // Active low, latches OH and NOOBJ_CT2

    output reg [8:4] OH,       // Object X position (5 higher bits)
    output reg [4:0] ADDR,     // ROM tile index bits (5 bits)
    output reg       NOOBJ_CT2 // Synchronized NOOBJ flag
);

reg ctlt1_d;
reg ctlt2_d;
wire ctlt1_fall = (ctlt1_d == 1'b1) && (CTLT1 == 1'b0);
wire ctlt2_fall = (ctlt2_d == 1'b1) && (CTLT2 == 1'b0);
wire ctlt1_rise = (ctlt1_d == 1'b0) && (CTLT1 == 1'b1);
wire ctlt2_rise = (ctlt2_d == 1'b0) && (CTLT2 == 1'b1);

// Multi-sample window: CTLT strobes go active before OVD/NOOBJ settle.
// Capture the first real change within the low phase, then ignore later
// bus collapse/noise.
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
            ctlt1_ovd_start <= OVD[8:4];   // CHAR[8:4] = tile_lo[8:4]
        end

        if (ctlt2_fall) begin
            NOOBJ_CT2         <= 1'b0;
            ctlt2_active      <= 1'b1;
            ctlt2_ovd_seen    <= 1'b0;
            ctlt2_noobj_seen  <= 1'b0;
            ctlt2_ovd_start   <= OVD[8:4];   // HPOS[8:4] = X[8:4]
            ctlt2_noobj_start <= NOOBJ;
        end

        // CTLT1 phase: capture CHAR[8:4] into ADDR (tile index bits)
        if (ctlt1_active && (CTLT1 == 1'b0) && !ctlt1_ovd_seen && (OVD[8:4] != ctlt1_ovd_start)) begin
            ADDR[4:0]      <= OVD[8:4];
            ctlt1_ovd_seen <= 1'b1;
        end

        // CTLT2 phase: capture HPOS[8:4] into OH (sprite X high bits)
        if (ctlt2_active && (CTLT2 == 1'b0) && !ctlt2_ovd_seen && (OVD[8:4] != ctlt2_ovd_start)) begin
            OH[8:4]        <= HREV ? ~OVD[8:4] : OVD[8:4];
            ctlt2_ovd_seen <= 1'b1;
        end

        if (ctlt2_active && (CTLT2 == 1'b0) && !ctlt2_noobj_seen && (NOOBJ != ctlt2_noobj_start)) begin
            NOOBJ_CT2      <= ~NOOBJ;
            ctlt2_noobj_seen <= 1'b1;
        end

        if (ctlt1_rise) begin
            if (!ctlt1_ovd_seen)
                ADDR[4:0] <= ctlt1_ovd_start;
            ctlt1_active   <= 1'b0;
            ctlt1_ovd_seen <= 1'b0;
        end

        if (ctlt2_rise) begin
            if (!ctlt2_ovd_seen)
                OH[8:4] <= HREV ? ~ctlt2_ovd_start : ctlt2_ovd_start;
            if (!ctlt2_noobj_seen)
                NOOBJ_CT2 <= ~ctlt2_noobj_start;
            ctlt2_active      <= 1'b0;
            ctlt2_ovd_seen    <= 1'b0;
            ctlt2_noobj_seen  <= 1'b0;
        end
    end
end

endmodule
