module ip_afifo_dpram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
)(
    input  wire                  wclk,
    input  wire                  wclken,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] wdata,

    input  wire                  rclk,
    input  wire                  rclken,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output reg  [DATA_WIDTH-1:0] rdata
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    (* ram_style = "distributed" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge rclk) begin
        if (rclken) begin
            rdata <= mem[raddr];
        end
    end

    always @(posedge wclk) begin
        if (wclken) begin
            mem[waddr] <= wdata;
        end
    end

endmodule