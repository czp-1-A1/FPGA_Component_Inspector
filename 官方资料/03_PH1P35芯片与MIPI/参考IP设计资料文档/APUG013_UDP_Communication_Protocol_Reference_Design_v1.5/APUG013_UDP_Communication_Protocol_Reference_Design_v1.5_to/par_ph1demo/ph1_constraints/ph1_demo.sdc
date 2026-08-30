create_clock -name clk_in -period 40 -waveform {0 20} [get_ports {clk_25}]
create_clock -name phy1_rgmii_rx_clk -period 8 -waveform {0 4} [get_ports {phy1_rgmii_rx_clk}]


create_generated_clock -name {pll_inst_125M_0} -source [get_ports {clk_25}] -master_clock {clk_in} -multiply_by 5.000 [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[0]}]
create_generated_clock -name {pll_inst_125M_1} -source [get_ports {clk_25}] -master_clock {clk_in} -multiply_by 5.000 [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[1]}]
create_generated_clock -name {pll_inst_12p5M} -source [get_ports {clk_25}] -master_clock {clk_in} -divide_by 2.000 [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[2]}]
create_generated_clock -name {pll_inst_25M} -source [get_ports {clk_25}] -master_clock {clk_in} -divide_by 1.000 [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[3]}]
#create_generated_clock -name {clk_1_25_out} -source [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[2]}] -master_clock {pll_inst_12p5M} -divide_by 10.000 [get_nets {u_clk_gen/u_udp_clk_gen_1p25/div_reg3}]

create_generated_clock -name {udp_clk_125m} -add -source [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[1]}] -master_clock {pll_inst_125M_1} -divide_by 1.000 [get_nets {udp_clk}]
create_generated_clock -name {udp_clk_12p5m} -add -source [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[2]}] -master_clock {pll_inst_12p5M} -divide_by 1.000 [get_nets {udp_clk}]
create_generated_clock -name {udp_clk_1p25m} -add -source [get_pins {u_clk_gen/u_pll_0/pll_inst.clkc[2]}] -master_clock {pll_inst_12p5M} -divide_by 10.000 [get_nets {udp_clk}]
set_clock_groups -exclusive -group [get_clocks {udp_clk_125m}]
set_clock_groups -exclusive -group [get_clocks {udp_clk_12p5m}]
set_clock_groups -exclusive -group [get_clocks {udp_clk_1p25m}]


set_clock_groups -exclusive -group [get_clocks {phy1_rgmii_rx_clk}]














