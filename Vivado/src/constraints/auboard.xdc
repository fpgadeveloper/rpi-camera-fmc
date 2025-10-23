##################################
# Constraints for the AUBoard 15P
##################################

# I2C signals for MIPI 0
set_property PACKAGE_PIN M21 [get_ports iic_0_scl_io]; # LA03_N
set_property PACKAGE_PIN M20 [get_ports iic_0_sda_io]; # LA03_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_0_*]
set_property SLEW SLOW [get_ports iic_0_*]
set_property DRIVE 4 [get_ports iic_0_*]

# I2C signals for MIPI 1
#set_property PACKAGE_PIN L19 [get_ports iic_1_scl_io]; # LA05_N
#set_property PACKAGE_PIN M19 [get_ports iic_1_sda_io]; # LA05_P
#set_property IOSTANDARD LVCMOS12 [get_ports iic_1_*]
#set_property SLEW SLOW [get_ports iic_1_*]
#set_property DRIVE 4 [get_ports iic_1_*]

# I2C signals for MIPI 2
set_property PACKAGE_PIN C13 [get_ports iic_2_scl_io]; # LA30_N
set_property PACKAGE_PIN C14 [get_ports iic_2_sda_io]; # LA30_P
set_property IOSTANDARD LVCMOS12 [get_ports iic_2_*]
set_property SLEW SLOW [get_ports iic_2_*]
set_property DRIVE 4 [get_ports iic_2_*]

# I2C signals for MIPI 3
#set_property PACKAGE_PIN A12 [get_ports iic_3_scl_io]; # LA32_N
#set_property PACKAGE_PIN A13 [get_ports iic_3_sda_io]; # LA32_P
#set_property IOSTANDARD LVCMOS12 [get_ports iic_3_*]
#set_property SLEW SLOW [get_ports iic_3_*]
#set_property DRIVE 4 [get_ports iic_3_*]

# CAM1 and CAM3 CLK_SEL signals
set_property PACKAGE_PIN H13 [get_ports {clk_sel[0]}]; # LA25_N
set_property IOSTANDARD LVCMOS12 [get_ports {clk_sel[0]}]

set_property PACKAGE_PIN J13 [get_ports {clk_sel[1]}]; # LA25_P
set_property IOSTANDARD LVCMOS12 [get_ports {clk_sel[1]}]

# GPIOs for MIPI camera 0
set_property PACKAGE_PIN K18 [get_ports {gpio_0_tri_o[0]}]; # LA12_N
set_property PACKAGE_PIN L18 [get_ports {gpio_0_tri_o[1]}]; # LA12_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_0_tri_o[*]}]

# GPIOs for MIPI camera 1
#set_property PACKAGE_PIN H22 [get_ports {gpio_1_tri_o[0]}]; # LA09_N
#set_property PACKAGE_PIN H21 [get_ports {gpio_1_tri_o[1]}]; # LA09_P
#set_property IOSTANDARD LVCMOS12 [get_ports {gpio_1_tri_o[*]}]

# GPIOs for MIPI camera 2
set_property PACKAGE_PIN E23 [get_ports {gpio_2_tri_o[0]}]; # LA19_N
set_property PACKAGE_PIN F23 [get_ports {gpio_2_tri_o[1]}]; # LA19_P
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_2_tri_o[*]}]

# GPIOs for MIPI camera 3
#set_property PACKAGE_PIN D25 [get_ports {gpio_3_tri_o[0]}]; # LA20_N
#set_property PACKAGE_PIN D24 [get_ports {gpio_3_tri_o[1]}]; # LA20_P
#set_property IOSTANDARD LVCMOS12 [get_ports {gpio_3_tri_o[*]}]

# Reserved GPIOs
set_property PACKAGE_PIN J19 [get_ports {rsvd_gpio_tri_o[0]}]; # LA04_P
set_property PACKAGE_PIN J20 [get_ports {rsvd_gpio_tri_o[1]}]; # LA04_N
set_property PACKAGE_PIN J12 [get_ports {rsvd_gpio_tri_o[2]}]; # LA07_P
set_property PACKAGE_PIN H12 [get_ports {rsvd_gpio_tri_o[3]}]; # LA07_N
set_property PACKAGE_PIN K22 [get_ports {rsvd_gpio_tri_o[4]}]; # LA13_P
set_property PACKAGE_PIN K23 [get_ports {rsvd_gpio_tri_o[5]}]; # LA13_N
set_property PACKAGE_PIN J15 [get_ports {rsvd_gpio_tri_o[6]}]; # LA27_P
set_property PACKAGE_PIN J14 [get_ports {rsvd_gpio_tri_o[7]}]; # LA27_N
set_property PACKAGE_PIN D14 [get_ports {rsvd_gpio_tri_o[8]}]; # LA29_P
set_property PACKAGE_PIN D13 [get_ports {rsvd_gpio_tri_o[9]}]; # LA29_N
set_property IOSTANDARD LVCMOS12 [get_ports {rsvd_gpio_tri_o[*]}]

