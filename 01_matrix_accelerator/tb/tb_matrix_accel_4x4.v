`timescale 1ns/1ps
module tb_matrix_accel_4x4;
    reg clk = 0, rst_n = 0;
    reg wr_en = 0, wr_matrix = 0;
    reg [3:0] wr_addr = 0;
    reg signed [7:0] wr_data = 0;
    reg start = 0;
    wire busy, done;
    reg [3:0] rd_addr = 0;
    wire signed [31:0] rd_data;
    integer i;
    integer cycles;

    matrix_accel_4x4 dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_matrix(wr_matrix),
        .wr_addr(wr_addr), .wr_data(wr_data),
        .start(start), .busy(busy), .done(done),
        .rd_addr(rd_addr), .rd_data(rd_data)
    );

    always #5 clk = ~clk;

    task write_elem;
        input which;
        input integer addr;
        input integer value;
        begin
            @(negedge clk);
            wr_en = 1'b1; wr_matrix = which;
            wr_addr = addr[3:0]; wr_data = value;
            @(negedge clk);
            wr_en = 1'b0;
        end
    endtask

    task check_result;
        input integer addr;
        input integer expected;
        begin
            @(negedge clk);
            rd_addr = addr[3:0];
            #1;
            if (rd_data !== expected) begin
                $display("FAIL: C[%0d]: expected %0d got %0d", addr, expected, rd_data);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        // A = identity; B[i] = i - 8. Therefore C = B.
        for (i = 0; i < 16; i = i + 1) begin
            write_elem(1'b0, i, ((i/4) == (i%4)) ? 1 : 0);
            write_elem(1'b1, i, i-8);
        end
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;
        cycles = 0;
        while ((done !== 1'b1) && (cycles < 200)) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (done !== 1'b1) begin
            $display("FAIL: timeout waiting for done");
            $finish;
        end
        if (busy !== 1'b0) begin
            $display("FAIL: busy did not deassert after done");
            $finish;
        end
        for (i = 0; i < 16; i = i + 1) check_result(i, i-8);
        $display("PASS: matrix identity test");
        $finish;
    end
endmodule
