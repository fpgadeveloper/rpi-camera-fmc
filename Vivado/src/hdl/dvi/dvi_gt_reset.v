// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// dvi_gt_reset - self-retrying reset sequencer for a TX-only transceiver.
//
// The DVI reference clock comes from an I2C-programmed clock synthesiser that
// is only set up once Linux (or u-boot) runs, i.e. long after the PL is
// configured. This block keeps (re)issuing the transceiver's "reset all"
// until the wizard reports TX reset done, so no software has to sequence the
// GT: as soon as the reference clock appears the link comes up by itself.
// It also restarts the sequence if reset-done drops (reference clock lost)
// or when software requests it.
//
//   - wait for gtpowergood
//   - assert gt_rst_all for RST_CYCLES
//   - wait up to TIMEOUT_CYCLES for tx_done; on timeout: retry
//   - RUN: ready = 1; leave on !tx_done or soft_reset
//
// All inputs except rstn are asynchronous and synchronised here.

`timescale 1ns / 1ps

module dvi_gt_reset #(
    parameter integer RST_CYCLES     = 1000,       // 10 us at 100 MHz
    parameter integer TIMEOUT_CYCLES = 5000000     // 50 ms at 100 MHz
) (
    input  wire       clk,            // free-running clock (AXI-Lite clock)
    input  wire       rstn,           // active low, synchronous to clk
    input  wire       gtpowergood,
    input  wire       tx_done,        // wizard: rst_tx_done_out
    input  wire       soft_reset,     // software request (level)
    output reg        gt_rst_all,     // to wizard: rst_all_in
    output reg        ready,          // link up (tx_done seen, synchronous to clk)
    output reg  [7:0] retries         // saturating count of timeouts
);

    wire pg, done, sreq;
    xpm_cdc_array_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0), .WIDTH(3)) u_sync (
        .src_clk(1'b0), .src_in({soft_reset, tx_done, gtpowergood}),
        .dest_clk(clk), .dest_out({sreq, done, pg}));

    localparam [1:0] S_PG = 2'd0, S_RST = 2'd1, S_WAIT = 2'd2, S_RUN = 2'd3;
    reg [1:0]  state;
    reg [22:0] timer;

    always @(posedge clk) begin
        if (!rstn) begin
            state      <= S_PG;
            timer      <= 23'd0;
            gt_rst_all <= 1'b1;
            ready      <= 1'b0;
            retries    <= 8'd0;
        end else begin
            case (state)
                S_PG: begin
                    gt_rst_all <= 1'b1;
                    ready      <= 1'b0;
                    timer      <= 23'd0;
                    if (pg && !sreq)
                        state <= S_RST;
                end
                S_RST: begin
                    gt_rst_all <= 1'b1;
                    if (timer == RST_CYCLES - 1) begin
                        timer <= 23'd0;
                        state <= S_WAIT;
                    end else begin
                        timer <= timer + 23'd1;
                    end
                end
                S_WAIT: begin
                    gt_rst_all <= 1'b0;
                    if (sreq) begin
                        state <= S_PG;
                    end else if (done) begin
                        state <= S_RUN;
                    end else if (timer == TIMEOUT_CYCLES - 1) begin
                        timer <= 23'd0;
                        if (retries != 8'hFF)
                            retries <= retries + 8'd1;
                        state <= S_PG;
                    end else begin
                        timer <= timer + 23'd1;
                    end
                end
                default: begin // S_RUN
                    gt_rst_all <= 1'b0;
                    ready      <= 1'b1;
                    if (!done || sreq || !pg) begin
                        ready <= 1'b0;
                        state <= S_PG;
                    end
                end
            endcase
        end
    end

endmodule