# MIPI interface 0
set_property PACKAGE_PIN F24 [get_ports {mipi_phy_if_0_clk_p}]; # LA00_CC_P
set_property PACKAGE_PIN F25 [get_ports {mipi_phy_if_0_clk_n}]; # LA00_CC_N
set_property PACKAGE_PIN D26 [get_ports {mipi_phy_if_0_data_p[0]}]; # LA06_P
set_property PACKAGE_PIN C26 [get_ports {mipi_phy_if_0_data_n[0]}]; # LA06_N
set_property PACKAGE_PIN H26 [get_ports {mipi_phy_if_0_data_p[1]}]; # LA02_P
set_property PACKAGE_PIN G26 [get_ports {mipi_phy_if_0_data_n[1]}]; # LA02_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_0_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_0_data_n[*]]

# MIPI interface 1
#set_property PACKAGE_PIN L24 [get_ports {mipi_phy_if_1_clk_p}]; # LA16_P
#set_property PACKAGE_PIN L25 [get_ports {mipi_phy_if_1_clk_n}]; # LA16_N
#set_property PACKAGE_PIN K21 [get_ports {mipi_phy_if_1_data_p[0]}]; # LA15_P
#set_property PACKAGE_PIN J21 [get_ports {mipi_phy_if_1_data_n[0]}]; # LA15_N
#set_property PACKAGE_PIN L20 [get_ports {mipi_phy_if_1_data_p[1]}]; # LA14_P
#set_property PACKAGE_PIN K20 [get_ports {mipi_phy_if_1_data_n[1]}]; # LA14_N

#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_p]
#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_clk_n]
#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_p[*]]
#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_1_data_n[*]]

#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_p]
#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_clk_n]
#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_p[*]]
#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_1_data_n[*]]

# MIPI interface 2
set_property PACKAGE_PIN G24 [get_ports {mipi_phy_if_2_clk_p}]; # LA18_CC_P
set_property PACKAGE_PIN G25 [get_ports {mipi_phy_if_2_clk_n}]; # LA18_CC_N
set_property PACKAGE_PIN H23 [get_ports {mipi_phy_if_2_data_p[0]}]; # LA24_P
set_property PACKAGE_PIN H24 [get_ports {mipi_phy_if_2_data_n[0]}]; # LA24_N
set_property PACKAGE_PIN J25 [get_ports {mipi_phy_if_2_data_p[1]}]; # LA17_CC_P
set_property PACKAGE_PIN J26 [get_ports {mipi_phy_if_2_data_n[1]}]; # LA17_CC_N

set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_clk_p]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_clk_n]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_data_p[*]]
set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_2_data_n[*]]

set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_clk_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_clk_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_data_p[*]]
set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_2_data_n[*]]

# MIPI interface 3
#set_property PACKAGE_PIN L22 [get_ports {mipi_phy_if_3_clk_p}]; # LA26_P
#set_property PACKAGE_PIN L23 [get_ports {mipi_phy_if_3_clk_n}]; # LA26_N
#set_property PACKAGE_PIN M25 [get_ports {mipi_phy_if_3_data_p[0]}]; # LA33_P
#set_property PACKAGE_PIN M26 [get_ports {mipi_phy_if_3_data_n[0]}]; # LA33_N
#set_property PACKAGE_PIN K25 [get_ports {mipi_phy_if_3_data_p[1]}]; # LA28_P
#set_property PACKAGE_PIN K26 [get_ports {mipi_phy_if_3_data_n[1]}]; # LA28_N

#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_clk_p]
#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_clk_n]
#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_data_p[*]]
#set_property IOSTANDARD MIPI_DPHY_DCI [get_ports mipi_phy_if_3_data_n[*]]

#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_clk_p]
#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_clk_n]
#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_data_p[*]]
#set_property DIFF_TERM_ADV TERM_100 [get_ports mipi_phy_if_3_data_n[*]]

# HDMI output (TX)

# CLK_297M_P/N - MGTREFCLK0P/N - P7/P6 (FROM CLK GENERATOR)
set_property PACKAGE_PIN P7 [get_ports TX_REFCLK_P_IN]
create_clock -period 3.367 -name tx_mgt_refclk [get_ports TX_REFCLK_P_IN]

# HDMI_TX_CLK_P/N - BANK65 - T25/U25
set_property PACKAGE_PIN T25 [get_ports HDMI_TX_CLK_P_OUT]
set_property IOSTANDARD DIFF_HSUL_12 [get_ports HDMI_TX_CLK_P_OUT]
set_property OUTPUT_IMPEDANCE RDRV_40_40 [get_ports HDMI_TX_CLK_P_OUT]
set_property SLEW SLOW [get_ports HDMI_TX_CLK_P_OUT]
set_property SLEW SLOW [get_ports HDMI_TX_CLK_N_OUT]

