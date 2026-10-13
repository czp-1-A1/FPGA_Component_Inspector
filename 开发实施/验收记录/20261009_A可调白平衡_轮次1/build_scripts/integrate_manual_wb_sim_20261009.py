from pathlib import Path
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
sim=project/'sim'

def replace(p,old,new,count=1):
    raw=p.read_bytes();old=old.encode('ascii');new=new.encode('ascii')
    nl=b'\n'
    if raw.count(old)!=count and b'\n' in old:
        old=old.replace(b'\n',b'\r\n');nl=b'\r\n'
    assert raw.count(old)==count,(p.name,old[:100],raw.count(old))
    p.write_bytes(raw.replace(old,new.replace(b'\n',nl)))

p=sim/'generate_osd_assets.py'
replace(p,"ANLOGICEXPGIMNFRCSTUYDVHW0123456789ABCDEF-+","ANLOGICEXPGIMNFRCSTUYDVHW0123456789ABCDEF-+K/*")
replace(p,' input wire [15:0] exposure,gain,',' input wire [15:0] exposure,gain,\n input wire [7:0] wb_r,wb_b,input wire wb_tune,wb_pending,')
replace(p,'reg [15:0] lane_s,format_s,','wire [19:0] wb_r_bcd,wb_b_bcd;\nbin16_bcd b8(clk,rst_n,start,{8\'d0,wb_r},wb_r_bcd);\nbin16_bcd b9(clk,rst_n,start,{8\'d0,wb_b},wb_b_bcd);\nreg wb_tune_s,wb_pending_s;\nreg [15:0] lane_s,format_s,')
replace(p,'  vs_d<=0;de_d<=0;x<=0;y<=0;sample_s<=0;cfg_s<=0;error_s<=0;','  vs_d<=0;de_d<=0;x<=0;y<=0;sample_s<=0;cfg_s<=0;error_s<=0;wb_tune_s<=0;wb_pending_s<=0;')
replace(p,'  if(start) begin\n   overflow_s<=','  if(start) begin\n   wb_tune_s<=wb_tune;wb_pending_s<=wb_pending;\n   overflow_s<=')
replace(p,"field(128,24,'ANLOGIC',scale=2)",'''field(128,24,'ANLOGIC',scale=2)
field(528,8,'WB LOCK',dynamic=["7'd87","7'd66","7'd32"]+
      [f"wb_tune_s ? 7'd{ord(a)} : 7'd{ord(b)}" for a,b in zip('TUNE','LOCK')])
field(528,32,'R 064 B 064',dynamic=["7'd82","7'd32"]+
      [f"7'd48+wb_r_bcd[{bit}+:4]" for bit in [8,4,0]]+
      ["7'd32","7'd66","7'd32"]+[f"7'd48+wb_b_bcd[{bit}+:4]" for bit in [8,4,0]])
field(528,56,'/64 *',dynamic=["7'd47","7'd54","7'd52","7'd32","wb_pending_s ? 7'd42 : 7'd32"])
''')
p=sim/'render_osd_reference.py'
replace(p,"text(128,24,'ANLOGIC',2)","text(128,24,'ANLOGIC',2)\ntext(528,8,'WB LOCK');text(528,32,'R 064 B 064');text(528,56,'/64')")
replace(p,'base=im.copy()','''base=im.copy()
for index,(r,b,tune,pending) in enumerate([(64,64,False,False),(96,32,True,False),(192,80,True,True)]):
 im=base.copy();d=ImageDraw.Draw(im);d.rectangle((528,8,639,71),fill=colors['bg'])
 text(528,8,'WB TUNE' if tune else 'WB LOCK');text(528,32,f'R {r:03d} B {b:03d}');text(528,56,'/64 *' if pending else '/64')
 im.save(a/f'wb_{index}.png')
 (a/f'wb_{index}.hex').write_text(''.join('%02x%02x%02x\\n'%rgb for rgb in im.getdata()),encoding='ascii')
''')
# Keep every legacy check, connect newly explicit configuration fields.
p=sim/'tb_controls.v'
replace(p,' (clk,rst,btn,aedone,camdone,req,ae,ag);', ' (.I_clk(clk),.I_rst(rst),.I_btn(btn),.I_ae_cfg_done(aedone),.I_cam_cfg_done(camdone),\n .O_ae_req(req),.O_ae(ae),.O_ag(ag),.O_wb_tune(),.O_wb_request());')
for name in ['tb_roi_chain.v','tb_isp_writer_stop.v']:
    p=sim/name
    replace(p,'isp_top dut(',"isp_top dut(.wb_request(32'h00004040),.wb_active(),")
    replace(p,'[82:0]','[114:0]')
p=sim/'tb_roi_chain.v'
replace(p,'if(observation_record!=={24\'(frame_mode',"if(observation_record!=={32'h00004040,24'(frame_mode")
p=sim/'tb_observation.v'
replace(p,'snapshot(rx_clk,rst,invalid,tag,legacy,cp,ec,strength,source_record);',"snapshot(rx_clk,rst,invalid,tag,32'h00004040,legacy,cp,ec,strength,source_record);")
replace(p,'[82:0]','[114:0]')
replace(p,'.WIDTH(83)', '.WIDTH(115)')
replace(p,'gate(dclk,rst,cfg,ex,ga,fps,1\'b0,gated_record,displayed,valid,state);',"gate(dclk,rst,cfg,ex,ga,fps,1'b0,gated_record,displayed,32'h00004040,valid,state);")
for name in ['tb_display_state.v','tb_stop_recovery.v']:
    p=sim/name
    replace(p,"dr,18'd0,valid", "dr,18'd0,32'h00004040,valid")
p=sim/'tb_osd.v'
replace(p,'.exposure(ex),.gain(ga),',".wb_r(8'd64),.wb_b(8'd64),.wb_tune(1'b0),.wb_pending(1'b0),.exposure(ex),.gain(ga),",count=2)
print('PASS manual WB OSD generator and explicit legacy test connections updated')
