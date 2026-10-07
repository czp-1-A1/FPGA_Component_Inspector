from pathlib import Path

root=Path(__file__).resolve().parent
text=(root/'tb_edge_freeze_transport.v').read_text()
text=text.replace('module tb_edge_freeze_transport;', 'module tb_edge_freeze_mc;')
text=text.replace('wire wrbusy,', 'wire user_rdvalid;wire [127:0] user_rddata;\nwire wrbusy,')
text=text.replace('reg ready=1,rdvalid=0,vsync=0,rd_en=0;', 'wire ready;reg rdvalid=0,vsync=0,rd_en=0;')
text=text.replace('.I_ddr_user_rd_valid(rdvalid),.I_ddr_user_rd_data(rddata),', '.I_ddr_user_rd_valid(user_rdvalid),.I_ddr_user_rd_data(user_rddata),')
text=text.replace('reg [23:0] reference_pixels', r'''
wire mc_en,mc_we;
wire [24:0] mc_addr;
wire [2:0] mc_cmd;
wire [127:0] mc_data;
reg mc_app_ready=1,mc_wdf_ready=1;
integer mc_pause_cycles=0,mc_at_words=2400,mc_remaining=0,mc_stall_started=0;
integer mc_period=0,mc_off=0,mc_peak=0,mc_writes=0,mc_reads=0;
reg [154:0] accepted_commands[0:4095];
integer command_head=0,command_tail=0,mc_slot,mc_word;
mc_to_user_interface mcif(
 .I_clk(ddr),.I_rst_n(rst_n),.I_ddr_user_wr_en(wren),.I_ddr_user_rd_en(rden),
 .I_ddr_user_addr(wren ? wraddr : rdaddr),.I_ddr_user_wr_data(wrdata),
 .O_ddr_user_ready(ready),.O_ddr_user_rd_valid(user_rdvalid),.O_ddr_user_rd_data(user_rddata),
 .O_mc_app_en(mc_en),.O_mc_app_addr(mc_addr),.O_mc_app_cmd(mc_cmd),
 .I_mc_app_rdy(mc_app_ready),.O_mc_app_wdf_wren(mc_we),.O_mc_app_wdf_data(mc_data),
 .O_mc_app_wdf_end(),.O_mc_app_wdf_mask(),.I_mc_app_wdf_rdy(mc_wdf_ready),
 .I_mc_app_rd_data(rddata),.I_mc_app_rd_data_end(rdvalid),.I_mc_app_rd_data_valid(rdvalid));
reg [23:0] reference_pixels''')
text=text.replace('  memory[decoded_slot*WORDS+decoded_word]=wrdata;', '')
text=text.replace('  response_data[qtail%2048]=memory[decoded_slot*WORDS+decoded_word];\n  response_due[qtail%2048]=ddr_cycle+return_latency;\n  qtail=qtail+1;total_reads=total_reads+1;', '  total_reads=total_reads+1;')
text=text.replace(' if(vo.S_fifo_wr_num>display_peak)', r'''
 if(wren || rden) begin
  if(command_tail-command_head>=4095) $fatal(1,"Accepted command checker exceeded");
  accepted_commands[command_tail%4096]={wren,rden,wren ? wraddr : rdaddr,wrdata};
  command_tail=command_tail+1;
 end
 if(mc_en) begin
  if(command_head==command_tail) $fatal(1,"MC emitted a command never accepted at user port");
  if(mc_addr!==accepted_commands[command_head%4096][152:128] || mc_we!==accepted_commands[command_head%4096][154] || mc_cmd!==(accepted_commands[command_head%4096][153] ? 3'd1 : 3'd0))
   $fatal(1,"Real command FIFO changed command order/address/type head=%0d",command_head);
  if(mc_we && mc_data!==accepted_commands[command_head%4096][127:0]) $fatal(1,"Real command FIFO changed write data head=%0d",command_head);
  command_head=command_head+1;
  mc_slot=address_slot(mc_addr);mc_word=(mc_addr-slot_address(mc_slot))/8;
  if(mc_we) begin memory[mc_slot*WORDS+mc_word]=mc_data;mc_writes=mc_writes+1;end
  else begin
   if(qtail-qhead>=2047) $fatal(1,"MC response queue exceeded");
   response_data[qtail%2048]=memory[mc_slot*WORDS+mc_word];
   response_due[qtail%2048]=ddr_cycle+return_latency;
   qtail=qtail+1;mc_reads=mc_reads+1;
  end
 end
 if(mcif.U_w155_d512_fifo.full_flag) $fatal(1,"Real command FIFO overflowed");
 if(mcif.U_w155_d512_fifo.wrusedw>mc_peak) mc_peak=mcif.U_w155_d512_fifo.wrusedw;
 if(vo.S_fifo_wr_num>display_peak)''')
text=text.replace(' if(stall_left>0) begin ready=0;stall_left=stall_left-1;end\n else ready=1;', r'''
 if(capture_id==2 && !mc_stall_started && mc_pause_cycles>0 && capture_words>=mc_at_words) begin
  mc_stall_started=1;mc_remaining=mc_pause_cycles;
  $display("MC_PAUSE_START cycles=%0d packed=%0d queue_used=%0d",mc_pause_cycles,capture_words,mcif.U_w155_d512_fifo.wrusedw);
 end
 if(mc_remaining>0) begin mc_app_ready=0;mc_wdf_ready=0;mc_remaining=mc_remaining-1;end
 else if(mc_period>0 && ddr_cycle%mc_period<mc_off) begin mc_app_ready=0;mc_wdf_ready=0;end
 else begin mc_app_ready=1;mc_wdf_ready=1;end''')
text=text.replace(' if(!$value$plusargs("TRACE=%s",trace_name))', ' if(!$value$plusargs("MC_PAUSE=%d",mc_pause_cycles)) mc_pause_cycles=0;\n if(!$value$plusargs("MC_AT=%d",mc_at_words)) mc_at_words=2400;\n if(!$value$plusargs("MC_PERIOD=%d",mc_period)) mc_period=0;\n if(!$value$plusargs("MC_OFF=%d",mc_off)) mc_off=0;\n if(!$value$plusargs("TRACE=%s",trace_name))')
text=text.replace(' $fclose(trace_file);$finish;', ' $display("MC_DIAGNOSTIC real_command_fifo=1 peak=%0d accepted=%0d retired=%0d mc_writes=%0d mc_reads=%0d pause=%0d period=%0d off=%0d",mc_peak,command_tail,command_head,mc_writes,mc_reads,mc_pause_cycles,mc_period,mc_off);\n $fclose(trace_file);$finish;')
(root/'tb_edge_freeze_mc.v').write_text(text,encoding='ascii')
print('Prepared real MC adapter + w155 command FIFO probe')
