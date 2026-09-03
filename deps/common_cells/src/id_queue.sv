// Copyright 2018 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51
//
// Clean, robust per-ID FIFO implementation of id_queue
// Fully compatible with Vivado 2014.2 XSim (avoids compiler segfault on complex linked lists)

`timescale 1ns/1ps

module id_queue #(
    parameter int ID_WIDTH  = 0,
    parameter int CAPACITY  = 0,
    parameter bit FULL_BW   = 0,
    parameter type data_t   = logic[31:0],
    // Dependent parameters, DO NOT OVERRIDE!
    localparam type id_t    = logic[ID_WIDTH-1:0]
) (
    input  logic    clk_i,
    input  logic    rst_ni,

    input  id_t     inp_id_i,
    input  data_t   inp_data_i,
    input  logic    inp_req_i,
    output logic    inp_gnt_o,

    input  data_t   exists_data_i,
    input  data_t   exists_mask_i,
    input  logic    exists_req_i,
    output logic    exists_o,
    output logic    exists_gnt_o,

    input  id_t     oup_id_i,
    input  logic    oup_pop_i,
    input  logic    oup_req_i,
    output data_t   oup_data_o,
    output logic    oup_data_valid_o,
    output logic    oup_gnt_o
);

    localparam int NumIds = 2**ID_WIDTH;
    localparam int unsigned FifoDepth = CAPACITY;

    // Per-ID FIFO storage
    data_t mem [0:NumIds-1][0:FifoDepth-1];
    int unsigned rptr [0:NumIds-1];
    int unsigned wptr [0:NumIds-1];
    int unsigned count [0:NumIds-1];

    int unsigned total_count;

    // Total elements across all sub-FIFOs
    always_comb begin
        total_count = 0;
        for (int i = 0; i < NumIds; i++) begin
            total_count = total_count + count[i];
        end
    end

    assign inp_gnt_o = (total_count < FifoDepth);
    assign oup_gnt_o = (count[oup_id_i] > 0);

    // Output data from the sub-FIFO matching oup_id_i
    always_comb begin
        if (count[oup_id_i] > 0) begin
            oup_data_o       = mem[oup_id_i][rptr[oup_id_i]];
            oup_data_valid_o = 1'b1;
        end else begin
            oup_data_o       = '0;
            oup_data_valid_o = 1'b0;
        end
    end

    // Exists port
    assign exists_gnt_o = 1'b1;
    always_comb begin
        exists_o = 1'b0;
        if (exists_req_i) begin
            for (int i = 0; i < NumIds; i++) begin
                for (int j = 0; j < FifoDepth; j++) begin
                    if (j < count[i]) begin
                        int unsigned idx;
                        idx = (rptr[i] + j) % FifoDepth;
                        if ((mem[i][idx] & exists_mask_i) == (exists_data_i & exists_mask_i)) begin
                            exists_o = 1'b1;
                        end
                    end
                end
            end
        end
    end

    // Sequential updates
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i < NumIds; i++) begin
                rptr[i]  <= 0;
                wptr[i]  <= 0;
                count[i] <= 0;
                for (int j = 0; j < FifoDepth; j++) begin
                    mem[i][j] <= '0;
                end
            end
        end else begin
            // Handle output pop
            if (oup_req_i && oup_pop_i && (count[oup_id_i] > 0)) begin
                rptr[oup_id_i]  <= (rptr[oup_id_i] + 1) % FifoDepth;
                count[oup_id_i] <= count[oup_id_i] - 1;
            end

            // Handle input push
            if (inp_req_i && inp_gnt_o) begin
                mem[inp_id_i][wptr[inp_id_i]] <= inp_data_i;
                wptr[inp_id_i] <= (wptr[inp_id_i] + 1) % FifoDepth;
                if (!(oup_req_i && oup_pop_i && (oup_id_i == inp_id_i) && (count[oup_id_i] > 0))) begin
                    count[inp_id_i] <= count[inp_id_i] + 1;
                end
            end
        end
    end

endmodule
