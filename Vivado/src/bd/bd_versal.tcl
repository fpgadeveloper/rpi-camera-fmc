################################################################
# Block design build script for Versal designs (VCK190, VEK280)
################################################################
#
# Sourced by build.tcl, which sets:
#   block_name = rpi
#   board_name = vck190 | vek280
#   target     = vck190_fmcp1 | vck190_fmcp2 | vek280
#   cams       = the enabled cameras, e.g. { 0 2 }
#
# Camera pipeline (one per enabled camera, same as the Zynq UltraScale+ design):
#   mipi_csi2_rx_subsystem (D-PHY in XPIO) -> axis_data_fifo -> ISPPipeline (HLS)
#     -> v_proc_ss (scaler + CSC) -> v_frmbuf_wr -> NoC -> DDR
# Display path:
#   v_mix (reads the frame buffers through the NoC) + v_tc
#     -> video_output (DVI over HDMI, src/bd/dvi_out.tcl)
#
# The camera set is limited per FMC slot by the Versal XPHY clocking rules (each
# camera's clock lane needs its own nibble / strobe path): see the target XDCs.
#
################################################################
# PMC EMIO GPIOs are connected as follows (same bit map as the ZynqMP EMIO GPIOs):
################################################################
# 0  - Reserved (VCU on ZynqMP)
# 1  - Video Mixer IP reset
# 2-7 Reserved
# 8  - CAM0 ISPPipeline IP reset
# 9  - CAM0 Vproc IP reset
# 10 - CAM0 Frame Buffer Write IP reset
# 16 - CAM1 ISPPipeline IP reset
# 17 - CAM1 Vproc IP reset
# 18 - CAM1 Frame Buffer Write IP reset
# 24 - CAM2 ISPPipeline IP reset
# 25 - CAM2 Vproc IP reset
# 26 - CAM2 Frame Buffer Write IP reset
# 32 - CAM3 ISPPipeline IP reset
# 33 - CAM3 Vproc IP reset
# 34 - CAM3 Frame Buffer Write IP reset
#
################################################################
# PL-to-PS interrupts
################################################################
# pl_ps_irq0 - axi_intc_0 (all camera pipeline interrupts)
# pl_ps_irq1 - v_mix
# pl_ps_irq2 - v_tc
# pl_ps_irq3 - video_output axi_iic (HDMI control I2C)
# pl_ps_irq4..15 - free

# CHECKING IF PROJECT EXISTS
if { [get_projects -quiet] eq "" } {
   puts "ERROR: Please open or create a project!"
   return 1
}

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

create_bd_design $block_name

current_bd_design $block_name

set parentCell [get_bd_cells /]

# Get object for parentCell
set parentObj [get_bd_cells $parentCell]
if { $parentObj == "" } {
   puts "ERROR: Unable to find parent cell <$parentCell>!"
   return
}

# Make sure parentObj is hier blk
set parentType [get_property TYPE $parentObj]
if { $parentType ne "hier" } {
   puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
   return
}

# Save current instance; Restore later
set oldCurInst [current_bd_instance .]

# Set parent object as current
current_bd_instance $parentObj

# Returns true if str contains substr
proc str_contains {str substr} {
  if {[string first $substr $str] == -1} {
    return 0
  } else {
    return 1
  }
}

# Target board checks
set is_vck190 [str_contains $board_name "vck190"]
set is_vek280 [str_contains $board_name "vek280"]
if { !$is_vck190 && !$is_vek280 } {
  error "bd_versal.tcl: unsupported board $board_name (only vck190 and vek280)"
}

# DVI (HDMI-compatible) video output on the board's HDMI TX connector (free IP only)
source $origin_dir/src/bd/dvi_out.tcl
if {$is_vek280} { set dvi_board vek280 } else { set dvi_board vck190 }

# Clock and reset selections
set cam_clk clk_wizard_0/clk_250M
set cam_rst rst_video_250M
set display_clk clk_wizard_0/clk_250M
set display_rst rst_video_250M
set lite_clk clk_wizard_0/clk_100M
set lite_rst rst_ps_axi_100M

# Width of the PMC EMIO GPIO output bus
set emio_width 64

# Video pipe max res has impact on resource usage
set max_cols 1920
set max_rows 1232

# Set the samples-per-clock for the video pipelines (1)
set samples_pc 1

