"""Prepare TD runs using only files inside an independently frozen input tree."""
from pathlib import Path
import argparse,re

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('freeze',type=Path)
    ap.add_argument('--td',default='D:/td6.2.1')
    args=ap.parse_args()
    root=args.freeze.resolve()
    project=root/'td_project/camera_to_dsi_display.al'
    # TD uses XML-like tags containing :: and unescaped &; preserve that format.
    def relocate(match):
        rel=match[1]
        resolved=(project.parent/rel).resolve()
        assert resolved.is_relative_to(root),rel
        assert resolved.exists(),rel
        return '<File Path="../../'+rel+'"'
    prj=re.sub(r'<File Path="([^"]+)"',relocate,project.read_text())
    runs=root/'td_project/camera_to_dsi_display_Runs'
    shared='''set ADCList {"../../../user_source/constraints_source/pin.adc"}
set IpADCList { ddr2 ../../../user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc }
set IpSDCList { ddr2 ../../../user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc w128_d512_fifo ../../../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl }
set SDCList {"../../camera_to_dsi_display.sdc"}
set area_option -packarea
set device_name ph1_35p.db
set package_name PH1P35MDG324
set prj_name {camera_to_dsi_display}
set speed 3
set top_model_name {design_top_wrapper}
'''
    for run,settings in [('syn_1','set run_type syn\nset start_step read_design\nset end_step opt_gate\n'),
                         ('phy_1','set run_type phy\nset parent ../syn_1\nset arr_filter false\nset drHoldFix on\nset start_step opt_place\nset end_step bitgen\n')]:
        d=runs/run
        d.mkdir(parents=True,exist_ok=True)
        (d/'camera_to_dsi_display.prj').write_text(prj,encoding='utf-8')
        (d/'settings.cfg').write_text(shared+settings)
        (d/'build.tcl').write_text('source {'+args.td+'/scripts/DefaultFlow.tcl}\ncheck_timing -file constraint_coverage.txt -verbose\nexit\n')
    print(runs)

if __name__=='__main__':main()
