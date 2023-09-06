# Opsero Electronic Design Inc. 2023
#
# This Makefile can be used to build the Vitis workspace.

CP = cp -rf
MKDIR = mkdir -p
RM = rm -rf
XSCT = $(XILINX_VITIS)/bin/xsct

APP_POSTFIX = _app
SYS_POSTFIX = $(APP_POSTFIX)_system

VIT_SCRIPT_WS = tcl/build-vitis.tcl

# valid targets
TARGET_LIST = zcu104 zcu102_hpc0 zcu102_hpc1 zcu106_hpc0 pynqzu genesyszu uzev

.PHONY: help
help:
	@echo 'Usage:'
	@echo ''
	@echo '  make workspace'
	@echo '    Create the Vitis workspace and add applications for all exported targets.'
	@echo ''
	@echo '  make clean'
	@echo '    Delete the Vitis workspace and all applications.'
	@echo ''

.PHONY: all
all: workspace

.PHONY: workspace
workspace:
	$(XSCT) $(VIT_SCRIPT_WS)

.PHONY: clean
clean:
	for targ in $(TARGET_LIST); do \
		$(RM) $$targ $$targ$(APP_POSTFIX) $$targ$(SYS_POSTFIX); \
	done
	$(RM) boot .metadata .Xil IDE.log .analytics