# Procedure for creating a MIPI pipe for one camera. Ported from bd_zynqmp.tcl:
# the cell names are unchanged (so the device-tree labels match the ZynqMP BSPs);
# on Versal the D-PHY pins come only from the XDC (no IO_LOC/bank parameters)
# and the per-pipe AXI-Lite interconnects are SmartConnects.
proc create_mipi_pipe { index } {
  set hier_obj [create_bd_cell -type hier mipi_$index]
  current_bd_instance $hier_obj
  global samples_pc
  global max_cols
  global max_rows
  global emio_width

  # Create pins of the block
  create_bd_pin -dir I dphy_clk_200M
  create_bd_pin -dir I s_axi_lite_aclk
  create_bd_pin -dir I aresetn
  create_bd_pin -dir I video_aclk
  create_bd_pin -dir I video_aresetn
  create_bd_pin -dir O mipi_sub_irq
  create_bd_pin -dir O isppipeline_irq
  create_bd_pin -dir O frmbufwr_irq
  create_bd_pin -dir O iic2intc_irpt
  create_bd_pin -dir I -from [expr {$emio_width-1}] -to 0 emio_gpio

  # Create the interfaces of the block
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_CTRL
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_VIDEO
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_mm_video
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 mipi_phy_if
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 IIC
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 GPIO

  # Add and configure the MIPI CSI-2 RX Subsystem (Versal: D-PHY in the XPIO bank,
  # SupportLevel 1 = the D-PHY XPLL/clocking is inside the core)
  set mipi_csi2_rx_subsyst [ create_bd_cell -type ip -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem mipi_csi2_rx_subsyst_0 ]
  set_property -dict [ list \
    CONFIG.SupportLevel {1} \
    CONFIG.CMN_NUM_LANES {2} \
    CONFIG.CMN_PXL_FORMAT {RAW10} \
    CONFIG.C_DPHY_LANES {2} \
    CONFIG.CMN_NUM_PIXELS $samples_pc \
    CONFIG.C_EN_CSI_V2_0 {true} \
    CONFIG.C_HS_LINE_RATE {420} \
    CONFIG.C_HS_SETTLE_NS {158} \
    CONFIG.DPY_LINE_RATE {420} \
  ] $mipi_csi2_rx_subsyst

  # AXI-Lite SmartConnect (100 MHz): CSI-2 RX, IIC, GPIO
  set axi_int_ctrl [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_int_ctrl ]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $axi_int_ctrl

  # AXI-Lite SmartConnect (video clock): ISPPipeline, Frame Buffer Write, VPSS
  set axi_int_video [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_int_video ]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $axi_int_video

  # Add the AXI4 Streaming Data FIFO
  set axis_data_fifo [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo axis_data_fifo]
  set_property CONFIG.FIFO_DEPTH {4096} $axis_data_fifo

  # Add the ISPPipeline
  set isppipeline [ create_bd_cell -type ip -vlnv xilinx.com:hls:ISPPipeline_accel:1.0 isppipeline ]

  # Add and configure the Video Processor subsystem
  set v_proc [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_proc_ss v_proc ]
  set_property -dict [ list \
    CONFIG.C_MAX_COLS $max_cols \
    CONFIG.C_MAX_ROWS $max_rows \
    CONFIG.C_ENABLE_DMA {false} \
    CONFIG.C_MAX_DATA_WIDTH {8} \
    CONFIG.C_TOPOLOGY {0} \
    CONFIG.C_SCALER_ALGORITHM {2} \
    CONFIG.C_ENABLE_CSC {true} \
    CONFIG.C_SAMPLES_PER_CLK $samples_pc \
  ] $v_proc

  # Add and configure the Video Frame Buffer Write
  set v_frmbuf_wr [create_bd_cell -type ip -vlnv xilinx.com:ip:v_frmbuf_wr v_frmbuf_wr]
  set_property -dict [list \
   CONFIG.C_M_AXI_MM_VIDEO_DATA_WIDTH {128} \
   CONFIG.SAMPLES_PER_CLOCK $samples_pc \
   CONFIG.AXIMM_DATA_WIDTH {128} \
   CONFIG.HAS_BGR8 {1} \
   CONFIG.HAS_Y_UV8_420 {1} \
   CONFIG.HAS_YUYV8 {1} \
   CONFIG.MAX_NR_PLANES {2} \
   CONFIG.MAX_COLS $max_cols \
   CONFIG.MAX_ROWS $max_rows \
  ] $v_frmbuf_wr

  # Reset slices from the PMC EMIO GPIO: ISPPipeline (+0), Vproc (+1), Frmbuf WR (+2)
  foreach {name offset pin} {reset_isppipeline 0 isppipeline/ap_rst_n \
                             reset_v_proc 1 v_proc/aresetn_ctrl \
                             reset_frmbuf_wr 2 v_frmbuf_wr/ap_rst_n} {
    set emio_gpio_index [expr {8*($index+1)+$offset}]
    set slice [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 $name ]
    set_property -dict [ list \
      CONFIG.DIN_WIDTH $emio_width \
      CONFIG.DIN_TO $emio_gpio_index \
      CONFIG.DIN_FROM $emio_gpio_index \
      CONFIG.DOUT_WIDTH {1} \
    ] $slice
    connect_bd_net -net ${name}_Dout [get_bd_pins $name/Dout] [get_bd_pins $pin]
    connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins $name/Din]
  }

  # Add and configure AXI IIC
  set axi_iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_0]

  # Add and configure AXI GPIO
  set axi_gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0]
  set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_DOUT_DEFAULT {0x00000001} ] $axi_gpio

  # Connect the 200M D-PHY clock
  connect_bd_net [get_bd_pins dphy_clk_200M] [get_bd_pins mipi_csi2_rx_subsyst_0/dphy_clk_200M]
  # Connect the video clock
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins mipi_csi2_rx_subsyst_0/video_aclk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_frmbuf_wr/ap_clk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_proc/aclk_axis]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_proc/aclk_ctrl]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axis_data_fifo/s_axis_aclk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins isppipeline/ap_clk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/aclk]
  # Connect the 100M AXI-Lite clock
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_int_ctrl/aclk]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins mipi_csi2_rx_subsyst_0/lite_aclk]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_iic_0/s_axi_aclk]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk]
  # Connect the video resets
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/aresetn]
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins mipi_csi2_rx_subsyst_0/video_aresetn]
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axis_data_fifo/s_axis_aresetn]
  # Connect the AXI-Lite resets
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_int_ctrl/aresetn]
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins mipi_csi2_rx_subsyst_0/lite_aresetn]
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_iic_0/s_axi_aresetn]
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
  # Connect AXI Lite CTRL interfaces
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins S_AXI_CTRL] [get_bd_intf_pins axi_int_ctrl/S00_AXI]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_ctrl/M00_AXI] [get_bd_intf_pins mipi_csi2_rx_subsyst_0/csirxss_s_axi]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_ctrl/M01_AXI] [get_bd_intf_pins axi_iic_0/S_AXI]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_ctrl/M02_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
  # Connect AXI Lite VIDEO interfaces
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins S_AXI_VIDEO] [get_bd_intf_pins axi_int_video/S00_AXI]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M00_AXI] [get_bd_intf_pins isppipeline/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M01_AXI] [get_bd_intf_pins v_frmbuf_wr/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M02_AXI] [get_bd_intf_pins v_proc/s_axi_ctrl]
  # Connect the AXI Streaming interfaces
  connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_subsyst_0/video_out] [get_bd_intf_pins axis_data_fifo/S_AXIS]
  connect_bd_intf_net [get_bd_intf_pins axis_data_fifo/M_AXIS] [get_bd_intf_pins isppipeline/s_axis_video]
  connect_bd_intf_net [get_bd_intf_pins isppipeline/m_axis_video] [get_bd_intf_pins v_proc/s_axis]
  connect_bd_intf_net [get_bd_intf_pins v_proc/m_axis] [get_bd_intf_pins v_frmbuf_wr/s_axis_video]
  # Connect the MIPI D-PHY interface
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins mipi_phy_if] [get_bd_intf_pins mipi_csi2_rx_subsyst_0/mipi_phy_if]
  # Connect the Frame Buffer MM interface
  connect_bd_intf_net [get_bd_intf_pins m_axi_mm_video] [get_bd_intf_pins v_frmbuf_wr/m_axi_mm_video]
  # Connect the I2C interface
  connect_bd_intf_net [get_bd_intf_pins IIC] [get_bd_intf_pins axi_iic_0/IIC]
  # Connect the GPIO interface
  connect_bd_intf_net [get_bd_intf_pins GPIO] [get_bd_intf_pins axi_gpio_0/GPIO]
  # Connect interrupts
  connect_bd_net [get_bd_pins mipi_sub_irq] [get_bd_pins mipi_csi2_rx_subsyst_0/csirxss_csi_irq]
  connect_bd_net [get_bd_pins isppipeline_irq] [get_bd_pins isppipeline/interrupt]
  connect_bd_net [get_bd_pins frmbufwr_irq] [get_bd_pins v_frmbuf_wr/interrupt]
  connect_bd_net [get_bd_pins iic2intc_irpt] [get_bd_pins axi_iic_0/iic2intc_irpt]

  current_bd_instance \
}

