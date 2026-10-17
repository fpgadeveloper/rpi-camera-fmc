#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Opsero Electronic Design Inc.
#
# dvi-status - show / change the DVI output's status and control register
# (dual-channel AXI GPIO in the PL, marked "opsero,dvi-ctrl" in the device tree;
# bit map in Vivado/src/hdl/dvi/dvi_ctrl.v).
#
#   dvi-status                 decode status + control
#   dvi-status pattern on|off  colour bars instead of the mixer output (v2 bitstream:
#                              with the encoder's own 1080p60 timing, no VTC/DRM needed)
#   dvi-status txen on|off     HDMI TX retimer/redriver enable pin
#   dvi-status polarity <0-f>  invert TX lanes (bit n = lane n; lane 3 = TMDS clock)
#   dvi-status reset           re-run the transceiver reset sequence
#   dvi-status clear           clear the sticky underflow/overflow flags (+ watchdog count)
#   dvi-status wait [sec]      wait for the link (default 5 s), exit 0 when up
#   dvi-status addr            print the status register address
set -e

find_base() {
	local n
	# trailing slash: /proc/device-tree is a symlink, and find (default -P)
	# does not descend into a symlinked start point
	for n in $(find /proc/device-tree/ -name 'opsero,dvi-ctrl' 2>/dev/null); do
		local node=$(dirname "$n")
		# reg = <addr_hi addr_lo size_hi size_lo> (#address-cells = 2)
		local hex=$(od -An -tx1 -v "$node/reg" | tr -d ' \n')
		if [ ${#hex} -ge 16 ]; then
			echo $((16#${hex:0:16}))
		else
			echo $((16#${hex:0:8}))
		fi
		return 0
	done
	return 1
}

BASE=$(find_base) || { echo "dvi-status: no 'opsero,dvi-ctrl' node in the device tree" >&2; exit 1; }
ST_ADDR=$(printf '0x%x' $BASE)
CT_ADDR=$(printf '0x%x' $((BASE + 8)))

rd() { dvi-reg "$1"; }
wr() { dvi-reg "$1" "$2"; }

decode() {
	local st=$(( $(rd $ST_ADDR) )) ct=$(( $(rd $CT_ADDR) ))
	# id: 0xD710 = v1 bitstream; 0xD72 in [31:20] = v2 (watchdog count in [19:16])
	if [ $(( st >> 20 )) = $(( 0xD72 )) ]; then
		printf 'DVI status  0x%08x (id 0x%03x, v2)\n' $st $(( st >> 20 ))
	else
		printf 'DVI status  0x%08x (id 0x%04x)\n' $st $(( st >> 16 ))
	fi
	printf '  link ready        %d\n' $(( st & 1 ))
	printf '  GT power good     %d\n' $(( (st >> 1) & 1 ))
	printf '  GT TX reset done  %d\n' $(( (st >> 2) & 1 ))
	printf '  FIFO streaming    %d\n' $(( (st >> 3) & 1 ))
	printf '  FIFO underflow    %d (sticky)\n' $(( (st >> 4) & 1 ))
	printf '  FIFO overflow     %d (sticky)\n' $(( (st >> 5) & 1 ))
	printf '  HDMI HPD (sink)   %d\n' $(( (st >> 6) & 1 ))
	printf '  clk synth LOL pin %d\n' $(( (st >> 7) & 1 ))
	printf '  GT reset retries  %d\n' $(( (st >> 8) & 255 ))
	[ $(( st >> 20 )) = $(( 0xD72 )) ] && \
		printf '  FIFO watchdog     %d recoveries\n' $(( (st >> 16) & 15 ))
	printf 'DVI control 0x%08x\n' $ct
	printf '  GT reset req %d  TX enable %d  test pattern %d  clear %d  polarity 0x%x\n' \
		$(( ct & 1 )) $(( (ct >> 1) & 1 )) $(( (ct >> 2) & 1 )) $(( (ct >> 3) & 1 )) $(( (ct >> 4) & 15 ))
}

setbit() { # bit value
	local ct=$(( $(rd $CT_ADDR) ))
	if [ "$2" = 1 ]; then ct=$(( ct | (1 << $1) )); else ct=$(( ct & ~(1 << $1) )); fi
	wr $CT_ADDR $(printf '0x%x' $ct)
}

onoff() { case "$1" in on|1) echo 1 ;; off|0) echo 0 ;; *) echo "expected on|off" >&2; exit 2 ;; esac; }

case "${1:-}" in
	"")       decode ;;
	pattern)  setbit 2 $(onoff "$2"); decode ;;
	txen)     setbit 1 $(onoff "$2"); decode ;;
	polarity) ct=$(( $(rd $CT_ADDR) & ~0xF0 )); wr $CT_ADDR $(printf '0x%x' $(( ct | ((16#${2:-0} & 15) << 4) ))); decode ;;
	reset)    setbit 0 1; sleep 0.1; setbit 0 0; decode ;;
	clear)    setbit 3 1; sleep 0.01; setbit 3 0; decode ;;
	addr)     echo $ST_ADDR ;;
	wait)     t=$(( ${2:-5} * 10 ))
	          while [ $t -gt 0 ]; do
	          	[ $(( $(rd $ST_ADDR) & 1 )) = 1 ] && { echo "DVI link up"; exit 0; }
	          	sleep 0.1; t=$((t - 1))
	          done
	          echo "DVI link NOT up"; decode; exit 1 ;;
	*)        sed -n '4,18p' "$0"; exit 2 ;;
esac
