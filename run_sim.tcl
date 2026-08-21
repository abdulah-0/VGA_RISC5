# ==============================================================================
# Automated Vivado Simulation Script for AXI VGA IP
# Compatible with Vivado 2014.2 through 2024.x
# Usage in Vivado Tcl Console:
#   cd C:/Users/snake/OneDrive/Desktop/axi_vga-main
#   source run_sim.tcl
# ==============================================================================

set script_dir [file normalize [file dirname [info script]]]
puts "==> Running AXI VGA Simulation from: $script_dir"

# 1. Close any existing open project
catch {close_project}

# 2. Create disk-backed simulation project in build_sim directory
set proj_dir "$script_dir/build_sim"
file mkdir $proj_dir
create_project -force vga_sim_proj $proj_dir -part xc7z020clg484-1

# 3. Define include directories
set inc_dirs [list \
    "$script_dir/deps/axi/include" \
    "$script_dir/deps/common_cells/include" \
    "$script_dir/deps/register_interface/include" \
]

# 4. Add Design, Dependency, and Verification Source Files
set src_files [list \
    "$script_dir/deps/common_cells/src/cf_math_pkg.sv" \
    "$script_dir/deps/axi/src/axi_pkg.sv" \
    "$script_dir/src/axi_vga_reg_pkg.sv" \
    "$script_dir/deps/register_interface/src/reg_intf.sv" \
    "$script_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv" \
    "$script_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg.sv" \
    "$script_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv" \
    "$script_dir/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_shadow.sv" \
    "$script_dir/deps/common_cells/src/delta_counter.sv" \
    "$script_dir/deps/common_cells/src/counter.sv" \
    "$script_dir/deps/common_cells/src/lzc.sv" \
    "$script_dir/deps/common_cells/src/onehot_to_bin.sv" \
    "$script_dir/deps/common_cells/src/id_queue.sv" \
    "$script_dir/deps/common_cells/src/rr_arb_tree.sv" \
    "$script_dir/deps/common_cells/src/spill_register_flushable.sv" \
    "$script_dir/deps/common_cells/src/spill_register.sv" \
    "$script_dir/deps/common_cells/src/fifo_v3.sv" \
    "$script_dir/deps/common_cells/src/stream_fifo.sv" \
    "$script_dir/deps/common_cells/src/stream_join_dynamic.sv" \
    "$script_dir/deps/common_cells/src/stream_join.sv" \
    "$script_dir/deps/common_cells/src/stream_register.sv" \
    "$script_dir/deps/axi/src/axi_atop_filter.sv" \
    "$script_dir/deps/axi/src/axi_err_slv.sv" \
    "$script_dir/deps/axi/src/axi_demux_simple.sv" \
    "$script_dir/deps/axi/src/axi_demux.sv" \
    "$script_dir/deps/axi/src/axi_burst_splitter.sv" \
    "$script_dir/src/axi_vga_reg_top.sv" \
    "$script_dir/src/axi_vga_timing_fsm.sv" \
    "$script_dir/src/axi_vga_fetcher.sv" \
    "$script_dir/src/axi_vga.sv" \
    "$script_dir/deps/axi/src/axi_cut.sv" \
    "$script_dir/deps/axi/src/axi_multicut.sv" \
    "$script_dir/deps/axi/src/axi_sim_mem.sv" \
    "$script_dir/deps/common_verification/src/clk_rst_gen.sv" \
    "$script_dir/test/tb_axi_vga.sv" \
]

# 5. Add source files
add_files -fileset sources_1 -norecurse $src_files
set_property file_type SystemVerilog [get_files $src_files]

# 6. Configure include search paths and top module
set_property include_dirs $inc_dirs [get_filesets sources_1]
set_property include_dirs $inc_dirs [get_filesets sim_1]
set_property top tb_axi_vga [get_filesets sim_1]

# 7. Add memory data file
if {[file exists "$script_dir/test/count.mem"]} {
    add_files -fileset sim_1 -norecurse "$script_dir/test/count.mem"
}


puts "==> Elaboration and Simulation Starting..."
launch_xsim -simset sim_1 -mode behavioral
