// Track ONLY globally numbered EMPTY tasks. R27B remains the sole counter.
// Stored coordinates may be predicted for association/hints. Actuation sees
// only a unique CURRENT measured aperture, never the predicted coordinate.
module global_empty_position_tracker(
 input wire clk,rst_n,source_start,actual_motor_running,
 input wire [1:0] start_run,clear_run,good_frame,bad_frame,main_snapshot,motion_valid,seed_valid,
 input wire [25:0] motion_dx,input wire [11:0] motion_radius,
 input wire [21:0] seed_x,input wire [19:0] seed_y,
 input wire [31:0] main_run,input wire [63:0] main_frame,
 input wire [1:0] event_valid,input wire [17:0] event_id,input wire [3:0] event_kind,
 input wire [17:0] query_id,input wire [607:0] objects,
 output reg [1:0] position_new,position_fault,search_valid,
 output reg [17:0] position_id,output reg [31:0] position_run,
 output reg [63:0] position_frame,output reg [21:0] position_x,search_x,
 output reg [19:0] position_y,search_y,output reg [11:0] search_radius
);
 localparam IDLE=0,READ=1,LOAD=2,SCAN=3,WRITE=4;
 reg [2:0] phase;reg selected,last_selected;reg [4:0] index;
 reg [1:0] waiting_result,pending;
 reg [31:0] valid[0:1];reg [4:0] seed_write[0:1];
 reg signed [12:0] last_step[0:1];
 wire [34:0] read_data[0:1];wire [34:0] word=read_data[selected];
 reg [34:0] working;reg signed [12:0] step,predicted_x;
 reg [5:0] radius;reg [8:0] active_query;reg [31:0] active_frame;
 reg [15:0] active_run;reg [3:0] used_objects;reg [2:0] match_count;
 reg [1:0] candidate,chosen;reg [10:0] measured_x;reg [9:0] measured_y;
 wire [303:0] lane_objects=selected ? objects[607:304] : objects[303:0];
 reg [75:0] ob;
 always @*case(candidate)
  0:ob=lane_objects[75:0];1:ob=lane_objects[151:76];
  2:ob=lane_objects[227:152];default:ob=lane_objects[303:228];
 endcase
 wire next_selected=pending[!last_selected] ? !last_selected : last_selected;
 wire [31:0] next_frame=next_selected ? main_frame[63:32] : main_frame[31:0];
 wire [15:0] next_run=next_selected ? main_run[31:16] : main_run[15:0];
 wire [8:0] next_query=next_selected ? query_id[17:9] : query_id[8:0];
 wire signed [12:0] next_motion=next_selected ? $signed(motion_dx[25:13]) : $signed(motion_dx[12:0]);
 wire signed [12:0] next_last=next_selected ? last_step[1] : last_step[0];
 wire [5:0] next_radius=next_selected ? motion_radius[11:6] : motion_radius[5:0];
 wire [11:0] xsum={1'b0,ob[41:31]}+ob[30:20];wire [10:0] cx=xsum[11:1];
 wire [10:0] ysum={1'b0,ob[19:10]}+ob[9:0];wire [9:0] cy=ysum[10:1];
 wire signed [12:0] error_x=$signed({2'd0,cx})-predicted_x;
 wire signed [11:0] error_y=$signed({2'd0,cy})-$signed({2'd0,working[29:20]});
 wire real_match=ob[75] && ob[74:73]==3 && error_x>=-$signed({7'd0,radius}) &&
  error_x<=$signed({7'd0,radius}) && error_y>=-16 && error_y<=16;
 wire unique_match=match_count==1 && !used_objects[chosen];
 wire [10:0] saved_x=unique_match ? measured_x : predicted_x<0 ? 11'd0 : predicted_x>1279 ? 11'd1279 : predicted_x[10:0];
 wire [9:0] saved_y=unique_match ? measured_y : working[29:20];
 wire [3:0] missing=unique_match ? 4'd0 : working[33:30]==15 ? 4'd15 : working[33:30]+1'b1;
 wire [34:0] update_word={1'b0,missing,saved_y,saved_x,working[8:0]};
 wire any_seed=|(event_valid & seed_valid);
 wire new_command=|start_run || |clear_run;
 wire run_step=!new_command && !any_seed;
 genvar bank;generate for(bank=0;bank<2;bank=bank+1)begin : storage
  (* ram_style="dram" *) reg [34:0] records[0:31];reg [34:0] q;
  always @(posedge clk)begin
   if(event_valid[bank] && event_kind[bank*2+:2]==3 && seed_valid[bank])
    records[seed_write[bank]]<={1'b1,4'd0,seed_y[bank*10+:10],seed_x[bank*11+:11],event_id[bank*9+:9]};
   else if(run_step && phase==WRITE && selected==bank)records[index]<=update_word;
   q<=records[index];
  end
  assign read_data[bank]=q;
 end endgenerate
 integer lane;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   phase<=IDLE;selected<=0;last_selected<=1;index<=0;waiting_result<=0;pending<=0;
   position_new<=0;position_fault<=0;search_valid<=0;position_id<=0;position_run<=0;position_frame<=0;
   position_x<=0;position_y<=0;search_x<=0;search_y<=0;search_radius<=0;
   working<=0;step<=0;predicted_x<=0;radius<=0;active_query<=0;active_frame<=0;active_run<=0;
   used_objects<=0;match_count<=0;candidate<=0;chosen<=0;measured_x<=0;measured_y<=0;
   for(lane=0;lane<2;lane=lane+1)begin valid[lane]<=0;seed_write[lane]<=0;last_step[lane]<=0;end
  end else begin
   position_new<=0;
   for(lane=0;lane<2;lane=lane+1)begin
    if(good_frame[lane])waiting_result[lane]<=1;
    if(waiting_result[lane] && main_snapshot[lane])begin pending[lane]<=1;waiting_result[lane]<=0;end
    if(event_valid[lane] && event_kind[lane*2+:2]==3)begin
     if(!seed_valid[lane])position_fault[lane]<=1;
     else begin valid[lane][seed_write[lane]]<=1;seed_write[lane]<=seed_write[lane]+1'b1;end
    end
    if(bad_frame[lane])begin waiting_result[lane]<=0;pending[lane]<=0;end
    if(start_run[lane] || clear_run[lane])begin
     valid[lane]<=0;seed_write[lane]<=0;last_step[lane]<=0;position_fault[lane]<=0;
     waiting_result[lane]<=0;pending[lane]<=0;search_valid[lane]<=0;
    end
   end
   if(new_command)begin phase<=IDLE;pending<=0;waiting_result<=0;end
   else if(source_start && (phase!=IDLE || |pending || |waiting_result))begin position_fault<=3;phase<=IDLE;pending<=0;end
   else if(run_step)case(phase)
    IDLE:if(|pending)begin
     selected<=next_selected;last_selected<=next_selected;
     pending[next_selected]<=0;active_query<=next_query;active_frame<=next_frame;active_run<=next_run;
     step<=motion_valid[next_selected] ? next_motion : actual_motor_running ? next_last : 13'sd0;
     radius<=next_radius;search_radius[next_selected*6+:6]<=next_radius;search_valid[next_selected]<=0;
     index<=0;used_objects<=0;phase<=READ;
    end
    READ:phase<=LOAD;
    LOAD:if(!valid[selected][index])begin
     if(index==31)phase<=IDLE;else begin index<=index+1'b1;phase<=READ;end
    end else if(active_query==0 || word[8:0]<active_query)begin
     valid[selected][index]<=0;
     if(index==31)phase<=IDLE;else begin index<=index+1'b1;phase<=READ;end
    end else begin
     working<=word;predicted_x<=word[34] ? $signed({2'd0,word[19:9]}) : $signed({2'd0,word[19:9]})+step;
     match_count<=0;candidate<=0;phase<=SCAN;
    end
    SCAN:begin
     if(real_match)begin match_count<=match_count+1'b1;chosen<=candidate;measured_x<=cx;measured_y<=cy;end
     if(candidate==3)phase<=WRITE;else candidate<=candidate+1'b1;
    end
    WRITE:begin
     if(unique_match)begin
      used_objects[chosen]<=1;
      if(!working[34] && working[33:30]==0)last_step[selected]<=$signed({2'd0,measured_x})-$signed({2'd0,working[19:9]});
      if(working[8:0]==active_query && query_id[selected*9+:9]==active_query)begin
       position_new[selected]<=1;position_id[selected*9+:9]<=active_query;position_run[selected*16+:16]<=active_run;
       position_frame[selected*32+:32]<=active_frame;position_x[selected*11+:11]<=measured_x;position_y[selected*10+:10]<=measured_y;
      end
     end
     if(working[8:0]==active_query && saved_x>=48 && saved_x<=432)begin
      search_valid[selected]<=1;search_x[selected*11+:11]<=saved_x;search_y[selected*10+:10]<=saved_y;
     end
     if(index==31)phase<=IDLE;else begin index<=index+1'b1;phase<=READ;end
    end
    default:phase<=IDLE;
   endcase
  end
 end
endmodule
