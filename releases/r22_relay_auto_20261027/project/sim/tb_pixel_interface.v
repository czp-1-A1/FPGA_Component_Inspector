`timescale 1ns/1ps
// TD-selected RTL and divider netlist; each runner selects its documented ERAM.
module tb_pixel_interface;
reg clk=0, rst=0, valid=0, sof=0, eol=0, ready=1;
reg [127:0] rgb128=0;
always #5 clk=~clk;
wire [95:0] rgb96, out_data;
wire out_valid, out_sof, out_eol, in_ready;
wire [127:0] packed_data;
wire packed_valid, packed_sof;
data128_96 unpack(rgb128, rgb96);
awb #(.IMG_WIDTH(1024),.IMG_HEIGHT(600)) dut(
    .I_clk(clk),.I_rst_n(rst),.I_tlast(eol),.I_tuser(sof),
    .I_tdata(rgb96),.I_tvalid(valid),.I_tready(in_ready),
    .O_tlast(out_eol),.O_tuser(out_sof),.O_tdata(out_data),
    .O_tvalid(out_valid),.O_tready(ready));
`ifdef MODELSIM_TIE_UNUSED_AWB_RAM_INPUTS
// Diagnostic only: the original signal_delay leaves these input ports open.
initial begin
    $display("OBS diagnostic override: AWB RAM web=0 and dib=0; original RTL remains unchanged");
    force dut.signal_delay_d.blk_mem_gen_awb_delay_signal_d.web = 1'b0;
    force dut.signal_delay_d.blk_mem_gen_awb_delay_signal_d.dib = 96'd0;
