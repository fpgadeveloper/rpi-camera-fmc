################################################################
# Block diagram build script for MicroBlaze designs
################################################################

################################################################
# AXI GPIOs are connected as follows:
################################################################
# 0  - CAM0 Demosaic IP reset
# 1  - CAM0 Vproc IP reset
# 2  - CAM0 Gamma LUT IP reset
# 3  - CAM0 Frame Buffer Read IP reset
# 4  - CAM0 Frame Buffer Write IP reset
# 5-7 - Reserved
# 8  - CAM1 Demosaic IP reset
# 9  - CAM1 Vproc IP reset
# 10 - CAM1 Gamma LUT IP reset
# 11 - CAM1 Frame Buffer Read IP reset
# 12 - CAM1 Frame Buffer Write IP reset
# 13-15 - Reserved
# 16 - CAM2 Demosaic IP reset
# 17 - CAM2 Vproc IP reset
# 18 - CAM2 Gamma LUT IP reset
# 19 - CAM2 Frame Buffer Read IP reset
# 20 - CAM2 Frame Buffer Write IP reset
# 21-23 - Reserved
# 24 - CAM3 Demosaic IP reset
# 25 - CAM3 Vproc IP reset
# 26 - CAM3 Gamma LUT IP reset
# 27 - CAM3 Frame Buffer Read IP reset
# 28 - CAM3 Frame Buffer Write IP reset
# 29-31 - Reserved

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

# Clock and reset selections
set cam_clk clk_wiz/clk_300M
set cam_rst rst_clk_wiz_300M

# Video pipe max res has impact on resource usage
set max_cols 1920
set max_rows 1232

# Set the samples-per-clock for the video pipelines (1)
# Set this to 2 to double the throughput at the cost of higher resource usage
set samples_pc 2

# AXI Lite ports
set periph_ports {}

# List of interrupt pins (AXI Intc)
set intr_list {}



set target auboard
set cams { 2 }


# Hierarchical cell: v_tpg_ss_0
proc create_hier_cell_v_tpg_ss_0 { } {

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier v_tpg_ss_0]
  current_bd_instance $hier_obj

  global samples_pc

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_TPG

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_GPIO

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_video

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_video


  # Create pins
  create_bd_pin -dir I -type clk ap_clk
  create_bd_pin -dir I -type rst m_axi_aresetn

  # Create instance: axi_gpio, and set properties
  set axi_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {1} \
  ] $axi_gpio


  # Create instance: v_tpg, and set properties
  set v_tpg [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_tpg v_tpg ]
  set_property -dict [list \
    CONFIG.COLOR_SWEEP {0} \
    CONFIG.DISPLAY_PORT {0} \
    CONFIG.FOREGROUND {0} \
    CONFIG.HAS_AXI4S_SLAVE {1} \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.RAMP {0} \
    CONFIG.SAMPLES_PER_CLOCK $samples_pc \
    CONFIG.SOLID_COLOR {0} \
    CONFIG.ZONE_PLATE {0} \
  ] $v_tpg


  # Create interface connections
  connect_bd_intf_net -intf_net intf_net_bdry_in_S_AXI_GPIO [get_bd_intf_pins S_AXI_GPIO] [get_bd_intf_pins axi_gpio/S_AXI]
  connect_bd_intf_net -intf_net intf_net_bdry_in_S_AXI_TPG [get_bd_intf_pins S_AXI_TPG] [get_bd_intf_pins v_tpg/s_axi_CTRL]
  connect_bd_intf_net -intf_net intf_net_bdry_in_s_axis_video [get_bd_intf_pins s_axis_video] [get_bd_intf_pins v_tpg/s_axis_video]
  connect_bd_intf_net -intf_net intf_net_v_tpg_m_axis_video [get_bd_intf_pins v_tpg/m_axis_video] [get_bd_intf_pins m_axis_video]

  # Create port connections
  connect_bd_net -net net_axi_gpio_gpio_io_o [get_bd_pins axi_gpio/gpio_io_o] [get_bd_pins v_tpg/ap_rst_n]
  connect_bd_net -net net_bdry_in_ap_clk [get_bd_pins ap_clk] [get_bd_pins axi_gpio/s_axi_aclk] [get_bd_pins v_tpg/ap_clk]
  connect_bd_net -net net_bdry_in_m_axi_aresetn [get_bd_pins m_axi_aresetn] [get_bd_pins axi_gpio/s_axi_aresetn]

  # Restore current instance
  current_bd_instance \
}


# Create interface ports
set HDMI_CLK_IIC [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 HDMI_CLK_IIC ]

set TX_DDC_OUT [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 TX_DDC_OUT ]

set RS232_UART [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 RS232_UART ]

set GTH_CLK_IIC [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 GTH_CLK_IIC ]


# Create ports
set TX_HPD_IN [ create_bd_port -dir I TX_HPD_IN ]
set HDMI_TX_CLK_P_OUT [ create_bd_port -dir O HDMI_TX_CLK_P_OUT ]
set HDMI_TX_CLK_N_OUT [ create_bd_port -dir O HDMI_TX_CLK_N_OUT ]
set HDMI_TX_DAT_P_OUT [ create_bd_port -dir O -from 2 -to 0 HDMI_TX_DAT_P_OUT ]
set HDMI_TX_DAT_N_OUT [ create_bd_port -dir O -from 2 -to 0 HDMI_TX_DAT_N_OUT ]
set IDT_8T49N241_LOL_IN [ create_bd_port -dir I IDT_8T49N241_LOL_IN ]
set TX_CLKSEL_OUT [ create_bd_port -dir O -from 0 -to 0 TX_CLKSEL_OUT ]
set LED0 [ create_bd_port -dir O LED0 ]
set TX_EN_OUT [ create_bd_port -dir O -from 0 -to 0 TX_EN_OUT ]
set TX_REFCLK_P_IN [ create_bd_port -dir I -type clk TX_REFCLK_P_IN ]
set TX_REFCLK_N_IN [ create_bd_port -dir I -type clk TX_REFCLK_N_IN ]
set LED1 [ create_bd_port -dir O -from 0 -to 0 LED1 ]
set LED2 [ create_bd_port -dir O LED2 ]
set IDT_8T49N241_RST_OUT [ create_bd_port -dir O -from 0 -to 0 -type rst IDT_8T49N241_RST_OUT ]

