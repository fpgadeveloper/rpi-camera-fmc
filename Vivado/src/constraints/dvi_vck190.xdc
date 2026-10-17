# SPDX-License-Identifier: MIT
# DVI output on the VCK190 HDMI TX connector (P2 upper), used by src/bd/dvi_out.tcl.
# Sources: UG1366 "HDMI Video Output (TX)", AMD v_hdmi_tx_ss VCK190 example XDC
# and the VCK190 Base TRD hdmi_tx_vck190.xdc (identical pinout).

# TMDS lanes: GTY quad 106 (GTY_QUAD_X0Y6) TX0..TX3 -> SN65DP159 retimer (U43).
# TX0..2 = TMDS data 0..2, TX3 = TMDS clock (AMD HDMI GT controller convention).
set_property PACKAGE_PIN F41 [get_ports {hdmi_tx_txp[0]}]
set_property PACKAGE_PIN D41 [get_ports {hdmi_tx_txp[1]}]
set_property PACKAGE_PIN B41 [get_ports {hdmi_tx_txp[2]}]
set_property PACKAGE_PIN A43 [get_ports {hdmi_tx_txp[3]}]

# Reference clock: 8T49N241 (U62) Q2 HDMI_8T49N241_OUT -> MGTREFCLK1_106, 148.5 MHz
set_property PACKAGE_PIN E39 [get_ports hdmi_tx_refclk_clk_p]
create_clock -period 6.734 -name hdmi_tx_refclk [get_ports hdmi_tx_refclk_clk_p]

# HDMI control I2C (8T49N241 @0x6C, SN65DP159 @0x5E), HDIO bank 406, 3.3 V
set_property PACKAGE_PIN K17 [get_ports hdmi_ctl_iic_scl_io]
set_property PACKAGE_PIN L18 [get_ports hdmi_ctl_iic_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_ctl_iic_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_ctl_iic_sda_io]

# HDMI_TX_EN, HDMI_TX_HPD, HDMI_8T49N241_LOL
set_property PACKAGE_PIN K20 [get_ports hdmi_tx_en]
set_property PACKAGE_PIN K18 [get_ports hdmi_tx_hpd]
set_property PACKAGE_PIN G20 [get_ports hdmi_clk_lol]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_tx_en]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_tx_hpd]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_clk_lol]

# HDIO IOBUFs of the I2C master: the IOBUF I input is constant 0 (open drain),
# so the I/T skew check does not apply (AR76846, same waiver as AMD's HDMI example XDC).
create_waiver -type DRC -id RPBF-8 -description {AR76846: IIC IOBUF I is constant 0} -objects [get_cells -hier -filter {NAME =~ *hdmi_ctl_iic_scl_iobuf}]
create_waiver -type DRC -id RPBF-8 -description {AR76846: IIC IOBUF I is constant 0} -objects [get_cells -hier -filter {NAME =~ *hdmi_ctl_iic_sda_iobuf}]
