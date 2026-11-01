module extracted_d3_metadata(input [1142:0] camera_metadata_raw,input [511:0] count_live_raw,output [1142:0] camera_metadata,output [511:0] count_live);
localparam CLASSIFIED_COUNT=1,REPORT_NUMBER_GAPS=0,FRAME_META_WIDTH=1143,ORIGINAL_META_WIDTH=631,DUAL_REGION_COUNT=1;
generate if(CLASSIFIED_COUNT)begin : count_record_views
 for(genvar count_bank=0;count_bank<1+DUAL_REGION_COUNT;count_bank=count_bank+1)begin : banks
 count_record_view #(.REPORT_NUMBER_GAPS(REPORT_NUMBER_GAPS)) live_view(.record_in(count_live_raw[count_bank*256+:256]),.record_out(count_live[count_bank*256+:256]));
 count_record_view #(.REPORT_NUMBER_GAPS(REPORT_NUMBER_GAPS)) frame_view(.record_in(camera_metadata_raw[ORIGINAL_META_WIDTH+count_bank*256+:256]),.record_out(camera_metadata[ORIGINAL_META_WIDTH+count_bank*256+:256]));
 end
 assign camera_metadata[ORIGINAL_META_WIDTH-1:0]=camera_metadata_raw[ORIGINAL_META_WIDTH-1:0];
end else begin : no_count_record_views
 assign count_live=count_live_raw;assign camera_metadata=camera_metadata_raw;
end endgenerate
endmodule
