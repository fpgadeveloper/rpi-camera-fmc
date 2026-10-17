################################################################
# DVI (HDMI-compatible) video output using only free IP
################################################################
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Opsero Electronic Design Inc.
#
# Drives the board's HDMI TX connector as a DVI 1.0 source, fixed 1080p60
# (148.5 MHz pixel clock, 1.485 Gb/s per TMDS lane), RGB 8 bpc, no audio.
# No licensed IP: the TMDS encoder is our own RTL (Vivado/src/hdl/dvi), the
# serializer is the free Versal Transceivers Wizard (gtwiz_versal).
#
# Structure (hierarchy <name>):
#
#   S_AXIS_VIDEO -> v_axi4s_vid_out -> dvi_tmds_core ----------------- front end
#   VTIMING_IN  ---------^               (TMDS encode, test pattern)   (device independent)
#   (from the design's v_tc, clocked by vid_clk / vid_resetn / vtg_ce / sof_state out)
#                        |
#                   vid_clk (148.5 MHz = GT reference clock / 1)
#                        |
#   phy/: util_ds_buf (IBUFDS_GTE5) -> gtwiz_versal (4 TX lanes) ---- back end
#         dvi_tx_gearbox (10b@148.5 -> 20b@74.25), dvi_gt_reset       (Versal GTY/GTYP)
#
#   axi_iic   : HDMI control I2C bus (clock synthesiser 8T49N241 @0x6C,
#               VCK190 SN65DP159 retimer @0x5E / VEK280 TMDS1204 redriver @0x5E)
#   axi_gpio  : status (ch1, in) / control (ch2, out) - see dvi_ctrl.v
#
# The board's 8T49N241 must be programmed to 148.5 MHz (Linux idt8t49n24x
# clock driver via the device tree) and the retimer/redriver configured over
# I2C (dvi-init script); until the reference clock is present the transceiver
# reset sequencer keeps retrying, so no ordering is required.
#
# Usage (from a block design script, after the video mixer exists):
#
#   source $origin_dir/src/bd/dvi_out.tcl
#   create_dvi_output video_output vck190      ;# or vek280
# then connect the hierarchy pins (same contract as the video_output stub in
# bd_versal.tcl, plus S_AXI_CTRL / irq_iic):
#   S_AXIS_VIDEO  <- v_mix m_axis_video (RGB, 8 bpc, 1 ppc, 24-bit tdata)
#   VTIMING_IN    <- v_tc vtiming_out (v_tc generator, 1080p60)
#   aclk/aresetn  <- the v_mix clock and reset
#   s_axi_aclk/s_axi_aresetn <- 100 MHz AXI-Lite clock/reset (also the GT free-running clock)
#   vid_clk       -> v_tc clk          vid_resetn -> v_tc resetn
#   vtg_ce        -> v_tc gen_clken    sof_state  -> v_tc sof_state
#   S_AXI_CTRL    <- AXI-Lite master (2 slaves inside: axi_iic, axi_gpio; 64 KB each)
#   irq_iic       -> PS interrupt
#
# The proc adds the RTL sources and the board's pin constraints
# (src/constraints/dvi_<board>.xdc) to the current project and creates the
# top-level ports hdmi_tx_refclk, hdmi_tx_txp/txn, hdmi_ctl_iic,
# hdmi_tx_en, hdmi_tx_hpd, hdmi_clk_lol.
#
# The v_mix feeding S_AXIS_VIDEO must output RGB (v_mix VIDEO_FORMAT 0),
# 8 bits per component, 1 sample per clock.

set dvi_script_dir [file normalize [file dirname [info script]]]

