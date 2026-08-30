create_clock -name pixel_clk -period 13.5 -waveform {0 6.75} [get_nets {S_pixel_clk}]
create_clock -name serial_clk -period 2.7 -waveform {0 1.35} [get_nets {S_serial_clk}]

set_clock_groups -exclusive -group [get_clocks {pixel_clk}] -group [get_clocks {serial_clk}]