# Create instance: v_tpg_ss_0
create_hier_cell_v_tpg_ss_0

# Create instance: rx_video_axis_reg_slice, and set properties
set rx_video_axis_reg_slice [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice rx_video_axis_reg_slice ]

# Create instance: tx_video_axis_reg_slice, and set properties
set tx_video_axis_reg_slice [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice tx_video_axis_reg_slice ]

# Create instance: v_hdmi_tx_ss, and set properties
set v_hdmi_tx_ss [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_hdmi_tx_ss v_hdmi_tx_ss ]
set_property -dict [list \
  CONFIG.C_ADDR_WIDTH {10} \
  CONFIG.C_ADD_MARK_DBG {0} \
  CONFIG.C_EXDES_NIDRU {false} \
  CONFIG.C_EXDES_RX_PLL_SELECTION {0} \
  CONFIG.C_HDMI_FAST_SWITCH {true} \
  CONFIG.C_HPD_INVERT {false} \
  CONFIG.C_HYSTERESIS_LEVEL {12} \
  CONFIG.C_INCLUDE_HDCP_1_4 {false} \
  CONFIG.C_INCLUDE_HDCP_2_2 {false} \
  CONFIG.C_INCLUDE_LOW_RESO_VID {true} \
  CONFIG.C_INCLUDE_YUV420_SUP {true} \
  CONFIG.C_INPUT_PIXELS_PER_CLOCK $samples_pc \
  CONFIG.C_MAX_BITS_PER_COMPONENT {8} \
  CONFIG.C_VALIDATION_ENABLE {false} \
  CONFIG.C_VID_INTERFACE {0} \
] $v_hdmi_tx_ss


# Create instance: vcc_const, and set properties
set vcc_const [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant vcc_const ]
set_property CONFIG.CONST_VAL {1} $vcc_const

# Create instance: gnd_const, and set properties
set gnd_const [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant gnd_const ]
set_property CONFIG.CONST_VAL {0} $gnd_const
connect_bd_net [get_bd_pins gnd_const/dout] [get_bd_pins v_hdmi_tx_ss/fid]


# Create instance: vid_phy_controller, and set properties
set vid_phy_controller [ create_bd_cell -type ip -vlnv xilinx.com:ip:vid_phy_controller vid_phy_controller ]
set_property -dict [list \
  CONFIG.Adv_Clk_Mode {false} \
  CONFIG.CHANNEL_ENABLE {X0Y8 X0Y9 X0Y10} \
  CONFIG.CHANNEL_SITE {X0Y8} \
  CONFIG.C_FOR_UPGRADE_ARCHITECTURE {virtexuplus} \
  CONFIG.C_FOR_UPGRADE_DEVICE {xcvu9p} \
  CONFIG.C_FOR_UPGRADE_PACKAGE {flga2104} \
  CONFIG.C_FOR_UPGRADE_PART {xcvu9p-flga2104-2L-e} \
  CONFIG.C_FOR_UPGRADE_SPEEDGRADE {-2L} \
  CONFIG.C_INPUT_PIXELS_PER_CLOCK $samples_pc \
  CONFIG.C_INT_HDMI_VER_CMPTBLE {3} \
  CONFIG.C_RX_PLL_SELECTION {0} \
  CONFIG.C_RX_REFCLK_SEL {1} \
  CONFIG.C_Rx_Protocol {None} \
  CONFIG.C_TX_PLL_SELECTION {6} \
  CONFIG.C_TX_REFCLK_SEL {0} \
  CONFIG.C_Tx_Clk_Primitive {1} \
  CONFIG.C_Tx_Protocol {HDMI} \
  CONFIG.C_Txrefclk_Rdy_Invert {true} \
  CONFIG.C_Use_Oddr_for_Tmds_Clkout {true} \
  CONFIG.C_vid_phy_rx_axi4s_ch_INT_TDATA_WIDTH {20} \
  CONFIG.C_vid_phy_rx_axi4s_ch_TDATA_WIDTH {20} \
  CONFIG.C_vid_phy_rx_axi4s_ch_TUSER_WIDTH {1} \
  CONFIG.C_vid_phy_tx_axi4s_ch_INT_TDATA_WIDTH {20} \
  CONFIG.C_vid_phy_tx_axi4s_ch_TDATA_WIDTH {20} \
  CONFIG.C_vid_phy_tx_axi4s_ch_TUSER_WIDTH {1} \
  CONFIG.Rx_GT_Line_Rate {5.94} \
  CONFIG.Rx_GT_Ref_Clock_Freq {297} \
  CONFIG.Transceiver {GTHE4} \
  CONFIG.Tx_GT_Line_Rate {5.94} \
  CONFIG.Tx_GT_Ref_Clock_Freq {297} \
] $vid_phy_controller


# Create instance: axi_uartlite, and set properties
set axi_uartlite [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite axi_uartlite ]
set_property -dict [list \
  CONFIG.C_BAUDRATE {115200} \
  CONFIG.UARTLITE_BOARD_INTERFACE {Custom} \
  CONFIG.USE_BOARD_FLOW {true} \
] $axi_uartlite

