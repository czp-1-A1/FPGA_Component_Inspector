`timescale 1ns/1ps
module tb_recovery_protection;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0,clear_all=0,bad=0,sample=0;
reg [31:0] source=0;reg [63:0] configuration=123;reg [607:0] objects=0;
wire busy,ev;wire [2:0] state;wire [3:0] reason;wire [8:0] total,pt,et,id;
wire [31:0] ef;wire [1:0] ek;wire [15:0] diagnostic;
classified_pocket_counter #(.RECORD_ONLY(1),.HYST(4),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1)) dut(
 .clk(clk),.rst_n(rst_n),.start_run(start),.finish_run(clear_all),.frame_bad(bad),.sample_new(sample),.frame_id(source),.config_tag(configuration),.objects(objects),
 .busy(busy),.state(state),.reason(reason),.total(total),.present_total(pt),.empty_total(et),.event_valid(ev),.event_id(id),.event_frame(ef),.event_kind(ek),.diagnostic(diagnostic),.ledger_address(9'd511),.empty_address(9'd511));
integer checks=0,events=0,n,base_total,last_frame,last_kind;reg [31:0] saved_valid;reg [15:0] saved_diagnostic;
function [75:0] obj(input integer x,k);
begin obj={1'b1,k[1:0],4'd0,13'd100,7'd38,7'd38,11'(x-4),11'(x+4),10'd312,10'd328};end endfunction
task check(input bit good,input string text);begin checks++;if(!good)$fatal(1,"%s state%0d C%0d total%0d source%0d",text,state,reason,total,source);end endtask
task tick(input integer cycles);begin repeat(cycles)@(negedge clk);end endtask
task send(input integer x,k,other);
integer cycles;begin
 objects={456'd0,obj(other,2),obj(x,k)};
 @(negedge clk);source++;sample=1;@(negedge clk);sample=0;tick(2);cycles=0;
 while(busy)begin tick(1);cycles++;check(cycles<2500,"bounded per-source processing");end tick(2);
end endtask
task restart;
begin @(negedge clk);start=1;@(negedge clk);start=0;events=0;tick(4);end endtask
task warm;
begin restart();for(n=0;n<11;n++)send(540+n*8,3,590+n*8);check(state==2,"acquire real direction");end endtask
always @(negedge clk)if(ev)begin events++;last_frame=ef;last_kind=ek;check(id==events,"number once in each run");end
initial begin
 tick(5);rst_n=1;warm();base_total=total;saved_valid=dut.valid_tracks;
 // Duplicate shared observations alias one identity. The entire sample must
 // roll back, not mutate an old track or allocate a phantom physical pocket.
 send(628,3,628);check(state==5 && reason==3 && total==base_total,"ambiguous packet enters recoverable HOLD without event");
 check(dut.valid_tracks==saved_valid && diagnostic!=0,"transaction rolls back identity allocation and records detail");saved_diagnostic=diagnostic;
 send(636,3,686);check(state==2 && total==base_total,"real unique return resumes without synthetic crossing");
 send(648,3,698);check(state==2 && total==base_total+1 && last_frame==source && last_kind==3,"actual crossing after recovery uses actual class/source");
 check(diagnostic==saved_diagnostic,"first-fault detail is sticky after recovery");
 // Duplicate display/sample source cannot emit again.
 @(negedge clk);sample=1;@(negedge clk);sample=0;tick(700);check(total==base_total+1 && !busy,"repeated source cannot count");
 bad=1;tick(1);bad=0;tick(4);check(state==3 && reason==6,"bad frame remains strict");
 send(660,3,710);check(state==3 && total==base_total+1,"bad-frame LOST never auto-resumes");
 warm();configuration++;send(628,3,678);check(state==3 && reason==6,"configuration change remains strict");
 warm();source++;send(628,3,678);check(state==3 && reason==6,"missing source frame remains strict");
 warm();send(604,3,654);send(588,3,638);check(state==3 && reason==5,"sustained reverse remains strict");
 warm();base_total=total;
 objects={304'd0,obj(620,3),228'd0,obj(620,3)};
 @(negedge clk);source++;sample=1;@(negedge clk);sample=0;tick(800);check(state==3 && reason==2 && total==base_total,"two active ROI rows remain strict");
 @(negedge clk);clear_all=1;@(negedge clk);clear_all=0;tick(5);
 check(state==0 && total==0 && pt==0 && et==0 && diagnostic==0,"explicit clear resets result and fault without reset");
 $display("PASS recovery protection: %0d checks, transactional ambiguity, real return/source/class, duplicate, bad frame/config/gap/reverse/multiROI, full clear",checks);$finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule
