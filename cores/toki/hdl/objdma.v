// Sheet-14 object snapshot DMA and per-line list discovery.
// Standard TTL parts and recovered PLD24 remain explicit; VCHECK/SORT48 are
// inferred custom-IC modes. Physical U141 is replaced by registered FPGA BRAM,
// so the common-clock edge/read phases are FPGA timing accommodations. The
// separate validity plane is timeout-recovery policy, not recovered U141 logic.
// FDA traverses 1,024 16-bit source words = 256 descriptors x four words.
// U149/U1418 select RAM word offsets 0x6c00..0x6fff; CPU-visible byte addresses
// are 0x06d800..0x06dfff (CPU word addresses 0x36c00..0x36fff).
module OBJDMA(
    input             clk,
    input             rst,
    input             STARTV,
    input             VCLK,
    input             RDCLK,
    input             RD_VPOS,
    input      [3:0]  ND1,
    input      [8:4]  ND2,
    input             HREVD_1,
    input             VREVD_1,
    input             SPR1_1,
    input             SPR2_1,
    input             OBJEN_1,
    input             DLHD,
    input             ODMARQ,
    input             OBUSAK,
    input             VORIGIN,
    // Retained wrapper name; literal sheet-14 SEI0050 H counter pins.
    input       [8:0] H_POS,
    input             VREV,
    input             NV256,
    input             H_128, // retained unused compatibility alias of H_POS[7]
    input             H_256, // retained unused compatibility alias of H_POS[8]
    input             V1B,
    //output
    output            MATCHV,
    output            XOBDIR,
    output            RAM2VLD,
    output     [10:1] FDA,
    //output            DMARD,
    output      [3:0] VMT,
    output            EVNWR2,
    output            ODDWR2,
    output            OIBDIR,
    output            OBUSRQ,
    output            OBUSDIR,
    output      [5:0] DMA2_EA,
    output      [5:0] DMA2_OA,
    output            ODH,
    output            SPR1_2,
    output            SPR2_2
);

wire [7:0]VPD;
wire VREVD_2;
wire SDTS, XSDTS;
reg  vclk_d;
wire vclk_rise = VCLK && !vclk_d;

always @(posedge clk) begin
   if (rst)
      vclk_d <= 1'b0;
   else
      vclk_d <= VCLK;
end