# AXI Lite ports: lists of {interface clock reset}
set fpd_ports {}
set lpd_ports {}

# List of interrupt pins (AXI Intc and direct PL-PS-IRQ)
set intr_list {}

# Number of cameras
set num_cams [llength $cams]

#########################################################
# CIPS, NoC and DDR
#########################################################

# Add the CIPS
create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0

# Configure the CIPS using the automation feature (board preset, NoC + 1 memory controller)
if {$is_vek280} {
  apply_bd_automation -rule xilinx.com:bd_rule:cips -config { \
    board_preset {Yes} \
    boot_config {Custom} \
    configure_noc {Add new AXI NoC} \
    debug_config {JTAG} \
    design_flow {Full System} \
    mc_type {LPDDR} \
    num_mc_ddr {None} \
    num_mc_lpddr {1} \
    pl_clocks {None} \
    pl_resets {None} \
  }  [get_bd_cells versal_cips_0]
} else {
  apply_bd_automation -rule xilinx.com:bd_rule:cips -config { \
    board_preset {Yes} \
    boot_config {Custom} \
    configure_noc {Add new AXI NoC} \
    debug_config {JTAG} \
    design_flow {Full System} \
    mc_type {DDR} \
    num_mc_ddr {1} \
    num_mc_lpddr {None} \
    pl_clocks {None} \
    pl_resets {None} \
  }  [get_bd_cells versal_cips_0]
}

