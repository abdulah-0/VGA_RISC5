## ==============================================================================
## Physical Constraints (XDC) for Digilent Arty A7 (XC7A35T / XC7A100T)
## ==============================================================================

## 100 MHz Master Oscillator Clock
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_100mhz }];

## Active-Low CPU Reset Pushbutton
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { btn_reset_n }];

## Slide Switches (Color Pattern Select)
## SW0=0, SW1=0 : 8 Color Bars
## SW0=1, SW1=0 : Solid Pure Red
## SW0=0, SW1=1 : Solid Pure Green
## SW0=1, SW1=1 : Solid Pure Blue
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];

## User LEDs (Status / Heartbeat)
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; # MMCM Lock
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; # Init Done
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; # VSync Status
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; # Heartbeat Blinker

## PMOD Header JA (Red and Blue channels)
set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]; # JA1
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]; # JA2
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }]; # JA3
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }]; # JA4
set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]; # JA7
set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]; # JA8
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }]; # JA9
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }]; # JA10

## PMOD Header JB (Green channel, HSync, VSync)
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]; # JB1
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]; # JB2
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }]; # JB3
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }]; # JB4
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }];# JB7
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }];# JB8

## Configuration Voltage Settings
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
