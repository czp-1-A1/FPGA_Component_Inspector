from pathlib import Path
import subprocess,json,hashlib
root=Path(__file__).resolve().parent.parent
subprocess.run([__import__('sys').executable,str(root/'tmp/prepare_tracking_late_20261011.py'),'visual'],check=True)
build=root/'tmp/tracking_late_visual_td_20261011';tb=build/'sim/tb_tracking_osd.v'
before=tb.read_text(encoding='utf-8');s=before.replace('integer px,py;','integer px,py,ppm;')
s=s.replace(' n=n+1;',' $fwrite(ppm,"%d %d %d\\n",color[23:16],color[15:8],color[7:0]);\n n=n+1;')
s=s.replace('  checking=0;tv=0;tx0=472;tx1=552;','  frame_no=frame_no+1;ppm=$fopen($sformatf("tracking_%0d.ppm",frame_no),"w");$fwrite(ppm,"P3\\n1024 600\\n255\\n");\n  checking=0;tv=0;tx0=472;tx1=552;')
s=s.replace('$fatal(1,"tracking OSD raster incomplete");checking=0;','$fatal(1,"tracking OSD raster incomplete");checking=0;$fclose(ppm);')
tb.write_text(s,encoding='utf-8')
(build/'visual_notes.json').write_text(json.dumps(dict(kind='actual simulated OSD raster',not_a_hardware_photo=True,
 source_sha256=hashlib.sha256((root/'fpga/component_inspector/sim/tb_tracking_osd.v').read_bytes()).hexdigest(),modified_testbench_sha256=hashlib.sha256(tb.read_bytes()).hexdigest(),
 modification='PPM dumps only; all assertions preserved.'),indent=2)+'\n',encoding='utf-8')