# Extra PS PMC config for this design (from the sibling Opsero Versal designs)
# - PL CLK0 = 100 MHz (clock wizard input)
# - M_AXI_FPD (video-clock control) + M_AXI_LPD (100 MHz control)
# - PMC GPIO EMIO (IP resets), PL-to-PS interrupts IRQ0-15, one fabric reset
# - GEM0 = board RJ45 (PS MIO 0..11, MDIO PS MIO 24..25)
if {$is_vek280} {
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.PS_BOARD_INTERFACE {Custom} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DEBUG_MODE {JTAG} \
      DESIGN_MODE {1} \
      DEVICE_INTEGRITY_MODE {Sysmon temperature voltage and external IO monitoring} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_GPIO_EMIO_PERIPHERAL_ENABLE {1} \
      PMC_MIO12 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_MIO38 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_REF_CLK_FREQMHZ {33.3333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x36} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {Custom} \
      PS_CAN0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 14 .. 15}}} \
      PS_CAN1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 16 .. 17}}} \
      PS_CRL_CAN0_REF_CTRL_FREQMHZ {160} \
      PS_CRL_CAN1_REF_CTRL_FREQMHZ {160} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_HSDP_EGRESS_TRAFFIC {JTAG} \
      PS_HSDP_INGRESS_TRAFFIC {JTAG} \
      PS_HSDP_MODE {NONE} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_I2CSYSMON_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 39 .. 40}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PS_MIO 18} \
      PS_PCIE_EP_RESET2_IO {PS_MIO 19} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_TTC0_PERIPHERAL_ENABLE {1} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_FPD {1} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {0} \
      PS_USE_PMCPL_CLK2 {0} \
      PS_USE_PMCPL_CLK3 {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_INTERFACE_TO_USE {I2C} \
      SMON_PMBUS_ADDRESS {0x18} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] [get_bd_cells versal_cips_0]
} else {
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.PS_BOARD_INTERFACE {Custom} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DEBUG_MODE {JTAG} \
      DESIGN_MODE {1} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_GPIO_EMIO_PERIPHERAL_ENABLE {1} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_OSPI_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_QSPI_COHERENCY {0} \
      PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
      PMC_QSPI_PERIPHERAL_DATA_MODE {x4} \
      PMC_QSPI_PERIPHERAL_ENABLE {1} \
      PMC_QSPI_PERIPHERAL_MODE {Dual Parallel} \
      PMC_REF_CLK_FREQMHZ {33.3333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_COHERENCY {0} \
      PMC_SD1_DATA_TRANSFER_MODE {8Bit} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x36} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {Custom} \
      PS_CAN1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 40 .. 41}}} \
      PS_CRL_CAN1_REF_CTRL_FREQMHZ {160} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_ENET1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 12 .. 23}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_HSDP_EGRESS_TRAFFIC {JTAG} \
      PS_HSDP_INGRESS_TRAFFIC {JTAG} \
      PS_HSDP_MODE {NONE} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
      PS_MIO19 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO21 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PMC_MIO 38} \
      PS_PCIE_EP_RESET2_IO {PMC_MIO 39} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_TTC0_PERIPHERAL_ENABLE {1} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_FPD {1} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {0} \
      PS_USE_PMCPL_CLK2 {0} \
      PS_USE_PMCPL_CLK3 {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] [get_bd_cells versal_cips_0]
}

# Clock wizard: 100 MHz AXI-Lite and 250 MHz video clocks
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard clk_wizard_0
set_property -dict [list \
  CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
  CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
  CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
  CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
  CONFIG.CLKOUT_PORT {clk_100M,clk_250M,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
  CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
  CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {100.000,250.000,100.000,100.000,100.000,100.000,100.000} \
  CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
  CONFIG.CLKOUT_USED {true,true,false,false,false,false,false} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.USE_RESET {true} \
  CONFIG.RESET_TYPE {ACTIVE_LOW} \
] [get_bd_cells clk_wizard_0]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins clk_wizard_0/clk_in1]
connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins clk_wizard_0/resetn]

# D-PHY 200 MHz reference clocks: ONE CLOCK WIZARD (MMCM) PER XPIO BANK that holds
# cameras. Each CSI-2 RX (SupportLevel 1) has its own XPLL in its camera's bank.
# Placer rules: the BUFGCE driving an XPLL must be in the XPLL's clock region
# (rule_bufg_xpll) and an MMCM must be in the same clock region as the BUFGCEs it
# drives (rule_mmcm_bufg). So an MMCM can only feed the XPLLs of its own bank:
# a shared 200 MHz clock for cameras in two banks fails placement ([Place 30-6831] /
# [Place 30-674], seen on vck190_fmcp1). Cameras in the same bank share a wizard.
dict set dphy_groups vck190_fmcp1 { {0} {2} }
dict set dphy_groups vck190_fmcp2 { {1 2} {3} }
dict set dphy_groups vek280       { {0 1} {3} }
set dphy_index 0
foreach grp [dict get $dphy_groups $target] {
  set wiz dphy_clk_wiz_$dphy_index
  create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard $wiz
  set_property -dict [list \
    CONFIG.CLKOUT_PORT {clk_200M,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {200.000,100.000,100.000,100.000,100.000,100.000,100.000} \
    CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] [get_bd_cells $wiz]
  connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins $wiz/clk_in1]
  connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins $wiz/resetn]
  foreach i $grp { set dphy_clk($i) $wiz/clk_200M }
  incr dphy_index
}
foreach i $cams {
  if {![info exists dphy_clk($i)]} { error "bd_versal.tcl: CAM$i has no D-PHY clock group for $target" }
}

