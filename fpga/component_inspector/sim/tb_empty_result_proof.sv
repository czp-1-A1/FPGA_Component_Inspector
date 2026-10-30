`timescale 1ns/1ps
// Exercise the actual ISP/count join with controlled detector/proof ordering.
// Force only producer boundaries; the production join/counters/metadata run.
module tb_empty_result_proof;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,early=0,proof=0,cancel=0,bad=0,sn=0,sready=0;
 reg [16:0] command=0;reg [63:0] config_tag=64'h0444002800006464;
 wire [511:0] live;wire [1142:0] metadata;wire metadata_ready;
 wire [1:0] event_valid;
 isp_top #(.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.LOCAL_RECOVERY(1),.MULTITHRESHOLD_EMPTY(1),.CLASSIFIED_COUNT(1),.RESULT_RECORDER(1),.INPUT_WIDTH(1920),.INPUT_HEIGHT(1080),.WIDTH(1280),.HEIGHT(720),.SCALE_DISPLAY(1),.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1),.REGIONS(1),.CALIBRATION(1)) dut(
  .count_command(command),.count_live(live),.count_event_valid(event_valid),
  .processing_clk(clk),.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(1'b0),.I_tuser(1'b0),.I_tdata(40'd0),.I_tvalid(1'b0),.I_tdest(10'd0),.O_tready(1'b1),.view_ready(1'b1),
  .raw_start(1'b0),.raw_end(1'b0),.hs_valid(1'b0),.raw_valid(1'b0),.config_ok(1'b1),.lane_error(2'd0),
  .calibration_ok(1'b1),.present_high(1'b1),.threshold(8'd58),.observation_request(18'd1),.wb_request(32'h00006464),.image_config(32'h04440028),
  .frame_metadata(metadata),.frame_metadata_ready(metadata_ready));
 integer checks=0,seq=0,accepts=0,k,offset;
 initial begin
  force dut.post_start=fs;force dut.post_early=early;force dut.post_commit=proof;
  force dut.sample_cancel=cancel;force dut.video_frame_bad=bad;
  force dut.search_new=sn;force dut.search_ready=sready;
  force dut.recorder_candidates=608'd0;force dut.post_config=config_tag[63:32];force dut.post_wb=config_tag[31:0];
  force dut.post_accept=1'b0;
 end
 always @(posedge clk)if(rst)begin
  if(dut.classified_counting.dual_regions.pipeline.regions[0].pipeline.accept)accepts=accepts+1;
  if(event_valid!=0)$fatal(1,"empty input fabricated count event");
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task check(input logic ok,input string message);
  begin checks++;if(ok!==1'b1)$fatal(1,"%s seq=%0d offset=%0d accepts=%0d live=%h",message,seq,offset,accepts,live);end
 endtask
 task restart;
  begin seq++;command=seq*2;ticks(100);accepts=0;end
 endtask
 task start_source;
  begin fs=1;sn=0;sready=0;proof=0;cancel=0;bad=0;ticks(1);fs=0;early=1;ticks(1);early=0;ticks(2);end
 endtask
 task result;
  begin sn=1;sready=1;ticks(1);sn=0;end
 endtask
 task commit;
  begin proof=1;ticks(1);proof=0;end
 endtask
 task no_result;
  begin ticks(200);check(accepts==0 && !metadata_ready,"unproved or revoked result escaped");end
 endtask
 task valid_result;
  begin
   ticks(250);check(accepts==1 && metadata_ready,"proved empty result must publish exactly once");
   check(metadata[854] && metadata[1110] && metadata[662:631]==metadata[918:887],"dual marker/source binding");
   check(metadata[678:663]==seq && metadata[934:919]==seq,"dual run binding");
   check(live[50:48]==1 && live[306:304]==1,"empty source must remain LOCKING");
   check(live[93:58]==0 && live[349:314]==0,"empty source changed statistics");
   ticks(50);check(accepts==1,"held ready repeated sample");
   start_source();ticks(100);check(live[50:48]!=3 && live[306:304]!=3,"complete empty source caused next-FS C6");
  end
 endtask
 initial begin
  ticks(8);rst=1;ticks(4);
  for(offset=-12;offset<=12;offset++)begin
   restart();start_source();
   if(offset<0)begin result();ticks(-offset);check(accepts==0,"early result consumed before proof");commit();end
   else if(offset==0)begin sn=1;sready=1;proof=1;ticks(1);sn=0;proof=0;end
   else begin commit();ticks(offset);result();end
   valid_result();
  end
  // Cancellation and a genuine bad frame revoke an early result.
  restart();start_source();result();cancel=1;ticks(1);cancel=0;sready=0;commit();no_result();
  restart();start_source();result();bad=1;ticks(2);sready=0;commit();no_result();
  check(live[50:48]==3 && live[54:51]==6,"real bad frame protection removed");
  // A new source never borrows the old source's early result.
  restart();start_source();result();start_source();commit();no_result();
  start_source();ticks(100);check(live[50:48]==3 && live[54:51]==6,"missing new-source result must remain C6");
  // Restart between early result and proof cannot publish the old result.
  restart();start_source();result();restart();commit();no_result();
  start_source();commit();result();valid_result();
  // No proof: no counting/publication, and the next FS remains a fault.
  restart();start_source();result();no_result();start_source();ticks(100);
  check(live[50:48]==3 && live[54:51]==6,"missing proof must remain C6");
  $display("PASS EMPTY_RESULT_PROOF: %0d checks; actual ISP, 25 proof/result orders, same-edge, single delivery, dual empty LOCKING, cancel, bad frame, FS and restart exclusion, genuine missing-proof/result C6",checks);$finish;
 end
 initial begin #5000000;$fatal(1,"empty proof watchdog");end
endmodule
