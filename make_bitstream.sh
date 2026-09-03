#!/usr/bin/env bash
# ==============================================================================
# Linux Launcher for Nexys A7 Bitstream Generation in Vivado
# Usage:
#   ./make_bitstream.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v vivado &> /dev/null; then
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

cd "$SCRIPT_DIR"
vivado -mode batch -source "$SCRIPT_DIR/make_bitstream.tcl"