# Processor system resets for the 100 MHz AXI-Lite clock and the 250 MHz video clock
foreach {rst clk} [list rst_ps_axi_100M $lite_clk rst_video_250M $cam_clk] {
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset $rst
  connect_bd_net [get_bd_pins $clk] [get_bd_pins $rst/slowest_sync_clk]
  connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins $rst/ext_reset_in]
  connect_bd_net [get_bd_pins clk_wizard_0/locked] [get_bd_pins $rst/dcm_locked]
}

# PS master interface clocks
connect_bd_net [get_bd_pins $lite_clk] [get_bd_pins versal_cips_0/m_axi_lpd_aclk]
connect_bd_net [get_bd_pins $cam_clk] [get_bd_pins versal_cips_0/m_axi_fpd_aclk]

# NoC: the CIPS automation pre-connects S00..S05 (PS) and aclk0..5. Add two PL
# slave ports on aclk6 (video clock): S06 = camera frame buffer writes,
# S07 = video mixer reads. The ports go to different MC ports of the single
# memory controller.
set_property -dict [list CONFIG.NUM_CLKS {7} CONFIG.NUM_SI {8}] [get_bd_cells axi_noc_0]
set_property -dict [list CONFIG.CONNECTIONS {MC_2 {read_bw {100} write_bw {1500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S06_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_3 {read_bw {1500} write_bw {100} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S07_AXI]
connect_bd_net [get_bd_pins $cam_clk] [get_bd_pins axi_noc_0/aclk6]
set_property CONFIG.ASSOCIATED_BUSIF {S06_AXI:S07_AXI} [get_bd_pins axi_noc_0/aclk6]

#########################################################
# Camera pipelines
#########################################################

# AXI Intc for the camera pipeline interrupts -> pl_ps_irq0
set axi_intc_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc axi_intc_0]
set_property -dict [list CONFIG.C_IRQ_CONNECTION {1}] $axi_intc_0
set concat_0 [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 xlconcat_0]
connect_bd_net [get_bd_pins $lite_clk] [get_bd_pins axi_intc_0/s_axi_aclk]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins axi_intc_0/intr]
connect_bd_net [get_bd_pins axi_intc_0/irq] [get_bd_pins versal_cips_0/pl_ps_irq0]
connect_bd_net [get_bd_pins $lite_rst/peripheral_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn]
lappend lpd_ports "axi_intc_0/s_axi"

# CAM1 and CAM3 CLK_SEL pins: 10b = CAM1 clock on LA01, CAM3 clock on LA31.
# On Versal only these clock pins can reach the XPHY clock-capable nibble pins.
set clk_sel [create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 clk_sel]
set_property -dict [list CONFIG.CONST_WIDTH {2} CONFIG.CONST_VAL {0x02}] $clk_sel
create_bd_port -dir O -from 1 -to 0 clk_sel
connect_bd_net [get_bd_ports clk_sel] [get_bd_pins clk_sel/dout]

# GPIO for the camera I/O level-shifter controls (LA13_P/N = CAM_IO0/1_DIR,
# LA27_P/N = CAM_IO0/1_OE_N). Default 0x3: direction = 1, outputs enabled. This
# matches the ZynqMP rsvd_gpio default (0x30) on the 4 pins the card uses.
set rsvd_gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio rsvd_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_DOUT_DEFAULT {0x00000003} ] $rsvd_gpio
connect_bd_net [get_bd_pins $lite_clk] [get_bd_pins rsvd_gpio/s_axi_aclk]
connect_bd_net [get_bd_pins $lite_rst/peripheral_aresetn] [get_bd_pins rsvd_gpio/s_axi_aresetn]
lappend lpd_ports "rsvd_gpio/S_AXI"
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 rsvd_gpio
connect_bd_intf_net [get_bd_intf_pins rsvd_gpio/GPIO] [get_bd_intf_ports rsvd_gpio]

# SmartConnect for the Frame Buffer Writes -> NoC S06
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_cams
set_property -dict [list CONFIG.NUM_SI $num_cams CONFIG.NUM_MI {1}] [get_bd_cells smartconnect_cams]
connect_bd_net [get_bd_pins $cam_clk] [get_bd_pins smartconnect_cams/aclk]
connect_bd_net [get_bd_pins $cam_rst/peripheral_aresetn] [get_bd_pins smartconnect_cams/aresetn]
connect_bd_intf_net [get_bd_intf_pins smartconnect_cams/M00_AXI] [get_bd_intf_pins axi_noc_0/S06_AXI]

# Add the MIPI pipes
set cam_index 0
foreach i $cams {
  create_mipi_pipe $i
  # Connect clocks
  connect_bd_net [get_bd_pins $dphy_clk($i)] [get_bd_pins mipi_$i/dphy_clk_200M]
  connect_bd_net [get_bd_pins $lite_clk] [get_bd_pins mipi_$i/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins $cam_clk] [get_bd_pins mipi_$i/video_aclk]
  # Connect resets
  connect_bd_net [get_bd_pins $lite_rst/peripheral_aresetn] [get_bd_pins mipi_$i/aresetn]
  connect_bd_net [get_bd_pins $cam_rst/peripheral_aresetn] [get_bd_pins mipi_$i/video_aresetn]
  # Connect EMIO GPIO
  connect_bd_net [get_bd_pins versal_cips_0/PMC_GPIO_o] [get_bd_pins mipi_$i/emio_gpio]
  # Interrupts to the AXI Intc
  lappend intr_list "mipi_$i/mipi_sub_irq"
  lappend intr_list "mipi_$i/isppipeline_irq"
  lappend intr_list "mipi_$i/frmbufwr_irq"
  lappend intr_list "mipi_$i/iic2intc_irpt"
  # AXI Lite interfaces to be connected later
  lappend lpd_ports "mipi_$i/S_AXI_CTRL"
  lappend fpd_ports "mipi_$i/S_AXI_VIDEO"
  # MIPI D-PHY interface
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 mipi_phy_if_$i
  connect_bd_intf_net [get_bd_intf_ports mipi_phy_if_$i] -boundary_type upper [get_bd_intf_pins mipi_$i/mipi_phy_if]
  # I2C interface
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 iic_$i
  connect_bd_intf_net [get_bd_intf_ports iic_$i] [get_bd_intf_pins mipi_$i/IIC]
  # GPIO interface
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 gpio_$i
  connect_bd_intf_net [get_bd_intf_ports gpio_$i] [get_bd_intf_pins mipi_$i/GPIO]
  # Frame buffer AXI MM -> SmartConnect -> NoC
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins mipi_$i/m_axi_mm_video] [get_bd_intf_pins smartconnect_cams/S0${cam_index}_AXI]
  incr cam_index
}

