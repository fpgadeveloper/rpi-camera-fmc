// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// dvi_tmds_core - device-independent DVI front end.
//
// Takes the native video output of a Xilinx v_axi4s_vid_out (RGB 8 bpc,
// 1 pixel per clock, AXI4-Stream video component order: [7:0]=G, [15:8]=B,
// [23:16]=R) plus DE/HSYNC/VSYNC and produces the three TMDS data channel
// symbols for a DVI 1.0 link (no HDMI data islands, no audio):
//   ch0 = blue  (C0 = HSYNC, C1 = VSYNC during blanking)
//   ch1 = green (C0 = C1 = 0)
//   ch2 = red   (C0 = C1 = 0)
// The TMDS clock channel (10'b0000011111 every pixel) is produced by the
// serializer back end; it does not depend on the video.
//
// test_pattern = 1 outputs 8 vertical colour bars with the core's OWN fixed
// 1080p60 timing (CEA-861 VIC 16: 2200 x 1125 total, HS/VS active high), so
// the DVI link can be brought up without the v_tc / mixer / Linux DRM path
// (the input video and timing are ignored while the pattern is on).
//
// Latency: 4 pixel clocks (1 input register + 3 encoder stages).

`timescale 1ns / 1ps

module dvi_tmds_core #(
    parameter integer BAR_WIDTH = 240,       // 1920 / 8
    // internal test-pattern timing (default 1080p60 at 148.5 MHz)
    parameter integer H_ACTIVE  = 1920,
    parameter integer H_FP      = 88,
    parameter integer H_SYNC    = 44,
    parameter integer H_TOTAL   = 2200,
    parameter integer V_ACTIVE  = 1080,
    parameter integer V_FP      = 4,
    parameter integer V_SYNC    = 5,
    parameter integer V_TOTAL   = 1125
) (
    input  wire        pix_clk,
    input  wire        pix_rst,              // active high, synchronous to pix_clk
    input  wire [23:0] vid_data,
    input  wire        vid_active_video,
    input  wire        vid_hsync,
    input  wire        vid_vsync,
    input  wire        test_pattern,         // async (quasi-static), synchronised here
    output wire [29:0] tmds_data             // {ch2, ch1, ch0}, bit 0 of each sent first
);

    // ---- synchronise the quasi-static test pattern enable ----
    wire tp_en;
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_tp_sync (
        .src_clk(1'b0), .src_in(test_pattern), .dest_clk(pix_clk), .dest_out(tp_en));

    // ---- internal test-pattern timing generator ----
    reg [11:0] h_cnt = 12'd0;
    reg [11:0] v_cnt = 12'd0;
    always @(posedge pix_clk) begin
        if (pix_rst) begin
            h_cnt <= 12'd0;
            v_cnt <= 12'd0;
        end else if (h_cnt == H_TOTAL - 1) begin
            h_cnt <= 12'd0;
            v_cnt <= (v_cnt == V_TOTAL - 1) ? 12'd0 : v_cnt + 12'd1;
        end else begin
            h_cnt <= h_cnt + 12'd1;
        end
    end
    wire tg_de = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
    wire tg_hs = (h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC);
    wire tg_vs = (v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC);

    // ---- colour bar generator (counts pixels within the active line) ----
    reg [2:0]  bar   = 3'd0;
    reg [11:0] bar_px = 12'd0;
    always @(posedge pix_clk) begin
        if (pix_rst || !tg_de) begin
            bar    <= 3'd0;
            bar_px <= 12'd0;
        end else begin
            if (bar_px == BAR_WIDTH - 1) begin
                bar_px <= 12'd0;
                bar    <= bar + 3'd1;
            end else begin
                bar_px <= bar_px + 12'd1;
            end
        end
    end

    // bars: white, yellow, cyan, green, magenta, red, blue, black (75% level)
    reg [7:0] tp_r, tp_g, tp_b;
    always @(*) begin
        tp_r = (bar == 3'd0 || bar == 3'd1 || bar == 3'd4 || bar == 3'd5) ? 8'd191 : 8'd0;
        tp_g = (bar == 3'd0 || bar == 3'd1 || bar == 3'd2 || bar == 3'd3) ? 8'd191 : 8'd0;
        tp_b = (bar == 3'd0 || bar == 3'd2 || bar == 3'd4 || bar == 3'd6) ? 8'd191 : 8'd0;
    end

    // ---- input register ----
    reg [7:0] r_q, g_q, b_q;
    reg       de_q, hs_q, vs_q;
    always @(posedge pix_clk) begin
        r_q  <= tp_en ? tp_r : vid_data[23:16];
        g_q  <= tp_en ? tp_g : vid_data[7:0];
        b_q  <= tp_en ? tp_b : vid_data[15:8];
        de_q <= tp_en ? tg_de : vid_active_video;
        hs_q <= tp_en ? tg_hs : vid_hsync;
        vs_q <= tp_en ? tg_vs : vid_vsync;
    end

    wire [9:0] sym0, sym1, sym2;

    dvi_tmds_encoder enc_b (
        .clk(pix_clk), .rst(pix_rst), .din(b_q), .de(de_q),
        .c0(hs_q), .c1(vs_q), .tmds_out(sym0));

    dvi_tmds_encoder enc_g (
        .clk(pix_clk), .rst(pix_rst), .din(g_q), .de(de_q),
        .c0(1'b0), .c1(1'b0), .tmds_out(sym1));

    dvi_tmds_encoder enc_r (
        .clk(pix_clk), .rst(pix_rst), .din(r_q), .de(de_q),
        .c0(1'b0), .c1(1'b0), .tmds_out(sym2));

    assign tmds_data = {sym2, sym1, sym0};

endmodule
