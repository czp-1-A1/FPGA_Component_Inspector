`timescale 1ns/1ps
module tb_dual_osd;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0;wire ov,oh,od;wire [23:0] pixel;
 reg [63:0] motor=0;reg page=1;
 function [75:0] box(input integer xx,yy,kind);
  box={1'b1,2'(kind),4'd0,13'd64,7'd8,7'd8,11'(xx),11'(xx+12),10'(yy),10'(yy+16)};
 endfunction
 compact_inspector_osd #(.RECOGNITION_ONLY(1),.BUILD_R22(1),.EMPTY_TRACE(1),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.WIDTH(1280),.HEIGHT(720)) dut(
 .clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(page),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),.wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b0),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd0),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd1),.diagnostics(36'd0),.publish_diagnostic(27'd0),
 .objects({box(720,510,2),box(510,510,3),box(700,310,3),box(500,310,2)}),.calibration_record(128'd0),.calibration_valid(1'b0),.local_wait_reason(4'd0),
 .relay_status(motor),.relay_diagnostic(96'hffffffffffffffffffffffff),.relay_control_mode(3'd3),.live_record({256{1'b1}}),.frame_record({256{1'b1}}),.eligible(1'b1),
 .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(pixel));
 reg [2:0] vp=0,hp=0,dp=0;integer x,y,f=0,chars=0,pixels=0,fd;
 reg [511:0] expected;integer ci;
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 always @(posedge clk)begin
  vp<={vp[1:0],vs};hp<={hp[1:0],hs};dp<={dp[1:0],de};#1;
  if(rst)begin
   if({ov,oh,od}!=={vp[2],hp[2],dp[2]})$fatal(1,"3-clock video changed");
   if(od)begin if(^pixel===1'bx)$fatal(1,"unknown active pixel");pixels++;if(f==0)$fwrite(fd,"%06x\n",pixel);end
   if(de && dut.page_s)$fatal(1,"count page remained enabled");
   if(de && dut.repair_border)$fatal(1,"single-row refill frame leaked into dual recognition");
   if(de && dut.y==300 && (dut.x==400 || dut.x==879) && !dut.guide)$fatal(1,"upper ROI border missing");
   if(de && dut.y==508 && (dut.x==400 || dut.x==879) && !dut.guide)$fatal(1,"lower ROI visible dash missing");
   if(de && (dut.y==300 || dut.y==500) && dut.x==640 && dut.guide)$fatal(1,"count gate still visible");
   if(de && (dut.y==318 || dut.y==518) && (dut.x==500 || dut.x==700 || dut.x==510 || dut.x==720))begin
    if((dut.y==318 && (dut.x==500 || dut.x==700)) || (dut.y==518 && (dut.x==510 || dut.x==720)))if(!dut.guide)$fatal(1,"per-lane result box missing");
   end
   if(de && dut.x>=136 && dut.x<648 && dut.x[2:0]==0 && (dut.y==8 || dut.y==32 || dut.y==56 || dut.y==632 || dut.y==656 || dut.y==680 || dut.y==704))begin
    expected=0;
    case(dut.y)
     8:expected={"DUAL ROI D1 ",416'd0};
     32:expected="UPPER + LOWER ROI - RECOGNITION ONLY                            ";
     56:expected=f==0 ? "K1 RUN  K2 PAUSE/RUN  K3/K4 STOP  MOTOR:0                       " : "K1 RUN  K2 PAUSE/RUN  K3/K4 STOP  MOTOR:1                       ";
     632:expected="ROI1 UPPER - SEE RESULT BOXES                                   ";
     656:expected="ROI2 LOWER - SEE RESULT BOXES                                   ";
     680:expected="PRESENT / EMPTY / REVIEW                                        ";
     704:expected="COUNTING: WAITING   AUTO PARK: OFF                              ";
    endcase
    ci=(dut.x-136)/8;
    if((dut.y!=8 || ci<12) && dut.code!==expected[511-ci*8-:8])$fatal(1,"D1 text mismatch y%0d index%0d got%h expected%h",dut.y,ci,dut.code,expected[511-ci*8-:8]);
    if(dut.y!=8 || ci<12)chars++;
   end
   if(de && dut.y>100 && f==0 && dut.relay_snapshot[0])$fatal(1,"motor status tore midframe");
  end
 end
 task picture;
  begin vs=1;ticks(5);vs=0;ticks(20);
   for(y=0;y<720;y++)begin de=1;hs=0;for(x=0;x<1280;x++)begin if(f==0 && y==100 && x==300)begin motor=1;page=0;end ticks(1);end
    de=0;hs=1;ticks(12);hs=0;ticks(12);
   end ticks(20);
  end
 endtask
 initial begin fd=$fopen("dual_osd.hex","w");ticks(5);rst=1;ticks(5);picture();$fclose(fd);f=1;picture();
  if(pixels!=1843200 || chars!=792)$fatal(1,"incomplete output pixels%0d chars%0d",pixels,chars);
  $display("PASS DUAL OSD: two full rasters,792 literal D1/recognition/count-waiting/manual characters, both ROI and result boxes, no ledger/page/refill/ID gates, motor snapshot and 3-cycle stream");$finish;
 end
 initial begin #30000000;$fatal(1,"OSD watchdog");end
endmodule
