// ==============================================================================
// Top-Level FPGA Prototype Wrapper for Digilent Nexys A7 (Artix-7 XC7A100T / XC7A50T)
// Compatible with onboard DB15 VGA Connector
// ==============================================================================
`timescale 1ns/1ps

module nexys_a7_top (
  input  logic        clk_100mhz,   // 100 MHz Master Oscillator Clock (Pin E3)
  input  logic        btn_reset_n,  // Active-Low CPU Reset Pushbutton (Pin C12)
  input  logic [1:0]  sw,           // Slide switches for color mode (Pins J15, L16)
  output logic [3:0]  led,          // 4 User LEDs (Pins H17, K15, J13, N14)

  // Direct Onboard VGA Port (DB15 Connector)
  output logic [3:0]  vga_r,        // Red Channel (Pins A3, B4, C5, A4)
  output logic [3:0]  vga_g,        // Green Channel (Pins C6, A5, B6, A6)
  output logic [3:0]  vga_b,        // Blue Channel (Pins B7, C7, D7, D8)
  output logic        vga_hsync,    // Horizontal Sync (Pin B11)
  output logic        vga_vsync     // Vertical Sync (Pin B12)
);

  `include "axi/typedef.svh"
  `include "register_interface/assign.svh"
  `include "register_interface/typedef.svh"

  // AXI & RegBus Parameters
  localparam int unsigned AXIAddrWidth    = 48;
  localparam int unsigned AXIDataWidth    = 64;
  localparam int unsigned AXIStrbWidth    =  8;
  localparam int unsigned AXIIdWidth      =  2;
  localparam int unsigned AXIUserWidth    =  1;
  localparam int unsigned BufferDepth     = 16;
  localparam int unsigned MaxReadTxns     = 16;

  localparam int unsigned RegBusAddrWidth = 48;
  localparam int unsigned RegBusDataWidth = 32;
  localparam int unsigned RegBusStrbWidth =  4;

  // --------------------------------------------------------------------------
  // 1. Clock Generation via Native Xilinx 7-Series MMCM Primitive
  //    100 MHz Input -> 800 MHz VCO -> 50 MHz System Clock
  // --------------------------------------------------------------------------
  logic clk_50mhz, clk_fb, mmcm_locked;

  MMCME2_BASE #(
    .BANDWIDTH          ( "OPTIMIZED" ),
    .CLKFBOUT_MULT_F    ( 8.0         ), // 100 MHz * 8.0 = 800 MHz VCO
    .CLKFBOUT_PHASE     ( 0.0         ),
    .CLKIN1_PERIOD      ( 10.0        ), // 100 MHz input
    .CLKOUT0_DIVIDE_F   ( 16.0        ), // 800 MHz / 16.0 = 50 MHz
    .CLKOUT0_DUTY_CYCLE ( 0.5         ),
    .CLKOUT0_PHASE      ( 0.0         ),
    .DIVCLK_DIVIDE      ( 1           ),
    .STARTUP_WAIT       ( "FALSE"     )
  ) u_mmcm (
    .CLKOUT0            ( clk_50mhz   ),
    .CLKOUT0B           (             ),
    .CLKOUT1            (             ),
    .CLKOUT1B           (             ),
    .CLKOUT2            (             ),
    .CLKOUT2B           (             ),
    .CLKOUT3            (             ),
    .CLKOUT3B           (             ),
    .CLKOUT4            (             ),
    .CLKOUT5            (             ),
    .CLKOUT6            (             ),
    .CLKFBOUT           ( clk_fb      ),
    .CLKFBOUTB          (             ),
    .LOCKED             ( mmcm_locked ),
    .CLKIN1             ( clk_100mhz  ),
    .PWRDWN             ( 1'b0        ),
    .RST                ( ~btn_reset_n),
    .CLKFBIN            ( clk_fb      )
  );

  // Synchronous Reset Generation
  logic [3:0] rst_sync_q;
  always_ff @(posedge clk_50mhz or negedge btn_reset_n) begin
    if (!btn_reset_n) begin
      rst_sync_q <= 4'h0;
    end else begin
      rst_sync_q <= {rst_sync_q[2:0], mmcm_locked};
    end
  end
  logic rst_n;
  assign rst_n = rst_sync_q[3];

  // --------------------------------------------------------------------------
  // 2. Struct Definitions for AXI and Register Bus
  // --------------------------------------------------------------------------
  `AXI_TYPEDEF_ALL(axi_fpga, logic [AXIAddrWidth-1:0], logic [AXIIdWidth-1:0], logic [AXIDataWidth-1:0], logic [AXIStrbWidth-1:0], logic [AXIUserWidth-1:0])
  `REG_BUS_TYPEDEF_ALL(reg_fpga, logic [RegBusAddrWidth-1:0], logic [RegBusDataWidth-1:0], logic [RegBusStrbWidth-1:0])

  axi_fpga_req_t  vga_axi_req;
  axi_fpga_resp_t vga_axi_resp;

  reg_fpga_req_t  vga_reg_req;
  reg_fpga_rsp_t  vga_reg_rsp;

  // --------------------------------------------------------------------------
  // 3. Autonomous Register Initialization FSM
  // --------------------------------------------------------------------------
  logic init_done;
  vga_reg_init #(
    .RegBusAddrWidth ( RegBusAddrWidth ),
    .RegBusDataWidth ( RegBusDataWidth ),
    .RegBusStrbWidth ( RegBusStrbWidth ),
    .reg_req_t      ( reg_fpga_req_t  ),
    .reg_rsp_t      ( reg_fpga_rsp_t  )
  ) u_reg_init (
    .clk_i       ( clk_50mhz   ),
    .rst_ni      ( rst_n       ),
    .reg_req_o   ( vga_reg_req ),
    .reg_rsp_i   ( vga_reg_rsp ),
    .init_done_o ( init_done   )
  );

  // --------------------------------------------------------------------------
  // 4. Synthesizable AXI4 Test Pattern Framebuffer (Color Bars & Solid Colors)
  // --------------------------------------------------------------------------
  axi_synth_fb #(
    .AddrWidth ( AXIAddrWidth  ),
    .DataWidth ( AXIDataWidth  ),
    .IdWidth   ( AXIIdWidth    ),
    .UserWidth ( AXIUserWidth  ),
    .axi_req_t ( axi_fpga_req_t  ),
    .axi_rsp_t ( axi_fpga_resp_t )
  ) u_synth_fb (
    .clk_i          ( clk_50mhz       ),
    .rst_ni         ( rst_n           ),
    .pattern_mode_i ( sw              ), // sw=00: Color bars, 01: Red, 10: Green, 11: Blue
    .axi_req_i      ( vga_axi_req     ),
    .axi_rsp_o      ( vga_axi_resp    )
  );

  // --------------------------------------------------------------------------
  // 5. AXI VGA Display Controller IP
  // --------------------------------------------------------------------------
  logic [4:0] red_5bit;
  logic [5:0] green_6bit;
  logic [4:0] blue_5bit;

  axi_vga #(
    .RedWidth       ( 5                 ),
    .GreenWidth     ( 6                 ),
    .BlueWidth      ( 5                 ),
    .HCountWidth    ( 12                ),
    .VCountWidth    ( 12                ),
    .AXIAddrWidth   ( AXIAddrWidth      ),
    .AXIDataWidth   ( AXIDataWidth      ),
    .AXIStrbWidth   ( AXIStrbWidth      ),
    .AXIIdWidth     ( AXIIdWidth        ),
    .AXIUserWidth   ( AXIUserWidth      ),
    .BufferDepth    ( BufferDepth       ),
    .MaxReadTxns    ( MaxReadTxns       ),
    .axi_req_t      ( axi_fpga_req_t    ),
    .axi_resp_t     ( axi_fpga_resp_t   ),
    .axi_r_chan_t   ( axi_fpga_r_chan_t ),
    .reg_req_t      ( reg_fpga_req_t    ),
    .reg_resp_t     ( reg_fpga_rsp_t    )
  ) u_axi_vga (
    .clk_i          ( clk_50mhz         ),
    .rst_ni         ( rst_n             ),
    .test_mode_en_i ( 1'b0              ),

    // Register configuration bus
    .reg_req_i      ( vga_reg_req       ),
    .reg_rsp_o      ( vga_reg_rsp       ),

    // AXI DMA Read Port
    .axi_req_o      ( vga_axi_req       ),
    .axi_resp_i     ( vga_axi_resp      ),

    // VGA Output Signals
    .hsync_o        ( vga_hsync         ),
    .vsync_o        ( vga_vsync         ),
    .red_o          ( red_5bit          ),
    .green_o        ( green_6bit        ),
    .blue_o         ( blue_5bit         )
  );

  // Map 5/6/5 RGB to 4/4/4 Nexys A7 Onboard VGA DAC (take MSBs)
  assign vga_r = red_5bit[4:1];
  assign vga_g = green_6bit[5:2];
  assign vga_b = blue_5bit[4:1];

  // --------------------------------------------------------------------------
  // 6. Diagnostics & Status LEDs
  // --------------------------------------------------------------------------
  logic [25:0] heartbeat_cnt;
  always_ff @(posedge clk_50mhz or negedge rst_n) begin
    if (!rst_n) heartbeat_cnt <= '0;
    else        heartbeat_cnt <= heartbeat_cnt + 1;
  end

  assign led[0] = mmcm_locked;        // LED0: MMCM Lock OK
  assign led[1] = init_done;          // LED1: VGA Configuration Complete
  assign led[2] = vga_vsync;          // LED2: Frame VSync Activity
  assign led[3] = heartbeat_cnt[24];  // LED3: Heartbeat (~1.5 Hz blinker)

endmodule
