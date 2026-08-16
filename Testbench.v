`timescale 1ns / 1ps

module tb_ip_afifo_top_core();

    parameter DATA_WIDTH          = 32;
    parameter ADDR_WIDTH          = 8;
    parameter ALMOST_FULL_OFFSET  = 4;
    parameter ALMOST_EMPTY_OFFSET = 4;
    parameter DEPTH               = 1 << ADDR_WIDTH;

    reg                   wclk;
    reg                   wrst_n;
    reg                   winc;
    reg  [DATA_WIDTH-1:0] wdata;
    wire                  wfull;
    wire                  walmost_full;
    wire                  woverflow;

    reg                   rclk;
    reg                   rrst_n;
    reg                   rinc;
    wire [DATA_WIDTH-1:0] rdata;
    wire                  rempty;
    wire                  ralmost_empty;
    wire                  runderflow;

    ip_afifo_top_core #(
        .DATA_WIDTH          (DATA_WIDTH),
        .ADDR_WIDTH          (ADDR_WIDTH),
        .ALMOST_FULL_OFFSET  (ALMOST_FULL_OFFSET),
        .ALMOST_EMPTY_OFFSET (ALMOST_EMPTY_OFFSET)
    ) dut (
        .wclk          (wclk),
        .wrst_n        (wrst_n),
        .winc          (winc),
        .wdata         (wdata),
        .wfull         (wfull),
        .walmost_full  (walmost_full),
        .woverflow     (woverflow),
        .rclk          (rclk),
        .rrst_n        (rrst_n),
        .rinc          (rinc),
        .rdata         (rdata),
        .rempty        (rempty),
        .ralmost_empty (ralmost_empty),
        .runderflow    (runderflow)
    );

    localparam CONCURRENT_WORDS = 100;

    initial begin
        wclk = 0;
        forever #2.5 wclk = ~wclk;
    end

    initial begin
        rclk = 0;
        forever #3.75 rclk = ~rclk;
    end

    integer i;
    integer error_count = 0;

    task assert_eq(input integer expected, input integer actual, input [800:0] msg);
        begin
            if (expected !== actual) begin
                $display("[ERROR %0t] %s | Expected: %0d, Actual: %0d", $time, msg, expected, actual);
                error_count = error_count + 1;
            end
        end
    endtask

    task reset_fifo;
        begin
            wrst_n = 0;
            rrst_n = 0;
            winc   = 0;
            rinc   = 0;
            wdata  = 0;
            #200;
            @(negedge wclk) wrst_n = 1;
            @(negedge rclk) rrst_n = 1;
            #50;
        end
    endtask

    initial begin
        $display("ASYNC FIFO TESTBENCH");

        reset_fifo();

        $display("Test : Reset State Checks");
        assert_eq(1, rempty, "FIFO should be empty after reset");
        assert_eq(0, wfull,  "FIFO should not be full after reset");
        assert_eq(0, woverflow, "Overflow should be 0");
        assert_eq(0, runderflow, "Underflow should be 0");

        $display("Test : Writing %0d words to fill FIFO", DEPTH);
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge wclk);
            winc  = 1;
            wdata = i;
        end
        @(negedge wclk);
        winc = 0;

        #50;

        assert_eq(1, wfull, "FIFO should be full after writing DEPTH elements");
        assert_eq(1, walmost_full, "Almost full flag should be set");
        assert_eq(0, rempty, "FIFO should not be empty on read side");

        $display("Test : Forcing Overflow Error");
        @(negedge wclk);
        winc = 1;
        wdata = 32'hABCDEF99;
        @(negedge wclk);
        winc = 0;

        #10;
        assert_eq(1, woverflow, "Overflow flag should assert on write while full");

        $display("Test : Reading %0d words to empty FIFO", DEPTH);
        @(negedge rclk);
        rinc = 1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge rclk);
            #3;
            assert_eq(i, rdata, "Data mismatch during sequential read");
        end
        @(negedge rclk);
        rinc = 0;

        #50;

        assert_eq(1, rempty, "FIFO should be empty after reading all elements");
        assert_eq(1, ralmost_empty, "Almost empty flag should be set");
        assert_eq(0, wfull, "FIFO should not be full on write side");

        $display("Test : Forcing Underflow Error");
        @(negedge rclk);
        rinc = 1;
        @(negedge rclk);
        rinc = 0;

        #10;
        assert_eq(1, runderflow, "Underflow flag should assert on read while empty");

        reset_fifo();

        $display("Test");

        fork
            begin: write_thread
                integer w;
                w = 0;
                while (w < CONCURRENT_WORDS) begin
                    @(negedge wclk);
                    if (!wfull) begin
                        winc  = 1;
                        wdata = w;
                        w = w + 1;
                    end else begin
                        winc = 0;
                    end
                end
                @(negedge wclk);
                winc = 0;
            end

            begin: read_thread
                integer r_issue;
                integer r_check;
                integer pending_index;
                reg     read_pending;
                r_issue      = 0;
                r_check      = 0;
                read_pending = 1'b0;

                while (r_check < CONCURRENT_WORDS) begin
                    @(negedge rclk);

                    if (!rempty && r_issue < CONCURRENT_WORDS) begin
                        rinc = 1;
                    end else begin
                        rinc = 0;
                    end

                    #3;
                    if (read_pending) begin
                        assert_eq(pending_index, rdata, "Data mismatch during concurrent traffic");
                        r_check = r_check + 1;
                    end

                    if (rinc == 1) begin
                        pending_index = r_issue;
                        read_pending  = 1'b1;
                        r_issue       = r_issue + 1;
                    end else begin
                        read_pending  = 1'b0;
                    end
                end
                @(negedge rclk);
                rinc = 0;
            end
        join

        if (error_count == 0) begin
            $display("   [  PASS  ] All checks completed successfully!");
        end else begin
            $display("   [  FAIL  ] Simulation finished with %0d errors.", error_count);
        end

        $finish;
    end

endmodule