# Board specifics: transceiver type, the quad's reference clock input the
# 8T49N241 drives (R1 = GTREFCLK1 on both boards), lane carrying TMDS clock.
#   VCK190: GTY quad 106 (GTY_QUAD_X0Y6), refclk MGTREFCLK1_106 (E39/E40),
#           TX0..3 = F41/D41/B41/A43 -> SN65DP159 (U43); ctl pins bank 406 (3.3 V)
#   VEK280: GTYP bank 204 (GTYP_QUAD_X1Y2), refclk GTYP_REFCLK1_204 (AB30),
#           TX0..3 = R38/P36/N38/M36 -> TMDS1204 (U335); ctl pins bank 702 (1.5 V)
proc dvi_board_params { board } {
  switch -- $board {
    vck190 { return [dict create gt_type GTY  refclk R1 clk_lane 3] }
    vek280 { return [dict create gt_type GTYP refclk R1 clk_lane 3] }
    default { error "dvi_out.tcl: unsupported board '$board' (supported: vck190 vek280)" }
  }
}

# Add the RTL and board constraints to the current project (idempotent)
proc dvi_add_sources { board } {
  global dvi_script_dir
  set hdl_dir [file normalize "$dvi_script_dir/../hdl/dvi"]
  set files {}
  foreach f {dvi_tmds_encoder.v dvi_tmds_core.v dvi_tx_gearbox.v dvi_gt_reset.v dvi_ctrl.v} {
    set p "$hdl_dir/$f"
    if {[llength [get_files -quiet $p]] == 0} { lappend files $p }
  }
  if {[llength $files]} {
    add_files -norecurse -fileset [get_filesets sources_1] $files
  }
  set xdc [file normalize "$dvi_script_dir/../constraints/dvi_${board}.xdc"]
  if {[llength [get_files -quiet $xdc]] == 0} {
    add_files -norecurse -fileset [get_filesets constrs_1] $xdc
  }
  update_compile_order -fileset sources_1
}

