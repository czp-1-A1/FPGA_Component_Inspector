// Experimental 3528 geometry; all coordinates are native 1024x600 pixels.
// Fixed trial orientation: sprocket row above the component pockets.
// One PPC4-decimated parser searches the upper band, not an X anchor.
// Three adjacent sampled rows must agree and contain at least two pitched holes.
module multi_pocket_tracker #(
 parameter X0=128,X1=896,Y0=168,Y1=336,STEP_Y=8,
 parameter PITCH=96,PITCH_TOL=24,OFFSET_X=32,OFFSET_Y=80,
 parameter CORE=80,VERIFY_X=4,VERIFY_Y=8
)(
 input wire clk,rst_n,frame_start,pixel_sof,accept,frame_commit,invalidate,
 input wire [10:0] x,input wire [9:0] y,input wire [95:0] rgb,
 output reg [43:0] sample_x0,output reg [39:0] sample_y0,
 output reg [3:0] sample_mask,verified_mask,
 output reg located,output wire [7:0] diagnostic
);
wire [9:0] luma_sum={2'd0,rgb[95:88]}+{1'd0,rgb[87:80],1'b0}+{2'd0,rgb[79:72]};
reg a_d;reg [10:0] x_d;reg [9:0] y_d;reg [7:0] gray_d;
wire scan_row=y_d>=Y0 && y_d<Y1 && ((y_d-Y0)%STEP_Y)==0;
reg running,left_ok,pending,left_margin,previous_valid;
reg [10:0] first,last,pending_center,previous_center;
reg [6:0] pending_width,previous_width;
reg [3:0] dark_count;reg [1:0] mid_count;
reg [2:0] count,p1_count,p2_count,best_count,seed_count;
reg [10:0] centers [0:3],p1_x [0:3],p2_x [0:3],best_x [0:3],seed_x [0:3];
reg [6:0] widths [0:3],p1_w [0:3],p2_w [0:3];
reg [9:0] p1_y,p2_y,best_y,seed_y;
reg [8:0] best_score;
reg [3:0] reason;
wire [11:0] run_width={1'b0,last}-{1'b0,first}+12'd4;
wire [11:0] midpoint={1'b0,first}+{1'b0,last}+12'd4;
wire safe_pending=pending_center-OFFSET_X>=X0+CORE/2+16 && pending_center-OFFSET_X<=X1-CORE/2-16;
wire pair_ok=previous_valid && pending_center>previous_center &&
 pending_center-previous_center>=PITCH-PITCH_TOL && pending_center-previous_center<=PITCH+PITCH_TOL;
wire previous_safe=previous_center-OFFSET_X>=X0+CORE/2+16 && previous_center-OFFSET_X<=X1-CORE/2-16;
wire [8:0] row_score={2'd0,p1_w[0]}+{2'd0,p1_w[1]}+{2'd0,p1_w[2]}+{2'd0,p1_w[3]};
localparam CENTER_Y=(Y0+Y1)/2;
// A quantized maximum can span several rows. Move from a tapering shoulder
// toward the wider adjacent chord instead of treating the shoulder as center.
wire [9:0] candidate_y=widths[0]>p2_w[0] ? p1_y+STEP_Y : widths[0]<p2_w[0] ? p1_y-STEP_Y : p1_y;
wire [9:0] row_distance=candidate_y>=CENTER_Y ? candidate_y-CENTER_Y : CENTER_Y-candidate_y;
wire [9:0] best_distance=best_y>=CENTER_Y ? best_y-CENTER_Y : CENTER_Y-best_y;
reg shape_ok;reg [3:0] matched;integer k,j;
always @* begin
 shape_ok=count>=2 && count==p1_count && count==p2_count && p1_y==p2_y+STEP_Y && y_d==p1_y+STEP_Y;
 for(k=0;k<4;k=k+1) if(k<count) begin
  if((centers[k]>=p1_x[k] ? centers[k]-p1_x[k] : p1_x[k]-centers[k])>8 ||
     (p2_x[k]>=p1_x[k] ? p2_x[k]-p1_x[k] : p1_x[k]-p2_x[k])>8 ||
     widths[k]>p1_w[k]+8 || p2_w[k]>p1_w[k]+8 ||
     {widths[k],1'b0}<p1_w[k] || {p2_w[k],1'b0}<p1_w[k] ||
     p1_w[k]<widths[k] || p1_w[k]<p2_w[k] ||
     (p1_w[k]<widths[k]+4 && p1_w[k]<p2_w[k]+4)) shape_ok=0;
 end
 matched=0;
 for(k=0;k<4;k=k+1) for(j=0;j<4;j=j+1)
  if(sample_mask[k] && j<best_count &&
     (sample_x0[k*11+:11]>=best_x[j]-OFFSET_X-CORE/2 ?
       sample_x0[k*11+:11]-(best_x[j]-OFFSET_X-CORE/2) :
       (best_x[j]-OFFSET_X-CORE/2)-sample_x0[k*11+:11])<=VERIFY_X &&
     (sample_y0[k*10+:10]>=best_y+OFFSET_Y-CORE/2 ?
       sample_y0[k*10+:10]-(best_y+OFFSET_Y-CORE/2) :
       (best_y+OFFSET_Y-CORE/2)-sample_y0[k*10+:10])<=VERIFY_Y) matched[k]=1;
