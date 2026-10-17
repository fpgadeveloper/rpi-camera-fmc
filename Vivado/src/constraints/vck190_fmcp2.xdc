# RPi Camera FMC (OP068) on VCK190 FMCP2: cameras CAM1, CAM2, CAM3
#
# Pin LOCs from the FPGA Board Repository (generate_fmc_constraints OP068 / VCK190 / FMCP2).
# On Versal the MIPI CSI-2 RX D-PHY pins come only from this file (the IP has no I/O tab).
# Each camera needs its own XPHY nibble(s) for its clock-lane strobe, which limits the
# camera set per FMC slot: see docs (supported carriers) for the details.
#
# VCK190: VADJ_FMC is set to 1.2 V by U-Boot (IR38164 regulator) before Linux boots.

# CAM1 and CAM3 CLK_SEL signals (clk_sel = 0b10: CAM1 clock on LA01, CAM3 clock on LA31)
set_property PACKAGE_PIN BA11 [get_ports {clk_sel[0]}]; # LA25_N
set_property PACKAGE_PIN AY11 [get_ports {clk_sel[1]}]; # LA25_P
set_property IOSTANDARD LVCMOS12 [get_ports {clk_sel[*]}]

# Camera I/O level-shifter control (direction and output enables)
set_property PACKAGE_PIN BB15 [get_ports {rsvd_gpio_tri_o[0]}]; # LA13_P CAM_IO0_DIR
set_property PACKAGE_PIN BC15 [get_ports {rsvd_gpio_tri_o[1]}]; # LA13_N CAM_IO1_DIR
set_property PACKAGE_PIN AW20 [get_ports {rsvd_gpio_tri_o[2]}]; # LA27_P CAM_IO0_OE_N
set_property PACKAGE_PIN AY19 [get_ports {rsvd_gpio_tri_o[3]}]; # LA27_N CAM_IO1_OE_N
set_property IOSTANDARD LVCMOS12 [get_ports {rsvd_gpio_tri_o[*]}]

# I2C signals for MIPI 1
set_property PACKAGE_PIN BA13 [get_ports iic_1_scl_io]; # LA05_N
set_property PACKAGE_PIN AY14 [get_ports iic_1_sda_io]; # LA05_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_1_*]
set_property SLEW SLOW [get_ports iic_1_*]
set_property DRIVE 4 [get_ports iic_1_*]

# GPIOs for MIPI camera 1
set_property PACKAGE_PIN BD14 [get_ports {gpio_1_tri_o[0]}]; # LA09_N
set_property PACKAGE_PIN BD15 [get_ports {gpio_1_tri_o[1]}]; # LA09_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_1_tri_o[*]}]

# MIPI interface 1
set_property PACKAGE_PIN AW12 [get_ports {mipi_phy_if_1_clk_p}]; # LA01_CC_P
set_property PACKAGE_PIN AW13 [get_ports {mipi_phy_if_1_clk_n}]; # LA01_CC_N
set_property PACKAGE_PIN BE12 [get_ports {mipi_phy_if_1_data_p[0]}]; # LA15_P
set_property PACKAGE_PIN BF13 [get_ports {mipi_phy_if_1_data_n[0]}]; # LA15_N
set_property PACKAGE_PIN BE15 [get_ports {mipi_phy_if_1_data_p[1]}]; # LA14_P
set_property PACKAGE_PIN BE14 [get_ports {mipi_phy_if_1_data_n[1]}]; # LA14_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_1_clk_* mipi_phy_if_1_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_1_clk_* mipi_phy_if_1_data_*}]

# I2C signals for MIPI 2
set_property PACKAGE_PIN AP16 [get_ports iic_2_scl_io]; # LA30_N
set_property PACKAGE_PIN AN16 [get_ports iic_2_sda_io]; # LA30_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_2_*]
set_property SLEW SLOW [get_ports iic_2_*]
set_property DRIVE 4 [get_ports iic_2_*]

# GPIOs for MIPI camera 2
set_property PACKAGE_PIN AT13 [get_ports {gpio_2_tri_o[0]}]; # LA19_N
set_property PACKAGE_PIN AR14 [get_ports {gpio_2_tri_o[1]}]; # LA19_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_2_tri_o[*]}]

# MIPI interface 2
set_property PACKAGE_PIN AU13 [get_ports {mipi_phy_if_2_clk_p}]; # LA18_CC_P
set_property PACKAGE_PIN AV13 [get_ports {mipi_phy_if_2_clk_n}]; # LA18_CC_N
set_property PACKAGE_PIN AR11 [get_ports {mipi_phy_if_2_data_p[0]}]; # LA24_P
set_property PACKAGE_PIN AT11 [get_ports {mipi_phy_if_2_data_n[0]}]; # LA24_N
set_property PACKAGE_PIN AY13 [get_ports {mipi_phy_if_2_data_p[1]}]; # LA17_CC_P
set_property PACKAGE_PIN BA12 [get_ports {mipi_phy_if_2_data_n[1]}]; # LA17_CC_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_2_clk_* mipi_phy_if_2_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_2_clk_* mipi_phy_if_2_data_*}]

# I2C signals for MIPI 3
set_property PACKAGE_PIN AM17 [get_ports iic_3_scl_io]; # LA32_N
set_property PACKAGE_PIN AL16 [get_ports iic_3_sda_io]; # LA32_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_3_*]
set_property SLEW SLOW [get_ports iic_3_*]
set_property DRIVE 4 [get_ports iic_3_*]

# GPIOs for MIPI camera 3
set_property PACKAGE_PIN AR15 [get_ports {gpio_3_tri_o[0]}]; # LA20_N
set_property PACKAGE_PIN AP15 [get_ports {gpio_3_tri_o[1]}]; # LA20_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_3_tri_o[*]}]

# MIPI interface 3
set_property PACKAGE_PIN AT16 [get_ports {mipi_phy_if_3_clk_p}]; # LA31_P
set_property PACKAGE_PIN AR17 [get_ports {mipi_phy_if_3_clk_n}]; # LA31_N
set_property PACKAGE_PIN AT17 [get_ports {mipi_phy_if_3_data_p[0]}]; # LA33_P
set_property PACKAGE_PIN AU16 [get_ports {mipi_phy_if_3_data_n[0]}]; # LA33_N
set_property PACKAGE_PIN AU17 [get_ports {mipi_phy_if_3_data_p[1]}]; # LA28_P
set_property PACKAGE_PIN AV17 [get_ports {mipi_phy_if_3_data_n[1]}]; # LA28_N
set_property IOSTANDARD MIPI_DPHY [get_ports {mipi_phy_if_3_clk_* mipi_phy_if_3_data_*}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {mipi_phy_if_3_clk_* mipi_phy_if_3_data_*}]
