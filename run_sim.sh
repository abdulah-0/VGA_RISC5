#!/usr/bin/env bash
# ==============================================================================
# Linux Launcher for AXI VGA Simulation in Vivado
# Usage:
#   ./run_sim.sh          (launches GUI with waveform viewer)
#   ./run_sim.sh -batch   (runs batch mode simulation)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if vivado is in PATH
if ! command -v vivado &> /dev/null; then
    # Try searching common Xilinx install directories on Linux
    for v_dir in /opt/Xilinx/Vivado/20* /tools/Xilinx/Vivado/20*; do
        if [ -f "$v_dir/settings64.sh" ]; then
            source "$v_dir/settings64.sh"
            break
        fi
    done
fi

if ! command -v vivado &> /dev/null; then
    echo "[ERROR] 'vivado' command not found in PATH!"
    echo "Please source your Vivado settings64.sh first: source /path/to/Xilinx/Vivado/<version>/settings64.sh"
    exit 1
fi

MODE="gui"
if [ "$1" == "-batch" ] || [ "$1" == "batch" ]; then
    MODE="batch"
fi

cd "$SCRIPT_DIR"
vivado -mode "$MODE" -source "$SCRIPT_DIR/run_sim.tcl"
