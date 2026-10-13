`timescale 1ns/1ps
// Read-only observation of the existing, unexported delayed AWB frame marker.
module tb_awb_sof_probe;
integer beat=0, marks=0;
always @(posedge tb_pixel_interface.clk) begin
    #2;
    if(!tb_pixel_interface.rst) beat=0;
    else begin
        if(tb_pixel_interface.dut.I_tuser_r2) begin
            if(!tb_pixel_interface.out_valid || beat!=0)
                $fatal(1,"AWB delayed marker is not on first valid output, beat=%0d",beat);
            marks=marks+1;
            $display("OBS existing AWB delayed marker aligns with first valid pixel, case=%0d partial=%0d",
                     tb_pixel_interface.case_id,tb_pixel_interface.partial);
        end
        if(tb_pixel_interface.out_valid) beat=beat+1;
    end
end
final begin
    if(marks!=4) $error("Expected four restarted output sequences, got %0d",marks);
    else $display("PASS AWB delayed SOF probe: four output sequences; full-frame and overlap cases remain untested");
end
endmodule