#########################################################
# Display pipeline: video mixer + timing controller
#########################################################
# v_mix_0 reads the camera frame buffers (layers 1-4, YUYV) and an overlay
# layer (5, BGRA) through the NoC and outputs the composed 1080p frame on
# m_axis_video. v_tc_0 generates the 1080p60 timing. Both feed the video output
# hierarchy created by create_dvi_output (below). Cell names are the same as
# in the ZynqMP design (display_pipeline/v_mix_0, display_pipeline/v_tc_0).
proc create_display_pipeline { } {

  set hier_obj [create_bd_cell -type hier display_pipeline]
  current_bd_instance $hier_obj

  # Interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_ctrl_v_tc
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_ctrl_vmix
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_video
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:video_timing_rtl:2.0 vtiming_out

  # Pins
  global emio_width
  create_bd_pin -dir I -from [expr {$emio_width-1}] -to 0 emio_gpio
  create_bd_pin -dir I -type clk clk
  create_bd_pin -dir I -type rst resetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type clk vid_clk
  create_bd_pin -dir I -type rst vid_resetn
  create_bd_pin -dir I vtg_ce
  create_bd_pin -dir I sof_state
  create_bd_pin -dir O -type intr irq_v_tc
  create_bd_pin -dir O -type intr irq_vmix

  # Mixer AXI-MM read ports -> one SmartConnect -> NoC
  set smc_vmix [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smc_vmix ]
  set_property -dict [ list CONFIG.NUM_MI {1} CONFIG.NUM_SI {5} ] $smc_vmix

  # Video mixer
  set v_mix_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_mix v_mix_0 ]
  set_property -dict [ list \
   CONFIG.LAYER1_VIDEO_FORMAT {12} \
   CONFIG.LAYER2_VIDEO_FORMAT {12} \
   CONFIG.LAYER3_VIDEO_FORMAT {12} \
   CONFIG.LAYER4_VIDEO_FORMAT {12} \
   CONFIG.LAYER5_ALPHA {true} \
   CONFIG.LAYER5_VIDEO_FORMAT {26} \
   CONFIG.MAX_COLS {3840} \
   CONFIG.MAX_ROWS {2160} \
   CONFIG.NR_LAYERS {6} \
   CONFIG.VIDEO_FORMAT {0} \
 ] $v_mix_0

  # Video timing controller (1080p60 default)
  set v_tc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc v_tc_0 ]
  set_property -dict [ list \
   CONFIG.GEN_F0_VBLANK_HEND {960} \
   CONFIG.GEN_F0_VBLANK_HSTART {960} \
   CONFIG.GEN_F0_VFRAME_SIZE {1125} \
   CONFIG.GEN_F0_VSYNC_HEND {1004} \
   CONFIG.GEN_F0_VSYNC_HSTART {1004} \
   CONFIG.GEN_F0_VSYNC_VEND {1088} \
   CONFIG.GEN_F0_VSYNC_VSTART {1083} \
   CONFIG.GEN_F1_VBLANK_HEND {960} \
   CONFIG.GEN_F1_VBLANK_HSTART {960} \
   CONFIG.GEN_F1_VFRAME_SIZE {1125} \
   CONFIG.GEN_F1_VSYNC_HEND {1004} \
   CONFIG.GEN_F1_VSYNC_HSTART {1004} \
   CONFIG.GEN_F1_VSYNC_VEND {1088} \
   CONFIG.GEN_F1_VSYNC_VSTART {1083} \
   CONFIG.GEN_HACTIVE_SIZE {1920} \
   CONFIG.GEN_HFRAME_SIZE {2200} \
   CONFIG.GEN_HSYNC_END {2052} \
   CONFIG.GEN_HSYNC_START {2008} \
   CONFIG.GEN_VACTIVE_SIZE {1080} \
   CONFIG.VIDEO_MODE {1080p} \
   CONFIG.enable_detection {false} \
   CONFIG.max_clocks_per_line {8192} \
 ] $v_tc_0

  # Constants: mixer's unused streaming input layer, VTC clock enables
  set const_low_24 [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_low_24 ]
  set_property -dict [ list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {24} ] $const_low_24
  set const_high [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_high ]
  set_property -dict [ list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1} ] $const_high

  # Mixer reset from PMC EMIO GPIO bit 1
  set reset_vmix [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 reset_vmix ]
  set_property -dict [ list CONFIG.DIN_WIDTH $emio_width CONFIG.DIN_TO {1} CONFIG.DIN_FROM {1} CONFIG.DOUT_WIDTH {1} ] $reset_vmix

  # Interface connections
  connect_bd_intf_net [get_bd_intf_pins s_axi_ctrl_v_tc] [get_bd_intf_pins v_tc_0/ctrl]
  connect_bd_intf_net [get_bd_intf_pins s_axi_ctrl_vmix] [get_bd_intf_pins v_mix_0/s_axi_CTRL]
  connect_bd_intf_net [get_bd_intf_pins M00_AXI] [get_bd_intf_pins smc_vmix/M00_AXI]
  for {set l 1} {$l <= 5} {incr l} {
    connect_bd_intf_net [get_bd_intf_pins smc_vmix/S0[expr {$l-1}]_AXI] [get_bd_intf_pins v_mix_0/m_axi_mm_video$l]
  }
  connect_bd_intf_net [get_bd_intf_pins m_axis_video] [get_bd_intf_pins v_mix_0/m_axis_video]
  connect_bd_intf_net [get_bd_intf_pins vtiming_out] [get_bd_intf_pins v_tc_0/vtiming_out]

  # Clocks and resets
  connect_bd_net [get_bd_pins clk] [get_bd_pins smc_vmix/aclk] [get_bd_pins v_mix_0/ap_clk]
  connect_bd_net [get_bd_pins resetn] [get_bd_pins smc_vmix/aresetn]
  connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins reset_vmix/Din]
  connect_bd_net [get_bd_pins reset_vmix/Dout] [get_bd_pins v_mix_0/ap_rst_n]
  connect_bd_net [get_bd_pins s_axi_aclk] [get_bd_pins v_tc_0/s_axi_aclk]
  connect_bd_net [get_bd_pins s_axi_aresetn] [get_bd_pins v_tc_0/s_axi_aresetn]
  connect_bd_net [get_bd_pins vid_clk] [get_bd_pins v_tc_0/clk]
  connect_bd_net [get_bd_pins vid_resetn] [get_bd_pins v_tc_0/resetn]
  connect_bd_net [get_bd_pins vtg_ce] [get_bd_pins v_tc_0/gen_clken]
  connect_bd_net [get_bd_pins sof_state] [get_bd_pins v_tc_0/sof_state]
  connect_bd_net [get_bd_pins const_high/dout] [get_bd_pins v_tc_0/clken] [get_bd_pins v_tc_0/s_axi_aclken]
  connect_bd_net [get_bd_pins const_low_24/dout] [get_bd_pins v_mix_0/s_axis_video_TDATA]
  set const_low_1 [ create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_low_1 ]
  set_property -dict [ list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1} ] $const_low_1
  connect_bd_net [get_bd_pins const_low_1/dout] [get_bd_pins v_mix_0/s_axis_video_TVALID]
  # Interrupts
  connect_bd_net [get_bd_pins irq_vmix] [get_bd_pins v_mix_0/interrupt]
  connect_bd_net [get_bd_pins irq_v_tc] [get_bd_pins v_tc_0/irq]

  current_bd_instance \
}

