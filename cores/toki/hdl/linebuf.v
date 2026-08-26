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

wire [15:0] Q_EVN1;
wire [15:0] Q_EVN2;
wire [15:0] Q_ODD1;
wire [15:0] Q_ODD2;

wire [5:0] even_obj1_tag;
wire [5:0] even_obj2_tag;
wire [5:0] odd_obj1_tag;
wire [5:0] odd_obj2_tag;
wire       even_selected_find;
wire       odd_selected_find;
wire [9:0] even_selected_data;
wire [9:0] odd_selected_data;

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
// first-object-wins priority. The physical SORT48 scan presents entry n on
// delayed OBJ1/H2=1 and entry 24+n on direct OBJ2/H2=0. Keep that two-half
// order as a tag in the six FPGA RAM bits which sheet 18 leaves unconnected,
// then resolve simultaneous FINDs by the lower tag. This is an FPGA
// representation of the shared-bus result, not a claim that the original
// SIS6091B stores these tag bits.
obj_line_pair_priority even_pair_priority_u(
    .clk(clk),
    .clear_n(EVNCLR),
    .write_clock(OBJ_N6M),
    .write_enable_n(EVNWREN),
    .earlier_find(E2FIND),       // direct OBJ2: physical entry 24+n
    .later_find(E1FIND),         // delayed OBJ1: physical entry n
    .earlier_word(Q_EVN2),
    .later_word(Q_EVN1),
    .earlier_write_tag(even_obj2_tag), // serializer earlier, list later
    .later_write_tag(even_obj1_tag),   // serializer later, list earlier
    .selected_find(even_selected_find),
    .selected_data(even_selected_data)
);

obj_line_pair_priority odd_pair_priority_u(
    .clk(clk),
    .clear_n(ODDCLR),
    .write_clock(OBJ_N6M),
    .write_enable_n(ODDWREN),
    .earlier_find(O2FIND),       // direct OBJ2: physical entry 24+n
    .later_find(O1FIND),         // delayed OBJ1: physical entry n
    .earlier_word(Q_ODD2),
    .later_word(Q_ODD1),
    .earlier_write_tag(odd_obj2_tag), // serializer earlier, list later
    .later_write_tag(odd_obj1_tag),   // serializer later, list earlier
    .selected_find(odd_selected_find),
    .selected_data(odd_selected_data)
);

// Physical U181-U184 are SIS6091B/FIND devices.  Their exact collision and
// clear implementation remains unrecovered; these explicit FPGA backends
// preserve the Pocket/MiSTer-tested registered-read, first-write and atomic
// FIND-clear result without claiming those mechanisms are SIS internals.
sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(16)
) u_181(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(even_clear_cmd), // normalized U181 pin-34 EVNCLR event
  .write_req(line_write_phase && ~EVNWREN && obj1_pix_valid), // pins 31/30
  .write_data({even_obj1_tag, OBJ1[9:0]}), // OBJ pins + FPGA priority tag
  .addr(E1A),            // package address pins 62-70
  .read_valid(E1FIND),   // package pin 60 FIND
  .read_data(Q_EVN1)     // package OOD/PRIOR pins + FPGA priority tag
);

sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(16)
) u_182(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(even_clear_cmd), // normalized U182 pin-34 EVNCLR event
  .write_req(line_write_phase && ~EVNWREN && obj2_pix_valid), // pins 31/30
  .write_data({even_obj2_tag, OBJ2[9:0]}), // OBJ pins + FPGA priority tag
  .addr(E2A),            // package address pins 62-70
  .read_valid(E2FIND),   // package pin 60 FIND
  .read_data(Q_EVN2)     // package OOD/PRIOR pins + FPGA priority tag
);

sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(16)
) u_183(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(odd_clear_cmd), // normalized U183 pin-34 ODDCLR event
  .write_req(line_write_phase && ~ODDWREN && obj1_pix_valid), // pins 31/30
  .write_data({odd_obj1_tag, OBJ1[9:0]}), // OBJ pins + FPGA priority tag
  .addr(O1A),            // package address pins 62-70
  .read_valid(O1FIND),   // package pin 60 FIND
  .read_data(Q_ODD1)     // package OOD/PRIOR pins + FPGA priority tag
);

sis6091B_atomic #(
    .ADDR_W(9),
    .DATA_W(16)
) u_184(
  .clk(clk),             // FPGA master clock; no package-pin equivalent
  .clear_cmd(odd_clear_cmd), // normalized U184 pin-34 ODDCLR event
  .write_req(line_write_phase && ~ODDWREN && obj2_pix_valid), // pins 31/30
  .write_data({odd_obj2_tag, OBJ2[9:0]}), // OBJ pins + FPGA priority tag
  .addr(O2A),            // package address pins 62-70
  .read_valid(O2FIND),   // package pin 60 FIND
  .read_data(Q_ODD2)     // package OOD/PRIOR pins + FPGA priority tag
);


// The current system contract treats PRIOR_C/D and FIND as active high.
// FIND is unbubbled on sheet 18 but still needs package-pin confirmation.

// Sheet 18 connects D1V_7P and ND1V_7P to active-low RAM output enables.
// Thus D1V_7P=0 enables the EVEN pair, while D1V_7P=1 makes ND1V_7P=0 and
// enables the ODD pair. This also matches the captured SEI0060 beam routing
// (V1B=0 -> EA is the beam, V1B=1 -> OA is the beam).
always @(posedge clk) begin
  if (!D1V_7P) begin
    if (even_selected_find)
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= even_selected_data;
    else
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= 10'b11_1111_1111;
  end else begin
    if (odd_selected_find)
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= odd_selected_data;
    else
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= 10'b11_1111_1111;
  end
end

endmodule 
