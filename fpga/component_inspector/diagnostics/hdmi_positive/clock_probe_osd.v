// Three equal pixel delays for RGB/DE/HS/VS. Small synchronous diagnostic font.
// Counts are hexadecimal raw events per 50M reference cycles, never presets.
module clock_probe_osd(input wire clk,rst,
 input wire [11:0] x,input wire [10:0] y,
 input wire [23:0] rgb,input wire de,hs,vs,
 input wire [193:0] snapshot,
 output reg [23:0] out_rgb,output reg out_de,out_hs,out_vs);
 reg [23:0] rgb0,rgb1;
 reg [2:0] sync0,sync1;
 reg panel0,panel1,ink1;
 reg [7:0] ch0;
 reg [2:0] col0,row0;
 reg [7:0] ch;
 wire panel=x>=16 && x<656 && y>=16 && y<112;
 wire text_area=x>=32 && x<624 && y>=32 && y<96;
 wire [5:0] cell_x=(x-12'd32)>>4;
 wire [1:0] cell_y=(y-11'd32)>>4;
 function [7:0] hex_char(input [3:0] n);
  begin hex_char=n<10?(8'd48+n):(8'd65+n-10);end
 endfunction
 function [55:0] font(input [7:0] c);
  begin case(c)
   "0":font=56'h3c42464a52623c;"1":font=56'h1838181818183c;
   "2":font=56'h3c42020408107e;"3":font=56'h3c42021c02423c;
   "4":font=56'h040c14247e0404;"5":font=56'h7e407c0202423c;
   "6":font=56'h1c20407c42423c;"7":font=56'h7e020408101010;
   "8":font=56'h3c42423c42423c;"9":font=56'h3c42423e020438;
   "A":font=56'h1824427e424242;"B":font=56'h7c42427c42427c;
   "C":font=56'h3c42404040423c;"D":font=56'h78444242424478;
   "E":font=56'h7e40407c40407e;"F":font=56'h7e40407c404040;
   "H":font=56'h4242427e424242;"I":font=56'h3c18181818183c;
   "K":font=56'h42444870484442;"L":font=56'h4040404040407e;
   "M":font=56'h42665a5a424242;"N":font=56'h4262524a464242;"O":font=56'h3c42424242423c;
   "P":font=56'h7c42427c404040;"R":font=56'h7c42427c484442;
   "S":font=56'h3c42403c02423c;"V":font=56'h42424242242418;
   "W":font=56'h4242425a5a6642;"X":font=56'h42422418244242;
   "/":font=56'h02020408102040;default:font=0;
  endcase end
 endfunction
 reg [95:0] counts;
 reg [31:0] value;
 reg [3:0] digit;
 always @* begin
  ch=" ";counts=cell_y==1?snapshot[95:0]:snapshot[191:96];value=0;digit=0;
  case(cell_y)
   0:case(cell_x)
    0:ch="F";2:ch="C";3:ch="L";4:ch="O";5:ch="C";6:ch="K";
    8:ch="P";9:ch="R";10:ch="O";11:ch="B";12:ch="E";
    14:ch="V";15:ch="A";16:ch="L";17:ch="I";18:ch="D";
    20:ch=snapshot[192]?"1":"0";21:ch=snapshot[193]?"1":"0";
    default:ch=" ";endcase
   1,2:begin
    if(cell_x==0)ch=cell_y==1?"7":"F";
    else if(cell_x==1)ch=cell_y==1?"2":"H";
    else if(cell_x==2)ch=cell_y==1?"0":"D";
    else if(cell_x==4)ch="P";
    else if(cell_x==14)ch="H";
    else if(cell_x==24)ch="V";
    else if(cell_x>=5 && cell_x<=12)begin value=counts[95:64];digit=12-cell_x;ch=hex_char((value>>(digit*4))&15);end
    else if(cell_x>=15 && cell_x<=22)begin value=counts[63:32];digit=22-cell_x;ch=hex_char((value>>(digit*4))&15);end
    else if(cell_x>=25 && cell_x<=32)begin value=counts[31:0];digit=32-cell_x;ch=hex_char((value>>(digit*4))&15);end
   end
   3:case(cell_x)
    0:ch="5";1:ch="0";2:ch="M";4:ch="R";5:ch="E";6:ch="F";
    8:ch="/";10:ch="1";11:ch="S";13:ch="W";14:ch="I";15:ch="N";
    16:ch="D";17:ch="O";18:ch="W";20:ch="H";21:ch="E";22:ch="X";
    default:ch=" ";endcase
  endcase
  if(!text_area)ch=" ";
 end
 wire [55:0] glyph=font(ch0);
 always @(posedge clk or posedge rst)
  if(rst)begin
   rgb0<=0;rgb1<=0;out_rgb<=0;sync0<=0;sync1<=0;{out_de,out_hs,out_vs}<=0;
   ch0<=32;col0<=0;row0<=0;panel0<=0;panel1<=0;ink1<=0;
  end else begin
   rgb0<=rgb;sync0<={de,hs,vs};ch0<=ch;col0<=x[3:1];row0<=y[3:1];panel0<=panel;
   rgb1<=rgb0;sync1<=sync0;panel1<=panel0;
   ink1<=row0<7 && glyph[(6-row0)*8+(7-col0)];
   out_rgb<=panel1?(ink1?24'hffffff:24'h000000):rgb1;
   {out_de,out_hs,out_vs}<=sync1;
  end
endmodule
