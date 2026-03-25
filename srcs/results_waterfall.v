`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/27 16:07:24
// Design Name: 
// Module Name: results_waterfall
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 选用RGB888 LCD(尺寸：4.3'；分辨率：800 * 480)
//      
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module results_waterfall(
    input clk,  
    input clk_calc,
    input rst_n,
    
    input [23 : 0] user_data_f0,            // 输入的f0
    input [23 : 0] user_data_fl,            // 输入的fl
    input [23 : 0] user_data_rough_freq,    // 输入的粗算结果
    input [23 : 0] user_data_accurate_freq, // 输入的精确结果
    input [92 : 0] tdata,                   // 输入的幅度谱数据
    input [10 : 0] tuser,                   // 输入幅度谱的索引
    input tvalid,                           // 输入数据有效
    input [6 : 0] msb,                      // 幅度谱最大值的为1的最高位

    // RGB LCD接口
    output lcd_de,          // LCD 数据使能信号
    output lcd_hs,          // LCD 行同步信号
    output lcd_vs,          // LCD 场同步信号
    output lcd_bl,          // LCD 背光控制信号
    output lcd_clk,         // LCD 像素时钟
    output lcd_rst,         // LCD 复位
    inout [23 : 0] lcd_rgb  // LCD RGB888颜色数据
    
    );
    
//-----------------------------------------信号声明：-----------------------------------------
    wire [15:0] lcd_id; // LCD屏ID
    wire lcd_pclk;      // LCD像素时钟
              
    wire [10:0] pixel_xpos;    // 当前像素点横坐标
    wire [10:0] pixel_ypos;    // 当前像素点纵坐标
    wire [10:0] h_disp;        // LCD屏水平分辨率
    wire [10:0] v_disp;        // LCD屏垂直分辨率
    wire [23:0] pixel_data;    // 像素数据
    wire [23:0] lcd_rgb_o;     // 输出的像素数据
    wire [23:0] lcd_rgb_i;     // 输入的像素数据
    
    // 像素数据方向切换
    assign lcd_rgb = lcd_de ?  lcd_rgb_o :  {24{1'bz}};
    assign lcd_rgb_i = lcd_rgb;

//--------------------------------------lcd id读取模块：---------------------------------------
lcd_id_rd lcd_id_rd_inst(
    .clk          (clk),
    .rst_n        (rst_n),
    .lcd_rgb      (lcd_rgb_i),  // 输入RGB LCD像素数据,用于读取ID
    .lcd_id       (lcd_id)      // 输出lcd屏的id信息
    );    
    
//---------------------------------------时钟分频模块：----------------------------------------
lcd_clk_div lcd_clk_div_inst(
    .clk           (clk),
    .rst_n         (rst_n),
    .lcd_id        (lcd_id),    // 输入lcd屏的id信息
    .lcd_pclk      (lcd_pclk)   // 输出lcd屏的驱动时钟
    );   
    
//---------------------------------------LCD显示模块 ：----------------------------------------
// 瀑布图显示入口
hl_lcd_disp hl_lcd_disp_inst(
    .lcd_pclk                   (lcd_pclk),         // 输入lcd屏的驱动时钟
    .clk_calc                   (clk_calc),         // 连接外部逻辑操作的时钟
    .rst_n                      (rst_n),
    .user_data_f0               (user_data_f0),
    .user_data_fl               (user_data_fl),
    .user_data_rough_freq       (user_data_rough_freq),
    .user_data_accurate_freq    (user_data_accurate_freq),
    .tdata                      (tdata),            // 输入的幅度谱数据
    .tuser                      (tuser),            // 输入幅度谱的索引
    .tvalid                     (tvalid),           // 输入数据有效
    .msb                        (msb),              // 幅度谱最大值的为1的最高位
    .pixel_xpos                 (pixel_xpos),       // 输入当前像素点横坐标
    .pixel_ypos                 (pixel_ypos),       // 输入当前像素点纵坐标
    .h_disp                     (h_disp),           // 输入lcd屏水平分辨率
    .v_disp                     (v_disp),           // 输入lcd屏垂直分辨率
    .pixel_data                 (pixel_data)        // 输出像素数据
    );    

//---------------------------------------LCD驱动模块 ：----------------------------------------
lcd_driver lcd_driver_inst(
    .lcd_pclk      (lcd_pclk),
    .rst_n         (rst_n),
    .lcd_id        (lcd_id),        // 输入lcd屏的id信息
    .pixel_data    (pixel_data),    // 输入像素数据
    .pixel_xpos    (pixel_xpos),    // 输出当前像素点横坐标
    .pixel_ypos    (pixel_ypos),    // 输出当前像素点纵坐标
    .h_disp        (h_disp),        // 输出lcd屏水平分辨率
    .v_disp        (v_disp),        // 输出lcd屏垂直分辨率

    .lcd_de        (lcd_de),        // 输出lcd数据使能信号
    .lcd_hs        (lcd_hs),        // 输出lcd行同步信号
    .lcd_vs        (lcd_vs),        // 输出lcd场同步信号
    .lcd_bl        (lcd_bl),        // 输出lcd背光控制信号
    .lcd_clk       (lcd_clk),       // 输出lcd像素时钟
    .lcd_rst       (lcd_rst),       // 输出lcd复位信号
    .lcd_rgb       (lcd_rgb_o)      // 输出lcd屏的RGB888颜色数据
    );
    
endmodule







