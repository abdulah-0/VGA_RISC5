// ==============================================================================
// Autonomous Register Initialization FSM for AXI VGA
// ==============================================================================
`timescale 1ns/1ps

module vga_reg_init #(
  parameter int unsigned RegBusAddrWidth = 48,
  parameter int unsigned RegBusDataWidth = 32,
  parameter int unsigned RegBusStrbWidth = 4,
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic
) (
  input  logic     clk_i,
  input  logic     rst_ni,
  output reg_req_t reg_req_o,
  input  reg_rsp_t reg_rsp_i,
  output logic     init_done_o
);

  localparam int unsigned NUM_STEPS = 14;

  typedef struct packed {
    logic [RegBusAddrWidth-1:0] addr;
    logic [RegBusDataWidth-1:0] data;
  } reg_init_step_t;

  // Standard 640x480 @ 60Hz VGA timing configuration
  // Pixel clock = 25 MHz (from 50 MHz system clock / 2)
  reg_init_step_t init_table [0:NUM_STEPS-1];

  assign init_table[0]  = '{addr: 48'h04, data: 32'd2};        // Clock divider = 2 (50MHz / 2 = 25MHz)
  assign init_table[1]  = '{addr: 48'h08, data: 32'd640};      // H visible pixels = 640
  assign init_table[2]  = '{addr: 48'h0C, data: 32'd16};       // H front porch = 16
  assign init_table[3]  = '{addr: 48'h10, data: 32'd96};       // H sync width = 96
  assign init_table[4]  = '{addr: 48'h14, data: 32'd48};       // H back porch = 48
  assign init_table[5]  = '{addr: 48'h18, data: 32'd480};      // V visible lines = 480
  assign init_table[6]  = '{addr: 48'h1C, data: 32'd10};       // V front porch = 10
  assign init_table[7]  = '{addr: 48'h20, data: 32'd2};        // V sync width = 2
  assign init_table[8]  = '{addr: 48'h24, data: 32'd33};       // V back porch = 33
  assign init_table[9]  = '{addr: 48'h30, data: 32'd614400};   // Frame size (640*480*2 bytes = 614,400)
  assign init_table[10] = '{addr: 48'h28, data: 32'h8000_0000};// Base addr low
  assign init_table[11] = '{addr: 48'h2C, data: 32'h0000_0000};// Base addr high
  assign init_table[12] = '{addr: 48'h34, data: 32'd15};       // Burst length = 16 beats (AXI len = 15)
  assign init_table[13] = '{addr: 48'h00, data: 32'h0000_0001};// Enable FSM = 1

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_WRITE,
    ST_WAIT_RSP,
    ST_DONE
  } state_t;

  state_t state_q, state_d;
  logic [4:0] step_q, step_d;

  always_comb begin
    state_d   = state_q;
    step_d    = step_q;
    reg_req_o = '0;

    case (state_q)
      ST_IDLE: begin
        state_d = ST_WRITE;
      end

      ST_WRITE: begin
        reg_req_o.addr  = init_table[step_q].addr;
        reg_req_o.wdata = init_table[step_q].data;
        reg_req_o.wstrb = 4'hF;
        reg_req_o.write = 1'b1;
        reg_req_o.valid = 1'b1;
        if (reg_rsp_i.ready) begin
          state_d = ST_WAIT_RSP;
        end
      end

      ST_WAIT_RSP: begin
        if (step_q == (NUM_STEPS - 1)) begin
          state_d = ST_DONE;
        end else begin
          step_d  = step_q + 1;
          state_d = ST_WRITE;
        end
      end

      ST_DONE: begin
        // Keep idle forever
        state_d = ST_DONE;
      end

      default: state_d = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= ST_IDLE;
      step_q  <= '0;
    end else begin
      state_q <= state_d;
      step_q  <= step_d;
    end
  end

  assign init_done_o = (state_q == ST_DONE);

endmodule
