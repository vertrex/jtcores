//  SEI0060BU is the line‑buffer X‑address generator + line‑clear controller for sprites.
 // It does three jobs per line:

//  1. Generates the read address that scans the line buffer left‑to‑right during display.
//  2. Generates the write address that places the 16 pixels of a sprite line at its X position.
//  3. Clears the buffer that will be written on the next line (ping‑pong).


module SEI0060BU(
   input wire clk,        // System Clock (48Mhz)
   input wire cen,        // Pixel Clock Enable (6MHz)

   input wire [8:0] ADDR, // Sprite X base from OF/FH 
   input wire ODD_LD,     // Load Strobe for Odd path (Active Low)
   input wire EVN_LD,     // Load Strobe for Even path (Active Low)
   
   input wire HBLB,       // Horizontal Blanking (Low = Blank, High = Active) reset & clear timing
   input wire OBJT2_7,    // Timing/size flag (likely 8‑wide vs 16‑wide)
   input wire V1B,        // Line parity, selects odd/even buffer for read/write 
   input wire T8H,        // (Timing / half‑line strobe (8‑pixel) 
   input wire HREV,       // Horizontal Reverse (1=Reverse Scan)

   output reg [8:0] OA,   // Odd buffer address
   output reg [8:0] EA,   // Even buffer address
   output reg EVNCLR,     // Even buffer clear (Active Low)
   output reg ODDCLR      // Odd buffer clear (Active Low)
);


    // 1) Read scan counter for line buffer (video X position).
    //    Reset at HBLB rising edge, increment while HBLB=1.
    reg [8:0] x_scan;
    reg       hblb_prev;

    always @(posedge clk) begin
        if (cen) begin
            hblb_prev <= HBLB;
            if (!hblb_prev && HBLB)
                x_scan <= 9'd0;
            else if (HBLB)
                x_scan <= x_scan + 9'd1;
        end
    end

    // 2) Write address generation.
    //    Trace shows write bursts with fixed high bits and cycling low nibble.
    //    That implies: write_x = {ADDR[8:4], pix_off[3:0]} (no carry).
    reg [4:0] odd_base_hi;
    reg [4:0] even_base_hi;
    reg [3:0] odd_pix;
    reg [3:0] even_pix;

    wire [3:0] pix_max = OBJT2_7 ? 4'd7 : 4'd15;

    always @(posedge clk) begin
        if (cen) begin
            if (!ODD_LD) odd_base_hi <= ADDR[8:4];
            if (!EVN_LD) even_base_hi <= ADDR[8:4];

            if (!ODD_LD)
                odd_pix <= 4'd0;
            else if (odd_pix < pix_max) begin
                if (!OBJT2_7 || T8H)
                    odd_pix <= odd_pix + 4'd1;
            end

            if (!EVN_LD)
                even_pix <= 4'd0;
            else if (even_pix < pix_max) begin
                if (!OBJT2_7 || T8H)
                    even_pix <= even_pix + 4'd1;
            end
        end
    end

    wire [8:0] odd_write_x  = {odd_base_hi,  odd_pix};
    wire [8:0] even_write_x = {even_base_hi, even_pix};

    // Optional HREV flip for read scan.
    wire [8:0] read_x = HREV ? ~x_scan : x_scan;

    // Ping-pong mux.
    always @(*) begin
        if (V1B) begin
            // Odd line active: write ODD, read EVEN
            OA = odd_write_x;
            EA = read_x;
        end else begin
            // Even line active: write EVEN, read ODD
            EA = even_write_x;
            OA = read_x;
        end
    end

    // --- Clear pulses during HBLB ---
    // Trace shows EVNCLR low when HBLB=0 && V1B=1
    // and ODDCLR low when HBLB=0 && V1B=0
    always @(*) begin
      EVNCLR = 1'b1;
      ODDCLR = 1'b1;
      if (!HBLB) begin
        if (V1B) EVNCLR = 1'b0;
        else     ODDCLR = 1'b0;
      end
    end


endmodule
