// Behavioral model of the opaque SEI0021BU scroll adders on sheets 7/8.
//
// Pins 31..38 receive the already XORed EXH/EXV bus, pin 39 receives H256 on
// a horizontal instance and T8H on a vertical instance, and pin 41 receives
// HREV/VREV.  H256 remains the ninth horizontal coordinate bit in both
// directions.  With the lower EXH bus reversed, retaining H256 makes the
// source count decrement continuously across its low-byte wrap
// (...1, 0, 511, 510...).  Complementing H256 selects the unrelated map half;
// forcing it low instead creates a +256 discontinuity at that wrap.
//
// T8H is a timing input, not a vertical coordinate bit; its exact internal
// use still needs a joint input/output PCB capture.  Keeping pin 39 explicit
// prevents the schematic wiring from being confused with V256 again.
//
// CPU writes are sampled in the master domain so a physical select pulse
// cannot disappear between 6 MHz enables; raster addition remains on `cen`.
module sei0021bu #(
   parameter PIN39_IS_MSB = 1'b1
)(
   input            clk,

   input            cen,
   input            rst_n,
   input            cs_n,

   input            low, 
   input            high,
   input      [7:0] data,

   input      [7:0] pos,   // pins 31..38: EXH/EXV
   input            pin39, // H256 (horizontal) or T8H (vertical)
   input            rev,   // pin 41: HREV/VREV

   // `sync` is an RTL helper derived from the output coordinate for the
   // SEI0010 load phase; it is not an additional recovered IC pin.
   output reg       sync,
   output reg [8:0] scrolled // bit 8 is sheet output pin 2
);

reg [7:0] scroll_low;
reg       scroll_high;

wire [8:0] scroll = {scroll_high, scroll_low};
wire       raster_msb = PIN39_IS_MSB ? pin39 : 1'b0;
wire [8:0] raster_pos = {raster_msb, pos};
wire [8:0] scrolled_next = raster_pos + scroll;

always @(posedge clk, negedge rst_n) begin
   if (rst_n == 1'b0) begin 
      scroll_low <= 8'b0;
      scroll_high <= 1'b0;
      end 
   else begin
      // Sheet 8 connects MAB<2:1> directly to SEI0021 pins 28/29; they are
      // address inputs, not two independent level-sensitive write enables.
      // Phase 10 clocks the rotated low-byte latch.  MAB<1> clocks the high
      // bit at phase 01 during normal updates and at phase 11 during the ROM's
      // initialization sequence.  Sample the decoded write on the master
      // clock, independently of N6M: the physical select can fall and rise
      // entirely between 6-MHz edges. Repeated samples are idempotent, just as
      // holding a stable value at the physical latch is.
      if (!cs_n) begin
         if (low && !high)
            scroll_low <= {data[6:0], data[7]};
         if (high)
            scroll_high <= data[4];
      end

      if (cen) begin
         scrolled <= scrolled_next;

         // Once the raster direction is reversed the next four-pixel word
         // begins at coordinate 0 rather than 3.
         sync <= rev ? (scrolled_next[1:0] == 2'b00) :
                       (scrolled_next[1:0] == 2'b11);
      end
   end 
end

endmodule 
