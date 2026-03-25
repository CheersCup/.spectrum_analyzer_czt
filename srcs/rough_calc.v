`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/24 14:58:41
// Design Name: 
// Module Name: rough_calc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.10 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// 调用前进行初始化
module rough_calc(
    input clk_32M,
    input rst_n,
    
    // 启动信号，运行期间为高
    input enable, 
    
    // A/D接口
    input [7 : 0] ad_data,
    
    // 幅度谱
    output [18 : 0] fft_dout_abs,     // 幅度谱
    output [12 : 0] fft_dout_idx,     // 结果的索引
    output reg fft_dout_valid,       // 结果有效标志
    output reg [12 : 0] max_index    // 只搜索一半的频谱
    );
    
//-----------------------------------------参数声明：-----------------------------------------
    // 点数
    parameter FFT_LEN = 8192;
    parameter FFT_LEN_HALF = 4096;
    // pipelined streaming i/o 配置
    parameter PAD_0 = 1'b0;      // （15 : 15），bit1；边界对齐8bit整数倍
    parameter SCALE_SCH_0 = 14'b01_10_10_10_10_10_11;  // （14 ：1），bit14；2*ceil(0.5*log2(N)) = 14bit;
                                  // 在每层蝶形单元输出上加权，按比例减小输出;N点压缩N倍（01_10_10_10_10_10）；保守缩放
    parameter FWD_INV_0 = 1'b1;  // （0 : 0），bit1；进行fft正变换 

//-----------------------------------------信号声明：-----------------------------------------    
    // fft接口
    wire [15 : 0] fft_s_axis_config_tdata;
    wire fft_s_axis_config_tready;
    wire [31 : 0] fft_s_axis_data_tdata;
    wire fft_s_axis_data_tvalid;
    wire fft_s_axis_data_tready;
    reg  fft_s_axis_data_tlast;
    wire [31 : 0] fft_m_axis_data_tdata;
    wire [23 : 0] fft_m_axis_data_tuser;
    wire fft_m_axis_data_tvalid;
    reg  fft_m_axis_data_tvalid_d;
    wire fft_m_axis_data_tlast;
    wire fft_event_frame_started;
    wire fft_event_tlast_unexpected;
    wire fft_event_tlast_missing;
    wire fft_event_status_channel_halt;
    wire fft_event_data_in_channel_halt;
    wire fft_event_data_out_channel_halt;
    reg  [12 : 0] fft_din_cnt;   // 一帧fft输入数据计数器
    wire [8 : 0] fft_dout_re;    // 频谱的实部
    wire [8 : 0] fft_dout_im;    // 频谱的虚部
    wire [17 : 0] fft_dout_re_square;
    wire [17 : 0] fft_dout_im_square;
    
    // 用于计算窄带频谱区间的信号
    reg [18 : 0] max_data;
    
    // 内部信号
    reg [1 : 0] delay;
    
//------------------------------------ADC时钟缓冲模块：--------------------------------------
    // 将开始信号延迟一拍
    always@(posedge clk_32M or negedge rst_n)begin
		if(rst_n == 1'b0)
		    delay <= 2'd0;
		else
		    delay[1:0] <= {delay[0:0], enable};		    
    end
    
    assign fft_s_axis_data_tvalid = delay[1];
    
//----------------------------------------fft模块：----------------------------------------
    // pipelined streaming i/o 寄存器配置
    // 含CP前缀的配置
//    assign fft_s_axis_config_tdata = {PAD_0, SCALE_SCH_0, FWD_INV_0, PAD, CP_LEN}; 
    // 不含CP前缀的配置
    assign fft_s_axis_config_tdata = {PAD_0, SCALE_SCH_0, FWD_INV_0};
    
    // 输入数据的实部为采样信号，虚部补0，并且拓展到字节边界
    assign fft_s_axis_data_tdata = {16'b0, 7'b0, 1'b0, ad_data};
    
    // 用于产生fft模块每帧输入最后一个数据（第2048个数据）的控制信息fft_s_axis_data_tlast
    always@(posedge clk_32M or negedge rst_n)begin
        if(rst_n == 1'b0)
            fft_din_cnt <= 13'd0;
        else if((fft_din_cnt == FFT_LEN - 1) && (fft_s_axis_data_tvalid == 1'b1))
            fft_din_cnt <= 13'd0;        
        else if(fft_s_axis_data_tvalid == 1'b1)
            fft_din_cnt <= fft_din_cnt + 13'b1;
    end
    
    always@(posedge clk_32M or negedge rst_n)begin
        if(rst_n == 1'b0)
            fft_s_axis_data_tlast <= 1'b0;
        else if(fft_din_cnt == FFT_LEN - 1)
            fft_s_axis_data_tlast <= 1'b1;
        else
            fft_s_axis_data_tlast <= 1'b0;                    
    end
    
// 2048（N）点长度的fft模块，Pipelined Streaming I/O with no Cyclic Prefix Insertion
xfft_roughcalc xfft_roughcalc_inst (
  .aclk(clk_32M),                                                 // input wire aclk
  .aclken(1'b1),                                                  // input wire aclken
  .aresetn(rst_n),                                                // input wire aresetn
  
  .s_axis_config_tdata(fft_s_axis_config_tdata),                  // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(1'b1),                                    // input wire s_axis_config_tvalid
  .s_axis_config_tready(fft_s_axis_config_tready),                // output wire s_axis_config_tready
  
  .s_axis_data_tdata(fft_s_axis_data_tdata),                      // input wire [31 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(fft_s_axis_data_tvalid),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(fft_s_axis_data_tready),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(fft_s_axis_data_tlast),                      // input wire s_axis_data_tlast
  
  .m_axis_data_tdata(fft_m_axis_data_tdata),                      // output wire [31 : 0] m_axis_data_tdata
  .m_axis_data_tuser(fft_m_axis_data_tuser),                      // output wire [23 : 0] m_axis_data_tuser
  .m_axis_data_tvalid(fft_m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                                      // input wire m_axis_data_tready
  .m_axis_data_tlast(fft_m_axis_data_tlast),                      // output wire m_axis_data_tlast
  
  .event_frame_started(fft_event_frame_started),                  // output wire event_frame_started
  .event_tlast_unexpected(fft_event_tlast_unexpected),            // output wire event_tlast_unexpected
  .event_tlast_missing(fft_event_tlast_missing),                  // output wire event_tlast_missing
  .event_status_channel_halt(fft_event_status_channel_halt),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(fft_event_data_in_channel_halt),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(fft_event_data_out_channel_halt)  // output wire event_data_out_channel_halt
);
    
    // 得到fft结果的实部和虚部
    assign fft_dout_re = fft_m_axis_data_tdata[8 : 0];
    assign fft_dout_im = fft_m_axis_data_tdata[24: 16];
    
    // 计算实部和虚部的平方
    mult_gen_rough_fft mult_gen_re(
        .CLK    (clk_32M),              // input wire CLK
        .A      (fft_dout_re),          // input wire [8 : 0] A
        .B      (fft_dout_re),          // input wire [8 : 0] B
        .P      (fft_dout_re_square)    // output wire [17 : 0] P
    );
    
    mult_gen_rough_fft mult_gen_im(
        .CLK    (clk_32M),              // input wire CLK
        .A      (fft_dout_im),          // input wire [8 : 0] A
        .B      (fft_dout_im),          // input wire [8 : 0] B
        .P      (fft_dout_im_square)    // output wire [17 : 0] P
    );
    
//----------------------------------------计算幅度谱：----------------------------------------
    // 计算得到幅度谱的平方,
    assign fft_dout_abs = fft_dout_re_square + fft_dout_im_square;
    
    // 计算得到fft模块每帧输出数据的索引信息fft_dout_idx，乘法器输出结果滞后一个周期
    assign fft_dout_idx = fft_m_axis_data_tuser[12 : 0] - 1;
    
    // 对输出有效标志打一拍
    always@(posedge clk_32M or negedge rst_n)begin
        if(~rst_n)begin
            fft_m_axis_data_tvalid_d <= 1'b0;
        end else begin
            fft_m_axis_data_tvalid_d <= fft_m_axis_data_tvalid;
        end
    end

//------------------------------------分析窄带信号频谱范围：------------------------------------
    // 计算前半段频谱的最大点的频率
    always@(posedge clk_32M or negedge rst_n)begin
        if(~rst_n)begin
            max_data  <= 19'b0;
            max_index <= 13'b0;
            fft_dout_valid <= 1'b0;
        end else begin
            // 不分析直流分量，即fft_dout_idx != 13'd0
            if((fft_m_axis_data_tvalid_d == 1'b1) && (fft_dout_idx != 13'd0) && (fft_dout_idx <= FFT_LEN_HALF))begin
                fft_dout_valid <= 1'b0;
                if(fft_dout_abs > max_data)begin
                    max_data  <= fft_dout_abs;
                    max_index <= fft_dout_idx;
                end else begin
                    max_data  <= max_data;
                    max_index <= max_index;
                end
            end else begin
                max_data  <= 19'b0;
                max_index <= max_index;
                fft_dout_valid <= 1'b1;
            end
        end
    end
    
    
endmodule