# Add the DDR
create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4 ddr4_0
apply_board_connection -board_interface "ddr4_sdram" -ip_intf "ddr4_0/C0_DDR4" -diagram "$block_name" 
apply_board_connection -board_interface "system_clock_300mhz" -ip_intf "ddr4_0/C0_SYS_CLK" -diagram "$block_name" 

# Create instance: clk_wiz, and set properties
# Add and configure the clock wizard
set clk_wiz [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_wiz ]
set_property -dict [list \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.CLKOUT1_JITTER {85.183} \
  CONFIG.CLKOUT1_PHASE_ERROR {76.968} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.CLKOUT2_JITTER {96.285} \
  CONFIG.CLKOUT2_PHASE_ERROR {76.968} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLKOUT3_JITTER {79.342} \
  CONFIG.CLKOUT3_PHASE_ERROR {76.968} \
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {300.000} \
  CONFIG.CLKOUT3_USED {true} \
  CONFIG.CLKOUT4_USED {false} \
  CONFIG.CLKOUT5_USED {false} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {15.000} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {7.500} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {15} \
  CONFIG.MMCM_CLKOUT2_DIVIDE {5} \
  CONFIG.MMCM_CLKOUT3_DIVIDE {30} \
  CONFIG.RESET_PORT {resetn} \
  CONFIG.RESET_TYPE {ACTIVE_LOW} \
  CONFIG.CLK_OUT1_PORT {clk_200M} \
  CONFIG.CLK_OUT2_PORT {clk_100M} \
  CONFIG.CLK_OUT3_PORT {clk_300M} \
  CONFIG.NUM_OUT_CLKS {3} \
] $clk_wiz

# Connect 100MHz DDR additional user clock output to Clk wizard
connect_bd_net [get_bd_pins ddr4_0/addn_ui_clkout1] [get_bd_pins clk_wiz/clk_in1]

# Connect FPGA Reset using automation feature
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {system_resetn ( FPGA Reset ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins clk_wiz/resetn]

# Reset for DDR
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic invert_rst
set_property -dict [list \
  CONFIG.C_OPERATION {not} \
  CONFIG.C_SIZE {1} \
] [get_bd_cells invert_rst]
connect_bd_net [get_bd_ports system_resetn] [get_bd_pins invert_rst/Op1]
connect_bd_net [get_bd_pins invert_rst/Res] [get_bd_pins ddr4_0/sys_rst]

# Add and configure reset processor system for the 300MHz DDR clock
set rst_ddr_300M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_ddr_300M ]
connect_bd_net [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins rst_ddr_300M/slowest_sync_clk]
connect_bd_net [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins rst_ddr_300M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ddr_300M/peripheral_aresetn] [get_bd_pins ddr4_0/c0_ddr4_aresetn]

# Add the MicroBlaze
set microblaze_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0]
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { all {1} axi_intc {1} axi_periph {Enabled} cache {32KB} clk {/clk_wiz/clk_100M (100 MHz)} compress {1} cores {1} debug_module {Debug Only} disable {0} ecc {None} local_mem {16KB} preset {Application}}  $microblaze_0
set_property -dict [list \
  CONFIG.C_DEBUG_ENABLED {1} \
  CONFIG.C_D_AXI {1} \
  CONFIG.C_D_LMB {1} \
  CONFIG.C_I_AXI {0} \
  CONFIG.C_I_LMB {1} \
] $microblaze_0

# Connect Microblaze to DDR
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_100M (100 MHz)} Clk_slave {/ddr4_0/c0_ddr4_ui_clk (300 MHz)} Clk_xbar {Auto} Master {/microblaze_0 (Cached)} Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]

# Create instance: axi_iic_0, and set properties
set axi_iic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_0 ]
set_property -dict [list \
  CONFIG.IIC_BOARD_INTERFACE {Custom} \
  CONFIG.USE_BOARD_FLOW {true} \
] $axi_iic_0

# Create instance: rst_clk_wiz_300M, and set properties
set rst_clk_wiz_300M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_clk_wiz_300M ]
set_property -dict [list \
  CONFIG.RESET_BOARD_INTERFACE {Custom} \
  CONFIG.USE_BOARD_FLOW {false} \
] $rst_clk_wiz_300M


# Create instance: axi_iic_1, and set properties
set axi_iic_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_1 ]
set_property -dict [list \
  CONFIG.IIC_BOARD_INTERFACE {Custom} \
  CONFIG.USE_BOARD_FLOW {true} \
] $axi_iic_1

# AXI Peripheral ports
lappend periph_ports [list "vid_phy_controller/vid_phy_axi4lite" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]
lappend periph_ports [list "v_tpg_ss_0/S_AXI_GPIO" "clk_wiz/clk_300M" "rst_clk_wiz_300M/peripheral_aresetn"]
lappend periph_ports [list "v_hdmi_tx_ss/S_AXI_CPU_IN" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]
lappend periph_ports [list "axi_uartlite/S_AXI" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]
lappend periph_ports [list "axi_iic_0/S_AXI" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]
lappend periph_ports [list "v_tpg_ss_0/S_AXI_TPG" "clk_wiz/clk_300M" "rst_clk_wiz_300M/peripheral_aresetn"]
lappend periph_ports [list "axi_iic_1/S_AXI" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]

