module SEI0060BU(
   input wire clk,      // System Clock
   input wire cen,      // Pixel Clock Enable (6MHz)

   input wire [8:0] ADDR, // Base Sprite X Position
   input wire ODD_LD,     // Load Strobe for Odd path (Active Low)
   input wire EVN_LD,     // Load Strobe for Even path (Active Low)
   
   input wire HBLB,       // Horizontal Blanking (Low = Blank, High = Active)
   input wire OBJT2_7,    // (Unused)
   input wire V1B,        // Vertical Line LSB (0=Even, 1=Odd)
   input wire T8H,        // (Unused)
   input wire HREV,       // (Unused)

   output reg [8:0] OA,   // Odd Address Output
   output reg [8:0] EA,   // Even Address Output

   output reg EVNCLR,     // Even Buffer Clear (Active Low)
   output reg ODDCLR      // Odd Buffer Clear (Active Low)
);

   // Base address latches and 4-bit pixel counters (limit to 16 pixels).
   reg [8:0] even_base;
   reg [8:0] odd_base;
   reg [3:0] even_pix;
   reg [3:0] odd_pix;
   reg       even_active;
   reg       odd_active;

   // Read/beam counter (reset each line).
   reg [8:0] beam_cnt;
   reg       hblb_d;
   reg       evn_ld_d = 1'b1;
   reg       odd_ld_d = 1'b1;

   wire evn_ld_fall = (evn_ld_d == 1'b1) && (EVN_LD == 1'b0);
   wire odd_ld_fall = (odd_ld_d == 1'b1) && (ODD_LD == 1'b0);

   always @(posedge clk) begin
       evn_ld_d <= EVN_LD;
       odd_ld_d <= ODD_LD;

       if (cen) begin
           hblb_d <= HBLB;
           // Reset at start of active video (HBLB rising edge) to align X origin.
           if (!hblb_d && HBLB)
               beam_cnt <= 9'b0;
           else
               beam_cnt <= beam_cnt + 1'b1;
       end

       // Latch once per load strobe.
       if (evn_ld_fall) begin
           even_base   <= ADDR;
           even_pix    <= 4'b0;
           even_active <= 1'b1;
       end else if (cen && !V1B && even_active) begin
           even_pix <= even_pix + 1'b1;
           if (even_pix == 4'd15)
               even_active <= 1'b0;
       end

       if (odd_ld_fall) begin
           odd_base   <= ADDR;
           odd_pix    <= 4'b0;
           odd_active <= 1'b1;
       end else if (cen && V1B && odd_active) begin
           odd_pix <= odd_pix + 1'b1;
           if (odd_pix == 4'd15)
               odd_active <= 1'b0;
       end
   end

   // 3. Clear Logic (Pulse during H-Blank)
   // Target the FUTURE buffer (Next Line)
   always @(posedge clk) begin
       if (cen) begin
           EVNCLR <= 1'b1;
           ODDCLR <= 1'b1;

           if (!HBLB) begin
               // If V1B=1 (Odd Displaying), Next is Even -> Clear Even
               if (V1B) EVNCLR <= 1'b0;
               // If V1B=0 (Even Displaying), Next is Odd -> Clear Odd
               else     ODDCLR <= 1'b0;
           end
       end
   end

   // 4. Address Muxing
   wire [3:0] even_pix_adj = HREV ? ~even_pix : even_pix;
   wire [3:0] odd_pix_adj  = HREV ? ~odd_pix  : odd_pix;
   wire [8:0] even_wr_cnt  = even_base + {5'b0, even_pix_adj};
   wire [8:0] odd_wr_cnt   = odd_base  + {5'b0, odd_pix_adj};

   always @(*) begin
       // Trace-backed mapping from real SEI0060BU captures:
       // - V1B=0: OA behaves as beam/read counter, EA carries write address.
       // - V1B=1: EA behaves as beam/read counter, OA carries write address.
       //
       // Write-side address source follows the matching load domain:
       // - EA <= even_wr_cnt (EVN_LD/even_pix path)
       // - OA <= odd_wr_cnt  (ODD_LD/odd_pix path)
       if (V1B) begin
           OA = odd_wr_cnt;
           EA = HREV ? ~beam_cnt : beam_cnt;
       end else begin
           OA = HREV ? ~beam_cnt : beam_cnt;
           EA = even_wr_cnt;
       end
   end

endmodule