# Versal transceiver back end: refclk buffer, pixel clock, gtwiz_versal,
# TX user clock, gearbox and reset sequencer.
proc create_dvi_versal_phy { parent name board } {
  set p [dvi_board_params $board]
  set gt_type  [dict get $p gt_type]
  set refsrc   [dict get $p refclk]
  set clk_lane [dict get $p clk_lane]

  set old [current_bd_instance .]
  current_bd_instance $parent
  set hier [create_bd_cell -type hier $name]
  current_bd_instance $hier

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 REFCLK
  create_bd_pin -dir I -from 29 -to 0 tmds_data
  create_bd_pin -dir I -type clk freerun_clk
  create_bd_pin -dir I -type rst freerun_resetn
  create_bd_pin -dir I -type rst pix_rst
  create_bd_pin -dir O -type clk pix_clk
  create_bd_pin -dir O -from 3 -to 0 txp
  create_bd_pin -dir O -from 3 -to 0 txn
  create_bd_pin -dir I soft_reset
  create_bd_pin -dir I -from 3 -to 0 polarity
  create_bd_pin -dir I clr_flags
  create_bd_pin -dir O link_ready
  create_bd_pin -dir O gtpowergood
  create_bd_pin -dir O tx_done
  create_bd_pin -dir O running
  create_bd_pin -dir O underflow
  create_bd_pin -dir O overflow
  create_bd_pin -dir O -from 7 -to 0 retries
  create_bd_pin -dir O -from 3 -to 0 wd_count

  # Reference clock input buffer (IBUFDS_GTE5): O -> transceiver, ODIV2 (= O) -> pixel clock
  set refbuf [create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf refclk_buf]
  set_property -dict [list CONFIG.C_BUF_TYPE {IBUFDSGTE} CONFIG.C_DIVBY2 {false}] $refbuf
  set pixbuf [create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf pixclk_buf]
  set_property CONFIG.C_BUF_TYPE {BUFG_GT} $pixbuf
  set one [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_one]
  set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] $one
  set zero [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_zero]
  set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] $zero

  # TX driver settings used by AMD's HDMI PHY driver for GTYE5/GTYP (xhdmiphy:
  # vs 0xD, pre/post-cursor 5) - same boards, same retimer/redriver.
  set c_diff [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_txdiffctrl]
  set_property -dict [list CONFIG.CONST_VAL {13} CONFIG.CONST_WIDTH {5}] $c_diff
  set c_cur [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_txcursor]
  set_property -dict [list CONFIG.CONST_VAL {5} CONFIG.CONST_WIDTH {5}] $c_cur

  # Transceiver: 4 TX lanes, 1.485 Gb/s, 20-bit, raw, LCPLL from 148.5 MHz
  set gt [create_bd_cell -type ip -vlnv xilinx.com:ip:gtwiz_versal gtwiz]
  set_property -dict [list \
    CONFIG.GT_TYPE $gt_type \
    CONFIG.INTF0_GT_DIRECTION {SIMPLEX_TX} \
    CONFIG.INTF0_NO_OF_LANES {4} \
    CONFIG.INTF0_GT_SETTINGS(GT_DIRECTION) {SIMPLEX_TX} \
    CONFIG.INTF0_GT_SETTINGS(GT_TYPE) $gt_type \
    CONFIG.INTF0_GT_SETTINGS(LR0_SETTINGS) "GT_DIRECTION SIMPLEX_TX TX_LINE_RATE 1.485 TX_PLL_TYPE LCPLL\
      TX_REFCLK_FREQUENCY 148.5 TX_DATA_ENCODING RAW TX_USER_DATA_WIDTH 20 TX_INT_DATA_WIDTH 20\
      TX_BUFFER_MODE 1 TX_OUTCLK_SOURCE TXOUTCLKPMA TX_REFCLK_SOURCE $refsrc" \
  ] $gt

  # TX user clock (74.25 MHz) from TXOUTCLK of lane 0
  set bufg_tx [create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_tx]

  set gbx [create_bd_cell -type module -reference dvi_tx_gearbox gearbox]
  set_property -dict [list CONFIG.CLK_LANE $clk_lane CONFIG.TXDATA_W {128}] $gbx
  set rst [create_bd_cell -type module -reference dvi_gt_reset gt_reset]

  # refclk
  connect_bd_intf_net [get_bd_intf_pins REFCLK] [get_bd_intf_pins refclk_buf/CLK_IN_D]
  connect_bd_net [get_bd_pins refclk_buf/IBUF_OUT] [get_bd_pins gtwiz/QUAD0_GTREFCLK0]
  connect_bd_net [get_bd_pins refclk_buf/IBUF_DS_ODIV2] [get_bd_pins pixclk_buf/BUFG_GT_I]
  connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins pixclk_buf/BUFG_GT_CE]
  connect_bd_net [get_bd_pins pixclk_buf/BUFG_GT_O] [get_bd_pins pix_clk] [get_bd_pins gearbox/pix_clk]

  # transceiver clocks / resets
  connect_bd_net [get_bd_pins freerun_clk] [get_bd_pins gtwiz/gtwiz_freerun_clk] [get_bd_pins gt_reset/clk]
  connect_bd_net [get_bd_pins freerun_resetn] [get_bd_pins gt_reset/rstn]
  connect_bd_net [get_bd_pins gtwiz/QUAD0_TX0_outclk] [get_bd_pins bufg_gt_tx/outclk]
  connect_bd_net [get_bd_pins bufg_gt_tx/usrclk] [get_bd_pins gearbox/tx_clk] \
    [get_bd_pins gtwiz/QUAD0_TX0_usrclk] [get_bd_pins gtwiz/QUAD0_TX1_usrclk] \
    [get_bd_pins gtwiz/QUAD0_TX2_usrclk] [get_bd_pins gtwiz/QUAD0_TX3_usrclk]
  connect_bd_net [get_bd_pins gt_reset/gt_rst_all] [get_bd_pins gtwiz/INTF0_rst_all_in]
  connect_bd_net [get_bd_pins const_zero/dout] [get_bd_pins gtwiz/INTF0_rst_tx_datapath_in] \
    [get_bd_pins gtwiz/INTF0_rst_tx_pll_and_datapath_in] [get_bd_pins gearbox/tx_rst]
  connect_bd_net [get_bd_pins gtwiz/INTF0_rst_tx_done_out] [get_bd_pins gt_reset/tx_done] [get_bd_pins tx_done]
  connect_bd_net [get_bd_pins gtwiz/gtpowergood] [get_bd_pins gt_reset/gtpowergood] [get_bd_pins gtpowergood]
  connect_bd_net [get_bd_pins soft_reset] [get_bd_pins gt_reset/soft_reset]
  connect_bd_net [get_bd_pins gt_reset/ready] [get_bd_pins gearbox/link_ready] [get_bd_pins link_ready]
  connect_bd_net [get_bd_pins gt_reset/retries] [get_bd_pins retries]

  # data path
  connect_bd_net [get_bd_pins tmds_data] [get_bd_pins gearbox/tmds_data]
  connect_bd_net [get_bd_pins pix_rst] [get_bd_pins gearbox/pix_rst]
  connect_bd_net [get_bd_pins polarity] [get_bd_pins gearbox/polarity]
  connect_bd_net [get_bd_pins clr_flags] [get_bd_pins gearbox/clr_flags]
  foreach i {0 1 2 3} {
    connect_bd_net [get_bd_pins gearbox/tx_data$i] [get_bd_pins gtwiz/INTF0_TX${i}_ch_txdata]
    connect_bd_net [get_bd_pins const_txdiffctrl/dout] [get_bd_pins gtwiz/INTF0_TX${i}_ch_txdiffctrl]
    connect_bd_net [get_bd_pins const_txcursor/dout] [get_bd_pins gtwiz/INTF0_TX${i}_ch_txprecursor] \
      [get_bd_pins gtwiz/INTF0_TX${i}_ch_txpostcursor]
  }
  connect_bd_net [get_bd_pins gearbox/running] [get_bd_pins running]
  connect_bd_net [get_bd_pins gearbox/underflow] [get_bd_pins underflow]
  connect_bd_net [get_bd_pins gearbox/overflow] [get_bd_pins overflow]
  connect_bd_net [get_bd_pins gearbox/wd_count] [get_bd_pins wd_count]
  connect_bd_net [get_bd_pins gtwiz/QUAD0_txp] [get_bd_pins txp]
  connect_bd_net [get_bd_pins gtwiz/QUAD0_txn] [get_bd_pins txn]

  current_bd_instance $old
  return $hier
}

