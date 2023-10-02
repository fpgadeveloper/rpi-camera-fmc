#!/usr/bin/tclsh

# Description
# -----------
# This Tcl script will create Vitis workspace and add a software application for the specified
# target design. If a target design is not specified, a software application will be added for 
# each of the exported hardware designs in the ../Vivado directory.

# Set the Vivado directories containing the Vivado projects
set vivado_dirs_rel [list "../Vivado"]
set vivado_dirs {}
foreach d $vivado_dirs_rel {
  set d_abs [file join [pwd] $d]
  append vivado_dirs [file normalize $d_abs] " "
}

# Set the application postfix
# Applications will be named using the app_postfix appended to the board name
set app_postfix "_app"

# Specify the postfix on the Vivado projects (if one is used)
set vivado_postfix ""

# Set the app template used to create the application
set support_app "empty_application"
set template_app "Empty Application"

# Microblaze designs: Generate combined .bit and .elf file
set mb_combine_bit_elf 0

# Possible targets (board name in lower case for the board.h file)
dict set target_dict zcu104 { zcu104 }
dict set target_dict zcu102_hpc0 { zcu102 }
dict set target_dict zcu102_hpc1 { zcu102 }
dict set target_dict zcu106_hpc0 { zcu106 }
dict set target_dict uzev { uzev }
dict set target_dict pynqzu { pynqzu }
dict set target_dict genesyszu { genesyszu }
dict set target_dict zcu106_pcie { zcu106 }

# Target can be specified by creating the target variable before sourcing, or in the arguments
if { $argc >= 1 } {
  set target [lindex $argv 0]
  puts "Target for the build: $target"
} elseif { [info exists target] && [dict exists $target_dict $target] } {
  puts "Target for the build: $target"
} else {
  puts "No target specified, or invalid target."
  set target ""
}

# ----------------------------------------------------------------------------------------------
# Custom modifications functions
# ----------------------------------------------------------------------------------------------
# Use these functions to make custom changes to the platform or standard application template 
# such as modifying files or copying sources into the platform/application.
# These functions are called after creating the platform/application and before build.

proc custom_platform_mods {platform_name} {
  # Enable and configure the Standalone domain
  # Set the DisplayPort driver to dppsu
  domain active {standalone_domain}
  bsp setdriver -ip psu_dp -driver dppsu
  bsp regenerate
}

proc custom_app_mods {platform_name app_name} {
  # Copy common sources into the application
  copy-r "common/src" "${app_name}/src"
  set proc_instance [get_processor_from_platform $platform_name]
  # For Zynq MP designs
  if {$proc_instance == "psu_cortexa53_0"} {
    copy-r "zynqmp/src" "${app_name}/src"
  # For Microblaze designs
  } else {
    copy-r "mb/src" "${app_name}/src"
  }
  # Add math library to the linker options
  app config -name ${app_name} -add libraries m  
}

# Call the workspace builder script
source tcl/workspace.tcl