# Create interface connections
connect_bd_intf_net -intf_net intf_net_mb_ss_0_IIC [get_bd_intf_pins axi_iic_0/IIC] [get_bd_intf_ports HDMI_CLK_IIC]
connect_bd_intf_net -intf_net intf_net_mb_ss_0_UART [get_bd_intf_pins axi_uartlite/UART] [get_bd_intf_ports RS232_UART]
connect_bd_intf_net -intf_net intf_net_rx_video_axis_reg_slice_M_AXIS [get_bd_intf_pins rx_video_axis_reg_slice/M_AXIS] [get_bd_intf_pins v_tpg_ss_0/s_axis_video]
connect_bd_intf_net -intf_net intf_net_tx_video_axis_reg_slice_M_AXIS [get_bd_intf_pins tx_video_axis_reg_slice/M_AXIS] [get_bd_intf_pins v_hdmi_tx_ss/VIDEO_IN]
connect_bd_intf_net -intf_net intf_net_v_hdmi_tx_ss_DDC_OUT [get_bd_intf_pins v_hdmi_tx_ss/DDC_OUT] [get_bd_intf_ports TX_DDC_OUT]
connect_bd_intf_net -intf_net intf_net_v_hdmi_tx_ss_LINK_DATA0_OUT [get_bd_intf_pins v_hdmi_tx_ss/LINK_DATA0_OUT] [get_bd_intf_pins vid_phy_controller/vid_phy_tx_axi4s_ch0]
connect_bd_intf_net -intf_net intf_net_v_tpg_ss_0_m_axis_video [get_bd_intf_pins v_tpg_ss_0/m_axis_video] [get_bd_intf_pins tx_video_axis_reg_slice/S_AXIS]
connect_bd_intf_net -intf_net intf_net_vid_phy_controller_vid_phy_status_sb_tx [get_bd_intf_pins vid_phy_controller/vid_phy_status_sb_tx] [get_bd_intf_pins v_hdmi_tx_ss/SB_STATUS_IN]
connect_bd_intf_net -intf_net mb_ss_0_iic_rtl_0 [get_bd_intf_ports GTH_CLK_IIC] [get_bd_intf_pins axi_iic_1/IIC]
connect_bd_intf_net -intf_net v_hdmi_tx_ss_LINK_DATA1_OUT [get_bd_intf_pins v_hdmi_tx_ss/LINK_DATA1_OUT] [get_bd_intf_pins vid_phy_controller/vid_phy_tx_axi4s_ch1]
connect_bd_intf_net -intf_net v_hdmi_tx_ss_LINK_DATA2_OUT [get_bd_intf_pins vid_phy_controller/vid_phy_tx_axi4s_ch2] [get_bd_intf_pins v_hdmi_tx_ss/LINK_DATA2_OUT]

# Create port connections
connect_bd_net [get_bd_ports IDT_8T49N241_LOL_IN] [get_bd_ports LED2] [get_bd_pins vid_phy_controller/tx_refclk_rdy]
connect_bd_net [get_bd_ports TX_HPD_IN] [get_bd_pins v_hdmi_tx_ss/hpd]
connect_bd_net [get_bd_ports TX_REFCLK_N_IN] [get_bd_pins vid_phy_controller/mgtrefclk0_pad_n_in]
connect_bd_net [get_bd_ports TX_REFCLK_P_IN] [get_bd_pins vid_phy_controller/mgtrefclk0_pad_p_in]
connect_bd_net [get_bd_pins clk_wiz/clk_300M] [get_bd_pins v_tpg_ss_0/ap_clk] [get_bd_pins rx_video_axis_reg_slice/aclk] [get_bd_pins tx_video_axis_reg_slice/aclk] [get_bd_pins v_hdmi_tx_ss/s_axis_video_aclk] [get_bd_pins rst_clk_wiz_300M/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz/clk_100M] [get_bd_pins v_hdmi_tx_ss/s_axi_cpu_aclk] [get_bd_pins vid_phy_controller/vid_phy_sb_aclk] [get_bd_pins vid_phy_controller/vid_phy_axi4lite_aclk] [get_bd_pins vid_phy_controller/drpclk] [get_bd_pins axi_uartlite/s_axi_aclk] [get_bd_pins axi_iic_0/s_axi_aclk] [get_bd_pins axi_iic_1/s_axi_aclk] [get_bd_pins microblaze_0/Clk] [get_bd_pins rst_clk_wiz_100M/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz/locked] [get_bd_pins rst_clk_wiz_100M/aux_reset_in] [get_bd_pins rst_clk_wiz_100M/dcm_locked] [get_bd_pins rst_clk_wiz_300M/aux_reset_in] [get_bd_pins rst_clk_wiz_300M/dcm_locked]
connect_bd_net [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn] [get_bd_ports LED1] [get_bd_ports IDT_8T49N241_RST_OUT] [get_bd_pins v_hdmi_tx_ss/s_axi_cpu_aresetn] [get_bd_pins vid_phy_controller/vid_phy_sb_aresetn] [get_bd_pins vid_phy_controller/vid_phy_axi4lite_aresetn] [get_bd_pins axi_uartlite/s_axi_aresetn] [get_bd_pins axi_iic_0/s_axi_aresetn] [get_bd_pins axi_iic_1/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_clk_wiz_300M/peripheral_aresetn] [get_bd_pins v_tpg_ss_0/m_axi_aresetn] [get_bd_pins rx_video_axis_reg_slice/aresetn] [get_bd_pins tx_video_axis_reg_slice/aresetn] [get_bd_pins v_hdmi_tx_ss/s_axis_video_aresetn]
connect_bd_net [get_bd_pins invert_rst/Res] [get_bd_pins rst_clk_wiz_300M/ext_reset_in]
connect_bd_net [get_bd_pins v_hdmi_tx_ss/locked] [get_bd_ports LED0]
connect_bd_net [get_bd_pins vcc_const/dout] [get_bd_ports TX_CLKSEL_OUT] [get_bd_ports TX_EN_OUT] [get_bd_pins vid_phy_controller/vid_phy_tx_axi4s_aresetn] [get_bd_pins v_hdmi_tx_ss/s_axis_audio_aclk] [get_bd_pins v_hdmi_tx_ss/s_axis_audio_aresetn]
connect_bd_net [get_bd_pins vid_phy_controller/phy_txn_out] [get_bd_ports HDMI_TX_DAT_N_OUT]
connect_bd_net [get_bd_pins vid_phy_controller/phy_txp_out] [get_bd_ports HDMI_TX_DAT_P_OUT]
connect_bd_net [get_bd_pins vid_phy_controller/tx_tmds_clk_n] [get_bd_ports HDMI_TX_CLK_N_OUT]
connect_bd_net [get_bd_pins vid_phy_controller/tx_tmds_clk_p] [get_bd_ports HDMI_TX_CLK_P_OUT]
connect_bd_net [get_bd_pins vid_phy_controller/tx_video_clk] [get_bd_pins v_hdmi_tx_ss/video_clk]
connect_bd_net [get_bd_pins vid_phy_controller/txoutclk] [get_bd_pins v_hdmi_tx_ss/link_clk] [get_bd_pins vid_phy_controller/vid_phy_tx_axi4s_aclk]