// start DMA one time per frame at VBLANK (STARTV) 
// scan whole CPU sprite ram from 0 to 1023 
// Clarification: those are 1024 16-bit words, four words for each of 256
// descriptors. HVPOS decodes them and U141 stores one packed entry per object.
// copy RAM to sis 6091 u191 
// Correction: the sheet-14 snapshot RAM is U141, not U191.
// U142 is physically clocked by the rising edge of SEI0050 VCLK.  VCLK is a
// one-pixel level in the common-clock FPGA model, so a level enable would
// resample STARTV after synchronous PROM26 changes during that same pulse.
// Edge qualification preserves the LS74 old-D ordering of the PCB.
LS74 u142(
   .CLK(clk),
   .CEN(vclk_rise),
   .D(STARTV), // at each frame / vblank 
   .PRE(1'b1),
   .CLR(1'b1),
   .Q(SDTS),
   .QN(XSDTS)
);

wire LSBLD;
wire [1:0] NC2;
reg rdclk_word_d;
wire rdclk_word_rise = RDCLK && !rdclk_word_d;

always @(posedge clk) begin
    if (rst)
        rdclk_word_d <= 1'b0;
    else
        rdclk_word_d <= RDCLK;
end

LS161 u143(
    .clk(clk),
    // U143 is physically clocked by the RDCLK rising edge. Today's RDCLK=N6M
    // caller is already a one-master-clock JTFrame enable; the explicit event
    // also preserves that physical contract if a future caller supplies a
    // stretched level.
    .CEN(rdclk_word_rise),
    .rst(1'b0),
    .CLR_n(XOBDIR),
    .LOAD_n(LSBLD),
    .ENP(1'b1),
    .ENT(1'b1),
    .D({4'b0100}),
    .Q({NC2[1:0], FDA[2:1]}),
    .RCO()
);

wire OBJEN_2;
wire OBJEN_2_RAM;
wire OBJEN_3;
wire MSBLD;
wire MSBET;
wire ILD2;
wire OVER256;
wire VFIND;
wire INSCRN;

// Physical U146 / recovered PLD24.
PLD24 u_pld24(
   .FDA(FDA[2:1]),
   .SDTS(SDTS),
   // Physical RDCLK pin 4 is present, but the recovered JED uses it in no
   // output product term; its omission from PLD24's established port is exact.
   .DLHD(DLHD),
   .OIBDIR(OIBDIR),
   .OVER256(OVER256),
   .INSCRN(INSCRN),
   .OBJEN_2(OBJEN_2),
   .VFIND(VFIND),
///
   .MATCHV(MATCHV), // PLD24 result; not the later SCNDDMA NOOBJ stage
   .OBJEN_3(OBJEN_3),
   .LSBLD(LSBLD),
   .XOBDIR(XOBDIR),
   .RAM2VLD(RAM2VLD),
   .MSBLD(MSBLD), // sampled by U145; it does not parallel-load U147
   .MSBET(MSBET),
   .ILD2(ILD2)
);

wire [1:0] NC;

// during DMA , FDA get set to the right addr 
// data is read from MAB (set to fda) from CPU RAM 
// output of the CPU RAM is parsed by HVPOS 
// HVPOS read each bytes (4 bytes) of info in the dma 
// it preparse the object 
// the result is write in this ram at each frame (dma is activate at end of
// frame) 
// then for each line that buffer that is the copy of the dma is read 
// for each sprite that is read via FDA value (need to check if check well all
// value at read here XXX or that maybe the bug) 
// it check if the sprite colide with the current line 
// if yes sg0140 will send data to the sei60bue that will send it to scnd ma ? 
// that write two sprite ? one ODDWR and one EVNWR ? to DMA2OA DMA2 EA 
// 
// the scndma data is send to the line buffer so the sprite is written in
// the line buffer

// REVIEW CORRECTION: HVPOS decodes four 16-bit source words and U141 stores one
// packed tuple per descriptor. On each raster line VCHECK tests those tuples;
// SORT48 admits at most 48, and EVNWR2/ODDWR2 write the admitted tuples into the
// selected U151/U152 ping-pong list bank. These are line banks, not "two
// sprites". SEI0060 is downstream on sheet 17 after U153 readout, not driven
// directly here.

//what is strange is when does FDA is activated at each line it read only four by four 
//when it's activated by dma it read one by one 
//may  e not that much we we write only a RD_VPOS so each 4 address ..
    //but the address are not the same there is a shift of 1 ?? 



// STORE VPOS and other INFO 
// WHILE HPOS AND OTHER INFOS AS STORED IN 6091 SCNDMA 
// Exact U141 word: {00,OBJEN,SPR2,SPR1,VREV,HREV,INSCRN,VPD[7:0]},
// with INSCRN=ND2[8] and VPD={ND2[7:4],ND1[3:0]}. FDA3..10 select
// the 256 used entries; the two remaining physical address pins are grounded.
sis6091 u_141(
  .clk(clk),
  // FPGA BRAM capture phase; the exact physical SIS6091 write edge is not yet
  // recovered. RD_VPOS selects word 3 of four 16-bit/eight-byte source words.
  .wr_cen(~RDCLK), //clk 31
  .wr_en(~RD_VPOS), //each 4 bytes of DMA when ~OIBIDIR & FDA[2:1] == 1'b11
  // 1 fois par VBL (whole screen)  ecrit les resultats du ma ca prends plusieurs ligne 2/3 
  .wr_addr({2'b0, FDA[10:3]}),
  .wr_data({2'b0, OBJEN_1, SPR2_1, SPR1_1, VREVD_1, HREVD_1, ND2[8:4], ND1[3:0]}),

  // FPGA registered-read phase; do not interpret this as a recovered SIS6091
  // physical read-edge equation.
  .rd_cen(~RDCLK), //RDCLK ???
  // a chaque line, hbl  ca lit pour check avec sg0140 
  // si chaque sprite colisisone avec la ligne courente 
  // pour ca il check el VPD 
  // si le sg0140 colisione il affiche le sprite 
  //
  .rd_addr({2'b0, FDA[10:3]}),
  .rd_data({NC[1:0], OBJEN_2_RAM, SPR2_2, SPR1_2, VREVD_2, ODH, INSCRN ,VPD[7:0]})
);

// U141 is retentive and the PCB refresh runs to the 256-entry terminal count.
// A former FPGA recovery experiment could terminate that DMA early, so it
// paired U141 with an epoch-valid sideband to hide the untouched old tail.
// VCHECK now follows the physical no-timeout ownership contract; expose the
// registered U141 output directly and keep OBJEN's original active-low sense.
assign OBJEN_2 = OBJEN_2_RAM;

/**
*  Obj DMA genreate FDA[10:3] addr to copy obj from cpu ram to sis6091
*/
wire TC;
wire Q_144;

// Physical chain: U144A samples U147 /TC on the RDCLK edge and drives U148B
// /PRE; U145B samples MSBLD on that edge and drives U148B /CLR. Reuse the U143
// edge event for both LS74 halves. This is identical for today's one-clock N6M
// pulse and prevents a future stretched RDCLK from sampling either D twice.

LS74 u144(
    .CLK(clk),
    .CEN(rdclk_word_rise),
    .D(TC),
    .PRE(1'b1),
    .CLR(1'b1),
    .Q(Q_144),
    .QN()
);

wire Q_145;

LS74 u145(
    .CLK(clk),
    .CEN(rdclk_word_rise),
    .D(MSBLD),
    .PRE(1'b1),
    .CLR(1'b1),
    .Q(Q_145),
    .QN()
);

wire Q_148;

// Physical sheet-14 U148B is the following 74LS74 half, used only through its
// asynchronous /PRE and /CLR pins. Keep the literal PCB form here for review:
//
// LS74 u148(
//     .CLK(clk),
//     .CEN(1'b0),
//     .D(1'b0),
//     .PRE(Q_144),
//     .CLR(Q_145),
//     .Q(Q_148),
//     .QN(OVER256)
// );
//
// Cyclone V cannot map both independent asynchronous controls into one native
// flip-flop. Quartus turns that literal block into an untimed latch loop with
// undefined power-up state. Q_144/Q_145 are master-clock-domain levels, so the
// reusable FPGA primitive preserves their live set/clear effect and stores the
// result in a reset-defined register without changing the shared LS74 model.
// Keeping the physical reference in the instance name leaves U148 explicit
// without a Toki-only wrapper around this otherwise generic accommodation.
fpga_async_set_clear #(
    .RESET_Q(1'b0)
) u148_fpga (
    .clk  (clk),
    .rst  (rst),
    .PRE_N(Q_144),
    .CLR_N(Q_145),
    .Q    (Q_148),
    .QN   (OVER256)
);

//74F268 //269 ??? XXX
// REVIEW CORRECTION: U147 is a 74F269. /PE pin 24 is tied high; it counts up,
// MSBET drives /CEP, U148 Q drives /CET, direct RDCLK drives CP, and /TC feeds
// U144A. FDA10:3 is the 0..255 descriptor number; U143 supplies word phase
// FDA2:1, so each U147 increment represents one four-word/eight-byte descriptor.
// DMA COUNTER ? 8bits !
// output fda {FDA[10:3], 2'b11} => {DMARD, MAB[15:1]}
// 256 value au final calculer les addresses reel
// car en sortie des 2 bus driver
ttl_74F269 u147(
    .clk(clk),
    // Sheet 14 U147 pin 24 (/PE) is tied high. MSBLD clocks the
    // surrounding U145/U148 control chain; it does not reload this counter.
    .PE_n(1'b1),
    .U_D(1'b1),
    .CEP_n(MSBET), 
    .CET_n(Q_148),
    .CP(RDCLK), // direct sheet-14 RDCLK net
    .P(8'b0),
    .Q(FDA[10:3]),
    .TC_n(TC)
);

//74LS244P u149 16J
//74LS244P u1418 15J
// imlem in main.v 
//!OIBDIR  ? {1'b0, 6'b011011, FDA[10:1]} : //DMARD =0 p14

// 011011??_????????
// 0x6c00 - 0x6fff = 1024 * 2 (16bits) => 2048 => 1 sis6091 2**10 *2
// !!!>> hex(0b1101100_00000000)
//'0x6c00' !!!
//>>> bin(0x36c00)
//'0b11_01101100_00000000'
//obj_cs     = ~cpu_as_n & (cpu_a[23:1] >= 23'h36c00 && cpu_a[23:1] < 23'h37000);
//impl directly in main.v !  XXX exlain that in MAIN_V !
//assign {DMARD, MAB_OUT[15:1]} = !OIBDIR ? { 6'b011011 , FDA[10:1]} : {16'b0};
//assign DMARD = !OIBDIR ? 1'b0 : 1'b1; //z ?

// REVIEW CORRECTION: U149 buffers FDA1..8 to MAB1..8. U1418 buffers FDA9/10
// to MAB9/10; the sheet straps MAB15..11=11011 and DMARD low. Both buffer
// groups are enabled while OIBDIR is low. FPGA tri-state ownership is the
// `main.v` mux `!OIBDIR ? {1'b0,6'b011011,FDA[10:1]}`. CPU RAM uses only
// MAB15:1, so 0x6c00..0x6fff are RAM word offsets (1,024x16=2 KiB), while the
// CPU map is byte 0x06d800..0x06dfff / word 0x36c00..0x36fff.

// check if sprite intersect with current line ?
// sprite is 16x16
//
wire OVER48;

//vmt become VA1,VA2, ... which is use in linecunt  as u175_q
//so part of the  entry of rom address   it has 16 value so certainly some
//pixel related value it's the low
//
//in sprite we have rom_index[12:0] *64 so {rom_index[12:0], 000000}  13+6 => 19 we have [19:1] so it look ok

//gfx_rom_addr[19:1] <= rom_index[12:0]*19'd64 + (({11'b0, line_number} - {10'b0, y})*19'd2) + ({17'b0, rom_words_index});
// {rom_index[12:0], 0 0000 0 }  (vmt /va is at the end after vh4 we have only  18:1 on the board as rom is split in two

// the other part we do line_number -y*2 (y is the current pos but we check
// we're more or less at 16 from current line number  and we multiply by 2 so
// we shift by 1
//
// so it's actually :
//
// {rom_index[12:0], 0, line_number-y%16, 0 }
//
// the last 0 is determined by rom_words_index so we now if talke first or
// second so last byte is rom_words_index
//
// {rom_index[12:0], 0, line_number-y%16, rom_words_index  }
// then we have a *32 because before the two rom a consecutive and we need to
// choose which one here is
// bin(32)
 // '0b1 0000 0'
 //  so it's the lacking bit
 //  {rom_index[12:0], rom_words_index, line_number-y%16, rom_words_index }
 //  so THIS SG140 IS TO CALCULATE line_number-y%16 and know which pixel the
 //  line intersect !!!!!!!!!!!!!!!!!!!!!!!!!!!!!! solved !
 //wire VH4 = ~hpos[2] ^ OPSREV;
 //wire VH8 = hpos[3] ^ ~hpos[2] ^ OPSREV;
// {rom_index[12:0], VH8, line_number-y%16, VH4 }
// {rom_index[12:0], VH8, VTM, VH4 }

// {rom_index[12:0], VH8  VTM[3:0]/VA*  , VA4
//  174_q[3:0],ADDR,174_Q[3:0]                    VH8,  0000        0
//  so addr is rom_index
// 174_Q ==  172_Q[0]     171_q[5:0]
//  172_Q[0] + ADDR + 171_Q[5:0]
//  OVD[11]  + addr? + OVD[10:9] OVD[3:0]
//   add is got by an sg0140 by getting OVD
//   original code ram-words[2][15], ram_words[1][11:0]
//   so is OVD ram_words ? OVD is OBJ_DB so is MDA so it's ram_words
//   it's just not [15] bthe other seems to be partially from ram too OVD ...
//   but addr is a different part
//
//  the other
//
//
//
//scndma entry is address of second sg0140 data of first
//so we can see both as a splitted stuff to create
//what is stored in scndma ram


// THIS SG0140 calculate line_number-y%16
// it let know which line of the 16x16 pixel we want
// for that we actually need the pixel Y pos
// and the current line number
// or the current address as it's buffered ?
// do we really get aht or is the calcul here more complexe ????
// in my code to calcualte Y[8:0] I used this code ...
// y[8:0] <= ram_words[3][8:0] + (ram_words[0][3:0] * 8'd16);
// so we do
// {ram_words[0][3:0], 0000} + ram_words[3][8:0] // maybe the low part is only
// needed ?
// so ram-words[0] is ND2 and the other part is ND1 ?
// which make the VPD ? but it lack one bits ... is that over256 or nv256 ?
// {NV256, ND2[], ND1[] }
// then we still need to substract current lione number or address ....
//  does the other sg0140 play a role here ?
// need to check at which moment we get the line number ... via vpos ?
// but never pass sei050bu vpos ... so I don't really get how we know
// our posiution...
//from hvpos ND2 == offset
//
//does that is synchronze to get the line number ?
//it ocund line itself with the @clk, and vclk, vorigin ? sdts ?
//then it cound 4 bits to be able to know which line ?
//and synchronize itself ?
//maybe all the clocking is only to count line

// Current trace/schematic conclusion: this SG0140 mode has no V counter bus
// input. It reconstructs the scan line internally from physical VCLK,
// VORIGIN, NV256 and the list/DMA cadence. Pin 38 receives literal raw H2;
// its exact internal function remains unrecovered.

sg0140_vcheck u1411_sg0140_vcheck(
  .clk(clk),
  .rst(rst),
  .VPD(VPD[7:0]), // {ND2[7:4], ND1[3:0]}; ND2[8] is separate INSCRN
  .ODMARQ(ODMARQ),
  .OBUSAK(OBUSAK),
  .SDTS(SDTS),
  .VORIGIN(VORIGIN),
  .OVER256(OVER256),
  .OVER48(OVER48),
  .VREVD_2(VREVD_2), // vertical-reverse descriptor bit
  .OBJEN_3(OBJEN_3), // active-high eligibility: ~INSCRN & ~OBJEN_2
  .H2(H_POS[1]), // physical pin 38: literal raw H2
  //.SW(1'b0),
  .RDCLK(RDCLK),
  .VCLK(VCLK),
  .VREV(VREV),
  .NV256(NV256),
  //output
  .VMT(VMT[3:0]), // four-bit vertical row / VA result
  .EVNWR2(EVNWR2),
  .ODDWR2(ODDWR2),
  .OIBDIR(OIBDIR),
  .OBUSRQ(OBUSRQ),
  .VFIND(VFIND)
);
//74LS244 u1413 22K
// Sheet 14: VCHECK pin 7 is buffered twice as OIBDIR and OBUSDIR, pin 6 as
// OBUSRQ, and pin 5 as VFIND; pin 8 is NC. /2OE is grounded.
// XXX IMPL THAT out goes tothe counter 269
//assign Y1_4 = (!OE1_n) ? A1_4 : 4'bz;  // Tri-state si OE1_n = 1
// Correction to the exploratory tuple above: U1413 outputs are
// {VFIND, OBUSDIR, OBUSRQ, OIBDIR}; U147 receives RDCLK directly.
//output

// Both nets are non-inverting U1413 outputs driven by the same VCHECK pin 7.
assign OBUSDIR = OIBDIR;

// SORT48's package receives these literal sheet-14 SEI0050 pins. The custom
// model now exposes the captured 16..63/two-half physical address protocol;
// FPGA registered-read compensation remains outside it in SCNDDMA.
sg0140_sort48 u1412_sg0140_sort48(
  .clk(clk),
  .rst(rst),
  //.cen(),
  .RDCLK(RDCLK),
  .VFIND(VFIND),
  .XSDTS(XSDTS),
  .ILD2(ILD2),
  .NH2(~H_POS[1]),
  .V1B(V1B),
  .H2(H_POS[1]),
  .H2_2(H_POS[1]),
  .H(H_POS[8:4]),

  .OVER48(OVER48), //Active high
  .DMA2_EA(DMA2_EA),
  .DMA2_OA(DMA2_OA)
);

endmodule