end
assign diagnostic={reason,located,best_count>=2 ? 3'b111 : 3'b000};
integer i;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  a_d<=0;x_d<=0;y_d<=0;gray_d<=0;running<=0;left_ok<=0;pending<=0;left_margin<=0;previous_valid<=0;
  first<=0;last<=0;pending_center<=0;previous_center<=0;pending_width<=0;previous_width<=0;dark_count<=0;mid_count<=0;
  count<=0;p1_count<=0;p2_count<=0;best_count<=0;seed_count<=0;p1_y<=0;p2_y<=0;best_y<=CENTER_Y;seed_y<=CENTER_Y;best_score<=0;
  sample_x0<=0;sample_y0<=0;sample_mask<=0;verified_mask<=0;located<=0;reason<=1;
  for(i=0;i<4;i=i+1) begin centers[i]<=0;widths[i]<=0;p1_x[i]<=0;p2_x[i]<=0;p1_w[i]<=0;p2_w[i]<=0;best_x[i]<=0;seed_x[i]<=0;end
 end else begin
  a_d<=accept;x_d<=x;y_d<=y;gray_d<=luma_sum[9:2];
  if(frame_start) begin
   a_d<=0;running<=0;pending<=0;previous_valid<=0;dark_count<=0;mid_count<=0;left_margin<=0;
   count<=0;p1_count<=0;p2_count<=0;best_count<=0;best_score<=0;located<=0;verified_mask<=0;reason<=1;
   for(i=0;i<4;i=i+1) begin
    sample_mask[i]<=i<seed_count;
    sample_x0[i*11+:11]<=seed_x[i]-OFFSET_X-CORE/2;
    sample_y0[i*10+:10]<=seed_y+OFFSET_Y-CORE/2;
   end
  end else if(invalidate) begin
   seed_count<=0;sample_mask<=0;verified_mask<=0;best_count<=0;located<=1;reason<=7;
  end else begin
   if(a_d && scan_row && x_d>=X0 && x_d<X1) begin
    if(x_d==X0) begin
     running<=0;pending<=0;previous_valid<=0;dark_count<=gray_d<=100 ? 1 : 0;mid_count<=0;left_margin<=0;count<=0;
     for(i=0;i<4;i=i+1) widths[i]<=0;
    end else begin
     if(gray_d>=120) begin
      dark_count<=0;mid_count<=0;left_margin<=0;pending<=0;
      if(!running) begin first<=x_d;left_ok<=dark_count>=2 || (left_margin && mid_count<=2);end
      running<=1;last<=x_d;
     end else begin
      running<=0;
      if(gray_d<=100) begin
       mid_count<=0;left_margin<=0;if(dark_count!=15) dark_count<=dark_count+1'b1;
      end else begin
       dark_count<=0;if(mid_count!=3) mid_count<=mid_count+1'b1;
       if(running || pending) left_margin<=0;
       else if(dark_count>=2) left_margin<=1;
       else if(mid_count>=2) left_margin<=0;
       if(mid_count>=2 || dark_count!=0) pending<=0;
      end
      if(running) begin
       pending<=left_ok && run_width>=20 && run_width<=64;
       pending_center<=midpoint[11:1];pending_width<=run_width[6:0];
      end else if(pending && gray_d<=100 && dark_count>=1) begin
       pending<=0;previous_valid<=1;previous_center<=pending_center;previous_width<=pending_width;
       if(pair_ok && safe_pending) begin
        if(count==0 && previous_safe) begin
         centers[0]<=previous_center;widths[0]<=previous_width;centers[1]<=pending_center;widths[1]<=pending_width;count<=2;
        end else if(count<4) begin centers[count]<=pending_center;widths[count]<=pending_width;count<=count+1'b1;end
       end
      end
     end
    end
    if(x_d==X1-4) begin
     if(shape_ok && (row_score>best_score || (row_score==best_score && row_distance<best_distance))) begin
      best_count<=p1_count;best_y<=candidate_y;best_score<=row_score;
      for(i=0;i<4;i=i+1) best_x[i]<=p1_x[i];
     end
     p2_count<=p1_count;p1_count<=count;p2_y<=p1_y;p1_y<=y_d;
     for(i=0;i<4;i=i+1) begin p2_x[i]<=p1_x[i];p1_x[i]<=centers[i];p2_w[i]<=p1_w[i];p1_w[i]<=widths[i];end
    end
   end
   if(a_d && y_d==Y1 && x_d==X0) begin
    located<=1;verified_mask<=matched;
    reason<=best_count<2 ? 2 : sample_mask==0 ? 5 : matched==0 ? 6 : 0;
   end
   if(frame_commit) begin
    seed_count<=best_count;seed_y<=best_y;
    for(i=0;i<4;i=i+1) seed_x[i]<=best_x[i];
   end
  end
 end