# Interrupts
lappend intr_list "vid_phy_controller/irq"
lappend intr_list "v_hdmi_tx_ss/irq"

##### Add the MIPI pipes #####

# Procedure for creating a MIPI pipe for one camera
proc create_mipi_pipe { index loc_dict } {
  set hier_obj [create_bd_cell -type hier mipi_$index]
  current_bd_instance $hier_obj
  global samples_pc
  global target
  global max_cols
  global max_rows
  
  # Create pins of the block
  create_bd_pin -dir I dphy_clk_200M
  create_bd_pin -dir I s_axi_lite_aclk
  create_bd_pin -dir I aresetn
  create_bd_pin -dir I video_aclk
  create_bd_pin -dir I video_aresetn
  create_bd_pin -dir O -type intr mipi_sub_irq
  create_bd_pin -dir O -type intr demosaic_irq
  create_bd_pin -dir O -type intr gamma_lut_irq
  create_bd_pin -dir O -type intr frmbufwr_irq
  create_bd_pin -dir O -type intr frmbufrd_irq
  create_bd_pin -dir O -type intr iic2intc_irpt
  create_bd_pin -dir I emio_gpio
  
  # Create the interfaces of the block
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_CTRL
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_VIDEO
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_MM
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_video
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 mipi_phy_if
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 IIC
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 GPIO
  
  # Add and configure the MIPI Subsystem IP
  set clk_pin [dict get $loc_dict clk pin]
  set clk_pin_name [dict get $loc_dict clk pin_name]
  set data0_pin [dict get $loc_dict data0 pin]
  set data0_pin_name [dict get $loc_dict data0 pin_name]
  set data1_pin [dict get $loc_dict data1 pin]
  set data1_pin_name [dict get $loc_dict data1 pin_name]
  set bank [dict get $loc_dict bank]
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
    CONFIG.CLK_LANE_IO_LOC $clk_pin \
    CONFIG.CLK_LANE_IO_LOC_NAME $clk_pin_name \
    CONFIG.DATA_LANE0_IO_LOC $data0_pin \
    CONFIG.DATA_LANE0_IO_LOC_NAME $data0_pin_name \
    CONFIG.DATA_LANE1_IO_LOC $data1_pin \
    CONFIG.DATA_LANE1_IO_LOC_NAME $data1_pin_name \
    CONFIG.HP_IO_BANK_SELECTION $bank \
  ] $mipi_csi2_rx_subsyst
 
  # Add and configure the AXI Interconnect (LPD)
  set axi_int_ctrl [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_int_ctrl ]
  set_property -dict [list \
  CONFIG.NUM_MI {3} \
  ] $axi_int_ctrl
  
  # Add and configure the AXI Interconnect (HPD)
  set axi_int_video [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_int_video ]
  set_property -dict [list \
  CONFIG.NUM_MI {5} \
  ] $axi_int_video
  
  # Add the AXI4 Streaming Data FIFO
  set axis_data_fifo [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo axis_data_fifo]
  set_property CONFIG.FIFO_DEPTH {4096} $axis_data_fifo

  # Add and configure the AXIS Subset Converter
  if { $samples_pc == 1 } {
    set subset_conv_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter subset_conv_0 ]
    set_property -dict [ list \
     CONFIG.M_TDATA_NUM_BYTES {1} \
     CONFIG.S_TDATA_NUM_BYTES {2} \
     CONFIG.TDATA_REMAP {tdata[9:2]} \
    ] $subset_conv_0
  } else {
    set subset_conv_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter subset_conv_0 ]
    set_property -dict [ list \
     CONFIG.M_TDATA_NUM_BYTES {2} \
     CONFIG.S_TDATA_NUM_BYTES {3} \
     CONFIG.TDATA_REMAP {tdata[19:12],tdata[9:2]} \
    ] $subset_conv_0
  }
  
  # Add and configure demosaic
  set v_demosaic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_demosaic demosaic_0 ]
  set_property -dict [ list \
    CONFIG.SAMPLES_PER_CLOCK $samples_pc \
    CONFIG.MAX_COLS $max_cols \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.MAX_ROWS $max_rows \
    CONFIG.ALGORITHM {1} \
    CONFIG.USE_URAM {0} \
  ] $v_demosaic_0
  
  # Add and configure the V Gamma LUT
  set v_gamma_lut [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_gamma_lut v_gamma_lut ]
  set_property -dict [ list \
    CONFIG.SAMPLES_PER_CLOCK $samples_pc \
    CONFIG.MAX_COLS $max_cols \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.MAX_ROWS $max_rows \
  ] $v_gamma_lut
  
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
   CONFIG.MAX_COLS $max_cols \
   CONFIG.MAX_ROWS $max_rows \
  ] $v_frmbuf_wr
  
  # Add and configure the Video Frame Buffer Read
  set v_frmbuf_rd [create_bd_cell -type ip -vlnv xilinx.com:ip:v_frmbuf_rd v_frmbuf_rd]
  set_property -dict [list \
   CONFIG.C_M_AXI_MM_VIDEO_DATA_WIDTH {128} \
   CONFIG.SAMPLES_PER_CLOCK $samples_pc \
   CONFIG.AXIMM_DATA_WIDTH {128} \
   CONFIG.MAX_COLS $max_cols \
   CONFIG.MAX_ROWS $max_rows \
  ] $v_frmbuf_rd

  # Add AXI Smartconnect for the Frame Buffer MM interface
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
  ] [get_bd_cells axi_smc]
  
  connect_bd_intf_net [get_bd_intf_pins v_frmbuf_wr/m_axi_mm_video] [get_bd_intf_pins axi_smc/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins v_frmbuf_rd/m_axi_mm_video] [get_bd_intf_pins axi_smc/S01_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins M_AXI_MM]
  
  # Slice for Demosaic reset signal
  set emio_gpio_index [expr {8*$index+0}]
  set reset_demosaic [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice reset_demosaic ]
  set_property -dict [ list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_TO $emio_gpio_index \
  CONFIG.DIN_FROM $emio_gpio_index \
  CONFIG.DOUT_WIDTH {1} \
  ] $reset_demosaic

  connect_bd_net -net reset_demosaic_Dout [get_bd_pins reset_demosaic/Dout] [get_bd_pins demosaic_0/ap_rst_n]
  connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins reset_demosaic/Din]

  # Slice for Vproc reset signal
  set emio_gpio_index [expr {8*$index+1}]
  set reset_v_proc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice reset_v_proc ]
  set_property -dict [ list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_TO $emio_gpio_index \
  CONFIG.DIN_FROM $emio_gpio_index \
  CONFIG.DOUT_WIDTH {1} \
  ] $reset_v_proc

  connect_bd_net -net reset_v_proc_Dout [get_bd_pins reset_v_proc/Dout] [get_bd_pins v_proc/aresetn_ctrl]
  connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins reset_v_proc/Din]

  # Slice for Gamma Lut reset signal
  set emio_gpio_index [expr {8*$index+2}]
  set reset_gamma [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice reset_gamma ]
  set_property -dict [ list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_TO $emio_gpio_index \
  CONFIG.DIN_FROM $emio_gpio_index \
  CONFIG.DOUT_WIDTH {1} \
  ] $reset_gamma

  connect_bd_net -net reset_gamma_Dout [get_bd_pins reset_gamma/Dout] [get_bd_pins v_gamma_lut/ap_rst_n]
  connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins reset_gamma/Din]

  # Slice for Frmbuf RD reset signal
  set emio_gpio_index [expr {8*$index+3}]
  set reset_frmbuf_rd [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice reset_frmbuf_rd ]
  set_property -dict [ list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_TO $emio_gpio_index \
  CONFIG.DIN_FROM $emio_gpio_index \
  CONFIG.DOUT_WIDTH {1} \
  ] $reset_frmbuf_rd

  connect_bd_net -net reset_frmbuf_rd_Dout [get_bd_pins reset_frmbuf_rd/Dout] [get_bd_pins v_frmbuf_rd/ap_rst_n]
  connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins reset_frmbuf_rd/Din]

  # Slice for Frmbuf WR reset signal
  set emio_gpio_index [expr {8*$index+4}]
  set reset_frmbuf_wr [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice reset_frmbuf_wr ]
  set_property -dict [ list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_TO $emio_gpio_index \
  CONFIG.DIN_FROM $emio_gpio_index \
  CONFIG.DOUT_WIDTH {1} \
  ] $reset_frmbuf_wr

  connect_bd_net -net reset_frmbuf_wr_Dout [get_bd_pins reset_frmbuf_wr/Dout] [get_bd_pins v_frmbuf_wr/ap_rst_n]
  connect_bd_net [get_bd_pins emio_gpio] [get_bd_pins reset_frmbuf_wr/Din]


  # Add and configure AXI IIC
  set axi_iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_0]
  
  # Add and configure AXI GPIO
  set axi_gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0]
  set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_DOUT_DEFAULT {0x00000001} ] $axi_gpio
  
  # Connect the 200M D-PHY clock
  connect_bd_net [get_bd_pins dphy_clk_200M] [get_bd_pins mipi_csi2_rx_subsyst_0/dphy_clk_200M]
  # Connect the 250M video clock
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins mipi_csi2_rx_subsyst_0/video_aclk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins subset_conv_0/aclk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_frmbuf_wr/ap_clk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_frmbuf_rd/ap_clk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axis_data_fifo/s_axis_aclk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins demosaic_0/ap_clk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_proc/aclk_axis]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_proc/aclk_ctrl]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins v_gamma_lut/ap_clk]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/S00_ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/M00_ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/M01_ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/M02_ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/M03_ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_int_video/M04_ACLK]
  connect_bd_net [get_bd_pins video_aclk] [get_bd_pins axi_smc/aclk]
  # Connect the 100M AXI-Lite clock
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_int_ctrl/ACLK]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_int_ctrl/S00_ACLK]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_int_ctrl/M00_ACLK]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_int_ctrl/M01_ACLK]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_int_ctrl/M02_ACLK]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins mipi_csi2_rx_subsyst_0/lite_aclk]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_iic_0/s_axi_aclk]
  connect_bd_net [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk]
  # Connect the video resets
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins subset_conv_0/aresetn]
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axis_data_fifo/s_axis_aresetn]
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/S00_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/M00_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/M01_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/M02_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/M03_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_int_video/M04_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins mipi_csi2_rx_subsyst_0/video_aresetn]
  connect_bd_net [get_bd_pins video_aresetn] [get_bd_pins axi_smc/aresetn]
  # Connect the AXI-Lite resets
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_int_ctrl/ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_int_ctrl/S00_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_int_ctrl/M00_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_int_ctrl/M01_ARESETN] -boundary_type upper
  connect_bd_net [get_bd_pins aresetn] [get_bd_pins axi_int_ctrl/M02_ARESETN] -boundary_type upper
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
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M00_AXI] [get_bd_intf_pins demosaic_0/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M01_AXI] [get_bd_intf_pins v_gamma_lut/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M02_AXI] [get_bd_intf_pins v_proc/s_axi_ctrl]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M03_AXI] [get_bd_intf_pins v_frmbuf_wr/s_axi_CTRL]
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_int_video/M04_AXI] [get_bd_intf_pins v_frmbuf_rd/s_axi_CTRL]
  # Connect the AXI Streaming interfaces
  connect_bd_intf_net [get_bd_intf_pins mipi_csi2_rx_subsyst_0/video_out] [get_bd_intf_pins subset_conv_0/S_AXIS]
  connect_bd_intf_net [get_bd_intf_pins subset_conv_0/M_AXIS] [get_bd_intf_pins axis_data_fifo/S_AXIS]
  connect_bd_intf_net [get_bd_intf_pins axis_data_fifo/M_AXIS] [get_bd_intf_pins demosaic_0/s_axis_video]
  connect_bd_intf_net [get_bd_intf_pins demosaic_0/m_axis_video] [get_bd_intf_pins v_gamma_lut/s_axis_video]
  connect_bd_intf_net [get_bd_intf_pins v_gamma_lut/m_axis_video] [get_bd_intf_pins v_proc/s_axis]
  connect_bd_intf_net [get_bd_intf_pins v_proc/m_axis] [get_bd_intf_pins v_frmbuf_wr/s_axis_video]
  connect_bd_intf_net [get_bd_intf_pins v_frmbuf_rd/m_axis_video] [get_bd_intf_pins m_axis_video]
  # Connect the MIPI D-PHY interface
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins mipi_phy_if] [get_bd_intf_pins mipi_csi2_rx_subsyst_0/mipi_phy_if]
  # Connect the I2C interface
  connect_bd_intf_net [get_bd_intf_pins IIC] [get_bd_intf_pins axi_iic_0/IIC]
  # Connect the GPIO interface
  connect_bd_intf_net [get_bd_intf_pins GPIO] [get_bd_intf_pins axi_gpio_0/GPIO]
  # Connect interrupts
  connect_bd_net [get_bd_pins mipi_sub_irq] [get_bd_pins mipi_csi2_rx_subsyst_0/csirxss_csi_irq]
  connect_bd_net [get_bd_pins demosaic_irq] [get_bd_pins demosaic_0/interrupt]
  connect_bd_net [get_bd_pins gamma_lut_irq] [get_bd_pins v_gamma_lut/interrupt]
  connect_bd_net [get_bd_pins frmbufwr_irq] [get_bd_pins v_frmbuf_wr/interrupt]
  connect_bd_net [get_bd_pins frmbufrd_irq] [get_bd_pins v_frmbuf_rd/interrupt]
  connect_bd_net [get_bd_pins iic2intc_irpt] [get_bd_pins axi_iic_0/iic2intc_irpt]
  
  current_bd_instance \
}

