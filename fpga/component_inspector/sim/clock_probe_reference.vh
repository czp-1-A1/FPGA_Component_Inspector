// UI reference uses frozen row strings/font bytes, independent of DUT selection logic.
 reg [7:0] reference_font [0:895];
 initial $readmemh("clock_probe_font.mem",reference_font);
 function automatic [23:0] osd_reference(input integer xx,yy,input [23:0] background,input [193:0] data);
  reg [8*40-1:0] row_text; reg [7:0] cc; integer row,col,bit_x,bit_y;
  begin
   osd_reference=background;
   if(xx>=16 && xx<656 && yy>=16 && yy<112)begin
    osd_reference=0;
    if(xx>=32 && xx<624 && yy>=32 && yy<96)begin
     row=(yy-32)/16;col=(xx-32)/16;bit_x=((xx-32)%16)/2;bit_y=((yy-32)%16)/2;
     case(row)
      0:$sformat(row_text,"F CLOCK PROBE VALID %0d%0d",data[192],data[193]);
      1:$sformat(row_text,"720 P%08X H%08X V%08X",data[95:64],data[63:32],data[31:0]);
      2:$sformat(row_text,"FHD P%08X H%08X V%08X",data[191:160],data[159:128],data[127:96]);
      3:row_text="50M REF / 1S WINDOW HEX";
     endcase
     // Verilog strings are right justified; extend their visible length with spaces.
     if(row==0)begin if(col<22)cc=row_text[(21-col)*8+:8];else cc=32;end
     else if(row==3)begin if(col<23)cc=row_text[(22-col)*8+:8];else cc=32;end
     else begin if(col<33)cc=row_text[(32-col)*8+:8];else cc=32;end
     if(cc>=97 && cc<=102)cc=cc-32; // %X in ModelSim10.5 still emits lower-case hex.
     if(bit_y<7 && reference_font[cc*7+bit_y][7-bit_x])osd_reference=24'hffffff;
    end
   end
  end
 endfunction
