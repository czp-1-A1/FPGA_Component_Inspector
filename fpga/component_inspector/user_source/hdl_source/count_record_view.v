// Only changes representation of the inactive-ROI ID lane. Never drives
// recovery, counter state, event acceptance, source IDs or classification.
module count_record_view #(parameter REPORT_NUMBER_GAPS=0)(
 input wire [255:0] record_in,output wire [255:0] record_out
);
wire [35:0] ids=REPORT_NUMBER_GAPS ? record_in[129:94] :
 record_in[57] ? {record_in[129:112],18'd0} : {18'd0,record_in[111:94]};
assign record_out={record_in[255:130],ids,record_in[93:0]};
endmodule
