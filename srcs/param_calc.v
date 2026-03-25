`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/04 16:18:47
// Design Name: 
// Module Name: param_calc
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


// init_phase = θ；step_phase = φ；数据类型为ufix32_32
module param_calc(
    input clk,
    input rst_n,
    
    input enable,        // 使能除法运算,此时数据线有效；高电平有效
    input [23 : 0] f0,   // 频谱分析的起点
    input [23 : 0] fl,   // 频谱分析的长度
    
    output [31 : 0] theta,  // theta
    output [31 : 0] phi,    // phi
    output reg [10 : 0] origin_index, 
    output dout_valid       // 输出角度有效,数据线维持3个时钟周期
    );
    
//-----------------------------------------信号声明：-----------------------------------------
    // 除法器接口
    reg  aclken;
    wire s_axis_divisor_tvalid_theta;
    wire s_axis_divisor_tvalid_phi;
    wire s_axis_dividend_tvalid_theta;
    wire s_axis_dividend_tvalid_phi;
    wire m_axis_dout_tvalid_theta;
    wire m_axis_dout_tvalid_phi;
    wire [55 : 0] m_axis_dout_tdata_theta;
    wire [55 : 0] m_axis_dout_tdata_phi;
    wire [31 : 0] s_axis_divisor_tdata;

    // 内部信号
    reg enable_d1;
    reg enable_d2;
    wire enable_trig;
    reg [1 : 0] valid_count;
    reg [23 : 0] f0_reg;
    reg [23 : 0] fl_reg;

//-----------------------------------------时序控制：-----------------------------------------    
    // 采样enable信号产生单脉冲
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            enable_d1 <= 1'b0;
            enable_d2 <= 1'b0;
        end else begin
            enable_d1  <= enable  ;
            enable_d2  <= enable_d1 ;
        end
    end
    
    // 生成使能信号的单脉冲
    assign enable_trig = (enable_d1) && (~enable_d2);
       
    // 产生aclken信号
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            aclken <= 1'b0;
        end else if(enable_trig) begin // 采样单脉冲以使能ip核
            aclken <= 1'b1;
        end else if(valid_count == 2'b11) begin // 输出有效两个时钟周期后失能ip核
            aclken <= 1'b0;
        end else begin
            aclken <= aclken;
        end
    end
    
    // 锁存输入数据
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            f0_reg <= 24'b0;
            fl_reg <= 24'b0;
        end else if (enable_trig == 1'b1) begin
            f0_reg  <= f0 ;
            fl_reg  <= fl ;
        end else begin
            f0_reg  <= f0_reg ;
            fl_reg  <= fl_reg ;
        end
    end

    // 输出数据有效,持续3个时钟
    assign dout_valid = m_axis_dout_tvalid_theta && m_axis_dout_tvalid_phi;
    
    // 输出有效时钟计数
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            valid_count <= 2'b0;    
        end else if((dout_valid == 1'b1) && (enable == 1'b0)) begin // 使能信号失能后，延迟两个时钟失能模块   
            valid_count <= valid_count + 2'b1;
        end else begin
            valid_count <= 2'b0;            
        end
    end
    
//----------------------------------------除法器模块：-----------------------------------------
    // 被除数：fs/Hz，对齐到字节边界
    assign s_axis_divisor_tdata = {7'd0, 25'd32_000_000};
    
    // 除数输入常有效，使用aclk信号控制ip核
    assign s_axis_dividend_tvalid_theta = 1'b1;
    assign s_axis_dividend_tvalid_phi   = 1'b1;
    
    // 被除数输入常有效，使用aclk信号控制ip核
    assign s_axis_divisor_tvalid_theta = 1'b1;
    assign s_axis_divisor_tvalid_phi   = 1'b1;

// 输出theta，延迟两个时钟后输出
div_gen_angle div_gen_theta(
  .aclk(clk),                                             // input wire aclk
  .aclken(aclken),                                        // input wire aclken
  .s_axis_divisor_tvalid(s_axis_divisor_tvalid_theta),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(s_axis_divisor_tdata),            // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_dividend_tvalid_theta),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(f0_reg),                         // input wire [23 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_theta),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_theta)            // output wire [55 : 0] m_axis_dout_tdata
);

// 输出phi
div_gen_angle div_gen_phi(
  .aclk(clk),                                           // input wire aclk
  .aclken(aclken),                                      // input wire aclken
  .s_axis_divisor_tvalid(s_axis_divisor_tvalid_theta),  // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(s_axis_divisor_tdata),          // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_dividend_tvalid_phi),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(fl_reg),                       // input wire [23 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_phi),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_phi)            // output wire [55 : 0] m_axis_dout_tdata
);
    
//----------------------------------------角度输出：-----------------------------------------
    // 输出到端口
    assign theta = m_axis_dout_tdata_theta[31 : 0];
    assign phi = (m_axis_dout_tdata_phi[31 : 0] >> 11);
    
    
//-----------------------------------判断基频对应的序号：------------------------------------
//    always @(posedge clk or negedge rst_n) begin
//        if(~rst_n) begin
//            origin_index <= 11'b0;
//        end else if(f0 >= 24'd15_625)begin
//            origin_index <= 11'b0;
//        end else begin
//            origin_index <= (24'd15_625 - f0) << 11 / fl;
//        end
//    end
    
    
endmodule






