import_device ph1_35p.db -package PH1P35MDG324 -speed 3
import_db camera_to_dsi_display_elaborate.db
puts "SCL [get_pins {*scl_clk*}]"
puts "NETS [get_nets -hier {*scl_clk*}]"
puts "CLK [get_pins {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]"
exit
