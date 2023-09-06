#!/usr/bin/tclsh

# Description
# -----------
# This Tcl script will create Vitis workspace with software applications for each of the
# exported hardware designs in the ../Vivado directory.

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

