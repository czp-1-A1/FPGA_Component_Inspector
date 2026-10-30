"""Isolate another exact display-math optimization; never edits production.

Store already weighted horizontal endpoints in existing capture cycles, reuse
one input tripler per channel, and use one subtract/absolute pair for Sobel.
No pixel, clock, FSM phase, threshold or interface is removed.
"""
from pathlib import Path
import hashlib,json,shutil
base=Path('D:/CodexWork/D3_Lossless_Synthesis_R28_20261030/project')
out=Path('D:/CodexWork/D3_Math_Source_R32_20261030');assert not out.exists();shutil.copytree(base,out/'project')
p=out/'project/user_source/hdl_source/rgb_resize_2_3.v';raw_resize=p.read_bytes();s=raw_resize.decode().replace('\r\n','\n')
s=s.replace('reg [95:0] first,second,pending_rgb,h_rgb;','reg [119:0] first,second;reg [95:0] pending_rgb,h_rgb;')
s=s.replace('wire [287:0] block_rgb={first,second,rgb};','''// Only the middle source pixel in each triple is a light-weight sample.
 // Endpoints are stored as exact 3*value in ten bits (maximum765).
 // All three capture phases share these twelve combinational triplers.
 wire [119:0] first_data,second_data,third_data;
 genvar wl,wc;
 generate for(wl=0;wl<4;wl=wl+1)begin : weighted_input
  for(wc=0;wc<3;wc=wc+1)begin : channel
   wire [7:0] v=rgb[95-wl*24-wc*8-:8];
   wire [9:0] triple={2'd0,v}+{1'd0,v,1'b0};
   assign first_data[119-wl*30-wc*10-:10]=wl==1 ? {2'd0,v} : triple;
   assign second_data[119-wl*30-wc*10-:10]=(wl==0 || wl==3) ? {2'd0,v} : triple;
   assign third_data[119-wl*30-wc*10-:10]=wl==2 ? {2'd0,v} : triple;
  end
 end endgenerate
 wire [359:0] block_rgb={first,second,third_data};''')
begin=s.index(' function [23:0] horizontal(');end=s.index('\n integer lane;',begin)
s=s[:begin]+''' function [23:0] horizontal(input [359:0] pixels,input integer index);
  integer heavy,light,c;reg [9:0] sum;
  begin
   heavy=(index/2)*3+(index%2==0 ? 0 : 2);light=(index/2)*3+1;
   for(c=0;c<3;c=c+1)begin
    sum=pixels[359-heavy*30-c*10-:10]+pixels[359-light*30-c*10-:10];
    horizontal[23-c*8-:8]=sum[9:2];
   end
  end
 endfunction''' +s[end:]
assert 'begin first<=rgb;input_phase<=1;' in s;s=s.replace('begin first<=rgb;input_phase<=1;','begin first<=first_data;input_phase<=1;')
assert 'begin second<=rgb;input_phase<=2;' in s;s=s.replace('begin second<=rgb;input_phase<=2;','begin second<=second_data;input_phase<=2;')
p.write_bytes(s.encode())
q=out/'project/user_source/hdl_source/roi_sobel_view.v';raw_sobel=q.read_bytes();s=raw_sobel.decode().replace('\r\n','\n')
old='''generate for(g=0;g<4;g=g+1) begin : gradients
 assign dx[g]=xp[g]>=xn[g] ? xp[g]-xn[g] : xn[g]-xp[g];
 assign dy[g]=yp[g]>=yn[g] ? yp[g]-yn[g] : yn[g]-yp[g];
end endgenerate'''
new='''// One full-width signed subtraction and magnitude conversion replaces a
// comparator and two subtractors. Full ten-bit operand domain is preserved.
function [9:0] abs_diff10;
 input [9:0] a,b;reg [10:0] delta;
 begin delta={1'b0,a}-{1'b0,b};abs_diff10=delta[10] ? (~delta[9:0])+10'd1 : delta[9:0];end
endfunction
generate for(g=0;g<4;g=g+1) begin : gradients
 assign dx[g]=abs_diff10(xp[g],xn[g]);
 assign dy[g]=abs_diff10(yp[g],yn[g]);
end endgenerate'''
assert old in s;s=s.replace(old,new);q.write_bytes(s.encode())
sha=lambda b:hashlib.sha256(b).hexdigest()
(out/'PROVENANCE.json').write_text(json.dumps({'base':str(base),'production_modified':False,'resize_before':sha(raw_resize),'resize_after':sha(p.read_bytes()),'sobel_before':sha(raw_sobel),'sobel_after':sha(q.read_bytes()),'scope':'Exact full-precision endpoint re-encoding in existing capture cycles and absolute difference. No extra cycle or removed mode/function.'},indent=2)+'\n')
print(out)
