"""Exhaust the fixed-zone coordinate domain used by narrowed retained distances."""
from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1]
p=r/'fpga/component_inspector/user_source/hdl_source/frame_shape_search.v'
text=p.read_text()
assert 'DIST_BITS=DUAL_STOP && REGIONS && WIDTH==1280 && HEIGHT==720 ? 9 : 12' in text
assert text.count('reg [DIST_BITS-1:0]')==3
assert 'reg [11:0] distance;' in text
regions=[(400,880,240,400),(400,880,432,600),(64,400,240,400),(64,400,432,600)]
proof=[]
for x0,x1,y0,y1 in regions:
    tx=(x0+x1)//2;ty=(y0+y1)//2
    maximum=0;checked=0
    for y in range(y0,y1):
        for x in range(x0,x1):
            d=abs(x-tx)+abs(y-ty)
            assert d==d&511
            maximum=max(maximum,d);checked+=1
    proof.append({'bounds':[x0,x1,y0,y1],'max_distance':maximum,'coordinates_checked':checked})
assert max(x['max_distance'] for x in proof)==324
out={'status':'PASS_FIXED_ZONE_RETAINED_DISTANCE_BOUND','source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
     'valid_distance_bits':9,'transient_distance_bits':12,'zones':proof,
     'invalid_entries':'Distance reset truncates to 511; found/high_valid/row_anchor_valid mask invalid values before use.',
     'scope':'Only fixed 1280x720 DUAL_STOP/REGIONS; all other configurations keep original 12 bits. RGB equivalence is separate.'}
(r/'docs/D3_DISTANCE_BOUNDS.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
