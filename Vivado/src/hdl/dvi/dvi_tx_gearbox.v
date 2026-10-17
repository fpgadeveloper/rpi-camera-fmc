// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// dvi_tx_gearbox - TMDS symbols (10 bit/lane @ pixel clock) to a 20-bit
// transceiver TX interface (@ pixel clock / 2), plus the TMDS clock channel.
//
// Generic for any AMD transceiver run at 10x the pixel clock with a 20-bit
// TX user interface and LSB-first serialisation (Versal GTY/GTYP, UltraScale+
// GTH/GTY). The pixel clock and the TX user clock must be frequency locked
// (both derived from the same reference clock); their phase is arbitrary, the
// small asynchronous FIFO absorbs it.
//
// Output lane mapping: lane CLK_LANE carries the TMDS clock pattern, the other
// three lanes carry TMDS channels 0,1,2 in ascending order.
//
// The FIFO (32 deep) is primed to 8 words before reading starts, which leaves
// ample room for the pointer synchronisation latency; on underflow (only
// possible if the clocks are not locked or during reset) the data lanes send
// control tokens and the FIFO is re-primed. 'underflow' is a sticky flag in
// the tx_clk domain, cleared by tx_rst or clr_flags.
//
// link_ready (async, from the transceiver reset sequencer) holds the FIFO in
// reset until the TX user clock is running.
//
// Watchdog (pixel domain): if the link is ready but the FIFO has not been
// streaming for WD_CYCLES pixel clocks, or the FIFO overflows, the FIFO is
// reset (64 pixel clocks) and re-primes by itself. wd_count counts these
// recoveries (saturating). The sticky flags (underflow, overflow) survive the
// watchdog reset; they are cleared by clr_flags (or tx_rst / pix_rst). All clock domain crossings use
// XPM macros, which carry their own timing constraints.

