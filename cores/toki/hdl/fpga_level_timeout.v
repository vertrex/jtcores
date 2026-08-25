// Generic FPGA recovery guard for a level which must not remain active.
// This is implementation policy, not a model of any Toki PCB component.
// `expired` lasts for the cycle in which the saturating counter is full; the
// counter then restarts if the monitored level was not released by its owner.
module fpga_level_timeout #(
    parameter WIDTH = 17
) (
    input                  clk,
    input                  rst,
    input                  active,
    output                 expired
);

reg [WIDTH-1:0] count;

assign expired = active && (&count);

always @(posedge clk) begin
    if (rst || !active || expired)
        count <= {WIDTH{1'b0}};
    else
        count <= count + {{(WIDTH-1){1'b0}}, 1'b1};
end

endmodule
