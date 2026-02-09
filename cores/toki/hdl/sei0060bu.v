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
   input wire HREV,       // Horizontal Reverse (1=Reverse Scan)

   output reg [8:0] OA,   // Odd Address Output
   output reg [8:0] EA,   // Even Address Output

   output reg EVNCLR,     // Even Buffer Clear (Active Low)
   output reg ODDCLR      // Odd Buffer Clear (Active Low)
);

   // -----------------------------------------------------------------
   // 1. Video Scan Counter (Read Address)
   //    - Generates sequential addresses for reading from the buffer to display.
   //    - Resets on HBLB rising edge (start of active video).
   //    - Increments during active video.
   //    - Implements HREV: If 1, bit-wise inverts the address (Right-to-Left).
   // -----------------------------------------------------------------
   reg [8:0] scan_count;
   reg hblb_prev;

   // XOR Logic for Horizontal Reverse (matches 74HCT86 usage)
   wire [8:0] scan_addr_final = HREV ? ~scan_count : scan_count;

   always @(posedge clk) begin
       if (cen) begin
           hblb_prev <= HBLB;
           
           if (!hblb_prev && HBLB) 
               scan_count <= 9'd0;
           else if (HBLB)
               scan_count <= scan_count + 1'b1;
       end
   end

   // -----------------------------------------------------------------
   // 2. Sprite Write Counters (Write Address)
   //    - Mimics 2x 74HC161 4-bit counters.
   //    - When LD is LOW (Active), Loads ADDR[3:0].
   //    - When LD is HIGH (Inactive), Increments.
   //    - Handles the 16-pixel width of sprites.
   // -----------------------------------------------------------------
   reg [3:0] cnt_odd;
   reg [3:0] cnt_evn;

   always @(posedge clk) begin
       if (cen) begin
           // Odd Write Counter
           if (!ODD_LD) 
               cnt_odd <= ADDR[3:0]; // Load
           else if (cnt_odd != 4'hf) // Stop at 15 (optional, prevents wrap) or just wrap
               cnt_odd <= cnt_odd + 1'b1; // Count
           
           // Even Write Counter
           if (!EVN_LD) 
               cnt_evn <= ADDR[3:0]; // Load
           else if (cnt_evn != 4'hf) 
               cnt_evn <= cnt_evn + 1'b1; // Count
       end
   end

   // Combine Upper Bits (Static during write) with Counter Bits
   wire [8:0] sprite_addr_odd = {ADDR[8:4], cnt_odd};
   wire [8:0] sprite_addr_evn = {ADDR[8:4], cnt_evn};

   // -----------------------------------------------------------------
   // 3. Clear Logic
   //    - Pulses Clear during H-Blank for the FUTURE write buffer.
   //    - Logic matches LINEBUF reading behavior (Read Previous, Write Current).
   // -----------------------------------------------------------------
   always @(posedge clk) begin
       if (cen) begin
           EVNCLR <= 1'b1;
           ODDCLR <= 1'b1;

           if (!HBLB) begin
               // If V1B=1 (Odd Line): Display reads Even. Write to Odd. -> Clear Odd.
               if (V1B) ODDCLR <= 1'b0; 
               // If V1B=0 (Even Line): Display reads Odd. Write to Even. -> Clear Even.
               else     EVNCLR <= 1'b0; 
           end
       end
   end

   // -----------------------------------------------------------------
   // 4. Multiplexing (Ping-Pong)
   //    - If V1B=1 (Odd Line): Display reads Even.
   //      -> EA (Even Addr) = Scan Address (Read).
   //      -> OA (Odd Addr) = Sprite Address (Write Odd).
   //    - If V1B=0 (Even Line): Display reads Odd.
   //      -> OA (Odd Addr) = Scan Address (Read).
   //      -> EA (Even Addr) = Sprite Address (Write Even).
   // -----------------------------------------------------------------
   always @(*) begin
       if (V1B) begin // Odd Line
           OA = sprite_addr_odd; 
           EA = scan_addr_final; 
       end
       else begin // Even Line
           EA = sprite_addr_evn; 
           OA = scan_addr_final; 
       end
   end

endmodule
