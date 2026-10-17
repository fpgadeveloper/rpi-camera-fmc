# SPDX-License-Identifier: MIT
# DVI output on the VEK280 HDMI TX connector, used by src/bd/dvi_out.tcl.
# Sources: UG1612 "HDMI Video Input/Output", "HDMI Control I2C Bus", "HDMI Clocking",
# and the HDMI 2.1 section of AMD's VEK280 MIPI CSI-2 RX example design XDC
# (mipi_csi2_rx_subsystem 6.0) / v_hdmi_txss1 VEK280 example XDC (identical pinout).

# TMDS lanes: GTYP bank 204 (GTYP_QUAD_X1Y2) TX0..TX3 -> TMDS1204 redriver (U335),
# whose lane swap (reg 0x0A) is set over I2C by dvi-init.
# TX0..2 = TMDS data 0..2, TX3 = TMDS clock (AMD HDMI GT controller convention).
set_property PACKAGE_PIN R38 [get_ports {hdmi_tx_txp[0]}]
set_property PACKAGE_PIN P36 [get_ports {hdmi_tx_txp[1]}]
set_property PACKAGE_PIN N38 [get_ports {hdmi_tx_txp[2]}]
set_property PACKAGE_PIN M36 [get_ports {hdmi_tx_txp[3]}]

# Reference clock: 8T49N241 (U362) HDMI_8T49N241_OUT -> GTYP_REFCLK1_204, 148.5 MHz
set_property PACKAGE_PIN AB30 [get_ports hdmi_tx_refclk_clk_p]
create_clock -period 6.734 -name hdmi_tx_refclk [get_ports hdmi_tx_refclk_clk_p]

# HDMI control I2C (TMDS1204 TX @0x5E, TMDS1204 RX @0x5B, 8T49N241 @0x6C, EEPROM @0x50), XPIO bank 702, 1.5 V
set_property PACKAGE_PIN AR15 [get_ports hdmi_ctl_iic_scl_io]
set_property PACKAGE_PIN AT16 [get_ports hdmi_ctl_iic_sda_io]
set_property IOSTANDARD LVCMOS15 [get_ports hdmi_ctl_iic_scl_io]
set_property IOSTANDARD LVCMOS15 [get_ports hdmi_ctl_iic_sda_io]

# TX redriver enable, TX HPD, 8T49N241 LOL
set_property PACKAGE_PIN AM16 [get_ports hdmi_tx_en]
set_property PACKAGE_PIN AN16 [get_ports hdmi_tx_hpd]
set_property PACKAGE_PIN AP14 [get_ports hdmi_clk_lol]
set_property IOSTANDARD LVCMOS15 [get_ports hdmi_tx_en]
set_property IOSTANDARD LVCMOS15 [get_ports hdmi_tx_hpd]
set_property IOSTANDARD LVCMOS15 [get_ports hdmi_clk_lol]
