`timescale 1ns/1ps
module tb_hd_monitor;
reg rx=0,refclk=0,rst=0,fs=0,fe=0,hs=0,valid=0;
reg [1:0] lane=0;
always #5 rx=~rx;
always #7 refclk=~refclk;
wire [15:0] w,h,le,err,fps,gap;
wire [31:0] uptime,frames;
input_monitor #(.REF_HZ(200000),.EXPECTED_WIDTH(1920),.EXPECTED_HEIGHT(1080)) dut(
 rx,refclk,rst,fs,fe,hs,valid,lane,w,h,le,err,fps,gap,uptime,frames);
integer checks=0;
task ticks;input integer n;begin repeat(n) @(negedge rx);end endtask
task pulse_start;begin fs=1;ticks(1);fs=0;ticks(25);end endtask
task send_line;input integer pixels;integer x;begin
 hs=1;ticks(8);
 for(x=0;x<pixels/4;x=x+1) begin valid=1;ticks(1);valid=0;ticks(1);end
 hs=0;ticks(30);
end endtask
task frame;input integer width,height,short_line;integer y;begin
 pulse_start;
 for(y=0;y<height;y=y+1) send_line(y==short_line ? width-4 : width);
 fe=1;ticks(1);fe=0;ticks(250);
end endtask
task expect_status;input integer width,height,errors,count;begin
 checks=checks+1;
 if(w!==width || h!==height || err!==errors || frames!==count)
  $fatal(1,"check %0d got %0dx%0d errors=%0d frames=%0d expected %0dx%0d errors=%0d frames=%0d",
   checks,w,h,err,frames,width,height,errors,count);
end endtask
initial begin
 ticks(3);rst=1;ticks(10);
 // Normal FHD must not inherit the legacy format-error count.
 frame(1920,1080,-1);expect_status(1920,1080,0,1);
 frame(1920,1080,-1);expect_status(1920,1080,0,2);
 // True faults still count once per bad frame and report measured dimensions.
 frame(1924,1080,-1);expect_status(1924,1080,1,3);
 frame(1920,1079,-1);expect_status(1920,1079,2,4);
 frame(1920,1081,-1);expect_status(1920,1081,3,5);
 frame(1920,1080,300);expect_status(1920,1080,4,6);
 frame(1024,600,-1);expect_status(1024,600,5,7);
 // An interrupted frame is an error even when the next frame is valid.
 pulse_start;send_line(1920);
 frame(1920,1080,-1);expect_status(1920,1080,6,9);
 frame(1920,1080,-1);expect_status(1920,1080,6,10);
 lane=1;ticks(50);lane=0;ticks(150);
 if(le!==1) $fatal(1,"lane assertion edge must remain counted");
 ticks(600000);
 if(fps!==0 || gap==0 || err!==6) $fatal(1,"stopped CSI must retain errors and report gap");
 rst=0;ticks(10);rst=1;ticks(250);expect_status(0,0,0,0);
 frame(1920,1080,-1);expect_status(1920,1080,0,1);
 $display("PASS HD monitor: %0d status checks; FHD repeat, wrong width, missing/extra line, ragged line, legacy frame, interrupted frame, lane, CSI stop, reset recovery",checks);
 $finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
