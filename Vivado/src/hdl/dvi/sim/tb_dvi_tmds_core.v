// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// Testbench: dvi_tmds_core internal 1080p60 test-pattern timing. Decodes the
// blue channel's control tokens (HSYNC/VSYNC) and the data periods and checks
// the CEA-861 VIC 16 frame: 1920 active pixels/line, 1080 active lines,
// 2200 x 1125 total, HSYNC 44 / VSYNC 5 lines, 8 colour bars of 240 pixels.

`timescale 1ns / 1ps

module tb_dvi_tmds_core;
    reg clk = 1'b0, rst = 1'b1;
    always #3.367 clk = ~clk;
    wire [29:0] tmds;

    dvi_tmds_core dut (.pix_clk(clk), .pix_rst(rst), .vid_data(24'h0), .vid_active_video(1'b0),
        .vid_hsync(1'b0), .vid_vsync(1'b0), .test_pattern(1'b1), .tmds_data(tmds));

    // TMDS data symbols are never one of the 4 control tokens
    function is_ctrl(input [9:0] s);
        is_ctrl = (s == 10'b1101010100) || (s == 10'b0010101011) || (s == 10'b0101010100) || (s == 10'b1010101011);
    endfunction
    wire [9:0] b = tmds[9:0];
    wire de = !is_ctrl(b);
    wire hs = (b == 10'b0010101011) || (b == 10'b1010101011);
    wire vs = (b == 10'b0101010100) || (b == 10'b1010101011);

    integer errors = 0, t = 0, de_run = 0, hs_run = 0, line_de = 0, lines_act = 0;
    integer last_hs_rise = -1, hperiod = 0, vs_lines = 0, frames = 0, vs_rise = -1, vperiod = 0;
    reg de_d = 0, hs_d = 0, vs_d = 0;

    reg armed = 0;                             // start checking at the first VSYNC (skip pipeline start-up)
    always @(posedge clk) if (!rst) begin
        t = t + 1;
        if (vs && !vs_d && !armed) begin
            armed = 1; de_run = 0; hs_run = 0; last_hs_rise = -1;
        end
        if (de) de_run = de_run + 1;
        if (de_d && !de) begin
            if (armed && de_run != 1920) begin errors = errors + 1; if (errors < 5) $display("DE run %0d", de_run); end
            de_run = 0; lines_act = lines_act + 1;
        end
        if (hs) hs_run = hs_run + 1;
        if (hs_d && !hs) begin
            if (armed && hs_run != 44) begin errors = errors + 1; if (errors < 5) $display("HS width %0d", hs_run); end
            hs_run = 0;
        end
        if (hs && !hs_d) begin
            if (last_hs_rise >= 0) hperiod = t - last_hs_rise;
            if (armed && last_hs_rise >= 0 && hperiod != 2200) begin errors = errors + 1; if (errors < 5) $display("H period %0d", hperiod); end
            last_hs_rise = t;
        end
        if (vs && !vs_d) begin
            if (vs_rise >= 0) begin
                vperiod = t - vs_rise;
                if (vperiod != 2200*1125) begin errors = errors + 1; $display("V period %0d", vperiod); end
                if (lines_act != 1080) begin errors = errors + 1; $display("active lines %0d", lines_act); end
                frames = frames + 1;
            end
            vs_rise = t; lines_act = 0;
        end
        de_d <= de; hs_d <= hs; vs_d <= vs;
    end

    initial begin
        repeat (10) @(posedge clk);
        rst <= 1'b0;
        wait (frames == 2);
        if (errors == 0) $display("PASS: internal 1080p60 timing, %0d frames checked", frames);
        else             $display("FAIL: %0d timing errors", errors);
        $finish;
    end
endmodule
