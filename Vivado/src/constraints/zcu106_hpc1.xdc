# I2C signals for MIPI 0
set_property PACKAGE_PIN K22 [get_ports iic_0_scl_io]; # LA02_P
set_property PACKAGE_PIN K23 [get_ports iic_0_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_0_*]
set_property SLEW SLOW [get_ports iic_0_*]
set_property DRIVE 4 [get_ports iic_0_*]

# I2C signals for MIPI 1
set_property PACKAGE_PIN G25 [get_ports iic_1_scl_io]; # LA05_P
set_property PACKAGE_PIN G26 [get_ports iic_1_sda_io]; # LA05_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_1_*]
set_property SLEW SLOW [get_ports iic_1_*]
set_property DRIVE 4 [get_ports iic_1_*]

# PIN_SWAP signals
set_property PACKAGE_PIN D22 [get_ports {pin_swap[0]}]; # LA07_P
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[0]}]

set_property PACKAGE_PIN C23 [get_ports {pin_swap[1]}]; # LA07_N
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[1]}]

# GPIOs for MIPI camera 0
set_property PACKAGE_PIN A18 [get_ports {gpio_0_tri_o[0]}]; # LA15_P
set_property PACKAGE_PIN A19 [get_ports {gpio_0_tri_o[1]}]; # LA15_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_0_tri_o[*]}]

# GPIOs for MIPI camera 1
set_property PACKAGE_PIN C18 [get_ports {gpio_1_tri_o[0]}]; # LA16_P
set_property PACKAGE_PIN C19 [get_ports {gpio_1_tri_o[1]}]; # LA16_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_1_tri_o[*]}]

# MIPI interface 0
set_property PACKAGE_PIN K22 [get_ports {mipi_phy_if_0_clk_p}]; # LA02_P
set_property PACKAGE_PIN K23 [get_ports {mipi_phy_if_0_clk_n}]; # LA02_N
set_property PACKAGE_PIN J21 [get_ports {mipi_phy_if_0_data_p[0]}]; # LA03_P
set_property PACKAGE_PIN J22 [get_ports {mipi_phy_if_0_data_n[0]}]; # LA03_N
set_property PACKAGE_PIN J24 [get_ports {mipi_phy_if_0_data_p[1]}]; # LA04_P
set_property PACKAGE_PIN H24 [get_ports {mipi_phy_if_0_data_n[1]}]; # LA04_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_n[*]]

# MIPI interface 1
set_property PACKAGE_PIN E24 [get_ports {mipi_phy_if_1_clk_p}]; # LA01_CC_P
set_property PACKAGE_PIN D24 [get_ports {mipi_phy_if_1_clk_n}]; # LA01_CC_N
set_property PACKAGE_PIN E19 [get_ports {mipi_phy_if_1_data_p[0]}]; # LA12_P
set_property PACKAGE_PIN D19 [get_ports {mipi_phy_if_1_data_n[0]}]; # LA12_N
set_property PACKAGE_PIN C21 [get_ports {mipi_phy_if_1_data_p[1]}]; # LA13_P
set_property PACKAGE_PIN C22 [get_ports {mipi_phy_if_1_data_n[1]}]; # LA13_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_n[*]]

