// Full production display path: actual FIFO/reader, phase, OSD, TMDS and PHY.
// Independent synthetic progressive camera-frame memory, never DUT coordinates.
`timescale 1ns/1fs
module tb_hd_pins;
 reg refclk=0,ddr=0,rst_n=0;always #10 refclk=~refclk;always #7.5 ddr=~ddr;
 wire pixel,serial,lock;HDMI_PLL pll(refclk,pixel,serial,lock,!rst_n);
 reg [2:0] release_q=0;always @(posedge pixel or negedge rst_n)
  if(!rst_n)release_q<=0;else release_q<={release_q[1:0],lock};
 wire prst=release_q[2];
 wire [11:0] vx,tx;wire [10:0] vy,sx,sy,ox,oy,ty;
 wire vs,hs,de,pair_vs,field,ovs,ohs,ode,opair;
 native_720p60_vtc vtc(pixel,prst,vx,vy,sx,sy,vs,hs,de,pair_vs,field);
 native_i60_phase phase(pixel,prst,vx,vy,sx,sy,vs,hs,de,pair_vs,ovs,ohs,ode,opair,ox,oy,tx,ty);
 reg startup_armed=0;
 always @(posedge pixel)if(!prst)startup_armed<=0;else if(vs)startup_armed<=1;
 reg [1:0] completed=3;wire active,display_ok,busy,request;
 wire [1:0] active_slot;wire [24:0] addr;wire [23:0] camera_rgb;
 wire [15:0] under;reg reply=0;reg [127:0] data=0;
 video_out #(.WIDTH(1280),.HEIGHT(720),.META_WIDTH(350)) reader(
  .I_rst_n(prst),.I_ddr_clk(ddr),.I_completed_metadata(350'd0),.O_active_metadata(),
  .O_video_out_rd_busy(busy),.I_video_in_wr_busy(1'b0),.I_video_out_rp(completed),
  .I_completed_valid(startup_armed),.I_completed_rp(completed),.O_active_valid(active),.O_active_rp(active_slot),
  .O_ddr_user_rd_en(request),.O_ddr_user_addr(addr),.I_ddr_user_ready(1'b1),
  .I_ddr_user_rd_valid(reply),.I_ddr_user_rd_data(data),.I_dsi_clk(pixel),
  .I_video_vsync(pair_vs),.I_video_rd_en(de),.O_vdieo_data(camera_rgb),
  .O_display_ok(display_ok),.O_underflow_frames(under));
 function automatic [23:0] image_pixel(input integer slot,x,y);
  image_pixel={2'(slot),3'(y/256),3'(x/256),8'(y%256),8'(x%256)};
 endfunction
 function automatic [127:0] memory_word(input integer a);
  integer k,slot,byte_offset,pixel_index;reg [23:0] p;
  begin
   slot=a/7000000;byte_offset=(a-slot*7000000)*2;
   for(k=0;k<16;k=k+1)begin
    pixel_index=(byte_offset+k)/3;p=image_pixel(slot,pixel_index%1280,pixel_index/1280);
    case((byte_offset+k)%3)
     0:memory_word[127-k*8-:8]=p[23:16];1:memory_word[127-k*8-:8]=p[15:8];
     2:memory_word[127-k*8-:8]=p[7:0];
    endcase
   end
  end
 endfunction
 integer queue[0:1023],wp=0,rp=0,pending=0,request_index=0,request_slot=3;
 integer source_row,word_in_row,expected_addr,requests=0,returns=0;
 always @(posedge ddr)if(request)begin
  if(request_index==172800)begin request_index=0;request_slot=completed;end
  source_row=request_index/240;
  word_in_row=request_index%240;
  expected_addr=request_slot*7000000+source_row*1920+word_in_row*8;
  if(addr!==25'(expected_addr))$fatal(1,"H DDR order index%0d got%0d expected%0d",request_index,addr,expected_addr);
  queue[wp]=addr;wp=(wp+1)%1024;pending=pending+1;requests=requests+1;request_index=request_index+1;
 end
 always @(negedge ddr)begin
  reply=0;
  if(pending>0)begin
   reply=1;data=memory_word(queue[rp]);rp=(rp+1)%1024;pending=pending-1;returns=returns+1;
  end
 end
 wire ev,eh,ed;wire [23:0] ergb;
 function [75:0] record(input integer state,reason,x0,x1,y0,y1);
  begin record={1'b1,2'(state),4'(reason),13'd4000,7'd64,7'd76,11'(x0),11'(x1),10'(y0),10'(y1)};end
 endfunction
 wire valid=1;wire [1:0] mode=3;
 wire [151:0] objects={record(3,0,1180,1202,590,612),record(2,0,1080,1148,480,560)};
experiment_osd #(.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) osd(
 .clk(pixel),.rst_n(prst),.vs(ovs),.hs(ohs),.de(ode),.rgb(camera_rgb),.exposure(16'd2244),.gain(16'd48),
 .wb_r(8'd100),.wb_b(8'd100),.wb_tune(1'b0),.wb_pending(1'b0),.view_mode(mode),.edge_count(13'd0),.edge_sum(24'd0),
 .local_box_valid(1'b1),.local_x0(11'd479),.local_x1(11'd546),.local_y0(10'd261),.local_y1(10'd340),
 .frame_objects(objects),.roi_valid(valid),.roi_mean(8'd120),.roi_min(8'd30),.roi_max(8'd180),.roi_state(2'd2),
 .width(16'd1024),.height(16'd600),.fps(16'd27),.lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .frames(32'd3),.uptime(32'd8),.cfg_done(1'b1),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .diagnostics(36'd0),.publish_diagnostic({1'b0,8'hfb,18'h2a300}),.pocket_records(340'd0),.pocket_enable(1'b0),
 .track_valid(1'b0),.track_x0(11'd0),.track_x1(11'd0),.track_reason(4'd0),.track_rows(3'd0),.out_vs(ev),.out_hs(eh),.out_de(ed),.out_rgb(ergb));
 wire bp,gp,redp,cp;
 native_i60_tx #(.INTERLACED(0)) transmitter(pixel,serial,!prst,ev,eh,ed,ergb,tx,ty,bp,gp,redp,cp);
 `include "hdmi_decode.vh"
 reg [23:0] overlay[0:921599];initial $readmemh("hd_osd_reference.hex",overlay);
 function automatic [7:0] decode_rgb(input [9:0] w);
  integer i;reg [7:0] q;begin q=w[7:0]^{8{w[9]}};decode_rgb[0]=q[0];
   for(i=1;i<8;i=i+1)decode_rgb[i]=q[i]^q[i-1]^!w[8];end
 endfunction
 reg [9:0] wb=0,wg=0,wr=0,wc=0;reg [2:0] cb,cg,cr;reg [4:0] tb,tg,tr;
 integer bits=0,words=0,rx_x=0,rx_y=0,frames=0,frame_words=0,frame_pixels=0,avis=0,k;
 integer px,py,region,slot_reference=3,rows[0:719],j;
 reg acquired=0,previous_vs=0;reg [23:0] expected,rgb;
 localparam [31:0] HB=32'he40d0282;localparam [63:0] SB=64'h050000050020004a;
 always @(posedge serial or negedge serial)begin
  #0.05;
  if(!prst)begin bits=0;wc=0;end
  else begin
   wb={bp,wb[9:1]};wg={gp,wg[9:1]};wr={redp,wr[9:1]};wc={cp,wc[9:1]};bits=bits+1;
   if(bits>=10 && wc==10'b1111100000)begin
    words=words+1;cb=hdmi_control(wb);cg=hdmi_control(wg);cr=hdmi_control(wr);
    if(acquired)begin
     rx_x=(rx_x==1649)?0:rx_x+1;
     if(rx_x==0)rx_y=(rx_y==749)?0:rx_y+1;
    end
    if(!acquired && cb[2] && cb[1])begin
     acquired=1;rx_x=0;rx_y=725;frame_words=0;frame_pixels=0;avis=0;
     for(j=0;j<720;j=j+1)rows[j]=0;
    end
    if(acquired)begin
     px=rx_x;py=rx_y;
     region=(rx_y<720 && rx_x<1280)?6:0;
     case(region)
      0,1,3:begin
       if(!cb[2] || !cg[2] || !cr[2] || cb[0]!=(rx_x>=1390 && rx_x<1430) ||
        cb[1]!=(rx_y>=725 && rx_y<730))$fatal(1,"J control/sync phase x%0d y%0d",rx_x,rx_y);
       if(cg[1:0]!=0 || cr[1:0]!=0)$fatal(1,"J DVI blanking");
      end
      2:if(wb!==10'b1011001100 || wg!==10'b0100110011 || wr!==10'b1011001100)$fatal(1,"H video guard");
      4:begin tb=hdmi_terc4(wb);if(!tb[4] || tb[3:2]!=3 || wg!==10'b0100110011 || wr!==10'b0100110011)$fatal(1,"H DI guard");end
      5:begin
       tb=hdmi_terc4(wb);tg=hdmi_terc4(wg);tr=hdmi_terc4(wr);k=rx_x-2134;
       if(!tb[4] || !tg[4] || !tr[4] || tb[3]!=1 || tb[2]!==HB[k] ||
         tg[3:0]!=={3'b000,SB[2*k]} || tr[3:0]!=={3'b000,SB[2*k+1]})$fatal(1,"H AVI");
       if(k==31)avis=avis+1;
      end
      6:begin
       rgb={decode_rgb(wr),decode_rgb(wg),decode_rgb(wb)};
       expected=overlay[py*1280+px];
       if(expected==24'h556677)expected=image_pixel(slot_reference,rx_x,rx_y);
       if(rgb!==expected)$fatal(1,"H complete display RGB frame%0d x%0d y%0d got%h expected%h",frames,px,py,rgb,expected);
       frame_pixels=frame_pixels+1;rows[rx_y]=rows[rx_y]+1;
      end
     endcase
     if(rx_y==360 && rx_x==100 && frames==0)begin
      completed=0;$display("OBS H new completed slot0 midway; active slot3 must remain for current progressive frame");
     end
     frame_words=frame_words+1;
     if(rx_x==1649 && rx_y==724)begin
      if(frame_words!=1237500 || frame_pixels!=921600 || avis!=0 || under!=0)$fatal(1,"H full pair count/underflow");
      for(j=0;j<720;j=j+1)if(rows[j]!=1280)$fatal(1,"H row coverage%0d",j);
      frames=frames+1;
      $display("OBS K native720 frame%0d all921600 pixels/720 rows/no AVI, frame slot%0d",frames,slot_reference);
      if(frames==2)begin
       if(requests!=returns || request_index!=172800)$fatal(1,"H complete DDR request accounting");
       $display("PASS hd pins: two720p60 progressive frames; actual vendor FIFO/DDR reader, phase and native720 OSD with every glyph stroke and mapped ROI border, every pixel/row/address, frame-only slot publication, DVI-compatible progressive sync; ideal PLL/vendor ODDR. Camera/physical pending.");$finish;
      end
      frame_words=0;frame_pixels=0;avis=0;slot_reference=0;
      for(j=0;j<720;j=j+1)rows[j]=0;
     end
    end
    if(words%1000000==0)$display("OBS H pin words%0d",words);
   end
  end
 end
 initial begin #10000;rst_n=1;end
 initial begin #100000000;$fatal(1,"H complete display watchdog");end
endmodule
