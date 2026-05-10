//  "Object H-position + ROM index latch" for the sprite pipeline.
//  Two-phase latch, driven by CTLT1/CTLT2 (both active low).
//
//  OVD (Object Video Data) is a multiplexed bus that carries different data
//  in each phase:
//    - CTLT1 phase (H1=0): OVD = CHAR word (tile_lo[11:0] + color[3:0])
//    - CTLT2 phase (H1=1): OVD = HPOS word (X[8:0] + tile_hi)
//
//  Verified by tracing u_153 write addressing:
//    - word 1 (CHAR) at FDA[2:1]=01 → wr_addr LSB=FDA[2]=0 → stored at LSB=0
//    - word 2 (HPOS) at FDA[2:1]=10 → wr_addr LSB=FDA[2]=1 → stored at LSB=1
//  and u_153 read: rd_addr[0]=H1, so CTLT1(H1=0)→LSB=0 CHAR, CTLT2(H1=1)→LSB=1 HPOS
//
//  This module latches:
//    - ADDR[4:0] = CHAR[8:4] = ROM tile index bits (at CTLT1, OVD = CHAR)
//    - OH[8:4]   = HPOS[8:4] = sprite X high bits (at CTLT2, OVD = HPOS)
//    - NOOBJ_CT2 = synced NOOBJ flag (at CTLT2)
//
//  Level-sensitive latching: capture whenever strobe is low. Simpler than
//  edge-based multi-sample; relies on OVD being stable during the strobe's
//  low phase (which is ~4 clk cycles at 48 MHz vs 6 MHz cen, plenty for
//  BRAM settling).

module sg0140_ohmax(
    input            clk,
    input            rst,

    input            NOOBJ,
    input      [8:4] OVD,
    input            HREV,
    input            CTLT1,    // Active low — CHAR phase
    input            CTLT2,    // Active low — HPOS phase

    output reg [8:4] OH,       // Sprite X (high bits)
    output reg [4:0] ADDR,     // ROM tile index bits
    output reg       NOOBJ_CT2 // Sync'd NOOBJ flag
);

always @(posedge clk) begin
    if (rst) begin
        OH        <= 5'b0;
        ADDR      <= 5'b0;
        NOOBJ_CT2 <= 1'b0;
    end else begin
        // CTLT1 phase: OVD = CHAR word
        if (!CTLT1) begin
            ADDR[4:0] <= OVD[8:4];
        end
        // CTLT2 phase: OVD = HPOS word, also sample NOOBJ
        if (!CTLT2) begin
            OH[8:4]    <= HREV ? ~OVD[8:4] : OVD[8:4];
            NOOBJ_CT2  <= ~NOOBJ;
        end
    end
end

endmodule
