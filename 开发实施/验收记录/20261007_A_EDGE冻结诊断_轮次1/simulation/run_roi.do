# Run run_modelsim.ps1 first. Load the real native RAW10/ISP/ROI integration.
onerror {abort}
vsim -L anlogic_sim -voptargs=+acc=rn+/tb_roi_chain -onfinish stop test_roi_chain.tb_roi_chain anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR
add wave -group native /tb_roi_chain/clk /tb_roi_chain/rst /tb_roi_chain/fs /tb_roi_chain/fe /tb_roi_chain/hs /tb_roi_chain/rv /tb_roi_chain/cfg /tb_roi_chain/raw
add wave -group statistics /tb_roi_chain/sv /tb_roi_chain/mean /tb_roi_chain/minimum /tb_roi_chain/maximum /tb_roi_chain/frame_no /tb_roi_chain/commits
run -all
wave zoom full
