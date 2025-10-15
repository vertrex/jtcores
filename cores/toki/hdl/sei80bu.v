////////// sei80bu  ///////////////////////////////
//
// sei80bu decrypt the z80 encrypted rom
// address is used as key to decrypt for rom data
// decrypt rom opcode if m1 high or data if m1 low
//
module sei80bu(
  input             clk,
  input             N1H,
  input             N6M,  
  input      [15:0] z80_rom_addr,
  input       [7:0] z80_rom_data,
  input             z80_m1,

  input             z80_rom_ok, //? 
  input             z80_rom_cs_n, //rom_cs_n 

  output reg  [7:0] decrypt_rom_data,
  output reg        decrypt_rom_ok, // XXXX ? 
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

//assign decrypt_rom_ok = z80_rom_ok;
// work @48 mhz with @(*) not with @(posedge clk) 
//always @(z80_rom_cs, z80_rom_ok) begin
always @(posedge clk) begin 
  if (z80_rom_cs_n == 1'b0  && z80_rom_ok == 1'b1) begin
    decrypt_rom_data[(z80_m1 == 1'b1 &&(z80_rom_addr[11] & ~z80_rom_addr[6])) ? 6 : 7]
                     <= (z80_rom_addr[9] & z80_rom_addr[8])
                         ? z80_rom_data[7] ^ 1'b1
                         : z80_rom_data[7];

    decrypt_rom_data[(z80_m1 == 1'b1 &&(z80_rom_addr[11] & ~z80_rom_addr[6])) ? 7 : 6]
                     <=(z80_rom_addr[11] & z80_rom_addr[4] & z80_rom_addr[1])
                       ? z80_rom_data[6] ^ 1'b1
                       : z80_rom_data[6];

    decrypt_rom_data[(z80_m1 == 1'b1 &&(z80_rom_addr[12] & z80_rom_addr[9])) ? 4 : 5]
                     <= (z80_m1 == 1'b1 && (~z80_rom_addr[13] & z80_rom_addr[12]))
                           ? z80_rom_data[5] ^ 1'b1
                           : z80_rom_data[5];

    decrypt_rom_data[(z80_m1 == 1'b1 &&(z80_rom_addr[12] & z80_rom_addr[9])) ? 5 : 4]
                     <= (z80_m1 == 1'b1 && (~z80_rom_addr[6] & z80_rom_addr[1]))
                           ? z80_rom_data[4] ^ 1'b1
                           : z80_rom_data[4];

    decrypt_rom_data[z80_rom_addr[8] & z80_rom_addr[4] ? 2 : 3]
                    <= (z80_m1 == 1'b1 &&(~z80_rom_addr[12] & z80_rom_addr[2]))
                           ? z80_rom_data[3] ^ 1'b1
                           : z80_rom_data[3];

    decrypt_rom_data[z80_rom_addr[8] & z80_rom_addr[4] ? 3 : 2]
                     <= (z80_rom_addr[11] & ~z80_rom_addr[8] & z80_rom_addr[1])
                           ? z80_rom_data[2] ^ 1'b1
                           : z80_rom_data[2];


    decrypt_rom_data[(z80_rom_addr[13] & z80_rom_addr[4]) ? 0  : 1]
                     <= (z80_rom_addr[13] & ~z80_rom_addr[6] & z80_rom_addr[4])
                           ? z80_rom_data[1] ^ 1'b1
                           : z80_rom_data[1];

    decrypt_rom_data[(z80_rom_addr[13] & z80_rom_addr[4]) ? 1 : 0]
                    <= (~z80_rom_addr[11] & z80_rom_addr[9] & z80_rom_addr[2])
                           ? z80_rom_data[0] ^ 1'b1
                           : z80_rom_data[0];
    decrypt_rom_ok <= 1;
   end
   else if (z80_rom_cs_n == 1'b1 || z80_rom_ok == 1'b0) begin 
     decrypt_rom_ok <= 1'b0;
     decrypt_rom_data = decrypt_rom_data;
     end 
   else if (z80_rom_cs_n == 1'b0 || z80_rom_ok == 1'b1) begin 
     decrypt_rom_ok <= 1'b1;
     decrypt_rom_data = decrypt_rom_data;
     end 
end

endmodule
