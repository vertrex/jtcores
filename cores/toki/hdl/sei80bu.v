////////// sei80bu  ///////////////////////////////
//
// sei80bu decrypt the z80 encrypted rom
// address is used as key to decrypt for rom data
// decrypt rom opcode if m1 high or data if m1 low
//
module sei80bu(
  input             clk, //original clock is 14.13mhz 
  input             N1H, // 3Mhz 
  input             N6M, // 6Mhz 
  input      [15:0] z80_rom_addr,
  input       [7:0] z80_rom_data,
  input             z80_m1,

  input             z80_rom_ok, //? 
  input             z80_rom_cs_n, //rom_cs_n 

  output reg  [7:0] decrypt_rom_data,
  //output reg      decrypt_rom_ok, // XXXX ? 
  input             oki_cen, // XXX 
  output            PRCLK1,
  output            CLK_3_6
);

///////// Z80 CLOCK /////////////////////////////
//
// Generate 3.579545 MHz clock
//
jtframe_cen3p57 u_fmcen(
    .clk(clk),      // 48 MHz
    .cen_3p57(CLK_3_6),
    .cen_1p78()
);

//divive clk by 48 for PRCKL1 ? 
assign PRCLK1 = oki_cen;
  // --- Logique combinatoire du décryptage ---
  reg [7:0] decrypted_next;

  always @* begin
    decrypted_next = z80_rom_data;

    // Bit 7 et 6
    decrypted_next[(z80_m1 && (z80_rom_addr[11] & ~z80_rom_addr[6])) ? 6 : 7] =
        (z80_rom_addr[9] & z80_rom_addr[8]) ? z80_rom_data[7] ^ 1'b1 : z80_rom_data[7];

    decrypted_next[(z80_m1 && (z80_rom_addr[11] & ~z80_rom_addr[6])) ? 7 : 6] =
        (z80_rom_addr[11] & z80_rom_addr[4] & z80_rom_addr[1]) ? z80_rom_data[6] ^ 1'b1 : z80_rom_data[6];

    // Bit 5 et 4
    decrypted_next[(z80_m1 && (z80_rom_addr[12] & z80_rom_addr[9])) ? 4 : 5] =
        (z80_m1 && (~z80_rom_addr[13] & z80_rom_addr[12])) ? z80_rom_data[5] ^ 1'b1 : z80_rom_data[5];

    decrypted_next[(z80_m1 && (z80_rom_addr[12] & z80_rom_addr[9])) ? 5 : 4] =
        (z80_m1 && (~z80_rom_addr[6] & z80_rom_addr[1])) ? z80_rom_data[4] ^ 1'b1 : z80_rom_data[4];

    // Bit 3 et 2
    decrypted_next[z80_rom_addr[8] & z80_rom_addr[4] ? 2 : 3] =
        (z80_m1 && (~z80_rom_addr[12] & z80_rom_addr[2])) ? z80_rom_data[3] ^ 1'b1 : z80_rom_data[3];

    decrypted_next[z80_rom_addr[8] & z80_rom_addr[4] ? 3 : 2] =
        (z80_rom_addr[11] & ~z80_rom_addr[8] & z80_rom_addr[1]) ? z80_rom_data[2] ^ 1'b1 : z80_rom_data[2];

    // Bit 1 et 0
    decrypted_next[(z80_rom_addr[13] & z80_rom_addr[4]) ? 0 : 1] =
        (z80_rom_addr[13] & ~z80_rom_addr[6] & z80_rom_addr[4]) ? z80_rom_data[1] ^ 1'b1 : z80_rom_data[1];

    decrypted_next[(z80_rom_addr[13] & z80_rom_addr[4]) ? 1 : 0] =
        (~z80_rom_addr[11] & z80_rom_addr[9] & z80_rom_addr[2]) ? z80_rom_data[0] ^ 1'b1 : z80_rom_data[0];
  end

  // --- Latch synchrone (comme un 74LS373 ou 273) ---
  always @(posedge clk) begin
    //if (CLK_3_6) begin
      if (!z80_rom_cs_n && z80_rom_ok) begin
        decrypt_rom_data <= decrypted_next;
    end
  //end
end

endmodule
