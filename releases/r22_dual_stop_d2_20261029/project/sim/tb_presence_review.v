`timescale 1ns/1ps
// Replay photographed native feature counts using complete connected masks.
// These synthetic masks are not camera captures; RAW/vendor-RAM tests are separate.
module tb_presence_review;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready,fresh,located,review;wire [1:0] state;wire [12:0] fg;wire [6:0] bw,bh;
wire [10:0] x0,x1;wire [9:0] y0,y1;
roi_shape_search dut(.clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.sample_new(fresh),.located(located),.state(state),
 .foreground_count(fg),.box_width(bw),.box_height(bh),.box_x0(x0),.box_x1(x1),.box_y0(y0),.box_y1(y1),.review_required(review));
integer width_now,height_now,wanted,side_bright,background=30,left,top,remove_count;
integer count=0,i,j,l,gray,seen_foreground,cycles;
function integer image(input integer px,py);
 integer ix,iy;begin
 image=background;ix=px-left;iy=py-top;
 if(ix>=0 && ix<width_now && iy>=0 && iy<height_now)begin
  image=180;
  // Preserve the outer connected perimeter and independently remove interior pixels.
  if(ix>0 && ix<width_now-1 && iy>0 && iy<height_now-1 &&
   (iy-1)*(width_now-2)+(ix-1)<remove_count)image=30;
 end
 if(side_bright && px>=551 && px<567 && py>=260 && py<340)image=180;
 end endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task sample(input integer w,h,n,context_bad,expected,check);
 begin
  width_now=w;height_now=h;wanted=n;side_bright=context_bad;left=512-w/2;top=300-h/2;remove_count=w*h-n;
  fs=1;ticks(1);fs=0;ticks(2);sof=1;accept=1;x=0;y=0;rgb=0;ticks(1);sof=0;accept=0;ticks(2);
  seen_foreground=0;
  for(j=228;j<372;j++)for(i=416;i<608;i+=4)begin
   x=i;y=j;accept=1;
   for(l=0;l<4;l++)begin gray=image(i+l,j);rgb[95-l*24-:24]={3{8'(gray)}};
    if(i+l>=left && i+l<left+w && j>=top && j<top+h && gray>=100)seen_foreground++;
   end
   ticks(1);accept=0;ticks(1);
  end
  cycles=0;while(!ready && cycles<600000)begin ticks(1);cycles++;end
  if(!ready || state!==expected || review!==check || !located || fg!=wanted || seen_foreground!=wanted || bw!=w || bh!=h)
   $fatal(1,"feature replay %0d FG/W/H=%0d/%0d/%0d state/check=%0d/%b expected=%0d/%0d/%0d %0d/%0d phase=%0d",count,fg,bw,bh,state,review,n,w,h,expected,check,dut.phase);
  if(x0!=left-2 || x1!=left+w+2 || y0!=top-2 || y1!=top+h+2)$fatal(1,"replayed bbox was cropped");
  count++;$display("OBS presence review case=%0d FG=%0d W/H=%0d/%0d context_bad=%0d class=%0d CHECK=%b cycles=%0d",count,fg,bw,bh,context_bad,state,review,cycles);
 end endtask
initial begin
 ticks(4);rst=1;ticks(4);
 sample(61,76,16'h108f,0,2,0);sample(62,76,16'h1090,0,2,0);sample(61,76,16'h105f,0,2,0);
 sample(68,82,16'h1101,1,2,1);sample(62,76,16'h0ff9,1,2,1);sample(74,62,16'h1083,1,2,1);sample(46,75,16'h0a8e,1,2,1);
 sample(64,76,16'h1007,0,2,1); // Earlier human-confirmed near-85% positive.
 sample(16,17,16'h00d3,0,3,0);sample(19,16,16'h00ea,0,3,0);sample(17,18,16'h00e3,0,3,0);
 sample(28,30,16'h0247,0,0,0); // Actual large feeding hole must remain non-target.
 sample(64,76,3648,0,2,1);sample(64,76,3647,0,1,0); // Exact 75% envelope boundary.
 sample(40,72,2400,0,2,1);sample(40,73,2400,0,1,0); // Exact 1.8 aspect boundary.
 sample(60,60,3000,0,1,0);sample(64,87,5000,0,1,0); // Square/oversized body is not accepted.
 sample(63,75,4725,1,2,1);sample(63,75,4725,0,2,0); // Side contamination then clean recovery.
 fs=1;ticks(1);fs=0;cancel=1;ticks(1);cancel=0;ticks(3);
 if(ready || review || located || state!=1)$fatal(1,"old CHECK survived cancellation");
 $display("PASS presence review: %0d independently counted connected masks, photograph feature replays, unchanged empty/feed models, CHECK distinctions, 75%% and aspect boundaries, context recovery and cancellation",count);$finish;
end
initial begin #180000000;$fatal(1,"presence review watchdog");end
endmodule
