// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// Testbench: dvi_tmds_encoder against vectors from tmds_model.py
// (line format: "<din> <de> <c0> <c1> <expected q_out>", hex/bits).

`timescale 1ns / 1ps

module tb_dvi_tmds_encoder;
    localparam integer LAT = 3;
    localparam integer MAXV = 40000;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg  [7:0] din = 8'd0;
    reg        de = 1'b0, c0 = 1'b0, c1 = 1'b0;
    wire [9:0] q;

    reg [7:0] v_d  [0:MAXV-1];
    reg       v_de [0:MAXV-1];
    reg       v_c0 [0:MAXV-1];
    reg       v_c1 [0:MAXV-1];
    reg [9:0] v_q  [0:MAXV-1];

    integer fd, r, n, i, errors;
    reg [7:0] t_d; reg [9:0] t_q; integer t_de, t_c0, t_c1;

    always #3.367 clk = ~clk;

    dvi_tmds_encoder dut (.clk(clk), .rst(rst), .din(din), .de(de), .c0(c0), .c1(c1), .tmds_out(q));

    initial begin
        fd = $fopen("tmds_vectors.txt", "r");
        if (fd == 0) begin $display("FAIL: cannot open tmds_vectors.txt"); $finish; end
        n = 0;
        while (!$feof(fd) && n < MAXV) begin
            r = $fscanf(fd, "%h %d %d %d %h\n", t_d, t_de, t_c0, t_c1, t_q);
            if (r == 5) begin
                v_d[n] = t_d; v_de[n] = t_de; v_c0[n] = t_c0; v_c1[n] = t_c1; v_q[n] = t_q;
                n = n + 1;
            end
        end
        $fclose(fd);
        $display("loaded %0d vectors", n);

        errors = 0;
        // reset: encoder starts from disparity 0, like the model
        repeat (4) @(posedge clk);
        rst <= 1'b0;
        for (i = 0; i < n + LAT; i = i + 1) begin
            @(negedge clk);
            if (i >= LAT) begin
                if (q !== v_q[i-LAT]) begin
                    errors = errors + 1;
                    if (errors < 10)
                        $display("MISMATCH vec %0d: din=%02h de=%0d c=%0d%0d got %010b exp %010b",
                                 i-LAT, v_d[i-LAT], v_de[i-LAT], v_c1[i-LAT], v_c0[i-LAT], q, v_q[i-LAT]);
                end
            end
            if (i < n) begin
                din <= v_d[i]; de <= v_de[i]; c0 <= v_c0[i]; c1 <= v_c1[i];
            end else begin
                de <= 1'b0;
            end
        end
        if (errors == 0) $display("PASS: %0d vectors, 0 mismatches", n);
        else             $display("FAIL: %0d mismatches", errors);
        $finish;
    end
endmodule
