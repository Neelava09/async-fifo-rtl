module ip_afifo_wr_ctrl #(
    parameter ADDR_WIDTH = 8,
    parameter ALMOST_FULL_OFFSET = 4
)(
    input  wire wclk,
    input  wire wrst_n,
    input  wire winc,
    input  wire [ADDR_WIDTH:0] wq2_rptr,
    output reg  wfull,
    output reg  walmost_full,
    output reg  woverflow,
    output wire [ADDR_WIDTH-1:0] waddr,
    output reg  [ADDR_WIDTH:0] wptr
);
    reg  [ADDR_WIDTH:0] wbin;
    wire [ADDR_WIDTH:0] wgraynext, wbinnext;
    wire wfull_val, walmost_full_val, woverflow_val;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin         <= 0;
            wptr         <= 0;
            wfull        <= 0;
            walmost_full <= 0;
            woverflow    <= 0;
        end else begin
            wbin         <= wbinnext;
            wptr         <= wgraynext;
            wfull        <= wfull_val;
            walmost_full <= walmost_full_val;
            woverflow    <= woverflow_val;
        end
    end

    assign waddr = wbin[ADDR_WIDTH-1:0];
    assign wbinnext = wbin + (winc & ~wfull);
    assign wgraynext = (wbinnext >> 1) ^ wbinnext;

    assign wfull_val = (wgraynext == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});
    
    wire [ADDR_WIDTH:0] wq2_rptr_bin;
    genvar i;
    generate
        for (i = 0; i <= ADDR_WIDTH; i = i + 1) begin : gray_to_bin_w
            assign wq2_rptr_bin[i] = ^(wq2_rptr >> i);
        end
    endgenerate
    
    wire [ADDR_WIDTH:0] wdiff = wbinnext - wq2_rptr_bin;
    assign walmost_full_val = (wdiff >= ((1 << ADDR_WIDTH) - ALMOST_FULL_OFFSET));
    
    assign woverflow_val = woverflow | (wfull & winc);
endmodule