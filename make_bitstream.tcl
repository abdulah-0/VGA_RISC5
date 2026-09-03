# ==============================================================================
# Automated Bitstream Generation Script for Current Vivado Project
# Targeted for Digilent Nexys Video (Artix-7 XC7A200T-1SBG484C)
# Compatible with Vivado 2020.1+ / 2020.2 / 2024.x
#
# Usage inside Vivado Tcl Console (while your project is open):
#   source make_bitstream.tcl
#
# Optional board override before sourcing:
#   set BOARD "nexys"       (Default: Digilent Nexys Video XC7A200T)
#   set BOARD "arty"        (Digilent Arty A7-35T)
#   set BOARD "arty_100t"   (Digilent Arty A7-100T)
#   source make_bitstream.tcl
# ==============================================================================

# 1. Directory detection (works with source, batch mode, or pasted commands)
if {[info exists script_dir] == 0 || $script_dir eq ""} {
    if {[info script] ne ""} {
        set script_dir [file normalize [file dirname [info script]]]
    } else {
        set script_dir [file normalize [pwd]]
    }
}
set root_dir $script_dir

# 2. Check if a project is already open in Vivado
set current_proj ""
if {[catch {current_project} current_proj] != 0 || $current_proj eq ""} {
    # If no project is currently open, open existing build_sim/vga_sim_proj.xpr
    set proj_file "$root_dir/build_sim/vga_sim_proj.xpr"
    if {[file exists $proj_file]} {
        puts "==> No project currently open. Opening project: $proj_file"
        open_project $proj_file
    } else {
        puts "==> Creating project in $root_dir/build_sim..."
        file mkdir "$root_dir/build_sim"
        create_project -force vga_sim_proj "$root_dir/build_sim"
    }
} else {
    puts "==> Operating inside current project: [get_property NAME [current_project]]"
}

# 3. Determine target board configuration
# Default: "nexys" (Digilent Nexys Video XC7A200T). Can also be "arty" or "arty_100t"
if {[info exists BOARD] == 0 || $BOARD eq ""} {
    set BOARD "nexys"
}
set BOARD [string tolower $BOARD]

if {$BOARD eq "nexys" || $BOARD eq "nexys_video"} {
    set target_part    "xc7a200tsbg484-1"
    set top_module     "nexys_video_top"
    set top_file       "$root_dir/fpga/nexys_video_top.sv"
    set xdc_file       "$root_dir/fpga/nexys_video.xdc"
    set bit_name       "nexys_video_vga.bit"
    set other_xdc      "$root_dir/fpga/arty_a7.xdc"
    set other_top      "$root_dir/fpga/arty_a7_top.sv"
} elseif {$BOARD eq "arty_100t"} {
    set target_part    "xc7a100tcsg324-1"
    set top_module     "arty_a7_top"
    set top_file       "$root_dir/fpga/arty_a7_top.sv"
    set xdc_file       "$root_dir/fpga/arty_a7.xdc"
    set bit_name       "arty_100t_vga.bit"
    set other_xdc      "$root_dir/fpga/nexys_video.xdc"
    set other_top      "$root_dir/fpga/nexys_video_top.sv"
} else {
    # Arty A7-35T
    set target_part    "xc7a35tcsg324-1"
    set top_module     "arty_a7_top"
    set top_file       "$root_dir/fpga/arty_a7_top.sv"
    set xdc_file       "$root_dir/fpga/arty_a7.xdc"
    set bit_name       "arty_vga.bit"
    set other_xdc      "$root_dir/fpga/nexys_video.xdc"
    set other_top      "$root_dir/fpga/nexys_video_top.sv"
}

puts "--------------------------------------------------"
puts " Target Board : $BOARD"
puts " Target Device: $target_part"
puts " Top Module   : $top_module"
puts " Constraints  : $xdc_file"
puts " Bitstream Out: $bit_name"
puts "--------------------------------------------------"

# 4. Set project & run target device part
set_property part $target_part [current_project]
catch {set_property part $target_part [get_runs synth_1]}
catch {set_property part $target_part [get_runs impl_1]}

