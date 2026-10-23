`timescale 1ns/1ps
module tb_motion_recovery_page;
reg clk=0,rst_n=0,vs=0,hs=0,de=0,page_switch=1;
always #5 clk=~clk;
reg [255:0] live=0,packet=0;reg [303:0] objects=0;
wire nv,nh,nd,gv,gh,gd;wire [23:0] nrgb,grgb;
classified_dual_page_osd #(.CLASSIFIED_COUNT(1),.RESULT_RECORDER(1),.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.REGIONS(1),.CALIBRATION(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) dut(
.clk(clk),
.rst_n(rst_n),
.vs(vs),
.hs(hs),
.de(de),
.rgb(24'h556677),
.exposure(16'd1092),
.gain(16'd40),
.wb_r(8'd100),
.wb_b(8'd100),
.wb_tune(1'b0),
.wb_pending(1'b0),
.view_mode(2'd3),
.edge_count(13'd0),
.edge_sum(24'd0),
.local_box_valid(1'b1),
.local_x0(11'd550),
.local_x1(11'd720),
.local_y0(10'd290),
.local_y1(10'd350),
.roi_valid(1'b1),
.roi_mean(8'd100),
.roi_min(8'd30),
.roi_max(8'd180),
.roi_state(2'd2),
.width(16'd1920),
.height(16'd1080),
.fps(16'd27),
.lane_errors(16'd0),
.format_errors(16'd0),
.i2c_errors(16'd0),
.gaps(16'd0),
.frames(32'd17),
.uptime(32'd42),
.cfg_done(1'b1),
.overflow_frames(16'd0),
.lost_frames(16'd0),
.underflow_frames(16'd0),
.diagnostics(36'd0),
.publish_diagnostic(27'd0),
.pocket_records(340'd0),
.pocket_enable(1'b0),
.track_valid(1'b0),
.track_x0(11'd0),
.track_x1(11'd0),
.track_reason(4'd0),
.track_rows(3'd0),
.frame_objects(objects),
.calibration_record(128'd0),
.calibration_valid(1'b0),
.local_wait_reason(4'd0),
.out_vs(nv),
.out_hs(nh),
.out_de(nd),
.out_rgb(nrgb),
.count_page_switch(page_switch),
.count_live_record(live),
.count_frame_record(packet),
.count_eligible(1'b1));
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.REGIONS(1),.CALIBRATION(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) gold(
.clk(clk),
.rst_n(rst_n),
.vs(vs),
.hs(hs),
.de(de),
.rgb(24'h556677),
.exposure(16'd1092),
.gain(16'd40),
.wb_r(8'd100),
.wb_b(8'd100),
.wb_tune(1'b0),
.wb_pending(1'b0),
.view_mode(2'd3),
.edge_count(13'd0),
.edge_sum(24'd0),
.local_box_valid(1'b1),
.local_x0(11'd550),
.local_x1(11'd720),
.local_y0(10'd290),
.local_y1(10'd350),
.roi_valid(1'b1),
.roi_mean(8'd100),
.roi_min(8'd30),
.roi_max(8'd180),
.roi_state(2'd2),
.width(16'd1920),
.height(16'd1080),
.fps(16'd27),
.lane_errors(16'd0),
.format_errors(16'd0),
.i2c_errors(16'd0),
.gaps(16'd0),
.frames(32'd17),
.uptime(32'd42),
.cfg_done(1'b1),
.overflow_frames(16'd0),
.lost_frames(16'd0),
.underflow_frames(16'd0),
.diagnostics(36'd0),
.publish_diagnostic(27'd0),
.pocket_records(340'd0),
.pocket_enable(1'b0),
.track_valid(1'b0),
.track_x0(11'd0),
.track_x1(11'd0),
.track_reason(4'd0),
.track_rows(3'd0),
.frame_objects(objects),
.calibration_record(128'd0),
.calibration_valid(1'b0),
.local_wait_reason(4'd0),
.out_vs(gv),
.out_hs(gh),
.out_de(gd),
.out_rgb(grgb));

function [7:0] expected_header(input integer ch,rr);
 begin case(ch*16+rr)
 1072:expected_header=8'h00;
 1073:expected_header=8'h00;
 1074:expected_header=8'h00;
 1075:expected_header=8'h3c;
 1076:expected_header=8'h62;
 1077:expected_header=8'h40;
 1078:expected_header=8'h40;
 1079:expected_header=8'h40;
 1080:expected_header=8'h40;
 1081:expected_header=8'h40;
 1082:expected_header=8'h62;
 1083:expected_header=8'h3c;
 1084:expected_header=8'h00;
 1085:expected_header=8'h00;
 1086:expected_header=8'h00;
 1087:expected_header=8'h00;
 928:expected_header=8'h00;
 929:expected_header=8'h00;
 930:expected_header=8'h00;
 931:expected_header=8'h00;
 932:expected_header=8'h00;
 933:expected_header=8'h00;
 934:expected_header=8'h00;
 935:expected_header=8'h00;
 936:expected_header=8'h00;
 937:expected_header=8'h00;
 938:expected_header=8'h00;
 939:expected_header=8'h00;
 940:expected_header=8'h00;
 941:expected_header=8'h00;
 942:expected_header=8'h00;
 943:expected_header=8'h00;
 768:expected_header=8'h00;
 769:expected_header=8'h00;
 770:expected_header=8'h00;
 771:expected_header=8'h3c;
 772:expected_header=8'h66;
 773:expected_header=8'h46;
 774:expected_header=8'h4e;
 775:expected_header=8'h5a;
 776:expected_header=8'h62;
 777:expected_header=8'h46;
 778:expected_header=8'h64;
 779:expected_header=8'h3c;
 780:expected_header=8'h00;
 781:expected_header=8'h00;
 782:expected_header=8'h00;
 783:expected_header=8'h00;
 848:expected_header=8'h00;
 849:expected_header=8'h00;
 850:expected_header=8'h00;
 851:expected_header=8'h7c;
 852:expected_header=8'h60;
 853:expected_header=8'h60;
 854:expected_header=8'h60;
 855:expected_header=8'h7c;
 856:expected_header=8'h06;
 857:expected_header=8'h06;
 858:expected_header=8'h04;
 859:expected_header=8'h78;
 860:expected_header=8'h00;
 861:expected_header=8'h00;
 862:expected_header=8'h00;
 863:expected_header=8'h00;
 default:expected_header=0;endcase end
endfunction
integer header_x,header_y,header_ch,header_pixels=0;reg [7:0] header_row;reg [23:0] header_rgb;
integer checking=0,pixels=0,frames=0,ppm,px,py;
always @(negedge clk)if(checking && nd)begin
 if(checking==1 && {nv,nh,nd,nrgb}!=={gv,gh,gd,grgb})$fatal(1,"original page changed pixel%0d",pixels);
 if(checking==2)$fwrite(ppm,"%c%c%c",nrgb[23:16],nrgb[15:8],nrgb[7:0]);
 if(checking==2)begin
  header_x=pixels%1280;header_y=pixels/1280;
  if(header_x>=648 && header_x<672 && header_y>=32 && header_y<48)begin
   header_ch=header_x<656 ? "C" : header_x<664 ? ":" : "0"+live[54:51];
   header_row=expected_header(header_ch,header_y-32);
   header_rgb=header_row[7-(header_x%8)] ? 24'h70ffdd : 24'h142336;
   if(nrgb!==header_rgb)$fatal(1,"C:reason glyph pixel wrong x%0d y%0d code%0d",header_x,header_y,live[54:51]);
   header_pixels++;
  end
 end
 pixels++;
end
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task raster(input integer which);
begin
 frames++;vs=1;ticks(10);vs=0;ticks(2000);checking=which;pixels=0;
 if(which==2)begin ppm=$fopen("classified_page.ppm","wb");$fwrite(ppm,"P6\n1280 720\n255\n");end
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px++)begin de=1;ticks(1);end
  de=0;ticks(370);
 end
 ticks(5);checking=0;if(pixels!=921600)$fatal(1,"raster pixel count");
 if(which==2)$fclose(ppm);
end endtask
initial begin
 ticks(10);rst_n=1;ticks(10);
 live[239:224]=3;live[223]=1;live[31:0]=17;live[47:32]=7;live[50:48]=2;live[55]=1;live[56]=1;
 live[54:51]=5;live[66:58]=123;live[75:67]=120;live[84:76]=3;live[93:85]=4;
 live[138:130]=4;live[147:139]=10;live[156:148]=86;
 live[210:202]=123;live[212:211]=2;live[216:213]=1;packet=live;
 packet[102:94]=111;packet[111:103]=112;
 objects[75:0]={1'b1,2'd2,4'd0,13'd1000,7'd40,7'd40,11'd560,11'd600,10'd300,10'd340};
 objects[151:76]={1'b1,2'd3,4'd0,13'd80,7'd8,7'd8,11'd696,11'd704,10'd316,10'd324};
 raster(1);page_switch=0;ticks(743000);raster(2);
 if(dut.counting_page.render.cache[0]!==16'h0123 || dut.counting_page.render.cache[1]!==16'h0120 || dut.counting_page.render.cache[14]!==16'h1092)$fatal(1,"shared BCD conversion");
 if(!dut.counting_page.render.observed_valid || dut.counting_page.render.observed_present!=1 ||
   dut.counting_page.render.observed_empty!=1 || dut.counting_page.render.observed_unknown!=0)$fatal(1,"frame observation counts wrong");
 if(dut.counting_page.render.cache[4]!==16'h0003)$fatal(1,"visible RUN must use resettable counter, not internal generation7");
 live[50:48]=1;packet[50:48]=1;packet[129:94]=0;
 raster(2);
 if(!dut.counting_page.render.show || dut.counting_page.render.observed_empty!=1)$fatal(1,"ACQUIRE hides measured candidates");
 objects[74:73]=1;raster(2);
 if(dut.counting_page.render.observed_present!=0 || dut.counting_page.render.observed_empty!=1 ||
   dut.counting_page.render.observed_unknown!=1)$fatal(1,"unknown diagnostic not atomic");
 live[50:48]=0;live[54:51]=0;live[239:224]=0;live[216:58]=0;packet=0;raster(2);
 if(dut.counting_page.render.cache[4]!==0 || dut.counting_page.render.cache[0]!==0 || dut.counting_page.render.show)$fatal(1,"clear header or old frame overlay retained");
 if(dut.counting_page.render.static_char(2,31)!="S" || dut.counting_page.render.static_char(2,32)!="W" ||
    dut.counting_page.render.static_char(2,33)!="3")$fatal(1,"SW3 instruction missing or shifted");
 page_switch=1;ticks(743000);raster(1);
 if(header_pixels!=1536)$fatal(1,"header pixel coverage%0d",header_pixels);
 $display("PASS motion recovery page: 2 original 720p rasters byte-identical before/after SW4; new-page RGB snapshot; 3-clock sync and BCD");$finish;
end
initial begin #100000000;$fatal(1,"page watchdog");end
endmodule