`timescale 1ns / 1ps

module dvi_tx_gearbox #(
    parameter integer CLK_LANE  = 3,
    parameter integer TXDATA_W  = 20,     // width of the transceiver txdata port (Versal: 128); bits above 19 are 0
    parameter integer WD_CYCLES = 262144  // watchdog timeout in pixel clocks (1.8 ms at 148.5 MHz)
) (
    // pixel domain
    input  wire        pix_clk,
    input  wire        pix_rst,          // active high, synchronous to pix_clk
    input  wire        link_ready,       // async: transceiver TX is out of reset
    input  wire [29:0] tmds_data,        // {ch2, ch1, ch0}
    // transceiver TX user clock domain
    input  wire        tx_clk,
    input  wire        tx_rst,           // active high, synchronous to tx_clk
    input  wire [3:0]  polarity,         // per output lane invert (async, quasi-static)
    input  wire        clr_flags,        // async, quasi-static
    output wire [TXDATA_W-1:0] tx_data0,
    output wire [TXDATA_W-1:0] tx_data1,
    output wire [TXDATA_W-1:0] tx_data2,
    output wire [TXDATA_W-1:0] tx_data3,
    output reg         underflow,
    output reg         overflow,         // sticky, pix_clk domain: a word was dropped (FIFO full)
    output reg         running,          // FIFO primed and streaming (tx_clk domain)
    output reg  [3:0]  wd_count          // watchdog FIFO recoveries, saturating (pix_clk domain)
);

    localparam [9:0]  CTRL00  = 10'b1101010100;
    localparam [19:0] CLK_PAT = 20'b0000011111_0000011111;

    // ---------------- pixel domain: pack two symbols per lane ----------------
    reg        phase = 1'b0;
    reg [29:0] first;
    reg [59:0] wr_word;
    reg        wr_en = 1'b0;
    wire       wr_rst_busy;
    wire       full;
    reg        rd_ready = 1'b0;                  // tx domain: reader out of reset
    wire       wr_go;
    wire       ready_p;

    // writes start only once the reader is up, so the FIFO fills from empty
    // and settles at the priming level instead of filling up while the
    // reader is still held in reset
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_go_sync (
        .src_clk(1'b0), .src_in(rd_ready), .dest_clk(pix_clk), .dest_out(wr_go));
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_rdy_p_sync (
        .src_clk(1'b0), .src_in(link_ready), .dest_clk(pix_clk), .dest_out(ready_p));

    wire running_p, clr_p;
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_run_p_sync (
        .src_clk(1'b0), .src_in(running), .dest_clk(pix_clk), .dest_out(running_p));
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_clr_p_sync (
        .src_clk(1'b0), .src_in(clr_flags), .dest_clk(pix_clk), .dest_out(clr_p));

    // watchdog: link ready but not streaming for WD_CYCLES, or FIFO full -> reset the FIFO
    reg [18:0] wd_timer = 19'd0;
    reg [6:0]  wd_hold  = 7'd0;                  // [6] set while the reset pulse is active
    reg        fifo_rst = 1'b1;
    wire       wd_fire  = ~fifo_rst & ((wd_timer == WD_CYCLES - 1) | (wr_en & full));

    always @(posedge pix_clk) begin
        if (pix_rst) begin
            wd_timer <= 19'd0;
            wd_hold  <= 7'd0;
            wd_count <= 4'd0;
        end else begin
            if (clr_p)
                wd_count <= 4'd0;
            if (wd_hold != 7'd0) begin
                wd_hold  <= wd_hold - 7'd1;
                wd_timer <= 19'd0;
            end else if (wd_fire) begin
                wd_hold  <= 7'd64;
                wd_timer <= 19'd0;
                if (wd_count != 4'hF && !clr_p)
                    wd_count <= wd_count + 4'd1;
            end else if (ready_p && !running_p && !fifo_rst) begin
                wd_timer <= wd_timer + 19'd1;
            end else begin
                wd_timer <= 19'd0;
            end
        end
    end

    // FIFO reset (pix_clk domain): transceiver not ready, or watchdog recovery
    always @(posedge pix_clk) fifo_rst <= pix_rst | ~ready_p | (wd_hold != 7'd0);

    // sticky overflow flag: survives watchdog resets, cleared by clr_flags
    always @(posedge pix_clk) begin
        if (pix_rst || clr_p)
            overflow <= 1'b0;
        else if (wr_en && full)
            overflow <= 1'b1;
    end

    always @(posedge pix_clk) begin
        if (fifo_rst) begin
            phase    <= 1'b0;
            wr_en    <= 1'b0;
        end else begin
            phase <= ~phase;
            if (!phase) begin
                first <= tmds_data;
                wr_en <= 1'b0;
            end else begin
                // per lane: [9:0] = earlier symbol (sent first), [19:10] = later
                wr_word <= {tmds_data[29:20], first[29:20],
                            tmds_data[19:10], first[19:10],
                            tmds_data[9:0],   first[9:0]};
                wr_en   <= wr_go & ~wr_rst_busy;
            end
        end
    end

    // ---------------- clock domain crossing FIFO ----------------
    wire [59:0] rd_word;
    wire        rd_rst_busy;
    wire        empty;
    wire        data_valid;
    wire [5:0]  rd_count;
    reg         rd_en = 1'b0;

    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE    ("distributed"),
        .FIFO_WRITE_DEPTH    (32),
        .WRITE_DATA_WIDTH    (60),
        .READ_DATA_WIDTH     (60),
        .READ_MODE           ("std"),
        .FIFO_READ_LATENCY   (1),
        .RD_DATA_COUNT_WIDTH (6),
        .WR_DATA_COUNT_WIDTH (6),
        .USE_ADV_FEATURES    ("1400"),       // rd_data_count + data_valid
        .CDC_SYNC_STAGES     (2),
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .RELATED_CLOCKS      (0),
        .SIM_ASSERT_CHK      (0)
    ) u_fifo (
        .rst           (fifo_rst),
        .wr_clk        (pix_clk),
        .wr_en         (wr_en),
        .din           (wr_word),
        .full          (full),
        .wr_rst_busy   (wr_rst_busy),
        .rd_clk        (tx_clk),
        .rd_en         (rd_en),
        .dout          (rd_word),
        .empty         (empty),
        .data_valid    (data_valid),
        .rd_data_count (rd_count),
        .rd_rst_busy   (rd_rst_busy),
        .sleep         (1'b0),
        .injectsbiterr (1'b0),
        .injectdbiterr (1'b0),
        .overflow      (),
        .wr_ack        (),
        .almost_full   (),
        .prog_full     (),
        .wr_data_count (),
        .almost_empty  (),
        .underflow     (),
        .prog_empty    (),
        .sbiterr       (),
        .dbiterr       ()
    );

    // ---------------- TX domain ----------------
    wire [3:0] pol_t;
    wire       clr_t, ready_t;
    xpm_cdc_array_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0), .WIDTH(4)) u_pol_sync (
        .src_clk(1'b0), .src_in(polarity), .dest_clk(tx_clk), .dest_out(pol_t));
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_clr_sync (
        .src_clk(1'b0), .src_in(clr_flags), .dest_clk(tx_clk), .dest_out(clr_t));
    xpm_cdc_single #(.DEST_SYNC_FF(3), .SRC_INPUT_REG(0)) u_rdy_t_sync (
        .src_clk(1'b0), .src_in(link_ready), .dest_clk(tx_clk), .dest_out(ready_t));

    wire rd_rst = tx_rst | ~ready_t | rd_rst_busy;
    always @(posedge tx_clk) rd_ready <= ~rd_rst;

    // read control: start when primed, stop (and re-prime) on empty
    always @(posedge tx_clk) begin
        if (tx_rst || clr_t)
            underflow <= 1'b0;
        if (rd_rst) begin
            rd_en     <= 1'b0;
            running   <= 1'b0;
        end else begin
            if (!running) begin
                if (rd_count >= 6'd8) begin
                    running <= 1'b1;
                    rd_en   <= 1'b1;
                end
            end else if (empty) begin
                running   <= 1'b0;
                rd_en     <= 1'b0;
                underflow <= 1'b1;
            end
        end
    end

    wire [19:0] ch0 = data_valid ? rd_word[19:0]  : {CTRL00, CTRL00};
    wire [19:0] ch1 = data_valid ? rd_word[39:20] : {CTRL00, CTRL00};
    wire [19:0] ch2 = data_valid ? rd_word[59:40] : {CTRL00, CTRL00};

    // lane assignment: CLK_LANE gets the clock, data channels fill the rest in order
    wire [19:0] l0 = (CLK_LANE == 0) ? CLK_PAT : ch0;
    wire [19:0] l1 = (CLK_LANE == 0) ? ch0 : (CLK_LANE == 1) ? CLK_PAT : ch1;
    wire [19:0] l2 = (CLK_LANE <= 1) ? ch1 : (CLK_LANE == 2) ? CLK_PAT : ch2;
    wire [19:0] l3 = (CLK_LANE == 3) ? CLK_PAT : ch2;

    reg [19:0] q0, q1, q2, q3;
    always @(posedge tx_clk) begin
        q0 <= l0 ^ {20{pol_t[0]}};
        q1 <= l1 ^ {20{pol_t[1]}};
        q2 <= l2 ^ {20{pol_t[2]}};
        q3 <= l3 ^ {20{pol_t[3]}};
    end

    generate
        if (TXDATA_W > 20) begin : g_pad
            assign tx_data0 = {{(TXDATA_W-20){1'b0}}, q0};
            assign tx_data1 = {{(TXDATA_W-20){1'b0}}, q1};
            assign tx_data2 = {{(TXDATA_W-20){1'b0}}, q2};
            assign tx_data3 = {{(TXDATA_W-20){1'b0}}, q3};
        end else begin : g_nopad
            assign tx_data0 = q0;
            assign tx_data1 = q1;
            assign tx_data2 = q2;
            assign tx_data3 = q3;
        end
    endgenerate

endmodule
