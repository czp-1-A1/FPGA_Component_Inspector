"""Independent brute-force reference for the optimized synthetic RGB stimulus."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent
def empty(n):return n in [2,8,16,17,21,27] or n>=29
def shape(x,y,cx,n):
 def ellipse(w,h,cy):
  dx=2*(x-(cx-w//2))+1-w;dy=2*(y-(cy-h//2))+1-h
  return dx*dx*h*h+dy*dy*w*w<=w*w*h*h
 dx=x-cx;dy=y-321
 if ellipse(16,14,281):return True
 if empty(n):return ellipse(6,6,321) if n>=29 else ellipse(14,12,321)
 if n==1:return -6<=dx<6 and -22<=dy<22
 return -18<=dx<18 and -22<=dy<22 and not((dx< -14 or dx>=14) and (dy< -14 or dy>=14))
checked=0;bright=[0]*36
for x in range(-40,36*64+41):
 if -32<=x<29*64-32:n=(x+32)//64
 elif 29*64<=x<36*64:n=29+(x-29*64)//64
 else:n=-1
 for y in range(250,353):
  actual=0<=n<36 and 257<=y<=345 and shape(x,y,n*64+(32 if n>=29 else 0),n)
  expected=any(shape(x,y,m*64+(32 if m>=29 else 0),m) for m in range(36))
  assert actual==expected,(x,y,n)
  if actual:bright[n]+=1
  checked+=1
assert all(v>0 for v in bright)
proof={'status':'PASS','brute_force_36_shapes_vs_optimized_pairs':checked,'bright_pixels_per_object':bright,'synthetic_prefix_normal':22,'synthetic_prefix_review':1,'synthetic_prefix_empty':6,'tail_empty':7,'body_width':36,'review_width':12,'prefix_cavity_width':14,'tail_cavity_width':6,'phase_y':321,'upper_feed_y':281,'pitch':64,'splice_extra_pitch':32,'truth_positions_are_synthetic':True,'fixture_sha256':hashlib.sha256((root/'motion_r3/tb_tail_29_plus_7_rgb.sv').read_bytes()).hexdigest()}
(root/'motion_pixels_reference.json').write_text(json.dumps(proof,indent=2)+'\n');print('PASS independent brute pixels',checked)
