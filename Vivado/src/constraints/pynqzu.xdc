# I2C signals for MIPI 0
set_property PACKAGE_PIN K9 [get_ports iic_0_scl_io]; # LA03_P
set_property PACKAGE_PIN J9 [get_ports iic_0_sda_io]; # LA03_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_0_*]
set_property SLEW SLOW [get_ports iic_0_*]
set_property DRIVE 4 [get_ports iic_0_*]

# I2C signals for MIPI 1
set_property PACKAGE_PIN H9 [get_ports iic_1_scl_io]; # LA04_P
set_property PACKAGE_PIN H8 [get_ports iic_1_sda_io]; # LA04_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_1_*]
set_property SLEW SLOW [get_ports iic_1_*]
set_property DRIVE 4 [get_ports iic_1_*]

# I2C signals for MIPI 2
set_property PACKAGE_PIN AB2 [get_ports iic_2_scl_io]; # LA19_P
set_property PACKAGE_PIN AC2 [get_ports iic_2_sda_io]; # LA19_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_2_*]
set_property SLEW SLOW [get_ports iic_2_*]
set_property DRIVE 4 [get_ports iic_2_*]

# I2C signals for MIPI 3
set_property PACKAGE_PIN AB4 [get_ports iic_3_scl_io]; # LA20_P
set_property PACKAGE_PIN AB3 [get_ports iic_3_sda_io]; # LA20_N
set_property IOSTANDARD LVCMOS12 [get_ports iic_3_*]
set_property SLEW SLOW [get_ports iic_3_*]
set_property DRIVE 4 [get_ports iic_3_*]

# PIN_SWAP signals
set_property PACKAGE_PIN J1 [get_ports {pin_swap[0]}]; # LA05_P
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[0]}]

set_property PACKAGE_PIN H1 [get_ports {pin_swap[1]}]; # LA05_N
set_property IOSTANDARD LVCMOS12 [get_ports {pin_swap[1]}]

# GPIOs for MIPI camera 0
set_property PACKAGE_PIN J6 [get_ports {gpio_0_tri_o[0]}]; # LA07_P
set_property PACKAGE_PIN H6 [get_ports {gpio_0_tri_o[1]}]; # LA07_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_0_tri_o[*]}]

# GPIOs for MIPI camera 1
set_property PACKAGE_PIN L1 [get_ports {gpio_1_tri_o[0]}]; # LA09_P
set_property PACKAGE_PIN K1 [get_ports {gpio_1_tri_o[1]}]; # LA09_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_1_tri_o[*]}]

# GPIOs for MIPI camera 2
set_property PACKAGE_PIN AB1 [get_ports {gpio_2_tri_o[0]}]; # LA22_P
set_property PACKAGE_PIN AC1 [get_ports {gpio_2_tri_o[1]}]; # LA22_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_2_tri_o[*]}]

# GPIOs for MIPI camera 3
set_property PACKAGE_PIN AH2 [get_ports {gpio_3_tri_o[0]}]; # LA25_P
set_property PACKAGE_PIN AH1 [get_ports {gpio_3_tri_o[1]}]; # LA25_N
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_3_tri_o[*]}]

# MIPI interface 0
set_property PACKAGE_PIN L7 [get_ports {mipi_phy_if_0_clk_p}]; # LA00_CC_P
set_property PACKAGE_PIN L6 [get_ports {mipi_phy_if_0_clk_n}]; # LA00_CC_N
set_property PACKAGE_PIN K8 [get_ports {mipi_phy_if_0_data_p[0]}]; # LA02_P
set_property PACKAGE_PIN K7 [get_ports {mipi_phy_if_0_data_n[0]}]; # LA02_N
set_property PACKAGE_PIN J7 [get_ports {mipi_phy_if_0_data_p[1]}]; # LA06_P
set_property PACKAGE_PIN H7 [get_ports {mipi_phy_if_0_data_n[1]}]; # LA06_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_n[*]]

# MIPI interface 1
set_property PACKAGE_PIN P7 [get_ports {mipi_phy_if_1_clk_p}]; # LA01_CC_P
set_property PACKAGE_PIN P6 [get_ports {mipi_phy_if_1_clk_n}]; # LA01_CC_N
set_property PACKAGE_PIN R7 [get_ports {mipi_phy_if_1_data_p[0]}]; # LA14_P
set_property PACKAGE_PIN T7 [get_ports {mipi_phy_if_1_data_n[0]}]; # LA14_N
set_property PACKAGE_PIN N9 [get_ports {mipi_phy_if_1_data_p[1]}]; # LA15_P
set_property PACKAGE_PIN N8 [get_ports {mipi_phy_if_1_data_n[1]}]; # LA15_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_n[*]]

# MIPI interface 2
set_property PACKAGE_PIN AD2 [get_ports {mipi_phy_if_2_clk_p}]; # LA18_CC_P
set_property PACKAGE_PIN AD1 [get_ports {mipi_phy_if_2_clk_n}]; # LA18_CC_N
set_property PACKAGE_PIN AC4 [get_ports {mipi_phy_if_2_data_p[0]}]; # LA17_CC_P
set_property PACKAGE_PIN AC3 [get_ports {mipi_phy_if_2_data_n[0]}]; # LA17_CC_N
set_property PACKAGE_PIN AG3 [get_ports {mipi_phy_if_2_data_p[1]}]; # LA24_P
set_property PACKAGE_PIN AH3 [get_ports {mipi_phy_if_2_data_n[1]}]; # LA24_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_data_n[*]]

# MIPI interface 3
set_property PACKAGE_PIN AG9 [get_ports {mipi_phy_if_3_clk_p}]; # LA31_P
set_property PACKAGE_PIN AH9 [get_ports {mipi_phy_if_3_clk_n}]; # LA31_N
set_property PACKAGE_PIN AG6 [get_ports {mipi_phy_if_3_data_p[0]}]; # LA28_P
set_property PACKAGE_PIN AG5 [get_ports {mipi_phy_if_3_data_n[0]}]; # LA28_N
set_property PACKAGE_PIN AD7 [get_ports {mipi_phy_if_3_data_p[1]}]; # LA33_P
set_property PACKAGE_PIN AE7 [get_ports {mipi_phy_if_3_data_n[1]}]; # LA33_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_data_n[*]]