end
endmodule

// Shared PPC4 luma and shared incoming Sobel magnitudes, four small accumulator
// banks. One 21-cycle constant-area divider emits each bank after row 456.
// Packet per bank, low to high: GS24,EC13,max8,min8,mean8,state2,valid1,Y0_10,X0_11.
module multi_pocket_statistics(
 input wire clk,rst_n,frame_start,pixel_sof,accept,commit,invalidate,
 input wire [10:0] x,input wire [9:0] y,input wire [95:0] rgb,
 input wire [43:0] x0,input wire [39:0] y0,input wire [3:0] sample_mask,verified_mask,
 input wire edge_valid,input wire [10:0] edge_x,input wire [9:0] edge_y,
 input wire [43:0] magnitudes,input wire [3:0] edge_neighborhood,
 input wire [1:0] mode,input wire calibration_ok,present_high,input wire [7:0] threshold,
 output reg [339:0] records,output reg sample_new
);
wire [9:0] luma [0:3];reg [7:0] gray [0:3];reg accept_d,accept_dd;
reg edge_d,edge_dd;reg [43:0] magnitude_d;
genvar p,l;
generate for(l=0;l<4;l=l+1) begin : luma_lane
 assign luma[l]={2'd0,rgb[95-l*24-:8]}+{1'd0,rgb[87-l*24-:8],1'b0}+{2'd0,rgb[79-l*24-:8]};
 always @(posedge clk) gray[l]<=luma[l][9:2];
end endgenerate
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin accept_d<=0;accept_dd<=0;edge_d<=0;edge_dd<=0;magnitude_d<=0;end
 else begin accept_d<=accept;accept_dd<=accept_d;edge_d<=edge_valid;edge_dd<=edge_d;magnitude_d<=magnitudes;
  if(frame_start || pixel_sof || invalidate) begin accept_d<=0;accept_dd<=0;edge_d<=0;edge_dd<=0;end
 end
