// Three-clock pipeline, same as experiment_osd. Decimal conversion is shared
// and completed in the header, never divided in the active-pixel path.
module classified_count_renderer #(parameter WIDTH=1280,HEIGHT=720,RECORD_ONLY=0,RECOVERABLE=0,LOCAL_RECOVERY=0,MULTITHRESHOLD_EMPTY=0)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [255:0] live_record,frame_record,input wire [303:0] objects,
 input wire eligible,input wire [15:0] exposure,gain,fps,
 output reg out_vs,out_hs,out_de,original_logo,output reg [23:0] out_rgb
);
 reg vs_d,de_d;reg [10:0] x;reg [9:0] y;
 wire start=de && !de_d && y==0;
 reg [255:0] live,record;reg [151:0] boxes;reg show;
 reg [15:0] ex,ga,fp;
 wire [8:0] live_gap=LOCAL_RECOVERY ? (live[57] ? live[102:94] : live[120:112]) : 9'd0;
 reg [8:0] record_gap;
 reg observed_valid;reg [2:0] observed_present,observed_empty,observed_unknown;
 function [2:0] observations;
  input [303:0] data;input [1:0] kind;
  integer i;
  begin observations=0;
   for(i=0;i<4;i=i+1)if(data[i*76+75] && data[i*76+73+:2]==kind)observations=observations+1'b1;
  end
 endfunction
 reg [4:0] fmt;reg [4:0] bit_index;reg formatting;
 reg [15:0] number,cache[0:20];reg [19:0] bcd,adjusted;
 reg [15:0] next_number;integer digit;
 always @*begin
  next_number=0;
  case(fmt)
   0:next_number={7'd0,live[66:58]};1:next_number={7'd0,live[75:67]};
   2:next_number={7'd0,live[84:76]};3:next_number={7'd0,live[93:85]};
   4:next_number=RECORD_ONLY ? live[239:224] : live[47:32];5:next_number={7'd0,live[210:202]};
   6:next_number={7'd0,live[130+:9]};
   7:next_number={7'd0,live[139+:9]};
   8:next_number={7'd0,live[148+:9]};
   9:next_number={7'd0,live[157+:9]};
   10:next_number={7'd0,live[166+:9]};
   11:next_number={7'd0,live[175+:9]};
   12:next_number={7'd0,live[184+:9]};
   13:next_number={7'd0,live[193+:9]};
   14:next_number=ex;15:next_number=ga;16:next_number=fp;
   17:next_number={10'd0,live[222:217]}+1'b1;
   18:next_number={7'd0,record[94+:9]};19:next_number={7'd0,record[103+:9]};
   20:next_number={7'd0,live_gap};
  endcase
  adjusted=bcd;
  for(digit=0;digit<5;digit=digit+1)
   if(bcd[digit*4+:4]>=5)adjusted[digit*4+:4]=bcd[digit*4+:4]+3;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   vs_d<=0;de_d<=0;x<=0;y<=0;live<=0;record<=0;boxes<=0;show<=0;ex<=0;ga<=0;fp<=0;
   fmt<=0;bit_index<=0;formatting<=0;number<=0;bcd<=0;
   record_gap<=0;observed_valid<=0;observed_present<=0;observed_empty<=0;observed_unknown<=0;
  end else begin
   vs_d<=vs;de_d<=de;
   if(vs)begin x<=0;y<=0;end
   else if(de)x<=x+1'b1;else if(de_d)begin x<=0;y<=y+1'b1;end
   if(start)begin
    live<=live_record;record<=frame_record;
    record_gap<=LOCAL_RECOVERY ? (frame_record[57] ? frame_record[102:94] : frame_record[120:112]) : 9'd0;
    record[129:94]<=frame_record[57] ? {18'd0,frame_record[129:112]} : {18'd0,frame_record[111:94]};
    boxes<=frame_record[57] ? objects[303:152] : objects[151:0];
    show<=eligible && (frame_record[50:48]==1 || frame_record[50:48]==2 || (RECOVERABLE && frame_record[50:48]==5)) &&
     (live_record[50:48]==1 || live_record[50:48]==2 || (RECOVERABLE && live_record[50:48]==5));
    observed_valid<=eligible;
    observed_present<=observations(objects,2);observed_empty<=observations(objects,3);observed_unknown<=observations(objects,1);
    ex<=exposure;ga<=gain;fp<=fps;fmt<=0;bit_index<=0;formatting<=1;
   end else if(formatting)begin
    if(bit_index==0)begin number<=next_number;bcd<=0;bit_index<=1;end
    else begin
     bcd<={adjusted[18:0],number[15]};number<={number[14:0],1'b0};
     if(bit_index==16)begin
      cache[fmt]<={adjusted[14:0],number[15]};bit_index<=0;
      if(fmt==(LOCAL_RECOVERY ? 20 : 19))formatting<=0;else fmt<=fmt+1'b1;
     end else bit_index<=bit_index+1'b1;
    end
   end
  end
 end
 function [7:0] decchar;
  input [15:0] val;input integer pos;
  begin case(pos)0:decchar="0"+val[11:8];1:decchar="0"+val[7:4];default:decchar="0"+val[3:0];endcase end
 endfunction
 function [7:0] hexchar;
  input [3:0] val;begin hexchar=val<10 ? "0"+val : "A"+val-10;end
 endfunction
 function [7:0] static_char;
  input [2:0] line;input [6:0] column_index;
  reg [639:0] text;
  begin
   case(line)
    0:text=MULTITHRESHOLD_EMPTY ? "FIXED ROI RECORDER / SHARED CLASSIFIER / SW4 DOWN / R12                         " : LOCAL_RECOVERY ? "FIXED ROI RECORDER / SHARED CLASSIFIER / SW4 DOWN / R11                         " : RECOVERABLE ? "FIXED ROI RESULT RECORDER / SHARED CLASSIFIER / SW4 DOWN / R10                  " : RECORD_ONLY ? "FIXED ROI RESULT RECORDER / SHARED CLASSIFIER / SW4 DOWN / R8                   " : "FIXED ROI COUNTER / SHARED CLASSIFIER / SW4 DOWN / R4                           ";
    1:text=RECORD_ONLY ? "STATE          TOTAL 000  PRESENT 000  EMPTY 000  REVIEW 000    C:0             " : "STATE          TOTAL 000  PRESENT 000  EMPTY 000  REVIEW 000                    ";
    2:text=RECORD_ONLY ? "RUN 000  LAST N000             SW3 DOWN START / K3+K4 HOLD 1S CLEAR ALL         " : "RUN 000  LAST N000              K1+K4 HOLD 1S START / K3+K4 HOLD 1S FINISH      ";
    3:text="EMPTY IDS PAGE 000:  000 000 000 000 000 000 000 000                            ";
    4:text="LAST CLASS              REASON 0   TRACK CODE 0   LIMIT 300                     ";
    5:text="SOURCE FRAME 00000000   EXP 0000  GAIN 0000  FPS 000   REGION 0   DIR ?         ";
    6:text=RECOVERABLE ? "FRAME OBS P:0 E:0 U:0 | FIRST FAULT 0000 / SHARED SOURCE RESULTS                " : RECORD_ONLY ? "FRAME OBS P:0 E:0 U:0 | SHARED RESULTS / CENTRE CROSSING / SOURCE FRAME         " : "FRAME OBS P:0 E:0 U:0 | EMPTY PROBE:-------- | SAME DISPLAYED SOURCE FRAME      ";
    default:text="SINGLE TAPE IN FIXED ROI / COMPLETE CROSSING / UNKNOWN STOPS                    ";
   endcase
   static_char=column_index<80 ? text[(79-column_index)*8+:8] : 8'd32;
  end
 endfunction
 reg [7:0] glyph;reg [3:0] row,col;reg panel,guide;reg [23:0] ink;
 reg [2:0] line;reg [6:0] column_index;integer t,label_x,label_y,label_cell;
 reg [75:0] ob;reg [10:0] center_x;reg [9:0] center_y;reg [8:0] id;
 always @*begin
  glyph=32;row=y[3:0];col=x[2:0];panel=0;guide=0;ink=24'h70ffdd;line=0;column_index=0;
  ob=0;center_x=0;center_y=0;id=0;label_x=0;label_y=0;label_cell=0;
  if(y<80 || y>=HEIGHT-96)begin
   panel=1;
   if(x>=136 && x<776)begin
    column_index=(x-136)>>3;col=(x-136)&7;
    if(y>=8 && y<24)begin line=0;row=y-8;glyph=static_char(line,column_index);end
    if(y>=32 && y<48)begin
     line=1;row=y-32;glyph=static_char(line,column_index);
     case(live[50:48])
      0:if(column_index>=6 && column_index<11)glyph=("READY" >> ((10-column_index)*8));
      1:if(column_index>=6 && column_index<13)glyph=("LOCKING" >> ((12-column_index)*8));
      2:begin
       if(live_gap!=0 && column_index>=6 && column_index<13)glyph=("RUN GAP" >> ((12-column_index)*8));
       else if(column_index>=6 && column_index<9)glyph=("RUN" >> ((8-column_index)*8));
      end
      3:if(column_index>=6 && column_index<10)glyph=("LOST" >> ((9-column_index)*8));
      4:if(column_index>=6 && column_index<10)glyph=("DONE" >> ((9-column_index)*8));
      5:if(RECOVERABLE && column_index>=6 && column_index<10)glyph=("HOLD" >> ((9-column_index)*8));
      6:if(RECOVERABLE && column_index>=6 && column_index<11)glyph=("CHECK" >> ((10-column_index)*8));
     endcase
     if(column_index>=21 && column_index<24)glyph=decchar(cache[0],column_index-21);
     if(column_index>=34 && column_index<37)glyph=decchar(cache[1],column_index-34);
     if(column_index>=45 && column_index<48)glyph=decchar(cache[2],column_index-45);
     if(column_index>=57 && column_index<60)glyph=decchar(cache[3],column_index-57);
     if(RECORD_ONLY && column_index==66)glyph=hexchar(live[54:51]);
    end
    if(y>=56 && y<72)begin
     row=y-56;glyph=static_char(2,column_index);
     if(live_gap!=0 && column_index==14)glyph="R";
     if(column_index>=4 && column_index<7)glyph=decchar(cache[4],column_index-4);
     if(column_index>=15 && column_index<18)glyph=decchar(cache[5],column_index-15);
     if(column_index>=19 && column_index<24)glyph=live[212:211]==3 ? ("EMPTY" >> ((23-column_index)*8)) : live[212:211]==2 ? ("PART " >> ((23-column_index)*8)) : 32;
    end
    if(y>=HEIGHT-88 && y<HEIGHT-72)begin
     row=y-(HEIGHT-88);glyph=static_char(3,column_index);
     if(live_gap!=0 && column_index>=6 && column_index<9)glyph=("REC" >> ((8-column_index)*8));
     if(column_index>=15 && column_index<18)glyph=decchar(cache[17],column_index-15);
     for(t=0;t<8;t=t+1)if(column_index>=21+t*4 && column_index<24+t*4)
      glyph=live[130+t*9+:9]!=0 ? decchar(cache[6+t],column_index-21-t*4) : 8'd45;
    end
    if(y>=HEIGHT-64 && y<HEIGHT-48)begin
     row=y-(HEIGHT-64);glyph=static_char(4,column_index);
     if(column_index>=11 && column_index<16)glyph=live[212:211]==3 ? ("EMPTY" >> ((15-column_index)*8)) : live[212:211]==2 ? ("PART " >> ((15-column_index)*8)) : 32;
     if(column_index==31)glyph=hexchar(live[216:213]);
     if(column_index==46)glyph=hexchar(live[54:51]);
     if(live_gap!=0)begin
      glyph=("GAP FROM R000 / PHYSICAL IDS UNCONFIRMED / CHECK TAPE                           " >> ((79-column_index)*8));
      if(column_index>=10 && column_index<13)glyph=decchar(cache[20],column_index-10);
      ink=24'hffe080;
     end
    end
    if(y>=HEIGHT-40 && y<HEIGHT-24)begin
     row=y-(HEIGHT-40);glyph=static_char(5,column_index);
     if(column_index>=13 && column_index<21)glyph=hexchar(record[(20-column_index)*4+:4]);
     if(column_index>=28 && column_index<32)glyph=column_index==28 ? "0"+cache[14][15:12] : decchar(cache[14],column_index-29);
     if(column_index>=39 && column_index<43)glyph=column_index==39 ? "0"+cache[15][15:12] : decchar(cache[15],column_index-40);
     if(column_index>=49 && column_index<52)glyph=decchar(cache[16],column_index-49);
     if(column_index==62)glyph="1"+live[57];
     if(column_index==70)glyph=!live[55] ? "?" : live[56] ? "R" : "L";
    end
    if(y>=HEIGHT-16)begin
     row=y-(HEIGHT-16);glyph=static_char(6,column_index);
     if(column_index==12)glyph=observed_valid ? "0"+observed_present : "-";
     if(column_index==16)glyph=observed_valid ? "0"+observed_empty : "-";
     if(column_index==20)glyph=observed_valid ? "0"+observed_unknown : "-";
     if(RECOVERABLE && column_index>=36 && column_index<40)glyph=hexchar(live[255-(column_index-36)*4-:4]);
     if(!RECORD_ONLY && column_index>=36 && column_index<44)glyph=observed_valid && record[255] ? hexchar(record[255-(column_index-36)*4-:4]) : "-";
    end
   end
  end else begin
   guide=((x==400 || x==879) && ((y>=240 && y<400)||(y>=432 && y<600)) && y[3]) ||
    ((y==240 || y==399 || y==432 || y==599) && x>=400 && x<880 && x[3]);
   if(x==WIDTH/2 && y>=(live[57] ? 432 : 240) && y<(live[57] ? 600 : 400) && y[2])guide=1;
   for(t=0;t<2;t=t+1)begin
    ob=boxes[t*76+:76];id=record[94+t*9+:9];
    center_x=({1'b0,ob[41:31]}+{1'b0,ob[30:20]})>>1;
    center_y=({1'b0,ob[19:10]}+{1'b0,ob[9:0]})>>1;
    if(show && ob[75] && ob[74:73]>=2)begin
     if(((x==ob[41:31] || x==ob[30:20]) && y>=ob[19:10] && y<=ob[9:0]) ||
       ((y==ob[19:10] || y==ob[9:0]) && x>=ob[41:31] && x<=ob[30:20]))guide=1;
     label_x=center_x-16;label_y=ob[9:0]+4;
     if(id!=0 && x>=label_x && x<label_x+32 && y>=label_y && y<label_y+16)begin
      panel=1;label_cell=(x-label_x)>>3;row=y-label_y;col=(x-label_x)&7;
      glyph=label_cell==0 ? (record_gap!=0 && id>=record_gap ? "R" : "N") : decchar(cache[18+t],label_cell-1);
      ink=ob[74:73]==3 ? 24'hffe080 : ob[72:69]!=0 ? 24'hff8080 : 24'h70ffdd;
     end
    end
   end
  end
 end
 reg [10:0] address;wire [7:0] bits;
 osd_ascii_rom font(clk,address,bits);
 reg [1:0] vp,hp,dp,pp,lp;reg [3:0] c0,c1;reg [23:0] rgb0,rgb1,ink0,ink1;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   address<=0;vp<=0;hp<=0;dp<=0;pp<=0;lp<=0;c0<=0;c1<=0;rgb0<=0;rgb1<=0;ink0<=0;ink1<=0;
   out_vs<=0;out_hs<=0;out_de<=0;original_logo<=0;out_rgb<=0;
  end else begin
   address<={glyph[6:0],row};vp<={vp[0],vs};hp<={hp[0],hs};dp<={dp[0],de};pp<={pp[0],panel && de};lp<={lp[0],y<80 && x<128};
   c0<=col;c1<=c0;rgb0<=guide ? 24'h00d8d0 : rgb;rgb1<=rgb0;ink0<=ink;ink1<=ink0;
   out_vs<=vp[1];out_hs<=hp[1];out_de<=dp[1];original_logo<=lp[1];
   out_rgb<=pp[1] ? (bits[7-c1] ? ink1 : 24'h142336) : rgb1;
  end
 end
endmodule
