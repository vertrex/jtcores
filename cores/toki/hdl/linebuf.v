// Define dual-linebuffer (line odd or even) for obj 1 & obj 2 
// Odd and Even line are switched at each hbl 
// Object 1 & 2 are written to current WREN line (either odd or even)
// and read from other line 
// selected object is data is outputed 

module LINEBUF(
    input             clk,
    input             ODDWREN,
    input             EVNWREN,  // Even write en 
    input             OBJ_N6M,  // ~Clk 6mhz  
    input       [9:0] OBJ1,     // Obj 1 data 
    input       [9:0] OBJ2,     // Obj 2 data 
    input       [8:0] E1A,      // Even 1 addr 
    input             EVNCLR,   // Even clear 
    input             D1V_7P,  
    input             OBJ_P6M,  // Clk 6Mhz
    input       [8:0] E2A,      // Even 2 addr 
    input       [8:0] O1A,      // Obj 1 addr 
    input             ODDCLR,   // Odd line clear 
    input             ND1V_7P,  //~div 7p 
    input       [8:0] O2A,      // Odd 2 addr 
    input             OBJ1_Z,
    input             OBJ2_Z,
    //output 
    output            E1FIND,  // Even 1 find (en?) 
    output            E2FIND,  // Even 2 find (en?)
    output            O1FIND,  // Odd 1 find  (en?)
    output            O2FIND,  // Odd 2 find  (en?)
    output reg  [7:0] OOD,     // object out data 
    output reg        PRIOR_C, // object priority C
    output reg        PRIOR_D  // object priority D
);

wire [9:0] Q_EVN1;
wire [9:0] Q_EVN2; 
wire [9:0] Q_ODD1;
wire [9:0] Q_ODD2;

wire [5:0] nc0;
wire [5:0] nc1;
wire [5:0] nc2;
wire [5:0] nc3;

// Avoid writing transparent pixels (color = 0xF) and ignore hi-Z (masked) bus.
// OBJ*_Z emulates the tri-state output on the original PCB.
wire obj1_pix_valid = (~OBJ1_Z) & (OBJ1[3:0] != 4'hF);
wire obj2_pix_valid = (~OBJ2_Z) & (OBJ2[3:0] != 4'hF);

/// XXX ADD CLEAR SUPPORT !!! 

// XXX  THIS MODULE USE ONLY 6091B that are different than 6091 !!!

// XXXX MUST ADD D1V_7p directio n?
sis6091B u_181(
  .clk(clk),
  .wr_cen(OBJ_N6M), //31 //XXX ~OBJ_N6M or change in sis6091B ? 
  //.we(~EVNWREN & ~OBJ1_Z), //30
  //OBJ1_Z must be up only for 16 ticks 
  //since start of object otherwise it will loop and write same object on
  //whole line  determine by pld29 noobj & noobj_ct2 so by sg0140 (VFIND =>
  //MATCHV => NOOBJ => NOOB_CT2)
  // Gate writes by line write enable and non-transparent pixel
  .we(~EVNWREN & obj1_pix_valid), //30
  // clr at each line by sei60bu (or each frame ?)  
  .clr_n(EVNCLR),
  //data is deserialized by sei0010bu 
  .data({6'b0, OBJ1[9:0]}), //6,7,8,10,12-19,22-25
  // E1A come from sei60bu it extract write addr of each pixel 
  // or provide read addr depending if it's even or odd line turn 
  .addr({1'b0, E1A[8:0]}),//62-71    
  .rd_cen(OBJ_P6M), //73
  .find(E1FIND),
  .q({nc0, Q_EVN1}) //42-56

);

//6091 B 
sis6091B u_182(
  .clk(clk),
  .wr_cen(OBJ_N6M), //31
  .we(~EVNWREN & obj2_pix_valid), //30
  .clr_n(EVNCLR),
  .data({6'b0, OBJ2[9:0]}), //6,7,8,10,12-19,22-25
  .addr({1'b0, E2A[8:0]}),//62-71
  .rd_cen(OBJ_P6M), //73
  .find(E2FIND),
  .q({nc1, Q_EVN2}) //42-56
);

//
sis6091B u_183(
  .clk(clk),
  .wr_cen(OBJ_N6M), //31
  .we(~ODDWREN & obj1_pix_valid), //30
  .clr_n(ODDCLR),
  .data({6'b0, OBJ1[9:0]}), //6,7,8,10,12-19,22-25
  .addr({1'b0, O1A[8:0]}),//62-71
  .rd_cen(OBJ_P6M), //73
  .find(O1FIND),
  .q({nc2, Q_ODD1}) //42-56
);

//
sis6091B u_184(
  .clk(clk),
  .wr_cen(OBJ_N6M), //31
  .we(~ODDWREN & obj2_pix_valid), //30
  .clr_n(ODDCLR),
  .data({6'b0, OBJ2[9:0]}), //6,7,8,10,12-19,22-25
  .addr({1'b0, O2A[8:0]}),//62-71
  .rd_cen(OBJ_P6M), //73
  .find(O2FIND),
  .q({nc3, Q_ODD2}) //42-56
);

//objon is active high 
//PRIOR_C & D are active high 
//FIND is active high 

always @(posedge clk) begin 
  if (D1V_7P) begin 
    if (E1FIND) 
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= Q_EVN1; //depend of OBJON too 
    else if (E2FIND) 
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= Q_EVN2; //depend of OBJON too 
    else
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= 10'b11_1111_1111; //depend of OBJON too 
      end 
  else begin //if (ND1V_7P) begin  ND1V_7P = ~D1V_7P
    if (O1FIND)
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= Q_ODD1; //depend of OBJON TOO 
    else if (O2FIND)
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= Q_ODD2; //depend of OBJON TOO
    else 
      { PRIOR_D, PRIOR_C, OOD[7:0] } <= 10'b11_1111_1111;
     end 
end

//assign {PRIOR_D, PRIOR_C, OOD[7:0]} = E1FIND ? Q_EVN1 : E2FIND ? Q_EVN2 :  O1FIND ? Q_ODD1 : O2FIND ? Q_ODD2 : 10'b0; 


endmodule 