#########################################################
# VIDEO OUTPUT: DVI over the board's HDMI TX connector
#########################################################
# create_dvi_output (src/bd/dvi_out.tcl) creates the hierarchy "video_output":
# v_axi4s_vid_out + TMDS encoder (own RTL) + Versal GT transceivers (gtwiz_versal),
# fixed 1080p60 RGB, plus an axi_iic (HDMI clock synthesiser and retimer/redriver)
# and an axi_gpio (status/control). Interface with the display pipeline:
#   S_AXIS_VIDEO  <- display_pipeline/v_mix_0/m_axis_video (RGB 8 bpc, 1 ppc)
#   VTIMING_IN    <- display_pipeline/v_tc_0/vtiming_out
#   aclk/aresetn  <- video clock/reset, s_axi_aclk/s_axi_aresetn <- 100 MHz
#   vid_clk/vid_resetn/vtg_ce/sof_state -> v_tc_0 (pixel clock = HDMI GT refclk 148.5 MHz)
#   S_AXI_CTRL    <- M_AXI_LPD,  irq_iic -> pl_ps_irq3
# It also creates the top-level HDMI ports and adds src/constraints/dvi_<board>.xdc.

# Create the display pipeline and the video output
create_display_pipeline
create_dvi_output video_output $dvi_board

