# Opsero Electronic Design Inc. Copyright 2023
#
# Project build script
#
# This script requires the target name to be specified upon launch. This can be done
# in two ways:
#
#   1. Using a single argument passed to the script via tclargs.
#      eg. vivado -mode batch -source build.tcl -notrace -tclargs <target-name>
#
#   2. By setting the target variable before sourcing the script.
#      eg. set target <target-name>
#          source build.tcl -notrace
#
# The valid target names are:
#   * zcu104       * zcu102_hpc0  * zcu102_hpc1  * zcu106_hpc0
#   * pynqzu       * genesyszu    * uzev
#
#*****************************************************************************************

# Check the version of Vivado used
set version_required "2020.2"
set ver [lindex [split $::env(XILINX_VIVADO) /] end]
if {![string equal $ver $version_required]} {
  puts "###############################"
  puts "### Failed to build project ###"
  puts "###############################"
  puts "This project was designed for use with Vivado $version_required."
  puts "You are using Vivado $ver. Please install Vivado $version_required,"
  puts "or download the project sources from a commit of the Git repository"
  puts "that was intended for your version of Vivado ($ver)."
  return
}

# Possible targets
dict set target_dict zcu104 { xczu7ev-ffvc1156-2-e xilinx.com:zcu104:part0:1.1 { 0 1 2 3 } zynqmp }
dict set target_dict zcu102_hpc0 { xczu9eg-ffvb1156-2-e xilinx.com:zcu102:part0:3.4 { 0 1 2 3 } zynqmp }
dict set target_dict zcu102_hpc1 { xczu9eg-ffvb1156-2-e xilinx.com:zcu102:part0:3.4 { 0 1 } zynqmp }
dict set target_dict zcu106_hpc0 { xc7z045ffg900-2 xilinx.com:zcu106:part0:2.6 { 0 1 2 3 } zynqmp }
dict set target_dict pynqzu { xczu5eg-sfvc784-1-e tul.com.tw:pynqzu:part0:1.1 { 0 1 2 3 } zynqmp }
dict set target_dict genesyszu { xczu5ev-sfvc784-1-e digilentinc.com:gzu_5ev:part0:1.1 { 0 1 2 3 } zynqmp }
dict set target_dict uzev { xczu7ev-fbvb900-1-i avnet.com:ultrazed_7ev_cc:part0:1.4 { 0 1 2 3 } zynqmp }

if { $argc == 1 } {
  set target [lindex $argv 0]
  puts "Target for the build: $target"
} elseif { [info exists target] && [dict exists $target_dict $target] } {
  puts "Target for the build: $target"
} else {
  puts ""
  if { [info exists target] } {
    puts "ERROR: Invalid target $target"
    puts ""
  }
  puts "The build script requires one argument to specify the design to build."
  puts "Possible values are:"
  puts "   * zcu104       * zcu102_hpc0  * zcu102_hpc1  * zcu106_hpc0"
  puts "   * pynqzu       * genesyszu    * uzev"
  puts ""
  puts "Example 1 (from the Windows command line):"
  puts "   vivado -mode batch -source build.tcl -notrace -tclargs zcu106-hpc0"
  puts ""
  puts "Example 2 (from Vivado Tcl console):"
  puts "   set target zcu106-hpc0"
  puts "   source build.tcl -notrace"
  return
}

set design_name ${target}
set block_name rpi
set fpga_part [lindex [dict get $target_dict $target] 0]
set board_part [lindex [dict get $target_dict $target] 1]
set cams [lindex [dict get $target_dict $target] 2]
set bd_script [lindex [dict get $target_dict $target] 3]

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/$design_name"]"

# Create project
create_project $design_name $origin_dir/$design_name -part ${fpga_part}

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "board_part" -value "$board_part" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/$design_name.cache/ip" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set IP repository paths
set obj [get_filesets sources_1]
set_property "ip_repo_paths" "[file normalize "$origin_dir/../HLS"]" $obj

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property -name "top" -value "${block_name}_wrapper" -objects $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/src/constraints/${target}.xdc"]"
set file_added [add_files -norecurse -fileset $obj $file]
set file "$origin_dir/src/constraints/${target}.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "XDC" $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]
set_property "target_constrs_file" "[file normalize "$origin_dir/src/constraints/${target}.xdc"]" $obj

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property -name "top" -value "${block_name}_wrapper" -objects $obj

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part ${fpga_part} -flow {Vivado Synthesis 2020} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2020" [get_runs synth_1]
}
set obj [get_runs synth_1]

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part ${fpga_part} -flow {Vivado Implementation 2020} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2020" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property -name "steps.write_bitstream.args.readback_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.verbose" -value "0" -objects $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created:${design_name}"

# Create the MIPI LOC dictionary that is used by the block design script
source $origin_dir/src/bd/mipi_locs.tcl

# Create block design
source $origin_dir/src/bd/design_1-${bd_script}.tcl

# Generate the wrapper
make_wrapper -files [get_files *${block_name}.bd] -top
add_files -norecurse ${design_name}/${design_name}.gen/sources_1/bd/${block_name}/hdl/${block_name}_wrapper.v

# Update the compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Ensure parameter propagation has been performed
close_bd_design [current_bd_design]
open_bd_design [get_files ${block_name}.bd]
validate_bd_design -force
save_bd_design

