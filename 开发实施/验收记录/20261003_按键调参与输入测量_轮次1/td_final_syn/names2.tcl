import_device ph1_35p.db -package PH1P35MDG324 -speed 3
import_db camera_to_dsi_display_elaborate.db
puts "SCL [get_nets -hier -full_hier {scl_clk}]"
puts "REF [get_nets -hier -full_hier {S_24m_clk}]"
create_generated_clock -name camera_i2c_clk -source [get_pins {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}] -divide_by 240 [get_nets -hier -full_hier {scl_clk}]
exit