# Number of cameras
set num_cams [llength $cams]

# Add constant for the CAM1 and CAM3 CLK_SEL pin (01b for UltraZed-EV Carrier + AUBoard and 00b for Genesys ZU, 10b for all other boards)
set clk_sel [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant clk_sel]
set_property -dict [list CONFIG.CONST_WIDTH {2}] $clk_sel
if { $target == "auboard" } {
  set_property -dict [list CONFIG.CONST_VAL {0x01}] $clk_sel
} else {
  set_property -dict [list CONFIG.CONST_VAL {0x02}] $clk_sel
}
create_bd_port -dir O clk_sel
connect_bd_net [get_bd_ports clk_sel] [get_bd_pins clk_sel/dout]

# Add and configure GPIO for the reserved GPIOs
set rsvd_gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio rsvd_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH {10} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_DOUT_DEFAULT {0x00000030} ] $rsvd_gpio
connect_bd_net [get_bd_pins clk_wiz/clk_100M] [get_bd_pins rsvd_gpio/s_axi_aclk]
connect_bd_net [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn] [get_bd_pins rsvd_gpio/s_axi_aresetn]
lappend periph_ports [list "rsvd_gpio/S_AXI" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 rsvd_gpio
connect_bd_intf_net [get_bd_intf_pins rsvd_gpio/GPIO] [get_bd_intf_ports rsvd_gpio]

# Create AXI GPIO to drive the video port IP resets
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0
set_property CONFIG.C_GPIO_WIDTH {32} [get_bd_cells axi_gpio_0]
connect_bd_net [get_bd_pins clk_wiz/clk_100M] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
lappend periph_ports [list "axi_gpio_0/S_AXI" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]

# Reconfigure the DDR AXI SmartConnect to accommodate the Frame Buffers
set smartcon_ports [expr {$num_cams+2}]
set_property -dict [list \
  CONFIG.NUM_SI $smartcon_ports \
  CONFIG.NUM_CLKS {3} \
] [get_bd_cells axi_smc]
connect_bd_net [get_bd_pins clk_wiz/clk_300M] [get_bd_pins axi_smc/aclk2]

# Add the MIPI pipes
set smartcon_index 2
foreach i $cams {
  # Create the MIPI pipe block
  create_mipi_pipe $i [dict get $mipi_loc_dict $target $i]
  # Externalize all of the strobe propagation pins
  set strobe_pins [get_bd_pins mipi_$i/mipi_csi2_rx_subsyst_0/bg*_nc]
  foreach strobe $strobe_pins {
    set strobe_pin_name [file tail $strobe]
    create_bd_port -dir I mipi_${i}_$strobe_pin_name
    connect_bd_net [get_bd_ports mipi_${i}_$strobe_pin_name] [get_bd_pins $strobe]
  }
  # Connect clocks
  connect_bd_net [get_bd_pins clk_wiz/clk_200M] [get_bd_pins mipi_$i/dphy_clk_200M]
  connect_bd_net [get_bd_pins clk_wiz/clk_100M] [get_bd_pins mipi_$i/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins $cam_clk] [get_bd_pins mipi_$i/video_aclk]
  # Connect resets
  connect_bd_net [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn] [get_bd_pins mipi_$i/aresetn]
  connect_bd_net [get_bd_pins $cam_rst/peripheral_aresetn] [get_bd_pins mipi_$i/video_aresetn]
  # Connect the resets
  connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins mipi_$i/emio_gpio]
  # Add interrupts to the interrupt list to be connected later
  lappend intr_list "mipi_$i/mipi_sub_irq"
  lappend intr_list "mipi_$i/demosaic_irq"
  lappend intr_list "mipi_$i/gamma_lut_irq"
  lappend intr_list "mipi_$i/frmbufwr_irq"
  lappend intr_list "mipi_$i/frmbufrd_irq"
  lappend intr_list "mipi_$i/iic2intc_irpt"
  
  # AXI Lite interfaces to be connected later
  lappend periph_ports [list "mipi_$i/S_AXI_CTRL" "clk_wiz/clk_100M" "rst_clk_wiz_100M/peripheral_aresetn"]
  lappend periph_ports [list "mipi_$i/S_AXI_VIDEO" $cam_clk $cam_rst/peripheral_aresetn]
  # Connect the MIPI D-Phy interface
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 mipi_phy_if_$i
  connect_bd_intf_net [get_bd_intf_ports mipi_phy_if_$i] -boundary_type upper [get_bd_intf_pins mipi_$i/mipi_phy_if]
  # Connect the I2C interface
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 iic_$i
  connect_bd_intf_net [get_bd_intf_ports iic_$i] [get_bd_intf_pins mipi_$i/IIC]
  # Connect the GPIO interface
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 gpio_$i
  connect_bd_intf_net [get_bd_intf_ports gpio_$i] [get_bd_intf_pins mipi_$i/GPIO]
  # Connect the AXI MM interfaces of the Frame Buffers
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins mipi_$i/M_AXI_MM] [get_bd_intf_pins axi_smc/S0${smartcon_index}_AXI]
  # Connect the video AXIS interface
  #connect_bd_intf_net [get_bd_intf_pins mipi_$i/m_axis_video] [get_bd_intf_pins v_mix_0/s_axis_video${cam_index}]
  # Increment the smartconnector index
  set smartcon_index [expr {$smartcon_index+1}]
}

