from pathlib import Path
import hashlib, json, shutil

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
record = root / '开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1'
unit = root / 'tmp/hole_transition_unit_r1_20261012'
rel = Path('user_source/hdl_source/tape_hole_tracker.v')
p = project / rel
before = (record / 'before' / rel).read_bytes()
assert p.read_bytes() == before
new = before
replacements = [
    ('reg [3:0] dark_count;', 'reg [3:0] dark_count;\n// At most two decimated samples (8 pixels) of MID on either boundary.\nreg [1:0] transition_count;\nreg left_margin;'),
    ('previous_center<=0;dark_count<=0;best_distance<=2047;', 'previous_center<=0;dark_count<=0;transition_count<=0;left_margin<=0;best_distance<=2047;'),
    ('paired<=0;ambiguous<=0;dark_count<=0;best_distance<=2047;', 'paired<=0;ambiguous<=0;dark_count<=0;transition_count<=0;left_margin<=0;best_distance<=2047;'),
    ('dark_count<=0;pending<=0;\n   if(!running) begin first<=x;left_ok<=dark_count>=2;end', 'dark_count<=0;pending<=0;transition_count<=0;left_margin<=0;\n   if(!running) begin first<=x;left_ok<=dark_count>=2 || (left_margin && transition_count<=2);end'),
    ('''   if(gray<=DARK) begin
    if(dark_count!=15) dark_count<=dark_count+1'b1;
   end else begin dark_count<=0;pending<=0;end
   if(running) begin
    pending<=left_ok && run_width>=MIN_WIDTH && run_width<=MAX_WIDTH && gray<=DARK;
    pending_center<=midpoint[11:1];pending_width<=run_width[6:0];
   end else if(pending && gray<=DARK && dark_count>=1) begin''', '''   if(gray<=DARK) begin
    transition_count<=0;left_margin<=0;
    if(dark_count!=15) dark_count<=dark_count+1'b1;
   end else begin
    dark_count<=0;
    if(transition_count!=3) transition_count<=transition_count+1'b1;
    if(running || pending) left_margin<=0;
    else if(dark_count>=2) left_margin<=1;
    else if(transition_count>=2) left_margin<=0;
    // MID after a partial right dark margin breaks its continuity.
    if(transition_count>=2 || dark_count!=0) pending<=0;
   end
   if(running) begin
    pending<=left_ok && run_width>=MIN_WIDTH && run_width<=MAX_WIDTH;
    pending_center<=midpoint[11:1];pending_width<=run_width[6:0];
   end else if(pending && gray<=DARK && dark_count>=1) begin''')
]
for a,b in replacements:
    newline='\r\n' if b'\r\n' in before else '\n'
    a=a.replace('\n',newline).encode('ascii')
    b=b.replace('\n',newline).encode('ascii')
    assert new.count(a)==1, a
    new=new.replace(a,b)
assert new.split(b'endmodule',1)[1] == before.split(b'endmodule',1)[1]
p.write_bytes(new)
shutil.copy2(p, unit / 'tape_hole_tracker.v')
sha = lambda data: hashlib.sha256(data).hexdigest()
(record / 'changes.json').write_text(json.dumps([dict(path=rel.as_posix(),before_sha256=sha(before),after_sha256=sha(new))],indent=2)+'\n',encoding='utf-8')
(unit / 'source_inputs.json').write_text(json.dumps([dict(path=f.name,bytes=f.stat().st_size,sha256=sha(f.read_bytes())) for f in unit.iterdir() if f.is_file()],indent=2)+'\n',encoding='utf-8')
print('Only hole_scanline changed; downstream modules byte-identical.')
