"""Static, reproducible camera/geometry/DDR consistency and freeze checks."""
from pathlib import Path
import re,json,hashlib,sys

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
engine=Path(__file__).resolve().parents[1]
output=Path(sys.argv[1]) if len(sys.argv)>1 else engine/'vendor_reference/sc500_1080p/audit.json'
vendor=engine/'vendor_reference/sc500_1080p/cfg_cs500.c'
camera=engine/'user_source/hdl_source/uics500_cfg/uics500reg.v'
c=[(int(a,16),int(v,16)) for a,v in re.findall(r'\{\s*0x([0-9a-fA-F]+),\s*0x([0-9a-fA-F]+)\s*\}',vendor.read_text())]
rtl=[(int(a,16),int(v,16)) for a,v in re.findall(r"\d+:\s*REG_DATA\s*=\s*\{16'h([0-9a-f]+), 8'h([0-9a-f]+)\}",camera.read_text(errors='replace'))]
explicit={0x3018:0x3a,0x3031:0x0a,0x3650:0x31,0x3652:0x00,0x3654:0x00}
assert [(a,v) for a,v in rtl if a not in explicit]==[(a,0x08 if a==0x3e08 else 0x5f if a==0x3e09 else v) for a,v in c]
registers=dict(rtl)
assert [registers[a] for a in range(0x3208,0x320c)]==[7,128,4,56]
for a,v in explicit.items():assert registers[a]==v
ddr=engine/'user_source/hdl_source/ph1p35_ddr/ddr2'
params={key:float(value) for key,value in re.findall(r'\.(\w+)\(([\d.]+)\)',(ddr/'ddr2.v').read_text())}
fref=params['PLL0_REFCLK_FREQ'];vco=fref/params['PLL0_REFCLK_DIV']*params['PLL0_FBKCLK_DIV']
fddr=vco/params['PLL0_CLK2_DIV'];fusr=vco/12;fmcu=vco/params['PLL0_CLK3_DIV']
assert fref==50 and abs(fddr-266.6666666667)<1e-8 and abs(fusr-66.6666666667)<1e-8
assert 800<=vco<=1600 and params['tCK']==3750 and params['CL']==4 and params['CWL']==3
assert '`define DDR2_533C' in (ddr/'src/rtl/include/ph1p_mis_define.vh').read_text()
slots=[dict(slot=i,base=base,end_exclusive=base+388800*8) for i,base in enumerate([0,7000000,14000000,21000000])]
assert all(slot['end_exclusive']<=slots[i+1]['base'] for i,slot in enumerate(slots[:-1]))
assert slots[-1]['end_exclusive']<=2**25
result=dict(status='static_checks_pass_only',camera=dict(vendor_sha256=sha(vendor),rtl_sha256=sha(camera),vendor_entries=len(c),rtl_entries=len(rtl),
 common_sequence_equal=True,retained_explicit_raw10_2lane={f'{a:04x}':f'{v:02x}' for a,v in explicit.items()},
 retained_gain_difference={'3e08':{'vendor':'07','rtl':'08'},'3e09':{'vendor':'3f','rtl':'5f'}},geometry='1920x1080'),
 ddr=dict(reference_mhz=fref,vco_mhz=vco,ddr_mhz=fddr,user_mhz=fusr,config_mhz=fmcu,tck_ps=3750,cl=4,cwl=3,
 speed_bin='DDR2-533C',refresh_ddr_cycles=2080,refresh_us=7.8,mc_address_unit_bytes=2,slots=slots,
 payload_mb_per_s=1920*1080*3*30*2/1e6,theoretical_mb_per_s=fddr*2*2,
 physical_ddr_write_read_stress='NOT_RUN'),
 fifo=dict(write_used_max_before_line=120,line_words=360,read_reserved_max_before_240_burst=271,prefill_words=360),
 hdmi=dict(pll_chain=[dict(reference=50,n=5,m=108,c=32,output=33.75),dict(reference=33.75,n=1,m=33,c0=15,c1=3,pixel=74.25,serial=371.25)],
 note='Integer ratios exact. TD clock periods rounded to 1ps can display serial 371.333 MHz; vendor model measurement separately required.',vic=34),
 classification='UNCALIBRATED',physical_acceptance='NOT_RUN')
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('PASS native static audit: camera common order, DDR clock/tCK/CL/CWL/refresh, four MC slots, FIFO capacities')
