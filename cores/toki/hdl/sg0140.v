///////////////////////////////////////////////////
///////////// SG0140 ABSEL ////////////////////////
///////////////////////////////////////////////////
// SG0140: Priority & Color Mixer / Multifunction Chip
module sg0140(
  input       clk, 
  input       cen, 

  // Background Layer (BK1)
  input [3:0] PIC_A, 
  input [3:0] COL_A, 
  input       COL_A_EN,
  input       MASK_A,  

  // Character Layer (CHAR)
  input [3:0] PIC_B, 
  input [3:0] COL_B, 
  input       COL_B_EN,
  input       MASK_B, 
  input [1:0] MODE, 

  output reg  [7:0] Q,  
  output reg  ON_A,     
  output reg  ON_B      
);

reg [3:0] COL_A_LATCH;
reg [3:0] COL_B_LATCH;

always @(posedge clk) begin
  if (cen) begin
    if (COL_B_EN) COL_B_LATCH[3:0] <= COL_B[3:0];
    if (COL_A_EN) COL_A_LATCH[3:0] <= COL_A[3:0];

    ON_A <= (PIC_A[3:0] == 4'hf) ? 1'b0 : 1'b1;
    ON_B <= (PIC_B[3:0] == 4'hf) ? 1'b0 : 1'b1;

    Q[7:0] <= (PIC_B[3:0] != 4'hf) ? {COL_B_LATCH[3:0], PIC_B[3:0]} :
                                     {COL_A_LATCH[3:0], PIC_A[3:0]};
  end
end
endmodule

///////////////////////////////////////////////////
///////////// SG0140 OHMAX ////////////////////////
///////////////////////////////////////////////////
module sg0140_ohmax(
  input            clk,
  input            rst, 
  input            NOOBJ, 
  input      [8:4] OVD,   
  input            HREV,  
  input            CTLT1, 
  input            CTLT2, 

  output reg [8:4] OH,   
  output reg [4:0] ADDR, 
  output reg       NOOBJ_CT2 
);

always @(negedge clk) begin
      if (rst) begin
          OH        <= 5'b0;
          ADDR      <= 5'b0;
          NOOBJ_CT2 <= 1'b0;
      end
      else begin
          if (!CTLT1) begin
              OH[8:4] <= HREV ? ~OVD[8:4] : OVD[8:4];
          end

          if (!CTLT2) begin
              ADDR[4:0] <= HREV ? ~OVD[8:4] : OVD[8:4]; 
              NOOBJ_CT2 <= NOOBJ; 
          end
      end
end
endmodule

///////////////////////////////////////////////////
///////////// SG0140 VCHECK ///////////////////////
///////////////////////////////////////////////////
module sg0140_vcheck(
  input             clk,
  input             rst,
  input       [7:0] VPD,      
  input             ODMARQ,   
  input             OBUSAK,   
  input             SDTS,     
  input             VORIGIN,  
  input             OVER256,  
  input             OVER48,   
  input             VREVD_2,  
  input             OBJEN_3,  
  input             H2,       
  input             RDCLK,    
  input             VCLK,     
  input             VREV,     
  input             NV256,    

  output reg  [3:0] VMT,    
  output reg        EVNWR2, 
  output reg        ODDWR2, 
  output reg        OIBDIR, 
  output reg        OBUSRQ, 
  output reg        VFIND   
);

    // 1. Line Counter
    reg [8:0] current_y;
    reg old_vclk;
    
    always @(posedge clk) begin
        if (rst) begin
            current_y <= 0;
            old_vclk <= 0;
        end else begin
            old_vclk <= VCLK;
            
            if (VORIGIN) begin
                current_y <= 0;
            end
            else if (VCLK && !old_vclk) begin
                current_y <= current_y + 1'b1;
            end
        end
    end

    // 2. Bus Arbitration
    always @(posedge clk) begin
        if (rst) begin
            OBUSRQ <= 1'b1; 
            OIBDIR <= 1'b1; 
        end
        else begin
            if (!ODMARQ) OBUSRQ <= 1'b0;
            
            if (!OBUSAK && !OBUSRQ) begin
                OIBDIR <= 1'b0; 
                OBUSRQ <= 1'b1; 
            end

            if (!OVER256) OIBDIR <= 1'b1;
        end
    end

    // 3. Visibility Calculation
    wire [8:0] sprite_y = {1'b0, VPD}; 
    wire [8:0] diff_y = current_y - sprite_y;
    wire visible = (diff_y < 16);
    wire effective_flip = VREV ^ VREVD_2;

    always @(negedge clk) begin
        if (rst) begin
            VFIND <= 1'b1;
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
            VMT <= 0;
        end
        else if (!OIBDIR) begin 
             if (!RDCLK) begin
                 if (visible && OBJEN_3 && !OVER48) begin
                     
                     VFIND <= 1'b0; // Signal Match
                     VMT <= effective_flip ? ~diff_y[3:0] : diff_y[3:0];

                     // Write Strobe Logic
                     // If Current Line is Odd (1), Write to Odd Buffer.
                     // If Current Line is Even (0), Write to Even Buffer.
                     if (current_y[0]) begin
                         EVNWR2 <= 1'b1; 
                         ODDWR2 <= 1'b0; // Write Odd
                     end else begin
                         EVNWR2 <= 1'b0; // Write Even
                         ODDWR2 <= 1'b1;
                     end
                 end
                 else begin
                     VFIND <= 1'b1;
                     EVNWR2 <= 1'b1;
                     ODDWR2 <= 1'b1;
                 end
             end
        end
        else begin
            VFIND <= 1'b1;
            EVNWR2 <= 1'b1;
            ODDWR2 <= 1'b1;
        end
    end

endmodule

///////////////////////////////////////////////////
///////////// SG0140 SORT 48 //////////////////////
///////////////////////////////////////////////////
module sg0140_sort48(
  input   clk,
  input   rst, 
  input   RDCLK, 
  input   VFIND, 
  input   XSDTS, 
  input   ILD2, 
  input   V1B,   
  input   NH2,  
  input   H2,    
  input   H2_2, 
  input   [8:4] H, 

  output reg  OVER48,      
  output reg  [5:0] DMA2_EA, 
  output reg  [5:0] DMA2_OA  
);

  // 1. Read Address (Scan)
  wire [5:0] read_addr = {H[8:7], H2, H[6:4]};

  // 2. Write Address (Stack)
  reg [5:0] stack_ptr;
  reg vfind_prev;

  always @(negedge clk) begin
      if (rst) begin
          stack_ptr <= 0;
          OVER48 <= 0;
          vfind_prev <= 1;
      end
      else begin
          vfind_prev <= VFIND;

          // XSDTS High = Display Phase -> Reset
          if (XSDTS) begin
              stack_ptr <= 0;
              OVER48 <= 0;
          end
          // XSDTS Low = Sorting Phase -> Build Stack
          else begin
              // Removed ILD2 check as trace analysis shows ILD2 is 0 during sorting
              if (vfind_prev && !VFIND) begin
                  if (stack_ptr < 6'd48) begin
                      stack_ptr <= stack_ptr + 1'b1;
                  end
                  else begin
                      OVER48 <= 1'b1; 
                  end
              end
          end
      end
  end

  // 3. Ping-Pong Address Multiplexing
  // If V1B=1 (Odd): Write Odd (Stack), Read Even (Video)
  // If V1B=0 (Even): Write Even (Stack), Read Odd (Video)
  // Updates on negedge clk (Fast) to ensure stability before memory latch
  always @(negedge clk) begin
      if (V1B) begin
          DMA2_OA <= stack_ptr; // Write Odd
          DMA2_EA <= read_addr; // Read Even
      end
      else begin
          DMA2_EA <= stack_ptr; // Write Even
          DMA2_OA <= read_addr; // Read Odd
      end
  end

endmodule
