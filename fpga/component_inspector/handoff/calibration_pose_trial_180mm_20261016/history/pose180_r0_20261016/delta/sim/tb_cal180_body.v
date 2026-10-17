`timescale 1ns/1ps
module tb_cal180_body;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready,old_ready;wire [303:0] objects,old_objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) previous_minima(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(old_ready),.region_objects(old_objects));
// Counterfactual old minima; the rest of the recipe is identical.
defparam previous_minima.regions.cfg.RECIPE0={8'd240,8'd21,8'd10,8'd23,8'd14,8'd12,8'd4,8'd13,8'd5,8'd38,8'd43,8'd36,8'd20,8'd39,8'd26};
defparam previous_minima.regions.cfg.RECIPE1={8'd240,8'd21,8'd10,8'd23,8'd14,8'd12,8'd4,8'd13,8'd5,8'd38,8'd43,8'd36,8'd20,8'd39,8'd26};
integer pattern=0,cases=0,checks=0,cycles,px,py,l,v;
integer centers[0:3];integer rows[0:3];
function integer image(input integer xx,yy);
 integer dx,dy,h,local_x,local_y;
 begin
 image=30;
 for(integer k=0;k<4;k++)begin
  dx=xx-centers[k];dy=yy-rows[k];
  if(pattern<=2 || pattern==5 || pattern==6)begin
   h=pattern==5 ? 21 : (k%2==0 ? 22 : 23);
   if(dx>=-18 && dx<18 && dy>=-h && dy<h)begin
    local_x=(dx+18)/2;local_y=(dy+h)/2;
    image=180;
    // Synthetic connected masks with exactly the observed CAL W/H/A.
    if(k%2==0 || pattern==5)begin
     if((local_x<2 || local_x>=16) && (local_y<4 || local_y>=h-4))image=30;
    end else begin
     if((local_x<3 && (local_y<3 || local_y>=h-3)) ||
        (local_x>=15 && local_y<3) || (local_x>=16 && local_y>=h-4))image=30;
    end
   end
  end else if(pattern==3)begin
   // Distinct dark empty/hole examples remain below T100: never infer EMPTY.
   if(dx>=-8 && dx<8 && dy>=-8 && dy<8)image=k%2==0 ? 57 : 71;
  end else if(pattern==4 && dx>=0 && dx<2 && dy>=0 && dy<2)image=104;
 end
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p);
 reg [75:0] rec,old_rec;integer count,expected_count,body_h,body_a;
 begin
 cases++;pattern=p;centers[0]=p==1 ? 402 : p==2 ? 398 : p==6 ? 521 : 520;
 centers[1]=p==6 ? 761 : 760;centers[2]=p==6 ? 521 : 520;centers[3]=p==6 ? 761 : 760;
 // Exact CAL fixtures start on even source rows; a separate case tests odd phase.
 rows[0]=p==5 ? 319 : p==6 ? 321 : 320;rows[1]=p==6 ? 320 : 319;
 rows[2]=p==5 ? 519 : p==6 ? 521 : 520;rows[3]=p==6 ? 520 : 519;
 fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;if(px%64==0)ticks(1);
  end
  ticks(2);
 end
 ticks(5);cycles=0;
 while((!ready || !old_ready) && cycles<2300000)begin ticks(1);cycles++;end
 if(!ready || !old_ready)$fatal(1,"180mm detector timeout pattern%0d",p);
 expected_count=(p==3 || p==4) ? 0 : p==2 ? 3 : 4;count=0;
 for(integer k=0;k<4;k++)begin
  rec=objects[k*76+:76];old_rec=old_objects[k*76+:76];
  if(rec[75])begin
   count++;checks++;
   if(rec[74:73]!==((p==5) ? 2'd1 : 2'd2))$fatal(1,"measured body class pattern%0d slot%0d got%0d expected%0d",p,k,rec[74:73],p==5 ? 1 : 2);
   if(p<=1)begin
    body_h=k%2==0 ? 44 : 46;body_a=k%2==0 ? 1456 : 1516;
    if(rec[55:49]!==36 || rec[48:42]!==body_h || rec[68:56]!==body_a)
     $fatal(1,"measured feature mismatch slot%0d",k);
    if(!old_rec[75] || old_rec[74:73]!==1)$fatal(1,"old minimum failure not reproduced");
   end
   if(p==1 && k==0 && (rec[41:31]!=382 || rec[30:20]!=422))$fatal(1,"zone edge truncated measured body");
  end
 end
 if(count!=expected_count)$fatal(1,"180mm count pattern%0d got%0d expected%0d",p,count,expected_count);
 $display("REF cal180 body pattern=%0d count=%0d cycles=%0d records=%h",p,count,cycles,objects);
 cancel=1;ticks(1);cancel=0;ticks(2);
 if(ready || old_ready || objects!==0 || old_objects!==0)$fatal(1,"stale 180mm objects after invalidation");
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(integer p=0;p<7;p++)frame(p);
 $display("PASS cal180 body: %0d full frames, %0d checked records, exact measured36x44/A1456 and36x46/A1516, old-minimum counterfactual, dual zones, boundary and odd-phase translation, outside center, zero-mask and one-cell not EMPTY, below-minimum review, cancel",cases,checks);$finish;
end
initial begin #500000000;$fatal(1,"180mm body watchdog");end
endmodule
