`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/30 17:20:36
// Design Name: 
// Module Name: TCTM_uplink_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module TCTM_uplink_top(
    input clk_25M_in,//25MHz G22
    //Peripheral 1: AD9361
	//Receiver
	input Rx_clk_9361,      //AB11
	input [11:0] Rx_data_9361,
	input Rx_frame_9361,    // AE10
	//Transmitter
	output Tx_clk_9361,     // AC9
	output [11:0] Tx_data_9361, // AD11
	output Tx_frame_9361,
	//Comm
	output RST_9361,
	output EN_9361,
	output EN_AGC_9361,
	output TXNRX_9361,
	output SPI_ENB_9361,
	output SPI_DI_9361,
	output SPI_CLK_9361,
	input  SPI_DO_9361,
	output [3:0] CONTROL_I_9361,
	input  [7:0] CONTROL_O_9361,
    input rs422,
    output CLK_SEL
    );
    
    wire clk_40MHz;
    wire clk_125MHz;
    wire locked;
    wire ad9361_finish;
    wire system_soft_reset;
    wire rst_ad9361;
    wire reset2;
    wire rst_Transmitter;
    wire rst_Receiver;
    wire rx_en;
    wire [7:0] rx_data;
    wire clk_TR;
    wire rx_data_en;
    wire [11:0] rx_data_i;
    wire [11:0] rx_data_q;
    wire [9:0] probe0;
    wire [24:0] probe1;
    wire [9:0] vio_probe_out0;
    wire locked2;
    wire [11:0] data_I_R, data_Q_R, data_I_T, data_Q_T;
    //9361 debug signals
    wire dbg_auto_instruction_en;
    wire [11:0] dbg_auto_instruction_addr;
    // 软复位信号。
    wire rec_soft_reset;
    wire [1:0]  vio_dttl_mode;
    wire [19:0] vio_pll_c1;
    wire [19:0] vio_pll_c2;
    wire [19:0] vio_pll_c3;

    
    
    // ============================================================
    // rec_top debug signals
    // ============================================================
    wire [2:0]         dbg_rx_state;
    wire               dbg_start;
    wire               dbg_acq_busy;
    wire               dbg_acq_done;
    wire               dbg_acq_success;
    wire               dbg_fft_error;
    wire [10:0]        dbg_code_phase;
    wire               dbg_pn0_valid;
    wire [34:0]        dbg_par_product;
    wire [34:0]        dbg_sum_pipe;
    wire               dbg_ctrl_done;

    
    assign CLK_SEL = 1'b0;
    assign data_I_T = 12'd1024;
    assign data_Q_T = -12'd1024;

    ad9361_tr_clk AD9361_clk
    (
    // Clock out ports
    .clk_out1(clk_TR),     // output clk_out1
    // Status and control signals
    .reset(1'b0), // input reset
    .locked(locked2),       // output locked
   // Clock in ports
    .clk_in1(Rx_clk_9361));      // input clk_in1

    Main_CLK_generator main_clk_mmcm
    (
    // Clock out ports
    .clk_out1(clk_40MHz),     // output clk_out1
    .clk_out2(clk_125MHz),     // output clk_out2
    // Status and control signals
    .reset(1'b0), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(clk_25M_in));      // input clk_in1

    RST_manager RST_manager_inst
    (
    .clk(clk_40MHz),
    .ad9361_finish(ad9361_finish),
    .LOCKED(1'b1),
	.system_soft_reset(system_soft_reset),
    .rst_AD9361(rst_ad9361),
    .rst_clk(reset2),
	.rst_Transmitter(rst_Transmitter),
	.rst_Receiver(rst_Receiver)
    );

    rx_module RS232_RX (
    .clk(clk_40MHz), 
    .rst(rst_ad9361), 
    .nominal_clock_frequency(32'd40000000), 
    .nominal_baud_rate(32'd115200), 
    .rx_in(rs422), 
    .dout_en(rx_en), 
    .dout(rx_data), 
    .rdy()
    );
    
    AD9361_CON_TOP AD9361_CON_inst(
    //top port
    .rst(rst_ad9361),
    .clk(clk_40MHz),
    //ad9361 phy port
    .RST_9361(RST_9361),
    .EN_9361(EN_9361),
    .EN_AGC_9361(EN_AGC_9361),
    .SPI_ENB_9361(SPI_ENB_9361),
    .TXNRX_9361(TXNRX_9361),
    .SPI_DI_9361(SPI_DI_9361),
    .SPI_CLK_9361(SPI_CLK_9361),
    .SPI_DO_9361(SPI_DO_9361),
    .CONTROL_I_9361(CONTROL_I_9361),
    .CONTROL_O_9361(CONTROL_O_9361),
    .ad9361_finish(ad9361_finish),
    .dbg_auto_instruction_en(dbg_auto_instruction_en),
    .dbg_auto_instruction_addr(dbg_auto_instruction_addr),
    //data_R_interface
    .clk_TR(clk_TR),
    .rst_TR(rst_Transmitter),	
    .data_I_R(data_I_R),
    .data_Q_R(data_Q_R),
    .Rx_frame_9361(Rx_frame_9361), 
    .Rx_data_9361(Rx_data_9361),
    //data_T_interface
    .data_I_T(data_I_T),//data_I_T
    .data_Q_T(data_Q_T),//	data_Q_T	
    .TX_FB_clk(Tx_clk_9361),
    .Tx_frame_9361(Tx_frame_9361),
    .Tx_data_9361(Tx_data_9361),
    //power of Transmitter
    .SET_att(9'd0),
    .MIN_att(9'd0),
    // .SET_att(9'd0),
    // .MIN_att(9'd0),
    .rs422_en(rx_en),
    .rs422(rx_data)
    );
    
    // ============================================================
    // Reset for the 125 MHz processing clock domain
    // ============================================================
    wire rec_reset_async;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg  [2:0] rec_rst_sync;
    
    assign rec_reset_async =
            rst_Receiver
        | rec_soft_reset;
    
    always @(posedge clk_125MHz or posedge rec_reset_async) begin
        if (rec_reset_async)
            rec_rst_sync <= 3'b111;
        else
            rec_rst_sync <= {rec_rst_sync[1:0], 1'b0};
    end
    
    wire rec_rst_125m = rec_rst_sync[2];


    (* ASYNC_REG = "TRUE" *)
    reg [61:0] track_cfg_meta =
        {20'd1, 20'd173, 20'd59082, 2'd1};

    (* ASYNC_REG = "TRUE" *)
    reg [61:0] track_cfg_sync =
        {20'd1, 20'd173, 20'd59082, 2'd1};

    // 接收机状态定义。
    always @(posedge clk_125MHz) begin
        track_cfg_meta <= {
            vio_pll_c1,
            vio_pll_c2,
            vio_pll_c3,
            vio_dttl_mode
        };

        track_cfg_sync <= track_cfg_meta;
    end
        

    Data_Buffer_Xclk DATA_Xclk (
    .clk       (clk_125MHz),
    .rst       (rec_rst_125m),
    .clk_R     (clk_TR),
    .ad_din_i  (data_I_R),
    .ad_din_q  (data_Q_R),
    .dout_en   (rx_data_en),
    .dout_i    (rx_data_i),
    .dout_q    (rx_data_q)
    );
    
    // ============================================================
    // Receiver algorithm
    // ============================================================
    rec_top u_rec_top (
        .clk                  (clk_125MHz),
        .rst                  (rec_rst_125m),
        .DTTL_mode            (track_cfg_sync[1:0]),
        .PLL_C1               (track_cfg_sync[61:42]),
        .PLL_C2               (track_cfg_sync[41:22]),
        .PLL_C3               (track_cfg_sync[21:2]),
    
        .rx_adc_en            (rx_data_en),
        .rx_adc_i             (rx_data_i),
        .rx_adc_q             (rx_data_q),
    
        .dbg_rx_state         (dbg_rx_state),
        .dbg_start            (dbg_start),
        .dbg_acq_busy         (dbg_acq_busy),
        .dbg_acq_done         (dbg_acq_done),
        .dbg_acq_success      (dbg_acq_success),
        .dbg_fft_error        (dbg_fft_error),
        .dbg_code_phase       (dbg_code_phase),
        .dbg_pn0_valid        (dbg_pn0_valid),
        .dbg_par_product      (dbg_par_product),
        .dbg_sum_pipe         (dbg_sum_pipe),
        .dbg_ctrl_done        (dbg_ctrl_done)
    );
    
    ila_rec u_ila_rec (
        .clk     (clk_125MHz),
        .probe0  (rx_data_en),
        .probe1  (rx_data_i),
        .probe2  (rx_data_q),
        .probe3  (dbg_rx_state),
        .probe4  (dbg_start),
        .probe5  (dbg_acq_busy),
        .probe6  (dbg_acq_done),
        .probe7  (dbg_acq_success),
        .probe8  (dbg_fft_error),
        .probe9  (dbg_code_phase),
        .probe10 (dbg_pn0_valid),
        .probe11 (dbg_ctrl_done),
        .probe12 (dbg_par_product),
        .probe13 (dbg_sum_pipe),
        .probe14(u_rec_top.acq_tracking_fcw_o),
        .probe15(u_rec_top.acq_tracking_fcw_valid_o)
    );

    ILA_CONFIG ila_40M (
	.clk(clk_40MHz), // input wire clk
	.probe0(probe0), // input wire [9:0] probe0
    .probe1(dbg_auto_instruction_en),
    .probe2(dbg_auto_instruction_addr),
    .probe3(ad9361_finish)
    );

    assign probe0[0]   = locked2;
    assign probe0[1]   = rx_en;
    assign probe0[9:2] = rx_data;

    ila_tr_rx ila_TR (
	.clk(clk_125MHz), // input wire clk
	.probe0(probe1) // input wire [24:0] probe1
    );

    assign probe1[24] = rx_data_en;
    assign probe1[23:12] = rx_data_i;
    assign probe1[11:0] = rx_data_q;


    assign system_soft_reset = vio_probe_out0[0]; 
    assign rec_soft_reset    = vio_probe_out0[1]; 

    vio_0 vio (
    .clk(clk_40MHz),                // input wire clk
    .probe_out0(vio_probe_out0) // output wire [9 : 0] probe_out0
    );
    // Tracking debug: configure ila_data for 33 probes.
    // FCW_preset_reg and FCW_reg are 36 bits each; NCO_incr stays on probe11.
    ila_data ila_track (
        .clk(clk_125MHz),
        .probe0 (u_rec_top.u_TMTC_Track_Top.Track_enable),
        .probe1 (u_rec_top.u_TMTC_Track_Top.DDLL.sample_in_en),
        .probe2 (u_rec_top.u_TMTC_Track_Top.DDLL.sample_in_i),
        .probe3 (u_rec_top.u_TMTC_Track_Top.DDLL.sample_in_q),
        .probe4 (u_rec_top.u_TMTC_Track_Top.DDLL.coherent_out_en),
        .probe5 (u_rec_top.u_TMTC_Track_Top.DDLL.coherent_out_i),
        .probe6 (u_rec_top.u_TMTC_Track_Top.DDLL.coherent_out_q),
        .probe7 (u_rec_top.u_TMTC_Track_Top.DDLL.chip_out_en),
        .probe8 (u_rec_top.u_TMTC_Track_Top.DDLL.chip_out_i),
        .probe9 (u_rec_top.u_TMTC_Track_Top.DDLL.chip_out_q),
        .probe10(u_rec_top.u_TMTC_Track_Top.PLL_DDS.NCO),
        .probe11(u_rec_top.u_TMTC_Track_Top.PLL_DDS.NCO_incr),
        .probe12(u_rec_top.u_TMTC_Track_Top.track_lock),
        .probe13(u_rec_top.u_TMTC_Track_Top.track_lock_valid),
        .probe14(u_rec_top.u_TMTC_Track_Top.symbol_out_valid),
        .probe15(u_rec_top.u_TMTC_Track_Top.symbol_out),
        .probe16(u_rec_top.u_TMTC_Track_Top.DDLL.PN),
        .probe17(u_rec_top.u_TMTC_Track_Top.DDLL.PN_move_trig),
        .probe18(u_rec_top.u_TMTC_Track_Top.DDLL.chip_index),
        .probe19(u_rec_top.u_TMTC_Track_Top.dttl_middle_out),
        .probe20(u_rec_top.u_TMTC_Track_Top.dttl_pd_en),
        .probe21(u_rec_top.u_TMTC_Track_Top.dttl_pd_out),
        .probe22(u_rec_top.u_TMTC_Track_Top.DTTL.DTTL_PD_inst.ref_magnitude),
        .probe23(u_rec_top.u_TMTC_Track_Top.dttl_fcw_update_en),
        .probe24(u_rec_top.u_TMTC_Track_Top.dttl_fcw_modifying),
        .probe25(u_rec_top.u_TMTC_Track_Top.dttl_fcw_out),
        .probe26(u_rec_top.u_TMTC_Track_Top.dttl_debug_event),
        .probe27(u_rec_top.u_TMTC_Track_Top.PLL_DDS.FCW_preset_reg),
        .probe28(u_rec_top.u_TMTC_Track_Top.PLL_DDS.FCW_reg),
        .probe29(u_rec_top.u_TMTC_Track_Top.PLL_PD.PD),
        .probe30(u_rec_top.u_TMTC_Track_Top.PLL_PD.PD_en)
    );
    
    vio_1 vio_1 (
      .clk(clk_125MHz),                // input wire clk
      .probe_out0(vio_dttl_mode),  // output wire [1 : 0] probe_out0
      .probe_out1(vio_pll_c1),  // output wire [19 : 0] probe_out1
      .probe_out2(vio_pll_c2),  // output wire [19 : 0] probe_out2
      .probe_out3(vio_pll_c3)  // output wire [19 : 0] probe_out3
    );
endmodule
