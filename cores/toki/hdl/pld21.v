module PLD21 (
    //seems ok 
    input   [23:17] A,  // Inputs 1 to 7: address[17:23]
    input           MBUSDIR,          // Input 8: MBUSDIR
    input           OBUSDIR,          // Input 9: OBUSDIR
    input           MEMDIR,           // Input 11: MEMDIR

    output          ROM0,            // Output 12: ROM0 (Active low)
    output          ROM1,            // Output 13: ROM1 (Active low)
    output          RAM,             // Output 14: RAM (Active high)
    output          MUSIC,           // Output 15: MUSIC (Active low)
    output          MBUFEN,          // Output 16: MBUFEN (Active high)
    output          MBUFDR,          // Output 17: MBUFDR (Active high)
    output          WRADRS,          // Output 18: WRADRS (Active low)
    output          RDADRS           // Output 19: RDARDS (Active low)
);

    // whole rom 
    //
    // bin(i0x30_000)
    //''0b110000000000000000  everything between 0 and 0  bits 18 and 17 high 
    // but here we check address between 17 & 23 ?? 
    //
    //  0?0000   is start or upper boud / rom 0 start a 0 may be ok 
    //  0?0010  bit 18 hight but not 17 ?  
    // bin(0x60_000)
    // 0b1100000000000000000 bit 19 and 18 high doesn't match ..

    //    bin(int((131072*2)/2)) '0b100000000000000000' ROM 0 is 131072 *2 rom 1 et 2 )
    //    rom 1 is 64k*2 
    //
    //    bin(int((131072*2)/2))
    // '0b100000000000000000
    //1098765432109876543210

    //A[17] hight or low and everyrthing low ! this is OK !!! msbudir lw
    //obusdir low memdir lwo ! (22 should be low too) does that mean 22 should
    //be low if not in the equation  ?
    assign ROM0 = ~(~A[18] & ~A[19] & ~A[20] & ~A[21] & ~A[23] & MBUSDIR & OBUSDIR & MEMDIR);  // /o12

    assign ROM1 = ~(~A[17] & A[18]  & ~A[19] & ~A[20] & ~A[23] & MBUSDIR & OBUSDIR & MEMDIR);   // /o13

    assign RAM =   (A[19] & MBUSDIR & OBUSDIR) 
                 | (~A[17] & ~A[23] & MBUSDIR & OBUSDIR) 
                 | (~A[18] & MBUSDIR & OBUSDIR) 
                 | (A[20] & ~A[23] & MBUSDIR & OBUSDIR) 
                 | (A[21] & MBUSDIR & OBUSDIR) 
                 | (A[23] & MBUSDIR & OBUSDIR); // o14

    assign MUSIC = ~(~A[17] & ~A[18] & A[19] & ~A[20] & ~A[21] & ~A[23] & MBUSDIR & OBUSDIR); // /o15

    assign MBUFEN =   (A[19] & MBUSDIR & OBUSDIR) 
                    | (A[17] & A[21] & ~A[23] & MBUSDIR & OBUSDIR & MEMDIR) 
                    | (~A[17] & ~A[23] & MBUSDIR & OBUSDIR & ~MEMDIR) 
                    | (~A[18] & ~A[23] & MBUSDIR & OBUSDIR & ~MEMDIR) 
                    | (A[21] & ~A[23] & MBUSDIR & OBUSDIR & ~MEMDIR) 
                    | (~A[18] & A[21] & ~A[23] & MBUSDIR & OBUSDIR) 
                    | (A[20] & ~A[23] & MBUSDIR & OBUSDIR) 
                    | (A[23] & MBUSDIR & OBUSDIR); // o16

    assign MBUFDR = ~MEMDIR; // o17

                    //    0?00100  00000000000000000 
                    //  0b0100100  36   0x24  24_0000   + 0x60_000 2a0_000
                    //  0b0000100  4    0x4   0x40 000
                    //
                    //
    assign WRADRS = ~(A[17] & ~A[18] & A[19] & ~A[20] & ~A[21] & ~A[23] & MBUSDIR & OBUSDIR); // /o18
    assign RDADRS = ~(~A[17] & A[18] & A[19] & ~A[20] & ~A[21] & ~A[23] & MBUSDIR & OBUSDIR); // /o19

endmodule

