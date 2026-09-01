// Sheet-18 dual object line buffer. OBJ1 and OBJ2 write the bank selected by
// EVNWREN/ODDWREN while delayed U161 D1V_7P/ND1V_7P enables the other bank's
// shared OOD/priority outputs. The bank transition is related to HBL timing,
// but sheet 18 selects it through these explicit delayed parity nets.
//
// Sheet-18 line-buffer boundary. Both physical object lanes write their own
// row, X and attribute phases at the four U181-U184 storage positions; the
// FPGA storage mechanism is isolated in sis6091B_atomic.

module LINEBUF(
    input             clk,
    input             ODDWREN,  // active-low pin-30 write enable, U183/U184
    input             EVNWREN,  // active-low pin-30 write enable, U181/U182
    input             OBJ_N6M,  // bubbled SIS6091B pin-31 write phase
    input       [9:0] OBJ1,     // U164A/U166 delayed lane data and attributes
    input       [9:0] OBJ2,     // U164B direct lane data and attributes
    input       [8:0] E1A,      // U181 address pins 62-70
    input             EVNCLR,   // active-low pin-34 clear, U181/U182
    input             D1V_7P,   // active-low output enable for EVEN devices
    input             OBJ_P6M,  // physical read/output phase; presently inert
    input       [8:0] E2A,      // U182 address pins 62-70
    input       [8:0] O1A,      // U183 address pins 62-70
    input             ODDCLR,   // active-low pin-34 clear, U183/U184
    input             ND1V_7P,  // active-low output enable for ODD devices
    input       [8:0] O2A,      // U184 address pins 62-70
    input             OBJ1_Z,   // FPGA: delayed lane was not physically driven
    input             OBJ2_Z,   // FPGA: direct lane was not physically driven
    output            E1FIND,   // U181 pin 60 FIND
    output            E2FIND,   // U182 pin 60 FIND
    output            O1FIND,   // U183 pin 60 FIND
    output            O2FIND,   // U184 pin 60 FIND
    output reg  [7:0] OOD,      // shared SIS pins 42-49
    output reg        PRIOR_C,  // shared SIS pin 51
    output reg        PRIOR_D   // shared SIS pin 53
);

wire [9:0] Q_EVN1;
wire [9:0] Q_EVN2;
wire [9:0] Q_ODD1;
wire [9:0] Q_ODD2;

// Only write active, non-transparent sprite pixels. OBJ1_Z carries U164A's
// qualification through U166's two physical delay stages; OBJ2_Z directly
// represents U164B's output qualification.
wire obj1_pix_valid = (~OBJ1_Z) & (OBJ1[3:0] != 4'hF);
wire obj2_pix_valid = (~OBJ2_Z) & (OBJ2[3:0] != 4'hF);

// FPGA phase adapter for the four physical sheet-18 SIS6091B line stores.
// The tested implementation admits a pixel on the rising OBJ_N6M phase and
// treats each active-low CLR transition as one atomic validity command.  Keep
// those Toki phases here; sis6091B_atomic contains no raster knowledge.
reg obj_n6m_d = 1'b0;
reg evnclr_d  = 1'b1;
reg oddclr_d  = 1'b1;

always @(posedge clk) begin
    obj_n6m_d <= OBJ_N6M;
    evnclr_d  <= EVNCLR;
    oddclr_d  <= ODDCLR;
end

wire line_write_phase = !obj_n6m_d && OBJ_N6M;
wire even_clear_cmd   =  evnclr_d && !EVNCLR;
wire odd_clear_cmd    =  oddclr_d && !ODDCLR;

// OBJ_P6M and ND1V_7P remain in the schematic-mapped LINEBUF interface. The
// former SIS facade's rd_cen input was behaviorally inert, and the exact
// package output-enable truth table is unrecovered, so the FPGA backend does
// not claim either signal as a memory-read control.

// The PCB has no conventional OBJ1/OBJ2 output mux: all four SIS6091B devices
// connect to the pulled-up OOD/PRIOR nets. D1V parity leaves one two-lane bank
// driving those shared nets. Its simultaneous-FIND behavior is opaque, while
// CPU/MAME ordering and the validated single-lane compositor establish global
// first-object-wins priority. The recovered physical SORT48 scan presents
// entry n (0..23) on delayed OBJ1/H2=1 and entry 24+n on direct OBJ2/H2=0.
// Consequently OBJ1 is always earlier whenever both physical lanes FIND at
// one X. Resolve that fixed sheet-15 ordering directly below; the former FPGA
// chronology tags, counters and 16-bit line words only re-encoded this already
// guaranteed relation and had no PCB counterpart.

// Physical U181-U184 are SIS6091B/FIND devices.  Their exact collision and
// clear implementation remains unrecovered; these explicit FPGA backends
// preserve the Pocket/MiSTer-tested registered-read, first-write and atomic
// FIND-clear result without claiming those mechanisms are SIS internals.
sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(10)
) u_181(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(even_clear_cmd), // normalized U181 pin-34 EVNCLR event
  .write_req(line_write_phase && ~EVNWREN && obj1_pix_valid), // pins 31/30
  .write_data(OBJ1[9:0]), // physical OBJ pins 6,7,8,10,12-17
  .addr(E1A),            // package address pins 62-70
  .read_valid(E1FIND),   // package pin 60 FIND
  .read_data(Q_EVN1)     // package OOD/PRIOR pins
);

sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(10)
) u_182(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(even_clear_cmd), // normalized U182 pin-34 EVNCLR event
  .write_req(line_write_phase && ~EVNWREN && obj2_pix_valid), // pins 31/30
  .write_data(OBJ2[9:0]), // physical OBJ pins 6,7,8,10,12-17
  .addr(E2A),            // package address pins 62-70
  .read_valid(E2FIND),   // package pin 60 FIND
  .read_data(Q_EVN2)     // package OOD/PRIOR pins
);

sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(10)
) u_183(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(odd_clear_cmd), // normalized U183 pin-34 ODDCLR event
  .write_req(line_write_phase && ~ODDWREN && obj1_pix_valid), // pins 31/30
  .write_data(OBJ1[9:0]), // physical OBJ pins 6,7,8,10,12-17
  .addr(O1A),            // package address pins 62-70
  .read_valid(O1FIND),   // package pin 60 FIND
  .read_data(Q_ODD1)     // package OOD/PRIOR pins
);

sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(10)
) u_184(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(odd_clear_cmd), // normalized U184 pin-34 ODDCLR event
  .write_req(line_write_phase && ~ODDWREN && obj2_pix_valid), // pins 31/30
  .write_data(OBJ2[9:0]), // physical OBJ pins 6,7,8,10,12-17
  .addr(O2A),            // package address pins 62-70
  .read_valid(O2FIND),   // package pin 60 FIND
  .read_data(Q_ODD2)     // package OOD/PRIOR pins
);


// The current system contract treats PRIOR_C/D and FIND as active high.
// FIND is unbubbled on sheet 18 but still needs package-pin confirmation.

// Sheet 18 connects D1V_7P and ND1V_7P to active-low RAM output enables.
// Thus D1V_7P=0 enables the EVEN pair, while D1V_7P=1 makes ND1V_7P=0 and
// enables the ODD pair. This also matches the captured SEI0060 beam routing
// (V1B=0 -> EA is the beam, V1B=1 -> OA is the beam).
//
// U181-U184 pins 42-49/51/53 drive the shared OOD/PRIOR bus directly; sheet
// 18 has no latch after those outputs. The FPGA SIS facades already register
// their Q and FIND results together, so a second register here made OOD lag
// PLD29's OBJON by one 48 MHz clock. That missed each first opaque pixel at
// MiSTer's centre-pixel sample. Keep only the physical combinational bank and
// first-lane priority selection at this boundary.
always @* begin
  if (!D1V_7P) begin
    if (E1FIND)
      { PRIOR_D, PRIOR_C, OOD[7:0] } = Q_EVN1;
    else if (E2FIND)
      { PRIOR_D, PRIOR_C, OOD[7:0] } = Q_EVN2;
    else
      { PRIOR_D, PRIOR_C, OOD[7:0] } = 10'b11_1111_1111;
  end else begin
    if (O1FIND)
      { PRIOR_D, PRIOR_C, OOD[7:0] } = Q_ODD1;
    else if (O2FIND)
      { PRIOR_D, PRIOR_C, OOD[7:0] } = Q_ODD2;
    else
      { PRIOR_D, PRIOR_C, OOD[7:0] } = 10'b11_1111_1111;
  end
end

endmodule 
