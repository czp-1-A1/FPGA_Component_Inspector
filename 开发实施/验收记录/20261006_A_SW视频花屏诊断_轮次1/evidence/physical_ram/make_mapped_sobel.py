from pathlib import Path
import re, hashlib, json
out=Path(__file__).resolve().parent
root=out.parents[1]
hdl=root/'fpga/component_inspector/user_source/hdl_source'
source=hdl/'roi_sobel_view.v'
text=source.read_text()
a=text.index('genvar bank;')
b=text.index('end endgenerate',a)+len('end endgenerate')
text=text[:a]+'''wire [3:0] bank_enable;
genvar bank;
generate for(bank=0;bank<4;bank=bank+1) begin : mapped_enable
 assign bank_enable[bank]=rst_n && pixel_valid && write_row[1:0]==bank;
end endgenerate
mapped_rgb_ram physical_lines(.clk(clk),.bank_enable(bank_enable),
 .write_address(write_address),.read_address(read_address),.rgb(rgb),.row_q(row_q));
'''+text[b:]
(out/'roi_sobel_view_mapped.v').write_text(text)
tb=root/'fpga/component_inspector/sim/tb_sobel_view.v'
text=tb.read_text().replace('initial begin\n ticks(4);','initial begin\n #10000;\n ticks(4);')
(out/'tb_sobel_view.v').write_text(text)
(out/'mapped_sobel_manifest.json').write_text(json.dumps({'original_sobel_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'original_tb_sha256':hashlib.sha256(tb.read_bytes()).hexdigest(),'changes':'diagnostic copy only: replace inferred line arrays with exact synthesized physical ERAM connections; delay TB start 10us for global GSR'},indent=2))
