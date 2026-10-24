`timescale 1ns/1ps
module tb_surface_detector;
reg clk=0,rst_n=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;always #5 clk=~clk;
wire ar,an,br,bn,cr,cn,apr,bpr,cpr;
wire [151:0] ao,bo,co;wire [303:0] az,bz,cz;wire [607:0] ac,bc,cc;
wire [127:0] ap,bp,cp;
frame_shape_search_p01 #(.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) baseline(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ar),.sample_new(an),.objects(ao),.region_objects(az),.recorder_objects(ac),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.probe_record(ap),.probe_ready(apr));
frame_shape_search #(.SURFACE_REVIEW(1),.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) candidate(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(br),.sample_new(bn),.objects(bo),.region_objects(bz),.recorder_objects(bc),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.probe_record(bp),.probe_ready(bpr));
frame_shape_search #(.SURFACE_REVIEW(0),.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) default_off(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(cr),.sample_new(cn),.objects(co),.region_objects(cz),.recorder_objects(cc),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.probe_record(cp),.probe_ready(cpr));
integer scene=0,clocks=0,checks=0,means=0,changed=0,seen_baseline=0;
reg [607:0] saved_base;
always @(negedge clk)if(rst_n)begin
 clocks++;
 if({ar,an,ao,az,ac,apr,ap}!=={cr,cn,co,cz,cc,cpr,cp})$fatal(1,"default-off P01 mismatch clock%0d scene%0d",clocks,scene);
 if(an)begin saved_base=ac;seen_baseline=1;end
end
function automatic integer center(input integer p);
 begin center=scene==1 ? 556+p*56 : p==0 ? 404 : p==1 ? 560 : p==2 ? 720 : 876;end
endfunction
function automatic integer image(input integer xx,yy);
 integer cx,cy,w,h,back;
 begin
  image=30;w=scene==5 ? 30 : scene==6 ? 44 : 36;h=scene==5 ? 38 : scene==6 ? 38 : 48;
  if(scene!=7)for(integer bank=0;bank<2;bank++)for(integer p=0;p<4;p++)begin
   cx=center(p)+(scene==5);cy=(scene==4 ? (bank ? 516 : 320) : (bank ? 598 : 242))+(scene==5);back=scene==2 || (scene==3 && p%2==1);
   if(xx>=cx-w/2 && xx<cx+w/2 && yy>=cy-h/2 && yy<cy+h/2)begin
    image=scene==4 ? 90 : 224;
    if(scene!=4)begin
     if(xx>=cx-8 && xx<cx+8 && yy>=cy-8 && yy<cy+8)image=back ? 242 : 254;
     if(xx>=cx-16 && xx<cx-8 && yy>=cy-8 && yy<cy+8)image=back ? 238 : 224;
     if(xx>=cx+8 && xx<cx+16 && yy>=cy-8 && yy<cy+8)image=back ? 226 : 219;
     if(yy>=cy-16 && yy<cy-8 && xx>=cx-8 && xx<cx+8)image=back ? 181 : 229;
     if(yy>=cy+8 && yy<cy+16 && xx>=cx-8 && xx<cx+8)image=back ? 206 : 232;
     if(scene==6 && xx>=cx+2 && xx<cx+16 && yy>=cy-14 && yy<cy+14)image=30;
    end
   end
  end
 end
endfunction
function automatic integer scalar_mean(input integer cx,cy,f);
 integer x0,x1,y0,y1,total,n,quad;
 begin
  x0=cx-8;x1=cx+8;y0=cy-8;y1=cy+8;
  case(f)1:begin x0=cx-16;x1=cx-8;end 2:begin x0=cx+8;x1=cx+16;end
   3:begin y0=cy-16;y1=cy-8;end 4:begin y0=cy+8;y1=cy+16;end endcase
  total=0;n=0;
  for(integer y=y0;y<y1;y+=2)for(integer x=x0;x<x1;x+=2)begin
   quad=image(x,y)+image(x+1,y)+image(x,y+1)+image(x+1,y+1);
   total+=(quad/4)/8;n++;
  end
  scalar_mean=total/n;
 end
endfunction
task tick;@(negedge clk);endtask
task check_packet(input [607:0] actual,original);
 reg [75:0] a,b,masked_a,masked_b;integer cx,cy,c,m,e,pass,valids;
 begin
  valids=0;
  for(integer slot=0;slot<8;slot++)begin
   a=actual[slot*76+:76];b=original[slot*76+:76];masked_a=a;masked_b=b;
   if(a[75] && a[74:73]==2)begin
    masked_a[72]=0;masked_b[72]=0;valids++;
    cx=int'(a[41:31])+2+2*(int'(a[55:49])/4);
    cy=int'(a[19:10])+2+2*(int'(a[48:42])/4);
    c=scalar_mean(cx,cy,0);m=31;
    for(integer f=1;f<5;f++)begin e=scalar_mean(cx,cy,f);if(e<m)m=e;end
    pass=c>=13 && m*5>=c*4 && a[55:49]>=32 && a[48:42]>=32;
    means+=5;
    if(a[72] !== (scene==4 ? 1'b1 : !pass))$fatal(1,"surface reason scene%0d slot%0d C5%0d min5%0d a=%h b=%h",scene,slot,c,m,a,b);
    if(scene<=1 && a[72:69]!==0)$fatal(1,"normal not released");
    if(scene==2 && a[72:69]!==8)$fatal(1,"back was released");
    if(scene==4 && a[72:69]!==15)$fatal(1,"weakT80 was released");
    if(scene==5 && !a[69])$fatal(1,"narrow geometry was released");
    if(scene==6 && !a[71])$fatal(1,"fill guard was released");
    if(a[72]!=b[72])changed++;
   end
   if(masked_a!==masked_b)$fatal(1,"changed non-quality field scene%0d slot%0d got=%h original=%h",scene,slot,a,b);
   checks++;
  end
  if(valids!=(scene==7 ? 0 : 8))$fatal(1,"fixture retained %0d of8 real bodies scene%0d",valids,scene);
 end
endtask
task frame(input integer n);
 integer px,py,k,v,waits;
 begin
  scene=n;fs=1;tick;fs=0;seen_baseline=0;repeat(3)tick;
  for(py=0;py<720;py++)begin
   for(px=0;px<1280;px+=4)begin
    x=px;y=py;accept=1;sof=(px==0 && py==0);
    for(k=0;k<4;k++)begin v=image(px+k,py);rgb[95-k*24-:24]={8'(v+1),8'(v),8'(v-1)};end
    tick;accept=0;sof=0;
   end
   repeat(2)tick;
  end
  waits=0;while(!bpr && waits<900000)begin tick;waits++;end
  if(!bpr || !seen_baseline)$fatal(1,"result not complete scene%0d",scene);
  check_packet(bc,saved_base);
  $display("SURFACE RGB scene%0d checks%0d means%0d changed%0d cycles%0d records=%h",scene,checks,means,changed,waits,bc);
  cancel=1;tick;cancel=0;repeat(2)tick;
  if(br || bn || bpr || bo!==0 || bz!==0 || bc!==0 || bp!==0)$fatal(1,"cancel retained result");
 end
endtask
initial begin
 repeat(5)tick;rst_n=1;repeat(5)tick;
 for(integer n=0;n<8;n++)frame(n);
 if(changed<8)$fatal(1,"no neighbouring-strip false-review reproduction");
 $display("PASS surface detector:8 full720p RGB frames, %0d recorder records, %0d independent means, %0d quality bits changed, %0d clocks default-off EXACT P01; all8 slots, ROI edges, neighbours/front/back/geometry/fill/weak/cancel",checks,means,changed,clocks);
 $finish;
end
initial begin #150000000;$fatal(1,"watchdog");end
endmodule
