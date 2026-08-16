module ip_afifo_sync2 #(
    parameter ADDR_WIDTH = 8
)(
    input  wire dest_clk,
    input  wire dest_rst_n,
    input  wire [ADDR_WIDTH:0] src_ptr,
    output reg  [ADDR_WIDTH:0] dest_ptr
);
    reg [ADDR_WIDTH:0] q1;

    always @(posedge dest_clk or negedge dest_rst_n) begin
        if (!dest_rst_n) begin
            q1       <= 0;
            dest_ptr <= 0;
        end else begin
            q1       <= src_ptr;
            dest_ptr <= q1;
        end
    end
endmodule