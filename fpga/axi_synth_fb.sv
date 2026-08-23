// ==============================================================================
// Synthesizable On-Chip AXI4 Test Pattern Framebuffer
// Generates standard 8-color test bars and selectable solid RGB colors
// ==============================================================================
`timescale 1ns/1ps

module axi_synth_fb #(
  parameter int unsigned AddrWidth = 48,
  parameter int unsigned DataWidth = 64,
  parameter int unsigned IdWidth   = 2,
  parameter int unsigned UserWidth = 1,
  parameter type         axi_req_t = logic,
  parameter type         axi_rsp_t = logic
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic [1:0]        pattern_mode_i, // 0: Color Bars, 1: Pure Red, 2: Pure Green, 3: Pure Blue
  input  axi_req_t          axi_req_i,
  output axi_rsp_t          axi_rsp_o
);

  localparam logic [15:0] COLOR_WHITE   = 16'hFFFF;
  localparam logic [15:0] COLOR_YELLOW  = 16'hFFE0;
  localparam logic [15:0] COLOR_CYAN    = 16'h07FF;
  localparam logic [15:0] COLOR_GREEN   = 16'h07E0;
  localparam logic [15:0] COLOR_MAGENTA = 16'hF81F;
  localparam logic [15:0] COLOR_RED     = 16'hF800;
  localparam logic [15:0] COLOR_BLUE    = 16'h001F;
  localparam logic [15:0] COLOR_BLACK   = 16'h0000;

  typedef enum logic [1:0] {
    ST_AR_WAIT,
    ST_R_STREAM
  } state_t;

  state_t state_q, state_d;

  logic [AddrWidth-1:0] ar_addr_q, ar_addr_d;
  logic [7:0]           ar_len_q, ar_len_d;
  logic [IdWidth-1:0]   ar_id_q, ar_id_d;
  logic [7:0]           r_cnt_q, r_cnt_d;

  // Compute current pixel address in frame
  logic [31:0] byte_offset;
  assign byte_offset = (ar_addr_q + (r_cnt_q * 8)) - 32'h8000_0000;

  // 4 pixels per 64-bit beat (each pixel = 2 bytes)
  logic [15:0] pixel0, pixel1, pixel2, pixel3;

  function automatic logic [15:0] get_pixel(input logic [31:0] pixel_idx, input logic [1:0] mode);
    logic [9:0] col;
    begin
      col = pixel_idx % 640;
      case (mode)
        2'b01: get_pixel = COLOR_RED;
        2'b10: get_pixel = COLOR_GREEN;
        2'b11: get_pixel = COLOR_BLUE;
        default: begin // 8 Color Bars (80 pixels each)
          if (col < 80)        get_pixel = COLOR_WHITE;
          else if (col < 160)  get_pixel = COLOR_YELLOW;
          else if (col < 240)  get_pixel = COLOR_CYAN;
          else if (col < 320)  get_pixel = COLOR_GREEN;
          else if (col < 400)  get_pixel = COLOR_MAGENTA;
          else if (col < 480)  get_pixel = COLOR_RED;
          else if (col < 560)  get_pixel = COLOR_BLUE;
          else                 get_pixel = COLOR_BLACK;
        end
      endcase
    end
  endfunction

  logic [31:0] p_idx0, p_idx1, p_idx2, p_idx3;
  assign p_idx0 = (byte_offset >> 1);
  assign p_idx1 = (byte_offset >> 1) + 1;
  assign p_idx2 = (byte_offset >> 1) + 2;
  assign p_idx3 = (byte_offset >> 1) + 3;

  assign pixel0 = get_pixel(p_idx0, pattern_mode_i);
  assign pixel1 = get_pixel(p_idx1, pattern_mode_i);
  assign pixel2 = get_pixel(p_idx2, pattern_mode_i);
  assign pixel3 = get_pixel(p_idx3, pattern_mode_i);

  always_comb begin
    state_d   = state_q;
    ar_addr_d = ar_addr_q;
    ar_len_d  = ar_len_q;
    ar_id_d   = ar_id_q;
    r_cnt_d   = r_cnt_q;

    axi_rsp_o = '0;

    case (state_q)
      ST_AR_WAIT: begin
        axi_rsp_o.ar_ready = 1'b1;
        if (axi_req_i.ar_valid) begin
          ar_addr_d = axi_req_i.ar.addr;
          ar_len_d  = axi_req_i.ar.len;
          ar_id_d   = axi_req_i.ar.id;
          r_cnt_d   = '0;
          state_d   = ST_R_STREAM;
        end
      end

      ST_R_STREAM: begin
        axi_rsp_o.r_valid = 1'b1;
        axi_rsp_o.r.id    = ar_id_q;
        axi_rsp_o.r.resp  = 2'b00; // OKAY
        axi_rsp_o.r.last  = (r_cnt_q == ar_len_q);
        axi_rsp_o.r.data  = {pixel3, pixel2, pixel1, pixel0};

        if (axi_req_i.r_ready) begin
          if (r_cnt_q == ar_len_q) begin
            state_d = ST_AR_WAIT;
          end else begin
            r_cnt_d = r_cnt_q + 1;
          end
        end
      end

      default: state_d = ST_AR_WAIT;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q   <= ST_AR_WAIT;
      ar_addr_q <= '0;
      ar_len_q  <= '0;
      ar_id_q   <= '0;
      r_cnt_q   <= '0;
    end else begin
      state_q   <= state_d;
      ar_addr_q <= ar_addr_d;
      ar_len_q  <= ar_len_d;
      ar_id_q   <= ar_id_d;
      r_cnt_q   <= r_cnt_d;
    end
  end

endmodule
