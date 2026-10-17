// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// dvi_tmds_encoder - one TMDS channel encoder (8b -> 10b), DVI 1.0 section 3.2.
//
// Device independent, plain Verilog-2001. One symbol per clock, 3 pipeline
// stages (latency 3 clocks from inputs to tmds_out).
//
// Bit 0 of tmds_out is the first bit transmitted on the wire.
//
// Control tokens (de = 0), as q_out[9:0]:
//   {c1,c0} = 00 -> 10'b1101010100
//             01 -> 10'b0010101011
//             10 -> 10'b0101010100
//             11 -> 10'b1010101011

`timescale 1ns / 1ps

module dvi_tmds_encoder (
    input  wire       clk,
    input  wire       rst,       // synchronous, active high: clears the disparity counter
    input  wire [7:0] din,       // pixel component
    input  wire       de,        // data enable (active video)
    input  wire       c0,        // control bit 0 (blue channel: HSYNC)
    input  wire       c1,        // control bit 1 (blue channel: VSYNC)
    output reg  [9:0] tmds_out
);

    // number of ones in an 8-bit value
    function [3:0] ones8;
        input [7:0] v;
        integer k;
        begin
            ones8 = 4'd0;
            for (k = 0; k < 8; k = k + 1)
                ones8 = ones8 + {3'd0, v[k]};
        end
    endfunction

    // ---------------- stage 1: register inputs, count ones of D ------------
    reg [7:0] d1;
    reg       de1, c0_1, c1_1;
    reg [3:0] n1d1;

    always @(posedge clk) begin
        d1   <= din;
        de1  <= de;
        c0_1 <= c0;
        c1_1 <= c1;
        n1d1 <= ones8(din);
    end

    // ---------------- stage 2: transition-minimised q_m --------------------
    wire use_xnor = (n1d1 > 4'd4) || ((n1d1 == 4'd4) && (d1[0] == 1'b0));
    reg  [8:0] qm_c;
    integer i;
    always @(*) begin
        qm_c[0] = d1[0];
        for (i = 1; i < 8; i = i + 1)
            qm_c[i] = use_xnor ? ~(qm_c[i-1] ^ d1[i]) : (qm_c[i-1] ^ d1[i]);
        qm_c[8] = ~use_xnor;
    end

    reg [8:0] qm2;
    reg       de2, c0_2, c1_2;
    reg [3:0] n1q2;

    always @(posedge clk) begin
        qm2  <= qm_c;
        de2  <= de1;
        c0_2 <= c0_1;
        c1_2 <= c1_1;
        n1q2 <= ones8(qm_c[7:0]);
    end

    // ---------------- stage 3: DC balancing --------------------------------
    // cnt is the running disparity (ones minus zeros) of the transmitted
    // stream; it is always even, range well inside -16..+16.
    reg  signed [5:0] cnt;
    wire signed [5:0] n1 = $signed({2'b00, n1q2});
    wire signed [5:0] n0 = 6'sd8 - n1;
    wire signed [5:0] diff = n1 - n0;                 // N1(q_m) - N0(q_m)

    always @(posedge clk) begin
        if (rst) begin
            cnt      <= 6'sd0;
            tmds_out <= 10'b1101010100;
        end else if (!de2) begin
            cnt <= 6'sd0;
            case ({c1_2, c0_2})
                2'b00:   tmds_out <= 10'b1101010100;
                2'b01:   tmds_out <= 10'b0010101011;
                2'b10:   tmds_out <= 10'b0101010100;
                default: tmds_out <= 10'b1010101011;
            endcase
        end else if ((cnt == 6'sd0) || (n1 == n0)) begin
            tmds_out[9]   <= ~qm2[8];
            tmds_out[8]   <=  qm2[8];
            tmds_out[7:0] <=  qm2[8] ? qm2[7:0] : ~qm2[7:0];
            if (qm2[8] == 1'b0)
                cnt <= cnt - diff;                     // + (N0 - N1)
            else
                cnt <= cnt + diff;                     // + (N1 - N0)
        end else if (((cnt > 6'sd0) && (n1 > n0)) || ((cnt < 6'sd0) && (n0 > n1))) begin
            tmds_out[9]   <= 1'b1;
            tmds_out[8]   <= qm2[8];
            tmds_out[7:0] <= ~qm2[7:0];
            cnt <= cnt + (qm2[8] ? 6'sd2 : 6'sd0) - diff;
        end else begin
            tmds_out[9]   <= 1'b0;
            tmds_out[8]   <= qm2[8];
            tmds_out[7:0] <= qm2[7:0];
            cnt <= cnt - (qm2[8] ? 6'sd0 : 6'sd2) + diff;
        end
    end

endmodule
