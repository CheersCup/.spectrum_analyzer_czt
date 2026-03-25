`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/24 19:09:19
// Design Name: 
// Module Name: top_design
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


module top_design(
    input sys_clk,
    input sys_rst_n,
    
    // A/D接口
    input  [7:0] ad_data,
    input  ad_otr, // 不使用，可删
    output ad_clk,
    
    // LCD接口
    output lcd_de,
    output lcd_hs,
    output lcd_vs,
    output lcd_bl,
    output lcd_clk,
    output lcd_rst,
    inout  [23:0] lcd_rgb,
    
    // 4*4矩阵键盘接口
    input  [3 : 0] keyboard_row,
    output [3 : 0] keyboard_col,
    
    // D/A接口，调试用
    output da_clk, // DAC(AD9708)驱动时钟,最大支持125Mhz时钟
    output [7:0] da_data,
    output led_1,
    output led_2
    );

//-----------------------------------------信号声明：-----------------------------------------    
    // mmcm接口
    wire clk_50M;
    wire clk_32M;
    wire clk_10M;
    wire locked;
    
    // rough_calc模块接口
    wire [18 : 0] rough_calc_dout_abs;  // 粗算采样信号后得到的幅度谱
    wire [12 : 0] rough_calc_dout_idx;  // 信号幅度谱对应的索引
    wire rough_calc_dout_valid;         // 信号幅度谱输出有效
    wire [12 : 0] rough_calc_dout_max_index;
    reg  [12 : 0] rough_calc_dout_max_index_reg;
    // 附带逻辑信号
    wire [27 : 0] multiplier_fft_dout;
    wire [23 : 0] fft_dout_rough_freq;
    reg  [25 : 0] refresh_cnt;          // 要求能计数到50_000_000（50MHz）
    reg   refresh_flag;                 // 已刷新最新数据的标志位
    
    // 4*4矩阵键盘模块接口
    wire [3 : 0]  key_board_data_val;
    wire [23 : 0] key_board_dout_f0;
    reg  [23 : 0] key_board_dout_f0_d;
    wire [23 : 0] key_board_dout_fl;
    reg  [23 : 0] key_board_dout_fl_d;
    wire key_board_dout_valid;
    
    // thinning_czt模块接口
    reg  key_board_dout_valid_d1;
    reg  key_board_dout_valid_d2;
    wire thinning_czt_enable;
    wire [23 : 0] thinning_param_calc_din_f0;
    wire [23 : 0] thinning_param_calc_din_fl;
    wire thinning_czt_finish_flag;
    reg  thinning_czt_finish_flag_d;
    wire [10 : 0] thinning_czt_dout_index;
    wire [92 : 0] thinning_czt_dout_data;
    wire [10 : 0] thinning_czt_dout_max_index;
    wire thinning_czt_dout_valid;
    wire [6 : 0] thinning_czt_dout_msb;
    // 附带逻辑信号
    wire [34 : 0] multiplier_czt_dout;
    wire [23 : 0] czt_dout_accurate_freq;
    
//----------------------------------------mmcm模块：----------------------------------------
clk_wiz_global u_clk_wiz_global(
    // Clock out ports
    .clk_50M(clk_50M),     // output clk_50M
    .clk_32M(clk_32M),     // output clk_32M
    .clk_10M(clk_10M),     // output clk_10M
    // Status and control signals
    .reset(~sys_rst_n),     // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in(sys_clk));     // input clk_in
    
//----------------------------------------ADC驱动模块：----------------------------------------
//    assign ad_clk = ~clk_32M;
    assign ad_clk = ~clk_32M;
    
//---------------------------------------频谱粗算模块：----------------------------------------
// 粗测fft，8192点
rough_calc u_rough_calc(
    .clk_32M        (clk_32M),
    .rst_n          (sys_rst_n),
    .enable         (1'b1), 
    .ad_data        (ad_data),
    .fft_dout_abs   (rough_calc_dout_abs),          // output [18 : 0] fft_dout_abs,幅度谱
    .fft_dout_idx   (rough_calc_dout_idx),          // output [12 : 0] fft_dout_idx,结果的索引
    .fft_dout_valid (rough_calc_dout_valid),        // output fft_dout_valid,结果有效标志
    .max_index      (rough_calc_dout_max_index)     // output [12 : 0] max_index,只搜索一半的频谱
    );
    
    // 定时1s刷新一次幅度谱最大值的索引
    always@(posedge clk_10M or negedge sys_rst_n)begin
    	if(~sys_rst_n)begin
    		refresh_cnt  <= 26'd0;
    		refresh_flag <= 1'b0;
    		rough_calc_dout_max_index_reg <= 10'd0;
    	end else if((refresh_cnt >= 26'd5_000_000) && (refresh_cnt <= 26'd10_000_000))begin
    	    refresh_cnt <= refresh_cnt + 26'd1;
    	    if(refresh_flag == 1'b0)begin // 未更新
    	        if(rough_calc_dout_valid == 1'b1)begin // 此时结果有效
    	            refresh_flag <= 1'b1;
    	            rough_calc_dout_max_index_reg <= rough_calc_dout_max_index;
    	        end
    	    end
    	end else if((refresh_cnt >= 26'd0) && (refresh_cnt <= 26'd4_999_999))begin
    	    refresh_cnt <= refresh_cnt + 26'd1;
    		refresh_flag <= 1'b0;   // 清空标志位
    		rough_calc_dout_max_index_reg <= rough_calc_dout_max_index_reg;  // 锁存该值
    	end	else begin
    		refresh_cnt  <= 26'd0;  // 归零计数值
    		refresh_flag <= 1'b0;   // 清空标志位
    		rough_calc_dout_max_index_reg <= rough_calc_dout_max_index_reg;  // 锁存该值
    	end
    end

    // 求解频谱峰值对应的频率
    multiplier_fft u_multiplier_fft(
        .CLK(clk_10M),                      // input  wire CLK
        .A(rough_calc_dout_max_index_reg),  // input  wire [12 : 0] A
        .P(multiplier_fft_dout)             // output wire [27 : 0] P
    );
    
    // 粗测频谱结果
    assign fft_dout_rough_freq = (multiplier_fft_dout >> 13); // (unit:kHz)
//---------------------------------------矩阵键盘模块：----------------------------------------
// 4*4矩阵键盘
key_board u_key_board(
    .clk            (clk_50M),
    .rst_n          (sys_rst_n),
    .led            (led_1),
    .row            (keyboard_row),         // input  [3:0] row,矩阵键盘 行
    .col            (keyboard_col),         // output [3:0] col,矩阵键盘 列
    
    .keyboard_val   (key_board_data_val),   // output [3:0] keyboard_val,键盘值
    .input_f0       (key_board_dout_f0),    // output [23 : 0] input_f0,输入值f0(unit:kHz)
    .input_fl       (key_board_dout_fl),    // output [23 : 0] input_fl,输入值fl(unit:kHz)
    .input_valid    (key_board_dout_valid)  // output input_valid,输入有效
);

    // 锁存上一次的f0和fl
    always@(posedge clk_10M or negedge sys_rst_n)begin
        if(!sys_rst_n)begin
            key_board_dout_f0_d <= 23'b0;
            key_board_dout_fl_d <= 23'b0;
        end else if(thinning_czt_enable == 1'b1)begin // 使能czt时锁存输入参数
            key_board_dout_f0_d <= key_board_dout_f0;
            key_board_dout_fl_d <= key_board_dout_fl;
        end
    end
    
//---------------------------------------频谱细化模块：----------------------------------------
    // 确定输入数据时使能该模块，但需要采样key_board_dout_valid生成单脉冲
    always@(posedge clk_10M or negedge sys_rst_n)begin
        if(!sys_rst_n)begin
            key_board_dout_valid_d1 <= 1'b0;
            key_board_dout_valid_d2 <= 1'b0;
        end else begin
//            key_board_dout_valid_d1  <= czt_begin_flag  ;
            key_board_dout_valid_d1  <= key_board_dout_valid  ;
            key_board_dout_valid_d2  <= key_board_dout_valid_d1 ;
        end
    end
    
    // 使能czt，确定输入数据时使能该模块
    assign thinning_czt_enable = (key_board_dout_valid_d1) && (~key_board_dout_valid_d2);
    
    // 输入参数变换(unit:kHz 2 Hz)
    assign thinning_param_calc_din_f0 = key_board_dout_f0_d * 1000;
    assign thinning_param_calc_din_fl = key_board_dout_fl_d * 1000;

// czt主程序
thinning_czt u_thinning_czt(
    .calc_clk               (clk_10M),
    .ad_clk                 (clk_32M),
    .rst_n                  (sys_rst_n),
    .led_1                  (),
    .led_2                  (led_2),
    .ad_data                (ad_data),
    
    .czt_enable             (thinning_czt_enable),          // input [0 : 0] czt_enableczt，转换使能信号，脉冲信号，不可长时间有效
    .param_calc_din_f0      (thinning_param_calc_din_f0),   // input [23 : 0] param_calc_din_f0,(unit:Hz)
    .param_calc_din_fl      (thinning_param_calc_din_fl),   // input [23 : 0] param_calc_din_fl,(unit:Hz)
    
    .czt_finish_flag        (thinning_czt_finish_flag),     // output reg czt_finish_flag, czt转换结束
    .czt_dout_index         (thinning_czt_dout_index),      // output [10 : 0] czt_dout_index，czt输出结果索引
    .czt_dout_data          (thinning_czt_dout_data),       // output [92 : 0] czt_dout_data，czt输出结果值
    .max_index              (thinning_czt_dout_max_index),  // output [10 : 0] max_index，最大频谱值对应的索引
    .czt_dout_valid         (thinning_czt_dout_valid),      // output czt_dout_valid，czt输出结果有效标志
    .msb_position           (thinning_czt_dout_msb)         // output [6 : 0] msb_position,幅度谱最大值的为1的最高位
    );
    
    // 求解频谱峰值对应的频率
    multiplier_czt u_multiplier_czt(
        .CLK(clk_10M),                        // input wire CLK
        .A(thinning_czt_dout_max_index),      // input wire [10 : 0] A
        .B(key_board_dout_fl_d),              // input wire [23 : 0] B
        .P(multiplier_czt_dout)               // output wire [34 : 0] P
    );
    
    // 输出有效
    always @(posedge clk_10M or negedge sys_rst_n) begin
        if(~sys_rst_n) begin
            thinning_czt_finish_flag_d <= 1'b0;    
        end else begin
            thinning_czt_finish_flag_d <= thinning_czt_finish_flag;                    
        end
    end    
    
    // 频谱细化结果
    assign czt_dout_accurate_freq = (thinning_czt_finish_flag_d == 1'b1) ? (key_board_dout_f0_d + (multiplier_czt_dout >> 11)) : 24'd0; // (unit:kHz)
//--------------------------------------瀑布图屏显模块：---------------------------------------
// lcd模块
results_waterfall u_results_waterfall(
    .clk                        (clk_50M),
    .clk_calc                   (clk_10M),                          // 与外部数据处理部分同频
    .rst_n                      (sys_rst_n),
    
    .user_data_f0               (key_board_dout_f0),                // 频谱分析起点，(unit:kHz)
    .user_data_fl               (key_board_dout_fl),                // 频谱分析长度，(unit:kHz)
    .user_data_rough_freq       (fft_dout_rough_freq),              // 粗测频率，(unit:kHz)
    .user_data_accurate_freq    (czt_dout_accurate_freq),           // 细化频率，(unit:kHz)
    
    .tdata                      (thinning_czt_dout_data),           // input [92 : 0] czt_dout_data，czt幅度谱
    .tuser                      (thinning_czt_dout_index),          // input [10 : 0] czt_dout_index，czt幅度谱对应的索引
    .tvalid                     (thinning_czt_dout_valid),          // input czt_dout_valid，czt幅度谱数据有效
    .msb                        (7'd92 - thinning_czt_dout_msb),    // output [6 : 0] msb_position，幅度谱最大值的为1的最高位
    
    .lcd_de                     (lcd_de),   // output，LCD 数据使能信号
    .lcd_hs                     (lcd_hs),   // output，LCD 行同步信号
    .lcd_vs                     (lcd_vs),   // output，LCD 场同步信号
    .lcd_bl                     (lcd_bl),   // output，LCD 背光控制信号
    .lcd_clk                    (lcd_clk),  // output，LCD 像素时钟
    .lcd_rst                    (lcd_rst),  // output，LCD 复位
    .lcd_rgb                    (lcd_rgb)   // inout， LCD RGB888颜色数据
    );
    
    
endmodule





