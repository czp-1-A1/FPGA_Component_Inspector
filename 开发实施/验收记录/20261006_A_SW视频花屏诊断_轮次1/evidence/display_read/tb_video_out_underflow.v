`timescale 1ns/1ps
module tb_video_out_underflow;
    reg ddr_clk=0, dsi_clk=0;
    always #7.5 ddr_clk=~ddr_clk;
    always #9.615 dsi_clk=~dsi_clk;
    reg rst_n=0, vsync=0, rd_en=0;
    reg base_valid=0, starve_valid=0;
    reg [127:0] base_data=0, starve_data=0;
    wire [23:0] base_pixel, starve_pixel;
    integer display_x=-1, output_x=-1, display_y=0;
    integer base_errors=0, shifted_errors=0;
    integer base_underflows=0, starve_underflows=0;
    integer base_marker=-1, starve_marker=-1;
    integer base_marker_row0=-1, starve_marker_row0=-1, prefix_errors=0;
    integer base_reads=0, starve_reads=0;
    reg previous_en=0;
    integer previous_x=-1, previous_y=0;
    video_out baseline (
        .I_rst_n(rst_n),.I_ddr_clk(ddr_clk),.O_video_out_rd_busy(),
        .I_video_in_wr_busy(1'b1),.I_video_out_rp(2'b0),
        .O_ddr_user_rd_en(),.O_ddr_user_addr(),.I_ddr_user_ready(1'b0),
        .I_ddr_user_rd_valid(base_valid),.I_ddr_user_rd_data(base_data),
        .I_dsi_clk(dsi_clk),.I_video_vsync(vsync),.I_video_rd_en(rd_en),
        .O_vdieo_data(base_pixel));
    video_out starved (
        .I_rst_n(rst_n),.I_ddr_clk(ddr_clk),.O_video_out_rd_busy(),
        .I_video_in_wr_busy(1'b1),.I_video_out_rp(2'b0),
        .O_ddr_user_rd_en(),.O_ddr_user_addr(),.I_ddr_user_ready(1'b0),
        .I_ddr_user_rd_valid(starve_valid),.I_ddr_user_rd_data(starve_data),
        .I_dsi_clk(dsi_clk),.I_video_vsync(vsync),.I_video_rd_en(rd_en),
        .O_vdieo_data(starve_pixel));
    function [23:0] pixel_color;
        input integer x;
        begin
            if(x==700 || x==1724) pixel_color=24'hffae64;
            else pixel_color=24'h100000+x;
        end
    endfunction
    function [127:0] packed_word;
        input integer word_index;
        integer b, byte_index, pixel_index, lane;
        reg [23:0] color;
        begin
            packed_word=0;
            for(b=0;b<16;b=b+1) begin
                byte_index=word_index*16+b;
                pixel_index=byte_index/3;
                lane=byte_index%3;
                color=pixel_color(pixel_index);
                case(lane)
                    0: packed_word[127-b*8 -:8]=color[23:16];
                    1: packed_word[127-b*8 -:8]=color[15:8];
                    2: packed_word[127-b*8 -:8]=color[7:0];
                endcase
            end
        end
    endfunction
    always @(posedge dsi_clk) begin
        if(rd_en && baseline.S_fifo_rd_en) begin
            if(baseline.S_fifo_emtpy) base_underflows=base_underflows+1;
            else base_reads=base_reads+1;
        end
        if(rd_en && starved.S_fifo_rd_en) begin
            if(starved.S_fifo_emtpy) starve_underflows=starve_underflows+1;
            else begin
                if(starve_reads==0) $display("FIRST_SUCCESSFUL_STARVED_READ display_x=%0d time=%0t",display_x,$time);
                starve_reads=starve_reads+1;
            end
        end
        #1;
        if(previous_en) begin
            output_x=previous_y*1024+previous_x;
            if(base_pixel!==pixel_color(output_x)) begin
                if(base_errors<5) $display("BASE_MISMATCH x=%0d got=%h expected=%h",output_x,base_pixel,pixel_color(output_x));
                base_errors=base_errors+1;
            end
            if(output_x>=128 && starve_pixel!==pixel_color(output_x-128)) begin
                if(shifted_errors<5) $display("SHIFT_MISMATCH x=%0d got=%h expected=%h",output_x,starve_pixel,pixel_color(output_x-128));
                shifted_errors=shifted_errors+1;
            end
            if(output_x<128 && starve_pixel!==24'b0) prefix_errors=prefix_errors+1;
            if(base_pixel==24'hffae64) base_marker=output_x;
            if(starve_pixel==24'hffae64) starve_marker=output_x;
        end
        previous_en=rd_en;
        previous_x=display_x;
        previous_y=display_y;
    end
    integer i,j;
    initial begin
        repeat(4) @(negedge ddr_clk);
        rst_n=1; vsync=1;
        repeat(4) @(negedge ddr_clk);
        vsync=0;
        repeat(30) @(negedge ddr_clk);
        // Actual FIFO reset is produced by video_out from vsync, not testbench force.
        for(i=0;i<192;i=i+1) begin
            base_valid=1; base_data=packed_word(i);
            @(negedge ddr_clk);
        end
        base_valid=0;
        repeat(20) @(negedge dsi_clk);
        fork
            begin
                // A bounded data return gap. First data crosses FIFO CDC before x=128.
                wait(rd_en && display_x==123);
                @(negedge ddr_clk);
                for(j=0;j<192;j=j+1) begin
                    starve_valid=1; starve_data=packed_word(j);
                    @(negedge ddr_clk);
                end
                starve_valid=0;
            end
            begin
                for(i=0;i<1024;i=i+1) begin
                    @(negedge dsi_clk);
                    display_x=i; rd_en=1;
                end
                @(negedge dsi_clk);
                rd_en=0;
            end
        join
        repeat(5) @(negedge dsi_clk);
        base_marker_row0=base_marker;
        starve_marker_row0=starve_marker;
        $display("ROW0 baseline_marker=%0d starved_marker=%0d remaining=%0d",base_marker_row0,starve_marker_row0,starved.U_w128_d512_fifo.rdusedw);
        // Normal horizontal blanking and a fully prefetched second line.
        // Starved FIFO retains the last 24 words (128 pixels) of the first line.
        for(i=192;i<384;i=i+1) begin
            @(negedge ddr_clk);
            base_valid=1; starve_valid=1;
            base_data=packed_word(i); starve_data=packed_word(i);
        end
        @(negedge ddr_clk);
        base_valid=0; starve_valid=0;
        repeat(20) @(negedge dsi_clk);
        display_y=1;
        for(i=0;i<1024;i=i+1) begin
            @(negedge dsi_clk);
            display_x=i; rd_en=1;
        end
        @(negedge dsi_clk);
        rd_en=0;
        repeat(5) @(negedge dsi_clk);
        $display("SUMMARY baseline_errors=%0d shifted_errors=%0d prefix_errors=%0d baseline_underflows=%0d starved_underflows=%0d baseline_reads=%0d starved_reads=%0d row1_baseline_marker_x=%0d row1_starved_marker_x=%0d remaining=%0d",base_errors,shifted_errors,prefix_errors,base_underflows,starve_underflows,base_reads,starve_reads,base_marker-1024,starve_marker-1024,starved.U_w128_d512_fifo.rdusedw);
        if(base_errors==0 && shifted_errors==0 && prefix_errors==0 && base_underflows==0 && starve_underflows==24 && base_reads==384 && starve_reads==360 && base_marker_row0==700 && starve_marker_row0==828 && base_marker==1724 && starve_marker==1852)
            $display("PASS: actual video_out and FIFO reproduce a 128-pixel right shift across two lines after 24 suppressed empty reads; second-line left strip is previous-line tail. Orange marker x=700 moves to x=828 outside fixed ROI x=[256,768). Baseline has zero pixel mismatches.");
        else $fatal(1,"Unexpected diagnostic result");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
