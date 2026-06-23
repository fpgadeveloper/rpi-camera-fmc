# Opsero Electronic Design Inc. 2025
#
# Thin wrapper around build.py, which generates the HLS IP on both Windows
# and Linux and reads the target list from config/data.json at runtime
# (see ../../build.sh ip). This make interface is kept for compatibility
# and will be REMOVED at the next version update -- please switch to
# ../../build.sh.
#
# Note: on Windows use ../../build.sh directly from git bash; GNU make is
# not usable there (no sh-capable make is available).

TARGET ?= none
BUILD = ./build.sh

.PHONY: help ip all clean clean_all
help:
	@echo 'Usage:'
	@echo ''
	@echo '  make ip TARGET=<val>'
	@echo '    Generate the IP for the target design (wraps: ../../build.sh ip --target <val>).'
	@echo ''
	@echo '  make all'
	@echo '    Generate the IP for all targets.'
	@echo ''
	@echo '  make clean TARGET=<val>  |  make clean_all'
	@echo '    Delete generated IP for one target / all targets.'
	@echo ''
	@echo "  Valid targets: run '../../build.sh labels'"
	@echo ''
	@echo 'DEPRECATED: drive builds with ../../build.sh instead (works on Windows too).'

ip:
	cd ../.. && $(BUILD) ip --target $(TARGET)

all:
	cd ../.. && $(BUILD) ip --target all

clean:
	cd ../.. && $(BUILD) clean --stage ip --target $(TARGET)

clean_all:
	cd ../.. && $(BUILD) clean --stage ip --target all
