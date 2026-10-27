`timescale 1ns/1ps
module tb_empty_trace_unit;
reg clk=0,rst=0,cancel=0,measure=0,region=0,ins=0,rb=0,rd=0,rr=0,rok=0,pub=0,sample=0,overflow=0;
always #5 clk=~clk;
reg [11:0] score=100;reg [10:0] x=620,refx=620;reg [9:0] y=320,refy=320,rw=5,rh=5;
wire [127:0] record;
empty_gate_trace dut(.clk(clk),.rst_n(rst),.cancel(cancel),.measure(measure),.region(region),.score(score),.x(x),.y(y),.width(5'd5),.height(5'd5),.area(18'd21),.bright(3'd4),.row_delta(11'd1),.flags(9'b111110010),
.insert(ins),.reference_begin(rb),.reference_done(rd),.reference_region(rr),.reference_x(refx),.reference_y(refy),.reference_width(rw),.reference_height(rh),.reference_ok(rok),.publish(pub),.sample(sample),.overflow(overflow),.record(record));
task tick;@(negedge clk);endtask
initial begin
 tick;rst=1;tick;measure=1;tick;measure=0;
 if(!record[63] || record[62:52]!=620 || record[127])$fatal(1,"ROI0 capture");
 score=120;x=700;measure=1;tick;measure=0;if(record[62:52]!=620)$fatal(1,"worse candidate replaced");
 region=1;y=516;x=650;score=50;measure=1;tick;measure=0;if(!record[127] || record[126:116]!=650 || record[62:52]!=620)$fatal(1,"independentROI1");
 rr=1;refx=649;refy=516;rb=1;rd=1;rok=1;pub=1;tick;rb=0;rd=0;pub=0;if(record[70:67]!=0)$fatal(1,"wrong object attached proof");
 refx=650;rw=6;rb=1;tick;rb=0;if(record[70])$fatal(1,"wrong width attached proof");
 rw=5;rb=1;tick;rb=0;rd=1;rok=1;tick;rd=0;pub=1;tick;pub=0;sample=1;tick;sample=0;
 if(record[70:67]!=4'b1111 || !record[65] || record[6:3]!=0 || !record[1])$fatal(1,"ROI1 proof/publication/completion");
 overflow=1;tick;overflow=0;if(!record[0] || !record[64])$fatal(1,"budget flag");
 cancel=1;measure=1;tick;cancel=0;measure=0;if(record!==0)$fatal(1,"cancel precedence");
 $display("PASS EMPTY_TRACE_UNIT:ROI isolation,nearest selection,exact proof binding,budget,cancel");$finish;
end
initial begin #10000;$fatal(1,"unit watchdog");end
endmodule