end
wire [20:0] sums [0:3];wire [12:0] pixels [0:3],edge_pixels [0:3],counts [0:3];
wire [23:0] strengths [0:3];wire [7:0] lows [0:3],highs [0:3];wire [3:0] scene;
generate for(p=0;p<4;p=p+1) begin : pocket
 wire [10:0] bx=x0[p*11+:11];wire [9:0] by=y0[p*10+:10];
 reg [3:0] selected,left_s,right_s,dark,edge_s;
 reg [10:0] beat_sum;reg [2:0] beat_count,left_n,right_n,left_dark_n,right_dark_n,edge_n,edge_on;
 reg [12:0] beat_strength;reg [7:0] beat_min,beat_max;
 reg [20:0] sum;reg [12:0] count,ec,ep;reg [23:0] es;
 reg [10:0] lc,rc,ld,rd;reg [7:0] lo,hi;
 wire [7:0] c [0:3],low_c [0:3];wire [10:0] m [0:3];wire [3:0] on;
 for(l=0;l<4;l=l+1) begin : lane
  assign c[l]=selected[l] ? gray[l] : 0;
  assign low_c[l]=selected[l] ? gray[l] : 255;
  assign m[l]=edge_s[l] ? magnitude_d[l*11+:11] : 0;
  assign on[l]=edge_s[l] && magnitude_d[l*11+:11]>=80;
 end
 wire [7:0] lo01=low_c[0]<low_c[1] ? low_c[0] : low_c[1],lo23=low_c[2]<low_c[3] ? low_c[2] : low_c[3];
 wire [7:0] hi01=c[0]>c[1] ? c[0] : c[1],hi23=c[2]>c[3] ? c[2] : c[3];
 integer i;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin selected<=0;left_s<=0;right_s<=0;dark<=0;edge_s<=0;
   beat_sum<=0;beat_count<=0;left_n<=0;right_n<=0;left_dark_n<=0;right_dark_n<=0;edge_n<=0;edge_on<=0;beat_strength<=0;beat_min<=255;beat_max<=0;
  end else begin
   for(i=0;i<4;i=i+1) begin
    selected[i]<=sample_mask[p] && x+i>=bx && x+i<bx+80 && y>=by && y<by+80;
    left_s[i]<=sample_mask[p] && x+i>=bx-16 && x+i<bx && y>=by && y<by+80;
    right_s[i]<=sample_mask[p] && x+i>=bx+80 && x+i<bx+96 && y>=by && y<by+80;
    dark[i]<=luma[i][9:2]<=100;
    edge_s[i]<=sample_mask[p] && edge_neighborhood[i] && edge_x+i>=bx && edge_x+i<bx+80 && edge_y>=by && edge_y<by+80;
   end
   beat_sum<=({3'd0,c[0]}+{3'd0,c[1]})+({3'd0,c[2]}+{3'd0,c[3]});
   beat_count<=({2'd0,selected[0]}+{2'd0,selected[1]})+({2'd0,selected[2]}+{2'd0,selected[3]});
   beat_min<=lo01<lo23 ? lo01 : lo23;beat_max<=hi01>hi23 ? hi01 : hi23;
   left_n<=({2'd0,left_s[0]}+{2'd0,left_s[1]})+({2'd0,left_s[2]}+{2'd0,left_s[3]});
   right_n<=({2'd0,right_s[0]}+{2'd0,right_s[1]})+({2'd0,right_s[2]}+{2'd0,right_s[3]});
   left_dark_n<=({2'd0,(left_s[0] && dark[0])}+{2'd0,(left_s[1] && dark[1])})+({2'd0,(left_s[2] && dark[2])}+{2'd0,(left_s[3] && dark[3])});
   right_dark_n<=({2'd0,(right_s[0] && dark[0])}+{2'd0,(right_s[1] && dark[1])})+({2'd0,(right_s[2] && dark[2])}+{2'd0,(right_s[3] && dark[3])});
   edge_n<=({2'd0,edge_s[0]}+{2'd0,edge_s[1]})+({2'd0,edge_s[2]}+{2'd0,edge_s[3]});
   edge_on<=({2'd0,on[0]}+{2'd0,on[1]})+({2'd0,on[2]}+{2'd0,on[3]});
   beat_strength<=({2'd0,m[0]}+{2'd0,m[1]})+({2'd0,m[2]}+{2'd0,m[3]});
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin sum<=0;count<=0;lo<=255;hi<=0;lc<=0;rc<=0;ld<=0;rd<=0;ec<=0;ep<=0;es<=0;end
  else if(frame_start || pixel_sof || invalidate) begin sum<=0;count<=0;lo<=255;hi<=0;lc<=0;rc<=0;ld<=0;rd<=0;ec<=0;ep<=0;es<=0;end
  else begin
   if(accept_dd) begin
    sum<=sum+beat_sum;count<=count+beat_count;
    if(beat_count!=0) begin if(beat_min<lo) lo<=beat_min;if(beat_max>hi) hi<=beat_max;end
    lc<=lc+left_n;rc<=rc+right_n;ld<=ld+left_dark_n;rd<=rd+right_dark_n;
   end
   if(edge_dd) begin ep<=ep+edge_n;ec<=ec+edge_on;es<=es+beat_strength;end
  end
 end
 assign sums[p]=sum;assign pixels[p]=count;assign lows[p]=lo;assign highs[p]=hi;
 assign counts[p]=ec;assign edge_pixels[p]=ep;assign strengths[p]=es;
 assign scene[p]=lc==1280 && rc==1280 && ld>=960 && rd>=960;