# HDMI_TX_HPD - BANK65 - W21
set_property PACKAGE_PIN W21 [get_ports TX_HPD_IN]
set_property IOSTANDARD LVCMOS12 [get_ports TX_HPD_IN]

# HDMI_TX_SRC_SCL - BANK65 - R25
set_property PACKAGE_PIN R25 [get_ports TX_DDC_OUT_scl_io]
set_property IOSTANDARD LVCMOS12 [get_ports TX_DDC_OUT_scl_io]
set_property DRIVE 8 [get_ports TX_DDC_OUT_scl_io]

# HDMI_TX_SRC_SDA - BANK65 - R26
set_property PACKAGE_PIN R26 [get_ports TX_DDC_OUT_sda_io]
set_property IOSTANDARD LVCMOS12 [get_ports TX_DDC_OUT_sda_io]
set_property DRIVE 8 [get_ports TX_DDC_OUT_sda_io]

# UART

# UART_TX - BANK84 - AF15 (SWAPPED AT TRANSLATOR U23 - MAY NEED CROSSING)
set_property PACKAGE_PIN AF15 [get_ports RS232_UART_txd]
set_property IOSTANDARD LVCMOS18 [get_ports RS232_UART_txd]

# UART_RX - BANK84 - AF14 (SWAPPED AT TRANSLATOR U23 - MAY NEED CROSSING)
set_property PACKAGE_PIN AF14 [get_ports RS232_UART_rxd]
set_property IOSTANDARD LVCMOS18 [get_ports RS232_UART_rxd]

# Misc

# LED1 - BANK85 - A10
set_property PACKAGE_PIN A10 [get_ports LED0]
set_property IOSTANDARD LVCMOS33 [get_ports LED0]

# LED2 - BANK85 - B10 - CLKGEN RESET
set_property PACKAGE_PIN B10 [get_ports {LED1[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED1[0]}]

# LED3 - BANK85 - B11 - CLKGEN LOL
set_property PACKAGE_PIN B11 [get_ports LED2]
set_property IOSTANDARD LVCMOS33 [get_ports LED2]

# RST_CLOCK_N - BANK66 - G22 
set_property PACKAGE_PIN G22 [get_ports {IDT_8T49N241_RST_OUT[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {IDT_8T49N241_RST_OUT[0]}]

# PLL_LOCKED - BANK66 - F22
set_property PACKAGE_PIN F22 [get_ports IDT_8T49N241_LOL_IN]
set_property IOSTANDARD LVCMOS12 [get_ports IDT_8T49N241_LOL_IN]

# HDMI_TX_EN - BANK65 - Y23
set_property PACKAGE_PIN Y23 [get_ports {TX_EN_OUT[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {TX_EN_OUT[0]}]

# HDMI_TX_CEC - BANK65 - AA23
set_property PACKAGE_PIN AA23 [get_ports {TX_CLKSEL_OUT[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {TX_CLKSEL_OUT[0]}]

# sys_diff_clock_clk_p/n - SYSCLK_P/N - Bank64 - AD21 / AE21
#set_property PACKAGE_PIN AD21 [get_ports sys_diff_clock_clk_p]
#set_property IOSTANDARD DIFF_SSTL12 [get_ports sys_diff_clock_clk_p]
set_property DCI_CASCADE {65} [get_iobanks 64]

# I2C

# HDMI_CTL_SCL - BANK65 - R22
set_property PACKAGE_PIN R22 [get_ports HDMI_CLK_IIC_scl_io]
set_property IOSTANDARD LVCMOS12 [get_ports HDMI_CLK_IIC_scl_io]
set_property DRIVE 8 [get_ports HDMI_CLK_IIC_scl_io]

# HDMI_CTL_SDA - BANK65 -R23
set_property PACKAGE_PIN R23 [get_ports HDMI_CLK_IIC_sda_io]
set_property IOSTANDARD LVCMOS12 [get_ports HDMI_CLK_IIC_sda_io]
set_property DRIVE 8 [get_ports HDMI_CLK_IIC_sda_io]

# SCL_SCLK - BANK85 -B9
set_property PACKAGE_PIN B9 [get_ports GTH_CLK_IIC_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports GTH_CLK_IIC_scl_io]
set_property DRIVE 8 [get_ports GTH_CLK_IIC_scl_io]

# SDA_nCS - BANK85 - A9
set_property PACKAGE_PIN A9 [get_ports GTH_CLK_IIC_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports GTH_CLK_IIC_sda_io]
set_property DRIVE 8 [get_ports GTH_CLK_IIC_sda_io]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 31.9 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
