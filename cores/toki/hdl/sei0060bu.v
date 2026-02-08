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

   always @(posedge clk) begin
       if (cen) begin
           hblb_d <= HBLB;
           // Reset at start of active video (HBLB rising edge) to align X origin.
           if (!hblb_d && HBLB)
               beam_cnt <= 9'b0;
           else
               beam_cnt <= beam_cnt + 1'b1;
       end

       // Load strobes are active low; capture base and restart pixel counter.
       if (!EVN_LD) begin
           even_base   <= ADDR;
           even_pix    <= 4'b0;
           even_active <= 1'b1;
       end else if (cen && !V1B && even_active) begin
           even_pix <= even_pix + 1'b1;
           if (even_pix == 4'd15)
               even_active <= 1'b0;
       end

       if (!ODD_LD) begin
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
       // When V1B=0 (even line): even buffer writes, odd buffer reads.
       // When V1B=1 (odd line):  odd buffer writes, even buffer reads.
       if (V1B) begin
           OA = HREV ? ~beam_cnt   : beam_cnt;
           EA = odd_wr_cnt;
       end else begin
           OA = even_wr_cnt;
           EA = HREV ? ~beam_cnt   : beam_cnt;
       end
   end

endmodule
