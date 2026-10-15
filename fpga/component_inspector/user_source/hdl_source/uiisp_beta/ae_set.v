/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2023/03/23
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/
/*********ae_set �ֶ��������AE ***********
--�汾��1.0
*********************************************************************/

module ae_set #(
    parameter integer CLK_HZ = 24074074,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer HOLD_MS = 500,
    parameter integer REPEAT_MS = 60,
    parameter integer WB_HOLD_MS = 1000
)(
    input wire I_clk, I_rst,
    input wire [3:0] I_btn,
    input wire I_ae_cfg_done, I_cam_cfg_done,
    output reg O_ae_req,
    output reg [15:0] O_ae, O_ag,
    output reg O_wb_tune,
    output reg [31:0] O_wb_request
);
// Exposure is in half-lines. VTS=1127: maximum=2*1127-10=2244.
// Power-on imaging defaults selected at 180 mm; manual controls remain active.
localparam [15:0] AE_MIN=3, AE_MAX=2244, AE_STEP=16;
localparam [15:0] AE_DEFAULT=1092, AG_DEFAULT=40;
reg [3:0] btn_meta, btn_sync, pressed, event_key;
reg [$clog2(CLK_HZ/1000)-1:0] ms_count;
wire ms_tick = ms_count == CLK_HZ/1000-1;
reg [9:0] debounce [0:3];
reg [9:0] hold_count [0:3];
reg [15:0] ae_setpoint, ag_setpoint;
reg [1:0] request_state;
// Q2.6: code 64 = 1.0; 32..192 = 0.5..3.0, step 1/64.
// The epoch also distinguishes a quick change away and back while CSI is stopped.
reg [9:0] chord_count;
reg chord_used,chord_fired;
reg [1:0] click_pending;
wire chord_down = &btn_sync[1:0];
wire keys_allowed = !chord_down && !chord_used;
wire r_down = event_key[0] && !btn_sync[1] && O_wb_request[15:8]>32;
wire r_up = event_key[1] && !btn_sync[0] && O_wb_request[15:8]<192;
wire b_down = event_key[2] && !btn_sync[3] && O_wb_request[7:0]>32;
wire b_up = event_key[3] && !btn_sync[2] && O_wb_request[7:0]<192;
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        O_wb_tune<=0;O_wb_request<=32'h00006464;
        chord_count<=0;chord_used<=0;chord_fired<=0;
    end else begin
        if(chord_down) chord_used<=1;
        else if(btn_sync==0 && pressed==0) begin chord_used<=0;chord_fired<=0;end
        if(ms_tick) begin
            if(chord_down && &pressed[1:0] && !chord_fired) begin
                if(chord_count==WB_HOLD_MS-1) begin
                    O_wb_tune<=!O_wb_tune;chord_fired<=1;chord_count<=0;
                end else chord_count<=chord_count+1'b1;
            end else chord_count<=0;
        end
        if(O_wb_tune && keys_allowed) begin
            if(r_down) O_wb_request[15:8]<=O_wb_request[15:8]-1'b1;
            else if(r_up) O_wb_request[15:8]<=O_wb_request[15:8]+1'b1;
            if(b_down) O_wb_request[7:0]<=O_wb_request[7:0]-1'b1;
            else if(b_up) O_wb_request[7:0]<=O_wb_request[7:0]+1'b1;
            if(r_down || r_up || b_down || b_up)
                O_wb_request[31:16]<=O_wb_request[31:16]+1'b1;
        end
    end
end
integer k;
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin
        btn_meta<=0; btn_sync<=0; pressed<=0; event_key<=0; ms_count<=0;click_pending<=0;
        for(k=0;k<4;k=k+1) begin debounce[k]<=0; hold_count[k]<=0; end
    end else begin
        btn_meta<=~I_btn; btn_sync<=btn_meta; event_key<=0;
        if(chord_down || chord_used) click_pending<=0;
        if(ms_tick) begin
            ms_count<=0;
            for(k=0;k<4;k=k+1) begin
                if(btn_sync[k] != pressed[k]) begin
                    if(debounce[k] == DEBOUNCE_MS-1) begin
                        pressed[k]<=btn_sync[k]; debounce[k]<=0;
                        hold_count[k]<=0;
                        // KEY1/2 clicks act on release; a chord cannot cause an
                        // initial exposure step, even with staggered debounce.
                        if(k<2) begin
                            if(btn_sync[k]) click_pending[k]<=1;
                            else begin
                                event_key[k]<=click_pending[k] && keys_allowed;
                                click_pending[k]<=0;
                            end
                        end else event_key[k]<=btn_sync[k];
                    end else debounce[k]<=debounce[k]+1'b1;
                end else begin
                    debounce[k]<=0;
                    if(pressed[k]) begin
                        if(hold_count[k] == HOLD_MS-1) begin
                            event_key[k]<=1; hold_count[k]<=HOLD_MS-REPEAT_MS;
                            if(k<2) click_pending[k]<=0;
                        end else hold_count[k]<=hold_count[k]+1'b1;
                    end else hold_count[k]<=0;
                end
            end
        end else ms_count<=ms_count+1'b1;
    end
end
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin ae_setpoint<=AE_DEFAULT; ag_setpoint<=AG_DEFAULT; end
    else if(!O_wb_tune && keys_allowed) begin
        if(event_key[0] && !btn_sync[1])
            ae_setpoint <= ae_setpoint > AE_MIN+AE_STEP ? ae_setpoint-AE_STEP : AE_MIN;
        else if(event_key[1] && !btn_sync[0])
            ae_setpoint <= ae_setpoint < AE_MAX-AE_STEP ? ae_setpoint+AE_STEP : AE_MAX;
        if(event_key[2] && !btn_sync[3] && ag_setpoint>16) ag_setpoint<=ag_setpoint-1'b1;
        else if(event_key[3] && !btn_sync[2] && ag_setpoint<89) ag_setpoint<=ag_setpoint+1'b1;
    end
end
// Hold the complete pair until the writer acknowledges busy, then done.
// Startup AE is applied by uicfgcs500 immediately after the init table.
always @(posedge I_clk or posedge I_rst) begin
    if(I_rst) begin O_ae<=AE_DEFAULT; O_ag<=AG_DEFAULT; O_ae_req<=0; request_state<=0; end
    else begin
        O_ae_req<=0;
        case(request_state)
            0: if(I_cam_cfg_done && I_ae_cfg_done &&
                   (O_ae!=ae_setpoint || O_ag!=ag_setpoint)) begin
                O_ae<=ae_setpoint; O_ag<=ag_setpoint; O_ae_req<=1; request_state<=1;
            end
            1: if(!I_ae_cfg_done) request_state<=2;
            2: if(I_ae_cfg_done) request_state<=0;
            default: request_state<=0;
        endcase
    end
end
endmodule
