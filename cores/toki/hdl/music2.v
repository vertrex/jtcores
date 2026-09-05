module music2
(
    input           clk,
    input           rst, //SYS_RESET
    // Z80 
    output          SRDB,
    output          SWRB, 

    //PLD238 
    output          SEL6295, 

    // SEI080BU 
    input           N1H,
    input           N6M, 

    input           MUSIC, 
    input           MWRLB,
    input           MRDLB,
    input   [3:1]   MAB,
    input   [7:0]   MDB_CPU_OUT,
    output  [7:0]   MDB_IN,
    input           IRQ3812,
    input           COIN1,
    input           COIN2, 
    output          COUNTER1,
    output          COUNTER2, 
    output          CS3812,
    //74HC74
    output          CLK_3_6, 
    output          PRCLK1,
    output          SA_0, 
    output   [7:0]  SD_OUT,
    input    [7:0]  MUSIC1_SD_IN,

    input             oki_cen, // 1 MHz enable generated from cfg/mem.yaml
    /// ROM 
    input       [7:0] z80_rom_data,
    output     [12:0] z80_rom_addr,

    input       [7:0] bank_rom_data,
    output     [15:0] bank_rom_addr,
    output            bank_rom_cs_n
);



///////// Z80 CPU  /////////////////////// 
// 
//
//
wire [7:0] SD_IN;
wire z80_iorq_n;

wire RFSH_n;
wire Z80_INT;
wire [15:0] SA;

assign SA_0 = SA[0];
assign z80_rom_addr = SA[12:0];
assign bank_rom_addr[15:0] = {BANK_SELECTED, SA[14:0]};

jtframe_z80 u_z80(
    .clk(clk),
    .cen(CLK_3_6),
    .rst_n(~rst),

    .wait_n(1'b1),
    .int_n(Z80_INT), //DRIVE BY CONTROLER PIN 23  // sound interrupt
    .nmi_n(1'b1),
    .busrq_n(1'b1),

    .m1_n(z80_m1_n),
    .mreq_n(z80_mreq_n),
    .iorq_n(z80_iorq_n),
    .rd_n(SRDB), 
    .wr_n(SWRB),
    .rfsh_n(RFSH_n), //ram refresh
    .halt_n(), 
    .busak_n(),

    .A(SA[15:0]),

    .din(SD_IN),
    .dout(SD_OUT)
);

///// PLD 23 //////////////////////////
//
//  Chip select 
//
wire irq_ack_n;
wire SEI0100_CS_N, SEI0100_Z80_DATA_OE_N, z80_ram_cs_n, z80_rom_cs_n;

pld23 pld23_u(
  .SA_3(SA[3]),
  .SA_13(SA[13]),
  .SA_14(SA[14]),
  .SA_15(SA[15]),
  .MEMRQ_n(z80_mreq_n),
  .IORQ_n(z80_iorq_n),
  .RD_n(SRDB),
  .RFSH_n(RFSH_n),
  .M1_n(z80_m1_n),

  .SEI0100_CS_N(SEI0100_CS_N),
  .SEI0100_Z80_DATA_OE_N(SEI0100_Z80_DATA_OE_N),
  .SEL6295(SEL6295),
  .irq_ack_n(irq_ack_n),
  .bank_rom_cs_n(bank_rom_cs_n),
  .z80_ram_cs_n(z80_ram_cs_n),
  .z80_rom_cs_n(z80_rom_cs_n)
);

////// Z80 RAM  ///////////////////////
//
//  2kx8bits ram  (2048)
//
wire [7:0] RAM_SD_OUT;

jtframe_ram #(.AW(11)) u_z80_cpu_ram(
    .clk(clk),
    .cen(CLK_3_6),
    .data(SD_OUT[7:0]),
    .addr(SA[10:0]),  //z80_addr 
    .we(~z80_ram_cs_n & ~SWRB), //PLD23 19
    .q(RAM_SD_OUT[7:0])
);

///// SEI0100BU ////////////////////////////
//
// 2151/5205 controller 
// YM3931 (SDIP64)
wire [7:0] SEI0100_SD_IN;

wire BANK_SELECTED;

sei0100bu sei0100bu_u(
  .clk(clk),
  .rst(rst),
  .MUSIC(MUSIC),
  .MWRLB(MWRLB),
  .MRDLB(MRDLB),
  .MAB(MAB),  
  .MDB_OUT(MDB_CPU_OUT),
  .MDB_IN(MDB_IN),
  .irq_ack_n(irq_ack_n),
  .IRQ3812(IRQ3812),
  .CLK_3_6(CLK_3_6),
  .COIN1(COIN1),
  .COIN2(COIN2),
  .SEI0100_CS_N(SEI0100_CS_N),
  .SWRB(SWRB),
  .SEI0100_Z80_DATA_OE_N(SEI0100_Z80_DATA_OE_N),
  .SA(SA[4:0]),
   // output 
  .COUNTER1(COUNTER1),
  .COUNTER2(COUNTER2),
  .Z80_INT(Z80_INT),
  .CS3812(CS3812),
  .SD_OUT(SD_OUT),
  .SD_IN(SEI0100_SD_IN),
  .BANK_SELECTED(BANK_SELECTED)
); 

// tri-state SD bus on original PCB 
assign SD_IN =  
                 ~CS3812 & ~SRDB                       ? MUSIC1_SD_IN :   
                 ~SEL6295 & ~SRDB                      ? MUSIC1_SD_IN :
                 (~SEI0100_CS_N && ~SEI0100_Z80_DATA_OE_N) ? SEI0100_SD_IN :
                 ~irq_ack_n ? SEI0100_SD_IN :
                 ~z80_ram_cs_n                         ? RAM_SD_OUT:
                 ~bank_rom_cs_n                        ? bank_rom_data :
                 ~z80_rom_cs_n                         ? decrypt_rom_data :
                                                         8'hff;

///////// SEIBU80 //////////
//
// Decypher z80 ROM 8.m3
//
wire [7:0] decrypt_rom_data;

wire       z80_m1_n;   //m1 low => opcode
wire       z80_mreq_n;

sei80bu u_sei80bu(
  .clk(clk),
  .N1H(N1H),
  .N6M(N6M),
  .z80_rom_addr({3'd0, z80_rom_addr}),
  .z80_rom_data(z80_rom_data),
  .z80_rom_cs_n(z80_rom_cs_n),
  .z80_m1(~z80_m1_n),
  .decrypt_rom_data(decrypt_rom_data),
  .oki_cen(oki_cen),
  .PRCLK1(PRCLK1),
  .CLK_3_6(CLK_3_6)
);

endmodule
