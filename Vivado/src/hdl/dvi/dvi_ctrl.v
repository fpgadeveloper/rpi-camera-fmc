// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// dvi_ctrl - maps the DVI output's control/status bits to a dual-channel
// AXI GPIO (channel 1 = status inputs, channel 2 = control outputs), so the
// link can be inspected and debugged from Linux without a custom driver.
//
// Status (GPIO channel 1, read only)
//   [0]     link ready (transceiver TX reset done, sequencer in RUN)
//   [1]     transceiver power good
//   [2]     transceiver TX reset done (raw)
//   [3]     gearbox FIFO streaming
//   [4]     FIFO underflow seen (sticky, clear with control[3])
//   [5]     FIFO overflow seen  (sticky, clear with control[3])
//   [6]     HDMI hot plug detect (sink present)
//   [7]     clock synthesiser loss-of-lock pin (raw level, board specific)
//   [15:8]  transceiver reset retries (saturating)
//   [19:16] gearbox FIFO watchdog recoveries (saturating, cleared by control[3])
//   [31:20] 12'hD72 (identifier: DVI, version 2)
// Control (GPIO channel 2, default 0x00000002)
//   [0]     transceiver reset request (hold 1, then 0)
//   [1]     HDMI TX enable pin (retimer/redriver enable), default 1
//   [2]     colour bar test pattern instead of the video input
//   [3]     clear sticky flags + watchdog count (hold 1, then 0)
//   [7:4]   TX lane polarity invert (lane 3..0)

`timescale 1ns / 1ps

module dvi_ctrl (
    input  wire        clk,              // AXI GPIO clock
    // AXI GPIO side
    input  wire [31:0] gpio_ctrl,        // from axi_gpio gpio2_io_o
    output wire [31:0] gpio_status,      // to axi_gpio gpio_io_i
    // control outputs
    output wire        gt_soft_reset,
    output wire        tx_en,
    output wire        test_pattern,
    output wire        clr_flags,
    output wire [3:0]  polarity,
    // status inputs (any clock domain)
    input  wire        link_ready,
    input  wire        gtpowergood,
    input  wire        tx_done,
    input  wire        fifo_running,
    input  wire        underflow,
    input  wire        overflow,
    input  wire        hpd,
    input  wire        clk_lol,
    input  wire [7:0]  retries,
    input  wire [3:0]  wd_count          // pixel clock domain
);

    assign gt_soft_reset = gpio_ctrl[0];
    assign tx_en         = gpio_ctrl[1];
    assign test_pattern  = gpio_ctrl[2];
    assign clr_flags     = gpio_ctrl[3];
    assign polarity      = gpio_ctrl[7:4];

    wire [7:0] st;
    xpm_cdc_array_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0), .WIDTH(8)) u_sync (
        .src_clk  (1'b0),
        .src_in   ({clk_lol, hpd, overflow, underflow, fifo_running, tx_done, gtpowergood, link_ready}),
        .dest_clk (clk),
        .dest_out (st));

    // retries is produced in this clock domain (dvi_gt_reset runs on the AXI clock)
    // debug counter: a read during an increment may be off by one count
    wire [3:0] wd;
    xpm_cdc_array_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0), .WIDTH(4)) u_wd_sync (
        .src_clk(1'b0), .src_in(wd_count), .dest_clk(clk), .dest_out(wd));

    assign gpio_status = {12'hD72, wd, retries, st};

endmodule
