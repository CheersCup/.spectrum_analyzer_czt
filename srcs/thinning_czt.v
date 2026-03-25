`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/04 14:03:04
// Design Name: Chirp-Z Transform Verilog File
// Module Name: thinning_czt
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:fft结果取后2048点；ifft结果取前2048点
// 
//////////////////////////////////////////////////////////////////////////////////

module thinning_czt(
    input calc_clk,
    input ad_clk,
    input rst_n,
    
    output reg led_1,
    output reg led_2,
    
    // A/D采样数据
    input [7 : 0] ad_data,
    
    // czt转换使能信号(也是状态复位信号)，脉冲信号
    input czt_enable,
    // 键盘输入
    input [23 : 0] param_calc_din_f0,   // 频谱细化起点
    input [23 : 0] param_calc_din_fl,   // 频谱细化长度
    
    output reg czt_finish_flag,        // czt转换结束
    output [10 : 0] czt_dout_index,    // czt输出结果索引
    output [92 : 0] czt_dout_data,     // czt输出结果值
    output reg [10 : 0] max_index,    // 最大频谱值对应的索引
    output reg czt_dout_valid,        // czt输出结果有效标志
    output reg [6 : 0] msb_position   // 幅度谱最大值的为1的最高位
    );
//---------------------------------------部分参数声明：---------------------------------------
    // fft变换长度
    parameter FFT_LEN = 4096;
    // radix-4, burst i/o 配置
    parameter PAD_0 = 7'b0;      // （31 : 25），bit7；边界对齐8bit整数倍
    parameter SCALE_SCH_0 = 24'b01_01_01_01_01_01_01_01_01_01_01_10;  // （24 ：1），bit24；在每层蝶形单元输出上加权，按比例减小输出;N点压缩N倍；保守缩放
    parameter SCALE_SCH_1 = 24'b01_01_01_01_01_01_01_01_01_01_01_10;  // （24 ：1），bit24；在每层蝶形单元输出上加权，按比例减小输出;
    parameter FWD_INV_0 = 1'b1;  // （0 : 0），bit1；进行fft正变换 
    parameter FWD_INV_1 = 1'b0;  // （0 : 0），bit1；进行fft逆变换 
    
//-----------------------------------------信号声明：-----------------------------------------
    // state machine接口,one hot
    reg [7 : 0] cur_state;
    reg [7 : 0] nxt_state;
    
    // 缓存ADC采样数据的双口ram接口
    wire dual_port_ram_xn_wr_enable;          // 写使能
    reg  [11 : 0] dual_port_ram_xn_wr_addra;  // 写地址线
    wire [7 : 0] dual_port_ram_xn_dout;       // 读出数据线
    wire [8 : 0] unsigned_xn_2signed;
    
    // param_calc模块接口
    wire [31 : 0] parameter_theta;  // θ
    wire [31 : 0] parameter_phi;    // φ
    wire [10 : 0] parameter_origin_index;
    
    // chirp_gen1模块接口
    reg  [31 : 0] parameter_theta_reg;  // θ锁存值
    reg  [31 : 0] parameter_phi_reg;    // φ锁存值
    wire [12 : 0] data_chirp1_real;     // chirp1信号实部，fix13_11
    wire [12 : 0] data_chirp1_imag;     // chirp1信号虚部，fix13_11
    wire [31 : 0] data_chirp1_phase;    // chirp1信号相位，ufix32_32
    wire data_chirp1_valid;             // 输出chirp1信号有效
    wire [11 : 0] index_chirp1;         // 输出chirp1信号的索引
    // 缓存chirp1信号的双口ram接口
    wire [12 : 0] dual_port_ram_an_dout_real;   // a(n)信号的实部
    wire [12 : 0] dual_port_ram_an_dout_imag;   // a(n)信号的虚部
    reg  [10 : 0] sync_output_1_rd_addr;        // x(n)和a(n)同步输出的读地址
    
    // 复数乘法器_level1模块接口
    wire [31 : 0] cmpy_1_s_axis_a_tdata;        // 复数乘法器输入通道a数据
    wire [31 : 0] cmpy_1_s_axis_b_tdata;        // 复数乘法器输入通道b数据
    wire cmpy_1_m_axis_dout_tvalid;             // 复数乘法器输出数据有效
    wire cmpy_1_m_axis_dout_tvalid_truncation;  // 复数乘法器输出数据有效，截断至2048点范围
    reg  [11 : 0] cmpy_1_gn_dout_cnt;           // 复数乘法器输出数据计数器
    wire [47 : 0] cmpy_1_m_axis_dout_tdata;     // 复数乘法器输出数据
    // 两个缓存输出的daul_port_ram接口
    reg  [12 : 0] dual_port_ram_gn_din_cnt;     // 写入数据计数器
    wire [22 : 0] dual_port_ram_gn_din_real;    // 写入的g(n)的实部
    wire [22 : 0] dual_port_ram_gn_din_imag;    // 写入的g(n)的虚部
    wire [22 : 0] dual_port_ram_gn_dout_real;   // 读出的g(n)的实部
    wire [22 : 0] dual_port_ram_gn_dout_imag;   // 读出的g(n)的虚部
    wire dual_port_ram_gn_wr_enable;            // 缓存结果写入使能
    
    // chirp_gen2模块接口
    reg  [1 : 0]  data_chirp2_switch;   // 输出chirp信号源选取
    wire [12 : 0] data_chirp2_real;     // chirp2信号实部，fix13_11
    wire [12 : 0] data_chirp2_imag;     // chirp2信号虚部，fix13_11
    wire [31 : 0] data_chirp2_phase;    // chirp2信号相位，ufix32_32
    wire data_chirp2_valid;             // 输出chirp2信号有效
    wire [11 : 0] index_chirp2;         // 输出chirp2信号的索引
    // 缓存延拓后的chirp2信号的双口ram接口
    wire [12 : 0] dual_port_ram_hn_half_dout_real;  // h(n)输出实部
    wire [12 : 0] dual_port_ram_hn_half_dout_imag;  // h(n)输出虚部
    wire dual_port_ram_hn_half_wr_enable;           // h(n)写入使能
    reg  [11 : 0] hn_continuance_rd_addr;           // h(n)读出地址
    reg  hn_reverse_flag;                           // 读地址反向标志：1'b1有效
    reg  [12 : 0] hn_continuance_wr_addr;           // 延拓后的h(n)写入地址
    wire dual_port_ram_hn_wr_enable;                // 延拓后的h(n)写入使能
    wire [12 : 0] dual_port_ram_hn_din_real;        // 输入延拓后的h(n)的实部
    wire [12 : 0] dual_port_ram_hn_din_imag;        // 输入延拓后的h(n)的虚部
    wire [12 : 0] dual_port_ram_hn_dout_real;       // 读出延拓后的h(n)的实部
    wire [12 : 0] dual_port_ram_hn_dout_imag;       // 读出延拓后的h(n)的虚部
    // 缓存chirp2信号的共轭信号的双口ram接口
    wire dual_port_ram_bn_wr_enable;            // b(n)写入使能
    wire [12 : 0] dual_port_ram_bn_dout_real;   // 读出b(n)的实部
    wire [12 : 0] dual_port_ram_bn_dout_imag;   // 读出b(n)的虚部
    
    // L点FFT（输出G(r)）模块接口
    wire xfft_dout_Gr_s_axis_config_tready;
    wire [47 : 0] xfft_dout_Gr_s_axis_data_tdata;
    wire xfft_dout_Gr_s_axis_data_tready;
    wire [47 : 0] xfft_dout_Gr_m_axis_data_tdata;
    wire [47 : 0] xfft_dout_Gr_m_axis_data_tdata_truncation;
    wire [17 : 0] xfft_dout_Gr_m_axis_data_tdata_real_truncation;
    wire [17 : 0] xfft_dout_Gr_m_axis_data_tdata_imag_truncation;
    wire [15 : 0] xfft_dout_Gr_m_axis_data_tuser;
    wire xfft_dout_Gr_m_axis_data_tvalid;
    wire xfft_dout_Gr_m_axis_data_tlast;
    wire xfft_dout_Gr_event_frame_started;
    wire xfft_dout_Gr_event_tlast_unexpected;
    wire xfft_dout_Gr_event_tlast_missing;
    wire xfft_dout_Gr_event_status_channel_halt;
    wire xfft_dout_Gr_event_data_in_channel_halt;
    wire xfft_dout_Gr_event_data_out_channel_halt;
    wire [22 : 0] xfft_dout_Gr_real;
    wire [22 : 0] xfft_dout_Gr_imag;
    wire [11 : 0] xfft_dout_Gr_index;
    // 缓存部分
    reg  [47 : 0] Gr_dc_component;
    reg  [31 : 0] Hr_dc_component;
    reg  first_flag;
    wire cache_wr_enable;
    reg  [10 : 0] cache_wr_addr;
    wire cache_rd_enable;
    reg  [10 : 0] cache_rd_addr;
    wire [47 : 0] cache_Gr_dout;
    wire [31 : 0] cache_Hr_dout;
    reg  cmpy_2_reverse_flag;
    reg  [11 : 0] xfft_dout_index;
    
    // L点FFT（输出H(r)）模块接口
    wire xfft_dout_Hr_s_axis_config_tready;
    wire [31 : 0] xfft_dout_Hr_s_axis_data_tdata;
    wire xfft_dout_Hr_s_axis_data_tready;
    wire [31 : 0] xfft_dout_Hr_m_axis_data_tdata;
    wire [15 : 0] xfft_dout_Hr_m_axis_data_tuser;
    wire xfft_dout_Hr_m_axis_data_tvalid;
    wire xfft_dout_Hr_m_axis_data_tlast;
    wire xfft_dout_Hr_event_frame_started;
    wire xfft_dout_Hr_event_tlast_unexpected;
    wire xfft_dout_Hr_event_tlast_missing;
    wire xfft_dout_Hr_event_status_channel_halt;
    wire xfft_dout_Hr_event_data_in_channel_halt;
    wire xfft_dout_Hr_event_data_out_channel_halt;
    wire [12 : 0] xfft_dout_Hr_real;
    wire [12 : 0] xfft_dout_Hr_imag;
    wire [11 : 0] xfft_dout_Hr_index;
    
    // 两个FFT模块公共接口
    reg  [12 : 0] xfft_din_addr;  // 输入数据索引，也是读取源数据缓存的地址
    wire [31 : 0] xfft_dout_s_axis_config_tdata;
    reg  xfft_dout_s_axis_data_tlast;
    wire xfft_dout_s_axis_data_tvalid;
    reg  [4 : 0] xfft_trans_delay;
    
    // 复数乘法器_level2模块接口
    wire [47 : 0] cmpy_2_s_axis_a_tdata;
    wire [31 : 0] cmpy_2_s_axis_b_tdata;
    wire cmpy_2_m_axis_dout_tvalid;
    wire [63 : 0] cmpy_2_m_axis_dout_tdata;     // 复数乘法器输出数据
    wire [31 : 0] cmpy_2_dout_Yk_real;
    wire [31 : 0] cmpy_2_dout_Yk_imag;
    
    // L点IFFT（输出y(k)）模块接口
    wire [31 : 0] xifft_dout_s_axis_config_tdata;
    wire xifft_dout_yk_s_axis_config_tready;
    wire xifft_dout_yk_s_axis_data_tready;    
    reg  xifft_dout_yk_s_axis_data_tlast;
    wire [63 : 0] xifft_dout_yk_m_axis_data_tdata;
    reg  [63 : 0] xifft_dout_yk_m_axis_data_tdata_d1; 
    wire [15 : 0] xifft_dout_yk_m_axis_data_tuser;
    wire xifft_dout_yk_m_axis_data_tvalid;
    reg  xifft_dout_yk_m_axis_data_tvalid_d;
    wire xifft_dout_yk_m_axis_data_tlast;
    wire xifft_dout_yk_event_frame_started;
    wire xifft_dout_yk_event_tlast_unexpected;
    wire xifft_dout_yk_event_tlast_missing;
    wire xifft_dout_yk_event_status_channel_halt;
    wire xifft_dout_yk_event_data_in_channel_halt;
    wire xifft_dout_yk_event_data_out_channel_halt;
    reg  [12 : 0] ifft_din_cnt;
    wire [11 : 0] xifft_dout_yk_index;
    wire [31 : 0] xifft_dout_yk_real;
    wire [31 : 0] xifft_dout_yk_imag;
    // 缓存部分
    wire cache_yk_enable;
    reg  [10 : 0] cache_wr_addr_for_yk;
    reg  [10 : 0] cache_rd_addr_for_yk;
    wire [63 : 0] cache_yk_dout;
    wire [31 : 0] cache_yk_dout_real;
    wire [31 : 0] cache_yk_dout_imag;
    
    // 复数乘法器_level3模块接口
    wire cmpy_3_s_axis_aandb_tvalid;                    // 输入数据通道a和b数据有效标志
    wire [31 : 0] cmpy_3_din_bn_s_axis_data_tdata;      // 输入数据通道b
    wire cmpy_3_m_axis_dout_tvalid;                     // 乘法器3输出数据有效标志
    reg  cmpy_3_m_axis_dout_tvalid_truncation;          // 乘法器3输出数据有效标志，截断至2048点范围
    reg  [12 : 0] cmpy_3_dout_cnt;                      // 乘法器3输出数据计数器
    wire [95 : 0] cmpy_3_m_axis_dout_tdata;             // 乘法器3输出数据
    // 计算幅度谱用的乘法器模块接口
    wire [45 : 0] Xk_real;                              // czt结果实部
    wire [45 : 0] Xk_imag;                              // czt结果虚部
    wire [91 : 0] mult_dout_Xk_real;                    // czt结果实部的平方
    wire [91 : 0] mult_dout_Xk_imag;                    // czt结果虚部的平方
    wire [92 : 0] Xk_data;                              // czt幅度谱
    reg  [63 : 0] Xk_data_truncation;                   // czt幅度谱，截出高64bit
    wire [10 : 0] Xk_index;                             // czt幅度谱对应的索引
    // 缓存czt输出结果的双口ram接口
    reg  [10 : 0] dual_port_ram_Xk_wr_addr;             // 缓存数据写地址
    reg  [10 : 0] dual_port_ram_Xk_rd_addr;             // 缓存数据读地址
    // 最大值
    reg  [92 : 0] max_data;                             // 幅度谱的最大值
    
    // 状态机控制信号
    reg  load_xn_enable;                // ADC采样数据装载使能信号
    reg  load_chirp1_enable;            // chirp1信号装载使能信号
    reg  load_chirp2_enable;            // chirp2信号装载使能信号
    reg  param_calc_enable;             // 窄带信号参数计算使能信号
    reg  sync_output_1_enable;          // x(n)和chirp1(n)信号同步生成使能信号
    reg  sync_output_1_enable_d;        // x(n)和chirp1(n)信号同步生成使能信号
    reg  cmpy_1_enable;                 // 复数乘法器使能信号
    reg  hn_continuance_enable;         // h(n)延拓使能信号
    reg  hn_continuance_enable_d;       // h(n)延拓使能信号
    reg  zero_fill_enable;              // g(n)补零使能信号
    wire zero_fill_enable_truncation;   // g(n)补零使能信号，截断至2048点
    reg  xfft_dout_enable;              // 使能fft运算信号
    reg  xfft_dout_enable_d1;           // 使能fft运算信号
    reg  xfft_dout_enable_d2;           // 使能fft运算信号
    reg  xifft_dout_enable;             // 使能ifft运算信号
    reg  sync_output_3_enable;          // y(n)和b(n)信号同步生成使能信号
    reg  sync_output_3_enable_d;        // y(n)和b(n)信号同步生成使能信号
    
    // 状态机状态标志
    reg  loaded_xn_flag;                // ADC采样数据装载完成标志
    reg  loaded_an_flag;                // chirp1信号装载完成标志
    reg  loaded_hn_half_flag;           // chirp2信号装载完成标志
    reg  loaded_hn_flag;                // 延拓后的chirp2信号装载完成标志
    reg  loaded_Gr_flag;
    reg  loaded_bn_flag;                // chirp2的共轭信号装载完成标志
    wire param_calc_dout_valid;         // 输出角度有效标志
    reg  cmpy_1_dout_flag;              // 复数乘法器输出2048点完成标志
    reg  zero_fill_flag;                // g(n)序列补零至L点完成标志
    reg  loaded_yk_flag;
    reg  loaded_Xk_flag;                // czt结果装载完成标志
    reg  loaded_Xk_flag_d;              // czt结果装载完成标志
    
//------------------------------------键盘输入数据获取：------------------------------------
    // 输入数据已锁存

//--------------------------------------czt参数获取：---------------------------------------    
// rough_calc模块传入f0和fl两个参数，输入数据是否需要锁存？
param_calc u_param_calc(
    .clk                (calc_clk),
    .rst_n              (rst_n),
    .enable             (param_calc_enable),     // 使能除法运算,此时数据线有效；高电平期间有效,低电平复位输出
    .f0                 (param_calc_din_f0),     // f0,频谱分析的起点
    .fl                 (param_calc_din_fl),     // fl,频谱分析的长度
    .theta              (parameter_theta),       // theta,数据类型为ufix32_32
    .phi                (parameter_phi),         // phi,数据类型为ufix32_32
    .origin_index       (parameter_origin_index),// origin_index,czt中直流分量泄露影响到的序号
    .dout_valid         (param_calc_dout_valid)  // 输出角度有效
    );    
    
    // 锁存输出角度
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            parameter_theta_reg <= 32'd0;
            parameter_phi_reg <= 32'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            parameter_theta_reg <= 32'd0;
            parameter_phi_reg <= 32'd0; 
        end else if(param_calc_dout_valid == 1'b1)begin
            parameter_theta_reg <= parameter_theta;
            parameter_phi_reg <= parameter_phi;
        end else begin
            parameter_theta_reg <= parameter_theta_reg;
            parameter_phi_reg <= parameter_phi_reg;
        end
    end  
    
//---------------------------------双口ram缓存数据，即x(n)：----------------------------------
    // 装载0.5 * FFT_LEN个采样点，写时钟与ADC驱动时钟同频
    always@(posedge ad_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            dual_port_ram_xn_wr_addra <= 12'd0;
            loaded_xn_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_xn_flag <= 1'b0; 
            dual_port_ram_xn_wr_addra <= 12'd0;
        end else if(load_xn_enable == 1'b1)begin
            if(dual_port_ram_xn_wr_addra == 12'd2047)begin
                dual_port_ram_xn_wr_addra <= dual_port_ram_xn_wr_addra + 12'd1; // 继续向上
                loaded_xn_flag <= 1'b1;
            end else begin
                dual_port_ram_xn_wr_addra <= dual_port_ram_xn_wr_addra + 12'd1;
                loaded_xn_flag <= loaded_xn_flag; // 锁存状态
            end
        end else begin
            dual_port_ram_xn_wr_addra <= 12'd0;
            loaded_xn_flag <= loaded_xn_flag; // 此处不清零标志位，放在czt_enable == 1'b1逻辑分支中清零
        end
    end
    
    // x(n)写入使能
    assign dual_port_ram_xn_wr_enable = ((load_xn_enable == 1'b1) && (dual_port_ram_xn_wr_addra <= 12'd2047)) ? 1'b1 : 1'b0;

// 缓存2048点数据x(n)
dual_port_ram_xn u_dual_port_ram_xn(
  .clka(ad_clk),                           // input wire clka
  .wea(dual_port_ram_xn_wr_enable),         // input wire [0 : 0] wea
  .addra(dual_port_ram_xn_wr_addra[10 : 0]),// input wire [10 : 0] addra
  .dina(ad_data),                           // input wire [7 : 0] dina
  .clkb(calc_clk),                           // input wire clkb
  .enb(sync_output_1_enable),               // input wire enb
  .addrb(sync_output_1_rd_addr),            // input wire [10 : 0] addrb
  .doutb(dual_port_ram_xn_dout)             // output wire [7 : 0] doutb
);
    
//-----------------------------------chirp信号生成模块_1：-----------------------------------
// 输出滞后输入2个时钟周期，输入滞后使能4个时钟周期，共计滞后使能信号6个时钟周期后产生输出信号
chirp_gen_1 u_chirp_gen_1(
    .clk            (calc_clk),
    .rst_n          (rst_n),
    .enable         (load_chirp1_enable),    // 产生chirp信号模块使能信号
    .init_phase     (parameter_theta_reg),   // init_phase = θ；数据类型为ufix32_32
    .step_phase     (parameter_phi_reg),     // step_phase = φ；数据类型为ufix32_32
    .dout_valid     (data_chirp1_valid),     // 输出数据有效，仅在2048点之内
    .chirp_real     (data_chirp1_real),      // cos，fix13_11;生成的chirp信号实部
    .chirp_imag     (data_chirp1_imag),      // sin，fix13_11;生成的chirp信号虚部
    .chirp_phase    (data_chirp1_phase),     // 生成的chirp相位信号；弧度值，ufix32_32
    .chirp_index    (index_chirp1)           // 输出chirp信号的索引:0-2047
    );
    
    // 产生a(n)装载完成标志位
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            loaded_an_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_an_flag <= 1'b0;
        end else if(data_chirp1_valid == 1'b1)begin
            if(index_chirp1 == 12'd2047)begin
                loaded_an_flag <= 1'b1;
            end else begin
                loaded_an_flag <= 1'b0; // 在此处清零标志位
            end
        end else begin // 锁存状态
            loaded_an_flag <= loaded_an_flag;
        end
    end
    
// 缓存chirp1信号（即a(n)）实部
dual_port_ram_an u_dual_port_ram_an_real(
  .clka(calc_clk),                     // input wire clka
  .wea(data_chirp1_valid),            // input wire [0 : 0] wea
  .addra(index_chirp1[10 : 0]),       // input wire [10 : 0] addra
  .dina(data_chirp1_real),            // input wire [12 : 0] dina
  .clkb(calc_clk),                     // input wire clkb
  .enb(sync_output_1_enable),         // input wire enb
  .addrb(sync_output_1_rd_addr),      // input wire [10 : 0] addrb
  .doutb(dual_port_ram_an_dout_real)  // output wire [12 : 0] doutb
);

// 缓存chirp1信号（即a(n)）虚部
dual_port_ram_an u_dual_port_ram_an_imag( 
  .clka(calc_clk),                     // input wire clka
  .wea(data_chirp1_valid),            // input wire [0 : 0] wea
  .addra(index_chirp1[10 : 0]),       // input wire [10 : 0] addra
  .dina(data_chirp1_imag),            // input wire [12 : 0] dina
  .clkb(calc_clk),                     // input wire clkb
  .enb(sync_output_1_enable),         // input wire enb
  .addrb(sync_output_1_rd_addr),      // input wire [10 : 0] addrb
  .doutb(dual_port_ram_an_dout_imag)  // output wire [12 : 0] doutb
);
    
    // 需对sync_output_1_enable打一拍使得缓存输出对齐sync_output_1_enable信号
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            sync_output_1_enable_d <= 1'b0;
        end else begin
            sync_output_1_enable_d <= sync_output_1_enable;
        end
    end

    // 同步产生x(n)信号和chirp1信号（即a(n)），分别送入复数乘法器1的a输入端和b输入端
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            sync_output_1_rd_addr <= 11'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            sync_output_1_rd_addr <= 11'd0;
        end else if(sync_output_1_enable == 1'b1)begin
            if(sync_output_1_rd_addr == 11'd2047)begin
                sync_output_1_rd_addr <= 11'd0;
            end else begin
                sync_output_1_rd_addr <= sync_output_1_rd_addr + 11'd1;
            end
        end else begin // 复位读地址线
            sync_output_1_rd_addr <= 11'd0;
        end
    end
    
//------------------------------------复数乘法器_level1：------------------------------------
//    assign unsigned_xn_2signed = {~dual_port_ram_xn_dout[7], dual_port_ram_xn_dout - 8'd128};
    // 输入通道a为x(n)，高位为虚部，低位为实部，均对齐到字节边界；正数的符号位可以直接补零以形成补码；该信号包含直流分量
    assign cmpy_1_s_axis_a_tdata  = {7'b0, 9'b0, 7'b0, 1'b0, dual_port_ram_xn_dout}; 
    // 输入通道a为x(n)，高位为虚部，低位为实部，均对齐到字节边界；该信号减去了直流分量
//    assign cmpy_1_s_axis_a_tdata  = {7'b0, 9'b0, 7'b0, unsigned_xn_2signed}; 
    // 输入通道b为chirp1(n)，高位为虚部，低位为实部，均对齐到字节边界；fix13_11->fix13_0，输出结果会放大2048倍
    assign cmpy_1_s_axis_b_tdata  = {3'b0, dual_port_ram_an_dout_imag, 3'b0, dual_port_ram_an_dout_real};

// 同步输入x(n)和chirp1(n)，输出结果滞后时钟使能信号6个时钟周期;aresetn失能两个时钟后数据线失能
cmpy_1 u_cmpy_dout_gn(
  .aclk(calc_clk),                                 // input wire aclk
  .aresetn(cmpy_1_enable),                         // input wire aresetn
  .s_axis_a_tvalid(sync_output_1_enable_d),        // input wire s_axis_a_tvalid，同步输入的同时拉高数据有效位
  .s_axis_a_tdata(cmpy_1_s_axis_a_tdata),          // fix9_0,,input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(sync_output_1_enable_d),        // input wire s_axis_b_tvalid
  .s_axis_b_tdata(cmpy_1_s_axis_b_tdata),          // fix13_0,,input wire [31 : 0] s_axis_b_tdata
  .m_axis_dout_tvalid(cmpy_1_m_axis_dout_tvalid),  // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(cmpy_1_m_axis_dout_tdata)    // fix23_0,,output wire [47 : 0] m_axis_dout_tdata，输出结果需要移位处理（>> 11,fix23_11）
);

    // 对cmpy_1输出点数计数
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            cmpy_1_gn_dout_cnt <= 12'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            cmpy_1_gn_dout_cnt <= 12'd0;
        end else if(cmpy_1_m_axis_dout_tvalid == 1'b1)begin
            if(cmpy_1_gn_dout_cnt == 12'd2048)begin
                // 不对cmpy_1_gn_dout_cnt清零，相当于只向上计数到12'd2047后停止
            end else begin
                cmpy_1_gn_dout_cnt <= cmpy_1_gn_dout_cnt + 12'd1;
            end
        end else begin
            cmpy_1_gn_dout_cnt <= 12'd0; // 输出点数计数器在此处清零
        end
    end
    
    // 复数乘法器输出数据有效，截断至2048点范围
    assign cmpy_1_m_axis_dout_tvalid_truncation = (cmpy_1_gn_dout_cnt <= 12'd2047) ? cmpy_1_m_axis_dout_tvalid : 1'b0;
    
    // dual_port_ram_gn输入点数计数器
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            dual_port_ram_gn_din_cnt <= 13'd0;
            cmpy_1_dout_flag <= 1'b0;
            zero_fill_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            dual_port_ram_gn_din_cnt <= 13'd0;
            cmpy_1_dout_flag <= 1'b0;
            zero_fill_flag <= 1'b0;
        end else if(dual_port_ram_gn_wr_enable == 1'b1)begin
            if(dual_port_ram_gn_din_cnt == 13'd2047)begin
                zero_fill_flag <= 1'b0;     // 清空g(n)序列补零完成标志位
                cmpy_1_dout_flag <= 1'b1;   // 乘法器输出完成
                dual_port_ram_gn_din_cnt <= dual_port_ram_gn_din_cnt + 13'd1; // 继续增长，脱离该条件
            end else if(dual_port_ram_gn_din_cnt == 13'd4095)begin
                cmpy_1_dout_flag <= 1'b0;   // 清空乘法器输出完成标志位
                zero_fill_flag <= 1'b1;     // g(n)序列补零完成
                dual_port_ram_gn_din_cnt <= 13'd0; // 清零
            end else begin
                dual_port_ram_gn_din_cnt <= dual_port_ram_gn_din_cnt + 13'd1;
            end
        end else begin // 锁存计数值
            dual_port_ram_gn_din_cnt <= dual_port_ram_gn_din_cnt;
            cmpy_1_dout_flag <= cmpy_1_dout_flag;
            zero_fill_flag <= zero_fill_flag;
        end
    end
    
    // 补零信号有效，截断至2048点范围
    assign zero_fill_enable_truncation = (dual_port_ram_gn_din_cnt == 13'd0) ? 1'b0 : zero_fill_enable;

    // 先将复数乘法器输出结果x(n)写入dual_port_ram中，再对x(n)补零至L点（4096）
    // 写入使能，复数乘法器输出有效或补零操作有效时
    assign dual_port_ram_gn_wr_enable = (cmpy_1_m_axis_dout_tvalid_truncation == 1'b1) || (zero_fill_enable_truncation == 1'b1);
    // 写入数据选择，结果需要缩小2048倍，损失11位的精度
    assign dual_port_ram_gn_din_real = (zero_fill_enable == 1'b1) ? 23'b0 : cmpy_1_m_axis_dout_tdata[22 : 0];
    assign dual_port_ram_gn_din_imag = (zero_fill_enable == 1'b1) ? 23'b0 : cmpy_1_m_axis_dout_tdata[46 : 24];
    
// 将复数乘法器1的输出结果分别进行缓存（实部和虚部），cmpy_1输出有效时 dual_port_ram写使能有效
dual_port_ram_gn u_dual_port_ram_gn_real(     // 实部
  .clka(calc_clk),                            // input wire clka
  .wea(dual_port_ram_gn_wr_enable),           // input wire [0 : 0] wea
  .addra(dual_port_ram_gn_din_cnt),           // input wire [11 : 0] addra
  .dina(dual_port_ram_gn_din_real),           // input wire [22 : 0] dina
  .clkb(calc_clk),                            // input wire clkb，该时钟和FFT时钟相同，如果需要加速FFT则需要同时改变此时钟
  .enb(xfft_dout_enable_d1),                  // input wire enb
  .addrb(xfft_din_addr[11 : 0]),              // input wire [11 : 0] addrb
  .doutb(dual_port_ram_gn_dout_real)          // output wire [22 : 0] doutb
);

dual_port_ram_gn u_dual_port_ram_gn_imag(     // 虚部
  .clka(calc_clk),                            // input wire clka
  .wea(dual_port_ram_gn_wr_enable),           // input wire [0 : 0] wea
  .addra(dual_port_ram_gn_din_cnt),           // input wire [11 : 0] addra
  .dina(dual_port_ram_gn_din_imag),           // input wire [22 : 0] dina
  .clkb(calc_clk),                            // input wire clkb，该时钟和FFT时钟相同
  .enb(xfft_dout_enable_d1),                  // input wire enb
  .addrb(xfft_din_addr[11 : 0]),              // input wire [11 : 0] addrb
  .doutb(dual_port_ram_gn_dout_imag)          // output wire [22 : 0] doutb
);
    
//-----------------------------------chirp信号生成模块_2：-----------------------------------
// 输出滞后输入2个时钟周期，输入滞后使能4个时钟周期，共计滞后使能信号6个时钟周期后产生输出信号
chirp_gen_2 u_chirp_gen_2(
    .clk            (calc_clk),
    .rst_n          (rst_n),
    .enable         (load_chirp2_enable),   // 产生chirp信号的触发标志，一个周期的脉冲信号
    .dout_switch    (data_chirp2_switch),   // 输出chirp信号源选择：2'b01为输出2048点原始的chirp信号；2'b10为输出4096点进行周期延拓后的chirp信号
    .step_phase     (parameter_phi_reg),    // step_phase = φ；数据类型为ufix32_32
    .dout_valid     (data_chirp2_valid),    // 输出数据有效,0-2047有效
    .chirp_real     (data_chirp2_real),     // cos，fix13_11;生成的chirp信号实部
    .chirp_imag     (data_chirp2_imag),     // sin，fix13_11;生成的chirp信号虚部
    .chirp_phase    (data_chirp2_phase),    // 生成的chirp相位信号；弧度值，ufix32_32
    .chirp_index    (index_chirp2)          // 生成的chirp信号的索引:0-2047
    );
    
    // dual_port_ram_hn_half写使能；可能存在bug：装载完成后可以不用立即失效
    assign dual_port_ram_hn_half_wr_enable = ((data_chirp2_valid == 1'b1) && (data_chirp2_switch == 2'b10)) ? 1'b1 : 1'b0;
    
    // 产生h(n)装载完成标志位
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            loaded_hn_half_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_hn_half_flag <= 1'b0;
        end else if(dual_port_ram_hn_half_wr_enable == 1'b1)begin
            if(index_chirp2 == 12'd2047)begin
                loaded_hn_half_flag <= 1'b1;
            end else begin
                loaded_hn_half_flag <= 1'b0; // 在此处清零标志位
            end
        end else begin // 锁存状态
            loaded_hn_half_flag <= loaded_hn_half_flag;
        end
    end
    
// 缓存chirp2信号的前2048点
dual_port_ram_bn u_dual_port_ram_gn_half_real(  // 实部
  .clka(calc_clk),                               // input wire clka
  .wea(dual_port_ram_hn_half_wr_enable),        // input wire [0 : 0] wea
  .addra(index_chirp2[10 : 0]),                 // input wire [10 : 0] addra
  .dina(data_chirp2_real),                      // input wire [12 : 0] dina
  .clkb(calc_clk),                               // input wire clkb
  .enb(hn_continuance_enable),                  // input wire enb
  .addrb(hn_continuance_rd_addr),               // input wire [10 : 0] addrb
  .doutb(dual_port_ram_hn_half_dout_real)       // output wire [12 : 0] doutb
);

dual_port_ram_bn u_dual_port_ram_gn_half_imag(  // 虚部
  .clka(calc_clk),                               // input wire clka
  .wea(dual_port_ram_hn_half_wr_enable),        // input wire [0 : 0] wea
  .addra(index_chirp2[10 : 0]),                 // input wire [10 : 0] addra
  .dina(data_chirp2_imag),                      // input wire [12 : 0] dina
  .clkb(calc_clk),                               // input wire clkb
  .enb(hn_continuance_enable),                  // input wire enb
  .addrb(hn_continuance_rd_addr),               // input wire [10 : 0] addrb
  .doutb(dual_port_ram_hn_half_dout_imag)       // output wire [12 : 0] doutb
);

    // 对hn_continuance_enable打一拍，以对齐数据输出
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            hn_continuance_enable_d <= 1'b0;
        end else begin
            hn_continuance_enable_d <= hn_continuance_enable;
        end
    end

    // 产生chirp信号的读地址
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            hn_continuance_rd_addr <= 12'd0;
            hn_reverse_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            hn_continuance_rd_addr <= 12'd0;
            hn_reverse_flag <= 1'b0;
        end else if(hn_continuance_enable == 1'b1)begin // 延拓使能有效期间
            if(hn_reverse_flag == 1'b0)begin 
                hn_continuance_rd_addr <= hn_continuance_rd_addr + 12'b1;  // n=2048时输出n=0时的值，并开始反向计数
                if(hn_continuance_rd_addr == 12'd2047)begin
                    hn_reverse_flag <= 1'b1;
                end
            end else begin
                hn_continuance_rd_addr <= hn_continuance_rd_addr - 12'b1;
            end
        end else begin // 清零
            hn_continuance_rd_addr <= 12'd0;
            hn_reverse_flag <= 1'b0;
        end    
    end

    // 产生延拓后的h(n)信号的写地址
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            hn_continuance_wr_addr <= 13'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            hn_continuance_wr_addr <= 13'd0;
        end else if(hn_continuance_enable_d == 1'b1)begin
            if(hn_continuance_wr_addr == 13'd4095)begin 
                hn_continuance_wr_addr <= hn_continuance_wr_addr + 13'b1; // 继续向上
            end else begin
                hn_continuance_wr_addr <= hn_continuance_wr_addr + 13'b1;
            end
        end else begin // 清零
            hn_continuance_wr_addr <= 13'd0;
        end    
    end

    // 产生延拓后的h(n)装载完成标志位
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            loaded_hn_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_hn_flag <= 1'b0;
        end else if(hn_continuance_enable_d == 1'b1)begin
            if(hn_continuance_wr_addr == 13'd4095)begin
                loaded_hn_flag <= 1'b1;
            end else begin
                loaded_hn_flag <= 1'b0; // 在此处清零标志位
            end
        end else begin // 锁存状态
            loaded_hn_flag <= loaded_hn_flag;
        end
    end
    
    // dual_port_ram_hn写使能；截断至4096点范围
    assign dual_port_ram_hn_wr_enable = ((hn_continuance_enable_d == 1'b1) && (hn_continuance_wr_addr <= 13'd4095)) ? 1'b1 : 1'b0;
    
    // dual_port_ram_hn写数据，n=2048点处改为补0
    assign dual_port_ram_hn_din_real = (hn_continuance_wr_addr == 13'd2048) ? 13'b0 : dual_port_ram_hn_half_dout_real;
    assign dual_port_ram_hn_din_imag = (hn_continuance_wr_addr == 13'd2048) ? 13'b0 : dual_port_ram_hn_half_dout_imag;
    
// 缓存延拓后的chirp2信号（即h(n)）
dual_port_ram_hn u_dual_port_ram_hn_real(   // 实部
  .clka(calc_clk),                           // input wire clka
  .wea(dual_port_ram_hn_wr_enable),         // input wire [0 : 0] wea
  .addra(hn_continuance_wr_addr),           // input wire [11 : 0] addra
  .dina(dual_port_ram_hn_din_real),         // input wire [12 : 0] dina
  .clkb(calc_clk),                           // input wire clkb
  .enb(xfft_dout_enable_d1),                // input wire enb
  .addrb(xfft_din_addr[11 : 0]),            // input wire [11 : 0] addrb
  .doutb(dual_port_ram_hn_dout_real)        // output wire [12 : 0] doutb
);

dual_port_ram_hn u_dual_port_ram_hn_imag(   // 虚部
  .clka(calc_clk),                           // input wire clka
  .wea(dual_port_ram_hn_wr_enable),         // input wire [0 : 0] wea
  .addra(hn_continuance_wr_addr),           // input wire [11 : 0] addra
  .dina(dual_port_ram_hn_din_imag),         // input wire [12 : 0] dina
  .clkb(calc_clk),                           // input wire clkb
  .enb(xfft_dout_enable_d1),                // input wire enb
  .addrb(xfft_din_addr[11 : 0]),            // input wire [11 : 0] addrb
  .doutb(dual_port_ram_hn_dout_imag)        // output wire [12 : 0] doutb
);

    // 产生b(n)装载完成标志位
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            loaded_bn_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_bn_flag <= 1'b0;
        end else if(dual_port_ram_bn_wr_enable == 1'b1)begin
            if(index_chirp2[11 : 0] == 12'd2047)begin
                loaded_bn_flag <= 1'b1;
            end else begin
                loaded_bn_flag <= 1'b0; // 在此处清零标志位
            end
        end else begin // 锁存状态
            loaded_bn_flag <= loaded_bn_flag;
        end
    end

    // dual_port_ram_bn写使能
    assign dual_port_ram_bn_wr_enable = ((data_chirp2_valid == 1'b1) && (data_chirp2_switch == 2'b01)) ? 1'b1 : 1'b0;
    
// 缓存chirp2信号的共轭信号（即b(n)）
dual_port_ram_bn u_dual_port_ram_bn_real(  // 实部
  .clka(calc_clk),                         // input wire clka
  .wea(dual_port_ram_bn_wr_enable),        // input wire [0 : 0] wea
  .addra(index_chirp2[10 : 0]),            // input wire [10 : 0] addra
  .dina(data_chirp2_real),                 // input wire [12 : 0] dina
  .clkb(calc_clk),                         // input wire clkb
  .enb(sync_output_3_enable),              // input wire enb；待修正：是否会和IFFT输出数据错位一个时钟（解决方法考虑对IFFT输出计数来产生使能信号）
  .addrb(cache_rd_addr_for_yk),            // input wire [10 : 0] addrb
  .doutb(dual_port_ram_bn_dout_real)       // output wire [12 : 0] doutb
);

dual_port_ram_bn u_dual_port_ram_bn_imag(  // 虚部
  .clka(calc_clk),                         // input wire clka
  .wea(dual_port_ram_bn_wr_enable),        // input wire [0 : 0] wea
  .addra(index_chirp2[10 : 0]),            // input wire [10 : 0] addra
  .dina(data_chirp2_imag),                 // input wire [12 : 0] dina
  .clkb(calc_clk),                         // input wire clkb
  .enb(sync_output_3_enable),              // input wire enb
  .addrb(cache_rd_addr_for_yk),            // input wire [10 : 0] addrb
  .doutb(dual_port_ram_bn_dout_imag)       // output wire [12 : 0] doutb
);

//--------------------------------对复数乘法器1输出做L点FFT：--------------------------------- 
    // FFT模块配置部分
    assign xfft_dout_s_axis_config_tdata = {PAD_0, SCALE_SCH_0, FWD_INV_0};

    // FFT模块输入部分，bit48，对齐到字节边界
    assign xfft_dout_Gr_s_axis_data_tdata = {1'b0, dual_port_ram_gn_dout_imag, 1'b0, dual_port_ram_gn_dout_real};
//    assign xfft_dout_Gr_s_axis_data_tdata = {1'b0, 23'b0, 1'b0, 15'b0, ad_data};

    // 对输入数据进行计数，产生输入源数据的读地址;0-4095
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            xfft_din_addr <= 13'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            xfft_din_addr <= 13'd0;
        end else if(xfft_dout_enable_d1 == 1'b1)begin   // 输出数据有效时开始计数
            if(xfft_din_addr == FFT_LEN - 1)begin 
                xfft_din_addr <= xfft_din_addr + 13'b1; // 不清零，但此时低12位已经置零    
            end else begin
                xfft_din_addr <= xfft_din_addr + 13'b1;
            end
        end else begin // 清零
            xfft_din_addr <= 13'd0;
        end    
    end
    
    // 产生xfft_dout_s_axis_data_tlast信号
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            xfft_dout_s_axis_data_tlast <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            xfft_dout_s_axis_data_tlast <= 1'b0;
        end else if(xfft_din_addr == FFT_LEN - 1)begin   // 输入第4096个数据，输出滞后一个时钟，所以输出到4096点时，计数器的值为4096
            xfft_dout_s_axis_data_tlast <= 1'b1;
        end else begin
            xfft_dout_s_axis_data_tlast <= 1'b0;
        end             
    end
    
    // 对xfft_dout_enable_d1打一拍，以对齐缓存的输出
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            xfft_dout_enable_d2 <= 1'b0;
        end else begin
            xfft_dout_enable_d2 <= xfft_dout_enable_d1;
        end
    end
    
    // 产生xfft_dout_s_axis_data_tvalid信号
    assign xfft_dout_s_axis_data_tvalid = ((xfft_dout_enable_d2 == 1'b1) && (xfft_din_addr <= 13'd4096)) ? 1'b1 : 1'b0;
    
    // fft模块使能后延迟一段时间，等待配置完成
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            xfft_trans_delay <= 5'd0;
            xfft_dout_enable_d1 <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if((czt_enable == 1'b1) || (xfft_dout_enable == 1'b0))begin
            xfft_trans_delay <= 5'd0;
            xfft_dout_enable_d1 <= 1'b0;
        end else if(xfft_trans_delay == 5'd30)begin // 记到30之后，使能缓存输出
            xfft_dout_enable_d1 <= xfft_dout_enable;
        end else if(xfft_dout_enable == 1'b1)begin // 开始计数，等待配置fft ip core
            xfft_trans_delay <= xfft_trans_delay + 5'd1;
            xfft_dout_enable_d1 <= xfft_dout_enable_d1;
        end
    end

// 4096点FFT运算；待修正：xfft_dout_enable是否需要打一拍
xfft_dout_Gr u_xfft_dout_Gr(
  .aclk(calc_clk),                                                          // input wire aclk
  .aresetn(xfft_dout_enable),                                              // input wire aresetn
  
  .s_axis_config_tdata(xfft_dout_s_axis_config_tdata),                     // input wire [31 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                                             // input wire s_axis_config_tvalid
  .s_axis_config_tready(xfft_dout_Gr_s_axis_config_tready),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(xfft_dout_Gr_s_axis_data_tdata),                      // fix23_22,,input wire [47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(xfft_dout_s_axis_data_tvalid),                       // input wire s_axis_data_tvalid
  .s_axis_data_tready(xfft_dout_Gr_s_axis_data_tready),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(xfft_dout_s_axis_data_tlast),                         // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(xfft_dout_Gr_m_axis_data_tdata),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tuser(xfft_dout_Gr_m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
  .m_axis_data_tvalid(xfft_dout_Gr_m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                                               // input wire m_axis_data_tready
  .m_axis_data_tlast(xfft_dout_Gr_m_axis_data_tlast),                      // output wire m_axis_data_tlast
  
  .event_frame_started(xfft_dout_Gr_event_frame_started),                  // output wire event_frame_started
  .event_tlast_unexpected(xfft_dout_Gr_event_tlast_unexpected),            // output wire event_tlast_unexpected
  .event_tlast_missing(xfft_dout_Gr_event_tlast_missing),                  // output wire event_tlast_missing
  .event_status_channel_halt(xfft_dout_Gr_event_status_channel_halt),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(xfft_dout_Gr_event_data_in_channel_halt),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(xfft_dout_Gr_event_data_out_channel_halt)  // output wire event_data_out_channel_halt
);
    // 输出数据截断至18bit,注意负数截断
//    assign xfft_dout_Gr_m_axis_data_tdata_truncation = {6'b0, xfft_dout_Gr_m_axis_data_tdata[46 : 29], 6'b0, xfft_dout_Gr_m_axis_data_tdata[22 : 5]};
    assign xfft_dout_Gr_m_axis_data_tdata_real_truncation = (xfft_dout_Gr_m_axis_data_tdata[22] == 1'b1) ? xfft_dout_Gr_m_axis_data_tdata[22 : 5] + 1'b1 : xfft_dout_Gr_m_axis_data_tdata[22 : 5];
    assign xfft_dout_Gr_m_axis_data_tdata_imag_truncation = (xfft_dout_Gr_m_axis_data_tdata[46] == 1'b1) ? xfft_dout_Gr_m_axis_data_tdata[46 : 29] + 1'b1 :xfft_dout_Gr_m_axis_data_tdata[46 : 29];
    assign xfft_dout_Gr_m_axis_data_tdata_truncation = {6'b0, xfft_dout_Gr_m_axis_data_tdata_imag_truncation, 6'b0, xfft_dout_Gr_m_axis_data_tdata_real_truncation};
//    assign xfft_dout_Gr_m_axis_data_tdata_truncation = xfft_dout_Gr_m_axis_data_tdata >> 5; // 有误

    // for debug
    assign xfft_dout_Gr_index = xfft_dout_Gr_m_axis_data_tuser[11 : 0];
    
//-------------------------------对补齐后的chirp2信号做L点FFT：-------------------------------
// FFT模块输入部分，bit32，对齐到字节边界
//assign xfft_dout_Hr_s_axis_data_tdata = {1'b0, dual_port_ram_hn_dout_imag, 10'b0, 1'b0, dual_port_ram_hn_dout_real, 10'b0};
assign xfft_dout_Hr_s_axis_data_tdata = {3'b0, dual_port_ram_hn_dout_imag, 3'b0, dual_port_ram_hn_dout_real};

xfft_dout_Hr u_xfft_dout_Hr(
  .aclk(calc_clk),                                                          // input wire aclk
  .aresetn(xfft_dout_enable),                                              // input wire aresetn
  
  .s_axis_config_tdata(xfft_dout_s_axis_config_tdata),                     // input wire [31 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                                             // input wire s_axis_config_tvalid
  .s_axis_config_tready(xfft_dout_Hr_s_axis_config_tready),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(xfft_dout_Hr_s_axis_data_tdata),                      // input wire 1.[31 : 0] / 2.[47 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(xfft_dout_s_axis_data_tvalid),                       // input wire s_axis_data_tvalid
  .s_axis_data_tready(xfft_dout_Hr_s_axis_data_tready),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(xfft_dout_s_axis_data_tlast),                         // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(xfft_dout_Hr_m_axis_data_tdata),                      // output wire 1.[31 : 0] / 2.[47 : 0]  m_axis_data_tdata
  .m_axis_data_tuser(xfft_dout_Hr_m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
  .m_axis_data_tvalid(xfft_dout_Hr_m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                                               // input wire m_axis_data_tready
  .m_axis_data_tlast(xfft_dout_Hr_m_axis_data_tlast),                      // output wire m_axis_data_tlast
  
  .event_frame_started(xfft_dout_Hr_event_frame_started),                  // output wire event_frame_started
  .event_tlast_unexpected(xfft_dout_Hr_event_tlast_unexpected),            // output wire event_tlast_unexpected
  .event_tlast_missing(xfft_dout_Hr_event_tlast_missing),                  // output wire event_tlast_missing
  .event_status_channel_halt(xfft_dout_Hr_event_status_channel_halt),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(xfft_dout_Hr_event_data_in_channel_halt),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(xfft_dout_Hr_event_data_out_channel_halt)  // output wire event_data_out_channel_halt
);

    // for debug
    assign xfft_dout_Hr_index = xfft_dout_Hr_m_axis_data_tuser[11 : 0];    
//----------------------------------xfft结果缓存及读出部分：----------------------------------
    // 提供后2048点的写使能
    assign cache_wr_enable = ((xfft_dout_Gr_m_axis_data_tvalid == 1'b1) && (xfft_dout_Gr_index >= 12'd2048)) ? 1'b1 : 1'b0;
    
    // 单独缓存直流分量
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            Gr_dc_component <= 48'd0;
            Hr_dc_component <= 32'd0;
            first_flag      <= 1'b0;
        // 使用czt_enable有效时清零
        end else if(czt_enable == 1'b1)begin
            Gr_dc_component <= 48'd0;
            Hr_dc_component <= 32'd0;
            first_flag      <= 1'b0;
        end else if((xfft_dout_Gr_m_axis_data_tvalid == 1'b1) && (xfft_dout_Gr_index == 12'd0) && (first_flag == 1'b0))begin
            Gr_dc_component <= xfft_dout_Gr_m_axis_data_tdata_truncation;
            Hr_dc_component <= xfft_dout_Hr_m_axis_data_tdata;
            first_flag      <= 1'b1;
        end else begin
            Gr_dc_component <= Gr_dc_component;
            Hr_dc_component <= Hr_dc_component;
            first_flag      <= first_flag;
        end
    end
    
    // 写地址
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            cache_wr_addr <= 11'd2047;
        end else if(cache_wr_enable == 1'b1)begin
            cache_wr_addr <= cache_wr_addr - 11'd1; // 倒序写入
        end else begin
            cache_wr_addr <= 11'd2047;
        end
    end
    
    // 产生Gr和Hr装载完成标志
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            loaded_Gr_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_Gr_flag <= 1'b0;
        end else if(cache_wr_addr == 11'd0)begin
            loaded_Gr_flag <= 1'b1;
        end else begin
            loaded_Gr_flag <= loaded_Gr_flag;
        end
    end

// Gr
cache_Gr u_cache_Gr(
  .clka(calc_clk),                                    // input wire clka
  .wea(cache_wr_enable),                             // input wire [0 : 0] wea
  .addra(cache_wr_addr),                             // input wire [10 : 0] addra
  .dina(xfft_dout_Gr_m_axis_data_tdata_truncation),  // input wire [47 : 0] dina
  .clkb(calc_clk),                                    // input wire clkb
  .enb(xifft_dout_enable),                           // input wire enb
  .addrb(cache_rd_addr),                             // input wire [10 : 0] addrb
  .doutb(cache_Gr_dout)                              // output wire [47 : 0] doutb
);

// Hr
cache_Hr u_cache_Hr(
  .clka(calc_clk),                           // input wire clka
  .wea(cache_wr_enable),                    // input wire [0 : 0] wea
  .addra(cache_wr_addr),                    // input wire [10 : 0] addra
  .dina(xfft_dout_Hr_m_axis_data_tdata),    // input wire [31 : 0] dina
  .clkb(calc_clk),                           // input wire clkb
  .enb(xifft_dout_enable),                  // input wire enb
  .addrb(cache_rd_addr),                    // input wire [10 : 0] addrb
  .doutb(cache_Hr_dout)                     // output wire [31 : 0] doutb
);
    
    // 读地址逻辑
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            cache_rd_addr <= 11'd0;
            cmpy_2_reverse_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            cache_rd_addr <= 11'd0;
            cmpy_2_reverse_flag <= 1'b0;
        end else if(xifft_dout_enable == 1'b1)begin
            if(cmpy_2_reverse_flag == 1'b0)begin
                cache_rd_addr <= cache_rd_addr + 11'd1;
                if(cache_rd_addr == 11'd2046)begin
                    cmpy_2_reverse_flag <= 1'b1;
                end
            end else begin
                cache_rd_addr <= cache_rd_addr - 11'd1;
            end
        end else begin
            cache_rd_addr <= 11'd0;
            cmpy_2_reverse_flag <= 1'b0;
        end
    end
    
    // 读数据,N / 2之后的点虚部取补码
    assign cmpy_2_s_axis_a_tdata = ((cmpy_2_reverse_flag == 1'b1) && (xfft_dout_index >= 12'd2049)) ? {1'b1, ~cache_Gr_dout[46 : 24] + 1'b1, cache_Gr_dout[23 : 0]} :
                                    (xfft_dout_index == 12'd0) ? Gr_dc_component : cache_Gr_dout;
    assign cmpy_2_s_axis_b_tdata = ((cmpy_2_reverse_flag == 1'b1) && (xfft_dout_index >= 12'd2049)) ? {3'b1, ~cache_Hr_dout[28 : 16] + 1'b1, cache_Hr_dout[15 : 0]} : 
                                    (xfft_dout_index == 12'd0) ? Hr_dc_component : cache_Hr_dout;
                                    
    // for debug
    assign xfft_dout_Gr_real  = cmpy_2_s_axis_a_tdata[22 : 0];
    assign xfft_dout_Gr_imag  = cmpy_2_s_axis_a_tdata[46 : 24];
    assign xfft_dout_Hr_real  = cmpy_2_s_axis_b_tdata[12 : 0];
    assign xfft_dout_Hr_imag  = cmpy_2_s_axis_b_tdata[28 : 16];
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            xfft_dout_index <= 12'd0;
        end else if(xifft_dout_enable == 1'b1)begin
            xfft_dout_index <= xfft_dout_index + 1;                    
        end
    end
    
//------------------------------------复数乘法器_level2：------------------------------------
// 同步输入G(r)和H(r)，输出结果滞后时钟使能信号6个时钟周期;aresetn失能两个时钟后数据线失能
cmpy_2 u_cmpy_dout_Yr(
  .aclk(calc_clk),                                           // input wire aclk
  .aresetn(xifft_dout_enable),                              // input wire aresetn
  .s_axis_a_tvalid(xifft_dout_enable),                      // input wire s_axis_a_tvalid
  .s_axis_a_tdata(cmpy_2_s_axis_a_tdata),                   // input wire [47 : 0] s_axis_a_tdata，将fft输出结果右移5位，截断为bit18
  .s_axis_b_tvalid(xifft_dout_enable),                      // input wire s_axis_b_tvalid
  .s_axis_b_tdata(cmpy_2_s_axis_b_tdata),                   // input wire [31 : 0] s_axis_b_tdata，bit13
  .m_axis_dout_tvalid(cmpy_2_m_axis_dout_tvalid),           // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(cmpy_2_m_axis_dout_tdata)              // output wire [63: 0] m_axis_dout_tdata，结果为bit32（bit37超过xfft输入数据位宽上限）
);
    
    // for debug
    assign cmpy_2_dout_Yk_real = cmpy_2_m_axis_dout_tdata[31 : 0];
    assign cmpy_2_dout_Yk_imag = cmpy_2_m_axis_dout_tdata[63 : 32];

//--------------------------------对复数乘法器2输出做L点IFFT：-------------------------------- 
// IFFT模块配置部分
assign xifft_dout_s_axis_config_tdata = {PAD_0, SCALE_SCH_1, FWD_INV_1};

    // 对输入数据进行计数；待修正：cmpy_2_m_axis_dout_tvalid常有效;1-4096
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            ifft_din_cnt <= 13'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            ifft_din_cnt <= 13'd0;
        end else if(cmpy_2_m_axis_dout_tvalid == 1'b1)begin // chirp_gen2模块输出数据有效时开始计数
            if(ifft_din_cnt == FFT_LEN)begin 
                ifft_din_cnt <= ifft_din_cnt + 13'b1;  // 不清零
            end else begin
                ifft_din_cnt <= ifft_din_cnt + 13'b1;
            end
        end else begin
            ifft_din_cnt <= 13'd0;
        end    
    end
    
    // 产生xifft_dout_yk_s_axis_data_tlast信号
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            xifft_dout_yk_s_axis_data_tlast <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            xifft_dout_yk_s_axis_data_tlast <= 1'b0; 
        end else if(ifft_din_cnt == FFT_LEN - 2)begin
            xifft_dout_yk_s_axis_data_tlast <= 1'b1;
        end else begin
            xifft_dout_yk_s_axis_data_tlast <= 1'b0;                    
        end
    end

// 4096点IFFT运算，未使用复位端口
xifft_dout_yk u_xifft_dout_yk(
  .aclk(calc_clk),                                                           // input wire aclk
  .aresetn(xifft_dout_enable),                                              // input wire aresetn
  
  .s_axis_config_tdata(xifft_dout_s_axis_config_tdata),                     // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                                              // input wire s_axis_config_tvalid
  .s_axis_config_tready(xifft_dout_yk_s_axis_config_tready),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(cmpy_2_m_axis_dout_tdata),                             // input wire [63 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(cmpy_2_m_axis_dout_tvalid),                           // input wire s_axis_data_tvalid
  .s_axis_data_tready(xifft_dout_yk_s_axis_data_tready),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(xifft_dout_yk_s_axis_data_tlast),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(xifft_dout_yk_m_axis_data_tdata),                      // output wire [63 : 0] m_axis_data_tdata
  .m_axis_data_tuser(xifft_dout_yk_m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
  .m_axis_data_tvalid(xifft_dout_yk_m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                                                // input wire m_axis_data_tready
  .m_axis_data_tlast(xifft_dout_yk_m_axis_data_tlast),                      // output wire m_axis_data_tlast
  
  .event_frame_started(xifft_dout_yk_event_frame_started),                   // output wire event_frame_started
  .event_tlast_unexpected(xifft_dout_yk_event_tlast_unexpected),             // output wire event_tlast_unexpected
  .event_tlast_missing(xifft_dout_yk_event_tlast_missing),                   // output wire event_tlast_missing
  .event_status_channel_halt(xifft_dout_yk_event_status_channel_halt),       // output wire event_status_channel_halt
  .event_data_in_channel_halt(xifft_dout_yk_event_data_in_channel_halt),     // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(xifft_dout_yk_event_data_out_channel_halt)   // output wire event_data_out_channel_halt
);
    
    // 输出数据实部和虚部，for debug
    assign xifft_dout_yk_real = xifft_dout_yk_m_axis_data_tdata[31 : 0];
    assign xifft_dout_yk_imag = xifft_dout_yk_m_axis_data_tdata[63 : 32];

    // IFFT输出点的索引
    assign xifft_dout_yk_index = xifft_dout_yk_m_axis_data_tuser[11 : 0];

//----------------------------------xifft结果缓存及读出部分：----------------------------------
    // 提供后2048点的写使能
    assign cache_yk_enable = ((xifft_dout_yk_m_axis_data_tvalid == 1'b1) && (xifft_dout_yk_index >= 12'd2048)) ? 1'b1 : 1'b0;
    
    // 写地址
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            cache_wr_addr_for_yk <= 11'd2047;
        end else if(cache_yk_enable == 1'b1)begin
            cache_wr_addr_for_yk <= cache_wr_addr_for_yk - 11'd1; // 倒序写入
        end else begin
            cache_wr_addr_for_yk <= 11'd2047;
        end
    end
    
    // 产生Gr和Hr装载完成标志
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            loaded_yk_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            loaded_yk_flag <= 1'b0;
        end else if(cache_wr_addr_for_yk == 11'd0)begin
            loaded_yk_flag <= 1'b1;
        end else begin
            loaded_yk_flag <= loaded_yk_flag;
        end
    end

// yk
cache_yk u_cache_yk(
  .clka(calc_clk),                          // input wire clka
  .wea(cache_yk_enable),                    // input wire [0 : 0] wea
  .addra(cache_wr_addr_for_yk),             // input wire [10 : 0] addra
  .dina(xifft_dout_yk_m_axis_data_tdata),   // input wire [63 : 0] dina
  .clkb(calc_clk),                          // input wire clkb
  .enb(sync_output_3_enable),               // input wire enb
  .addrb(cache_rd_addr_for_yk),             // input wire [10 : 0] addrb
  .doutb(cache_yk_dout)                     // output wire [63 : 0] doutb
);

// 读地址逻辑
    always @(posedge calc_clk or negedge rst_n) begin
        if(~rst_n)begin
            cache_rd_addr_for_yk <= 11'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            cache_rd_addr_for_yk <= 11'd0;
        end else if(sync_output_3_enable == 1'b1)begin
            cache_rd_addr_for_yk <= cache_rd_addr_for_yk + 1'b1;
        end else begin
            cache_rd_addr_for_yk <= 11'd0;
        end
    end
    
    // for debug
    assign cache_yk_dout_real  = cache_yk_dout[31 : 0];
    assign cache_yk_dout_imag  = cache_yk_dout[63 : 32];

//------------------------------------复数乘法器_level3：------------------------------------    
    // 对sync_output_3_enable打一拍，以对齐输出
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            sync_output_3_enable_d <= 1'b0;
        end else begin
            sync_output_3_enable_d <= sync_output_3_enable;
        end
    end
    
    // 输入b(n)
    assign cmpy_3_din_bn_s_axis_data_tdata = {3'b0, dual_port_ram_bn_dout_imag, 3'b0, dual_port_ram_bn_dout_real};
    
    // cmpy_3输入数据通道a仅截取前M点IFFT数据
    assign cmpy_3_s_axis_aandb_tvalid = sync_output_3_enable_d;

// 同步输入y(k)和b(n)，输出结果滞后时钟使能信号6个时钟周期
cmpy_3 u_cmpy_dout_Xk(
  .aclk(calc_clk),                                           // input wire aclk
  .aresetn(sync_output_3_enable),                            // input wire aresetn
  .s_axis_a_tvalid(cmpy_3_s_axis_aandb_tvalid),              // input wire s_axis_a_tvalid
  .s_axis_a_tdata(cache_yk_dout),                            // input wire [63 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(cmpy_3_s_axis_aandb_tvalid),              // input wire s_axis_b_tvalid
  .s_axis_b_tdata(cmpy_3_din_bn_s_axis_data_tdata),          // input wire [31 : 0] s_axis_b_tdata
  .m_axis_dout_tvalid(cmpy_3_m_axis_dout_tvalid),            // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(cmpy_3_m_axis_dout_tdata)               // output wire [95 : 0] m_axis_dout_tdata
);
    
    // for debug
    assign Xk_real = cmpy_3_m_axis_dout_tdata[45 : 0];
    assign Xk_imag = cmpy_3_m_axis_dout_tdata[93 : 48];
    
    // 1.cmpy_3输出数据通道仅截取前M点IFFT数据，并且该标志位已经打了一拍;1-4096
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            cmpy_3_m_axis_dout_tvalid_truncation <= 1'b0;
            cmpy_3_dout_cnt <= 13'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            cmpy_3_m_axis_dout_tvalid_truncation <= 1'b0;
            cmpy_3_dout_cnt <= 13'd0;
        end else if(cmpy_3_m_axis_dout_tvalid == 1'b1)begin
            if(cmpy_3_dout_cnt == 13'd2048)begin
                cmpy_3_m_axis_dout_tvalid_truncation <= 1'b0;
                // 不对cmpy_3_dout_cnt清零，相当于只向上计数到12'd2048后停止
            end else begin
                cmpy_3_m_axis_dout_tvalid_truncation <= 1'b1;
                cmpy_3_dout_cnt <= cmpy_3_dout_cnt + 13'd1;
            end
        end else begin
            cmpy_3_m_axis_dout_tvalid_truncation <= 1'b0;
            cmpy_3_dout_cnt <= 13'd0; // 输出点数计数器在此处清零
        end
    end

//------------------------------------计算czt结果幅度谱：------------------------------------
// 求解czt结果的实部和虚部平方和
mult_dout_Xk u_mult_dout_Xk_real(
  .CLK(calc_clk),                           // input wire CLK
  .A(cmpy_3_m_axis_dout_tdata[45 : 0]),     // input wire [45 : 0] A
  .B(cmpy_3_m_axis_dout_tdata[45 : 0]),     // input wire [45 : 0] B
  .P(mult_dout_Xk_real)                     // output wire [91 : 0] P
);

mult_dout_Xk u_mult_dout_Xk_imag(
  .CLK(calc_clk),                           // input wire CLK
  .A(cmpy_3_m_axis_dout_tdata[93 : 48]),    // input wire [45 : 0] A
  .B(cmpy_3_m_axis_dout_tdata[93 : 48]),    // input wire [45 : 0] B
  .P(mult_dout_Xk_imag)                     // output wire [91 : 0] P
);
    
    // for debug
    assign Xk_data  = mult_dout_Xk_real + mult_dout_Xk_imag;
    assign Xk_index = dual_port_ram_Xk_wr_addr;
    
    // czt输出结果缓存时的写地址，并产生X(k)装载完成标志位
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            dual_port_ram_Xk_wr_addr <= 11'd0;
            loaded_Xk_flag <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            dual_port_ram_Xk_wr_addr <= 11'd0;
            loaded_Xk_flag <= 1'b0;
        end else if(cmpy_3_m_axis_dout_tvalid_truncation == 1'b1)begin
            if(dual_port_ram_Xk_wr_addr == 11'd2047)begin
//                dual_port_ram_Xk_wr_addr <= dual_port_ram_Xk_wr_addr + 1'b1;
                loaded_Xk_flag <= 1'b1;
            end else begin
                dual_port_ram_Xk_wr_addr <= dual_port_ram_Xk_wr_addr + 1'b1;
                loaded_Xk_flag <= 1'b0; // 在此处清零标志位
            end
        end else begin // 锁存状态
            dual_port_ram_Xk_wr_addr <= 11'd0;
            loaded_Xk_flag <= loaded_Xk_flag;
        end
    end
    
    // 对loaded_Xk_flag打一拍
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            loaded_Xk_flag_d <= 1'b0;
        end else begin
            loaded_Xk_flag_d <= loaded_Xk_flag;
        end
    end
    
    // 输出读数据
    always@(posedge calc_clk or negedge rst_n)begin
        if(~rst_n)begin
            dual_port_ram_Xk_rd_addr <= 11'd0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            dual_port_ram_Xk_rd_addr <= 11'd0;
        end else if(czt_finish_flag == 1'b1)begin // 持续读出
            dual_port_ram_Xk_rd_addr <= dual_port_ram_Xk_rd_addr + 11'd1;
        end else begin
            dual_port_ram_Xk_rd_addr <= 11'd0;
        end
    end
    
// 缓存czt结果（幅度谱）
dual_port_ram_Xk u_dual_port_ram_Xk(
  .clka(calc_clk),                              // input wire clka
  .wea(cmpy_3_m_axis_dout_tvalid_truncation),   // input wire [0 : 0] wea
  .addra(dual_port_ram_Xk_wr_addr),             // input wire [10 : 0] addra
  .dina(Xk_data),                               // input wire [92 : 0] dina
  .clkb(calc_clk),                              // input wire clkb
  .enb(czt_finish_flag),                        // input wire enb
  .addrb(dual_port_ram_Xk_rd_addr),             // input wire [10 : 0] addrb
  .doutb(czt_dout_data)                         // output wire [92 : 0] doutb
);

    // 计算细化后的频谱最大点的频率；对Xk_data截断至64bit；max_data不对直流分量进行分析（注意频谱泄露）
    always@(posedge calc_clk or negedge rst_n)begin
        if(~rst_n)begin
            max_data  <= 93'b0;
            max_index <= 11'b0;
            Xk_data_truncation <= 64'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            max_data  <= 93'b0;
            max_index <= 11'b0;
            Xk_data_truncation <= 64'b0;
        end else begin
            // 不分析直流分量，即dual_port_ram_Xk_wr_addr >= origin_index
            if((cmpy_3_m_axis_dout_tvalid_truncation == 1'b1) && (dual_port_ram_Xk_wr_addr >= 11'd0))begin
                if(Xk_data > max_data)begin
                    max_data  <= Xk_data;
                    Xk_data_truncation <= Xk_data[92 : 29];
                    max_index <= dual_port_ram_Xk_wr_addr;
                end else begin
                    max_data  <= max_data;
                    Xk_data_truncation <= Xk_data[92 : 29];
                    max_index <= max_index;
                end
            end else begin
                max_data  <= max_data;
                Xk_data_truncation <= 64'b0;
                max_index <= max_index;
            end
        end
    end
    
    // 输出结果的索引
    assign czt_dout_index = dual_port_ram_Xk_rd_addr - 1'b1;
    
    // 寻找幅度谱峰值的为1的最高位
    always@(posedge calc_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            msb_position   <= 7'd0;
            czt_dout_valid <= 1'b0;
        // 使用czt_enable有效时清零所有状态
        end else if(czt_enable == 1'b1)begin
            msb_position   <= 7'd0;
            czt_dout_valid <= 1'b0;
        end else if((czt_finish_flag == 1'b1) && (czt_dout_valid == 1'b0))begin // 寻找到最大值，但未确定最大值为1的最高位
            if(max_data[92 - msb_position] == 1'b1)begin
                czt_dout_valid <= 1'b1;
            end else begin
                msb_position <= msb_position + 7'd1;
            end
        end else begin // 锁存结果
            msb_position   <= msb_position;
            czt_dout_valid <= czt_dout_valid;
        end
    end
    
//-----------------------------------------参数定义：-----------------------------------------   
    // state space，v8.0
    parameter INIT  = 8'b00000001;  // INIT：等待触发chirp-z变换，同时缓存上一次Z的czt结果；
    parameter CZT_0 = 8'b00000010;  // CZT_0：计算窄带信号的相关参数θ和φ；
    parameter CZT_1 = 8'b00000100;  // CZT_1：装载2048个采样数据x(n)、缓存chirp1信号（即a(n)）和chirp2信号（即h(n)）的前2048点；
    parameter CZT_2 = 8'b00001000;  // CZT_2：同步产生x(n)和a(n)信号，送入复数乘法器1，完成2048点的复数乘法，并缓存结果、将chirp2信号（即h(n)）延拓至4096点；
    parameter CZT_3 = 8'b00010000;  // CZT_3：复数乘法器1的输出结果g(n)补零至4096点(L点)、缓存chirp2信号的共轭信号（即b(n)）；
    parameter CZT_4 = 8'b00100000;  // CZT_4：将g(n)和h(n)同步进行4096点的FFT，取出前（2048+1）点后，通过圆周共轭得到剩余的2047点；
    parameter CZT_5 = 8'b01000000;  // CZT_5：后将两路4096点的FFT结果一一对应送入复数乘法器2；完成4096点的复数乘法后，把结果送入xifft模块；完成4096点的IFFT运算后，截取并缓存后2048点
    parameter CZT_6 = 8'b10000000;  // CZT_6：y(n)与b(n)信号一一对应送入复数乘法器3，缓存czt结果X(zk)。  
    
//-----------------------------------三段式状态机模块：--------------------------------------- 
    // 状态转移
    always@(posedge calc_clk or negedge rst_n)begin
	    if(~rst_n)
		   cur_state <= INIT;
	    else
		   cur_state <= nxt_state;
    end
        
    // 转移条件判断
    always @(*) begin
        case(cur_state)
            INIT : begin
                // 触发chirp-z变换
                if(czt_enable == 1'b1)begin 
                    nxt_state <= CZT_0;
                end else begin
                    nxt_state <= INIT;
                end
            end CZT_0 : begin
                // 参数计算完成
                if(param_calc_dout_valid == 1'b1)begin 
                    nxt_state <= CZT_1;
                end else begin
                    nxt_state <= CZT_0;
                end
            end CZT_1 : begin
                // 各信号已缓存完成
                if((loaded_xn_flag == 1'b1) && (loaded_an_flag == 1'b1) && (loaded_hn_half_flag == 1'b1))begin
                    nxt_state <= CZT_2;
                end else begin
                    nxt_state <= CZT_1;
                end
            end CZT_2 : begin
                // 乘法器输出结果缓存完成、h(n)延拓完成
                if((cmpy_1_dout_flag == 1'b1) && (loaded_hn_flag == 1'b1))begin 
                    nxt_state <= CZT_3;
                end else begin
                    nxt_state <= CZT_2;
                end
            end CZT_3 : begin
                // g(n)序列补零完成、b(n)序列缓存完成
                if((zero_fill_flag == 1'b1) && (loaded_bn_flag == 1'b1))begin 
                    nxt_state <= CZT_4;
                end else begin
                    nxt_state <= CZT_3;
                end
            end CZT_4 : begin
                // G(r)、H(r)缓存完成缓存完成
                if(loaded_Gr_flag == 1'b1)begin 
                    nxt_state <= CZT_5;
                end else begin
                    nxt_state <= CZT_4;
                end
            end CZT_5 : begin
                // xifft结果y(k)缓存完成
                if(loaded_yk_flag == 1'b1)begin 
                    nxt_state <= CZT_6;
                end else begin
                    nxt_state <= CZT_5;
                end
            end CZT_6 : begin
                // czt结果X(k)缓存完成
                if(loaded_Xk_flag_d == 1'b1)begin 
                    nxt_state <= INIT;
                end else begin
                    nxt_state <= CZT_6;
                end
            end default : begin
                nxt_state <= INIT;
            end
        endcase
    end
    
    // 同步时序输出
    always@(posedge calc_clk or negedge rst_n)begin
        if(!rst_n)begin
            load_xn_enable        <= 1'b0;
            param_calc_enable     <= 1'b0;
            load_chirp1_enable    <= 1'b0;
            load_chirp2_enable    <= 1'b0;
            sync_output_1_enable  <= 1'b0; 
            cmpy_1_enable         <= 1'b0;
            hn_continuance_enable <= 1'b0;
            zero_fill_enable      <= 1'b0;
            data_chirp2_switch    <= 2'b00;
            xfft_dout_enable      <= 1'b0;
            xifft_dout_enable     <= 1'b0;
            sync_output_3_enable  <= 1'b0;
            czt_finish_flag       <= 1'b0;
            led_1                 <= 1'b0;
            led_2                 <= 1'b0;
        end else begin
            case(nxt_state)
                INIT : begin          // 等待触发chirp-z变换，同时缓存上一次的czt结果；
                    // 失能所有无关信号
                    param_calc_enable     <= 1'b0;
                    load_xn_enable        <= 1'b0;
                    load_chirp1_enable    <= 1'b0;
                    load_chirp2_enable    <= 1'b0;
                    sync_output_1_enable  <= 1'b0; 
                    cmpy_1_enable         <= 1'b0;
                    hn_continuance_enable <= 1'b0;
                    zero_fill_enable      <= 1'b0;
                    data_chirp2_switch    <= 2'b00;
                    xfft_dout_enable      <= 1'b0;
                    xifft_dout_enable     <= 1'b0;
                    sync_output_3_enable  <= 1'b0;
                end CZT_0 : begin     // 计算窄带信号的相关参数θ和φ；
                    led_2                 <= 1'b0;
                    // 失能标志位，此时等效czt_enable有效时清零标志位
                    czt_finish_flag       <= 1'b0;
                    // 使能计算信号
                    param_calc_enable     <= 1'b1;
                end CZT_1 : begin     // 装载2048个采样数据x(n)、缓存chirp1信号（即a(n)）和chirp2信号（即h(n)）的前2048点；
                    // 失能计算信号
                    param_calc_enable     <= 1'b0;
                    // 使能缓存相关信号
                    load_xn_enable        <= 1'b1; 
                    load_chirp1_enable    <= 1'b1;
                    load_chirp2_enable    <= 1'b1;
                    data_chirp2_switch    <= 2'b10;
                end CZT_2 : begin // 同步产生x(n)和a(n)信号，送入复数乘法器1，完成2048点的复数乘法，并缓存结果、将chirp2信号（即h(n)）延拓至4096点；
                    // 失能缓存的相关信号
                    load_xn_enable        <= 1'b0;  
                    param_calc_enable     <= 1'b0;
                    load_chirp1_enable    <= 1'b0;
                    load_chirp2_enable    <= 1'b0;  // 失能两个chirp_gen模块，使得下一次使能时的电平信号可被采集到
                    data_chirp2_switch    <= 2'b00;
                    // 使能同步输入信号1和h(n)延拓信号
                    sync_output_1_enable  <= 1'b1;  
                    cmpy_1_enable         <= 1'b1;
                    hn_continuance_enable <= 1'b1;
                end CZT_3 : begin // 复数乘法器1的输出结果g(n)补零至4096点(L点)、缓存chirp2信号的共轭信号（即b(n)）；
                    // 失能同步输入信号1和h(n)延拓信号
                    sync_output_1_enable  <= 1'b0;
                    cmpy_1_enable         <= 1'b0;
                    hn_continuance_enable <= 1'b0;
                    // 使能补零和缓存信号
                    zero_fill_enable      <= 1'b1;
                    load_chirp2_enable    <= 1'b1;
                    data_chirp2_switch   <= 2'b01;
                end CZT_4 : begin // 将g(n)和h(n)同步进行4096点的FFT，取出前（2048+1）点后，通过圆周共轭得到剩余的2047点；
                    // 失能补零和缓存信号
                    zero_fill_enable      <= 1'b0;
                    load_chirp2_enable    <= 1'b0;
                    data_chirp2_switch    <= 2'b00;
                    // 使能同步输入信号2
                    xfft_dout_enable      <= 1'b1;
//                    led_1                 <= 1'b1;
                end CZT_5 : begin // 后将两路4096点的FFT结果一一对应送入复数乘法器2；完成4096点的复数乘法后，把结果送入xifft模块；完成4096点的IFFT运算后，截取并缓存后2048点
                    // 失能同步输入信号2
                    xfft_dout_enable      <= 1'b0;
                    // 使能傅里叶逆变换
                    xifft_dout_enable     <= 1'b1;
                    
                end CZT_6 : begin // y(n)与b(n)信号一一对应送入复数乘法器3，截取前M点的结果，缓存czt结果X(zk)。 
                    // 失能傅里叶逆变换
                    xifft_dout_enable     <= 1'b0;
                    // 使能同步输入信号3
                    sync_output_3_enable  <= 1'b1;
                    led_1                 <= 1'b1;
                    // 使能标志位
                    if(loaded_Xk_flag == 1'b1)begin 
                        czt_finish_flag   <= 1'b1;
                        led_2             <= 1'b1;
                    end
                end default : begin
                    // 失能所有无关信号
                    load_xn_enable        <= 1'b0;
                    param_calc_enable     <= 1'b0;
                    load_chirp1_enable    <= 1'b0;
                    load_chirp2_enable    <= 1'b0;
                    sync_output_1_enable  <= 1'b0; 
                    cmpy_1_enable         <= 1'b0;
                    hn_continuance_enable <= 1'b0;
                    zero_fill_enable      <= 1'b0;
                    data_chirp2_switch    <= 2'b00;
                    xfft_dout_enable      <= 1'b0;
                    xifft_dout_enable     <= 1'b0;
                    sync_output_3_enable  <= 1'b0;
                    // 失能标志位
                    czt_finish_flag       <= 1'b0;
                end    
            endcase
        end
    end
    
endmodule


