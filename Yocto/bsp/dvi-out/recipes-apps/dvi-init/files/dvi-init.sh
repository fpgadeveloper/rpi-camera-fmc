#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Opsero Electronic Design Inc.
#
# dvi-init - bring up the DVI output on the board's HDMI TX connector.
#
# The HDMI control I2C bus is the PL axi_iic whose device-tree node carries the
# 8T49N241 clock synthesiser (clock-generator@6c). The kernel's idt8t49n24x
# driver has already set the transceiver reference clock (148.5 MHz) from the
# device tree; this script configures the TMDS retimer/redriver at 0x5E:
#   VCK190: TI SN65DP159 (ID registers 0x00/0x01 = 'D','P')
#   VEK280: TI TMDS1204  (register 0x08 = device/revision id, lane swap needed)
# and then waits for the transceiver link (the PL reset sequencer retries by
# itself once the reference clock is present).
# Register values: AMD embeddedsw / HDMI driver settings for TMDS < 1.65 Gb/s
# (SN65DP159: Xilinx hdmi-modules dp159.c "HDMI 1.4" branch; TMDS1204:
# embeddedsw v_hdmitxss1 xhdmi_example ti_tmds1204.c TX_TI_R1_INIT +
# TX_TI_TMDS_14_L_R1, MIT licence).

ADDR=0x5e

log() { echo "dvi-init: $*"; }

find_bus() {
	local d
	for d in /sys/bus/i2c/devices/i2c-*; do
		[ -d "$d/of_node/clock-generator@6c" ] && { basename "$d" | sed 's/i2c-//'; return 0; }
	done
	return 1
}

BUS=""
for i in $(seq 1 100); do
	BUS=$(find_bus) && break
	sleep 0.1
done
[ -n "$BUS" ] || { log "HDMI control I2C bus not found (no clock-generator@6c under an I2C adapter)"; exit 1; }
log "HDMI control I2C bus: i2c-$BUS"

w() { i2cset -y -f "$BUS" $ADDR "$1" "$2" || { log "write 0x$(printf %02x $(($1))) failed"; return 1; }; }
r() { i2cget -y -f "$BUS" $ADDR "$1" 2>/dev/null; }

id0=$(r 0x00); id1=$(r 0x01)
if [ "$id0" = "0x44" ] && [ "$id1" = "0x50" ]; then
	log "SN65DP159 retimer found, configuring for TMDS 1.485 Gb/s (DVI 1080p60)"
	w 0x09 0x06 &&   # misc control
	w 0x0B 0x80 &&   # SLEW_CTL = 10, TX_TERM_CTL = 00 (HDMI 1.4 rates)
	w 0x0C 0x48 &&   # VSWING_DATA/CLK +14%, no pre-emphasis
	w 0x0D 0x00 &&
	w 0x0A 0x35      # automatic redriver (<1 Gb/s) / retimer (>1 Gb/s), DDC training off
	rc=$?
else
	dev=$(r 0x08)
	if [ -n "$dev" ] && [ "$dev" != "0x00" ]; then
		log "TMDS1204 redriver found (reg 0x08 = $dev), configuring for TMDS 1.485 Gb/s"
		# init (lane swap for the VEK280 layout)
		w 0x0A 0x8E && w 0x0B 0x43 && w 0x0C 0x70 && w 0x0D 0x22 &&
		w 0x0E 0x97 && w 0x11 0x0F && w 0x09 0x02 &&
		# TMDS <= 1.65 Gb/s
		w 0x11 0x00 && w 0x0D 0x22 && w 0x12 0x03 && w 0x13 0x00 &&
		w 0x14 0x03 && w 0x15 0x05 && w 0x16 0x03 && w 0x17 0x05 &&
		w 0x18 0x03 && w 0x19 0x05 && w 0x20 0x00 && w 0x31 0x00 &&
		w 0x11 0x0F
		rc=$?
	else
		log "no retimer/redriver answers at 0x5e on i2c-$BUS"
		rc=1
	fi
fi

[ $rc = 0 ] || log "retimer/redriver configuration FAILED"

if command -v dvi-status >/dev/null; then
	# Restart the transceivers + CDC FIFO now that the reference clock is final.
	# At power-up the GT reset sequencer can complete on the 8T49N241's
	# power-on clock; the kernel's reprogramming (Q2 -> 148.5 MHz) then glitches
	# pix_clk/tx_clk under a running FIFO, which was seen on the VCK190 bench to
	# leave it stuck (link ready but "FIFO streaming 0", overflow set) after
	# every cold boot. A reset here always recovered it.
	dvi-status reset >/dev/null
	dvi-status wait 5 || rc=1
	# The v2 bitstream keeps the sticky under/overflow flags and the watchdog
	# count across a transceiver reset, so the history of the clock change
	# above would fail the check below: clear it, then judge a fresh window.
	dvi-status clear >/dev/null
	sleep 0.5
	st=$(( $(dvi-reg "$(dvi-status addr)") ))
	if [ $(( (st >> 3) & 1 )) != 1 ] || [ $(( (st >> 4) & 3 )) != 0 ]; then
		log "FIFO not streaming cleanly after the reset"
		rc=1
	fi
	dvi-status
fi
exit $rc
