from pathlib import Path
r=Path(__file__).resolve().parent.parent;sim=r/'fpga/component_inspector/sim'
p=sim/'tb_multi_pockets.v';s=p.read_text()
s=s.replace('check(records[62:61]==3 && records[147:146]==3 && records[232:231]==3 && records[317:316]==3,"all empty remains locatable");','''check(records[62:61]==3 && records[147:146]==3 && records[232:231]==3 && records[317:316]==3,"all empty remains locatable");
 frame(-48,364,3,2,0,1,7);frame(-48,364,3,2,0,1,7);
 check(mask==7,"exiting fourth pocket removed");
 frame(-48,364,6,2,0,1,7);frame(-48,364,6,2,0,1,15);
 check(mask==15,"new fourth pocket acquired only after fresh sampling");''')
p.write_text(s,encoding='utf-8')
s=(sim/'tb_isp_multi.v').read_text().replace('tb_isp_multi','tb_multi_writer')
s=s.replace('always #5 clk=~clk;', 'always #5 clk=~clk;reg dclk=0;always #3 dclk=~dclk;')
s=s.replace('reg [17:0] request=1;', '''reg [17:0] request=1;
wire [127:0] video;wire vv,vsof,view_ready,cap;wire [517:0] completed_meta;
video_in #(.METADATA(1),.META_WIDTH(518)) writer(
 .I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(vsof),.I_camera_valid(vv),.I_camera_data(video),.I_mipi_rx_error(1'b0),
 .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(view_ready),.I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),
 .I_active_valid(1'b0),.I_active_rp(2'd0),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),
 .O_completed_metadata(completed_meta),.O_capture_ok(cap));''')
s=s.replace('.O_tdata(),.O_tlast(),.O_tuser(),.O_tvalid(),.I_tready(),.view_ready(1\'b1)', '.O_tdata(video),.O_tlast(),.O_tuser(vsof),.O_tvalid(vv),.I_tready(),.view_ready(view_ready)')
s=s.replace('integer row,b,l,x,h,c,v,shift=', 'integer nrows=600;reg [517:0] saved_meta;integer row,b,l,x,h,c,v,shift=')
s=s.replace('row<600','row<nrows')
s=s.replace('  if(frame_no==1) begin','''  if(expected_lock==-1) begin
   if(!bad || good || completed_meta!==saved_meta || writer.published) $fatal(1,"short AUTO4 frame published old/fresh metadata");
   $display("OBS actual multi writer rejects short native frame");
  end else if(frame_no==1) begin''')
s=s.replace('  if(!mready || !good || bad)', '''  if(!cap || !writer.published || writer.writer_epoch!=frame_no || completed_meta!==meta) $fatal(1,"AUTO4 full frame/metadata writer did not publish atomically epoch=%0d frame=%0d",writer.writer_epoch,frame_no);
  if(!mready || !good || bad)''')
start=s.index(' frame(0,1,1,0,1); // Original')
end=s.index(' $display("PASS',start)
s=s[:start]+''' frame(0,1,1,0,1);frame(0,1,1,0,1);frame(0,1,1,1,1);
 frame(4,1,1,1,0);frame(0,1,1,1,2);frame(4,1,1,1,3);
 saved_meta=completed_meta;nrows=100;frame(4,1,1,-1,3);nrows=600;
 frame(4,1,1,0,1);frame(4,1,1,1,1);
''' +s[end:]
s=s.replace('PASS actual ISP multi:', 'PASS multi writer:').replace('RAW10/vendor RAM/full frames','RAW10/vendor RAM/full frames/518-bit metadata/actual writer/short rejection')
(sim/'tb_multi_writer.v').write_text(s,encoding='utf-8')
p=sim/'run_modelsim.ps1';s=p.read_text()
marker='        @{Name="multi_pockets";'
index=s.index(marker)
s=s[:index]+'''        @{Name="multi_writer"; Pass="PASS multi writer:"; Sources=($ispSources + @("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_multi_writer.v"))},
''' +s[index:]
s=s.replace('"isp_multi")) {','"isp_multi", "multi_writer")) {')
p.write_text(s,encoding='utf-8')
record=r/'开发实施/验收记录/20261012_B多穴动态标注_轮次1.md'
with record.open('a',encoding='utf-8') as f:
 f.write('\n第一批冻结211生产输入；六个生产输入变化，SDC、传输/写入模块等其余205输入未改。初版矩形孔fixture无法唯一确定纵向圆孔中心，纵向16px失锁要求失败；日志保留，预期未降低。补入圆形输入后245项单元断言PASS。新增最多四穴独立统计/共享Sobel、元数据518位/三周期OSD，四独立标签627072像素比对及元数据时序测试PASS。真实ISP、回归和TD构建仍在运行，尚未发布镜像。\n')
p=r/'AGENTS.md';s=p.read_text(encoding='utf-8')
s=s.replace('当前主线程唯一写入，未启动新仿真/构建。','当前主线程唯一写入。211生产输入/新增测试冻结tmp/multi_pocket_r1_td_20261012与r2；单元245断言、四中文标签627072像素比对及518位元数据时序PASS；r1实际ISP/TD物理、r2旧功能回归运行中，尚无新镜像。纵向矩形孔fixture失败记录保留，补圆孔输入后原失锁预期PASS；未降低要求。正在加补边界进出与真实AUTO4写入测试，生产RTL未继续改动。')
s=s.replace('无运行中新构建/代理、JTAG/Flash操作','当前TD session60878、r1 ISP session87996、r2回归session65356运行；无代理/JTAG/Flash操作')
p.write_text(s,encoding='utf-8')
print('Added pocket entry/exit and full actual AUTO4 writer tests; preserved prior failures')
