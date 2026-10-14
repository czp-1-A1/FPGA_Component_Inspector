`timescale 1ns/1ps
module tb_shape_snapshot;
reg clk=0,rst=0,cancel=0,model_valid=1;
always #5 clk=~clk;
reg [17:0] tag=3;reg [31:0] wb=32'h00006464;reg [27:0] legacy=0;reg [36:0] features=0;
wire [114:0] record;
roi_observation_snapshot #(.SHAPE_MODEL(1)) dut(.clk(clk),.rst_n(rst),.invalidate(cancel),.tag(tag),.wb_tag(wb),
 .legacy_record(legacy),.core_pixels(13'd6400),.edge_count(13'd999),.edge_sum(24'habcdef),
 .model_valid(model_valid),.model_features(features),.record(record));
task tick;begin @(negedge clk);end endtask
reg [114:0] saved;
initial begin
 tick;rst=1;tick;
 features={2'b0,13'd3672,7'd68,7'd54,8'd100};legacy={1'b1,2'd2,1'b1,8'd115,8'd30,8'd180};tick;
 if(record!=={wb,features,tag,legacy})$fatal(1,"coherent model snapshot did not publish");
 saved=record;features={2'b0,13'd317,7'd21,7'd21,8'd100};wb=32'h00016464;tag=7;tick;
 if(record!==saved)$fatal(1,"live feature/tag changes tore frozen record");
 legacy={1'b0,2'd3,1'b1,8'd35,8'd30,8'd150};tick;
 if(record!=={wb,features,tag,legacy})$fatal(1,"next atomic sample mismatched");
 model_valid=0;legacy[27]=1;tick;if(record[24])$fatal(1,"incomplete model accepted");
 cancel=1;tick;cancel=0;model_valid=1;tick;if(record[24])$fatal(1,"cancel rearmed an old token");
 legacy[27]=0;tick;if(!record[24])$fatal(1,"fresh complete model failed recovery");
 rst=0;tick;if(record!=0)$fatal(1,"reset retained model record");
 $display("PASS shape snapshot: atomic 37-bit model/WB/mode/legacy tuple, no stale Sobel fields, completion token, cancellation and fresh recovery");$finish;
end
endmodule
