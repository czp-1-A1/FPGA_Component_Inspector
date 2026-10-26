`timescale 1ns/1ps
module format_cache_pair #(parameter GAPS=0)(input wire clk,output reg done=0);
localparam DIAG_BITS=27;
reg  rst_n=0;
reg  vs=0;
reg  hs=0;
reg  de=0;
reg [23:0] rgb=0;
reg  page=0;
reg [15:0] exposure=0;
reg [15:0] gain=0;
reg [15:0] fps=0;
reg [15:0] width=0;
reg [15:0] height=0;
reg [7:0] wb_r=0;
reg [7:0] wb_b=0;
reg [7:0] roi_mean=0;
reg [7:0] roi_min=0;
reg [7:0] roi_max=0;
reg  wb_tune=0;
reg  wb_pending=0;
reg  roi_valid=0;
reg  cfg_done=0;
reg [1:0] view_mode=0;
reg [12:0] edge_count=0;
reg [15:0] lane_errors=0;
reg [15:0] format_errors=0;
reg [15:0] i2c_errors=0;
reg [15:0] gaps=0;
reg [15:0] overflow_frames=0;
reg [15:0] lost_frames=0;
reg [15:0] underflow_frames=0;
reg [31:0] frames=0;
reg [35:0] diagnostics=0;
reg [DIAG_BITS-1:0] publish_diagnostic=0;
reg [303:0] objects=0;
reg [127:0] calibration_record=0;
reg  calibration_valid=0;
reg [3:0] local_wait_reason=0;
reg [255:0] live_record=0;
reg [255:0] frame_record=0;
reg  eligible=0;
wire  out_vs_a,out_vs_b;
wire  out_hs_a,out_hs_b;
wire  out_de_a,out_de_b;
wire [23:0] out_rgb_a,out_rgb_b;
R16_previous_compact_inspector_osd #(.REPORT_NUMBER_GAPS(GAPS)) a(.clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.page(page),.exposure(exposure),.gain(gain),.fps(fps),.width(width),.height(height),.wb_r(wb_r),.wb_b(wb_b),.roi_mean(roi_mean),.roi_min(roi_min),.roi_max(roi_max),.wb_tune(wb_tune),.wb_pending(wb_pending),.roi_valid(roi_valid),.cfg_done(cfg_done),.view_mode(view_mode),.edge_count(edge_count),.lane_errors(lane_errors),.format_errors(format_errors),.i2c_errors(i2c_errors),.gaps(gaps),.overflow_frames(overflow_frames),.lost_frames(lost_frames),.underflow_frames(underflow_frames),.frames(frames),.diagnostics(diagnostics),.publish_diagnostic(publish_diagnostic),.objects(objects),.calibration_record(calibration_record),.calibration_valid(calibration_valid),.local_wait_reason(local_wait_reason),.live_record(live_record),.frame_record(frame_record),.eligible(eligible),.out_vs(out_vs_a),.out_hs(out_hs_a),.out_de(out_de_a),.out_rgb(out_rgb_a));
compact_inspector_osd #(.REPORT_NUMBER_GAPS(GAPS)) b(.clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.page(page),.exposure(exposure),.gain(gain),.fps(fps),.width(width),.height(height),.wb_r(wb_r),.wb_b(wb_b),.roi_mean(roi_mean),.roi_min(roi_min),.roi_max(roi_max),.wb_tune(wb_tune),.wb_pending(wb_pending),.roi_valid(roi_valid),.cfg_done(cfg_done),.view_mode(view_mode),.edge_count(edge_count),.lane_errors(lane_errors),.format_errors(format_errors),.i2c_errors(i2c_errors),.gaps(gaps),.overflow_frames(overflow_frames),.lost_frames(lost_frames),.underflow_frames(underflow_frames),.frames(frames),.diagnostics(diagnostics),.publish_diagnostic(publish_diagnostic),.objects(objects),.calibration_record(calibration_record),.calibration_valid(calibration_valid),.local_wait_reason(local_wait_reason),.live_record(live_record),.frame_record(frame_record),.eligible(eligible),.out_vs(out_vs_b),.out_hs(out_hs_b),.out_de(out_de_b),.out_rgb(out_rgb_b));
integer profile,row,x,i,pixels=0;integer values[0:31];reg [15:0] v;
function [19:0] decimal(input integer n);
 integer j,q;begin decimal=0;q=n;for(j=0;j<5;j=j+1)begin decimal[j*4+:4]=q%10;q=q/10;end end
endfunction
always @(posedge clk)begin
 #1;
 if(rst_n)begin
  if({out_vs_a,out_hs_a,out_de_a,out_rgb_a} !== {out_vs_b,out_hs_b,out_de_b,out_rgb_b})
   $fatal(1,"format cache pixel/control mismatch GAPS%0d profile%0d row%0d x%0d",GAPS,profile,row,x);
  if(out_de_b)pixels=pixels+1;
 end
end
task tick(input integer n);begin repeat(n)@(negedge clk);end endtask
task setup(input integer k);
 begin
  for(i=0;i<32;i=i+1)values[i]=0;
  live_record=0;frame_record=0;objects=0;calibration_record=0;
  exposure=0;gain=0;fps=0;width=0;height=0;wb_r=0;wb_b=0;
  roi_mean=0;roi_min=0;roi_max=0;edge_count=0;roi_valid=1;cfg_done=1;eligible=1;
  rgb=24'h123456;page=(k==1);wb_tune=0;wb_pending=0;
  if(k!=0)begin
   for(i=0;i<32;i=i+1)values[i]=511;
   values[4]=65535;values[14]=65535;values[15]=65535;values[16]=65535;
   values[17]=64;values[20]=GAPS ? 511 : 0;
   for(i=21;i<=25;i=i+1)values[i]=255;
   values[26]=127;values[27]=127;values[28]=8191;values[29]=65535;values[30]=65535;values[31]=8191;
   live_record[66:58]=511;live_record[75:67]=511;live_record[84:76]=511;live_record[93:85]=511;
   live_record[239:224]=65535;live_record[210:202]=511;live_record[222:217]=63;
   live_record[129:94]={36{1'b1}};live_record[201:130]={72{1'b1}};
   exposure=65535;gain=65535;fps=65535;width=65535;height=65535;
   wb_r=255;wb_b=255;roi_mean=255;roi_min=255;roi_max=255;edge_count=8191;
   objects[75:0]={1'b1,2'd2,4'd0,13'd8191,7'd127,7'd127,11'd550,11'd600,10'd300,10'd350};
  end else values[17]=1;
  live_record[47:32]=1;live_record[50:48]=2;live_record[55]=1;live_record[56]=1;live_record[57]=0;
  frame_record=live_record;
  if(k==2)begin roi_valid=0;values[23]=0;values[24]=0;values[25]=0;wb_pending=1;eligible=0;end
 end
endtask
initial begin
 tick(6);rst_n=1;tick(5);
 for(profile=0;profile<3;profile=profile+1)begin
  setup(profile);vs=1;tick(4);vs=0;tick(10);
  for(row=0;row<720;row=row+1)begin
   hs=1;tick(2);hs=0;de=1;
   for(x=0;x<1280;x=x+1)tick(1);
   de=0;tick(10);
   if(row==2)begin
    if(!a.ready || !b.ready)$fatal(1,"formatting did not finish before visible text");
    for(i=0;i<32;i=i+1)if(a.cache[i]!==decimal(values[i]) || b.cache[i]!==decimal(values[i]))
     $fatal(1,"numeric oracle mismatch GAPS%0d profile%0d slot%0d expected%h old%h new%h",GAPS,profile,i,decimal(values[i]),a.cache[i],b.cache[i]);
   end
  end
  tick(8);
 end
 if(pixels!=3*1280*720)$fatal(1,"pixel coverage %0d",pixels);
 $display("PASS format cache pair GAPS%0d pixels%0d all32 numeric slots zero/max/gating with16bit fields preserved",GAPS,pixels);
 done=1;
end
endmodule
module tb_format_cache_equivalence;
reg clk=0;always #5 clk=~clk;wire a,b;
format_cache_pair #(.GAPS(0)) production(clk,a);
format_cache_pair #(.GAPS(1)) legacy(clk,b);
initial begin wait(a && b);$display("PASS format cache equivalence: all20bit BCD values and full720p pixels same, both reporting parameters");$finish;end
initial begin #100000000;$fatal(1,"format cache timeout");end
endmodule
