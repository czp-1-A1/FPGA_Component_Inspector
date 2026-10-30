"""Remove the unreachable fourth RGB cache row; preserve four gray rows.

The existing overrun guard cancels every write that is three rows ahead of
read_y. RGB needs only read_y, so a three-row ring retains every usable beat.
Gray still needs read_y-1 and retains all four banks. No capacity/guard change.
"""
from pathlib import Path
import hashlib,json,re,shutil
r=Path(__file__).resolve().parents[1]
base=Path('E:/2026FPGA/.codex_tmp/d3_resize_share_source_r22_20261030/project')
out=Path('E:/2026FPGA/.codex_tmp/d3_rgb_ring_source_r27_20261030')
assert not out.exists();shutil.copytree(base,out/'project')
# Reject the font experiment: restore the fully tested original font renderer,
# keeping only winning-label sharing. All font assets and read cycles remain.
osd=out/'project/user_source/hdl_source/compact_inspector_osd.v'
osd.write_bytes(Path('E:/2026FPGA/.codex_tmp/d3_osd_share_source_r18_20261030/project/user_source/hdl_source/compact_inspector_osd.v').read_bytes())
p=out/'project/user_source/hdl_source/roi_sobel_view.v';raw=p.read_bytes();s=raw.decode().replace('\r\n','\n')
ref=r/'tests/dual_stop_d3/r11_reference_roi_sobel_view.sv';assert not ref.exists()
ref.write_bytes(re.sub(rb'\bprocess\b',b'reference_process_beat',raw.replace(b'module roi_sobel_view #',b'module r11_reference_roi_sobel_view #',1)))
s=s.replace('localparam RGB_WORDS=4*BEATS,RGB_BITS=$clog2(RGB_WORDS);','''// write_row >= read_y+3 already aborts before any valid read/output.
// Middle-row RGB therefore needs only three rows; top/mid/bottom gray keeps
// four rows because its oldest required row is read_y-1.
localparam RGB_WORDS=3*BEATS,RGB_BITS=$clog2(RGB_WORDS);
reg [1:0] rgb_write_bank,rgb_read_bank;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin rgb_write_bank<=0;rgb_read_bank<=0;end
 else if(early_sof || pixel_sof)begin rgb_write_bank<=0;rgb_read_bank<=0;end
 else begin
  if(input_valid && pixel_last)rgb_write_bank<=rgb_write_bank==2 ? 0 : rgb_write_bank+1'b1;
  if(read_issue && read_address==BEATS-1)rgb_read_bank<=rgb_read_bank==2 ? 0 : rgb_read_bank+1'b1;
 end
end''')
s=s.replace('rgb_write_address=write_row[1:0]*BEATS+write_address','rgb_write_address=(pixel_sof ? 2\'d0 : rgb_write_bank)*BEATS+write_address')
s=s.replace('rgb_read_address=read_y[1:0]*BEATS+read_address','rgb_read_address=rgb_read_bank*BEATS+read_address')
assert 'RGB_WORDS=3*BEATS' in s;p.write_bytes(s.encode())
(out/'PROVENANCE.json').write_text(json.dumps({'base':str(base),'font_experiment':'REJECTED: restore exact R18 OSD/font path.','before_sha256':hashlib.sha256(raw).hexdigest(),'after_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'reference':str(ref),'reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),'scope':'RGB only three rows. Four luminance rows, original overrun guard, schedule, modes, counters, gradients, abort and latencies retained.'},indent=2)+'\n')
print(out)
