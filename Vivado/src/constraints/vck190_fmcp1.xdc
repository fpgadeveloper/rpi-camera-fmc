# RPi Camera FMC (OP068) on VCK190 FMCP1: cameras CAM0, CAM2
#
# Pin LOCs from the FPGA Board Repository (generate_fmc_constraints OP068 / VCK190 / FMCP1).
# On Versal the MIPI CSI-2 RX D-PHY pins come only from this file (the IP has no I/O tab).
# Each camera needs its own XPHY nibble(s) for its clock-lane strobe, which limits the
# camera set per FMC slot: see docs (supported carriers) for the details.
#
# VCK190: VADJ_FMC is set to 1.2 V by U-Boot (IR38164 regulator) before Linux boots.

# CAM1 and CAM3 CLK_SEL signals (clk_sel = 0b10: CAM1 clock on LA01, CAM3 clock on LA31)
set_property PACKAGE_PIN BG16 [get_ports {clk_sel[0]}]; # LA25_N
set_property PACKAGE_PIN BF16 [get_ports {clk_sel[1]}]; # LA25_P
set_property IOSTANDARD LVCMOS12 [get_ports {clk_sel[*]}]

# Camera I/O level-shifter control (direction and output enables)
set_property PACKAGE_PIN BE21 [get_ports {rsvd_gpio_tri_o[0]}]; # LA13_P CAM_IO0_DIR
set_property PACKAGE_PIN BE20 [get_ports {rsvd_gpio_tri_o[1]}]; # LA13_N CAM_IO1_DIR
set_property PACKAGE_PIN BF19 [get_ports {rsvd_gpio_tri_o[2]}]; # LA27_P CAM_IO0_OE_N
set_property PACKAGE_PIN BG19 [get_ports {rsvd_gpio_tri_o[3]}]; # LA27_N CAM_IO1_OE_N
set_property IOSTANDARD LVCMOS12 [get_ports {rsvd_gpio_tri_o[*]}]

# I2C signals for MIPI 0
set_property PACKAGE_PIN AW21 [get_ports iic_0_scl_io]; # LA03_N
set_property PACKAGE_PIN AV22 [get_ports iic_0_sda_io]; # LA03_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_0_*]
set_property SLEW SLOW [get_ports iic_0_*]
set_property DRIVE 4 [get_ports iic_0_*]

# GPIOs for MIPI camera 0
set_property PACKAGE_PIN BF22 [get_ports {gpio_0_tri_o[0]}]; # LA12_N
set_property PACKAGE_PIN BG21 [get_ports {gpio_0_tri_o[1]}]; # LA12_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_0_tri_o[*]}]

# MIPI interface 0
set_property PACKAGE_PIN BD23 [get_ports {mipi_phy_if_0_clk_p}]; # LA00_CC_P
set_property PACKAGE_PIN BD24 [get_ports {mipi_phy_if_0_clk_n}]; # LA00_CC_N
set_property PACKAGE_PIN BC20 [get_ports {mipi_phy_if_0_data_p[0]}]; # LA06_P
set_property PACKAGE_PIN BD20 [get_ports {mipi_phy_if_0_data_n[0]}]; # LA06_N
set_property PACKAGE_PIN AW24 [get_ports {mipi_phy_if_0_data_p[1]}]; # LA02_P
set_property PACKAGE_PIN AY25 [get_ports {mipi_phy_if_0_data_n[1]}]; # LA02_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_0_clk_* mipi_phy_if_0_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_0_clk_* mipi_phy_if_0_data_*}]

# I2C signals for MIPI 2
set_property PACKAGE_PIN AR20 [get_ports iic_2_scl_io]; # LA30_N
set_property PACKAGE_PIN AT20 [get_ports iic_2_sda_io]; # LA30_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_2_*]
set_property SLEW SLOW [get_ports iic_2_*]
set_property DRIVE 4 [get_ports iic_2_*]

# GPIOs for MIPI camera 2
set_property PACKAGE_PIN BA16 [get_ports {gpio_2_tri_o[0]}]; # LA19_N
set_property PACKAGE_PIN BA17 [get_ports {gpio_2_tri_o[1]}]; # LA19_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_2_tri_o[*]}]

# MIPI interface 2
set_property PACKAGE_PIN BE17 [get_ports {mipi_phy_if_2_clk_p}]; # LA18_CC_P
set_property PACKAGE_PIN BD17 [get_ports {mipi_phy_if_2_clk_n}]; # LA18_CC_N
set_property PACKAGE_PIN BA20 [get_ports {mipi_phy_if_2_data_p[0]}]; # LA24_P
set_property PACKAGE_PIN BA19 [get_ports {mipi_phy_if_2_data_n[0]}]; # LA24_N
set_property PACKAGE_PIN BB16 [get_ports {mipi_phy_if_2_data_p[1]}]; # LA17_CC_P
set_property PACKAGE_PIN BC16 [get_ports {mipi_phy_if_2_data_n[1]}]; # LA17_CC_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_2_clk_* mipi_phy_if_2_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_2_clk_* mipi_phy_if_2_data_*}]