# 5. Configure include directories
set inc_dirs [list \
    "$root_dir/deps/axi/include" \
    "$root_dir/deps/common_cells/include" \
    "$root_dir/deps/register_interface/include" \
]
set_property include_dirs $inc_dirs [get_filesets sources_1]

# 6. Ensure FPGA RTL files are in sources_1
set fpga_rtl_files [list \
    "$root_dir/fpga/vga_reg_init.sv" \
    "$root_dir/fpga/axi_synth_fb.sv" \
    $top_file \
]
foreach f $fpga_rtl_files {
    if {[llength [get_files -quiet [file tail $f]]] == 0} {
        add_files -fileset sources_1 -norecurse $f
    }
}
set_property file_type SystemVerilog [get_files -quiet $fpga_rtl_files]

# 7. Exclude testbench / simulation-only modules from synthesis & implementation
set sim_only_files [list \
    "tb_axi_vga.sv" \
    "axi_sim_mem.sv" \
    "clk_rst_gen.sv" \
]
foreach f $sim_only_files {
    set fileobj [get_files -quiet $f]
    if {[llength $fileobj] > 0} {
        set_property used_in_synthesis false $fileobj
        set_property used_in_implementation false $fileobj
    }
}

# Also ensure the alternate board top (if present in project) is not synthesized
if {[file exists $other_top]} {
    set other_top_obj [get_files -quiet [file tail $other_top]]
    if {[llength $other_top_obj] > 0} {
        set_property used_in_synthesis false $other_top_obj
        set_property used_in_implementation false $other_top_obj
    }
}
set current_top_obj [get_files -quiet [file tail $top_file]]
if {[llength $current_top_obj] > 0} {
    set_property used_in_synthesis true $current_top_obj
    set_property used_in_implementation true $current_top_obj
}

# 8. Add & configure constraints file in constrs_1
set cur_xdc_obj [get_files -quiet [file tail $xdc_file]]
if {[llength $cur_xdc_obj] == 0} {
    add_files -fileset constrs_1 -norecurse $xdc_file
    set cur_xdc_obj [get_files -quiet [file tail $xdc_file]]
}
if {[llength $cur_xdc_obj] > 0} {
    set_property is_enabled true $cur_xdc_obj
    set_property used_in_synthesis true $cur_xdc_obj
    set_property used_in_implementation true $cur_xdc_obj
}

# Disable the other board's XDC if present
set other_xdc_obj [get_files -quiet [file tail $other_xdc]]
if {[llength $other_xdc_obj] > 0} {
    set_property is_enabled false $other_xdc_obj
    set_property used_in_synthesis false $other_xdc_obj
    set_property used_in_implementation false $other_xdc_obj
}

# 9. Set Top module for synthesis
set_property top $top_module [get_filesets sources_1]
update_compile_order -fileset sources_1

# 10. Run Synthesis
puts "==> Step 1/3: Launching Synthesis for $top_module..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "==> ERROR: Synthesis did not reach 100%. Check synth_1 log."
    return -code error "Synthesis failed"
}
puts "==> Step 1/3: Synthesis completed successfully."

# 11. Run Implementation & Generate Bitstream
puts "==> Step 2/3: Launching Implementation and Bitstream Generation..."
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "==> ERROR: Implementation / Bitstream did not reach 100%. Check impl_1 log."
    return -code error "Implementation/Bitstream failed"
}
puts "==> Step 2/3: Bitstream generation completed successfully."

# 12. Copy bitstream to root directory
puts "==> Step 3/3: Exporting bitstream..."
set proj_runs_dir [get_property DIRECTORY [get_runs impl_1]]
set bit_files [glob -nocomplain -directory $proj_runs_dir *.bit]

if {[llength $bit_files] > 0} {
    set generated_bit [lindex $bit_files 0]
    file copy -force $generated_bit "$root_dir/$bit_name"
    puts "========================================================================="
    puts " SUCCESS! Nexys Video Bitstream generated at:"
    puts "   $root_dir/$bit_name"
    puts " You can now program your Nexys Video FPGA in Vivado Hardware Manager."
    puts "========================================================================="
} else {
    puts "==> WARNING: Bitstream was generated but could not locate *.bit file in $proj_runs_dir"
}
