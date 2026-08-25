# ==============================================================================
# Automated Bitstream Generation Script for Digilent Nexys Video (Artix-7 XC7A200T)
# Usage in Vivado Tcl Console or Batch Mode:
#   vivado -mode batch -source fpga/build_bitstream.tcl
# ==============================================================================

set script_dir [file normalize [file dirname [info script]]]
set root_dir   [file normalize "$script_dir/.."]
puts "==> Building AXI VGA Bitstream for Nexys Video from: $root_dir"

# 1. Close any open project
catch {close_project}

# 2. Target device: Digilent Nexys Video (xc7a200tsbg484-1)
set part "xc7a200tsbg484-1"
set proj_dir "$root_dir/build_fpga"
file mkdir $proj_dir
create_project -force nexys_video_vga_proj $proj_dir -part $part

# 3. Include directories
set inc_dirs [list \
    "$root_dir/deps/axi/include" \
    "$root_dir/deps/common_cells/include" \
    "$root_dir/deps/register_interface/include" \
]

# 4. Source Files (RTL + Submodules)
set src_files [list \
    "$root_dir/deps/common_cells/src/cf_math_pkg.sv" \
    "$root_dir/deps/axi/src/axi_pkg.sv" \
    "$root_dir/src/axi_vga_reg_pkg.sv" \
    "$root_dir/deps/register_interface/src/reg_intf.sv" \
    "$root_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv" \
    "$root_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg.sv" \
    "$root_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv" \
    "$root_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_shadow.sv" \
    "$root_dir/deps/common_cells/src/delta_counter.sv" \
    "$root_dir/deps/common_cells/src/counter.sv" \
    "$root_dir/deps/common_cells/src/lzc.sv" \
    "$root_dir/deps/common_cells/src/onehot_to_bin.sv" \
    "$root_dir/deps/common_cells/src/id_queue.sv" \
    "$root_dir/deps/common_cells/src/rr_arb_tree.sv" \
    "$root_dir/deps/common_cells/src/spill_register_flushable.sv" \
    "$root_dir/deps/common_cells/src/spill_register.sv" \
    "$root_dir/deps/common_cells/src/fifo_v3.sv" \
    "$root_dir/deps/common_cells/src/stream_fifo.sv" \
    "$root_dir/deps/common_cells/src/stream_join_dynamic.sv" \
    "$root_dir/deps/common_cells/src/stream_join.sv" \
    "$root_dir/deps/common_cells/src/stream_register.sv" \
    "$root_dir/deps/axi/src/axi_atop_filter.sv" \
    "$root_dir/deps/axi/src/axi_err_slv.sv" \
    "$root_dir/deps/axi/src/axi_demux_simple.sv" \
    "$root_dir/deps/axi/src/axi_demux.sv" \
    "$root_dir/deps/axi/src/axi_burst_splitter.sv" \
    "$root_dir/src/axi_vga_reg_top.sv" \
    "$root_dir/src/axi_vga_timing_fsm.sv" \
    "$root_dir/src/axi_vga_fetcher.sv" \
    "$root_dir/src/axi_vga.sv" \
    "$root_dir/fpga/vga_reg_init.sv" \
    "$root_dir/fpga/axi_synth_fb.sv" \
    "$root_dir/fpga/nexys_video_top.sv" \
]

# 5. Add Sources & Constraints
add_files -fileset sources_1 -norecurse $src_files
set_property file_type SystemVerilog [get_files $src_files]

set_property include_dirs $inc_dirs [get_filesets sources_1]
set_property top nexys_video_top [get_filesets sources_1]

add_files -fileset constrs_1 -norecurse "$script_dir/nexys_video.xdc"

# 6. Run Synthesis and Implementation
puts "==> Starting Synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

puts "==> Starting Implementation & Bitstream Generation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit_file "$proj_dir/nexys_video_vga_proj.runs/impl_1/nexys_video_top.bit"
if {[file exists $bit_file]} {
    file copy -force $bit_file "$root_dir/nexys_video_vga.bit"
    puts "================================================================="
    puts " SUCCESS! Bitstream generated at: $root_dir/nexys_video_vga.bit"
    puts "================================================================="
} else {
    puts "==> Error: Bitstream file was not created. Check logs in $proj_dir"
}
