# ==============================================================================
# Automated Vivado Simulation Script for AXI VGA IP
# Compatible with Vivado 2014.2 through 2024.x
# Usage in Vivado Tcl Console: source run_sim.tcl
# ==============================================================================

set script_dir [file normalize [file dirname [info script]]]
puts "==> Running AXI VGA Simulation from: $script_dir"

# 1. Close any open project
catch {close_project}

# 2. Create in-memory project
create_project -in_memory -part xc7z020clg484-1

# 3. Define include directories
set inc_dirs [list \
    "$script_dir/deps/axi/include" \
    "$script_dir/deps/common_cells/include" \
    "$script_dir/deps/register_interface/include" \
]

# 4. Add Design, Dependency, and Verification Source Files in dependency order
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

# Add source files to fileset
add_files -fileset sources_1 -norecurse $src_files
set_property file_type SystemVerilog [get_files $src_files]

# Set include paths
set_property include_dirs $inc_dirs [get_filesets sources_1]

# Set top module
set_property top tb_axi_vga [get_filesets sources_1]

puts "==> Elaboration and Simulation Starting..."
launch_xsim -simset sources_1 -mode behavioral
