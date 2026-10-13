`timescale 1ns/1ps
// Independent color arithmetic and an actual automatic-WB positive control.
module tb_fixed_wb;
reg clk=0,rst=0,valid=0,sof=0,eol=0,ready=1;
reg [95:0] rgb=0;
always #5 clk=~clk;
wire uv,sv,av,ul,sl,us,ss,ur,sr;
wire [95:0] unity,scaled,automatic_data;
awb #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.FIXED_GAIN(1)) fixed_unity(
 .I_clk(clk),.I_rst_n(rst),.I_tvalid(valid),.I_tuser(sof),.I_tlast(eol),.I_tdata(rgb),.I_tready(ur),
 .O_tvalid(uv),.O_tuser(us),.O_tlast(ul),.O_tdata(unity),.O_tready(ready));
awb #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.FIXED_GAIN(1),.FIXED_R_GAIN(20'h18000),.FIXED_B_GAIN(20'h08000)) fixed_scaled(
 .I_clk(clk),.I_rst_n(rst),.I_tvalid(valid),.I_tuser(sof),.I_tlast(eol),.I_tdata(rgb),.I_tready(sr),
 .O_tvalid(sv),.O_tuser(ss),.O_tlast(sl),.O_tdata(scaled),.O_tready(ready));
awb #(.IMG_WIDTH(1024),.IMG_HEIGHT(600)) automatic_reference(
 .I_clk(clk),.I_rst_n(rst),.I_tvalid(valid),.I_tuser(sof),.I_tlast(eol),.I_tdata(rgb),.I_tready(),
 .O_tvalid(av),.O_tuser(),.O_tlast(),.O_tdata(automatic_data),.O_tready(ready));
reg [95:0] expected[0:1023],expected_scaled[0:1023];
integer sent=0,received=0,lasts=0,events=0,roi_beats=0,blocked=0;
integer automatic_changes=0,row,beat,lane,r,g,b,rr,bb,case_no;
reg checking=0;
function [95:0] scale_color;
 input [95:0] value;
 integer k,r1,b1;
 begin
  for(k=0;k<4;k=k+1) begin
   r1=(value[95-k*24-:8]*3)/2;
   b1=value[79-k*24-:8]/2;
   if(r1>255) r1=255;
   scale_color[95-k*24-:24]={8'(r1),value[87-k*24-:8],8'(b1)};
  end
 end
endfunction
always @(posedge clk) begin
 if(checking && rst && valid) begin
  expected[sent]=rgb;expected_scaled[sent]=scale_color(rgb);sent=sent+1;
 end
 #1;
 if(checking && rst) begin
  if(uv!==sv || us!==ss || ul!==sl || ur!==ready || sr!==ready)
   $fatal(1,"fixed gain altered metadata/ready schedule");
  if(us) begin events=events+1;if(!sof) $fatal(1,"early SOF changed");end
  if(uv) begin
   if(received>=sent || unity!==expected[received] || scaled!==expected_scaled[received])
    $fatal(1,"color/clip/lane mismatch case=%0d beat=%0d got=%h/%h expected=%h/%h",case_no,received,unity,scaled,expected[received],expected_scaled[received]);
   if(av && automatic_data!==unity) automatic_changes=automatic_changes+1;
   if(!ready) blocked=blocked+1;
   if(received>=608 && received<628) begin
    if(unity!=={4{24'h785a3c}} || scaled!=={4{24'hb45a1e}})
     $fatal(1,"unchanged ROI changed with colored background");
    roi_beats=roi_beats+1;
   end
   received=received+1;
  end
  if(ul) begin
   lasts=lasts+1;if(!uv || received%256!=0) $fatal(1,"invalid output line tail");
  end
 end
end
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task reset_case;input integer n;
 begin
  checking=0;rst=0;valid=0;sof=0;eol=0;ready=1;ticks(8);rst=1;ticks(8);
  case_no=n;sent=0;received=0;lasts=0;events=0;roi_beats=0;blocked=0;checking=1;
 end
endtask
task frame;input integer scene;
 begin
  for(row=0;row<3;row=row+1) begin
   for(beat=0;beat<256;beat=beat+1) begin
    if(beat==17 || beat==185) begin valid=0;sof=0;eol=0;ticks(2);end
    for(lane=0;lane<4;lane=lane+1) begin
     if(row==2 && beat>=96 && beat<116) begin r=120;g=90;b=60;end
     else if(scene==0) begin r=200+lane;g=40+lane;b=10+lane;end
     else begin r=10+lane;g=40+lane;b=200+lane;end
     rgb[95-lane*24-:24]={8'(r),8'(g),8'(b)};
    end
    valid=1;sof=(row==0 && beat==0);eol=(beat==255);ready=!(beat>=70 && beat<130);ticks(1);
   end
   valid=0;sof=0;eol=0;ready=1;ticks(100);
  end
  ticks(20);
  if(sent!=768 || received!=768 || lasts!=3 || events!=1 || roi_beats!=20 || blocked==0)
   $fatal(1,"fixed-gain frame coverage case=%0d in=%0d out=%0d last=%0d ROI=%0d",case_no,sent,received,lasts,roi_beats);
  $display("PASS fixed WB frame case=%0d scene=%0d beats=%0d ROI=%0d ready_low=%0d",case_no,scene,received,roi_beats,blocked);
 end
endtask
initial begin
 reset_case(0);frame(0);
 reset_case(1);frame(1);
 reset_case(2);
 repeat(32) begin rgb={4{24'h785a3c}};valid=1;sof=(sent==0);ticks(1);end
 reset_case(3);frame(0);
 if(automatic_changes==0) $fatal(1,"automatic WB positive control was not exercised");
 $display("PASS fixed WB: colored-background invariance, fixed non-unity gains/clipping, four lanes, bubbles, reset, line tails, ready-low; automatic reference changed %0d beats",automatic_changes);
 $finish;
end
initial begin #100000; $fatal(1,"fixed WB watchdog");end
endmodule
