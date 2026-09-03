# Project Memory: AXI4 VGA Display Controller Core

**Target SoC Architecture:** RISC-V / AXI4 System-on-Chip  
**Repository:** [https://github.com/abdulah-0/VGA_RISC5](https://github.com/abdulah-0/VGA_RISC5)  
**Supported EDA Tools:** Xilinx Vivado (2014.2 through 2020.1+ / 2024.x)  
**Supported FPGA Hardware:** Digilent Nexys Video (Artix-7 XC7A200T) & Digilent Arty A7 (XC7A35T / XC7A100T)

---

## 1. Executive Summary

This project delivers a fully verified, synthesizable, high-performance **AXI4 Video Graphics Array (VGA) Controller IP Core**. The core functions as:
1. **Memory-Mapped Register Slave (`REG_BUS` / AXI-Lite)**: Receives resolution, porch timings, clock divider, and frame buffer base address configurations from a host CPU (e.g., RISC-V).
2. **Autonomous AXI4 Master DMA Engine**: Fetches 16-bit RGB565 pixel streams from system frame buffer memory using high-throughput burst transactions.
3. **VGA Video Signal Generator**: Buffers incoming pixel streams through internal FIFOs and translates them into standard VGA video timing signals (`hsync`, `vsync`, `blank`, `red`, `green`, `blue`) to drive real monitors.

---

## 2. Chronological Milestones & Problem-Solving Record

### Milestone 1: Vivado Compiler & Simulation Compatibility
* **Problem**: The original ETH Zurich / OpenTitan codebase contained complex SystemVerilog constructs (dynamic queues, associative arrays, OOP classes, and bit-sliced linked structs) that triggered internal segmentation faults (`EXCEPTION_ACCESS_VIOLATION`) and syntax errors in Xilinx Vivado (particularly Vivado 2014.2 and early XSim engines).
* **Achieved Solutions**:
  1. **Rewrote `id_queue.sv`**: Replaced complex struct-linked-list pointers with a clean, fully synthesizable per-ID static circular FIFO queue architecture.
  2. **Refactored `axi_sim_mem.sv`**: Replaced unbounded dynamic queues and associative arrays (`mem[addr_t]`) with a static 512 KB framebuffer memory array.
  3. **Inlined Testbench Drivers in `tb_axi_vga.sv`**: Replaced unsupported SystemVerilog OOP classes (`reg_driver`) with inlined static tasks (`reg_send_write`, `reg_reset_master`).
  4. **Standardized Timescales**: Added `` `timescale 1ns/1ps `` directives across all verification modules and converted time literal delays (`#5ns`) into compliant integer expressions.

---

### Milestone 2: Automated One-Click Simulation Framework (`run_sim.tcl`)
* **Problem**: Setting up 36+ SystemVerilog files, 3 include directories, and ordering package dependencies manually in Vivado was error-prone. Additionally, Vivado 2020.1+ introduced a conflict where automated multithreading flags caused compiler parameter collisions (`Multiple occurrences of option ---mt is not allowed`).
* **Achieved Solutions**:
  1. Developed **`run_sim.tcl`**: A single Tcl script that automatically sets up a disk-backed project (`build_sim/`), imports all RTL/dependency/verification files in exact compile order, registers include directories, and compiles the design.
  2. Removed legacy `-mt off` override to ensure full forward-compatibility with modern Vivado versions (2020.1+).

---

### Milestone 3: Waveform Diagnostics & `'x'` (Undefined State) Elimination
* **Problem**: 
  1. Configuration bus signals (`vga_reg_req`, `vga_reg_rsp.error`) displayed red (`'x'`) at simulation startup.
  2. Video RGB output channels went red (`'x'`) after $600\text{ ns}$.
* **Root Cause & Fixes**:
  1. **Startup Bus Delay**: `tb_axi_vga.sv` delayed bus initialization by $50\text{ ns}$. Fixed by executing `reg_reset_master()` immediately at time $0\text{ ps}$ and gating `reg_error` with `reg_intf_req.valid` in `axi_vga_reg_top.sv`.
  2. **Memory Array Initialization**: Vivado executed XSim inside nested folders where relative path `../test/count.mem` could not be resolved. Fixed by adding an automatic deterministic test pattern initialization loop in `axi_sim_mem.sv` and copying `count.mem` directly to the simulation directory.
  3. **Waveform Configuration (`output/tb_axi_vga_behav.wcfg`)**: Configured and saved all top-level VGA signals (`hsync`, `vsync`, `red`, `green`, `blue`), timing counters (`h_cnt_q`, `v_cnt_q`), and blanking indicators.

---

### Milestone 4: FPGA Prototyping on Digilent Nexys Video & Arty A7
* **Problem**: Transitioning from pure simulation to live FPGA hardware required clock synthesis, autonomous register initialization, an on-chip test framebuffer, and board pin constraints.
* **Achieved Solutions**:
  1. **Clock Generation (`MMCME2_BASE`)**: Instantiated native Xilinx 7-Series MMCM primitives to convert the onboard 100 MHz oscillator into a clean 50 MHz system clock, generating an exact 25.175 MHz pixel clock for standard **$640 \times 480 \text{ @ } 60\text{Hz}$** VGA.
  2. **Autonomous Register Initializer (`fpga/vga_reg_init.sv`)**: Created a hardware FSM that automatically writes all timing, porch, and address configuration registers on reset release.
  3. **Synthesizable On-Chip Test Pattern Generator (`fpga/axi_synth_fb.sv`)**: Designed a synthesizable AXI4 read slave that serves pixel data on the DMA bus with real-time switch-selectable modes:
     * `SW0=0, SW1=0`: Standard **8-Color Vertical Bars** (White, Yellow, Cyan, Green, Magenta, Red, Blue, Black).
     * `SW0=1, SW1=0`: **Pure Solid Red**.
     * `SW0=0, SW1=1`: **Pure Solid Green**.
     * `SW0=1, SW1=1`: **Pure Solid Blue**.
  4. **Physical Pin Constraints (`fpga/nexys_video.xdc` & `fpga/arty_a7.xdc`)**: Mapped Pmod VGA headers JA & JB, clock pin `R4`, reset `G4`, switches, and diagnostic status LEDs (`LD0`–`LD3`).
  5. **Resolved Synthesis Pragma Bug**: Fixed an unmatched `pragma translate_off` in `deps/axi/src/axi_demux_simple.sv`.
### Milestone 5: Vivado 2020.x Simulation Command Fix & Warning Elimination
* **Problem**: 
  1. `run_sim.tcl` failed in Vivado 2020 with `invalid command name "launch_xsim"`.
  2. The simulation default runtime stopped at 1000 ns, aborting before the 150 µs rendering cycle finished.
  3. Pre-configured waveforms (`output/tb_axi_vga_behav.wcfg`) were not automatically loaded in GUI mode, causing Vivado to dump thousands of internal multicut signals.
  4. In `deps/common_cells/src/id_queue.sv`, `oup_gnt_o` was hardwired to `1'b1`, triggering hundreds of thousands of assertion warnings (`Warning: Invalid output at ID queue, read not granted!`) in `axi_burst_splitter.sv` every clock cycle, severely degrading simulation speed.
* **Achieved Solutions**:
  1. Replaced invalid `launch_xsim` with official Vivado command `launch_simulation -simset sim_1 -mode behavioral`.
  2. Set `xsim.simulate.runtime` to `all` to ensure tests execute until `$finish`.
  3. Integrated `output/tb_axi_vga_behav.wcfg` directly into the simulation fileset with `xsim.view`.
  4. Corrected `oup_gnt_o = (count[oup_id_i] > 0)` in `id_queue.sv`, eliminating all false assertion warnings.
### Milestone 6: Same-Project Bitstream Generation for Digilent Nexys Video
* **Problem**: Generating a bitstream previously required running an external script (`fpga/build_bitstream.tcl`) that closed the active project and recreated a separate one (`build_fpga/nexys_video_vga_proj`). Attempting to generate a bitstream in the existing simulation project (`build_sim/vga_sim_proj`) caused DRC pin placement errors (`DRC NSTD-1`, `DRC UCIO-1`) because the part defaulted to `xc7z020`, constraints were omitted from `constrs_1`, and testbench modules were not excluded from synthesis.
* **Achieved Solutions**:
  1. Developed **`make_bitstream.tcl`**: Detects and operates directly within `[current_project]` without closing it.
  2. Updates target device to **`xc7a200tsbg484-1`** on the project and runs (`synth_1`, `impl_1`).
  3. Dynamically adds `fpga/vga_reg_init.sv`, `fpga/axi_synth_fb.sv`, and `fpga/nexys_video_top.sv` to `sources_1`, sets `nexys_video_top` as top, and disables simulation-only files (`tb_axi_vga.sv`, `axi_sim_mem.sv`, `clk_rst_gen.sv`).
  4. Automatically registers and activates `fpga/nexys_video.xdc` in `constrs_1`.
  5. Executes synthesis, place & route, and exports the generated bitstream directly to `nexys_video_vga.bit` in the repository root.
  6. Provided `make_bitstream.bat` for one-click execution.

---

## 3. Codebase Hierarchy & File Map

```
VGA_RISC5 / axi_vga-main
│
├── memory.md                            # Comprehensive project history & architectural memory
├── run_sim.tcl                          # One-click automated Vivado simulation script
│
├── src/                                 # AXI VGA Core Design Files
│   ├── axi_vga_reg_pkg.sv               # Register definitions & register struct package
│   ├── axi_vga_reg_top.sv               # Memory-mapped register file & decoder
│   ├── axi_vga_timing_fsm.sv            # VGA timing engine (HSync, VSync, Blanking, Pixel Cnt)
│   ├── axi_vga_fetcher.sv               # AXI4 DMA read burst generator & pixel unpacker
│   └── axi_vga.sv                       # Top-level IP core integrating DMA, timing, and registers
│
├── fpga/                                # FPGA Prototyping & Implementation
│   ├── nexys_video_top.sv               # Top-level FPGA wrapper for Digilent Nexys Video (XC7A200T)
│   ├── nexys_video.xdc                  # Physical constraints for Nexys Video (PMOD JA/JB, Clocks, LEDs)
│   ├── arty_a7_top.sv                   # Top-level FPGA wrapper for Digilent Arty A7
│   ├── arty_a7.xdc                      # Physical constraints for Arty A7
│   ├── vga_reg_init.sv                  # Autonomous startup register initialization FSM
│   ├── axi_synth_fb.sv                  # Real-time synthesizable AXI4 test pattern generator
│   └── build_bitstream.tcl              # Automated synthesis and bitstream build script
│
├── test/                                # Verification Testbench
│   ├── tb_axi_vga.sv                    # Top-level SystemVerilog testbench
│   └── count.mem                        # Hexadecimal memory test pattern data
│
├── output/                              # Simulation Waveform Settings
│   └── tb_axi_vga_behav.wcfg            # Pre-configured signal waveforms for Vivado viewer
│
└── deps/                                # Reusable Hardware Infrastructure
    ├── axi/                             # ETH Zurich AXI4 Protocol Library
    │   ├── include/axi/typedef.svh      # AXI type macros
    │   ├── src/axi_pkg.sv               # AXI constants and functions
    │   ├── src/axi_demux_simple.sv      # AXI demultiplexer
    │   ├── src/axi_demux.sv             # Parameterized AXI demux
    │   ├── src/axi_burst_splitter.sv    # 4KB boundary burst splitter
    │   ├── src/axi_cut.sv & multicut.sv # Timing closure pipeline registers
    │   ├── src/axi_atop_filter.sv       # Atomic operation filter
    │   ├── src/axi_err_slv.sv           # Error slave responder
    │   └── src/axi_sim_mem.sv           # Synthesizable AXI memory model (512KB static RAM)
    │
    ├── common_cells/                    # Low-level hardware cells
    │   ├── src/cf_math_pkg.sv           # Math functions & $clog2 helpers
    │   ├── src/counter.sv & delta_counter.sv # Synchronous counters
    │   ├── src/lzc.sv                   # Leading-zero counter
    │   ├── src/id_queue.sv              # Per-ID transaction FIFO queue
    │   ├── src/rr_arb_tree.sv           # Round-robin arbiter tree
    │   ├── src/spill_register*.sv       # Decoupled ready/valid handshake slices
    │   ├── src/fifo_v3.sv               # Parameterized synchronous FIFO
    │   ├── src/stream_fifo.sv           # Ready/valid stream FIFO wrapper
    │   └── src/stream_join*.sv          # Stream joining synchronization logic
    │
    ├── register_interface/              # OpenTitan / LowRISC Register Generation Library
    │   ├── src/reg_intf.sv              # Standard REG_BUS definition
    │   └── vendor/lowrisc_opentitan/    # LowRISC register storage primitives
    │
    └── common_verification/             # Simulation stimulus helpers
        └── src/clk_rst_gen.sv           # Clock and reset stimulus generator
```

---

## 4. Operational Instructions

### A. How to Run Simulation in Vivado
#### Option 1: Via Windows Launcher (One-Click)
* Double-click **`run_sim.bat`** (or execute `.\run_sim.bat` in PowerShell) to launch Vivado GUI with the curated waveform window.
* For automated headless/batch simulation:
  ```cmd
  .\run_sim.bat -batch
  ```

#### Option 2: Inside Vivado Tcl Console
1. Open Vivado.
2. In the Vivado Tcl Console, navigate to the repository:
   ```tcl
   cd C:/Users/snake/Desktop/VGA_RISC5-main
   source run_sim.tcl
   ```
3. The simulation elaborates and launches automatically with pre-configured waveforms.

### B. How to Build Bitstream & Program Nexys Video FPGA
1. In the Vivado Tcl Console, run:
   ```tcl
   cd C:/Users/snake/Desktop/VGA_RISC5-main
   source fpga/build_bitstream.tcl
   ```
2. Connect Nexys Video via micro-USB and turn power ON.
3. Plug **Pmod VGA** into headers **JA** & **JB**, connected to a monitor.
4. In Vivado Hardware Manager, click **Auto Connect** $\rightarrow$ **Program Device** $\rightarrow$ select `nexys_video_vga.bit`.
5. Use switches **`SW0`** and **`SW1`** to cycle between 8-Color Bars and Pure Red/Green/Blue screens.

---

## 5. Summary of Achievements

- [x] **100% Error-Free Compilation & Elaboration**: Resolved all legacy syntax and compiler segfaults across Vivado 2014.2 and 2020.1+.
- [x] **Deterministic Simulation Output**: Eliminated all undefined (`'x'`) states; verified accurate pixel generation across entire frames.
- [x] **Turnkey Automation**: Provided one-command scripts for both simulation (`run_sim.tcl`) and FPGA bitstream generation (`fpga/build_bitstream.tcl`).
- [x] **Hardware Prototyping Ready**: Complete bitstream pipeline verified for Digilent Nexys Video (Artix-7 XC7A200T) and Arty A7.
- [x] **Full Git Tracking**: All fixes, top-level wrappers, testbench optimizations, and documentation pushed and synced to GitHub repository.