connect_bd_intf_net [get_bd_intf_pins display_pipeline/M00_AXI] [get_bd_intf_pins axi_noc_0/S07_AXI]
lappend lpd_ports "display_pipeline/s_axi_ctrl_v_tc"
lappend fpd_ports "display_pipeline/s_axi_ctrl_vmix"
connect_bd_net [get_bd_pins versal_cips_0/PMC_GPIO_o] [get_bd_pins display_pipeline/emio_gpio]
connect_bd_net [get_bd_pins $display_clk] [get_bd_pins display_pipeline/clk]
connect_bd_net [get_bd_pins $display_rst/peripheral_aresetn] [get_bd_pins display_pipeline/resetn]
connect_bd_net [get_bd_pins $lite_clk] [get_bd_pins display_pipeline/s_axi_aclk]
connect_bd_net [get_bd_pins $lite_rst/peripheral_aresetn] [get_bd_pins display_pipeline/s_axi_aresetn]

# Display pipeline <-> video output
connect_bd_intf_net [get_bd_intf_pins display_pipeline/m_axis_video] [get_bd_intf_pins video_output/S_AXIS_VIDEO]
connect_bd_intf_net [get_bd_intf_pins display_pipeline/vtiming_out] [get_bd_intf_pins video_output/VTIMING_IN]
connect_bd_net [get_bd_pins $display_clk] [get_bd_pins video_output/aclk]
connect_bd_net [get_bd_pins $display_rst/peripheral_aresetn] [get_bd_pins video_output/aresetn]
connect_bd_net [get_bd_pins $lite_clk] [get_bd_pins video_output/s_axi_aclk]
connect_bd_net [get_bd_pins $lite_rst/peripheral_aresetn] [get_bd_pins video_output/s_axi_aresetn]
connect_bd_net [get_bd_pins video_output/vid_clk] [get_bd_pins display_pipeline/vid_clk]
connect_bd_net [get_bd_pins video_output/vid_resetn] [get_bd_pins display_pipeline/vid_resetn]
connect_bd_net [get_bd_pins video_output/vtg_ce] [get_bd_pins display_pipeline/vtg_ce]
connect_bd_net [get_bd_pins video_output/sof_state] [get_bd_pins display_pipeline/sof_state]
lappend lpd_ports "video_output/S_AXI_CTRL"
connect_bd_net [get_bd_pins video_output/irq_iic] [get_bd_pins versal_cips_0/pl_ps_irq3]

# Direct PL-to-PS interrupts
connect_bd_net [get_bd_pins display_pipeline/irq_vmix] [get_bd_pins versal_cips_0/pl_ps_irq1]
connect_bd_net [get_bd_pins display_pipeline/irq_v_tc] [get_bd_pins versal_cips_0/pl_ps_irq2]

#########################################################
# AXI-Lite control interconnects and interrupts
#########################################################

# Create a SmartConnect from a PS master to a list of AXI-Lite slave interfaces
proc create_ctrl_smc {label clk rst master ports} {
  set n [llength $ports]
  set smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect $label]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI $n] $smc
  connect_bd_net [get_bd_pins $clk] [get_bd_pins $label/aclk]
  connect_bd_net [get_bd_pins $rst/interconnect_aresetn] [get_bd_pins $label/aresetn]
  connect_bd_intf_net [get_bd_intf_pins $master] [get_bd_intf_pins $label/S00_AXI]
  set m 0
  foreach port $ports {
    connect_bd_intf_net -boundary_type upper [get_bd_intf_pins $label/M[format %02d $m]_AXI] [get_bd_intf_pins $port]
    incr m
  }
}

# M_AXI_FPD (250 MHz video clock): ISP / VPSS / frame buffer / mixer control
create_ctrl_smc "axi_ic_ctrl_250" $cam_clk $cam_rst "versal_cips_0/M_AXI_FPD" $fpd_ports

# M_AXI_LPD (100 MHz): CSI-2 RX, IIC, GPIO, AXI Intc, VTC
create_ctrl_smc "axi_ic_ctrl_100" $lite_clk $lite_rst "versal_cips_0/M_AXI_LPD" $lpd_ports

# Connect the camera interrupts to the AXI Intc (max 32 interrupts)
set_property -dict [list CONFIG.NUM_PORTS [llength $intr_list]] $concat_0
set intr_index 0
foreach intr $intr_list {
  connect_bd_net [get_bd_pins $intr] [get_bd_pins ${concat_0}/In$intr_index]
  incr intr_index
}

# Assign addresses
assign_bd_address

# Restore current instance
current_bd_instance $oldCurInst

validate_bd_design
save_bd_design
