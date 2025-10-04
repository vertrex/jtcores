///////// z80 bus mapping  ////////////////////
// z80 
// 0x0000, 0x1fff : rom (decrypted by sei80bu)
// 0x2000, 0x27ff : ram (2048) 8bits SRAM (rw)
// sei0100bu 
// 0x4000, 0x4000 : pending data for 68k (w)
// 0x4001, 0x4001 : irq clear (wo) ?
// 0x4002, 0x4002 : rst10 ack (wo) ?
// 0x4003, 0x4003 : rst18 ack (wo) ?
// 0x4007, 0x4007 : switch bank (wo) 
// 0x4008, 0x4009 : ym3812 read / write  
// 0x4010, 0x4011 : 68k sound latch (ro) 
// 0x4012, 0x4012 : 68k data pending (ro) 
// 0x4013, 0x4013 : coin inserted (ro) 
// 0x4018, 0x4019 : z80 sound latch (wo)
// 0x401b, 0x401b : write coin inserted ? (wo) 
// oki 
// 0x6000, 0x6000 : okim6295 (rw)
// bank rom address 
// 0x8000, 0xffff : bank rom data start (ro)
// if bank switch :
// 0x0000, 0x8000 : bank rom data (starting at 0x2000 from bank file) 
module pld23(
    //XXX list port for info
    input  wire SA_3,
    input  wire SA_13,
    input  wire SA_14,
    input  wire SA_15,
    input  wire MEMRQ_n,
    input  wire IORQ_n,
    input  wire RD_n,
    input  wire RFSH_n,
    input  wire M1_n,

    output wire SEI0100_CS_N, // active-low
    output wire B1, // active-low
    output wire SEL6295, // active-low
    output wire irq_ack_n, // active-low
    output wire bank_rom_cs_n, // active-low
    output wire z80_ram_cs_n, // active-low
    output wire z80_rom_cs_n//two port 7&6 // active-low
    //output wire z80_rom_cs_n_b  // active-low
);

    //    010?_????_????_????
    //    0x4000 - 0x5fff   -> SEI0100BU controller 
    //    effectively all controller value then it switch inside SEI0100BU see 
    //    z80_cs !
    //    SEI0100 CS ! 
    wire t_B0  = (~SA_13) &  SA_14  & (~SA_15) & (~MEMRQ_n) & RFSH_n;
    //    5432_1098_7654_3210
    //    ????_????_????_0???    ?? 
    wire t_B1  = (~SA_3) & (~RD_n); //bit 4 == 0 & wr ?
    //    5432_1098_7654_3210
    //    011?_????_????_????  :  0x6000 / 0x7fff  okim6295
    wire t_SEL6295  =  SA_13  &  SA_14  & (~SA_15) & (~MEMRQ_n) & RFSH_n;
    // 
    wire t_irq_ack_n  = (~IORQ_n) &  (~M1_n);
    //    5432_1098_7654_3210
    //    1???_????_????_???? 
    //    0x8000 - 0xffff  BANK_ROM_CS !
    wire t_B4  =  SA_15  & (~MEMRQ_n) & (~RD_n) & RFSH_n;
    //    5432_1098_7654_3210
    //      10_0000_0000_0000   => 0x2000
    // 0x2000, 0x27ff : ram (2048) 8bits SRAM (rw)
    wire t_B5  =  SA_13  & (~SA_14) & (~SA_15) & (~MEMRQ_n) & RFSH_n;
    //    5432_1098_7654_3210
    //    000?_????_????_????   => 0x2000
    //    < 0x1fff z80_rom_cs_n ! 
    wire t_B6  = (~SA_13) & (~SA_14) & (~SA_15) & (~MEMRQ_n) & (~RD_n) & RFSH_n;
    //wire t_B7  = (~SA_13) & (~SA_14) & (~SA_15) & (~MEMRQ_n) & (~RD_n) & RFSH_n; // same as B6 per JED

    assign SEI0100_CS_N = ~t_B0;
    assign B1 = ~t_B1;
    assign SEL6295 = ~t_SEL6295;
    assign irq_ack_n = ~t_irq_ack_n;
    assign bank_rom_cs_n = ~t_B4;
    assign z80_ram_cs_n = ~t_B5;
    assign z80_rom_cs_n = ~t_B6;
    //assign z80_rom_cs_n_b = ~t_B7;

endmodule