# Complete DVI output hierarchy + top-level ports.
proc create_dvi_output { name board } {
  dvi_add_sources $board

  set old [current_bd_instance .]
  set hier [create_bd_cell -type hier $name]
  current_bd_instance $hier

  # ---- hierarchy pins ----
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_VIDEO
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:video_timing_rtl:2.0 VTIMING_IN
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_CTRL
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:diff_clock_rtl:1.0 REFCLK
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 HDMI_CTL_IIC
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -type rst aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir O -type intr irq_iic
  create_bd_pin -dir O -type clk vid_clk
  create_bd_pin -dir O -type rst vid_resetn
  create_bd_pin -dir O vtg_ce
  create_bd_pin -dir O sof_state
  create_bd_pin -dir O -from 3 -to 0 txp
  create_bd_pin -dir O -from 3 -to 0 txn
  create_bd_pin -dir O tx_en
  create_bd_pin -dir I hpd
  create_bd_pin -dir I clk_lol

  # ---- AXI-Lite control: one slave port, two peripherals ----
  set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_ctrl]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $sc
  connect_bd_intf_net [get_bd_intf_pins S_AXI_CTRL] [get_bd_intf_pins axi_ctrl/S00_AXI]
  connect_bd_net [get_bd_pins s_axi_aclk] [get_bd_pins axi_ctrl/aclk]
  connect_bd_net [get_bd_pins s_axi_aresetn] [get_bd_pins axi_ctrl/aresetn]

  # ---- front end: AXIS -> native video (timing from the external v_tc) ----
  set vo [create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out v_axi4s_vid_out_0]
  set_property -dict [list \
    CONFIG.C_HAS_ASYNC_CLK {1} \
    CONFIG.C_NATIVE_COMPONENT_WIDTH {8} \
    CONFIG.C_S_AXIS_VIDEO_DATA_WIDTH {8} \
    CONFIG.C_S_AXIS_VIDEO_FORMAT {2} \
    CONFIG.C_VTG_MASTER_SLAVE {1} \
  ] $vo

  set core [create_bd_cell -type module -reference dvi_tmds_core tmds_core]
  set ctrl [create_bd_cell -type module -reference dvi_ctrl dvi_ctrl]

  # pixel clock domain reset
  set prst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_pix]
  set one [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_one]
  set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] $one

  # ---- back end ----
  create_dvi_versal_phy $hier phy $board

  # ---- control I2C + status/control GPIO ----
  set iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_hdmi]
  set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_dvi]
  set_property -dict [list \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO_WIDTH {32} CONFIG.C_ALL_INPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_ALL_OUTPUTS_2 {1} \
    CONFIG.C_DOUT_DEFAULT_2 {0x00000002} \
  ] $gpio

  # AXI-Lite
  connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M00_AXI] [get_bd_intf_pins axi_iic_hdmi/S_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M01_AXI] [get_bd_intf_pins axi_gpio_dvi/S_AXI]
  connect_bd_net [get_bd_pins s_axi_aclk] \
    [get_bd_pins axi_iic_hdmi/s_axi_aclk] [get_bd_pins axi_gpio_dvi/s_axi_aclk] \
    [get_bd_pins dvi_ctrl/clk] [get_bd_pins phy/freerun_clk]
  connect_bd_net [get_bd_pins s_axi_aresetn] \
    [get_bd_pins axi_iic_hdmi/s_axi_aresetn] [get_bd_pins axi_gpio_dvi/s_axi_aresetn] \
    [get_bd_pins phy/freerun_resetn] [get_bd_pins rst_pix/ext_reset_in]

  # video path
  connect_bd_intf_net [get_bd_intf_pins S_AXIS_VIDEO] [get_bd_intf_pins v_axi4s_vid_out_0/video_in]
  connect_bd_intf_net [get_bd_intf_pins VTIMING_IN] [get_bd_intf_pins v_axi4s_vid_out_0/vtiming_in]
  connect_bd_net [get_bd_pins aclk] [get_bd_pins v_axi4s_vid_out_0/aclk]
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins v_axi4s_vid_out_0/aresetn]
  connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins v_axi4s_vid_out_0/aclken] \
    [get_bd_pins v_axi4s_vid_out_0/vid_io_out_ce] [get_bd_pins rst_pix/dcm_locked]
  connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vtg_ce] [get_bd_pins vtg_ce]
  connect_bd_net [get_bd_pins v_axi4s_vid_out_0/sof_state_out] [get_bd_pins sof_state]

  connect_bd_net [get_bd_pins phy/pix_clk] [get_bd_pins vid_clk] [get_bd_pins rst_pix/slowest_sync_clk] \
    [get_bd_pins v_axi4s_vid_out_0/vid_io_out_clk] [get_bd_pins tmds_core/pix_clk]
  connect_bd_net [get_bd_pins rst_pix/peripheral_aresetn] [get_bd_pins vid_resetn]
  connect_bd_net [get_bd_pins rst_pix/peripheral_reset] [get_bd_pins v_axi4s_vid_out_0/vid_io_out_reset] \
    [get_bd_pins tmds_core/pix_rst] [get_bd_pins phy/pix_rst]

  connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_data] [get_bd_pins tmds_core/vid_data]
  connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_active_video] [get_bd_pins tmds_core/vid_active_video]
  connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_hsync] [get_bd_pins tmds_core/vid_hsync]
  connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_vsync] [get_bd_pins tmds_core/vid_vsync]
  connect_bd_net [get_bd_pins tmds_core/tmds_data] [get_bd_pins phy/tmds_data]

  # control / status
  connect_bd_net [get_bd_pins axi_gpio_dvi/gpio2_io_o] [get_bd_pins dvi_ctrl/gpio_ctrl]
  connect_bd_net [get_bd_pins dvi_ctrl/gpio_status] [get_bd_pins axi_gpio_dvi/gpio_io_i]
  connect_bd_net [get_bd_pins dvi_ctrl/gt_soft_reset] [get_bd_pins phy/soft_reset]
  connect_bd_net [get_bd_pins dvi_ctrl/tx_en] [get_bd_pins tx_en]
  connect_bd_net [get_bd_pins dvi_ctrl/test_pattern] [get_bd_pins tmds_core/test_pattern]
  connect_bd_net [get_bd_pins dvi_ctrl/clr_flags] [get_bd_pins phy/clr_flags]
  connect_bd_net [get_bd_pins dvi_ctrl/polarity] [get_bd_pins phy/polarity]
  foreach s {link_ready gtpowergood tx_done underflow overflow retries wd_count} {
    connect_bd_net [get_bd_pins phy/$s] [get_bd_pins dvi_ctrl/$s]
  }
  connect_bd_net [get_bd_pins phy/running] [get_bd_pins dvi_ctrl/fifo_running]
  connect_bd_net [get_bd_pins hpd] [get_bd_pins dvi_ctrl/hpd]
  connect_bd_net [get_bd_pins clk_lol] [get_bd_pins dvi_ctrl/clk_lol]

  # I2C, interrupts, serial lanes, refclk
  connect_bd_intf_net [get_bd_intf_pins axi_iic_hdmi/IIC] [get_bd_intf_pins HDMI_CTL_IIC]
  connect_bd_net [get_bd_pins axi_iic_hdmi/iic2intc_irpt] [get_bd_pins irq_iic]
  connect_bd_net [get_bd_pins phy/txp] [get_bd_pins txp]
  connect_bd_net [get_bd_pins phy/txn] [get_bd_pins txn]
  connect_bd_intf_net [get_bd_intf_pins REFCLK] [get_bd_intf_pins phy/REFCLK]

  current_bd_instance $old

  # ---- top-level ports (names used by src/constraints/dvi_<board>.xdc) ----
  set refclk [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 hdmi_tx_refclk]
  set_property CONFIG.FREQ_HZ {148500000} $refclk
  connect_bd_intf_net $refclk [get_bd_intf_pins $name/REFCLK]
  create_bd_port -dir O -from 3 -to 0 hdmi_tx_txp
  create_bd_port -dir O -from 3 -to 0 hdmi_tx_txn
  connect_bd_net [get_bd_ports hdmi_tx_txp] [get_bd_pins $name/txp]
  connect_bd_net [get_bd_ports hdmi_tx_txn] [get_bd_pins $name/txn]
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 hdmi_ctl_iic
  connect_bd_intf_net [get_bd_intf_ports hdmi_ctl_iic] [get_bd_intf_pins $name/HDMI_CTL_IIC]
  create_bd_port -dir O hdmi_tx_en
  connect_bd_net [get_bd_ports hdmi_tx_en] [get_bd_pins $name/tx_en]
  create_bd_port -dir I hdmi_tx_hpd
  connect_bd_net [get_bd_ports hdmi_tx_hpd] [get_bd_pins $name/hpd]
  create_bd_port -dir I hdmi_clk_lol
  connect_bd_net [get_bd_ports hdmi_clk_lol] [get_bd_pins $name/clk_lol]

  return $hier
}
