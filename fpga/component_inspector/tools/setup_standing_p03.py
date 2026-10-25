"""Declared one-time P02-to-P03 changes in an isolated source copy."""
from pathlib import Path

P=Path(__file__).resolve().parents[1]
edits={
 'user_source/hdl_source/present_surface_check.v':[
  ('reg [10:0] sum;reg [4:0] center_mean,min_edge;',
   'reg [10:0] sum;reg [4:0] center_mean,min_edge;\nreg [10:0] center_total;reg [9:0] max_edge_total;'),
  ('wire [6:0] center4={center_mean,2\'b0};',
   'wire [6:0] center4={center_mean,2\'b0};\nwire [9:0] next_max=next_sum[9:0]>max_edge_total ? next_sum[9:0] : max_edge_total;\n// Compare unrounded regional sums: center64 versus twice each edge32.\n//16 center-sum units allow2 equivalent gray levels, without losing a full5-bit bin.\nwire [10:0] center_limit=center_total+11\'d16;'),
  ('phase<=0;feature<=0;sample<=0;byte_index<=0;sum<=0;center_mean<=0;min_edge<=31;',
   'phase<=0;feature<=0;sample<=0;byte_index<=0;sum<=0;center_mean<=0;min_edge<=31;center_total<=0;max_edge_total<=0;'),
  ('phase<=measurable ? 2 : 0;feature<=0;sample<=0;sum<=0;center_mean<=0;min_edge<=31;',
   'phase<=measurable ? 2 : 0;feature<=0;sample<=0;sum<=0;center_mean<=0;min_edge<=31;center_total<=0;max_edge_total<=0;'),
  ('if(feature==0)center_mean<=mean;else min_edge<=next_min;',
   'if(feature==0)begin center_mean<=mean;center_total<=next_sum;end\n     else begin min_edge<=next_min;max_edge_total<=next_max;end'),
  ('normal<=center_mean>=((FOREGROUND+7)/8) && edge5>={1\'b0,center4};',
   'normal<=center_mean>=((FOREGROUND+7)/8) && edge5>={1\'b0,center4} && {next_max,1\'b0}<=center_limit;'),
 ],
 'user_source/hdl_source/compact_template_rom.v':[
  ('memory[9]=REVIEW_PROBE ? 10\'h032 : 10\'h033;', 'memory[9]=REVIEW_PROBE ? 10\'h033 : 10\'h033;'),
  ('memory[1032]=REVIEW_PROBE ? 10\'h032 : 10\'h033;', 'memory[1032]=REVIEW_PROBE ? 10\'h033 : 10\'h033;'),
 ],
}
if __name__=='__main__':
 for name,changes in edits.items():
  path=P/name;text=path.read_text(encoding='utf-8-sig')
  for old,new in changes:
   assert text.count(old)==1,(name,old,text.count(old));text=text.replace(old,new,1)
  path.write_text(text,encoding='utf-8')
 print('P03 standing guard added to one module; P03 title only; cache geometry/RAM unchanged')