end endgenerate
reg busy;reg [1:0] bank;reg [4:0] bits_left;
reg [20:0] shift,quotient;reg [12:0] remainder;
wire [13:0] trial={remainder,shift[20]};wire take=trial>=14'd6400;
wire [20:0] next_quotient={quotient[19:0],take};
wire gray_present=present_high ? sums[bank]>={13'd0,threshold}*21'd6400 : sums[bank]<={13'd0,threshold}*21'd6400;
wire [1:0] gray_class=gray_present ? 2'd2 : 2'd3;
wire [1:0] edge_class=counts[bank]>=96 && strengths[bank]>=32768 ? 2'd2 :
 counts[bank]<=48 && strengths[bank]<=16384 ? 2'd3 : 2'd1;
wire valid=verified_mask[bank] && pixels[bank]==6400 && scene[bank] && (!mode[1] || edge_pixels[bank]==6400);
wire [1:0] state=!calibration_ok ? 2'd0 : !valid ? 2'd1 : !mode[1] ? gray_class :
 mode[0] && gray_class!=edge_class ? 2'd1 : edge_class;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin records<=0;sample_new<=0;busy<=0;bank<=0;bits_left<=0;shift<=0;quotient<=0;remainder<=0;end
 else begin
  sample_new<=0;
  if(frame_start || pixel_sof || invalidate) begin records<=0;busy<=0;end
  else if(commit) begin busy<=1;bank<=0;bits_left<=21;shift<=sums[0];quotient<=0;remainder<=0;end
  else if(busy) begin
   shift<={shift[19:0],1'b0};quotient<=next_quotient;remainder<=take ? trial-14'd6400 : trial;
   bits_left<=bits_left-1'b1;
   if(bits_left==1) begin
    records[bank*85+:85]<={x0[bank*11+:11],y0[bank*10+:10],valid,state,next_quotient[7:0],lows[bank],highs[bank],counts[bank],strengths[bank]};
    if(bank==3) begin busy<=0;sample_new<=1;end
    else begin bank<=bank+1'b1;bits_left<=21;shift<=sums[bank+1'b1];quotient<=0;remainder<=0;end
   end
  end
 end
end
endmodule
