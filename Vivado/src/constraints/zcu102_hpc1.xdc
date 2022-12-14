# I2C signals for MIPI 0
set_property PACKAGE_PIN AD2 [get_ports iic_0_scl_io]; # LA02_P
set_property PACKAGE_PIN AD1 [get_ports iic_0_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_0_*]
set_property SLEW SLOW [get_ports iic_0_*]
set_property DRIVE 4 [get_ports iic_0_*]

# I2C signals for MIPI 1
set_property PACKAGE_PIN AG3 [get_ports iic_1_scl_io]; # LA05_P
set_property PACKAGE_PIN AH3 [get_ports iic_1_sda_io]; # LA05_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_1_*]
set_property SLEW SLOW [get_ports iic_1_*]
set_property DRIVE 4 [get_ports iic_1_*]

# PIN_SWAP signals
set_property PACKAGE_PIN AD4 [get_ports {pin_swap[0]}]; # LA07_P
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[0]}]

set_property PACKAGE_PIN AE4 [get_ports {pin_swap[1]}]; # LA07_N
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[1]}]

set_property PACKAGE_PIN T12 [get_ports {pin_swap[2]}]; # LA26_P
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[2]}]

# GPIOs for MIPI camera 0
set_property PACKAGE_PIN AD10 [get_ports {gpio_0_tri_o[0]}]; # LA15_P
set_property PACKAGE_PIN AE9 [get_ports {gpio_0_tri_o[1]}]; # LA15_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_0_tri_o[*]}]

# GPIOs for MIPI camera 1
set_property PACKAGE_PIN AG10 [get_ports {gpio_1_tri_o[0]}]; # LA16_P
set_property PACKAGE_PIN AG9 [get_ports {gpio_1_tri_o[1]}]; # LA16_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_1_tri_o[*]}]

# MIPI interface 0
set_property PACKAGE_PIN AE5 [get_ports {mipi_phy_if_0_clk_p}]; # LA00_CC_P
set_property PACKAGE_PIN AF5 [get_ports {mipi_phy_if_0_clk_n}]; # LA00_CC_N
set_property PACKAGE_PIN AH1 [get_ports {mipi_phy_if_0_data_p[0]}]; # LA03_P
set_property PACKAGE_PIN AJ1 [get_ports {mipi_phy_if_0_data_n[0]}]; # LA03_N
set_property PACKAGE_PIN AF2 [get_ports {mipi_phy_if_0_data_p[1]}]; # LA04_P
set_property PACKAGE_PIN AF1 [get_ports {mipi_phy_if_0_data_n[1]}]; # LA04_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_n[*]]

# MIPI interface 1
set_property PACKAGE_PIN AJ6 [get_ports {mipi_phy_if_1_clk_p}]; # LA01_CC_P
set_property PACKAGE_PIN AJ5 [get_ports {mipi_phy_if_1_clk_n}]; # LA01_CC_N
set_property PACKAGE_PIN AD7 [get_ports {mipi_phy_if_1_data_p[0]}]; # LA12_P
set_property PACKAGE_PIN AD6 [get_ports {mipi_phy_if_1_data_n[0]}]; # LA12_N
set_property PACKAGE_PIN AG8 [get_ports {mipi_phy_if_1_data_p[1]}]; # LA13_P
set_property PACKAGE_PIN AH8 [get_ports {mipi_phy_if_1_data_n[1]}]; # LA13_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_n[*]]

