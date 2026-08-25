// FPGA-only validity sideband for a retentive object-snapshot RAM.
//
// The Toki PCB completes every physical U141 refresh; the FPGA-only DMA timeout
// can instead release the CPU bus after a partial refresh. Both the physical
// and inferred RAM are retentive, so without a sideband the untouched tail from
// the prior frame can reappear as frozen/ghost descriptors. This plane starts a
// new empty epoch when ownership becomes active and publishes only entries
// whose final-word phase was reached in the current epoch. It owns no object
// attributes, visibility rule, raster policy or recovered PCB-IC behavior.
module obj_snapshot_valid_plane #(
    parameter ADDR_W = 8
) (
    input                         clk,
    input                         rst,
    input                         epoch_active,
    input                         mark_cen,
    input      [ADDR_W-1:0]       mark_addr,
    input                         read_cen,
    input      [ADDR_W-1:0]       read_addr,
    output reg                    read_valid
);

reg epoch_active_d;
reg [(1<<ADDR_W)-1:0] valid_map;

wire epoch_start = epoch_active && !epoch_active_d;

always @(posedge clk) begin
    if (rst) begin
        epoch_active_d <= 1'b0;
        valid_map      <= {(1<<ADDR_W){1'b0}};
        read_valid     <= 1'b0;
    end else begin
        epoch_active_d <= epoch_active;

        // Preserve the original OBJDMA precedence: a new ownership epoch
        // wins if its first mark would coincide with the entry transition.
        if (epoch_start)
            valid_map <= {(1<<ADDR_W){1'b0}};
        else if (mark_cen)
            valid_map[mark_addr] <= 1'b1;

        // Read the old validity value on the same clock as the synchronous
        // data RAM. A simultaneous mark is intentionally visible next time.
        if (read_cen)
            read_valid <= valid_map[read_addr];
    end
end

endmodule
