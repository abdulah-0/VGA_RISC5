// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Andreas Kurth  <akurth@iis.ee.ethz.ch>

`timescale 1ns/1ps

`include "axi/typedef.svh"

/// An AXI4 memory for simulation.
module axi_sim_mem #(
  parameter int unsigned AddrWidth = 0,
  parameter int unsigned DataWidth = 0,
  parameter int unsigned IdWidth = 0,
  parameter int unsigned UserWidth = 0,
  parameter type         axi_req_t = logic,
  parameter type         axi_rsp_t = logic,
  parameter bit          WarnUninitialized = 1'b0,
  parameter bit          ClearErrOnAccess = 1'b0,
  parameter time         ApplDelay = 0,
  parameter time         AcqDelay = 0
) (
  input  logic     clk_i,
  input  logic     rst_ni,
  input  axi_req_t axi_req_i,
  output axi_rsp_t axi_rsp_o,
  output logic                 mon_w_valid_o,
  output logic [AddrWidth-1:0] mon_w_addr_o,
  output logic [DataWidth-1:0] mon_w_data_o,
  output logic [IdWidth-1:0]   mon_w_id_o,
  output logic [UserWidth-1:0] mon_w_user_o,
  output axi_pkg::len_t        mon_w_beat_count_o,
  output logic                 mon_w_last_o,
  output logic                 mon_r_valid_o,
  output logic [AddrWidth-1:0] mon_r_addr_o,
  output logic [DataWidth-1:0] mon_r_data_o,
  output logic [IdWidth-1:0]   mon_r_id_o,
  output logic [UserWidth-1:0] mon_r_user_o,
  output axi_pkg::len_t        mon_r_beat_count_o,
  output logic                 mon_r_last_o
);

  localparam int unsigned StrbWidth = DataWidth / 8;
  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [IdWidth-1:0]   id_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [UserWidth-1:0] user_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_t, data_t, id_t, user_t)

  typedef struct packed {
    logic                 valid;
    logic [AddrWidth-1:0] addr;
    logic [DataWidth-1:0] data;
    logic [IdWidth-1:0]   id;
    logic [UserWidth-1:0] user;
    axi_pkg::len_t        beat_count;
    logic                 last;
  } monitor_t;

  monitor_t mon_w, mon_r;

  // Static memory array compatible with Vivado 2014.2 XSim
  localparam int unsigned MemBaseAddr = 32'h8000_0000;
  localparam int unsigned MemSize     = 32'h0008_0000; // 512 KB
  logic [7:0] mem [MemBaseAddr : MemBaseAddr + MemSize - 1];

  initial begin
    for (int unsigned a = MemBaseAddr; a < MemBaseAddr + MemSize; a++) begin
      mem[a] = (a - MemBaseAddr) & 8'hff;
    end
  end

  localparam int MaxQueueDepth = 64;
  aw_t aw_queue [0:MaxQueueDepth-1];
  int  aw_q_head = 0, aw_q_tail = 0, aw_q_count = 0;

  ar_t ar_queue [0:MaxQueueDepth-1];
  int  ar_q_head = 0, ar_q_tail = 0, ar_q_count = 0;

  b_t  b_queue [0:MaxQueueDepth-1];
  int  b_q_head = 0, b_q_tail = 0, b_q_count = 0;

  // error happened in write burst
  axi_pkg::resp_t error_happened = axi_pkg::RESP_OKAY;

  initial begin
    automatic shortint unsigned r_cnt = 0, w_cnt = 0;
    axi_rsp_o = '0;
    mon_w = '0;
    mon_r = '0;
    wait (rst_ni);
    fork
      // AW channel
      forever begin
        @(posedge clk_i);
        #(ApplDelay);
        axi_rsp_o.aw_ready = 1'b1;
        #(AcqDelay - ApplDelay);
        if (axi_req_i.aw_valid) begin
          aw_queue[aw_q_tail] = axi_req_i.aw;
          aw_q_tail = (aw_q_tail + 1) % MaxQueueDepth;
          aw_q_count = aw_q_count + 1;
        end
      end

      // W channel
      forever begin
        @(posedge clk_i);
        #(ApplDelay);
        axi_rsp_o.w_ready = 1'b0;
        mon_w = '0;
        if (aw_q_count != 0) begin
          axi_rsp_o.w_ready = 1'b1;
          #(AcqDelay - ApplDelay);
          if (axi_req_i.w_valid) begin
            automatic aw_t cur_aw = aw_queue[aw_q_head];
            automatic axi_pkg::burst_t burst = cur_aw.burst;
            automatic axi_pkg::len_t len = cur_aw.len;
            automatic axi_pkg::size_t size = cur_aw.size;
            automatic addr_t addr = axi_pkg::beat_addr(cur_aw.addr, size, len, burst, w_cnt);
            mon_w.valid = 1'b1;
            mon_w.addr = addr;
            mon_w.data = axi_req_i.w.data;
            mon_w.id = cur_aw.id;
            mon_w.user = cur_aw.user;
            mon_w.beat_count = w_cnt;
            for (shortint unsigned
                i_byte = axi_pkg::beat_lower_byte(cur_aw.addr, size, len, burst, StrbWidth, w_cnt);
                i_byte <= axi_pkg::beat_upper_byte(cur_aw.addr, size, len, burst, StrbWidth, w_cnt);
                i_byte++) begin
              if (axi_req_i.w.strb[i_byte]) begin
                automatic addr_t byte_addr = (addr / StrbWidth) * StrbWidth + i_byte;
                if (byte_addr >= MemBaseAddr && byte_addr < MemBaseAddr + MemSize) begin
                  mem[byte_addr] = axi_req_i.w.data[i_byte*8+:8];
                end
              end
            end
            if (w_cnt == cur_aw.len) begin
              automatic b_t b_beat = '0;
              b_beat.id = cur_aw.id;
              b_beat.resp = axi_pkg::RESP_OKAY;
              b_queue[b_q_tail] = b_beat;
              b_q_tail = (b_q_tail + 1) % MaxQueueDepth;
              b_q_count = b_q_count + 1;
              w_cnt = 0;
              mon_w.last = 1'b1;
              aw_q_head = (aw_q_head + 1) % MaxQueueDepth;
              aw_q_count = aw_q_count - 1;
            end else begin
              w_cnt++;
            end
          end
        end
      end

      // B channel
      forever begin
        @(posedge clk_i);
        #(ApplDelay);
        axi_rsp_o.b_valid = 1'b0;
        if (b_q_count != 0) begin
          axi_rsp_o.b = b_queue[b_q_head];
          axi_rsp_o.b_valid = 1'b1;
          #(AcqDelay - ApplDelay);
          if (axi_req_i.b_ready) begin
            b_q_head = (b_q_head + 1) % MaxQueueDepth;
            b_q_count = b_q_count - 1;
          end
        end
      end

      // AR channel
      forever begin
        @(posedge clk_i);
        #(ApplDelay);
        axi_rsp_o.ar_ready = 1'b1;
        #(AcqDelay - ApplDelay);
        if (axi_req_i.ar_valid) begin
          ar_queue[ar_q_tail] = axi_req_i.ar;
          ar_q_tail = (ar_q_tail + 1) % MaxQueueDepth;
          ar_q_count = ar_q_count + 1;
        end
      end

      // R channel
      forever begin
        @(posedge clk_i);
        #(ApplDelay);
        axi_rsp_o.r_valid = 1'b0;
        mon_r = '0;
        if (ar_q_count != 0) begin
          automatic ar_t cur_ar = ar_queue[ar_q_head];
          automatic axi_pkg::burst_t burst = cur_ar.burst;
          automatic axi_pkg::len_t len = cur_ar.len;
          automatic axi_pkg::size_t size = cur_ar.size;
          automatic addr_t addr = axi_pkg::beat_addr(cur_ar.addr, size, len, burst, r_cnt);
          automatic r_t r_beat = '0;
          automatic data_t r_data = '0;
          r_beat.data = '0;
          r_beat.id = cur_ar.id;
          r_beat.resp = axi_pkg::RESP_OKAY;
          for (shortint unsigned
              i_byte = axi_pkg::beat_lower_byte(cur_ar.addr, size, len, burst, StrbWidth, r_cnt);
              i_byte <= axi_pkg::beat_upper_byte(cur_ar.addr, size, len, burst, StrbWidth, r_cnt);
              i_byte++) begin
            automatic addr_t byte_addr = (addr / StrbWidth) * StrbWidth + i_byte;
            if (byte_addr >= MemBaseAddr && byte_addr < MemBaseAddr + MemSize) begin
              r_data[i_byte*8+:8] = mem[byte_addr];
            end else begin
              r_data[i_byte*8+:8] = 8'h00;
            end
          end
          r_beat.data = r_data;
          if (r_cnt == cur_ar.len) begin
            r_beat.last = 1'b1;
            mon_r.last = 1'b1;
          end
          axi_rsp_o.r = r_beat;
          axi_rsp_o.r_valid = 1'b1;
          mon_r.valid = 1'b1;
          mon_r.addr = addr;
          mon_r.data = r_beat.data;
          mon_r.id = r_beat.id;
          mon_r.user = cur_ar.user;
          mon_r.beat_count = r_cnt;
          #(AcqDelay - ApplDelay);
          while (!axi_req_i.r_ready) begin
            @(posedge clk_i);
            #(AcqDelay);
            mon_r = '0;
          end
          if (r_beat.last) begin
            r_cnt = 0;
            ar_q_head = (ar_q_head + 1) % MaxQueueDepth;
            ar_q_count = ar_q_count - 1;
          end else begin
            r_cnt++;
          end
        end
      end
    join
  end

  initial begin
    mon_w_valid_o = '0;
    mon_w_addr_o = '0;
    mon_w_data_o = '0;
    mon_w_id_o = '0;
    mon_w_user_o = '0;
    mon_w_beat_count_o = '0;
    mon_w_last_o = '0;
    mon_r_valid_o = '0;
    mon_r_addr_o = '0;
    mon_r_data_o = '0;
    mon_r_id_o = '0;
    mon_r_user_o = '0;
    mon_r_beat_count_o = '0;
    mon_r_last_o = '0;
    wait (rst_ni);
    forever begin
      @(posedge clk_i);
      mon_w_valid_o <= #(ApplDelay) mon_w.valid;
      mon_w_addr_o <= #(ApplDelay) mon_w.addr;
      mon_w_data_o <= #(ApplDelay) mon_w.data;
      mon_w_id_o <= #(ApplDelay) mon_w.id;
      mon_w_user_o <= #(ApplDelay) mon_w.user;
      mon_w_beat_count_o <= #(ApplDelay) mon_w.beat_count;
      mon_w_last_o <= #(ApplDelay) mon_w.last;
      mon_r_valid_o <= #(ApplDelay) mon_r.valid;
      mon_r_addr_o <= #(ApplDelay) mon_r.addr;
      mon_r_data_o <= #(ApplDelay) mon_r.data;
      mon_r_id_o <= #(ApplDelay) mon_r.id;
      mon_r_user_o <= #(ApplDelay) mon_r.user;
      mon_r_beat_count_o <= #(ApplDelay) mon_r.beat_count;
      mon_r_last_o <= #(ApplDelay) mon_r.last;
    end
  end

  // Parameter Assertions
  initial begin
    assert (AddrWidth != 0) else $fatal(1, "AddrWidth must be non-zero!");
    assert (DataWidth != 0) else $fatal(1, "DataWidth must be non-zero!");
    assert (IdWidth != 0) else $fatal(1, "IdWidth must be non-zero!");
    assert (UserWidth != 0) else $fatal(1, "UserWidth must be non-zero!");
  end

endmodule
