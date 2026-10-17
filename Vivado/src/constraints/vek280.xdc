# RPi Camera FMC (OP068) on VEK280 FMCP: cameras CAM0, CAM1, CAM3
#
# Pin LOCs from the FPGA Board Repository (generate_fmc_constraints OP068 / VEK280 / FMCP).
# On Versal the MIPI CSI-2 RX D-PHY pins come only from this file (the IP has no I/O tab).
# Each camera needs its own XPHY nibble(s) for its clock-lane strobe, which limits the
# camera set per FMC slot: see docs (supported carriers) for the details.
#
# VEK280: VADJ_FMC is fixed at 1.5 V by the board (UG1612). The FMC banks are
# constrained with the 1.2 V standards MIPI_DPHY + LVCMOS12, as in AMD's own VEK280
# MIPI example design, which Vivado requires for MIPI_DPHY in an XPIO bank.

# CAM1 and CAM3 CLK_SEL signals (clk_sel = 0b10: CAM1 clock on LA01, CAM3 clock on LA31)
set_property PACKAGE_PIN AW42 [get_ports {clk_sel[0]}]; # LA25_N
set_property PACKAGE_PIN AV42 [get_ports {clk_sel[1]}]; # LA25_P
set_property IOSTANDARD LVCMOS12 [get_ports {clk_sel[*]}]

# Camera I/O level-shifter control (direction and output enables)
set_property PACKAGE_PIN AR34 [get_ports {rsvd_gpio_tri_o[0]}]; # LA13_P CAM_IO0_DIR
set_property PACKAGE_PIN AT34 [get_ports {rsvd_gpio_tri_o[1]}]; # LA13_N CAM_IO1_DIR
set_property PACKAGE_PIN AY41 [get_ports {rsvd_gpio_tri_o[2]}]; # LA27_P CAM_IO0_OE_N
set_property PACKAGE_PIN AY42 [get_ports {rsvd_gpio_tri_o[3]}]; # LA27_N CAM_IO1_OE_N
set_property IOSTANDARD LVCMOS12 [get_ports {rsvd_gpio_tri_o[*]}]

# I2C signals for MIPI 0
set_property PACKAGE_PIN AY31 [get_ports iic_0_scl_io]; # LA03_N
set_property PACKAGE_PIN AY30 [get_ports iic_0_sda_io]; # LA03_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_0_*]
set_property SLEW SLOW [get_ports iic_0_*]
set_property DRIVE 4 [get_ports iic_0_*]

# GPIOs for MIPI camera 0
set_property PACKAGE_PIN AR32 [get_ports {gpio_0_tri_o[0]}]; # LA12_N
set_property PACKAGE_PIN AP32 [get_ports {gpio_0_tri_o[1]}]; # LA12_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_0_tri_o[*]}]

# MIPI interface 0
set_property PACKAGE_PIN AV30 [get_ports {mipi_phy_if_0_clk_p}]; # LA00_CC_P
set_property PACKAGE_PIN AW30 [get_ports {mipi_phy_if_0_clk_n}]; # LA00_CC_N
set_property PACKAGE_PIN BA33 [get_ports {mipi_phy_if_0_data_p[0]}]; # LA06_P
set_property PACKAGE_PIN BB33 [get_ports {mipi_phy_if_0_data_n[0]}]; # LA06_N
set_property PACKAGE_PIN BB29 [get_ports {mipi_phy_if_0_data_p[1]}]; # LA02_P
set_property PACKAGE_PIN BB30 [get_ports {mipi_phy_if_0_data_n[1]}]; # LA02_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_0_clk_* mipi_phy_if_0_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_0_clk_* mipi_phy_if_0_data_*}]

# I2C signals for MIPI 1
set_property PACKAGE_PIN BA32 [get_ports iic_1_scl_io]; # LA05_N
set_property PACKAGE_PIN AY32 [get_ports iic_1_sda_io]; # LA05_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_1_*]
set_property SLEW SLOW [get_ports iic_1_*]
set_property DRIVE 4 [get_ports iic_1_*]

# GPIOs for MIPI camera 1
set_property PACKAGE_PIN AW35 [get_ports {gpio_1_tri_o[0]}]; # LA09_N
set_property PACKAGE_PIN AV35 [get_ports {gpio_1_tri_o[1]}]; # LA09_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_1_tri_o[*]}]

# MIPI interface 1
set_property PACKAGE_PIN AU35 [get_ports {mipi_phy_if_1_clk_p}]; # LA01_CC_P
set_property PACKAGE_PIN AU36 [get_ports {mipi_phy_if_1_clk_n}]; # LA01_CC_N
set_property PACKAGE_PIN AT32 [get_ports {mipi_phy_if_1_data_p[0]}]; # LA15_P
set_property PACKAGE_PIN AU31 [get_ports {mipi_phy_if_1_data_n[0]}]; # LA15_N
set_property PACKAGE_PIN AR36 [get_ports {mipi_phy_if_1_data_p[1]}]; # LA14_P
set_property PACKAGE_PIN AT36 [get_ports {mipi_phy_if_1_data_n[1]}]; # LA14_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_1_clk_* mipi_phy_if_1_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_1_clk_* mipi_phy_if_1_data_*}]

# I2C signals for MIPI 3
set_property PACKAGE_PIN AT41 [get_ports iic_3_scl_io]; # LA32_N
set_property PACKAGE_PIN AR41 [get_ports iic_3_sda_io]; # LA32_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_3_*]
set_property SLEW SLOW [get_ports iic_3_*]
set_property DRIVE 4 [get_ports iic_3_*]

# GPIOs for MIPI camera 3
set_property PACKAGE_PIN BA39 [get_ports {gpio_3_tri_o[0]}]; # LA20_N
set_property PACKAGE_PIN AY39 [get_ports {gpio_3_tri_o[1]}]; # LA20_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_3_tri_o[*]}]

# MIPI interface 3
set_property PACKAGE_PIN AR40 [get_ports {mipi_phy_if_3_clk_p}]; # LA31_P
set_property PACKAGE_PIN AT39 [get_ports {mipi_phy_if_3_clk_n}]; # LA31_N
set_property PACKAGE_PIN AR42 [get_ports {mipi_phy_if_3_data_p[0]}]; # LA33_P
set_property PACKAGE_PIN AT42 [get_ports {mipi_phy_if_3_data_n[0]}]; # LA33_N
set_property PACKAGE_PIN BA36 [get_ports {mipi_phy_if_3_data_p[1]}]; # LA28_P
set_property PACKAGE_PIN BB36 [get_ports {mipi_phy_if_3_data_n[1]}]; # LA28_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_3_clk_* mipi_phy_if_3_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_3_clk_* mipi_phy_if_3_data_*}]
