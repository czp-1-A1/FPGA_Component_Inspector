`timescale 1ns/1ps
module tb_review_neighbours;
reg clk=0,rst_n=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ar,an,al,av,br,bn,bl,bv,pr;
wire [1:0] as,bs;wire [12:0] af,bf;wire [6:0] aw,ah,bw,bh;
wire [10:0] ax0,ax1,bx0,bx1;wire [9:0] ay0,ay1,by0,by1;
wire [151:0] ao,bo;wire [303:0] az,bz;wire [607:0] ac,bc;
wire [31:0] ae,be;wire [127:0] probe;
frame_shape_search_r13 #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) baseline(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ar),.sample_new(an),.located(al),.state(as),
 .foreground_count(af),.box_width(aw),.box_height(ah),.box_x0(ax0),.box_x1(ax1),.box_y0(ay0),.box_y1(ay1),
 .review_required(av),.objects(ao),.region_objects(az),.recorder_objects(ac),.empty_probe(ae),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
frame_shape_search #(.REVIEW_PROBE(1),.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1)) candidate(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(br),.sample_new(bn),.located(bl),.state(bs),
 .foreground_count(bf),.box_width(bw),.box_height(bh),.box_x0(bx0),.box_x1(bx1),.box_y0(by0),.box_y1(by1),
 .review_required(bv),.objects(bo),.region_objects(bz),.recorder_objects(bc),.empty_probe(be),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0),.probe_ready(pr),.probe_record(probe));
integer scene=0,px,py,lane,v,cycles,clocks=0,checks=0;
always @(negedge clk)if(rst_n)begin
 clocks=clocks+1;
 if({ar,an,al,as,af,aw,ah,ax0,ax1,ay0,ay1,av,ao,az,ac,ae} !==
    {br,bn,bl,bs,bf,bw,bh,bx0,bx1,by0,by1,bv,bo,bz,bc,be})
  $fatal(1,"baseline classification/timing changed scene%0d clock%0d",scene,clocks);
end
function automatic integer width;
 case(scene)1:width=24;2:width=34;3:width=26;4:width=44;default:width=36;endcase
endfunction
function automatic integer height;
 case(scene)1:height=36;2:height=40;3:height=44;4:height=38;default:height=46;endcase
endfunction
function automatic integer cx;
 cx=620;
endfunction
function automatic integer image(input integer xx,yy);
 integer cy,center;
 begin
  image=30;
  for(integer bank=0;bank<2;bank++)begin
   cy=bank ? 516 : 320;
   for(integer p=0;p<3;p++)begin
    center=564+p*56;
    if(xx>=center-18 && xx<center+18 && yy>=cy-22 && yy<cy+24)image=180;
    if(xx>=center-8 && xx<center+8 && yy>=cy-8 && yy<cy+8)image=220;
   end
  end
 end
endfunction
function automatic integer expected_mean(input integer bank,feature);
 integer sx,sy,nx,ny,sum;
 begin
  sx=cx()-8;sy=(bank ? 516 : 320)-8;nx=16;ny=16;
  case(feature)
   1:begin sx=cx()-16;nx=8;end
   2:begin sx=cx()+8;nx=8;end
   3:begin sy=(bank ? 516 : 320)-16;ny=8;end
   4:begin sy=(bank ? 516 : 320)+8;ny=8;end
  endcase
  sum=0;for(integer dy=0;dy<ny;dy=dy+1)for(integer dx=0;dx<nx;dx=dx+1)sum=sum+image(sx+dx,sy+dy);
  expected_mean=sum/(nx*ny);
 end
endfunction
task tick;@(negedge clk);endtask
task frame(input integer n);
 reg [63:0] rec;reg [75:0] ob;reg [3:0] reason;reg measurable;
 begin
  scene=n;fs=1;tick();fs=0;repeat(3)tick();
  for(py=0;py<720;py=py+1)begin
   for(px=0;px<1280;px=px+4)begin
    x=px;y=py;accept=1;sof=(px==0 && py==0);
    for(lane=0;lane<4;lane=lane+1)begin v=image(px+lane,py);rgb[95-lane*24-:24]={8'(v+2),8'(v),8'(v-2)};end
    tick();accept=0;sof=0;
   end
   repeat(2)tick();
  end
  cycles=0;while(!pr && cycles<900000)begin tick();cycles=cycles+1;end
  if(!pr)$fatal(1,"diagnostic completion missing scene%0d",n);
  reason=n==8 ? 8 : n==1 ? 1 : n==3 ? 3 : n==5 ? 15 : 0;
  measurable=n!=1 && n!=3 && n!=6 && n!=7;
  for(integer bank=0;bank<2;bank=bank+1)begin
   rec=probe[bank*64+:64];ob=bz[bank*152+:76];checks=checks+1;
   $display("REF scene%0d bank%0d object=%h probe=%h",n,bank,ob,rec);
   if(n==7)begin if(rec!==0 || ob!==0)$fatal(1,"blank source retained old object");end
   else begin
    if(!ob[75] || ob[74:73]!=2 || ob[72:69]!==reason || ob[55:49]!=width() || ob[48:42]!=height())
     $fatal(1,"known fixture classification mismatch scene%0d",n);
    if(rec[63:61]!=={1'b1,measurable,(n==5)} || rec[60:57]!==reason || rec[56:41]!==16'h8888 || rec[40]!==0)
     $fatal(1,"source/reference binding mismatch scene%0d",n);
    for(integer f=0;f<5;f=f+1)
     if(rec[32-f*8+:8] !== 8'(measurable ? expected_mean(bank,f) : 0))
      $fatal(1,"native mean mismatch scene%0d bank%0d feature%0d got%0d expected%0d",n,bank,f,rec[32-f*8+:8],expected_mean(bank,f));
   end
  end
  cancel=1;tick();cancel=0;repeat(2)tick();
  if(pr || probe!==0)$fatal(1,"stale diagnostics after invalidate");
 end
endtask
initial begin
 repeat(5)tick();rst_n=1;repeat(5)tick();
 frame(8);
 $display("PASS review_neighbours: three real neighbouring bodies/ROI, exact136 dark cells each side, %0d bound packets, %0d clocks EXACT R13 scalar/304/608/empty/ready equivalence; native means and T80 source",checks,clocks);$finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule
