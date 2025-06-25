module pld19(
    input wire i1, i2, i3, i4, i5, i6, i7, i8, i9, i11, i13, i14, i15, i16, i17, i18,
    output wire o12, o13, o15, o16, o18, o19
);

    // Assignments for combinatorial outputs
    assign o12 = ~(~i1 & ~i2); // /o12 = /i1 & /i2
    assign o13 = ~(i1 & ~i2); // /o13 = i1 & /i2

    // Equation for o15
    assign o15 = ~((~i3 & ~i4 & i5 & ~i6 & ~i7) |
                   (~i3 & i4 & ~i6 & ~i7) |
                   (i3 & ~i4 & ~i5 & i6) |
                   (i3 & ~i4 & ~i5 & ~i6) |
                   (~i4 & ~i5 & ~i6 & ~i7));

    // Equation for o16
    assign o16 = ~((i3 & ~i4 & i5 & ~i6 & ~i7) |
                   (i3 & i4 & ~i6 & ~i7) |
                   (~i3 & ~i4 & ~i5 & i6) |
                   (~i3 & ~i4 & ~i5 & ~i6) |
                   (~i4 & ~i5 & ~i6 & ~i7));

    assign o18 = ~(~i8 & i11); // /o18 = /i8 & i11
    assign o19 = ~(~i8 & i9); // /o19 = /i8 & i9

endmodule
