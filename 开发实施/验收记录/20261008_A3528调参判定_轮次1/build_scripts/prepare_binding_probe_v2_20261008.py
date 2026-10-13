from pathlib import Path
import re, json, hashlib
root=Path(__file__).resolve().parent.parent
build=root/'tmp/led_presence_demo_v2_td_20261008'
probe=build/'binding_probe'
assert not probe.exists()
probe.mkdir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
tb=(build/'sim/tb_display_state.v').read_text(encoding='utf-8')
tb=tb.replace('module tb_display_state;', 'module tb_profile_binding;')
tb=tb.replace(' ex=new_ex;ga=new_ga;wait_dest(2);', ' $display("OBS binding tuning ex=%d gain=%d enabled=%b",new_ex,new_ga,cal);\n ex=new_ex;ga=new_ga;wait_dest(2);')
sources={
 'v1':root/'tmp/led_presence_demo_v2_before_20261008/user_source/hdl_source/design_top_wrapper.v',
 'v2':build/'user_source/hdl_source/design_top_wrapper.v'}
expressions={}
for version,path in sources.items():
    raw=path.read_text(encoding='utf-8')
    matches=re.findall(r'\.calibration_ok\((CLASS_CALIBRATED[^\n]*?)\)',raw)
    assert len(matches)==2
    converted=[]
    for expression in matches:
        expression=expression.replace('CLASS_CALIBRATED','cal').replace('CLASS_EXPOSURE',"16'd2244").replace('CLASS_GAIN',"16'd48")
        for prefix in ['camera_receive','cam_display']:
            expression=expression.replace(prefix+'[48:33]','ex').replace(prefix+'[32:17]','ga')
        assert expression in ["cal && ex==16'd2244 && ga==16'd48",'cal']
        converted.append(expression)
    text=tb.replace('wire [1:0] source_state,dest_state;', 'wire capture_enabled='+converted[0]+';\nwire display_enabled='+converted[1]+';\nwire [1:0] source_state,dest_state;')
    text=text.replace('classifier(sclk,rst,cal,','classifier(sclk,rst,capture_enabled,')
    text=text.replace('snapshot(sclk,rst,fs,bad,cal,','snapshot(sclk,rst,fs,bad,capture_enabled,')
    text=text.replace('cfg,ex,ga,fps,cal,dr,','cfg,ex,ga,fps,display_enabled,dr,')
    dest=probe/('tb_profile_'+version+'.v')
    dest.write_text(text,encoding='utf-8')
    expressions[version]={'top_sha256':sha(path),'calibration_expressions':matches,'testbench_sha256':sha(dest)}
(probe/'expressions.json').write_text(json.dumps(expressions,indent=2)+'\n',encoding='utf-8')
print(json.dumps(expressions))
