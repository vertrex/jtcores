module SCNDDMA(
    input   [10:2] FDA,
    input    [3:0] VMT,
    input          ODH,
    input          EVNMR2,
    input    [5:0] DMA2_EA,
    input          XOBDIR,
    input          DIY_2,
    input    [5:0] DMA2_OA,
    input          ODDWR2,
    input          RAM2VLD,
    input          RDCLK,
    input          H_1,
    input    [9:1] CTA,
    input          OIBDIR,
    input    [8:0] ND2,
    input   [15:9] OBJ_DB,
    //output 
    output  [15:0] OVD,
    output   [3:0] VA,
    output         NOOBJ,
    output         ODHREY, 
    output         SPR1_3,
    output         SPR2_3
);

///////// NOT DRIVEN,  TO DRIVE //////////
assign OVD[15:0] = 16'b0;
assign VA[3:0] = 4'b0;
assign NOOBJ = 1'b0;
assign ODHREY = 1'b0;
assign SPR1_3 = 1'b0;
assign SPR2_3 = 1'b0;

endmodule
