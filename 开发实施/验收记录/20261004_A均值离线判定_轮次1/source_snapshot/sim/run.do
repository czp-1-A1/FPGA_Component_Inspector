# GUI entry: first run run_modelsim.ps1, then open ModelSim in this sim directory.
# Uses the original vendor ERAM model compiled by that script, not awb_ram_model.v.
onerror {abort}
# Default reproduces original RTL. For the explicit diagnostic, first run the
# PowerShell runner with -TieUnusedAwbRamInputs, then: set awb_ram_diagnostic 1
if {![info exists awb_ram_diagnostic]} {set awb_ram_diagnostic 0}
set pixel_library test_pixel_interface
if {$awb_ram_diagnostic} {
    set pixel_library test_pixel_interface_tied_inputs
    puts "DIAGNOSTIC: forcing unused AWB RAM inputs to zero; not original RTL acceptance"
}
vsim -L anlogic_sim -voptargs=+acc -onfinish stop ${pixel_library}.tb_pixel_interface anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR
add wave -group input /tb_pixel_interface/clk /tb_pixel_interface/rst /tb_pixel_interface/sof /tb_pixel_interface/eol /tb_pixel_interface/valid /tb_pixel_interface/rgb128
add wave -group awb /tb_pixel_interface/out_sof /tb_pixel_interface/out_eol /tb_pixel_interface/out_valid /tb_pixel_interface/out_data /tb_pixel_interface/ready
add wave -group packing /tb_pixel_interface/packed_sof /tb_pixel_interface/packed_valid /tb_pixel_interface/packed_data
run -all
wave zoom full
