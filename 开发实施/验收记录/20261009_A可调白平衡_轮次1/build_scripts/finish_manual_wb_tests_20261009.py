from pathlib import Path
root=Path(__file__).resolve().parent.parent
sim=root/'fpga/component_inspector/sim'
def patch(p,old,new,n=1):
 raw=p.read_bytes();o=old.encode('ascii');nl=b'\n'
 if raw.count(o)!=n and b'\n' in o:o=o.replace(b'\n',b'\r\n');nl=b'\r\n'
 assert raw.count(o)==n,(p.name,old[:80],raw.count(o))
 p.write_bytes(raw.replace(o,new.encode('ascii').replace(b'\n',nl)))
p=sim/'tb_roi_chain.v'
patch(p,'reg [17:0] request=1;',"reg [17:0] request=1;reg [31:0] wb_request=32'h00004040;")
patch(p,".wb_request(32'h00004040)",'.wb_request(wb_request)')
patch(p,'   if(mode==3 && row==200 && b==100) request=request+18\'d5;',"   if(mode==3 && row==200 && b==100) request=request+18'd5;\n   if(mode==4 && row==200 && b==100) wb_request=32'h00016020;")
patch(p,"if(observation_record!=={32'h00004040,",'if(observation_record!=={wb_request,')
patch(p,' $display("PASS actual ROI chain:', ''' request=18'd34;frame(4,0);
 if(sv || display_record[24] || observation_record[24] || dut.video_frame_bad || output_beat!=153600 || packed_beats!=115200)
  $fatal(1,"WB change retained old sample or interrupted full video");
 if(dut.wb_active!==32'h00004040)$fatal(1,"WB changed within native frame");
 frame(0,0);expect_good;
 if(dut.wb_active!==wb_request)$fatal(1,"WB request not applied on fresh complete frame");
 $display("PASS actual ROI chain:''')
patch(p,'real demosaic/AWB/vendor RAM, independent stats, ready-low, malformed/replay rejection and recovery', 'real demosaic/AWB/vendor RAM, independent stats, ready-low, malformed/replay rejection, WB mid-frame sample invalidation without video loss and recovery')
p=sim/'tb_osd.v'
patch(p,'reg [1:0] class_state=0;',"reg [1:0] class_state=0;reg [7:0] wb_r=64,wb_b=64;reg wb_tune=0,wb_pending=0;")
patch(p,".wb_r(8'd64),.wb_b(8'd64),.wb_tune(1'b0),.wb_pending(1'b0)",'.wb_r(wb_r),.wb_b(wb_b),.wb_tune(wb_tune),.wb_pending(wb_pending)',n=2)
patch(p,'task check_state;', '''task check_wb;input integer index;input [7:0] r,b;input tune,pending;
begin
 view=0;sv=1;cfg=1;rate=30;class_state=0;ex=1460;ga=48;diagnostics=36'h1_0280_0123;
 wb_r=r;wb_b=b;wb_tune=tune;wb_pending=pending;frame_start;
 if(dut.wb_r_bcd[11:0]!=={4'(r/100),4'((r/10)%10),4'(r%10)} ||
    dut.wb_b_bcd[11:0]!=={4'(b/100),4'((b/10)%10),4'(b%10)})$fatal(1,"WB decimal coefficients");
 wb_r=32;wb_b=192;wb_tune=!tune;wb_pending=!pending;
 $readmemh($sformatf("osd_assets/wb_%0d.hex",index),reference);
 n=0;f=$fopen($sformatf("osd_wb_%0d.ppm",index),"w");$fwrite(f,"P3\\n1024 600\\n255\\n");
 for(y=0;y<600;y=y+1)begin
  de=1;hs=1;for(x=0;x<1024;x=x+1)@(negedge clk);
  de=0;hs=0;repeat(20)@(negedge clk);
 end
 repeat(4)@(negedge clk);$fclose(f);f=0;
 if(n!=614400)$fatal(1,"WB raster coverage");
end endtask
task check_state;''')
patch(p,' check_mode(0);check_mode(1);check_mode(2);check_mode(3);',' check_mode(0);check_mode(1);check_mode(2);check_mode(3);\n check_wb(0,64,64,0,0);check_wb(1,96,32,1,0);check_wb(2,192,80,1,1);')
patch(p,'maximum values and frame snapshot','maximum values, WB actual coefficients/TUNE/LOCK/pending and frame snapshot')
p=sim/'run_modelsim.ps1'
patch(p,'    $tests = @(\n', '''    $tests = @(
        @{Name="wb_controls"; Pass="PASS WB controls:"; Sources=@("$hdl/uiisp_beta/ae_set.v", "tb_wb_controls.v")},
        @{Name="manual_wb"; Pass="PASS manual WB:"; Sources=@("$hdl/awb.v", "$hdl/signal_delay.v", "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v", "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v", "tb_manual_wb.v")},
        @{Name="wb_epoch"; Pass="PASS WB epoch:"; Sources=@("$hdl/status_cdc.v", "$hdl/roi_observation_snapshot.v", "$hdl/roi_display_state.v", "tb_wb_epoch.v")},
''')
patch(p,'@("fixed_wb", "pixel_interface", "roi_chain", "isp_writer_stop")','@("fixed_wb", "manual_wb", "pixel_interface", "roi_chain", "isp_writer_stop")')
print('PASS added independent color/control/CDC cases, full ISP WB transition and OSD raster checks')
