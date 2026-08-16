module ip_afifo_rd_ctrl #(
    parameter ADDR_WIDTH = 8,
    parameter ALMOST_EMPTY_OFFSET = 4
)(
    input  wire rclk,
    input  wire rrst_n,
    input  wire rinc,
    input  wire [ADDR_WIDTH:0] rq2_wptr,
    output reg  rempty,
    output reg  ralmost_empty,
    output reg  runderflow,
    output wire [ADDR_WIDTH-1:0] raddr,
    output reg  [ADDR_WIDTH:0] rptr
);
    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rgraynext, rbinnext;
    wire rempty_val, ralmost_empty_val, runderflow_val;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin          <= 0;
            rptr          <= 0;
            rempty        <= 1'b1;
            ralmost_empty <= 1'b1;
            runderflow    <= 0;
        end else begin
            rbin          <= rbinnext;
            rptr          <= rgraynext;
            rempty        <= rempty_val;
            ralmost_empty <= ralmost_empty_val;
            runderflow    <= runderflow_val;
        end
    end

    assign raddr = rbin[ADDR_WIDTH-1:0];
    assign rbinnext = rbin + (rinc & ~rempty);
    assign rgraynext = (rbinnext >> 1) ^ rbinnext;

    assign rempty_val = (rgraynext == rq2_wptr);

    wire [ADDR_WIDTH:0] rq2_wptr_bin;
    genvar i;
    generate
        for (i = 0; i <= ADDR_WIDTH; i = i + 1) begin : gray_to_bin_r
            assign rq2_wptr_bin[i] = ^(rq2_wptr >> i);
        end
    endgenerate

    wire [ADDR_WIDTH:0] rdiff = rq2_wptr_bin - rbinnext;
    assign ralmost_empty_val = (rdiff <= ALMOST_EMPTY_OFFSET);

    assign runderflow_val = runderflow | (rempty & rinc);
endmodule