module PLD21 (
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

    assign ROM0 = ~(~A[18] & ~A[19] & ~A[20] & ~A[22] & ~A[23] & MBUSDIR & OBUSDIR & MEMDIR);  // /o12

    assign ROM1 = ~(~A[17] & A[18]  & ~A[19] & ~A[20] & ~A[23] & MBUSDIR & OBUSDIR & MEMDIR);   // /o13

    assign RAM = (A[19] & MBUSDIR & OBUSDIR) | (~A[17] & ~A[23] & MBUSDIR & OBUSDIR) 
                                             | (~A[18] & MBUSDIR & OBUSDIR) 
                                             | (A[20] & ~A[23] & MBUSDIR & OBUSDIR) 
                                             | (A[22] & MBUSDIR & OBUSDIR) 
                                             | (A[23] & MBUSDIR & OBUSDIR); // o14

    assign MUSIC = ~(~A[17] & ~A[18] & A[19] & ~A[20] & ~A[22] & ~A[23] & MBUSDIR & OBUSDIR); // /o15

    assign MBUFEN = (A[19] & MBUSDIR & OBUSDIR) | (A[17] & A[22] & ~A[23] & MBUSDIR & OBUSDIR & MEMDIR) 
                                                | (~A[17] & ~A[23] & MBUSDIR & OBUSDIR & ~MEMDIR) 
                                                | (~A[18] & ~A[23] & MBUSDIR & OBUSDIR & ~MEMDIR) 
                                                | (A[22] & ~A[23] & MBUSDIR & OBUSDIR & ~MEMDIR) 
                                                | (~A[18] & A[22] & ~A[23] & MBUSDIR & OBUSDIR) 
                                                | (A[20] & ~A[23] & MBUSDIR & OBUSDIR) | (A[23] & MBUSDIR & OBUSDIR); // o16

    assign MBUFDR = ~MEMDIR; // o17

    assign WRADRS = ~(A[17] & ~A[18] & A[19] & ~A[20] & ~A[22] & ~A[23] & MBUSDIR & OBUSDIR); // /o18

    assign RDADRS = ~(~A[17] & A[18] & A[19] & ~A[20] & ~A[22] & ~A[23] & MBUSDIR & OBUSDIR); // /o19

endmodule
