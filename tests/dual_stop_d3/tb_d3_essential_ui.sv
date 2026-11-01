`timescale 1ns/1ps
module tb_d3_essential_ui;
 reg clk=0,rst_n=0,vs=0,hs=0,de=0;
 always #5 clk=~clk;
 reg [127:0] relay_status=0;reg [2:0] relay_mode=2;reg relay_motor=0;
 reg [511:0] live=0,packet=0;reg [303:0] objects=0;
 wire ov,oh,od;wire [23:0] pixel;
 reg [2:0] vp=0,hp=0,dp=0;
 integer fd,xx,yy,frame_no=0,pixels=0;
 compact_inspector_osd #(.ESSENTIAL_UI(1),.AUTO_RELAY(1),.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.BUILD_R22(1),.EMPTY_TRACE(1),.BUILD_R20(1),.REPORT_NUMBER_GAPS(0)) dut(
  .relay_status(relay_status),.relay_mode(relay_mode),.relay_motor(relay_motor),
  .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(1'b1),
  .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
  .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd149),.roi_min(8'd124),.roi_max(8'd176),
  .wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd3),.edge_count(13'd0),
  .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
  .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd17),
  .diagnostics(36'd0),.publish_diagnostic(27'd0),.objects(objects),.calibration_record(128'd0),
  .calibration_valid(1'b0),.local_wait_reason(4'd0),.live_record(live),.frame_record(packet),.eligible(1'b1),
  .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(pixel));
 function [75:0] object_at(input integer cx,cy,kind,mask);
  begin object_at={1'b1,2'(kind),4'(mask),13'd956,7'd32,7'd32,11'(cx),11'(cx+31),10'(cy),10'(cy+31)};end
 endfunction
 task text_at(input integer row,cell_no,input string value);
  begin
   for(integer i=0;i<value.len();i++)if(dut.plane[row*128+cell_no+i][7:0]!==value[i])
    $fatal(1,"text row%0d col%0d got%h expected%h",row,cell_no+i,dut.plane[row*128+cell_no+i][7:0],value[i]);
  end
 endtask
 always @(posedge clk)begin
  vp={vp[1:0],vs};hp={hp[1:0],hs};dp={dp[1:0],de};#1;
  if(rst_n && {ov,oh,od}!=={vp[2],hp[2],dp[2]})$fatal(1,"video pipeline alignment");
  if(od)begin
   if(^pixel===1'bx)$fatal(1,"unknown output pixel");
   $fwrite(fd,"%06x\n",pixel);pixels++;
  end
 end
 task picture;
  reg [511:0] saved;reg [303:0] saved_objects;
  begin
   saved=live;saved_objects=objects;pixels=0;
   fd=$fopen($sformatf("essential_ui_%0d.hex",frame_no),"w");
   vs=1;repeat(4)@(negedge clk);vs=0;repeat(10)@(negedge clk);
   for(yy=0;yy<720;yy++)begin
    hs=1;repeat(2)@(negedge clk);hs=0;de=1;
    for(xx=0;xx<1280;xx++)@(negedge clk);
    de=0;repeat(10)@(negedge clk);
    if(yy==7)begin
     text_at(0,0,"INSPECT D3 R56");text_at(0,22,"FPS 027");text_at(0,35,"1920x1080");
     text_at(1,0,"L1 TOTAL 027");text_at(1,23,"020");text_at(1,37,"007");text_at(1,54,"002");
     text_at(2,0,"L2 TOTAL 043");text_at(2,23,"040");text_at(2,37,"003");text_at(2,54,"005");
     text_at(3,0,"L1 EMPTY IDS PAGE 001 :   001  009  013  014  015  020  024  000");
     text_at(4,0,"L2 EMPTY IDS PAGE 001 :   002  021  043  000  000  000  000  000");
     text_at(5,0,"K1 START   K2 PAUSE/RESUME   K3 CLEAR   K4 STOP");text_at(6,0,"ALARM K3 CLEAR  ");
     for(integer z=83;z<128;z++)if(dut.plane[128+z][7:0]!==32 || dut.plane[256+z][7:0]!==32)$fatal(1,"right header not empty");
     if(dut.plane[128+16][7:0]!==8'h81 || dut.plane[128+19][7:0]!==8'h82 || dut.plane[128+30][7:0]!==8'h83 || dut.plane[128+33][7:0]!==8'h84 || dut.plane[128+44][7:0]!==8'h85)$fatal(1,"Chinese label glyph mapping");
     if(dut.label_bcd0!=20'h00008 || dut.label_bcd1!=20'h00009 ||
        dut.label_bcd2!=20'h00021 || dut.label_bcd3!=20'h00022)$fatal(1,"four label decimal IDs");
     if(!dut.show || dut.show2!==(frame_no==0))$fatal(1,"independent generation/status guard");
    end
    if(yy==300)begin live=~saved;objects=~saved_objects;relay_status=~relay_status;end
   end
   repeat(8)@(negedge clk);live=saved;objects=saved_objects;relay_status=~relay_status;
   if(pixels!=921600)$fatal(1,"raster length");$fclose(fd);
  end
 endtask
 reg [2:0] amber_delay=0;
 integer status_chars=0,amber=0;
 always @(posedge clk)begin
  amber_delay<={amber_delay[1:0],rst_n && de && dut.repair_border};
  if(rst_n && de && (dut.y==280 || dut.y==472) && (dut.x==72 || dut.x==232) && !dut.repair_border)$fatal(1,"one of two repair windows missing");
  if(rst_n && de && dut.y>100 && dut.relay_s!=={6'd32,1'b1,9'd300,16'd0,3'd1,4'd0,4'd0,9'd300,11'd192,1'b0,6'd18,1'b1,9'd27,16'd4321,3'd3,4'd9,4'd2,9'd27,11'd160,1'b0})$fatal(1,"relay frame snapshot tore");
  #1;if(od && amber_delay[2])begin if(pixel!==24'hffd060)$fatal(1,"amber window pipeline/color");amber++;end
 end
 initial begin
  repeat(10)@(negedge clk);rst_n=1;repeat(8)@(negedge clk);
  for(integer b=0;b<2;b++)begin
   live[b*256+47-:16]=7;live[b*256+50-:3]=2;live[b*256+55]=1;live[b*256+56]=b==0;
   live[b*256+57]=b;live[b*256+223]=1;live[b*256+239-:16]=1;
  end
  live[66:58]=27;live[75:67]=20;live[84:76]=7;live[93:85]=2;
  live[322:314]=43;live[331:323]=40;live[340:332]=3;live[349:341]=5;
  live[130+:9]=1;live[139+:9]=9;live[148+:9]=13;live[157+:9]=14;
  live[166+:9]=15;live[175+:9]=20;live[184+:9]=24;
  live[386+:9]=2;live[395+:9]=21;live[404+:9]=43;
  relay_status[63:0]={6'd18,1'b1,9'd27,16'd4321,3'd3,4'd9,4'd2,9'd27,11'd160,1'b0};
  relay_status[127:64]={6'd32,1'b1,9'd300,16'd0,3'd1,4'd0,4'd0,9'd300,11'd192,1'b0};
  packet=live;packet[94+:9]=8;packet[103+:9]=9;packet[368+:9]=21;packet[377+:9]=22;
  objects[75:0]=object_at(550,300,2,0);objects[151:76]=object_at(650,310,3,0);
  objects[227:152]=object_at(550,470,2,1);objects[303:228]=object_at(690,480,2,0);
  picture();frame_no=1;live[306:304]=3;picture();
  frame_no=2;live[306:304]=2;live[303:288]=8;picture();
  if(amber<100)$fatal(1,"incomplete two lane relay UI");
  $display("PASS ESSENTIAL UI: independent totals, empty lists, four IDs, one-region loss/stale-run masking, atomic snapshots, three complete rasters, two amber windows, essential fields, removed debug/right header, Chinese glyphs and atomic relay status");$finish;
 end
 initial begin #150000000;$fatal(1,"two-region UI watchdog");end
endmodule