connect_bd_intf_net -boundary_type upper [get_bd_intf_pins mipi_2/m_axis_video] [get_bd_intf_pins rx_video_axis_reg_slice/S_AXIS]

#########################################################
# AXI Interfaces and interrupts
#########################################################

# Add AXI Interconnect for the AXI Lite interfaces

proc create_axi_ic {label ports} {
  # Set number of master ports
  set n_periph_ports [llength $ports]
  set n_periph_ports [expr {$n_periph_ports+1}]
  set axi_ip [get_bd_cells $label]
  set_property -dict [list CONFIG.NUM_MI $n_periph_ports] $axi_ip
  # Attach all of the ports, their clocks and resets
  set port_num 1
  foreach port $ports {
    set port_name [format "M%02d" $port_num]
    set port_label [lindex $port 0]
    connect_bd_intf_net -boundary_type upper [get_bd_intf_pins $label/${port_name}_AXI] [get_bd_intf_pins $port_label]
    set port_clk [lindex $port 1]
    connect_bd_net [get_bd_pins $port_clk] [get_bd_pins $label/${port_name}_ACLK]
    set port_rst [lindex $port 2]
    connect_bd_net [get_bd_pins $port_rst] [get_bd_pins $label/${port_name}_ARESETN]
    set port_num [expr {$port_num+1}]
  }
}

# Connect peripheral AXI ports
create_axi_ic "microblaze_0_axi_periph" $periph_ports

# Connect the interrupts to AXI Intc(max 32 interrupts)
set n_interrupts [llength $intr_list]
set intr_concat [get_bd_cells "microblaze_0_xlconcat"]
set_property -dict [list CONFIG.NUM_PORTS $n_interrupts] $intr_concat
set intr_index 0
foreach intr $intr_list {
  connect_bd_net [get_bd_pins $intr] [get_bd_pins ${intr_concat}/In$intr_index]
  set intr_index [expr {$intr_index+1}]
}

# Assign addresses
assign_bd_address



# Restore current instance
current_bd_instance $oldCurInst

save_bd_design
