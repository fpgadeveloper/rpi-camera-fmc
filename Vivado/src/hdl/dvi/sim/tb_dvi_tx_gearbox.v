// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// Testbench: dvi_tx_gearbox. Pixel clock 148.5 MHz, TX user clock 74.25 MHz
// with an arbitrary phase offset (frequency locked, as on the board).
// Each data channel carries an incrementing 10-bit symbol sequence; the
// checker verifies that every 20-bit TX word holds two consecutive symbols
// (earlier one in bits [9:0]), that the sequence is continuous on all three
// data lanes, that the clock lane carries 0000011111 and that the polarity
// control inverts a lane.

`timescale 1ps / 1ps

module tb_dvi_tx_gearbox;
    reg pix_clk = 1'b0, tx_clk = 1'b0;
    reg pix_rst = 1'b1, tx_rst = 1'b1;
    reg [3:0] polarity = 4'b0000;
    reg clr = 1'b0;
    reg tx_gate = 1'b1;                        // 0 = stop the TX clock (stall the reader)
    reg [9:0] seq = 10'd0;

    always #3367 pix_clk = ~pix_clk;           // 148.5 MHz (period 6.734 ns)
    initial begin
        #2100;                                 // arbitrary phase
        forever begin #6734; if (tx_gate) tx_clk = ~tx_clk; end   // 74.25 MHz
    end

    wire [29:0] tmds = {seq + 10'd200, seq + 10'd100, seq};
    always @(posedge pix_clk) if (!pix_rst) seq <= seq + 10'd1;

    wire [19:0] d0, d1, d2, d3;
    wire underflow, overflow, running;
    wire [3:0] wd_count;

    dvi_tx_gearbox #(.CLK_LANE(3), .WD_CYCLES(4000)) dut (
        .pix_clk(pix_clk), .pix_rst(pix_rst), .tmds_data(tmds),
        .link_ready(~tx_rst), .tx_clk(tx_clk), .tx_rst(tx_rst), .polarity(polarity), .clr_flags(clr),
        .tx_data0(d0), .tx_data1(d1), .tx_data2(d2), .tx_data3(d3),
        .underflow(underflow), .overflow(overflow), .running(running), .wd_count(wd_count));

    integer words = 0, errors = 0, k;
    reg [9:0] exp0;
    reg       have_exp = 1'b0;
    reg       pol_phase = 1'b0;
    reg [19:0] w0, w1, w2, w3;

    task check_word;
        input [19:0] a0, a1, a2, a3;
        begin
            // data lane consistency: two consecutive symbols per word
            if (a0[19:10] !== a0[9:0] + 10'd1) begin errors = errors + 1; $display("lane0 pair error %h", a0); end
            if (a1[9:0] !== a0[9:0] + 10'd100)  begin errors = errors + 1; $display("lane1 skew error %h %h", a0, a1); end
            if (a2[9:0] !== a0[9:0] + 10'd200)  begin errors = errors + 1; $display("lane2 skew error %h %h", a0, a2); end
            if (a1[19:10] !== a1[9:0] + 10'd1) begin errors = errors + 1; $display("lane1 pair error %h", a1); end
            if (a2[19:10] !== a2[9:0] + 10'd1) begin errors = errors + 1; $display("lane2 pair error %h", a2); end
            if (a3 !== 20'b0000011111_0000011111) begin errors = errors + 1; $display("clock lane error %h", a3); end
            if (have_exp && a0[9:0] !== exp0) begin errors = errors + 1; $display("continuity error at %0t word %0d: got %h exp %h", $time, words, a0[9:0], exp0); end
            exp0 = a0[9:0] + 10'd2;
            have_exp = 1'b1;
        end
    endtask

    initial begin
        #100000;
        @(posedge pix_clk) pix_rst <= 1'b0;
        @(posedge tx_clk)  tx_rst  <= 1'b0;
        // wait for the FIFO to prime
        wait (running);
        repeat (3) @(posedge tx_clk);
        for (k = 0; k < 5000; k = k + 1) begin
            @(posedge tx_clk);
            #1;
            check_word(d0, d1, d2, d3);
            words = words + 1;
        end
        // polarity: invert lane 1 and lane 3, check both are inverted
        polarity <= 4'b1010;
        repeat (10) @(posedge tx_clk);
        #1;
        if (d3 !== ~20'b0000011111_0000011111) begin errors = errors + 1; $display("polarity lane3 not inverted"); end
        if ((~d1[9:0]) !== (d0[9:0] + 10'd100)) begin errors = errors + 1; $display("polarity lane1 not inverted"); end
        if (underflow) begin errors = errors + 1; $display("unexpected underflow"); end
        if (overflow)  begin errors = errors + 1; $display("unexpected overflow"); end
        if (wd_count != 0) begin errors = errors + 1; $display("unexpected watchdog %0d", wd_count); end
        polarity <= 4'b0000;
        // stall the reader (TX clock stopped, as when the reference clock is
        // reprogrammed): FIFO overflows -> watchdog resets the FIFO -> when
        // the clock is back the stream must recover by itself
        tx_gate = 1'b0;
        #200000000;                            // 200 us (timescale 1 ps)
        tx_gate = 1'b1;
        // allow the recovery to settle (reader restart, possible re-prime)
        repeat (2000) @(posedge tx_clk);
        if (!running) begin errors = errors + 1; $display("not streaming after recovery"); end
        have_exp = 1'b0;
        for (k = 0; k < 2000; k = k + 1) begin
            @(posedge tx_clk);
            #1;
            check_word(d0, d1, d2, d3);
        end
        if (wd_count == 0) begin errors = errors + 1; $display("watchdog did not fire"); end
        if (!overflow)     begin errors = errors + 1; $display("overflow not flagged"); end
        $display("after stall: wd_count=%0d overflow=%b underflow=%b, stream recovered", wd_count, overflow, underflow);
        clr <= 1'b1;
        repeat (20) @(posedge tx_clk);
        clr <= 1'b0;
        repeat (20) @(posedge tx_clk);
        if (overflow || underflow || wd_count != 0) begin errors = errors + 1; $display("clear did not clear flags"); end
        if (errors == 0) $display("PASS: %0d TX words checked, 0 errors", words);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
