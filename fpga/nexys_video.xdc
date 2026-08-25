## ==============================================================================
## Physical Constraints (XDC) for Digilent Nexys Video (Artix-7 XC7A200T-1SBG484C)
## ==============================================================================

## 100 MHz Master Oscillator Clock (Pin R4)
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_100mhz }];

## Active-Low CPU Reset Pushbutton (Pin G4)
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS15 } [get_ports { btn_reset_n }];

## Slide Switches (Color Pattern Select)
## SW0=0, SW1=0 : 8 Color Bars
## SW0=1, SW1=0 : Solid Pure Red
## SW0=0, SW1=1 : Solid Pure Green
## SW0=1, SW1=1 : Solid Pure Blue
set_property -dict { PACKAGE_PIN E22   IOSTANDARD LVCMOS12 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN F21   IOSTANDARD LVCMOS12 } [get_ports { sw[1] }];

## User LEDs (Status / Diagnostics)
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS25 } [get_ports { led[0] }]; # MMCM Lock
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS25 } [get_ports { led[1] }]; # Init Done
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS25 } [get_ports { led[2] }]; # VSync Status
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS25 } [get_ports { led[3] }]; # Heartbeat Blinker

## PMOD Header JA (Red and Blue channels for Pmod VGA)
set_property -dict { PACKAGE_PIN AB22  IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]; # JA1
set_property -dict { PACKAGE_PIN AB21  IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]; # JA2
set_property -dict { PACKAGE_PIN AB20  IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }]; # JA3
set_property -dict { PACKAGE_PIN AB18  IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }]; # JA4
set_property -dict { PACKAGE_PIN Y21   IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]; # JA7
set_property -dict { PACKAGE_PIN AA21  IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]; # JA8
set_property -dict { PACKAGE_PIN AA20  IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }]; # JA9
set_property -dict { PACKAGE_PIN AA18  IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }]; # JA10

## PMOD Header JB (Green channel, HSync, VSync for Pmod VGA)
set_property -dict { PACKAGE_PIN V9    IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]; # JB1
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]; # JB2
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }]; # JB3
set_property -dict { PACKAGE_PIN W7    IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }]; # JB4
set_property -dict { PACKAGE_PIN W9    IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }];# JB7
set_property -dict { PACKAGE_PIN Y9    IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }];# JB8

## Configuration Voltage Settings
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
