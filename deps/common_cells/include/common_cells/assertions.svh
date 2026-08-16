// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

`ifdef UVM
  // report assertion error with UVM if compiled
  package assert_rpt_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    function void assert_rpt(string msg);
      `uvm_error("ASSERT FAILED", msg)
    endfunction
  endpackage
`endif

///////////////////
// Helper macros //
///////////////////

// local helper macro to reduce code clutter. undefined at the end of this file
// Disabling assertions for Vivado compatibility
// `define INC_ASSERT
// Block disabled to prevent compilation errors under Vivado 2014.2

// Converts an arbitrary block of code into a Verilog string
`define PRIM_STRINGIFY(__x) `"__x`"

// ASSERT_RPT is available to change the reporting mechanism when an assert fails
`define ASSERT_RPT(__name)                                                  \
`ifdef UVM                                                                  \
  assert_rpt_pkg::assert_rpt($sformatf("[%m] %s (%s:%0d)",                  \
                             __name, `__FILE__, `__LINE__));                \
`else                                                                       \
  $error("[ASSERT FAILED] [%m] %s (%s:%0d)", __name, `__FILE__, `__LINE__); \
`endif

///////////////////////////////////////
// Simple assertion and cover macros //
///////////////////////////////////////

// Default clk and reset signals used by assertion macros below.
`define ASSERT_DEFAULT_CLK clk_i
`define ASSERT_DEFAULT_RST !rst_ni

`ifdef INC_ASSERT

// Immediate assertion
// Note that immediate assertions are sensitive to simulation glitches.
`define ASSERT_I(__name, __prop)           \
  __name: assert (__prop)                  \
    else begin                             \
      `ASSERT_RPT(`PRIM_STRINGIFY(__name)) \
    end

// Assertion in initial block. Can be used for things like parameter checking.
`define ASSERT_INIT(__name, __prop)          \
  initial begin                              \
    __name: assert (__prop)                  \
      else begin                             \
        `ASSERT_RPT(`PRIM_STRINGIFY(__name)) \
      end                                    \
  end

// Assertion in final block. Can be used for things like queues being empty
// at end of sim, all credits returned at end of sim, state machines in idle
// at end of sim.
`define ASSERT_FINAL(__name, __prop)                                         \
  final begin                                                                \
    __name: assert (__prop || $test$plusargs("disable_assert_final_checks")) \
      else begin                                                             \
        `ASSERT_RPT(`PRIM_STRINGIFY(__name))                                 \
      end                                                                    \
  end

// Assert a concurrent property directly.
// It can be called as a module (or interface) body item.
`define ASSERT(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `ASSERT_RPT(`PRIM_STRINGIFY(__name))                                               \
    end

// Assert a concurrent property NEVER happens
`define ASSERT_NEVER(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  __name: assert property (@(posedge __clk) disable iff ((__rst) !== '0) not (__prop))         \
    else begin                                                                                 \
      `ASSERT_RPT(`PRIM_STRINGIFY(__name))                                                     \
    end

// Assert that signal has a known value (each bit is either '0' or '1') after reset.
// It can be called as a module (or interface) body item.
`define ASSERT_KNOWN(__name, __sig, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ASSERT(__name, !$isunknown(__sig), __clk, __rst)

//  Cover a concurrent property
`define COVER(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  __name: cover property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop));

// Assert that signal is an active-high pulse with pulse length of 1 clock cycle
`define ASSERT_PULSE(__name, __sig, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)

// Assert that a property is true only when an enable signal is set.  It can be called as a module
// (or interface) body item.
`define ASSERT_IF(__name, __prop, __enable, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)

// Assert that signal has a known value (each bit is either '0' or '1') after reset if enable is
// set.  It can be called as a module (or interface) body item.
`define ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
  `ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)

// Assume a concurrent property
`define ASSUME(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  __name: assume property (@(posedge __clk) disable iff ((__rst) !== '0) (__prop))       \
    else begin                                                                           \
      `ASSERT_RPT(`PRIM_STRINGIFY(__name))                                               \
    end

// Assume an immediate property
`define ASSUME_I(__name, __prop)           \
  __name: assume (__prop)                  \
    else begin                             \
      `ASSERT_RPT(`PRIM_STRINGIFY(__name)) \
    end

// ASSUME_FPV
// Assume a concurrent property during formal verification only.
`define ASSUME_FPV(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                                \
   `ASSUME(__name, __prop, __clk, __rst)                                                     \
`endif

// ASSUME_I_FPV
// Assume a concurrent property during formal verification only.
`define ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `ASSUME_I(__name, __prop)         \
`endif

// COVER_FPV
// Cover a concurrent property during formal verification
`define COVER_FPV(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
`ifdef FPV_ON                                                                               \
   `COVER(__name, __prop, __clk, __rst)                                                     \
`endif

`else

`define ASSERT_I(__name, __prop)
`define ASSERT_INIT(__name, __prop)
`define ASSERT_FINAL(__name, __prop)
`define ASSERT(__name, __prop)
`define ASSERT_NEVER(__name, __prop)
`define ASSERT_KNOWN(__name, __sig)
`define COVER(__name, __prop)
`define ASSERT_PULSE(__name, __sig)
`define ASSERT_IF(__name, __prop)
`define ASSERT_KNOWN_IF(__name, __sig)
`define ASSUME(__name, __prop)
`define ASSUME_I(__name, __prop)
`define ASSUME_FPV(__name, __prop)
`define ASSUME_I_FPV(__name, __prop)
`define COVER_FPV(__name, __prop)

`endif

`endif // PRIM_ASSERT_SV