end
`endif
data_96bit_to_128bit pack(
    .I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(out_sof),
    .I_96b_valid(out_valid),.I_96b_data(out_data),
    .O_128b_frame_start(packed_sof),.O_128b_valid(packed_valid),
    .O_128b_data(packed_data));

reg [95:0] expected[0:2047];
reg [383:0] four_words;
reg [127:0] pack_expected[0:1535];
integer sent=0, received=0, packed_count=0, pack_sent=0;
integer cycle=0, first_in=-1, first_out=-1, last_outputs=0;
integer blocked_outputs=0, frame_events=0, packed_frame_events=0;
integer case_id=0, b, line_no, lane, byte_value, k;
reg checking=0, partial=0;
integer partial_outputs=0, partial_unknown=0;

function [127:0] word_at;
    input integer row, beat;
    integer p, v;
    begin
        // Equal R/G/B makes the real divider generate exactly unity gain.
        // Ascending lane values represent ascending x at the bilinear output.
        for(p=0;p<4;p=p+1) begin
            v=17+((row*11+beat*4+p)%173);
            word_at[p*32+:32]={8'd0,8'(v),8'(v),8'(v)};
        end
    end
endfunction

always @(posedge clk) begin
    cycle=cycle+1;
    if(checking && rst && valid) begin
        if(first_in<0) first_in=cycle;
        // The RGB boundary reverses the 32-bit bilinear groups.
        expected[sent]={rgb128[23:0],rgb128[55:32],rgb128[87:64],rgb128[119:96]};
        sent=sent+1;
        four_words={four_words[287:0],expected[sent-1]};
        if((sent%4)==0) begin
            pack_expected[pack_sent]=four_words[383:256];
            pack_expected[pack_sent+1]=four_words[255:128];
            pack_expected[pack_sent+2]=four_words[127:0];
            pack_sent=pack_sent+3;
        end
    end
    #1;
    if(checking && rst) begin
        if(out_sof) begin
            frame_events=frame_events+1;
            if(!sof) $fatal(1,"AWB SOF is expected to be direct passthrough");
        end
        if(packed_sof) packed_frame_events=packed_frame_events+1;
        if(out_valid) begin
            if(first_out<0) first_out=cycle;
            if(received>=sent || out_data!==expected[received])
                $fatal(1,"case %0d pixel beat %0d: got %h expected %h",case_id,received,out_data,expected[received]);
            received=received+1;
            if(!ready) blocked_outputs=blocked_outputs+1;
        end
        if(out_eol) begin
            last_outputs=last_outputs+1;
            if(!out_valid || (received%256)!=0)
                $fatal(1,"AWB last must accompany final valid beat, count %0d",received);
        end
        if(packed_valid) begin
            if(packed_count>=pack_sent || packed_data!==pack_expected[packed_count])
                $fatal(1,"packed byte order mismatch at word %0d",packed_count);
            packed_count=packed_count+1;
        end
    end
    if(partial && out_valid) begin
        partial_outputs=partial_outputs+1;
        if((^out_data)===1'bx) partial_unknown=partial_unknown+1;
    end
end

task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
task reset_case; input integer id; begin
    checking=0; partial=0; valid=0; sof=0; eol=0; ready=1; rst=0;
    ticks(8); rst=1; ticks(8);
    sent=0; received=0; pack_sent=0; packed_count=0; four_words=0;
    first_in=-1; first_out=-1; last_outputs=0; frame_events=0;
    packed_frame_events=0; blocked_outputs=0; case_id=id; checking=1;
end endtask

task frame; input integer bubbles; input integer block_ready;
begin
    for(line_no=0;line_no<3;line_no=line_no+1) begin
        for(b=0;b<256;b=b+1) begin
            if(bubbles && (b==10 || b==180)) begin
                valid=0; sof=0; eol=0; ticks(2);
            end
            ready=!(block_ready && b>=70 && b<130);
            rgb128=word_at(line_no,b); valid=1;
            sof=(line_no==0 && b==0); eol=(b==255); ticks(1);
        end
        valid=0; sof=0; eol=0; ready=1; ticks(100);
    end
    ticks(20);
    if(sent!=768 || received!=768 || packed_count!=576 || last_outputs!=3)
        $fatal(1,"case %0d counts in=%0d out=%0d packed=%0d eol=%0d",case_id,sent,received,packed_count,last_outputs);
    if(frame_events!=1 || packed_frame_events!=1 || first_out<=first_in)
        $fatal(1,"frame marker or pixel latency mismatch");
    $display("OBS case=%0d input-to-first-pixel=%0d clocks, SOF lead=%0d clocks, in=%0d out=%0d packed=%0d EOL=%0d",case_id,first_out-first_in,first_out-first_in,sent,received,packed_count,last_outputs);
    if(block_ready && blocked_outputs==0) $fatal(1,"ready-low test did not exercise output");
end endtask

// Separate real bilinear stage checks spatial order and distinct R/G/B channels.
reg bi_valid=0, bi_sof=0, bi_eol=0, parity=0;
reg [95:0] matrix0=0, matrix1=0, matrix2=0;
wire bi_out_valid, bi_out_sof, bi_out_eol, bi_ready;
wire [127:0] bi_rgb;
bilinear_interpolation #(.BAYER_MODE("BGGR")) bi(
    .I_clk(clk),.I_rst_n(rst),.I_tlast(bi_eol),.I_tuser(bi_sof),
    .I_tvalid(bi_valid),.I_tready(bi_ready),.bayer_ypos(parity),
    .matrix_last_line(matrix0),.matrix_cur_line(matrix1),.matrix_next_line(matrix2),
    .O_tlast(bi_out_eol),.O_tuser(bi_out_sof),.O_tvalid(bi_out_valid),
    .O_tdata(bi_rgb),.O_tready(1'b1));
task bilinear_probe; input integer mode;
begin
    for(k=0;k<12;k=k+1) begin
        if(mode==0) byte_value=20+k;
        else byte_value=(k%2)==0 ? 50 : 100;
        matrix1[95-k*8-:8]=byte_value;
        if(mode==0) byte_value=20+k;
        else byte_value=(k%2)==0 ? 20 : 50;
        matrix0[95-k*8-:8]=byte_value;
        matrix2[95-k*8-:8]=byte_value;
    end
    parity=1; bi_valid=1; bi_sof=1; bi_eol=1;
    ticks(1); bi_valid=0; bi_sof=0; bi_eol=0;
    ticks(4);
    if(!bi_out_valid || !bi_out_sof || !bi_out_eol) $fatal(1,"bilinear metadata alignment");
    for(lane=0;lane<4;lane=lane+1) begin
        if(mode==0) begin
            byte_value=24+lane;
            if(bi_rgb[lane*32+:32]!=={8'd0,8'(byte_value),8'(byte_value),8'(byte_value)})
                $fatal(1,"bilinear ascending-x lane %0d mismatch",lane);
        end else if(bi_rgb[lane*32+:32]!==32'h00643214)
            $fatal(1,"bilinear RGB channel order lane %0d",lane);
    end
    ticks(4);
end endtask

initial begin
    ticks(8); rst=1; ticks(8);
    bilinear_probe(0); bilinear_probe(1);
    $display("PASS bilinear: x increases from low 32-bit lane; RGB channels and five-stage markers aligned");
    reset_case(0); frame(0,0);
    reset_case(1); frame(1,1);
    $display("OBS ready-low output beats=%0d; ready is passthrough, not effective backpressure",blocked_outputs);
    // Reset while pixels are pending, then verify a complete fresh frame.
    reset_case(2);
    for(b=0;b<32;b=b+1) begin valid=1; sof=(b==0); rgb128=word_at(7,b); ticks(1); end
    reset_case(3); frame(0,0);
    $display("PASS AWB/packing: full lines, four lanes, small input bubbles, ready-low, reset and frame restart");
    // Characterize incomplete input without asserting that the pipeline rejects it.
    checking=0; rst=0; valid=0; ticks(8); rst=1; ticks(8);
    partial=1;
    for(b=0;b<64;b=b+1) begin valid=1; sof=(b==0); rgb128=word_at(9,b); ticks(1); end
    valid=0; sof=0; ticks(360); partial=0;
    if(partial_outputs<=64) $fatal(1,"expected incomplete line to expose fixed-width replay behavior");
    $display("OBS incomplete line: input=64 beats, output=%0d beats, unknown=%0d; valid alone cannot prove frame completeness",partial_outputs,partial_unknown);
    $display("PASS pixel boundary characterization; SOF alignment and incomplete-frame protection remain integration requirements");
    $finish;
end
initial begin #100000; $fatal(1,"pixel interface watchdog"); end
endmodule
