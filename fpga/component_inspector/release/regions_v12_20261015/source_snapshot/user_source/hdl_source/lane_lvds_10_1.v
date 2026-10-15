


module lane_lvds_10_1 #(
    parameter DEVICE = "EG",
    parameter LOCAL_ODDR_RESET = 0
    )(
    input wire      I_pixel_clk,
    input wire      I_serial_clk,
    input wire      I_rst,

    input wire[9:0] I_data_in,

    output wire     O_serial_out
);

    reg      S_odd_even;     
    reg      S_odd_even_1d;  
    reg      S_odd_even_2d;  
    reg      S_load_en;      
    reg      S_load_en_1d;   
    reg      S_load_en_2d;   
    reg[9:0] S_shift_data;   
    reg[1:0] S_oddr_data;    

    wire S_pad_reset;
    generate if(LOCAL_ODDR_RESET) begin:g_local_pad_reset
        // A separate final reset driver per lane avoids routing the common
        // serial reset to eight ODDR pad registers across the TMDS pins.
        // Preserve equivalent lane drivers; retain normal setup/hold checks.
        (* dont_touch="true" *) reg pad_reset;
        always @(posedge I_serial_clk or posedge I_rst)
            if(I_rst) pad_reset <= 1'b1;
            else pad_reset <= 1'b0;
        assign S_pad_reset=pad_reset;
    end else begin:g_original_pad_reset
        assign S_pad_reset=I_rst;
    end endgenerate


    always @(posedge I_pixel_clk or posedge I_rst) begin
        if(I_rst)
            S_odd_even <= 1'b0;
        else
            S_odd_even <= ~S_odd_even;
    end

    always @(posedge I_serial_clk) begin
        S_odd_even_1d <= S_odd_even;
        S_odd_even_2d <= S_odd_even_1d;
    end

    always @(posedge I_serial_clk) begin
        S_load_en    <= S_odd_even_1d ^ S_odd_even_2d;
        S_load_en_1d <= S_load_en;
        S_load_en_2d <= S_load_en_1d;
    end

    always @(posedge I_serial_clk or posedge I_rst) begin
        if(I_rst)
            S_shift_data <= 'd0;
        else
            if(S_load_en_2d)
                S_shift_data <= I_data_in;
            else 
                S_shift_data <= S_shift_data << 2;
    end

    always @(posedge I_serial_clk) begin
        S_oddr_data <= S_shift_data[9:8];
    end

    generate
        if(DEVICE == "EF2")
            begin
                EF2_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "EF3")
            begin
                EF3_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "EF4")
            begin
                EF4_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "SF1")
            begin
                SF1_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "EG")
            begin
                EG_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "PH1A")
            begin
                PH1_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "PH1P")
            begin
                PH1P_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( S_pad_reset    ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
        else if(DEVICE == "DR1")
            begin
                DR1_LOGIC_ODDR U_EG4_ODDR(
                    .clk   ( I_serial_clk   ),
                    .rst   ( I_rst          ),

                    .d1    ( S_oddr_data[0] ),
                    .d0    ( S_oddr_data[1] ),

                    .q     ( O_serial_out   )
                );
            end
    endgenerate
    
endmodule
