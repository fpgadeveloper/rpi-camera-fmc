#!/bin/bash
# SPDX-License-Identifier: MIT
# Run the DVI RTL simulations in xsim. Usage: run_sim.sh [workdir]
# Needs Vivado 2025.2 settings sourced (or VIVADO_SETTINGS pointing at settings64.sh).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
RTL=$(cd "$HERE/.." && pwd)
WORK=${1:-$(mktemp -d)}
mkdir -p "$WORK" && cd "$WORK"
if ! command -v xvlog >/dev/null; then
  source "${VIVADO_SETTINGS:-$HOME/Xilinx/2025.2/Vivado/settings64.sh}"
fi
XPM=$XILINX_VIVADO/data/ip/xpm
python3 -I "$HERE/tmds_model.py" "$WORK"

xvlog -sv "$XPM/xpm_cdc/hdl/xpm_cdc.sv" "$XPM/xpm_memory/hdl/xpm_memory.sv" \
      "$XPM/xpm_fifo/hdl/xpm_fifo.sv" > xvlog_xpm.log
xvlog "$XILINX_VIVADO/data/verilog/src/glbl.v" \
      "$RTL/dvi_tmds_encoder.v" "$RTL/dvi_tmds_core.v" "$RTL/dvi_tx_gearbox.v" \
      "$HERE/tb_dvi_tmds_encoder.v" "$HERE/tb_dvi_tx_gearbox.v" "$HERE/tb_dvi_tmds_core.v" > xvlog.log

rc=0
xelab -debug off tb_dvi_tmds_encoder -s enc > xelab_enc.log
xsim enc -R | tee sim_enc.log | grep -E "PASS|FAIL|MISMATCH|loaded"
grep -q PASS sim_enc.log || rc=1

xelab -debug off -L xpm tb_dvi_tx_gearbox glbl -s gbx > xelab_gbx.log
xsim gbx -R | tee sim_gbx.log | grep -E "PASS|FAIL|error"
grep -q PASS sim_gbx.log || rc=1
xelab -debug off -L xpm tb_dvi_tmds_core glbl -s core > xelab_core.log
xsim core -R | tee sim_core.log | grep -E "PASS|FAIL|DE run|HS|period|lines"
grep -q PASS sim_core.log || rc=1
echo "logs in $WORK"
exit $rc
