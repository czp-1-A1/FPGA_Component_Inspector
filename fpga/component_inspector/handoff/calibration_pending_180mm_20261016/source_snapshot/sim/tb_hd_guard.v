`timescale 1ns/1ps
module tb_hd_guard;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0,pv=0,sof=0,last=0;
always #5 clk=~clk;
wire [10:0] x,y;wire accept,commit,cancel;
integer commits=0,cancels=0,checks=0;
roi_frame_guard #(.WIDTH(1920),.HEIGHT(1080)) dut(
 .clk(clk),.rst_n(rst),.raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),
 .lane_error(2'd0),.config_ok(1'b1),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),
 .pixel_x(x),.pixel_y(y),.pixel_accept(accept),.frame_commit(commit),.invalidate(cancel));
always @(posedge clk)if(rst)begin
 if(commit)commits++;
 if(cancel)cancels++;
 if(accept)checks++;
end
task tick;begin @(negedge clk);end endtask
task frame(input integer short_row);
 begin
  fs=1;tick;fs=0;
  for(integer yy=0;yy<1080;yy++)begin
   hs=1;repeat(3)tick;
   for(integer xx=0;xx<(short_row && yy==1070 ? 1916 : 1920);xx+=4)begin
    rv=1;pv=1;sof=(yy==0 && xx==0);last=(xx==1916);
    tick;
   end
   rv=0;pv=0;sof=0;last=0;hs=0;repeat(20)tick;
  end
  fe=1;tick;fe=0;repeat(8)tick;
 end
endtask
initial begin
 repeat(10)tick;rst=1;repeat(4)tick;
 frame(0);
 if(commits!=1 || cancels!=0 || checks!=518400 || dut.raw_total!=2073600 || dut.processed_total!=2073600)
  $fatal(1,"FHD proof count/21-bit total failed commits=%0d cancel=%0d checks=%0d raw=%0d processed=%0d",commits,cancels,checks,dut.raw_total,dut.processed_total);
 frame(1);
 if(commits!=1 || cancels==0)$fatal(1,"short row beyond y=1023 accepted");
 frame(0);
 if(commits!=2)$fatal(1,"FHD guard did not recover");
 $display("PASS hd guard: 2073600 pixels/FHD y>=1024, exact native and processed proof, late short-row rejection and next-frame recovery");
 $finish;
end
initial begin #30000000;$fatal(1,"hd guard watchdog");end
endmodule
