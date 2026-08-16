module ip_afifo_top_core #(
    parameter DATA_WIDTH          = 32,
    parameter ADDR_WIDTH          = 8,
    parameter ALMOST_FULL_OFFSET  = 4,
    parameter ALMOST_EMPTY_OFFSET = 4
)(
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire                  wfull,
    output wire                  walmost_full,
    output wire                  woverflow,

    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  rempty,
    output wire                  ralmost_empty,
    output wire                  runderflow
);

    wire [ADDR_WIDTH-1:0] waddr;
    wire [ADDR_WIDTH-1:0] raddr;
    wire [ADDR_WIDTH:0]   wptr;
    wire [ADDR_WIDTH:0]   rptr;
    wire [ADDR_WIDTH:0]   wq2_rptr;
    wire [ADDR_WIDTH:0]   rq2_wptr;

    wire wclken = winc & ~wfull;
    wire rclken = rinc & ~rempty;

    ip_afifo_dpram #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_mem (
        .wclk   (wclk),
        .wclken (wclken),
        .waddr  (waddr),
        .wdata  (wdata),
        .rclk   (rclk),
        .rclken (rclken),
        .raddr  (raddr),
        .rdata  (rdata)
    );

    ip_afifo_sync2 #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_sync_w2r (
        .dest_clk   (rclk),
        .dest_rst_n (rrst_n),
        .src_ptr    (wptr),
        .dest_ptr   (rq2_wptr)
    );

    ip_afifo_sync2 #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_sync_r2w (
        .dest_clk   (wclk),
        .dest_rst_n (wrst_n),
        .src_ptr    (rptr),
        .dest_ptr   (wq2_rptr)
    );

    ip_afifo_wr_ctrl #(
        .ADDR_WIDTH         (ADDR_WIDTH),
        .ALMOST_FULL_OFFSET (ALMOST_FULL_OFFSET)
    ) u_wptr_full (
        .wclk         (wclk),
        .wrst_n       (wrst_n),
        .winc         (winc),
        .wq2_rptr     (wq2_rptr),
        .wfull        (wfull),
        .walmost_full (walmost_full),
        .woverflow    (woverflow),
        .waddr        (waddr),
        .wptr         (wptr)
    );

    ip_afifo_rd_ctrl #(
        .ADDR_WIDTH          (ADDR_WIDTH),
        .ALMOST_EMPTY_OFFSET (ALMOST_EMPTY_OFFSET)
    ) u_rptr_empty (
        .rclk          (rclk),
        .rrst_n        (rrst_n),
        .rinc          (rinc),
        .rq2_wptr      (rq2_wptr),
        .rempty        (rempty),
        .ralmost_empty (ralmost_empty),
        .runderflow    (runderflow),
        .raddr         (raddr),
        .rptr          (rptr)
    );

endmodule