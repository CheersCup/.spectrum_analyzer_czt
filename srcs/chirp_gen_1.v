`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/21 10:19:59
// Design Name: 
// Module Name: chirp_gen
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

// 传入相位增量和相位偏移,输出2048点（N点）的chirp信号;引入泰勒级数纠正
module chirp_gen_1(
    input  clk,
    input  rst_n,
    
    input  enable,                     // 使能chirp信号生成模块，高电平有效
    input  [31 : 0] init_phase,        // init_phase = θ；数据类型为ufix32_32
    input  [31 : 0] step_phase,        // step_phase = φ；数据类型为ufix32_32
    
    output dout_valid,
    output [12 : 0] chirp_real,        // 生成的chirp信号实部，cos，fix13_11
    output [12 : 0] chirp_imag,        // 生成的chirp信号虚部，sin，fix13_11
    output [31 : 0] chirp_phase,       // 生成的chirp相位信号，弧度值，ufix32_32
    output [11 : 0] chirp_index        // 输出chirp信号的索引
    );
    
//-----------------------------------------参数定义：-----------------------------------------
    // dds1的输出点数，对应CZT框架中各部分的计算点数
    parameter CHIRP_LEN = 2048;
        
//-----------------------------------------信号声明：-----------------------------------------
    // 输入输出数据计数寄存器
    reg  [11:0] data_in_count;
    reg  [11:0] data_out_count;
    
    // 描述时序的中间量
    reg  dds_aresetn1;
    reg  dds_aresetn2;   
    reg  dds_aresetn3;
    
    // 相位偏置和相位增量
    reg  [31:0] dds_pinc_in;
    reg  [31:0] dds_poff_in;
    reg  [31:0] dds_pinc_in_d;
 
    // dds接口
    reg  dds_aclken;
    wire dds_aresetn;
    reg  s_axis_phase_tvalid;
    wire [63:0] s_axis_phase_tdata;
    wire m_axis_data_tvalid;
    wire [31:0] m_axis_data_tdata;
    wire m_axis_phase_tvalid;
    wire [31:0] m_axis_phase_tdata;
    
    // 内部信号
    reg  enable_d1;
    reg  enable_d2;
    wire enable_trig;
    
//-------------------------------采样enable信号产生单脉冲：-------------------------------------    
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
    assign enable_trig = (enable) && (enable_d1) && (~enable_d2);
       
//------------------------------------产生aclken信号：------------------------------------------
    // 产生chirp信号的触发标志，使用一个周期的脉冲信号
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            dds_aclken <= 1'b0;
        end else if(enable_trig) begin // 采样单脉冲以使能ip核
            dds_aclken <= 1'b1;
        end else if(data_out_count == CHIRP_LEN) begin // 输出2048点chirp信号后失能ip核
            dds_aclken <= 1'b0;
        end else begin
            dds_aclken <= dds_aclken;
        end
    end

//-----------------------------------产生aresetn信号：------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            dds_aresetn1 <= 1'b1;
        end else if(enable_trig) begin
            dds_aresetn1 <= 1'b0; // dds模块复位
        end else begin
            dds_aresetn1 <= 1'b1;
        end
    end
 
     always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            dds_aresetn2 <= 1'b1;
            dds_aresetn3 <= 1'b1;
        end else begin
            dds_aresetn2 <= dds_aresetn1;
            dds_aresetn3 <= dds_aresetn2;
        end
    end
    
    // dds ip core需要复位两个时钟周期
    assign dds_aresetn = dds_aresetn1 & dds_aresetn2; 
   
//-----------------------------------dds控制逻辑部分：------------------------------------------    
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            s_axis_phase_tvalid <= 1'b0;                
        end else if(~dds_aresetn3) begin // dds复位完成后开始产生chirp信号
            s_axis_phase_tvalid <= 1'b1;        
        end else if(data_in_count >= CHIRP_LEN + 1) begin
            s_axis_phase_tvalid <= 1'b0;        
        end else begin
            s_axis_phase_tvalid <= s_axis_phase_tvalid;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_in_count <= 12'h0;                        
        end else if(s_axis_phase_tvalid) begin
            data_in_count <= data_in_count + 12'h1;                
        end else begin
            data_in_count <= 12'h0;                
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            dds_pinc_in_d <= 32'h0;    
        end else begin
            dds_pinc_in_d <= dds_pinc_in;                    
        end
    end    
    
 	// bw:带宽（MHz） pw:脉宽（us） fs:采样率（MHz）；32bit的相位增量，点数为2000点+采样率为25MHz=脉宽为80us；带宽为FFT粗算得到
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            dds_pinc_in <= 32'h0;
            dds_poff_in <= 32'h0;   
        end else if(~dds_aresetn3) begin // dds ip core复位后，初始化相位增量和相位偏移信号
            dds_pinc_in <= init_phase + (step_phase >> 1);
            dds_poff_in <= 32'h0;
        end else if(s_axis_phase_tvalid) begin
            dds_pinc_in <= dds_pinc_in + step_phase;// dds_pinc_in + step_phase
            dds_poff_in <= 32'h0;
        end else begin
            dds_pinc_in <= dds_pinc_in;
            dds_poff_in <= dds_poff_in;             
        end
    end
    
//----------------------------------------dds模块：---------------------------------------------- 
    assign s_axis_phase_tdata = {dds_poff_in, dds_pinc_in_d};  
       
    dds_compiler dds_compiler_1(
        .aclk                   (clk),                  // input wire aclk
        .aclken                 (dds_aclken),           // input wire aclken
        .aresetn                (dds_aresetn),          // input wire aresetn
        .s_axis_phase_tvalid    (s_axis_phase_tvalid),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata     (s_axis_phase_tdata),   // input wire [63 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid     (m_axis_data_tvalid),   // output wire m_axis_data_tvalid
        .m_axis_data_tdata      (m_axis_data_tdata),    // output wire [31 : 0] m_axis_data_tdata，
        .m_axis_phase_tvalid    (m_axis_phase_tvalid),  // output wire m_axis_phase_tvalid
        .m_axis_phase_tdata     (m_axis_phase_tdata)    // output wire [31 : 0] m_axis_phase_tdata
    );

//-------------------------------------chirp信号输出：--------------------------------------------
    // 对输出点计数
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_out_count <= 12'h0;    
        end else if(m_axis_data_tvalid) begin        
            if(data_out_count >= CHIRP_LEN) begin
                data_out_count <= 12'h0;
            end else begin
                data_out_count <= data_out_count + 12'h1;
           end
        end else begin
            data_out_count <= 12'h0;            
        end
    end
    
    // 输出chirp信号的索引
    assign chirp_index = data_out_count;

    // 输出chirp信号的实部和虚部，待修正
    assign chirp_real = m_axis_data_tdata[12 : 0];  
    assign chirp_imag = ~m_axis_data_tdata[28 : 16] + 1'b1;
    
    // 输出chirp信号的相位
    assign chirp_phase = m_axis_phase_tdata;
    
    // 输出数据有效
    assign dout_valid = m_axis_data_tvalid;
    
    
endmodule





