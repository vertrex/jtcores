// Secondary DMA triggered by objdma when sprite match  

//Write sprite info to one line 
//or the other , 
//when one is read alternatively via sg0140 / objdma 
//

module SCNDDMA(
    input          clk,
    input   [10:2] FDA,     //F data addr 
    input    [3:0] VMT,     //? 
    input          ODH,     // ? 
    input          EVNWR2,  //Even Wren 2 
    input    [5:0] DMA2_EA, //2DMA even addr 
    input          XOBDIR,  //x object dir 
    input          D1V_2,  
    input    [5:0] DMA2_OA, //2DMA object addr  
    input          ODDWR2,  //Odd Wren 2 
    input          RAM2VLD, // Ram 2 
    input          RDCLK,   //R data clock 
    input          H1,     //hpos[0] 
    input          OIBDIR, // Object IB direction 
    input    [8:0] ND2,
    input   [15:9] OBJ_DB,//Object Data bus 
    input          SPR2_2, //Spr2 2 
    input          SPR1_2, //spr1 2 
    input          MATCHV, 
    //output 
    output  [15:0] OVD,   //Object Valida? data 
    output   [3:0] VA,    //V? addr 
    output         NOOBJ,  //No Object 
    output         ODHREV, //Object Data H reverse  
    output         SPR1_3, //Sprite 1 _3 
    output         SPR2_3  //Sprite 2 _3 ?
);

wire [8:1] CTA;
wire [15:0] q_even;
wire [15:0] q_odd;
wire        find_even;
wire        find_odd;
wire [7:0]  cta_rd = (CTA[8:1] >= 8'd1) ? (CTA[8:1] - 8'd1) : 8'd0;
reg         d1v_2_d;
reg         xobdir_d;
reg         scan_even_bank_r = 1'b0;
reg         even_clr_n = 1'b1;
reg         odd_clr_n  = 1'b1;

always @(posedge clk) begin
  d1v_2_d   <= D1V_2;
  xobdir_d  <= XOBDIR;
  even_clr_n <= 1'b1;
  odd_clr_n  <= 1'b1;

  // Seed the display bank when read mode starts.
  if (xobdir_d && !XOBDIR)
    scan_even_bank_r <= D1V_2;

  if (d1v_2_d != D1V_2) begin
    // D1V_2 is the live display-line parity select. In hardware it flips at
    // line boundaries while XOBDIR remains in read mode for the whole visible
    // phase. If we only update on XOBDIR entry, the consume side keeps reading
    // the previous line's bank and repeats the same sprite row every other
    // scanline.
    scan_even_bank_r <= D1V_2;

    // D1V_2 selects the bank currently being scanned for display. Clear the
    // opposite bank here so VCHECK can rebuild it on the next list-build pass.
    if (D1V_2)
      odd_clr_n <= 1'b0;
    else
      even_clr_n <= 1'b0;
  end
end
// XXX IT'S a 6091 B pin are different than 6091 
// 64 obj EVEN 
sis6091B #(
  .ADDR_W(6),
  .GLOBAL_USED_CLEAR(1'b1),
  .WR_CEN_ACTIVE_LOW(1'b1)
) u_151(
  .clk(clk),
  .wr_cen(EVNWR2), // EVNWR2 active-low; sis6091B writes when wr_cen==0
  .we(1'b1), //30 // &RDCLK
  .clr_n(even_clr_n),
  .data({SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], FDA[10:3]}), //6,7,8,10,12-19,22-25
  .addr({4'b0, DMA2_EA[5:0]}),                                // 62-71
  .rd_cen(~XOBDIR), //73
  //.q({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .find(find_even),
  .q(q_even)//42-56
);
//XXX where goes XOBDIR ? DIY_2 ? check on other sis6901 if it's sometime used
//?

//64 obj ODD 
// store at oa/ea ? 
// addr + vmt ? match y ? + odh + sprite 
// output addr to next chips 

// XXX IT'S A SIS6091B !!! pin are different than SIS6091 ! 
//XXX create a bus arbitrer for output ! 
 
sis6091B #(
  .ADDR_W(6),
  .GLOBAL_USED_CLEAR(1'b1),
  .WR_CEN_ACTIVE_LOW(1'b1)
) u_152(
  .clk(clk),
  .wr_cen(ODDWR2), // ODDWR2 active-low; sis6091B writes when wr_cen==0
  .we(1'b1),
  .clr_n(odd_clr_n),
  .data({SPR2_2, SPR1_2, ODH, MATCHV, VMT[3:0], FDA[10:3]}), 
  .addr({4'b0, DMA2_OA[5:0]}),
  .rd_cen(~XOBDIR),
//  .q1({SPR2_3,SPR1_3, ODHREV, NOOBJ,VA[3:0], CTA[8:1]}) //42-56
  .find(find_odd),
  .q(q_odd)
);

// The bank being rebuilt by VCHECK is the opposite of the bank currently being
// scanned for display. Freeze only the bank choice for one whole read phase.
// Re-registering q/find adds an extra read-slot delay and turns one valid slot
// into stale repeated slots across the scan.
wire [15:0] q_sel = scan_even_bank_r ? q_even : q_odd;
wire slot_found = scan_even_bank_r ? find_even : find_odd;
wire read_is_sentinel = scan_even_bank_r ? (DMA2_EA == 6'h3f) : (DMA2_OA == 6'h3f);
wire slot_valid = slot_found && !read_is_sentinel;

// When SORT48 points at the sentinel slot (63) or the list RAM says the slot
// is unused, do not forward any stale CTA/VA/priority bits into LINECUNT.
// Keeping only NOOBJ high is not enough: stale CTA continues to fetch old RAM2
// entries, which retriggers the same sprite burst over and over across the line.
wire [15:0] q_active = slot_valid ? q_sel : 16'h1000;
wire q_noobj_n;
assign {SPR2_3,SPR1_3, ODHREV, q_noobj_n, VA[3:0], CTA[8:1]} = q_active;
assign NOOBJ = q_noobj_n;

// 256addr for obj ? 
// store at FDA => nd2, obj (graphical data?)
// retrieve at CTA, H[1]
sis6091 u_153(
  .clk(clk),

  .wr_cen(~RDCLK), //RAM2VLD ???? 
  .wr_en(~RAM2VLD), //RDCLK ????   //~OIBIDR ? write tor ram ?
  .wr_data({OBJ_DB[15:9] , ND2[8:0]}), 
  .wr_addr({1'b0, FDA[10:2]}),

  .rd_cen(OIBDIR), //OIBDIR always up except 1 time per frame during dma  
  // H1 phase selects which packed RAM2 word fragment is presented to LINECUNT.
  // Current live MAD evidence is:
  // - CTLT1 happens while H1=0 and must see the HPOS word
  // - CTLT2 happens while H1=1 and must see the char/index word
  // so the RAM2 phase bit must be inverted here.
  .rd_addr({1'b0, cta_rd[7:0], ~H1}),
  .rd_data({OVD[15:0]}) //XXX THIS WHERE DATA to create address is send is it blocked or have wrong data ?
);
//OIBIDR ?

endmodule
