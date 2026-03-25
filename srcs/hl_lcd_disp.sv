`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/27 15:28:00
// Design Name: 
// Module Name: lcd_disp
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

// 800*480
module hl_lcd_disp(
    input lcd_pclk,
    input clk_calc,
    input rst_n,
    
    // 用户接口
    input [23 : 0] user_data_f0,            // 输入的f0
    input [23 : 0] user_data_fl,            // 输入的fl
    input [23 : 0] user_data_rough_freq,    // 输入的粗算结果
    input [23 : 0] user_data_accurate_freq, // 输入的精确结果
    input [92 : 0] tdata,                   // 输入的幅度谱数据
    input [10 : 0] tuser,                   // 输入幅度谱的索引
    input tvalid,                           // 输入数据有效
    input [6 : 0] msb,                      // 幅度谱最大值的为1的最高位
    
    // 驱动接口
    input [10:0] pixel_xpos,        // 当前像素点横坐标
    input [10:0] pixel_ypos,        // 当前像素点纵坐标  
    input [10:0] h_disp,            // 水平分辨率
    input [10:0] v_disp,            // 垂直分辨率       
    output reg [23:0] pixel_data   // 像素数据
    );
    
    // parameter define  
    parameter WHITE  = 24'hFFFFFF;  // 白色
    parameter BLACK  = 24'h000000;  // 黑色
    parameter RED    = 24'hFF0000;  // 红色
    parameter GREEN  = 24'h00FF00;  // 绿色
    parameter BLUE   = 24'h0000FF;  // 蓝色
    parameter CYAN   = 24'h00FFFF;  // 青色，显示固定的内容
    parameter PURPLE = 24'hFF00FF;  // 紫色
    parameter YELLOW = 24'hFFFF00;  // 黄色
        
    // signal define
    // 字库部分：数字0-9（大小为8*16）
    reg  [7 : 0] rom_font_0 [15 : 0];
    reg  [7 : 0] rom_font_1 [15 : 0];
    reg  [7 : 0] rom_font_2 [15 : 0];
    reg  [7 : 0] rom_font_3 [15 : 0];
    reg  [7 : 0] rom_font_4 [15 : 0];
    reg  [7 : 0] rom_font_5 [15 : 0];
    reg  [7 : 0] rom_font_6 [15 : 0];
    reg  [7 : 0] rom_font_7 [15 : 0];
    reg  [7 : 0] rom_font_8 [15 : 0];
    reg  [7 : 0] rom_font_9 [15 : 0];
    // 显示逻辑部分
    reg  [151 : 0] vram_init_data [127 : 0];        // 初始化内容，已取字模
    // 输入数据部分
    reg  [7 : 0] vram_input_data_1 [4 : 0] [15 : 0];     // f0，五个数据位宽，维度从高到低分别对应数量级、字模高、字模宽
    reg  [7 : 0] vram_input_data_2 [4 : 0] [15 : 0];     // fl，五个数据位宽
    reg  [7 : 0] vram_input_data_3 [4 : 0] [15 : 0];     // rough_calc，五个数据位宽
    reg  [7 : 0] vram_input_data_4 [4 : 0] [15 : 0];     // accurate_calc，五个数据位宽
    wire [10 : 0] x_text_cnt;       // 文字横坐标计数器
    wire [10 : 0] y_text_cnt;       // 文字纵坐标计数器
    wire [10 : 0] x4_data_cnt;      // 数据横坐标计数器
    wire [10 : 0] x3_data_cnt;      // 数据横坐标计数器
    wire [10 : 0] x2_data_cnt;      // 数据横坐标计数器
    wire [10 : 0] x1_data_cnt;      // 数据横坐标计数器
    wire [10 : 0] x0_data_cnt;      // 数据横坐标计数器
    wire [10 : 0] y0_data_cnt;      // 数据纵坐标计数器
    wire [10 : 0] y1_data_cnt;      // 数据纵坐标计数器
    wire [10 : 0] y2_data_cnt;      // 数据纵坐标计数器
    wire [10 : 0] y3_data_cnt;      // 数据纵坐标计数器
    wire [10 : 0] x_fig_cnt;        // 图像横坐标计数器
    // 结果图像部分
    reg  [7 : 0] vram_czt_result [682 : 0]; // 将2048个点按照每3个点合并显示，共需要683个存储单元
    // 处理后的数据
    wire [5 : 0] tdata_truncation;    
    reg  tvalid_truncation;
    reg  enter_flag;
    
    // 加载文字vram_init_data及字库rom_font_i
    always @(posedge clk_calc) begin
        // 加载文字
        vram_init_data[0] <=152'h000000000000000000_00_000000000000000000;        vram_init_data[1] <=152'h00000000000000000000020000004000000000;
        vram_init_data[2] <=152'h000000000000000000_00_040000002000000000;        vram_init_data[3] <=152'h000030000000000000180800E7001000000000;
        vram_init_data[4] <=152'h00003000000000000C_24_08C042001000000000;        vram_init_data[5] <=152'h00000000000010001242104042000800000000;
        vram_init_data[6] <=152'h000000000000100010_42_104042000818000000;        vram_init_data[7] <=152'h000070DCD8C67C007C42104E427E0818000000;
        vram_init_data[8] <=152'h000010626442100010_42_10487E440800000000;        vram_init_data[9] <=152'h00001042424210001042105042080800000000;
        vram_init_data[10]<=152'h000010424242100010_42_107042100800000000;        vram_init_data[11]<=152'h00001042424210001042084842101000000000;
        vram_init_data[12]<=152'h000010426446120010_24_084442221018000000;        vram_init_data[13]<=152'h00007CE7583B0C007C1804EEE77E2018000000;
        vram_init_data[14]<=152'h000000004000000000_00_020000004000000000;        vram_init_data[15]<=152'h00000000E00000000000000000000000000000;
        vram_init_data[16]<=152'h00000000000000000000000000000000000000;        vram_init_data[17]<=152'h00000000000000000000000000000000000000;
        vram_init_data[18]<=152'h00000000000000000000000000000000000000;        vram_init_data[19]<=152'h00000000000000000000000000000000000000;
        vram_init_data[20]<=152'h00000000000000000000000000000000000000;        vram_init_data[21]<=152'h00000000000000000000000000000000000000;
        vram_init_data[22]<=152'h00000000000000000000000000000000000000;        vram_init_data[23]<=152'h00000000000000000000000000000000000000;
        vram_init_data[24]<=152'h00000000000000000000000000000000000000;        vram_init_data[25]<=152'h00000000000000000000000000000000000000;
        vram_init_data[26]<=152'h00000000000000000000000000000000000000;        vram_init_data[27]<=152'h00000000000000000000000000000000000000;
        vram_init_data[28]<=152'h00000000000000000000000000000000000000;        vram_init_data[29]<=152'h00000000000000000000000000000000000000;
        vram_init_data[30]<=152'h00000000000000000000000000000000000000;        vram_init_data[31]<=152'h00000000000000000000000000000000000000;
        vram_init_data[32]<=152'h00000000000000000000000000000000000000;        vram_init_data[33]<=152'h00000000000000000000020000004000000000;
        vram_init_data[34]<=152'h00000000000000000000040000002000000000;        vram_init_data[35]<=152'h000030000000000000100800E7001000000000;
        vram_init_data[36]<=152'h00003000000000000C7008C042001000000000;        vram_init_data[37]<=152'h00000000000010001210104042000800000000;
        vram_init_data[38]<=152'h00000000000010001010104042000818000000;        vram_init_data[39]<=152'h000070DCD8C67C007C10104E427E0818000000;
        vram_init_data[40]<=152'h0000106264421000101010487E440800000000;        vram_init_data[41]<=152'h00001042424210001010105042080800000000;
        vram_init_data[42]<=152'h00001042424210001010107042100800000000;        vram_init_data[43]<=152'h00001042424210001010084842101000000000;
        vram_init_data[44]<=152'h00001042644612001010084442221018000000;        vram_init_data[45]<=152'h00007CE7583B0C007C7C04EEE77E2018000000;
        vram_init_data[46]<=152'h00000000400000000000020000004000000000;        vram_init_data[47]<=152'h00000000E00000000000000000000000000000;
        vram_init_data[48]<=152'h00000000000000000000000000000000000000;        vram_init_data[49]<=152'h00000000000000000000000000000000000000;
        vram_init_data[50]<=152'h00000000000000000000000000000000000000;        vram_init_data[51]<=152'h00000000000000000000000000000000000000;
        vram_init_data[52]<=152'h00000000000000000000000000000000000000;        vram_init_data[53]<=152'h00000000000000000000000000000000000000;
        vram_init_data[54]<=152'h00000000000000000000000000000000000000;        vram_init_data[55]<=152'h00000000000000000000000000000000000000;
        vram_init_data[56]<=152'h00000000000000000000000000000000000000;        vram_init_data[57]<=152'h00000000000000000000000000000000000000;
        vram_init_data[58]<=152'h00000000000000000000000000000000000000;        vram_init_data[59]<=152'h00000000000000000000000000000000000000;
        vram_init_data[60]<=152'h00000000000000000000000000000000000000;        vram_init_data[61]<=152'h00000000000000000000000000000000000000;
        vram_init_data[62]<=152'h00000000000000000000000000000000000000;        vram_init_data[63]<=152'h00000000000000000000000000000000000000;
        vram_init_data[64]<=152'h00000000000000000000000000000000000000;        vram_init_data[65]<=152'h00000000000000000000000200000040000000;
        vram_init_data[66]<=152'h00000000000000000000000400000020000000;        vram_init_data[67]<=152'h00000000000000000010000800E70010000000;
        vram_init_data[68]<=152'h0000000000C0000000700008C0420010000000;        vram_init_data[69]<=152'h00000000004000000010001040420008000000;
        vram_init_data[70]<=152'h00000000004000000010001040420008180000;        vram_init_data[71]<=152'h00EE3CC63E5C001C38101C104E427E08180000;
        vram_init_data[72]<=152'h003242424462002244102210487E4408000000;        vram_init_data[73]<=152'h00204242444200400C10401050420808000000;
        vram_init_data[74]<=152'h00204242384200403410401070421008000000;        vram_init_data[75]<=152'h00204242404200404410400848421010000000;
        vram_init_data[76]<=152'h002042463C4200224C10220844422210180000;        vram_init_data[77]<=152'h00F83C3B42E7001C367C1C04EEE77E20180000;
        vram_init_data[78]<=152'h00000000420000000000000200000040000000;        vram_init_data[79]<=152'h000000003C00FF000000000000000000000000;
        vram_init_data[80]<=152'h00000000000000000000000000000000000000;        vram_init_data[81]<=152'h00000000000000000000000000000000000000;
        vram_init_data[82]<=152'h00000000000000000000000000000000000000;        vram_init_data[83]<=152'h00000000000000000000000000000000000000;
        vram_init_data[84]<=152'h00000000000000000000000000000000000000;        vram_init_data[85]<=152'h00000000000000000000000000000000000000;
        vram_init_data[86]<=152'h00000000000000000000000000000000000000;        vram_init_data[87]<=152'h00000000000000000000000000000000000000;
        vram_init_data[88]<=152'h00000000000000000000000000000000000000;        vram_init_data[89]<=152'h00000000000000000000000000000000000000;
        vram_init_data[90]<=152'h00000000000000000000000000000000000000;        vram_init_data[91]<=152'h00000000000000000000000000000000000000;
        vram_init_data[92]<=152'h00000000000000000000000000000000000000;        vram_init_data[93]<=152'h00000000000000000000000000000000000000;
        vram_init_data[94]<=152'h00000000000000000000000000000000000000;        vram_init_data[95]<=152'h00000000000000000000000000000000000000;
        vram_init_data[96]<=152'h00000000000000000000000000000000000000;        vram_init_data[97]<=152'h00000000000000000000000000020000004000;
        vram_init_data[98]<=152'h00000000000000000000000000040000002000;        vram_init_data[99]<=152'h000000000000000000000010000800E7001000;
        vram_init_data[100]<=152'h0000000000000000000000700008C042001000;        vram_init_data[101]<=152'h00000000000010000000001000104042000800;
        vram_init_data[102]<=152'h00000000000010000000001000104042000818;        vram_init_data[103]<=152'h381C1CC6EE387C3C001C38101C104E427E0818;
        vram_init_data[104]<=152'h4422224232441042002244102210487E440800;        vram_init_data[105]<=152'h0C404042200C104200400C1040105042080800;
        vram_init_data[106]<=152'h344040422034107E0040341040107042100800;        vram_init_data[107]<=152'h44404042204410400040441040084842101000;
        vram_init_data[108]<=152'h4C222246204C124200224C1022084442221018;        vram_init_data[109]<=152'h361C1C3BF8360C3C001C367C1C04EEE77E2018;
        vram_init_data[110]<=152'h00000000000000000000000000020000004000;        vram_init_data[111]<=152'h0000000000000000FF00000000000000000000;
        vram_init_data[112]<=152'h00000000000000000000000000000000000000;        vram_init_data[113]<=152'h00000000000000000000000000000000000000;
        vram_init_data[114]<=152'h00000000000000000000000000000000000000;        vram_init_data[115]<=152'h00000000000000000000000000000000000000;
        vram_init_data[116]<=152'h00000000000000000000000000000000000000;        vram_init_data[117]<=152'h00000000000000000000000000000000000000;
        vram_init_data[118]<=152'h00000000000000000000000000000000000000;        vram_init_data[119]<=152'h00000000000000000000000000000000000000;
        vram_init_data[120]<=152'h00000000000000000000000000000000000000;        vram_init_data[121]<=152'h00000000000000000000000000000000000000;
        vram_init_data[122]<=152'h00000000000000000000000000000000000000;        vram_init_data[123]<=152'h00000000000000000000000000000000000000;
        vram_init_data[124]<=152'h00000000000000000000000000000000000000;        vram_init_data[125]<=152'h00000000000000000000000000000000000000;
        vram_init_data[126]<=152'h00000000000000000000000000000000000000;        vram_init_data[127]<=152'h00000000000000000000000000000000000000;
        // 加载字库，8*16（width*height）
        // 0
        rom_font_0[0] <= 8'h00; rom_font_0[1] <= 8'h00; rom_font_0[2] <= 8'h00; rom_font_0[3] <= 8'h18; rom_font_0[4] <= 8'h24; rom_font_0[5] <= 8'h42; rom_font_0[6] <= 8'h42; rom_font_0[7] <= 8'h42;
        rom_font_0[8] <= 8'h42; rom_font_0[9] <= 8'h42; rom_font_0[10] <= 8'h42; rom_font_0[11] <= 8'h42; rom_font_0[12] <= 8'h24; rom_font_0[13] <= 8'h18; rom_font_0[14] <= 8'h00; rom_font_0[15] <= 8'h00;
        // 1
        rom_font_1[0] <= 8'h00; rom_font_1[1] <= 8'h00; rom_font_1[2] <= 8'h00; rom_font_1[3] <= 8'h08; rom_font_1[4] <= 8'h38; rom_font_1[5] <= 8'h08; rom_font_1[6] <= 8'h08; rom_font_1[7] <= 8'h08;
        rom_font_1[8] <= 8'h08; rom_font_1[9] <= 8'h08; rom_font_1[10] <= 8'h08; rom_font_1[11] <= 8'h08; rom_font_1[12] <= 8'h08; rom_font_1[13] <= 8'h3E; rom_font_1[14] <= 8'h00; rom_font_1[15] <= 8'h00;
        // 2
        rom_font_2[0] <= 8'h00; rom_font_2[1] <= 8'h00; rom_font_2[2] <= 8'h00; rom_font_2[3] <= 8'h3C; rom_font_2[4] <= 8'h42; rom_font_2[5] <= 8'h42; rom_font_2[6] <= 8'h42; rom_font_2[7] <= 8'h02;
        rom_font_2[8] <= 8'h04; rom_font_2[9] <= 8'h08; rom_font_2[10] <= 8'h10; rom_font_2[11] <= 8'h20; rom_font_2[12] <= 8'h42; rom_font_2[13] <= 8'h7E; rom_font_2[14] <= 8'h00; rom_font_2[15] <= 8'h00;
        // 3
        rom_font_3[0] <= 8'h00; rom_font_3[1] <= 8'h00; rom_font_3[2] <= 8'h00; rom_font_3[3] <= 8'h3C; rom_font_3[4] <= 8'h42; rom_font_3[5] <= 8'h42; rom_font_3[6] <= 8'h02; rom_font_3[7] <= 8'h04;
        rom_font_3[8] <= 8'h18; rom_font_3[9] <= 8'h04; rom_font_3[10] <= 8'h02; rom_font_3[11] <= 8'h42; rom_font_3[12] <= 8'h42; rom_font_3[13] <= 8'h3C; rom_font_3[14] <= 8'h00; rom_font_3[15] <= 8'h00;
        // 4
        rom_font_4[0] <= 8'h00; rom_font_4[1] <= 8'h00; rom_font_4[2] <= 8'h00; rom_font_4[3] <= 8'h04; rom_font_4[4] <= 8'h0C; rom_font_4[5] <= 8'h0C; rom_font_4[6] <= 8'h14; rom_font_4[7] <= 8'h24;
        rom_font_4[8] <= 8'h24; rom_font_4[9] <= 8'h44; rom_font_4[10] <= 8'h7F; rom_font_4[11] <= 8'h04; rom_font_4[12] <= 8'h04; rom_font_4[13] <= 8'h1F; rom_font_4[14] <= 8'h00; rom_font_4[15] <= 8'h00;
        // 5
        rom_font_5[0] <= 8'h00; rom_font_5[1] <= 8'h00; rom_font_5[2] <= 8'h00; rom_font_5[3] <= 8'h7E; rom_font_5[4] <= 8'h40; rom_font_5[5] <= 8'h40; rom_font_5[6] <= 8'h40; rom_font_5[7] <= 8'h78;
        rom_font_5[8] <= 8'h44; rom_font_5[9] <= 8'h02; rom_font_5[10] <= 8'h02; rom_font_5[11] <= 8'h42; rom_font_5[12] <= 8'h44; rom_font_5[13] <= 8'h38; rom_font_5[14] <= 8'h00; rom_font_5[15] <= 8'h00;
        // 6
        rom_font_6[0] <= 8'h00; rom_font_6[1] <= 8'h00; rom_font_6[2] <= 8'h00; rom_font_6[3] <= 8'h18; rom_font_6[4] <= 8'h24; rom_font_6[5] <= 8'h40; rom_font_6[6] <= 8'h40; rom_font_6[7] <= 8'h5C;
        rom_font_6[8] <= 8'h62; rom_font_6[9] <= 8'h42; rom_font_6[10] <= 8'h42; rom_font_6[11] <= 8'h42; rom_font_6[12] <= 8'h22; rom_font_6[13] <= 8'h1C; rom_font_6[14] <= 8'h00; rom_font_6[15] <= 8'h00;
        // 7
        rom_font_7[0] <= 8'h00; rom_font_7[1] <= 8'h00; rom_font_7[2] <= 8'h00; rom_font_7[3] <= 8'h7E; rom_font_7[4] <= 8'h42; rom_font_7[5] <= 8'h04; rom_font_7[6] <= 8'h04; rom_font_7[7] <= 8'h08;
        rom_font_7[8] <= 8'h08; rom_font_7[9] <= 8'h10; rom_font_7[10] <= 8'h10; rom_font_7[11] <= 8'h10; rom_font_7[12] <= 8'h10; rom_font_7[13] <= 8'h10; rom_font_7[14] <= 8'h00; rom_font_7[15] <= 8'h00;
        // 8
        rom_font_8[0] <= 8'h00; rom_font_8[1] <= 8'h00; rom_font_8[2] <= 8'h00; rom_font_8[3] <= 8'h3C; rom_font_8[4] <= 8'h42; rom_font_8[5] <= 8'h42; rom_font_8[6] <= 8'h42; rom_font_8[7] <= 8'h24;
        rom_font_8[8] <= 8'h18; rom_font_8[9] <= 8'h24; rom_font_8[10] <= 8'h42; rom_font_8[11] <= 8'h42; rom_font_8[12] <= 8'h42; rom_font_8[13] <= 8'h3C; rom_font_8[14] <= 8'h00; rom_font_8[15] <= 8'h00;
        // 9
        rom_font_9[0] <= 8'h00; rom_font_9[1] <= 8'h00; rom_font_9[2] <= 8'h00; rom_font_9[3] <= 8'h38; rom_font_9[4] <= 8'h44; rom_font_9[5] <= 8'h42; rom_font_9[6] <= 8'h42; rom_font_9[7] <= 8'h42;
        rom_font_9[8] <= 8'h46; rom_font_9[9] <= 8'h3A; rom_font_9[10] <= 8'h02; rom_font_9[11] <= 8'h02; rom_font_9[12] <= 8'h24; rom_font_9[13] <= 8'h18; rom_font_9[14] <= 8'h00; rom_font_9[15] <= 8'h00;
    end
    
    // 加载输入数据vram_input_data，
    always @(posedge clk_calc or negedge rst_n) begin
        if(~rst_n)begin // 复位
            // f0
            vram_input_data_1[0][0]<= 8'h0; vram_input_data_1[0][1]<= 8'h0; vram_input_data_1[0][2]<= 8'h0; vram_input_data_1[0][3]<= 8'h0;
            vram_input_data_1[0][4]<= 8'h0; vram_input_data_1[0][5]<= 8'h0; vram_input_data_1[0][6]<= 8'h0; vram_input_data_1[0][7]<= 8'h0;
            vram_input_data_1[0][8]<= 8'h0; vram_input_data_1[0][9]<= 8'h0; vram_input_data_1[0][10]<= 8'h0;vram_input_data_1[0][11]<= 8'h0;
            vram_input_data_1[0][12]<= 8'h0;vram_input_data_1[0][13]<= 8'h0;vram_input_data_1[0][14]<= 8'h0;vram_input_data_1[0][15]<= 8'h0;
            vram_input_data_1[1][0]<= 8'h0; vram_input_data_1[1][1]<= 8'h0; vram_input_data_1[1][2]<= 8'h0; vram_input_data_1[1][3]<= 8'h0;
            vram_input_data_1[1][4]<= 8'h0; vram_input_data_1[1][5]<= 8'h0; vram_input_data_1[1][6]<= 8'h0; vram_input_data_1[1][7]<= 8'h0;
            vram_input_data_1[1][8]<= 8'h0; vram_input_data_1[1][9]<= 8'h0; vram_input_data_1[1][10]<= 8'h0;vram_input_data_1[1][11]<= 8'h0;
            vram_input_data_1[1][12]<= 8'h0;vram_input_data_1[1][13]<= 8'h0;vram_input_data_1[1][14]<= 8'h0;vram_input_data_1[1][15]<= 8'h0;
            vram_input_data_1[2][0]<= 8'h0; vram_input_data_1[2][1]<= 8'h0; vram_input_data_1[2][2]<= 8'h0; vram_input_data_1[2][3]<= 8'h0;
            vram_input_data_1[2][4]<= 8'h0; vram_input_data_1[2][5]<= 8'h0; vram_input_data_1[2][6]<= 8'h0; vram_input_data_1[2][7]<= 8'h0;
            vram_input_data_1[2][8]<= 8'h0; vram_input_data_1[2][9]<= 8'h0; vram_input_data_1[2][10]<= 8'h0;vram_input_data_1[2][11]<= 8'h0;
            vram_input_data_1[2][12]<= 8'h0;vram_input_data_1[2][13]<= 8'h0;vram_input_data_1[2][14]<= 8'h0;vram_input_data_1[2][15]<= 8'h0;
            vram_input_data_1[3][0]<= 8'h0; vram_input_data_1[3][1]<= 8'h0; vram_input_data_1[3][2]<= 8'h0; vram_input_data_1[3][3]<= 8'h0;
            vram_input_data_1[3][4]<= 8'h0; vram_input_data_1[3][5]<= 8'h0; vram_input_data_1[3][6]<= 8'h0; vram_input_data_1[3][7]<= 8'h0;
            vram_input_data_1[3][8]<= 8'h0; vram_input_data_1[3][9]<= 8'h0; vram_input_data_1[3][10]<= 8'h0;vram_input_data_1[3][11]<= 8'h0;
            vram_input_data_1[3][12]<= 8'h0;vram_input_data_1[3][13]<= 8'h0;vram_input_data_1[3][14]<= 8'h0;vram_input_data_1[3][15]<= 8'h0;
            vram_input_data_1[4][0]<= 8'h0; vram_input_data_1[4][1]<= 8'h0; vram_input_data_1[4][2]<= 8'h0; vram_input_data_1[4][3]<= 8'h0;
            vram_input_data_1[4][4]<= 8'h0; vram_input_data_1[4][5]<= 8'h0; vram_input_data_1[4][6]<= 8'h0; vram_input_data_1[4][7]<= 8'h0;
            vram_input_data_1[4][8]<= 8'h0; vram_input_data_1[4][9]<= 8'h0; vram_input_data_1[4][10]<= 8'h0;vram_input_data_1[4][11]<= 8'h0;
            vram_input_data_1[4][12]<= 8'h0;vram_input_data_1[4][13]<= 8'h0;vram_input_data_1[4][14]<= 8'h0;vram_input_data_1[4][15]<= 8'h0;
            // fl
            vram_input_data_2[0][0]<= 8'h0; vram_input_data_2[0][1]<= 8'h0; vram_input_data_2[0][2]<= 8'h0; vram_input_data_2[0][3]<= 8'h0;
            vram_input_data_2[0][4]<= 8'h0; vram_input_data_2[0][5]<= 8'h0; vram_input_data_2[0][6]<= 8'h0; vram_input_data_2[0][7]<= 8'h0;
            vram_input_data_2[0][8]<= 8'h0; vram_input_data_2[0][9]<= 8'h0; vram_input_data_2[0][10]<= 8'h0;vram_input_data_2[0][11]<= 8'h0;
            vram_input_data_2[0][12]<= 8'h0;vram_input_data_2[0][13]<= 8'h0;vram_input_data_2[0][14]<= 8'h0;vram_input_data_2[0][15]<= 8'h0;
            vram_input_data_2[1][0]<= 8'h0; vram_input_data_2[1][1]<= 8'h0; vram_input_data_2[1][2]<= 8'h0; vram_input_data_2[1][3]<= 8'h0;
            vram_input_data_2[1][4]<= 8'h0; vram_input_data_2[1][5]<= 8'h0; vram_input_data_2[1][6]<= 8'h0; vram_input_data_2[1][7]<= 8'h0;
            vram_input_data_2[1][8]<= 8'h0; vram_input_data_2[1][9]<= 8'h0; vram_input_data_2[1][10]<= 8'h0;vram_input_data_2[1][11]<= 8'h0;
            vram_input_data_2[1][12]<= 8'h0;vram_input_data_2[1][13]<= 8'h0;vram_input_data_2[1][14]<= 8'h0;vram_input_data_2[1][15]<= 8'h0;
            vram_input_data_2[2][0]<= 8'h0; vram_input_data_2[2][1]<= 8'h0; vram_input_data_2[2][2]<= 8'h0; vram_input_data_2[2][3]<= 8'h0;
            vram_input_data_2[2][4]<= 8'h0; vram_input_data_2[2][5]<= 8'h0; vram_input_data_2[2][6]<= 8'h0; vram_input_data_2[2][7]<= 8'h0;
            vram_input_data_2[2][8]<= 8'h0; vram_input_data_2[2][9]<= 8'h0; vram_input_data_2[2][10]<= 8'h0;vram_input_data_2[2][11]<= 8'h0;
            vram_input_data_2[2][12]<= 8'h0;vram_input_data_2[2][13]<= 8'h0;vram_input_data_2[2][14]<= 8'h0;vram_input_data_2[2][15]<= 8'h0;
            vram_input_data_2[3][0]<= 8'h0; vram_input_data_2[3][1]<= 8'h0; vram_input_data_2[3][2]<= 8'h0; vram_input_data_2[3][3]<= 8'h0;
            vram_input_data_2[3][4]<= 8'h0; vram_input_data_2[3][5]<= 8'h0; vram_input_data_2[3][6]<= 8'h0; vram_input_data_2[3][7]<= 8'h0;
            vram_input_data_2[3][8]<= 8'h0; vram_input_data_2[3][9]<= 8'h0; vram_input_data_2[3][10]<= 8'h0;vram_input_data_2[3][11]<= 8'h0;
            vram_input_data_2[3][12]<= 8'h0;vram_input_data_2[3][13]<= 8'h0;vram_input_data_2[3][14]<= 8'h0;vram_input_data_2[3][15]<= 8'h0;
            vram_input_data_2[4][0]<= 8'h0; vram_input_data_2[4][1]<= 8'h0; vram_input_data_2[4][2]<= 8'h0; vram_input_data_2[4][3]<= 8'h0;
            vram_input_data_2[4][4]<= 8'h0; vram_input_data_2[4][5]<= 8'h0; vram_input_data_2[4][6]<= 8'h0; vram_input_data_2[4][7]<= 8'h0;
            vram_input_data_2[4][8]<= 8'h0; vram_input_data_2[4][9]<= 8'h0; vram_input_data_2[4][10]<= 8'h0;vram_input_data_2[4][11]<= 8'h0;
            vram_input_data_2[4][12]<= 8'h0;vram_input_data_2[4][13]<= 8'h0;vram_input_data_2[4][14]<= 8'h0;vram_input_data_2[4][15]<= 8'h0;
            // rough_calc
            vram_input_data_3[0][0]<= 8'h0; vram_input_data_3[0][1]<= 8'h0; vram_input_data_3[0][2]<= 8'h0; vram_input_data_3[0][3]<= 8'h0;
            vram_input_data_3[0][4]<= 8'h0; vram_input_data_3[0][5]<= 8'h0; vram_input_data_3[0][6]<= 8'h0; vram_input_data_3[0][7]<= 8'h0;
            vram_input_data_3[0][8]<= 8'h0; vram_input_data_3[0][9]<= 8'h0; vram_input_data_3[0][10]<= 8'h0;vram_input_data_3[0][11]<= 8'h0;
            vram_input_data_3[0][12]<= 8'h0;vram_input_data_3[0][13]<= 8'h0;vram_input_data_3[0][14]<= 8'h0;vram_input_data_3[0][15]<= 8'h0;
            vram_input_data_3[1][0]<= 8'h0; vram_input_data_3[1][1]<= 8'h0; vram_input_data_3[1][2]<= 8'h0; vram_input_data_3[1][3]<= 8'h0;
            vram_input_data_3[1][4]<= 8'h0; vram_input_data_3[1][5]<= 8'h0; vram_input_data_3[1][6]<= 8'h0; vram_input_data_3[1][7]<= 8'h0;
            vram_input_data_3[1][8]<= 8'h0; vram_input_data_3[1][9]<= 8'h0; vram_input_data_3[1][10]<= 8'h0;vram_input_data_3[1][11]<= 8'h0;
            vram_input_data_3[1][12]<= 8'h0;vram_input_data_3[1][13]<= 8'h0;vram_input_data_3[1][14]<= 8'h0;vram_input_data_3[1][15]<= 8'h0;
            vram_input_data_3[2][0]<= 8'h0; vram_input_data_3[2][1]<= 8'h0; vram_input_data_3[2][2]<= 8'h0; vram_input_data_3[2][3]<= 8'h0;
            vram_input_data_3[2][4]<= 8'h0; vram_input_data_3[2][5]<= 8'h0; vram_input_data_3[2][6]<= 8'h0; vram_input_data_3[2][7]<= 8'h0;
            vram_input_data_3[2][8]<= 8'h0; vram_input_data_3[2][9]<= 8'h0; vram_input_data_3[2][10]<= 8'h0;vram_input_data_3[2][11]<= 8'h0;
            vram_input_data_3[2][12]<= 8'h0;vram_input_data_3[2][13]<= 8'h0;vram_input_data_3[2][14]<= 8'h0;vram_input_data_3[2][15]<= 8'h0;
            vram_input_data_3[3][0]<= 8'h0; vram_input_data_3[3][1]<= 8'h0; vram_input_data_3[3][2]<= 8'h0; vram_input_data_3[3][3]<= 8'h0;
            vram_input_data_3[3][4]<= 8'h0; vram_input_data_3[3][5]<= 8'h0; vram_input_data_3[3][6]<= 8'h0; vram_input_data_3[3][7]<= 8'h0;
            vram_input_data_3[3][8]<= 8'h0; vram_input_data_3[3][9]<= 8'h0; vram_input_data_3[3][10]<= 8'h0;vram_input_data_3[3][11]<= 8'h0;
            vram_input_data_3[3][12]<= 8'h0;vram_input_data_3[3][13]<= 8'h0;vram_input_data_3[3][14]<= 8'h0;vram_input_data_3[3][15]<= 8'h0;
            vram_input_data_3[4][0]<= 8'h0; vram_input_data_3[4][1]<= 8'h0; vram_input_data_3[4][2]<= 8'h0; vram_input_data_3[4][3]<= 8'h0;
            vram_input_data_3[4][4]<= 8'h0; vram_input_data_3[4][5]<= 8'h0; vram_input_data_3[4][6]<= 8'h0; vram_input_data_3[4][7]<= 8'h0;
            vram_input_data_3[4][8]<= 8'h0; vram_input_data_3[4][9]<= 8'h0; vram_input_data_3[4][10]<= 8'h0;vram_input_data_3[4][11]<= 8'h0;
            vram_input_data_3[4][12]<= 8'h0;vram_input_data_3[4][13]<= 8'h0;vram_input_data_3[4][14]<= 8'h0;vram_input_data_3[4][15]<= 8'h0;
            // accurate_calc
            vram_input_data_4[0][0]<= 8'h0; vram_input_data_4[0][1]<= 8'h0; vram_input_data_4[0][2]<= 8'h0; vram_input_data_4[0][3]<= 8'h0;
            vram_input_data_4[0][4]<= 8'h0; vram_input_data_4[0][5]<= 8'h0; vram_input_data_4[0][6]<= 8'h0; vram_input_data_4[0][7]<= 8'h0;
            vram_input_data_4[0][8]<= 8'h0; vram_input_data_4[0][9]<= 8'h0; vram_input_data_4[0][10]<= 8'h0;vram_input_data_4[0][11]<= 8'h0;
            vram_input_data_4[0][12]<= 8'h0;vram_input_data_4[0][13]<= 8'h0;vram_input_data_4[0][14]<= 8'h0;vram_input_data_4[0][15]<= 8'h0;
            vram_input_data_4[1][0]<= 8'h0; vram_input_data_4[1][1]<= 8'h0; vram_input_data_4[1][2]<= 8'h0; vram_input_data_4[1][3]<= 8'h0;
            vram_input_data_4[1][4]<= 8'h0; vram_input_data_4[1][5]<= 8'h0; vram_input_data_4[1][6]<= 8'h0; vram_input_data_4[1][7]<= 8'h0;
            vram_input_data_4[1][8]<= 8'h0; vram_input_data_4[1][9]<= 8'h0; vram_input_data_4[1][10]<= 8'h0;vram_input_data_4[1][11]<= 8'h0;
            vram_input_data_4[1][12]<= 8'h0;vram_input_data_4[1][13]<= 8'h0;vram_input_data_4[1][14]<= 8'h0;vram_input_data_4[1][15]<= 8'h0;
            vram_input_data_4[2][0]<= 8'h0; vram_input_data_4[2][1]<= 8'h0; vram_input_data_4[2][2]<= 8'h0; vram_input_data_4[2][3]<= 8'h0;
            vram_input_data_4[2][4]<= 8'h0; vram_input_data_4[2][5]<= 8'h0; vram_input_data_4[2][6]<= 8'h0; vram_input_data_4[2][7]<= 8'h0;
            vram_input_data_4[2][8]<= 8'h0; vram_input_data_4[2][9]<= 8'h0; vram_input_data_4[2][10]<= 8'h0;vram_input_data_4[2][11]<= 8'h0;
            vram_input_data_4[2][12]<= 8'h0;vram_input_data_4[2][13]<= 8'h0;vram_input_data_4[2][14]<= 8'h0;vram_input_data_4[2][15]<= 8'h0;
            vram_input_data_4[3][0]<= 8'h0; vram_input_data_4[3][1]<= 8'h0; vram_input_data_4[3][2]<= 8'h0; vram_input_data_4[3][3]<= 8'h0;
            vram_input_data_4[3][4]<= 8'h0; vram_input_data_4[3][5]<= 8'h0; vram_input_data_4[3][6]<= 8'h0; vram_input_data_4[3][7]<= 8'h0;
            vram_input_data_4[3][8]<= 8'h0; vram_input_data_4[3][9]<= 8'h0; vram_input_data_4[3][10]<= 8'h0;vram_input_data_4[3][11]<= 8'h0;
            vram_input_data_4[3][12]<= 8'h0;vram_input_data_4[3][13]<= 8'h0;vram_input_data_4[3][14]<= 8'h0;vram_input_data_4[3][15]<= 8'h0;
            vram_input_data_4[4][0]<= 8'h0; vram_input_data_4[4][1]<= 8'h0; vram_input_data_4[4][2]<= 8'h0; vram_input_data_4[4][3]<= 8'h0;
            vram_input_data_4[4][4]<= 8'h0; vram_input_data_4[4][5]<= 8'h0; vram_input_data_4[4][6]<= 8'h0; vram_input_data_4[4][7]<= 8'h0;
            vram_input_data_4[4][8]<= 8'h0; vram_input_data_4[4][9]<= 8'h0; vram_input_data_4[4][10]<= 8'h0;vram_input_data_4[4][11]<= 8'h0;
            vram_input_data_4[4][12]<= 8'h0;vram_input_data_4[4][13]<= 8'h0;vram_input_data_4[4][14]<= 8'h0;vram_input_data_4[4][15]<= 8'h0;
        end else begin
            case(user_data_f0 % 10) // f0的个位
                24'd0 : begin
                    vram_input_data_1[4][0]<= rom_font_0[0];
                    vram_input_data_1[4][1]<= rom_font_0[1];
                    vram_input_data_1[4][2]<= rom_font_0[2];
                    vram_input_data_1[4][3]<= rom_font_0[3];
                    vram_input_data_1[4][4]<= rom_font_0[4];
                    vram_input_data_1[4][5]<= rom_font_0[5];
                    vram_input_data_1[4][6]<= rom_font_0[6];
                    vram_input_data_1[4][7]<= rom_font_0[7];
                    vram_input_data_1[4][8]<= rom_font_0[8];
                    vram_input_data_1[4][9]<= rom_font_0[9];
                    vram_input_data_1[4][10]<= rom_font_0[10];
                    vram_input_data_1[4][11]<= rom_font_0[11];
                    vram_input_data_1[4][12]<= rom_font_0[12];
                    vram_input_data_1[4][13]<= rom_font_0[13];
                    vram_input_data_1[4][14]<= rom_font_0[14];
                    vram_input_data_1[4][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_1[4][0]<= rom_font_1[0];
                    vram_input_data_1[4][1]<= rom_font_1[1];
                    vram_input_data_1[4][2]<= rom_font_1[2];
                    vram_input_data_1[4][3]<= rom_font_1[3];
                    vram_input_data_1[4][4]<= rom_font_1[4];
                    vram_input_data_1[4][5]<= rom_font_1[5];
                    vram_input_data_1[4][6]<= rom_font_1[6];
                    vram_input_data_1[4][7]<= rom_font_1[7];
                    vram_input_data_1[4][8]<= rom_font_1[8];
                    vram_input_data_1[4][9]<= rom_font_1[9];
                    vram_input_data_1[4][10]<= rom_font_1[10];
                    vram_input_data_1[4][11]<= rom_font_1[11];
                    vram_input_data_1[4][12]<= rom_font_1[12];
                    vram_input_data_1[4][13]<= rom_font_1[13];
                    vram_input_data_1[4][14]<= rom_font_1[14];
                    vram_input_data_1[4][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_1[4][0]<= rom_font_2[0];
                    vram_input_data_1[4][1]<= rom_font_2[1];
                    vram_input_data_1[4][2]<= rom_font_2[2];
                    vram_input_data_1[4][3]<= rom_font_2[3];
                    vram_input_data_1[4][4]<= rom_font_2[4];
                    vram_input_data_1[4][5]<= rom_font_2[5];
                    vram_input_data_1[4][6]<= rom_font_2[6];
                    vram_input_data_1[4][7]<= rom_font_2[7];
                    vram_input_data_1[4][8]<= rom_font_2[8];
                    vram_input_data_1[4][9]<= rom_font_2[9];
                    vram_input_data_1[4][10]<= rom_font_2[10];
                    vram_input_data_1[4][11]<= rom_font_2[11];
                    vram_input_data_1[4][12]<= rom_font_2[12];
                    vram_input_data_1[4][13]<= rom_font_2[13];
                    vram_input_data_1[4][14]<= rom_font_2[14];
                    vram_input_data_1[4][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_1[4][0]<= rom_font_3[0];
                    vram_input_data_1[4][1]<= rom_font_3[1];
                    vram_input_data_1[4][2]<= rom_font_3[2];
                    vram_input_data_1[4][3]<= rom_font_3[3];
                    vram_input_data_1[4][4]<= rom_font_3[4];
                    vram_input_data_1[4][5]<= rom_font_3[5];
                    vram_input_data_1[4][6]<= rom_font_3[6];
                    vram_input_data_1[4][7]<= rom_font_3[7];
                    vram_input_data_1[4][8]<= rom_font_3[8];
                    vram_input_data_1[4][9]<= rom_font_3[9];
                    vram_input_data_1[4][10]<= rom_font_3[10];
                    vram_input_data_1[4][11]<= rom_font_3[11];
                    vram_input_data_1[4][12]<= rom_font_3[12];
                    vram_input_data_1[4][13]<= rom_font_3[13];
                    vram_input_data_1[4][14]<= rom_font_3[14];
                    vram_input_data_1[4][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_1[4][0]<= rom_font_4[0];
                    vram_input_data_1[4][1]<= rom_font_4[1];
                    vram_input_data_1[4][2]<= rom_font_4[2];
                    vram_input_data_1[4][3]<= rom_font_4[3];
                    vram_input_data_1[4][4]<= rom_font_4[4];
                    vram_input_data_1[4][5]<= rom_font_4[5];
                    vram_input_data_1[4][6]<= rom_font_4[6];
                    vram_input_data_1[4][7]<= rom_font_4[7];
                    vram_input_data_1[4][8]<= rom_font_4[8];
                    vram_input_data_1[4][9]<= rom_font_4[9];
                    vram_input_data_1[4][10]<= rom_font_4[10];
                    vram_input_data_1[4][11]<= rom_font_4[11];
                    vram_input_data_1[4][12]<= rom_font_4[12];
                    vram_input_data_1[4][13]<= rom_font_4[13];
                    vram_input_data_1[4][14]<= rom_font_4[14];
                    vram_input_data_1[4][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_1[4][0]<= rom_font_5[0];
                    vram_input_data_1[4][1]<= rom_font_5[1];
                    vram_input_data_1[4][2]<= rom_font_5[2];
                    vram_input_data_1[4][3]<= rom_font_5[3];
                    vram_input_data_1[4][4]<= rom_font_5[4];
                    vram_input_data_1[4][5]<= rom_font_5[5];
                    vram_input_data_1[4][6]<= rom_font_5[6];
                    vram_input_data_1[4][7]<= rom_font_5[7];
                    vram_input_data_1[4][8]<= rom_font_5[8];
                    vram_input_data_1[4][9]<= rom_font_5[9];
                    vram_input_data_1[4][10]<= rom_font_5[10];
                    vram_input_data_1[4][11]<= rom_font_5[11];
                    vram_input_data_1[4][12]<= rom_font_5[12];
                    vram_input_data_1[4][13]<= rom_font_5[13];
                    vram_input_data_1[4][14]<= rom_font_5[14];
                    vram_input_data_1[4][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_1[4][0]<= rom_font_6[0];
                    vram_input_data_1[4][1]<= rom_font_6[1];
                    vram_input_data_1[4][2]<= rom_font_6[2];
                    vram_input_data_1[4][3]<= rom_font_6[3];
                    vram_input_data_1[4][4]<= rom_font_6[4];
                    vram_input_data_1[4][5]<= rom_font_6[5];
                    vram_input_data_1[4][6]<= rom_font_6[6];
                    vram_input_data_1[4][7]<= rom_font_6[7];
                    vram_input_data_1[4][8]<= rom_font_6[8];
                    vram_input_data_1[4][9]<= rom_font_6[9];
                    vram_input_data_1[4][10]<= rom_font_6[10];
                    vram_input_data_1[4][11]<= rom_font_6[11];
                    vram_input_data_1[4][12]<= rom_font_6[12];
                    vram_input_data_1[4][13]<= rom_font_6[13];
                    vram_input_data_1[4][14]<= rom_font_6[14];
                    vram_input_data_1[4][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_1[4][0]<= rom_font_7[0];
                    vram_input_data_1[4][1]<= rom_font_7[1];
                    vram_input_data_1[4][2]<= rom_font_7[2];
                    vram_input_data_1[4][3]<= rom_font_7[3];
                    vram_input_data_1[4][4]<= rom_font_7[4];
                    vram_input_data_1[4][5]<= rom_font_7[5];
                    vram_input_data_1[4][6]<= rom_font_7[6];
                    vram_input_data_1[4][7]<= rom_font_7[7];
                    vram_input_data_1[4][8]<= rom_font_7[8];
                    vram_input_data_1[4][9]<= rom_font_7[9];
                    vram_input_data_1[4][10]<= rom_font_7[10];
                    vram_input_data_1[4][11]<= rom_font_7[11];
                    vram_input_data_1[4][12]<= rom_font_7[12];
                    vram_input_data_1[4][13]<= rom_font_7[13];
                    vram_input_data_1[4][14]<= rom_font_7[14];
                    vram_input_data_1[4][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_1[4][0]<= rom_font_8[0];
                    vram_input_data_1[4][1]<= rom_font_8[1];
                    vram_input_data_1[4][2]<= rom_font_8[2];
                    vram_input_data_1[4][3]<= rom_font_8[3];
                    vram_input_data_1[4][4]<= rom_font_8[4];
                    vram_input_data_1[4][5]<= rom_font_8[5];
                    vram_input_data_1[4][6]<= rom_font_8[6];
                    vram_input_data_1[4][7]<= rom_font_8[7];
                    vram_input_data_1[4][8]<= rom_font_8[8];
                    vram_input_data_1[4][9]<= rom_font_8[9];
                    vram_input_data_1[4][10]<= rom_font_8[10];
                    vram_input_data_1[4][11]<= rom_font_8[11];
                    vram_input_data_1[4][12]<= rom_font_8[12];
                    vram_input_data_1[4][13]<= rom_font_8[13];
                    vram_input_data_1[4][14]<= rom_font_8[14];
                    vram_input_data_1[4][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_1[4][0]<= rom_font_9[0];
                    vram_input_data_1[4][1]<= rom_font_9[1];
                    vram_input_data_1[4][2]<= rom_font_9[2];
                    vram_input_data_1[4][3]<= rom_font_9[3];
                    vram_input_data_1[4][4]<= rom_font_9[4];
                    vram_input_data_1[4][5]<= rom_font_9[5];
                    vram_input_data_1[4][6]<= rom_font_9[6];
                    vram_input_data_1[4][7]<= rom_font_9[7];
                    vram_input_data_1[4][8]<= rom_font_9[8];
                    vram_input_data_1[4][9]<= rom_font_9[9];
                    vram_input_data_1[4][10]<= rom_font_9[10];
                    vram_input_data_1[4][11]<= rom_font_9[11];
                    vram_input_data_1[4][12]<= rom_font_9[12];
                    vram_input_data_1[4][13]<= rom_font_9[13];
                    vram_input_data_1[4][14]<= rom_font_9[14];
                    vram_input_data_1[4][15]<= rom_font_9[15];
                end
            endcase case((user_data_f0 % 100) / 10) // f0的十位
                24'd0 : begin
                    vram_input_data_1[3][0]<= rom_font_0[0];
                    vram_input_data_1[3][1]<= rom_font_0[1];
                    vram_input_data_1[3][2]<= rom_font_0[2];
                    vram_input_data_1[3][3]<= rom_font_0[3];
                    vram_input_data_1[3][4]<= rom_font_0[4];
                    vram_input_data_1[3][5]<= rom_font_0[5];
                    vram_input_data_1[3][6]<= rom_font_0[6];
                    vram_input_data_1[3][7]<= rom_font_0[7];
                    vram_input_data_1[3][8]<= rom_font_0[8];
                    vram_input_data_1[3][9]<= rom_font_0[9];
                    vram_input_data_1[3][10]<= rom_font_0[10];
                    vram_input_data_1[3][11]<= rom_font_0[11];
                    vram_input_data_1[3][12]<= rom_font_0[12];
                    vram_input_data_1[3][13]<= rom_font_0[13];
                    vram_input_data_1[3][14]<= rom_font_0[14];
                    vram_input_data_1[3][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_1[3][0]<= rom_font_1[0];
                    vram_input_data_1[3][1]<= rom_font_1[1];
                    vram_input_data_1[3][2]<= rom_font_1[2];
                    vram_input_data_1[3][3]<= rom_font_1[3];
                    vram_input_data_1[3][4]<= rom_font_1[4];
                    vram_input_data_1[3][5]<= rom_font_1[5];
                    vram_input_data_1[3][6]<= rom_font_1[6];
                    vram_input_data_1[3][7]<= rom_font_1[7];
                    vram_input_data_1[3][8]<= rom_font_1[8];
                    vram_input_data_1[3][9]<= rom_font_1[9];
                    vram_input_data_1[3][10]<= rom_font_1[10];
                    vram_input_data_1[3][11]<= rom_font_1[11];
                    vram_input_data_1[3][12]<= rom_font_1[12];
                    vram_input_data_1[3][13]<= rom_font_1[13];
                    vram_input_data_1[3][14]<= rom_font_1[14];
                    vram_input_data_1[3][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_1[3][0]<= rom_font_2[0];
                    vram_input_data_1[3][1]<= rom_font_2[1];
                    vram_input_data_1[3][2]<= rom_font_2[2];
                    vram_input_data_1[3][3]<= rom_font_2[3];
                    vram_input_data_1[3][4]<= rom_font_2[4];
                    vram_input_data_1[3][5]<= rom_font_2[5];
                    vram_input_data_1[3][6]<= rom_font_2[6];
                    vram_input_data_1[3][7]<= rom_font_2[7];
                    vram_input_data_1[3][8]<= rom_font_2[8];
                    vram_input_data_1[3][9]<= rom_font_2[9];
                    vram_input_data_1[3][10]<= rom_font_2[10];
                    vram_input_data_1[3][11]<= rom_font_2[11];
                    vram_input_data_1[3][12]<= rom_font_2[12];
                    vram_input_data_1[3][13]<= rom_font_2[13];
                    vram_input_data_1[3][14]<= rom_font_2[14];
                    vram_input_data_1[3][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_1[3][0]<= rom_font_3[0];
                    vram_input_data_1[3][1]<= rom_font_3[1];
                    vram_input_data_1[3][2]<= rom_font_3[2];
                    vram_input_data_1[3][3]<= rom_font_3[3];
                    vram_input_data_1[3][4]<= rom_font_3[4];
                    vram_input_data_1[3][5]<= rom_font_3[5];
                    vram_input_data_1[3][6]<= rom_font_3[6];
                    vram_input_data_1[3][7]<= rom_font_3[7];
                    vram_input_data_1[3][8]<= rom_font_3[8];
                    vram_input_data_1[3][9]<= rom_font_3[9];
                    vram_input_data_1[3][10]<= rom_font_3[10];
                    vram_input_data_1[3][11]<= rom_font_3[11];
                    vram_input_data_1[3][12]<= rom_font_3[12];
                    vram_input_data_1[3][13]<= rom_font_3[13];
                    vram_input_data_1[3][14]<= rom_font_3[14];
                    vram_input_data_1[3][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_1[3][0]<= rom_font_4[0];
                    vram_input_data_1[3][1]<= rom_font_4[1];
                    vram_input_data_1[3][2]<= rom_font_4[2];
                    vram_input_data_1[3][3]<= rom_font_4[3];
                    vram_input_data_1[3][4]<= rom_font_4[4];
                    vram_input_data_1[3][5]<= rom_font_4[5];
                    vram_input_data_1[3][6]<= rom_font_4[6];
                    vram_input_data_1[3][7]<= rom_font_4[7];
                    vram_input_data_1[3][8]<= rom_font_4[8];
                    vram_input_data_1[3][9]<= rom_font_4[9];
                    vram_input_data_1[3][10]<= rom_font_4[10];
                    vram_input_data_1[3][11]<= rom_font_4[11];
                    vram_input_data_1[3][12]<= rom_font_4[12];
                    vram_input_data_1[3][13]<= rom_font_4[13];
                    vram_input_data_1[3][14]<= rom_font_4[14];
                    vram_input_data_1[3][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_1[3][0]<= rom_font_5[0];
                    vram_input_data_1[3][1]<= rom_font_5[1];
                    vram_input_data_1[3][2]<= rom_font_5[2];
                    vram_input_data_1[3][3]<= rom_font_5[3];
                    vram_input_data_1[3][4]<= rom_font_5[4];
                    vram_input_data_1[3][5]<= rom_font_5[5];
                    vram_input_data_1[3][6]<= rom_font_5[6];
                    vram_input_data_1[3][7]<= rom_font_5[7];
                    vram_input_data_1[3][8]<= rom_font_5[8];
                    vram_input_data_1[3][9]<= rom_font_5[9];
                    vram_input_data_1[3][10]<= rom_font_5[10];
                    vram_input_data_1[3][11]<= rom_font_5[11];
                    vram_input_data_1[3][12]<= rom_font_5[12];
                    vram_input_data_1[3][13]<= rom_font_5[13];
                    vram_input_data_1[3][14]<= rom_font_5[14];
                    vram_input_data_1[3][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_1[3][0]<= rom_font_6[0];
                    vram_input_data_1[3][1]<= rom_font_6[1];
                    vram_input_data_1[3][2]<= rom_font_6[2];
                    vram_input_data_1[3][3]<= rom_font_6[3];
                    vram_input_data_1[3][4]<= rom_font_6[4];
                    vram_input_data_1[3][5]<= rom_font_6[5];
                    vram_input_data_1[3][6]<= rom_font_6[6];
                    vram_input_data_1[3][7]<= rom_font_6[7];
                    vram_input_data_1[3][8]<= rom_font_6[8];
                    vram_input_data_1[3][9]<= rom_font_6[9];
                    vram_input_data_1[3][10]<= rom_font_6[10];
                    vram_input_data_1[3][11]<= rom_font_6[11];
                    vram_input_data_1[3][12]<= rom_font_6[12];
                    vram_input_data_1[3][13]<= rom_font_6[13];
                    vram_input_data_1[3][14]<= rom_font_6[14];
                    vram_input_data_1[3][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_1[3][0]<= rom_font_7[0];
                    vram_input_data_1[3][1]<= rom_font_7[1];
                    vram_input_data_1[3][2]<= rom_font_7[2];
                    vram_input_data_1[3][3]<= rom_font_7[3];
                    vram_input_data_1[3][4]<= rom_font_7[4];
                    vram_input_data_1[3][5]<= rom_font_7[5];
                    vram_input_data_1[3][6]<= rom_font_7[6];
                    vram_input_data_1[3][7]<= rom_font_7[7];
                    vram_input_data_1[3][8]<= rom_font_7[8];
                    vram_input_data_1[3][9]<= rom_font_7[9];
                    vram_input_data_1[3][10]<= rom_font_7[10];
                    vram_input_data_1[3][11]<= rom_font_7[11];
                    vram_input_data_1[3][12]<= rom_font_7[12];
                    vram_input_data_1[3][13]<= rom_font_7[13];
                    vram_input_data_1[3][14]<= rom_font_7[14];
                    vram_input_data_1[3][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_1[3][0]<= rom_font_8[0];
                    vram_input_data_1[3][1]<= rom_font_8[1];
                    vram_input_data_1[3][2]<= rom_font_8[2];
                    vram_input_data_1[3][3]<= rom_font_8[3];
                    vram_input_data_1[3][4]<= rom_font_8[4];
                    vram_input_data_1[3][5]<= rom_font_8[5];
                    vram_input_data_1[3][6]<= rom_font_8[6];
                    vram_input_data_1[3][7]<= rom_font_8[7];
                    vram_input_data_1[3][8]<= rom_font_8[8];
                    vram_input_data_1[3][9]<= rom_font_8[9];
                    vram_input_data_1[3][10]<= rom_font_8[10];
                    vram_input_data_1[3][11]<= rom_font_8[11];
                    vram_input_data_1[3][12]<= rom_font_8[12];
                    vram_input_data_1[3][13]<= rom_font_8[13];
                    vram_input_data_1[3][14]<= rom_font_8[14];
                    vram_input_data_1[3][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_1[3][0]<= rom_font_9[0];
                    vram_input_data_1[3][1]<= rom_font_9[1];
                    vram_input_data_1[3][2]<= rom_font_9[2];
                    vram_input_data_1[3][3]<= rom_font_9[3];
                    vram_input_data_1[3][4]<= rom_font_9[4];
                    vram_input_data_1[3][5]<= rom_font_9[5];
                    vram_input_data_1[3][6]<= rom_font_9[6];
                    vram_input_data_1[3][7]<= rom_font_9[7];
                    vram_input_data_1[3][8]<= rom_font_9[8];
                    vram_input_data_1[3][9]<= rom_font_9[9];
                    vram_input_data_1[3][10]<= rom_font_9[10];
                    vram_input_data_1[3][11]<= rom_font_9[11];
                    vram_input_data_1[3][12]<= rom_font_9[12];
                    vram_input_data_1[3][13]<= rom_font_9[13];
                    vram_input_data_1[3][14]<= rom_font_9[14];
                    vram_input_data_1[3][15]<= rom_font_9[15];
                end
            endcase case((user_data_f0 % 1000) / 100) // f0的百位
                24'd0 : begin
                    vram_input_data_1[2][0]<= rom_font_0[0];
                    vram_input_data_1[2][1]<= rom_font_0[1];
                    vram_input_data_1[2][2]<= rom_font_0[2];
                    vram_input_data_1[2][3]<= rom_font_0[3];
                    vram_input_data_1[2][4]<= rom_font_0[4];
                    vram_input_data_1[2][5]<= rom_font_0[5];
                    vram_input_data_1[2][6]<= rom_font_0[6];
                    vram_input_data_1[2][7]<= rom_font_0[7];
                    vram_input_data_1[2][8]<= rom_font_0[8];
                    vram_input_data_1[2][9]<= rom_font_0[9];
                    vram_input_data_1[2][10]<= rom_font_0[10];
                    vram_input_data_1[2][11]<= rom_font_0[11];
                    vram_input_data_1[2][12]<= rom_font_0[12];
                    vram_input_data_1[2][13]<= rom_font_0[13];
                    vram_input_data_1[2][14]<= rom_font_0[14];
                    vram_input_data_1[2][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_1[2][0]<= rom_font_1[0];
                    vram_input_data_1[2][1]<= rom_font_1[1];
                    vram_input_data_1[2][2]<= rom_font_1[2];
                    vram_input_data_1[2][3]<= rom_font_1[3];
                    vram_input_data_1[2][4]<= rom_font_1[4];
                    vram_input_data_1[2][5]<= rom_font_1[5];
                    vram_input_data_1[2][6]<= rom_font_1[6];
                    vram_input_data_1[2][7]<= rom_font_1[7];
                    vram_input_data_1[2][8]<= rom_font_1[8];
                    vram_input_data_1[2][9]<= rom_font_1[9];
                    vram_input_data_1[2][10]<= rom_font_1[10];
                    vram_input_data_1[2][11]<= rom_font_1[11];
                    vram_input_data_1[2][12]<= rom_font_1[12];
                    vram_input_data_1[2][13]<= rom_font_1[13];
                    vram_input_data_1[2][14]<= rom_font_1[14];
                    vram_input_data_1[2][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_1[2][0]<= rom_font_2[0];
                    vram_input_data_1[2][1]<= rom_font_2[1];
                    vram_input_data_1[2][2]<= rom_font_2[2];
                    vram_input_data_1[2][3]<= rom_font_2[3];
                    vram_input_data_1[2][4]<= rom_font_2[4];
                    vram_input_data_1[2][5]<= rom_font_2[5];
                    vram_input_data_1[2][6]<= rom_font_2[6];
                    vram_input_data_1[2][7]<= rom_font_2[7];
                    vram_input_data_1[2][8]<= rom_font_2[8];
                    vram_input_data_1[2][9]<= rom_font_2[9];
                    vram_input_data_1[2][10]<= rom_font_2[10];
                    vram_input_data_1[2][11]<= rom_font_2[11];
                    vram_input_data_1[2][12]<= rom_font_2[12];
                    vram_input_data_1[2][13]<= rom_font_2[13];
                    vram_input_data_1[2][14]<= rom_font_2[14];
                    vram_input_data_1[2][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_1[2][0]<= rom_font_3[0];
                    vram_input_data_1[2][1]<= rom_font_3[1];
                    vram_input_data_1[2][2]<= rom_font_3[2];
                    vram_input_data_1[2][3]<= rom_font_3[3];
                    vram_input_data_1[2][4]<= rom_font_3[4];
                    vram_input_data_1[2][5]<= rom_font_3[5];
                    vram_input_data_1[2][6]<= rom_font_3[6];
                    vram_input_data_1[2][7]<= rom_font_3[7];
                    vram_input_data_1[2][8]<= rom_font_3[8];
                    vram_input_data_1[2][9]<= rom_font_3[9];
                    vram_input_data_1[2][10]<= rom_font_3[10];
                    vram_input_data_1[2][11]<= rom_font_3[11];
                    vram_input_data_1[2][12]<= rom_font_3[12];
                    vram_input_data_1[2][13]<= rom_font_3[13];
                    vram_input_data_1[2][14]<= rom_font_3[14];
                    vram_input_data_1[2][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_1[2][0]<= rom_font_4[0];
                    vram_input_data_1[2][1]<= rom_font_4[1];
                    vram_input_data_1[2][2]<= rom_font_4[2];
                    vram_input_data_1[2][3]<= rom_font_4[3];
                    vram_input_data_1[2][4]<= rom_font_4[4];
                    vram_input_data_1[2][5]<= rom_font_4[5];
                    vram_input_data_1[2][6]<= rom_font_4[6];
                    vram_input_data_1[2][7]<= rom_font_4[7];
                    vram_input_data_1[2][8]<= rom_font_4[8];
                    vram_input_data_1[2][9]<= rom_font_4[9];
                    vram_input_data_1[2][10]<= rom_font_4[10];
                    vram_input_data_1[2][11]<= rom_font_4[11];
                    vram_input_data_1[2][12]<= rom_font_4[12];
                    vram_input_data_1[2][13]<= rom_font_4[13];
                    vram_input_data_1[2][14]<= rom_font_4[14];
                    vram_input_data_1[2][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_1[2][0]<= rom_font_5[0];
                    vram_input_data_1[2][1]<= rom_font_5[1];
                    vram_input_data_1[2][2]<= rom_font_5[2];
                    vram_input_data_1[2][3]<= rom_font_5[3];
                    vram_input_data_1[2][4]<= rom_font_5[4];
                    vram_input_data_1[2][5]<= rom_font_5[5];
                    vram_input_data_1[2][6]<= rom_font_5[6];
                    vram_input_data_1[2][7]<= rom_font_5[7];
                    vram_input_data_1[2][8]<= rom_font_5[8];
                    vram_input_data_1[2][9]<= rom_font_5[9];
                    vram_input_data_1[2][10]<= rom_font_5[10];
                    vram_input_data_1[2][11]<= rom_font_5[11];
                    vram_input_data_1[2][12]<= rom_font_5[12];
                    vram_input_data_1[2][13]<= rom_font_5[13];
                    vram_input_data_1[2][14]<= rom_font_5[14];
                    vram_input_data_1[2][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_1[2][0]<= rom_font_6[0];
                    vram_input_data_1[2][1]<= rom_font_6[1];
                    vram_input_data_1[2][2]<= rom_font_6[2];
                    vram_input_data_1[2][3]<= rom_font_6[3];
                    vram_input_data_1[2][4]<= rom_font_6[4];
                    vram_input_data_1[2][5]<= rom_font_6[5];
                    vram_input_data_1[2][6]<= rom_font_6[6];
                    vram_input_data_1[2][7]<= rom_font_6[7];
                    vram_input_data_1[2][8]<= rom_font_6[8];
                    vram_input_data_1[2][9]<= rom_font_6[9];
                    vram_input_data_1[2][10]<= rom_font_6[10];
                    vram_input_data_1[2][11]<= rom_font_6[11];
                    vram_input_data_1[2][12]<= rom_font_6[12];
                    vram_input_data_1[2][13]<= rom_font_6[13];
                    vram_input_data_1[2][14]<= rom_font_6[14];
                    vram_input_data_1[2][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_1[2][0]<= rom_font_7[0];
                    vram_input_data_1[2][1]<= rom_font_7[1];
                    vram_input_data_1[2][2]<= rom_font_7[2];
                    vram_input_data_1[2][3]<= rom_font_7[3];
                    vram_input_data_1[2][4]<= rom_font_7[4];
                    vram_input_data_1[2][5]<= rom_font_7[5];
                    vram_input_data_1[2][6]<= rom_font_7[6];
                    vram_input_data_1[2][7]<= rom_font_7[7];
                    vram_input_data_1[2][8]<= rom_font_7[8];
                    vram_input_data_1[2][9]<= rom_font_7[9];
                    vram_input_data_1[2][10]<= rom_font_7[10];
                    vram_input_data_1[2][11]<= rom_font_7[11];
                    vram_input_data_1[2][12]<= rom_font_7[12];
                    vram_input_data_1[2][13]<= rom_font_7[13];
                    vram_input_data_1[2][14]<= rom_font_7[14];
                    vram_input_data_1[2][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_1[2][0]<= rom_font_8[0];
                    vram_input_data_1[2][1]<= rom_font_8[1];
                    vram_input_data_1[2][2]<= rom_font_8[2];
                    vram_input_data_1[2][3]<= rom_font_8[3];
                    vram_input_data_1[2][4]<= rom_font_8[4];
                    vram_input_data_1[2][5]<= rom_font_8[5];
                    vram_input_data_1[2][6]<= rom_font_8[6];
                    vram_input_data_1[2][7]<= rom_font_8[7];
                    vram_input_data_1[2][8]<= rom_font_8[8];
                    vram_input_data_1[2][9]<= rom_font_8[9];
                    vram_input_data_1[2][10]<= rom_font_8[10];
                    vram_input_data_1[2][11]<= rom_font_8[11];
                    vram_input_data_1[2][12]<= rom_font_8[12];
                    vram_input_data_1[2][13]<= rom_font_8[13];
                    vram_input_data_1[2][14]<= rom_font_8[14];
                    vram_input_data_1[2][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_1[2][0]<= rom_font_9[0];
                    vram_input_data_1[2][1]<= rom_font_9[1];
                    vram_input_data_1[2][2]<= rom_font_9[2];
                    vram_input_data_1[2][3]<= rom_font_9[3];
                    vram_input_data_1[2][4]<= rom_font_9[4];
                    vram_input_data_1[2][5]<= rom_font_9[5];
                    vram_input_data_1[2][6]<= rom_font_9[6];
                    vram_input_data_1[2][7]<= rom_font_9[7];
                    vram_input_data_1[2][8]<= rom_font_9[8];
                    vram_input_data_1[2][9]<= rom_font_9[9];
                    vram_input_data_1[2][10]<= rom_font_9[10];
                    vram_input_data_1[2][11]<= rom_font_9[11];
                    vram_input_data_1[2][12]<= rom_font_9[12];
                    vram_input_data_1[2][13]<= rom_font_9[13];
                    vram_input_data_1[2][14]<= rom_font_9[14];
                    vram_input_data_1[2][15]<= rom_font_9[15];
                end
            endcase case((user_data_f0 % 10000) / 1000) // f0的千位
                24'd0 : begin
                    vram_input_data_1[1][0]<= rom_font_0[0];
                    vram_input_data_1[1][1]<= rom_font_0[1];
                    vram_input_data_1[1][2]<= rom_font_0[2];
                    vram_input_data_1[1][3]<= rom_font_0[3];
                    vram_input_data_1[1][4]<= rom_font_0[4];
                    vram_input_data_1[1][5]<= rom_font_0[5];
                    vram_input_data_1[1][6]<= rom_font_0[6];
                    vram_input_data_1[1][7]<= rom_font_0[7];
                    vram_input_data_1[1][8]<= rom_font_0[8];
                    vram_input_data_1[1][9]<= rom_font_0[9];
                    vram_input_data_1[1][10]<= rom_font_0[10];
                    vram_input_data_1[1][11]<= rom_font_0[11];
                    vram_input_data_1[1][12]<= rom_font_0[12];
                    vram_input_data_1[1][13]<= rom_font_0[13];
                    vram_input_data_1[1][14]<= rom_font_0[14];
                    vram_input_data_1[1][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_1[1][0]<= rom_font_1[0];
                    vram_input_data_1[1][1]<= rom_font_1[1];
                    vram_input_data_1[1][2]<= rom_font_1[2];
                    vram_input_data_1[1][3]<= rom_font_1[3];
                    vram_input_data_1[1][4]<= rom_font_1[4];
                    vram_input_data_1[1][5]<= rom_font_1[5];
                    vram_input_data_1[1][6]<= rom_font_1[6];
                    vram_input_data_1[1][7]<= rom_font_1[7];
                    vram_input_data_1[1][8]<= rom_font_1[8];
                    vram_input_data_1[1][9]<= rom_font_1[9];
                    vram_input_data_1[1][10]<= rom_font_1[10];
                    vram_input_data_1[1][11]<= rom_font_1[11];
                    vram_input_data_1[1][12]<= rom_font_1[12];
                    vram_input_data_1[1][13]<= rom_font_1[13];
                    vram_input_data_1[1][14]<= rom_font_1[14];
                    vram_input_data_1[1][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_1[1][0]<= rom_font_2[0];
                    vram_input_data_1[1][1]<= rom_font_2[1];
                    vram_input_data_1[1][2]<= rom_font_2[2];
                    vram_input_data_1[1][3]<= rom_font_2[3];
                    vram_input_data_1[1][4]<= rom_font_2[4];
                    vram_input_data_1[1][5]<= rom_font_2[5];
                    vram_input_data_1[1][6]<= rom_font_2[6];
                    vram_input_data_1[1][7]<= rom_font_2[7];
                    vram_input_data_1[1][8]<= rom_font_2[8];
                    vram_input_data_1[1][9]<= rom_font_2[9];
                    vram_input_data_1[1][10]<= rom_font_2[10];
                    vram_input_data_1[1][11]<= rom_font_2[11];
                    vram_input_data_1[1][12]<= rom_font_2[12];
                    vram_input_data_1[1][13]<= rom_font_2[13];
                    vram_input_data_1[1][14]<= rom_font_2[14];
                    vram_input_data_1[1][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_1[1][0]<= rom_font_3[0];
                    vram_input_data_1[1][1]<= rom_font_3[1];
                    vram_input_data_1[1][2]<= rom_font_3[2];
                    vram_input_data_1[1][3]<= rom_font_3[3];
                    vram_input_data_1[1][4]<= rom_font_3[4];
                    vram_input_data_1[1][5]<= rom_font_3[5];
                    vram_input_data_1[1][6]<= rom_font_3[6];
                    vram_input_data_1[1][7]<= rom_font_3[7];
                    vram_input_data_1[1][8]<= rom_font_3[8];
                    vram_input_data_1[1][9]<= rom_font_3[9];
                    vram_input_data_1[1][10]<= rom_font_3[10];
                    vram_input_data_1[1][11]<= rom_font_3[11];
                    vram_input_data_1[1][12]<= rom_font_3[12];
                    vram_input_data_1[1][13]<= rom_font_3[13];
                    vram_input_data_1[1][14]<= rom_font_3[14];
                    vram_input_data_1[1][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_1[1][0]<= rom_font_4[0];
                    vram_input_data_1[1][1]<= rom_font_4[1];
                    vram_input_data_1[1][2]<= rom_font_4[2];
                    vram_input_data_1[1][3]<= rom_font_4[3];
                    vram_input_data_1[1][4]<= rom_font_4[4];
                    vram_input_data_1[1][5]<= rom_font_4[5];
                    vram_input_data_1[1][6]<= rom_font_4[6];
                    vram_input_data_1[1][7]<= rom_font_4[7];
                    vram_input_data_1[1][8]<= rom_font_4[8];
                    vram_input_data_1[1][9]<= rom_font_4[9];
                    vram_input_data_1[1][10]<= rom_font_4[10];
                    vram_input_data_1[1][11]<= rom_font_4[11];
                    vram_input_data_1[1][12]<= rom_font_4[12];
                    vram_input_data_1[1][13]<= rom_font_4[13];
                    vram_input_data_1[1][14]<= rom_font_4[14];
                    vram_input_data_1[1][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_1[1][0]<= rom_font_5[0];
                    vram_input_data_1[1][1]<= rom_font_5[1];
                    vram_input_data_1[1][2]<= rom_font_5[2];
                    vram_input_data_1[1][3]<= rom_font_5[3];
                    vram_input_data_1[1][4]<= rom_font_5[4];
                    vram_input_data_1[1][5]<= rom_font_5[5];
                    vram_input_data_1[1][6]<= rom_font_5[6];
                    vram_input_data_1[1][7]<= rom_font_5[7];
                    vram_input_data_1[1][8]<= rom_font_5[8];
                    vram_input_data_1[1][9]<= rom_font_5[9];
                    vram_input_data_1[1][10]<= rom_font_5[10];
                    vram_input_data_1[1][11]<= rom_font_5[11];
                    vram_input_data_1[1][12]<= rom_font_5[12];
                    vram_input_data_1[1][13]<= rom_font_5[13];
                    vram_input_data_1[1][14]<= rom_font_5[14];
                    vram_input_data_1[1][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_1[1][0]<= rom_font_6[0];
                    vram_input_data_1[1][1]<= rom_font_6[1];
                    vram_input_data_1[1][2]<= rom_font_6[2];
                    vram_input_data_1[1][3]<= rom_font_6[3];
                    vram_input_data_1[1][4]<= rom_font_6[4];
                    vram_input_data_1[1][5]<= rom_font_6[5];
                    vram_input_data_1[1][6]<= rom_font_6[6];
                    vram_input_data_1[1][7]<= rom_font_6[7];
                    vram_input_data_1[1][8]<= rom_font_6[8];
                    vram_input_data_1[1][9]<= rom_font_6[9];
                    vram_input_data_1[1][10]<= rom_font_6[10];
                    vram_input_data_1[1][11]<= rom_font_6[11];
                    vram_input_data_1[1][12]<= rom_font_6[12];
                    vram_input_data_1[1][13]<= rom_font_6[13];
                    vram_input_data_1[1][14]<= rom_font_6[14];
                    vram_input_data_1[1][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_1[1][0]<= rom_font_7[0];
                    vram_input_data_1[1][1]<= rom_font_7[1];
                    vram_input_data_1[1][2]<= rom_font_7[2];
                    vram_input_data_1[1][3]<= rom_font_7[3];
                    vram_input_data_1[1][4]<= rom_font_7[4];
                    vram_input_data_1[1][5]<= rom_font_7[5];
                    vram_input_data_1[1][6]<= rom_font_7[6];
                    vram_input_data_1[1][7]<= rom_font_7[7];
                    vram_input_data_1[1][8]<= rom_font_7[8];
                    vram_input_data_1[1][9]<= rom_font_7[9];
                    vram_input_data_1[1][10]<= rom_font_7[10];
                    vram_input_data_1[1][11]<= rom_font_7[11];
                    vram_input_data_1[1][12]<= rom_font_7[12];
                    vram_input_data_1[1][13]<= rom_font_7[13];
                    vram_input_data_1[1][14]<= rom_font_7[14];
                    vram_input_data_1[1][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_1[1][0]<= rom_font_8[0];
                    vram_input_data_1[1][1]<= rom_font_8[1];
                    vram_input_data_1[1][2]<= rom_font_8[2];
                    vram_input_data_1[1][3]<= rom_font_8[3];
                    vram_input_data_1[1][4]<= rom_font_8[4];
                    vram_input_data_1[1][5]<= rom_font_8[5];
                    vram_input_data_1[1][6]<= rom_font_8[6];
                    vram_input_data_1[1][7]<= rom_font_8[7];
                    vram_input_data_1[1][8]<= rom_font_8[8];
                    vram_input_data_1[1][9]<= rom_font_8[9];
                    vram_input_data_1[1][10]<= rom_font_8[10];
                    vram_input_data_1[1][11]<= rom_font_8[11];
                    vram_input_data_1[1][12]<= rom_font_8[12];
                    vram_input_data_1[1][13]<= rom_font_8[13];
                    vram_input_data_1[1][14]<= rom_font_8[14];
                    vram_input_data_1[1][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_1[1][0]<= rom_font_9[0];
                    vram_input_data_1[1][1]<= rom_font_9[1];
                    vram_input_data_1[1][2]<= rom_font_9[2];
                    vram_input_data_1[1][3]<= rom_font_9[3];
                    vram_input_data_1[1][4]<= rom_font_9[4];
                    vram_input_data_1[1][5]<= rom_font_9[5];
                    vram_input_data_1[1][6]<= rom_font_9[6];
                    vram_input_data_1[1][7]<= rom_font_9[7];
                    vram_input_data_1[1][8]<= rom_font_9[8];
                    vram_input_data_1[1][9]<= rom_font_9[9];
                    vram_input_data_1[1][10]<= rom_font_9[10];
                    vram_input_data_1[1][11]<= rom_font_9[11];
                    vram_input_data_1[1][12]<= rom_font_9[12];
                    vram_input_data_1[1][13]<= rom_font_9[13];
                    vram_input_data_1[1][14]<= rom_font_9[14];
                    vram_input_data_1[1][15]<= rom_font_9[15];
                end
            endcase case(user_data_f0 / 10000) // f0的万位
                24'd0 : begin
                    vram_input_data_1[0][0]<= rom_font_0[0];
                    vram_input_data_1[0][1]<= rom_font_0[1];
                    vram_input_data_1[0][2]<= rom_font_0[2];
                    vram_input_data_1[0][3]<= rom_font_0[3];
                    vram_input_data_1[0][4]<= rom_font_0[4];
                    vram_input_data_1[0][5]<= rom_font_0[5];
                    vram_input_data_1[0][6]<= rom_font_0[6];
                    vram_input_data_1[0][7]<= rom_font_0[7];
                    vram_input_data_1[0][8]<= rom_font_0[8];
                    vram_input_data_1[0][9]<= rom_font_0[9];
                    vram_input_data_1[0][10]<= rom_font_0[10];
                    vram_input_data_1[0][11]<= rom_font_0[11];
                    vram_input_data_1[0][12]<= rom_font_0[12];
                    vram_input_data_1[0][13]<= rom_font_0[13];
                    vram_input_data_1[0][14]<= rom_font_0[14];
                    vram_input_data_1[0][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_1[0][0]<= rom_font_1[0];
                    vram_input_data_1[0][1]<= rom_font_1[1];
                    vram_input_data_1[0][2]<= rom_font_1[2];
                    vram_input_data_1[0][3]<= rom_font_1[3];
                    vram_input_data_1[0][4]<= rom_font_1[4];
                    vram_input_data_1[0][5]<= rom_font_1[5];
                    vram_input_data_1[0][6]<= rom_font_1[6];
                    vram_input_data_1[0][7]<= rom_font_1[7];
                    vram_input_data_1[0][8]<= rom_font_1[8];
                    vram_input_data_1[0][9]<= rom_font_1[9];
                    vram_input_data_1[0][10]<= rom_font_1[10];
                    vram_input_data_1[0][11]<= rom_font_1[11];
                    vram_input_data_1[0][12]<= rom_font_1[12];
                    vram_input_data_1[0][13]<= rom_font_1[13];
                    vram_input_data_1[0][14]<= rom_font_1[14];
                    vram_input_data_1[0][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_1[0][0]<= rom_font_2[0];
                    vram_input_data_1[0][1]<= rom_font_2[1];
                    vram_input_data_1[0][2]<= rom_font_2[2];
                    vram_input_data_1[0][3]<= rom_font_2[3];
                    vram_input_data_1[0][4]<= rom_font_2[4];
                    vram_input_data_1[0][5]<= rom_font_2[5];
                    vram_input_data_1[0][6]<= rom_font_2[6];
                    vram_input_data_1[0][7]<= rom_font_2[7];
                    vram_input_data_1[0][8]<= rom_font_2[8];
                    vram_input_data_1[0][9]<= rom_font_2[9];
                    vram_input_data_1[0][10]<= rom_font_2[10];
                    vram_input_data_1[0][11]<= rom_font_2[11];
                    vram_input_data_1[0][12]<= rom_font_2[12];
                    vram_input_data_1[0][13]<= rom_font_2[13];
                    vram_input_data_1[0][14]<= rom_font_2[14];
                    vram_input_data_1[0][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_1[0][0]<= rom_font_3[0];
                    vram_input_data_1[0][1]<= rom_font_3[1];
                    vram_input_data_1[0][2]<= rom_font_3[2];
                    vram_input_data_1[0][3]<= rom_font_3[3];
                    vram_input_data_1[0][4]<= rom_font_3[4];
                    vram_input_data_1[0][5]<= rom_font_3[5];
                    vram_input_data_1[0][6]<= rom_font_3[6];
                    vram_input_data_1[0][7]<= rom_font_3[7];
                    vram_input_data_1[0][8]<= rom_font_3[8];
                    vram_input_data_1[0][9]<= rom_font_3[9];
                    vram_input_data_1[0][10]<= rom_font_3[10];
                    vram_input_data_1[0][11]<= rom_font_3[11];
                    vram_input_data_1[0][12]<= rom_font_3[12];
                    vram_input_data_1[0][13]<= rom_font_3[13];
                    vram_input_data_1[0][14]<= rom_font_3[14];
                    vram_input_data_1[0][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_1[0][0]<= rom_font_4[0];
                    vram_input_data_1[0][1]<= rom_font_4[1];
                    vram_input_data_1[0][2]<= rom_font_4[2];
                    vram_input_data_1[0][3]<= rom_font_4[3];
                    vram_input_data_1[0][4]<= rom_font_4[4];
                    vram_input_data_1[0][5]<= rom_font_4[5];
                    vram_input_data_1[0][6]<= rom_font_4[6];
                    vram_input_data_1[0][7]<= rom_font_4[7];
                    vram_input_data_1[0][8]<= rom_font_4[8];
                    vram_input_data_1[0][9]<= rom_font_4[9];
                    vram_input_data_1[0][10]<= rom_font_4[10];
                    vram_input_data_1[0][11]<= rom_font_4[11];
                    vram_input_data_1[0][12]<= rom_font_4[12];
                    vram_input_data_1[0][13]<= rom_font_4[13];
                    vram_input_data_1[0][14]<= rom_font_4[14];
                    vram_input_data_1[0][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_1[0][0]<= rom_font_5[0];
                    vram_input_data_1[0][1]<= rom_font_5[1];
                    vram_input_data_1[0][2]<= rom_font_5[2];
                    vram_input_data_1[0][3]<= rom_font_5[3];
                    vram_input_data_1[0][4]<= rom_font_5[4];
                    vram_input_data_1[0][5]<= rom_font_5[5];
                    vram_input_data_1[0][6]<= rom_font_5[6];
                    vram_input_data_1[0][7]<= rom_font_5[7];
                    vram_input_data_1[0][8]<= rom_font_5[8];
                    vram_input_data_1[0][9]<= rom_font_5[9];
                    vram_input_data_1[0][10]<= rom_font_5[10];
                    vram_input_data_1[0][11]<= rom_font_5[11];
                    vram_input_data_1[0][12]<= rom_font_5[12];
                    vram_input_data_1[0][13]<= rom_font_5[13];
                    vram_input_data_1[0][14]<= rom_font_5[14];
                    vram_input_data_1[0][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_1[0][0]<= rom_font_6[0];
                    vram_input_data_1[0][1]<= rom_font_6[1];
                    vram_input_data_1[0][2]<= rom_font_6[2];
                    vram_input_data_1[0][3]<= rom_font_6[3];
                    vram_input_data_1[0][4]<= rom_font_6[4];
                    vram_input_data_1[0][5]<= rom_font_6[5];
                    vram_input_data_1[0][6]<= rom_font_6[6];
                    vram_input_data_1[0][7]<= rom_font_6[7];
                    vram_input_data_1[0][8]<= rom_font_6[8];
                    vram_input_data_1[0][9]<= rom_font_6[9];
                    vram_input_data_1[0][10]<= rom_font_6[10];
                    vram_input_data_1[0][11]<= rom_font_6[11];
                    vram_input_data_1[0][12]<= rom_font_6[12];
                    vram_input_data_1[0][13]<= rom_font_6[13];
                    vram_input_data_1[0][14]<= rom_font_6[14];
                    vram_input_data_1[0][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_1[0][0]<= rom_font_7[0];
                    vram_input_data_1[0][1]<= rom_font_7[1];
                    vram_input_data_1[0][2]<= rom_font_7[2];
                    vram_input_data_1[0][3]<= rom_font_7[3];
                    vram_input_data_1[0][4]<= rom_font_7[4];
                    vram_input_data_1[0][5]<= rom_font_7[5];
                    vram_input_data_1[0][6]<= rom_font_7[6];
                    vram_input_data_1[0][7]<= rom_font_7[7];
                    vram_input_data_1[0][8]<= rom_font_7[8];
                    vram_input_data_1[0][9]<= rom_font_7[9];
                    vram_input_data_1[0][10]<= rom_font_7[10];
                    vram_input_data_1[0][11]<= rom_font_7[11];
                    vram_input_data_1[0][12]<= rom_font_7[12];
                    vram_input_data_1[0][13]<= rom_font_7[13];
                    vram_input_data_1[0][14]<= rom_font_7[14];
                    vram_input_data_1[0][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_1[0][0]<= rom_font_8[0];
                    vram_input_data_1[0][1]<= rom_font_8[1];
                    vram_input_data_1[0][2]<= rom_font_8[2];
                    vram_input_data_1[0][3]<= rom_font_8[3];
                    vram_input_data_1[0][4]<= rom_font_8[4];
                    vram_input_data_1[0][5]<= rom_font_8[5];
                    vram_input_data_1[0][6]<= rom_font_8[6];
                    vram_input_data_1[0][7]<= rom_font_8[7];
                    vram_input_data_1[0][8]<= rom_font_8[8];
                    vram_input_data_1[0][9]<= rom_font_8[9];
                    vram_input_data_1[0][10]<= rom_font_8[10];
                    vram_input_data_1[0][11]<= rom_font_8[11];
                    vram_input_data_1[0][12]<= rom_font_8[12];
                    vram_input_data_1[0][13]<= rom_font_8[13];
                    vram_input_data_1[0][14]<= rom_font_8[14];
                    vram_input_data_1[0][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_1[0][0]<= rom_font_9[0];
                    vram_input_data_1[0][1]<= rom_font_9[1];
                    vram_input_data_1[0][2]<= rom_font_9[2];
                    vram_input_data_1[0][3]<= rom_font_9[3];
                    vram_input_data_1[0][4]<= rom_font_9[4];
                    vram_input_data_1[0][5]<= rom_font_9[5];
                    vram_input_data_1[0][6]<= rom_font_9[6];
                    vram_input_data_1[0][7]<= rom_font_9[7];
                    vram_input_data_1[0][8]<= rom_font_9[8];
                    vram_input_data_1[0][9]<= rom_font_9[9];
                    vram_input_data_1[0][10]<= rom_font_9[10];
                    vram_input_data_1[0][11]<= rom_font_9[11];
                    vram_input_data_1[0][12]<= rom_font_9[12];
                    vram_input_data_1[0][13]<= rom_font_9[13];
                    vram_input_data_1[0][14]<= rom_font_9[14];
                    vram_input_data_1[0][15]<= rom_font_9[15];
                end
            endcase 
            //------------------------------------------------------//
            case(user_data_fl % 10) // fl的个位
                24'd0 : begin
                    vram_input_data_2[4][0]<= rom_font_0[0];
                    vram_input_data_2[4][1]<= rom_font_0[1];
                    vram_input_data_2[4][2]<= rom_font_0[2];
                    vram_input_data_2[4][3]<= rom_font_0[3];
                    vram_input_data_2[4][4]<= rom_font_0[4];
                    vram_input_data_2[4][5]<= rom_font_0[5];
                    vram_input_data_2[4][6]<= rom_font_0[6];
                    vram_input_data_2[4][7]<= rom_font_0[7];
                    vram_input_data_2[4][8]<= rom_font_0[8];
                    vram_input_data_2[4][9]<= rom_font_0[9];
                    vram_input_data_2[4][10]<= rom_font_0[10];
                    vram_input_data_2[4][11]<= rom_font_0[11];
                    vram_input_data_2[4][12]<= rom_font_0[12];
                    vram_input_data_2[4][13]<= rom_font_0[13];
                    vram_input_data_2[4][14]<= rom_font_0[14];
                    vram_input_data_2[4][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_2[4][0]<= rom_font_1[0];
                    vram_input_data_2[4][1]<= rom_font_1[1];
                    vram_input_data_2[4][2]<= rom_font_1[2];
                    vram_input_data_2[4][3]<= rom_font_1[3];
                    vram_input_data_2[4][4]<= rom_font_1[4];
                    vram_input_data_2[4][5]<= rom_font_1[5];
                    vram_input_data_2[4][6]<= rom_font_1[6];
                    vram_input_data_2[4][7]<= rom_font_1[7];
                    vram_input_data_2[4][8]<= rom_font_1[8];
                    vram_input_data_2[4][9]<= rom_font_1[9];
                    vram_input_data_2[4][10]<= rom_font_1[10];
                    vram_input_data_2[4][11]<= rom_font_1[11];
                    vram_input_data_2[4][12]<= rom_font_1[12];
                    vram_input_data_2[4][13]<= rom_font_1[13];
                    vram_input_data_2[4][14]<= rom_font_1[14];
                    vram_input_data_2[4][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_2[4][0]<= rom_font_2[0];
                    vram_input_data_2[4][1]<= rom_font_2[1];
                    vram_input_data_2[4][2]<= rom_font_2[2];
                    vram_input_data_2[4][3]<= rom_font_2[3];
                    vram_input_data_2[4][4]<= rom_font_2[4];
                    vram_input_data_2[4][5]<= rom_font_2[5];
                    vram_input_data_2[4][6]<= rom_font_2[6];
                    vram_input_data_2[4][7]<= rom_font_2[7];
                    vram_input_data_2[4][8]<= rom_font_2[8];
                    vram_input_data_2[4][9]<= rom_font_2[9];
                    vram_input_data_2[4][10]<= rom_font_2[10];
                    vram_input_data_2[4][11]<= rom_font_2[11];
                    vram_input_data_2[4][12]<= rom_font_2[12];
                    vram_input_data_2[4][13]<= rom_font_2[13];
                    vram_input_data_2[4][14]<= rom_font_2[14];
                    vram_input_data_2[4][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_2[4][0]<= rom_font_3[0];
                    vram_input_data_2[4][1]<= rom_font_3[1];
                    vram_input_data_2[4][2]<= rom_font_3[2];
                    vram_input_data_2[4][3]<= rom_font_3[3];
                    vram_input_data_2[4][4]<= rom_font_3[4];
                    vram_input_data_2[4][5]<= rom_font_3[5];
                    vram_input_data_2[4][6]<= rom_font_3[6];
                    vram_input_data_2[4][7]<= rom_font_3[7];
                    vram_input_data_2[4][8]<= rom_font_3[8];
                    vram_input_data_2[4][9]<= rom_font_3[9];
                    vram_input_data_2[4][10]<= rom_font_3[10];
                    vram_input_data_2[4][11]<= rom_font_3[11];
                    vram_input_data_2[4][12]<= rom_font_3[12];
                    vram_input_data_2[4][13]<= rom_font_3[13];
                    vram_input_data_2[4][14]<= rom_font_3[14];
                    vram_input_data_2[4][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_2[4][0]<= rom_font_4[0];
                    vram_input_data_2[4][1]<= rom_font_4[1];
                    vram_input_data_2[4][2]<= rom_font_4[2];
                    vram_input_data_2[4][3]<= rom_font_4[3];
                    vram_input_data_2[4][4]<= rom_font_4[4];
                    vram_input_data_2[4][5]<= rom_font_4[5];
                    vram_input_data_2[4][6]<= rom_font_4[6];
                    vram_input_data_2[4][7]<= rom_font_4[7];
                    vram_input_data_2[4][8]<= rom_font_4[8];
                    vram_input_data_2[4][9]<= rom_font_4[9];
                    vram_input_data_2[4][10]<= rom_font_4[10];
                    vram_input_data_2[4][11]<= rom_font_4[11];
                    vram_input_data_2[4][12]<= rom_font_4[12];
                    vram_input_data_2[4][13]<= rom_font_4[13];
                    vram_input_data_2[4][14]<= rom_font_4[14];
                    vram_input_data_2[4][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_2[4][0]<= rom_font_5[0];
                    vram_input_data_2[4][1]<= rom_font_5[1];
                    vram_input_data_2[4][2]<= rom_font_5[2];
                    vram_input_data_2[4][3]<= rom_font_5[3];
                    vram_input_data_2[4][4]<= rom_font_5[4];
                    vram_input_data_2[4][5]<= rom_font_5[5];
                    vram_input_data_2[4][6]<= rom_font_5[6];
                    vram_input_data_2[4][7]<= rom_font_5[7];
                    vram_input_data_2[4][8]<= rom_font_5[8];
                    vram_input_data_2[4][9]<= rom_font_5[9];
                    vram_input_data_2[4][10]<= rom_font_5[10];
                    vram_input_data_2[4][11]<= rom_font_5[11];
                    vram_input_data_2[4][12]<= rom_font_5[12];
                    vram_input_data_2[4][13]<= rom_font_5[13];
                    vram_input_data_2[4][14]<= rom_font_5[14];
                    vram_input_data_2[4][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_2[4][0]<= rom_font_6[0];
                    vram_input_data_2[4][1]<= rom_font_6[1];
                    vram_input_data_2[4][2]<= rom_font_6[2];
                    vram_input_data_2[4][3]<= rom_font_6[3];
                    vram_input_data_2[4][4]<= rom_font_6[4];
                    vram_input_data_2[4][5]<= rom_font_6[5];
                    vram_input_data_2[4][6]<= rom_font_6[6];
                    vram_input_data_2[4][7]<= rom_font_6[7];
                    vram_input_data_2[4][8]<= rom_font_6[8];
                    vram_input_data_2[4][9]<= rom_font_6[9];
                    vram_input_data_2[4][10]<= rom_font_6[10];
                    vram_input_data_2[4][11]<= rom_font_6[11];
                    vram_input_data_2[4][12]<= rom_font_6[12];
                    vram_input_data_2[4][13]<= rom_font_6[13];
                    vram_input_data_2[4][14]<= rom_font_6[14];
                    vram_input_data_2[4][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_2[4][0]<= rom_font_7[0];
                    vram_input_data_2[4][1]<= rom_font_7[1];
                    vram_input_data_2[4][2]<= rom_font_7[2];
                    vram_input_data_2[4][3]<= rom_font_7[3];
                    vram_input_data_2[4][4]<= rom_font_7[4];
                    vram_input_data_2[4][5]<= rom_font_7[5];
                    vram_input_data_2[4][6]<= rom_font_7[6];
                    vram_input_data_2[4][7]<= rom_font_7[7];
                    vram_input_data_2[4][8]<= rom_font_7[8];
                    vram_input_data_2[4][9]<= rom_font_7[9];
                    vram_input_data_2[4][10]<= rom_font_7[10];
                    vram_input_data_2[4][11]<= rom_font_7[11];
                    vram_input_data_2[4][12]<= rom_font_7[12];
                    vram_input_data_2[4][13]<= rom_font_7[13];
                    vram_input_data_2[4][14]<= rom_font_7[14];
                    vram_input_data_2[4][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_2[4][0]<= rom_font_8[0];
                    vram_input_data_2[4][1]<= rom_font_8[1];
                    vram_input_data_2[4][2]<= rom_font_8[2];
                    vram_input_data_2[4][3]<= rom_font_8[3];
                    vram_input_data_2[4][4]<= rom_font_8[4];
                    vram_input_data_2[4][5]<= rom_font_8[5];
                    vram_input_data_2[4][6]<= rom_font_8[6];
                    vram_input_data_2[4][7]<= rom_font_8[7];
                    vram_input_data_2[4][8]<= rom_font_8[8];
                    vram_input_data_2[4][9]<= rom_font_8[9];
                    vram_input_data_2[4][10]<= rom_font_8[10];
                    vram_input_data_2[4][11]<= rom_font_8[11];
                    vram_input_data_2[4][12]<= rom_font_8[12];
                    vram_input_data_2[4][13]<= rom_font_8[13];
                    vram_input_data_2[4][14]<= rom_font_8[14];
                    vram_input_data_2[4][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_2[4][0]<= rom_font_9[0];
                    vram_input_data_2[4][1]<= rom_font_9[1];
                    vram_input_data_2[4][2]<= rom_font_9[2];
                    vram_input_data_2[4][3]<= rom_font_9[3];
                    vram_input_data_2[4][4]<= rom_font_9[4];
                    vram_input_data_2[4][5]<= rom_font_9[5];
                    vram_input_data_2[4][6]<= rom_font_9[6];
                    vram_input_data_2[4][7]<= rom_font_9[7];
                    vram_input_data_2[4][8]<= rom_font_9[8];
                    vram_input_data_2[4][9]<= rom_font_9[9];
                    vram_input_data_2[4][10]<= rom_font_9[10];
                    vram_input_data_2[4][11]<= rom_font_9[11];
                    vram_input_data_2[4][12]<= rom_font_9[12];
                    vram_input_data_2[4][13]<= rom_font_9[13];
                    vram_input_data_2[4][14]<= rom_font_9[14];
                    vram_input_data_2[4][15]<= rom_font_9[15];
                end
            endcase case((user_data_fl % 100) / 10) // fl的十位
                24'd0 : begin
                    vram_input_data_2[3][0]<= rom_font_0[0];
                    vram_input_data_2[3][1]<= rom_font_0[1];
                    vram_input_data_2[3][2]<= rom_font_0[2];
                    vram_input_data_2[3][3]<= rom_font_0[3];
                    vram_input_data_2[3][4]<= rom_font_0[4];
                    vram_input_data_2[3][5]<= rom_font_0[5];
                    vram_input_data_2[3][6]<= rom_font_0[6];
                    vram_input_data_2[3][7]<= rom_font_0[7];
                    vram_input_data_2[3][8]<= rom_font_0[8];
                    vram_input_data_2[3][9]<= rom_font_0[9];
                    vram_input_data_2[3][10]<= rom_font_0[10];
                    vram_input_data_2[3][11]<= rom_font_0[11];
                    vram_input_data_2[3][12]<= rom_font_0[12];
                    vram_input_data_2[3][13]<= rom_font_0[13];
                    vram_input_data_2[3][14]<= rom_font_0[14];
                    vram_input_data_2[3][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_2[3][0]<= rom_font_1[0];
                    vram_input_data_2[3][1]<= rom_font_1[1];
                    vram_input_data_2[3][2]<= rom_font_1[2];
                    vram_input_data_2[3][3]<= rom_font_1[3];
                    vram_input_data_2[3][4]<= rom_font_1[4];
                    vram_input_data_2[3][5]<= rom_font_1[5];
                    vram_input_data_2[3][6]<= rom_font_1[6];
                    vram_input_data_2[3][7]<= rom_font_1[7];
                    vram_input_data_2[3][8]<= rom_font_1[8];
                    vram_input_data_2[3][9]<= rom_font_1[9];
                    vram_input_data_2[3][10]<= rom_font_1[10];
                    vram_input_data_2[3][11]<= rom_font_1[11];
                    vram_input_data_2[3][12]<= rom_font_1[12];
                    vram_input_data_2[3][13]<= rom_font_1[13];
                    vram_input_data_2[3][14]<= rom_font_1[14];
                    vram_input_data_2[3][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_2[3][0]<= rom_font_2[0];
                    vram_input_data_2[3][1]<= rom_font_2[1];
                    vram_input_data_2[3][2]<= rom_font_2[2];
                    vram_input_data_2[3][3]<= rom_font_2[3];
                    vram_input_data_2[3][4]<= rom_font_2[4];
                    vram_input_data_2[3][5]<= rom_font_2[5];
                    vram_input_data_2[3][6]<= rom_font_2[6];
                    vram_input_data_2[3][7]<= rom_font_2[7];
                    vram_input_data_2[3][8]<= rom_font_2[8];
                    vram_input_data_2[3][9]<= rom_font_2[9];
                    vram_input_data_2[3][10]<= rom_font_2[10];
                    vram_input_data_2[3][11]<= rom_font_2[11];
                    vram_input_data_2[3][12]<= rom_font_2[12];
                    vram_input_data_2[3][13]<= rom_font_2[13];
                    vram_input_data_2[3][14]<= rom_font_2[14];
                    vram_input_data_2[3][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_2[3][0]<= rom_font_3[0];
                    vram_input_data_2[3][1]<= rom_font_3[1];
                    vram_input_data_2[3][2]<= rom_font_3[2];
                    vram_input_data_2[3][3]<= rom_font_3[3];
                    vram_input_data_2[3][4]<= rom_font_3[4];
                    vram_input_data_2[3][5]<= rom_font_3[5];
                    vram_input_data_2[3][6]<= rom_font_3[6];
                    vram_input_data_2[3][7]<= rom_font_3[7];
                    vram_input_data_2[3][8]<= rom_font_3[8];
                    vram_input_data_2[3][9]<= rom_font_3[9];
                    vram_input_data_2[3][10]<= rom_font_3[10];
                    vram_input_data_2[3][11]<= rom_font_3[11];
                    vram_input_data_2[3][12]<= rom_font_3[12];
                    vram_input_data_2[3][13]<= rom_font_3[13];
                    vram_input_data_2[3][14]<= rom_font_3[14];
                    vram_input_data_2[3][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_2[3][0]<= rom_font_4[0];
                    vram_input_data_2[3][1]<= rom_font_4[1];
                    vram_input_data_2[3][2]<= rom_font_4[2];
                    vram_input_data_2[3][3]<= rom_font_4[3];
                    vram_input_data_2[3][4]<= rom_font_4[4];
                    vram_input_data_2[3][5]<= rom_font_4[5];
                    vram_input_data_2[3][6]<= rom_font_4[6];
                    vram_input_data_2[3][7]<= rom_font_4[7];
                    vram_input_data_2[3][8]<= rom_font_4[8];
                    vram_input_data_2[3][9]<= rom_font_4[9];
                    vram_input_data_2[3][10]<= rom_font_4[10];
                    vram_input_data_2[3][11]<= rom_font_4[11];
                    vram_input_data_2[3][12]<= rom_font_4[12];
                    vram_input_data_2[3][13]<= rom_font_4[13];
                    vram_input_data_2[3][14]<= rom_font_4[14];
                    vram_input_data_2[3][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_2[3][0]<= rom_font_5[0];
                    vram_input_data_2[3][1]<= rom_font_5[1];
                    vram_input_data_2[3][2]<= rom_font_5[2];
                    vram_input_data_2[3][3]<= rom_font_5[3];
                    vram_input_data_2[3][4]<= rom_font_5[4];
                    vram_input_data_2[3][5]<= rom_font_5[5];
                    vram_input_data_2[3][6]<= rom_font_5[6];
                    vram_input_data_2[3][7]<= rom_font_5[7];
                    vram_input_data_2[3][8]<= rom_font_5[8];
                    vram_input_data_2[3][9]<= rom_font_5[9];
                    vram_input_data_2[3][10]<= rom_font_5[10];
                    vram_input_data_2[3][11]<= rom_font_5[11];
                    vram_input_data_2[3][12]<= rom_font_5[12];
                    vram_input_data_2[3][13]<= rom_font_5[13];
                    vram_input_data_2[3][14]<= rom_font_5[14];
                    vram_input_data_2[3][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_2[3][0]<= rom_font_6[0];
                    vram_input_data_2[3][1]<= rom_font_6[1];
                    vram_input_data_2[3][2]<= rom_font_6[2];
                    vram_input_data_2[3][3]<= rom_font_6[3];
                    vram_input_data_2[3][4]<= rom_font_6[4];
                    vram_input_data_2[3][5]<= rom_font_6[5];
                    vram_input_data_2[3][6]<= rom_font_6[6];
                    vram_input_data_2[3][7]<= rom_font_6[7];
                    vram_input_data_2[3][8]<= rom_font_6[8];
                    vram_input_data_2[3][9]<= rom_font_6[9];
                    vram_input_data_2[3][10]<= rom_font_6[10];
                    vram_input_data_2[3][11]<= rom_font_6[11];
                    vram_input_data_2[3][12]<= rom_font_6[12];
                    vram_input_data_2[3][13]<= rom_font_6[13];
                    vram_input_data_2[3][14]<= rom_font_6[14];
                    vram_input_data_2[3][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_2[3][0]<= rom_font_7[0];
                    vram_input_data_2[3][1]<= rom_font_7[1];
                    vram_input_data_2[3][2]<= rom_font_7[2];
                    vram_input_data_2[3][3]<= rom_font_7[3];
                    vram_input_data_2[3][4]<= rom_font_7[4];
                    vram_input_data_2[3][5]<= rom_font_7[5];
                    vram_input_data_2[3][6]<= rom_font_7[6];
                    vram_input_data_2[3][7]<= rom_font_7[7];
                    vram_input_data_2[3][8]<= rom_font_7[8];
                    vram_input_data_2[3][9]<= rom_font_7[9];
                    vram_input_data_2[3][10]<= rom_font_7[10];
                    vram_input_data_2[3][11]<= rom_font_7[11];
                    vram_input_data_2[3][12]<= rom_font_7[12];
                    vram_input_data_2[3][13]<= rom_font_7[13];
                    vram_input_data_2[3][14]<= rom_font_7[14];
                    vram_input_data_2[3][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_2[3][0]<= rom_font_8[0];
                    vram_input_data_2[3][1]<= rom_font_8[1];
                    vram_input_data_2[3][2]<= rom_font_8[2];
                    vram_input_data_2[3][3]<= rom_font_8[3];
                    vram_input_data_2[3][4]<= rom_font_8[4];
                    vram_input_data_2[3][5]<= rom_font_8[5];
                    vram_input_data_2[3][6]<= rom_font_8[6];
                    vram_input_data_2[3][7]<= rom_font_8[7];
                    vram_input_data_2[3][8]<= rom_font_8[8];
                    vram_input_data_2[3][9]<= rom_font_8[9];
                    vram_input_data_2[3][10]<= rom_font_8[10];
                    vram_input_data_2[3][11]<= rom_font_8[11];
                    vram_input_data_2[3][12]<= rom_font_8[12];
                    vram_input_data_2[3][13]<= rom_font_8[13];
                    vram_input_data_2[3][14]<= rom_font_8[14];
                    vram_input_data_2[3][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_2[3][0]<= rom_font_9[0];
                    vram_input_data_2[3][1]<= rom_font_9[1];
                    vram_input_data_2[3][2]<= rom_font_9[2];
                    vram_input_data_2[3][3]<= rom_font_9[3];
                    vram_input_data_2[3][4]<= rom_font_9[4];
                    vram_input_data_2[3][5]<= rom_font_9[5];
                    vram_input_data_2[3][6]<= rom_font_9[6];
                    vram_input_data_2[3][7]<= rom_font_9[7];
                    vram_input_data_2[3][8]<= rom_font_9[8];
                    vram_input_data_2[3][9]<= rom_font_9[9];
                    vram_input_data_2[3][10]<= rom_font_9[10];
                    vram_input_data_2[3][11]<= rom_font_9[11];
                    vram_input_data_2[3][12]<= rom_font_9[12];
                    vram_input_data_2[3][13]<= rom_font_9[13];
                    vram_input_data_2[3][14]<= rom_font_9[14];
                    vram_input_data_2[3][15]<= rom_font_9[15];
                end
            endcase case((user_data_fl % 1000) / 100) // fl的百位
                24'd0 : begin
                    vram_input_data_2[2][0]<= rom_font_0[0];
                    vram_input_data_2[2][1]<= rom_font_0[1];
                    vram_input_data_2[2][2]<= rom_font_0[2];
                    vram_input_data_2[2][3]<= rom_font_0[3];
                    vram_input_data_2[2][4]<= rom_font_0[4];
                    vram_input_data_2[2][5]<= rom_font_0[5];
                    vram_input_data_2[2][6]<= rom_font_0[6];
                    vram_input_data_2[2][7]<= rom_font_0[7];
                    vram_input_data_2[2][8]<= rom_font_0[8];
                    vram_input_data_2[2][9]<= rom_font_0[9];
                    vram_input_data_2[2][10]<= rom_font_0[10];
                    vram_input_data_2[2][11]<= rom_font_0[11];
                    vram_input_data_2[2][12]<= rom_font_0[12];
                    vram_input_data_2[2][13]<= rom_font_0[13];
                    vram_input_data_2[2][14]<= rom_font_0[14];
                    vram_input_data_2[2][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_2[2][0]<= rom_font_1[0];
                    vram_input_data_2[2][1]<= rom_font_1[1];
                    vram_input_data_2[2][2]<= rom_font_1[2];
                    vram_input_data_2[2][3]<= rom_font_1[3];
                    vram_input_data_2[2][4]<= rom_font_1[4];
                    vram_input_data_2[2][5]<= rom_font_1[5];
                    vram_input_data_2[2][6]<= rom_font_1[6];
                    vram_input_data_2[2][7]<= rom_font_1[7];
                    vram_input_data_2[2][8]<= rom_font_1[8];
                    vram_input_data_2[2][9]<= rom_font_1[9];
                    vram_input_data_2[2][10]<= rom_font_1[10];
                    vram_input_data_2[2][11]<= rom_font_1[11];
                    vram_input_data_2[2][12]<= rom_font_1[12];
                    vram_input_data_2[2][13]<= rom_font_1[13];
                    vram_input_data_2[2][14]<= rom_font_1[14];
                    vram_input_data_2[2][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_2[2][0]<= rom_font_2[0];
                    vram_input_data_2[2][1]<= rom_font_2[1];
                    vram_input_data_2[2][2]<= rom_font_2[2];
                    vram_input_data_2[2][3]<= rom_font_2[3];
                    vram_input_data_2[2][4]<= rom_font_2[4];
                    vram_input_data_2[2][5]<= rom_font_2[5];
                    vram_input_data_2[2][6]<= rom_font_2[6];
                    vram_input_data_2[2][7]<= rom_font_2[7];
                    vram_input_data_2[2][8]<= rom_font_2[8];
                    vram_input_data_2[2][9]<= rom_font_2[9];
                    vram_input_data_2[2][10]<= rom_font_2[10];
                    vram_input_data_2[2][11]<= rom_font_2[11];
                    vram_input_data_2[2][12]<= rom_font_2[12];
                    vram_input_data_2[2][13]<= rom_font_2[13];
                    vram_input_data_2[2][14]<= rom_font_2[14];
                    vram_input_data_2[2][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_2[2][0]<= rom_font_3[0];
                    vram_input_data_2[2][1]<= rom_font_3[1];
                    vram_input_data_2[2][2]<= rom_font_3[2];
                    vram_input_data_2[2][3]<= rom_font_3[3];
                    vram_input_data_2[2][4]<= rom_font_3[4];
                    vram_input_data_2[2][5]<= rom_font_3[5];
                    vram_input_data_2[2][6]<= rom_font_3[6];
                    vram_input_data_2[2][7]<= rom_font_3[7];
                    vram_input_data_2[2][8]<= rom_font_3[8];
                    vram_input_data_2[2][9]<= rom_font_3[9];
                    vram_input_data_2[2][10]<= rom_font_3[10];
                    vram_input_data_2[2][11]<= rom_font_3[11];
                    vram_input_data_2[2][12]<= rom_font_3[12];
                    vram_input_data_2[2][13]<= rom_font_3[13];
                    vram_input_data_2[2][14]<= rom_font_3[14];
                    vram_input_data_2[2][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_2[2][0]<= rom_font_4[0];
                    vram_input_data_2[2][1]<= rom_font_4[1];
                    vram_input_data_2[2][2]<= rom_font_4[2];
                    vram_input_data_2[2][3]<= rom_font_4[3];
                    vram_input_data_2[2][4]<= rom_font_4[4];
                    vram_input_data_2[2][5]<= rom_font_4[5];
                    vram_input_data_2[2][6]<= rom_font_4[6];
                    vram_input_data_2[2][7]<= rom_font_4[7];
                    vram_input_data_2[2][8]<= rom_font_4[8];
                    vram_input_data_2[2][9]<= rom_font_4[9];
                    vram_input_data_2[2][10]<= rom_font_4[10];
                    vram_input_data_2[2][11]<= rom_font_4[11];
                    vram_input_data_2[2][12]<= rom_font_4[12];
                    vram_input_data_2[2][13]<= rom_font_4[13];
                    vram_input_data_2[2][14]<= rom_font_4[14];
                    vram_input_data_2[2][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_2[2][0]<= rom_font_5[0];
                    vram_input_data_2[2][1]<= rom_font_5[1];
                    vram_input_data_2[2][2]<= rom_font_5[2];
                    vram_input_data_2[2][3]<= rom_font_5[3];
                    vram_input_data_2[2][4]<= rom_font_5[4];
                    vram_input_data_2[2][5]<= rom_font_5[5];
                    vram_input_data_2[2][6]<= rom_font_5[6];
                    vram_input_data_2[2][7]<= rom_font_5[7];
                    vram_input_data_2[2][8]<= rom_font_5[8];
                    vram_input_data_2[2][9]<= rom_font_5[9];
                    vram_input_data_2[2][10]<= rom_font_5[10];
                    vram_input_data_2[2][11]<= rom_font_5[11];
                    vram_input_data_2[2][12]<= rom_font_5[12];
                    vram_input_data_2[2][13]<= rom_font_5[13];
                    vram_input_data_2[2][14]<= rom_font_5[14];
                    vram_input_data_2[2][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_2[2][0]<= rom_font_6[0];
                    vram_input_data_2[2][1]<= rom_font_6[1];
                    vram_input_data_2[2][2]<= rom_font_6[2];
                    vram_input_data_2[2][3]<= rom_font_6[3];
                    vram_input_data_2[2][4]<= rom_font_6[4];
                    vram_input_data_2[2][5]<= rom_font_6[5];
                    vram_input_data_2[2][6]<= rom_font_6[6];
                    vram_input_data_2[2][7]<= rom_font_6[7];
                    vram_input_data_2[2][8]<= rom_font_6[8];
                    vram_input_data_2[2][9]<= rom_font_6[9];
                    vram_input_data_2[2][10]<= rom_font_6[10];
                    vram_input_data_2[2][11]<= rom_font_6[11];
                    vram_input_data_2[2][12]<= rom_font_6[12];
                    vram_input_data_2[2][13]<= rom_font_6[13];
                    vram_input_data_2[2][14]<= rom_font_6[14];
                    vram_input_data_2[2][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_2[2][0]<= rom_font_7[0];
                    vram_input_data_2[2][1]<= rom_font_7[1];
                    vram_input_data_2[2][2]<= rom_font_7[2];
                    vram_input_data_2[2][3]<= rom_font_7[3];
                    vram_input_data_2[2][4]<= rom_font_7[4];
                    vram_input_data_2[2][5]<= rom_font_7[5];
                    vram_input_data_2[2][6]<= rom_font_7[6];
                    vram_input_data_2[2][7]<= rom_font_7[7];
                    vram_input_data_2[2][8]<= rom_font_7[8];
                    vram_input_data_2[2][9]<= rom_font_7[9];
                    vram_input_data_2[2][10]<= rom_font_7[10];
                    vram_input_data_2[2][11]<= rom_font_7[11];
                    vram_input_data_2[2][12]<= rom_font_7[12];
                    vram_input_data_2[2][13]<= rom_font_7[13];
                    vram_input_data_2[2][14]<= rom_font_7[14];
                    vram_input_data_2[2][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_2[2][0]<= rom_font_8[0];
                    vram_input_data_2[2][1]<= rom_font_8[1];
                    vram_input_data_2[2][2]<= rom_font_8[2];
                    vram_input_data_2[2][3]<= rom_font_8[3];
                    vram_input_data_2[2][4]<= rom_font_8[4];
                    vram_input_data_2[2][5]<= rom_font_8[5];
                    vram_input_data_2[2][6]<= rom_font_8[6];
                    vram_input_data_2[2][7]<= rom_font_8[7];
                    vram_input_data_2[2][8]<= rom_font_8[8];
                    vram_input_data_2[2][9]<= rom_font_8[9];
                    vram_input_data_2[2][10]<= rom_font_8[10];
                    vram_input_data_2[2][11]<= rom_font_8[11];
                    vram_input_data_2[2][12]<= rom_font_8[12];
                    vram_input_data_2[2][13]<= rom_font_8[13];
                    vram_input_data_2[2][14]<= rom_font_8[14];
                    vram_input_data_2[2][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_2[2][0]<= rom_font_9[0];
                    vram_input_data_2[2][1]<= rom_font_9[1];
                    vram_input_data_2[2][2]<= rom_font_9[2];
                    vram_input_data_2[2][3]<= rom_font_9[3];
                    vram_input_data_2[2][4]<= rom_font_9[4];
                    vram_input_data_2[2][5]<= rom_font_9[5];
                    vram_input_data_2[2][6]<= rom_font_9[6];
                    vram_input_data_2[2][7]<= rom_font_9[7];
                    vram_input_data_2[2][8]<= rom_font_9[8];
                    vram_input_data_2[2][9]<= rom_font_9[9];
                    vram_input_data_2[2][10]<= rom_font_9[10];
                    vram_input_data_2[2][11]<= rom_font_9[11];
                    vram_input_data_2[2][12]<= rom_font_9[12];
                    vram_input_data_2[2][13]<= rom_font_9[13];
                    vram_input_data_2[2][14]<= rom_font_9[14];
                    vram_input_data_2[2][15]<= rom_font_9[15];
                end
            endcase case((user_data_fl % 10000) / 1000) // fl的千位
                24'd0 : begin
                    vram_input_data_2[1][0]<= rom_font_0[0];
                    vram_input_data_2[1][1]<= rom_font_0[1];
                    vram_input_data_2[1][2]<= rom_font_0[2];
                    vram_input_data_2[1][3]<= rom_font_0[3];
                    vram_input_data_2[1][4]<= rom_font_0[4];
                    vram_input_data_2[1][5]<= rom_font_0[5];
                    vram_input_data_2[1][6]<= rom_font_0[6];
                    vram_input_data_2[1][7]<= rom_font_0[7];
                    vram_input_data_2[1][8]<= rom_font_0[8];
                    vram_input_data_2[1][9]<= rom_font_0[9];
                    vram_input_data_2[1][10]<= rom_font_0[10];
                    vram_input_data_2[1][11]<= rom_font_0[11];
                    vram_input_data_2[1][12]<= rom_font_0[12];
                    vram_input_data_2[1][13]<= rom_font_0[13];
                    vram_input_data_2[1][14]<= rom_font_0[14];
                    vram_input_data_2[1][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_2[1][0]<= rom_font_1[0];
                    vram_input_data_2[1][1]<= rom_font_1[1];
                    vram_input_data_2[1][2]<= rom_font_1[2];
                    vram_input_data_2[1][3]<= rom_font_1[3];
                    vram_input_data_2[1][4]<= rom_font_1[4];
                    vram_input_data_2[1][5]<= rom_font_1[5];
                    vram_input_data_2[1][6]<= rom_font_1[6];
                    vram_input_data_2[1][7]<= rom_font_1[7];
                    vram_input_data_2[1][8]<= rom_font_1[8];
                    vram_input_data_2[1][9]<= rom_font_1[9];
                    vram_input_data_2[1][10]<= rom_font_1[10];
                    vram_input_data_2[1][11]<= rom_font_1[11];
                    vram_input_data_2[1][12]<= rom_font_1[12];
                    vram_input_data_2[1][13]<= rom_font_1[13];
                    vram_input_data_2[1][14]<= rom_font_1[14];
                    vram_input_data_2[1][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_2[1][0]<= rom_font_2[0];
                    vram_input_data_2[1][1]<= rom_font_2[1];
                    vram_input_data_2[1][2]<= rom_font_2[2];
                    vram_input_data_2[1][3]<= rom_font_2[3];
                    vram_input_data_2[1][4]<= rom_font_2[4];
                    vram_input_data_2[1][5]<= rom_font_2[5];
                    vram_input_data_2[1][6]<= rom_font_2[6];
                    vram_input_data_2[1][7]<= rom_font_2[7];
                    vram_input_data_2[1][8]<= rom_font_2[8];
                    vram_input_data_2[1][9]<= rom_font_2[9];
                    vram_input_data_2[1][10]<= rom_font_2[10];
                    vram_input_data_2[1][11]<= rom_font_2[11];
                    vram_input_data_2[1][12]<= rom_font_2[12];
                    vram_input_data_2[1][13]<= rom_font_2[13];
                    vram_input_data_2[1][14]<= rom_font_2[14];
                    vram_input_data_2[1][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_2[1][0]<= rom_font_3[0];
                    vram_input_data_2[1][1]<= rom_font_3[1];
                    vram_input_data_2[1][2]<= rom_font_3[2];
                    vram_input_data_2[1][3]<= rom_font_3[3];
                    vram_input_data_2[1][4]<= rom_font_3[4];
                    vram_input_data_2[1][5]<= rom_font_3[5];
                    vram_input_data_2[1][6]<= rom_font_3[6];
                    vram_input_data_2[1][7]<= rom_font_3[7];
                    vram_input_data_2[1][8]<= rom_font_3[8];
                    vram_input_data_2[1][9]<= rom_font_3[9];
                    vram_input_data_2[1][10]<= rom_font_3[10];
                    vram_input_data_2[1][11]<= rom_font_3[11];
                    vram_input_data_2[1][12]<= rom_font_3[12];
                    vram_input_data_2[1][13]<= rom_font_3[13];
                    vram_input_data_2[1][14]<= rom_font_3[14];
                    vram_input_data_2[1][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_2[1][0]<= rom_font_4[0];
                    vram_input_data_2[1][1]<= rom_font_4[1];
                    vram_input_data_2[1][2]<= rom_font_4[2];
                    vram_input_data_2[1][3]<= rom_font_4[3];
                    vram_input_data_2[1][4]<= rom_font_4[4];
                    vram_input_data_2[1][5]<= rom_font_4[5];
                    vram_input_data_2[1][6]<= rom_font_4[6];
                    vram_input_data_2[1][7]<= rom_font_4[7];
                    vram_input_data_2[1][8]<= rom_font_4[8];
                    vram_input_data_2[1][9]<= rom_font_4[9];
                    vram_input_data_2[1][10]<= rom_font_4[10];
                    vram_input_data_2[1][11]<= rom_font_4[11];
                    vram_input_data_2[1][12]<= rom_font_4[12];
                    vram_input_data_2[1][13]<= rom_font_4[13];
                    vram_input_data_2[1][14]<= rom_font_4[14];
                    vram_input_data_2[1][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_2[1][0]<= rom_font_5[0];
                    vram_input_data_2[1][1]<= rom_font_5[1];
                    vram_input_data_2[1][2]<= rom_font_5[2];
                    vram_input_data_2[1][3]<= rom_font_5[3];
                    vram_input_data_2[1][4]<= rom_font_5[4];
                    vram_input_data_2[1][5]<= rom_font_5[5];
                    vram_input_data_2[1][6]<= rom_font_5[6];
                    vram_input_data_2[1][7]<= rom_font_5[7];
                    vram_input_data_2[1][8]<= rom_font_5[8];
                    vram_input_data_2[1][9]<= rom_font_5[9];
                    vram_input_data_2[1][10]<= rom_font_5[10];
                    vram_input_data_2[1][11]<= rom_font_5[11];
                    vram_input_data_2[1][12]<= rom_font_5[12];
                    vram_input_data_2[1][13]<= rom_font_5[13];
                    vram_input_data_2[1][14]<= rom_font_5[14];
                    vram_input_data_2[1][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_2[1][0]<= rom_font_6[0];
                    vram_input_data_2[1][1]<= rom_font_6[1];
                    vram_input_data_2[1][2]<= rom_font_6[2];
                    vram_input_data_2[1][3]<= rom_font_6[3];
                    vram_input_data_2[1][4]<= rom_font_6[4];
                    vram_input_data_2[1][5]<= rom_font_6[5];
                    vram_input_data_2[1][6]<= rom_font_6[6];
                    vram_input_data_2[1][7]<= rom_font_6[7];
                    vram_input_data_2[1][8]<= rom_font_6[8];
                    vram_input_data_2[1][9]<= rom_font_6[9];
                    vram_input_data_2[1][10]<= rom_font_6[10];
                    vram_input_data_2[1][11]<= rom_font_6[11];
                    vram_input_data_2[1][12]<= rom_font_6[12];
                    vram_input_data_2[1][13]<= rom_font_6[13];
                    vram_input_data_2[1][14]<= rom_font_6[14];
                    vram_input_data_2[1][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_2[1][0]<= rom_font_7[0];
                    vram_input_data_2[1][1]<= rom_font_7[1];
                    vram_input_data_2[1][2]<= rom_font_7[2];
                    vram_input_data_2[1][3]<= rom_font_7[3];
                    vram_input_data_2[1][4]<= rom_font_7[4];
                    vram_input_data_2[1][5]<= rom_font_7[5];
                    vram_input_data_2[1][6]<= rom_font_7[6];
                    vram_input_data_2[1][7]<= rom_font_7[7];
                    vram_input_data_2[1][8]<= rom_font_7[8];
                    vram_input_data_2[1][9]<= rom_font_7[9];
                    vram_input_data_2[1][10]<= rom_font_7[10];
                    vram_input_data_2[1][11]<= rom_font_7[11];
                    vram_input_data_2[1][12]<= rom_font_7[12];
                    vram_input_data_2[1][13]<= rom_font_7[13];
                    vram_input_data_2[1][14]<= rom_font_7[14];
                    vram_input_data_2[1][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_2[1][0]<= rom_font_8[0];
                    vram_input_data_2[1][1]<= rom_font_8[1];
                    vram_input_data_2[1][2]<= rom_font_8[2];
                    vram_input_data_2[1][3]<= rom_font_8[3];
                    vram_input_data_2[1][4]<= rom_font_8[4];
                    vram_input_data_2[1][5]<= rom_font_8[5];
                    vram_input_data_2[1][6]<= rom_font_8[6];
                    vram_input_data_2[1][7]<= rom_font_8[7];
                    vram_input_data_2[1][8]<= rom_font_8[8];
                    vram_input_data_2[1][9]<= rom_font_8[9];
                    vram_input_data_2[1][10]<= rom_font_8[10];
                    vram_input_data_2[1][11]<= rom_font_8[11];
                    vram_input_data_2[1][12]<= rom_font_8[12];
                    vram_input_data_2[1][13]<= rom_font_8[13];
                    vram_input_data_2[1][14]<= rom_font_8[14];
                    vram_input_data_2[1][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_2[1][0]<= rom_font_9[0];
                    vram_input_data_2[1][1]<= rom_font_9[1];
                    vram_input_data_2[1][2]<= rom_font_9[2];
                    vram_input_data_2[1][3]<= rom_font_9[3];
                    vram_input_data_2[1][4]<= rom_font_9[4];
                    vram_input_data_2[1][5]<= rom_font_9[5];
                    vram_input_data_2[1][6]<= rom_font_9[6];
                    vram_input_data_2[1][7]<= rom_font_9[7];
                    vram_input_data_2[1][8]<= rom_font_9[8];
                    vram_input_data_2[1][9]<= rom_font_9[9];
                    vram_input_data_2[1][10]<= rom_font_9[10];
                    vram_input_data_2[1][11]<= rom_font_9[11];
                    vram_input_data_2[1][12]<= rom_font_9[12];
                    vram_input_data_2[1][13]<= rom_font_9[13];
                    vram_input_data_2[1][14]<= rom_font_9[14];
                    vram_input_data_2[1][15]<= rom_font_9[15];
                end
            endcase case(user_data_fl / 10000) // fl的万位
                24'd0 : begin
                    vram_input_data_2[0][0]<= rom_font_0[0];
                    vram_input_data_2[0][1]<= rom_font_0[1];
                    vram_input_data_2[0][2]<= rom_font_0[2];
                    vram_input_data_2[0][3]<= rom_font_0[3];
                    vram_input_data_2[0][4]<= rom_font_0[4];
                    vram_input_data_2[0][5]<= rom_font_0[5];
                    vram_input_data_2[0][6]<= rom_font_0[6];
                    vram_input_data_2[0][7]<= rom_font_0[7];
                    vram_input_data_2[0][8]<= rom_font_0[8];
                    vram_input_data_2[0][9]<= rom_font_0[9];
                    vram_input_data_2[0][10]<= rom_font_0[10];
                    vram_input_data_2[0][11]<= rom_font_0[11];
                    vram_input_data_2[0][12]<= rom_font_0[12];
                    vram_input_data_2[0][13]<= rom_font_0[13];
                    vram_input_data_2[0][14]<= rom_font_0[14];
                    vram_input_data_2[0][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_2[0][0]<= rom_font_1[0];
                    vram_input_data_2[0][1]<= rom_font_1[1];
                    vram_input_data_2[0][2]<= rom_font_1[2];
                    vram_input_data_2[0][3]<= rom_font_1[3];
                    vram_input_data_2[0][4]<= rom_font_1[4];
                    vram_input_data_2[0][5]<= rom_font_1[5];
                    vram_input_data_2[0][6]<= rom_font_1[6];
                    vram_input_data_2[0][7]<= rom_font_1[7];
                    vram_input_data_2[0][8]<= rom_font_1[8];
                    vram_input_data_2[0][9]<= rom_font_1[9];
                    vram_input_data_2[0][10]<= rom_font_1[10];
                    vram_input_data_2[0][11]<= rom_font_1[11];
                    vram_input_data_2[0][12]<= rom_font_1[12];
                    vram_input_data_2[0][13]<= rom_font_1[13];
                    vram_input_data_2[0][14]<= rom_font_1[14];
                    vram_input_data_2[0][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_2[0][0]<= rom_font_2[0];
                    vram_input_data_2[0][1]<= rom_font_2[1];
                    vram_input_data_2[0][2]<= rom_font_2[2];
                    vram_input_data_2[0][3]<= rom_font_2[3];
                    vram_input_data_2[0][4]<= rom_font_2[4];
                    vram_input_data_2[0][5]<= rom_font_2[5];
                    vram_input_data_2[0][6]<= rom_font_2[6];
                    vram_input_data_2[0][7]<= rom_font_2[7];
                    vram_input_data_2[0][8]<= rom_font_2[8];
                    vram_input_data_2[0][9]<= rom_font_2[9];
                    vram_input_data_2[0][10]<= rom_font_2[10];
                    vram_input_data_2[0][11]<= rom_font_2[11];
                    vram_input_data_2[0][12]<= rom_font_2[12];
                    vram_input_data_2[0][13]<= rom_font_2[13];
                    vram_input_data_2[0][14]<= rom_font_2[14];
                    vram_input_data_2[0][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_2[0][0]<= rom_font_3[0];
                    vram_input_data_2[0][1]<= rom_font_3[1];
                    vram_input_data_2[0][2]<= rom_font_3[2];
                    vram_input_data_2[0][3]<= rom_font_3[3];
                    vram_input_data_2[0][4]<= rom_font_3[4];
                    vram_input_data_2[0][5]<= rom_font_3[5];
                    vram_input_data_2[0][6]<= rom_font_3[6];
                    vram_input_data_2[0][7]<= rom_font_3[7];
                    vram_input_data_2[0][8]<= rom_font_3[8];
                    vram_input_data_2[0][9]<= rom_font_3[9];
                    vram_input_data_2[0][10]<= rom_font_3[10];
                    vram_input_data_2[0][11]<= rom_font_3[11];
                    vram_input_data_2[0][12]<= rom_font_3[12];
                    vram_input_data_2[0][13]<= rom_font_3[13];
                    vram_input_data_2[0][14]<= rom_font_3[14];
                    vram_input_data_2[0][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_2[0][0]<= rom_font_4[0];
                    vram_input_data_2[0][1]<= rom_font_4[1];
                    vram_input_data_2[0][2]<= rom_font_4[2];
                    vram_input_data_2[0][3]<= rom_font_4[3];
                    vram_input_data_2[0][4]<= rom_font_4[4];
                    vram_input_data_2[0][5]<= rom_font_4[5];
                    vram_input_data_2[0][6]<= rom_font_4[6];
                    vram_input_data_2[0][7]<= rom_font_4[7];
                    vram_input_data_2[0][8]<= rom_font_4[8];
                    vram_input_data_2[0][9]<= rom_font_4[9];
                    vram_input_data_2[0][10]<= rom_font_4[10];
                    vram_input_data_2[0][11]<= rom_font_4[11];
                    vram_input_data_2[0][12]<= rom_font_4[12];
                    vram_input_data_2[0][13]<= rom_font_4[13];
                    vram_input_data_2[0][14]<= rom_font_4[14];
                    vram_input_data_2[0][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_2[0][0]<= rom_font_5[0];
                    vram_input_data_2[0][1]<= rom_font_5[1];
                    vram_input_data_2[0][2]<= rom_font_5[2];
                    vram_input_data_2[0][3]<= rom_font_5[3];
                    vram_input_data_2[0][4]<= rom_font_5[4];
                    vram_input_data_2[0][5]<= rom_font_5[5];
                    vram_input_data_2[0][6]<= rom_font_5[6];
                    vram_input_data_2[0][7]<= rom_font_5[7];
                    vram_input_data_2[0][8]<= rom_font_5[8];
                    vram_input_data_2[0][9]<= rom_font_5[9];
                    vram_input_data_2[0][10]<= rom_font_5[10];
                    vram_input_data_2[0][11]<= rom_font_5[11];
                    vram_input_data_2[0][12]<= rom_font_5[12];
                    vram_input_data_2[0][13]<= rom_font_5[13];
                    vram_input_data_2[0][14]<= rom_font_5[14];
                    vram_input_data_2[0][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_2[0][0]<= rom_font_6[0];
                    vram_input_data_2[0][1]<= rom_font_6[1];
                    vram_input_data_2[0][2]<= rom_font_6[2];
                    vram_input_data_2[0][3]<= rom_font_6[3];
                    vram_input_data_2[0][4]<= rom_font_6[4];
                    vram_input_data_2[0][5]<= rom_font_6[5];
                    vram_input_data_2[0][6]<= rom_font_6[6];
                    vram_input_data_2[0][7]<= rom_font_6[7];
                    vram_input_data_2[0][8]<= rom_font_6[8];
                    vram_input_data_2[0][9]<= rom_font_6[9];
                    vram_input_data_2[0][10]<= rom_font_6[10];
                    vram_input_data_2[0][11]<= rom_font_6[11];
                    vram_input_data_2[0][12]<= rom_font_6[12];
                    vram_input_data_2[0][13]<= rom_font_6[13];
                    vram_input_data_2[0][14]<= rom_font_6[14];
                    vram_input_data_2[0][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_2[0][0]<= rom_font_7[0];
                    vram_input_data_2[0][1]<= rom_font_7[1];
                    vram_input_data_2[0][2]<= rom_font_7[2];
                    vram_input_data_2[0][3]<= rom_font_7[3];
                    vram_input_data_2[0][4]<= rom_font_7[4];
                    vram_input_data_2[0][5]<= rom_font_7[5];
                    vram_input_data_2[0][6]<= rom_font_7[6];
                    vram_input_data_2[0][7]<= rom_font_7[7];
                    vram_input_data_2[0][8]<= rom_font_7[8];
                    vram_input_data_2[0][9]<= rom_font_7[9];
                    vram_input_data_2[0][10]<= rom_font_7[10];
                    vram_input_data_2[0][11]<= rom_font_7[11];
                    vram_input_data_2[0][12]<= rom_font_7[12];
                    vram_input_data_2[0][13]<= rom_font_7[13];
                    vram_input_data_2[0][14]<= rom_font_7[14];
                    vram_input_data_2[0][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_2[0][0]<= rom_font_8[0];
                    vram_input_data_2[0][1]<= rom_font_8[1];
                    vram_input_data_2[0][2]<= rom_font_8[2];
                    vram_input_data_2[0][3]<= rom_font_8[3];
                    vram_input_data_2[0][4]<= rom_font_8[4];
                    vram_input_data_2[0][5]<= rom_font_8[5];
                    vram_input_data_2[0][6]<= rom_font_8[6];
                    vram_input_data_2[0][7]<= rom_font_8[7];
                    vram_input_data_2[0][8]<= rom_font_8[8];
                    vram_input_data_2[0][9]<= rom_font_8[9];
                    vram_input_data_2[0][10]<= rom_font_8[10];
                    vram_input_data_2[0][11]<= rom_font_8[11];
                    vram_input_data_2[0][12]<= rom_font_8[12];
                    vram_input_data_2[0][13]<= rom_font_8[13];
                    vram_input_data_2[0][14]<= rom_font_8[14];
                    vram_input_data_2[0][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_2[0][0]<= rom_font_9[0];
                    vram_input_data_2[0][1]<= rom_font_9[1];
                    vram_input_data_2[0][2]<= rom_font_9[2];
                    vram_input_data_2[0][3]<= rom_font_9[3];
                    vram_input_data_2[0][4]<= rom_font_9[4];
                    vram_input_data_2[0][5]<= rom_font_9[5];
                    vram_input_data_2[0][6]<= rom_font_9[6];
                    vram_input_data_2[0][7]<= rom_font_9[7];
                    vram_input_data_2[0][8]<= rom_font_9[8];
                    vram_input_data_2[0][9]<= rom_font_9[9];
                    vram_input_data_2[0][10]<= rom_font_9[10];
                    vram_input_data_2[0][11]<= rom_font_9[11];
                    vram_input_data_2[0][12]<= rom_font_9[12];
                    vram_input_data_2[0][13]<= rom_font_9[13];
                    vram_input_data_2[0][14]<= rom_font_9[14];
                    vram_input_data_2[0][15]<= rom_font_9[15];
                end
            endcase 
            //------------------------------------------------------//
            case(user_data_rough_freq % 10) // user_data_rough_freq的个位
                24'd0 : begin
                    vram_input_data_3[4][0]<= rom_font_0[0];
                    vram_input_data_3[4][1]<= rom_font_0[1];
                    vram_input_data_3[4][2]<= rom_font_0[2];
                    vram_input_data_3[4][3]<= rom_font_0[3];
                    vram_input_data_3[4][4]<= rom_font_0[4];
                    vram_input_data_3[4][5]<= rom_font_0[5];
                    vram_input_data_3[4][6]<= rom_font_0[6];
                    vram_input_data_3[4][7]<= rom_font_0[7];
                    vram_input_data_3[4][8]<= rom_font_0[8];
                    vram_input_data_3[4][9]<= rom_font_0[9];
                    vram_input_data_3[4][10]<= rom_font_0[10];
                    vram_input_data_3[4][11]<= rom_font_0[11];
                    vram_input_data_3[4][12]<= rom_font_0[12];
                    vram_input_data_3[4][13]<= rom_font_0[13];
                    vram_input_data_3[4][14]<= rom_font_0[14];
                    vram_input_data_3[4][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_3[4][0]<= rom_font_1[0];
                    vram_input_data_3[4][1]<= rom_font_1[1];
                    vram_input_data_3[4][2]<= rom_font_1[2];
                    vram_input_data_3[4][3]<= rom_font_1[3];
                    vram_input_data_3[4][4]<= rom_font_1[4];
                    vram_input_data_3[4][5]<= rom_font_1[5];
                    vram_input_data_3[4][6]<= rom_font_1[6];
                    vram_input_data_3[4][7]<= rom_font_1[7];
                    vram_input_data_3[4][8]<= rom_font_1[8];
                    vram_input_data_3[4][9]<= rom_font_1[9];
                    vram_input_data_3[4][10]<= rom_font_1[10];
                    vram_input_data_3[4][11]<= rom_font_1[11];
                    vram_input_data_3[4][12]<= rom_font_1[12];
                    vram_input_data_3[4][13]<= rom_font_1[13];
                    vram_input_data_3[4][14]<= rom_font_1[14];
                    vram_input_data_3[4][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_3[4][0]<= rom_font_2[0];
                    vram_input_data_3[4][1]<= rom_font_2[1];
                    vram_input_data_3[4][2]<= rom_font_2[2];
                    vram_input_data_3[4][3]<= rom_font_2[3];
                    vram_input_data_3[4][4]<= rom_font_2[4];
                    vram_input_data_3[4][5]<= rom_font_2[5];
                    vram_input_data_3[4][6]<= rom_font_2[6];
                    vram_input_data_3[4][7]<= rom_font_2[7];
                    vram_input_data_3[4][8]<= rom_font_2[8];
                    vram_input_data_3[4][9]<= rom_font_2[9];
                    vram_input_data_3[4][10]<= rom_font_2[10];
                    vram_input_data_3[4][11]<= rom_font_2[11];
                    vram_input_data_3[4][12]<= rom_font_2[12];
                    vram_input_data_3[4][13]<= rom_font_2[13];
                    vram_input_data_3[4][14]<= rom_font_2[14];
                    vram_input_data_3[4][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_3[4][0]<= rom_font_3[0];
                    vram_input_data_3[4][1]<= rom_font_3[1];
                    vram_input_data_3[4][2]<= rom_font_3[2];
                    vram_input_data_3[4][3]<= rom_font_3[3];
                    vram_input_data_3[4][4]<= rom_font_3[4];
                    vram_input_data_3[4][5]<= rom_font_3[5];
                    vram_input_data_3[4][6]<= rom_font_3[6];
                    vram_input_data_3[4][7]<= rom_font_3[7];
                    vram_input_data_3[4][8]<= rom_font_3[8];
                    vram_input_data_3[4][9]<= rom_font_3[9];
                    vram_input_data_3[4][10]<= rom_font_3[10];
                    vram_input_data_3[4][11]<= rom_font_3[11];
                    vram_input_data_3[4][12]<= rom_font_3[12];
                    vram_input_data_3[4][13]<= rom_font_3[13];
                    vram_input_data_3[4][14]<= rom_font_3[14];
                    vram_input_data_3[4][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_3[4][0]<= rom_font_4[0];
                    vram_input_data_3[4][1]<= rom_font_4[1];
                    vram_input_data_3[4][2]<= rom_font_4[2];
                    vram_input_data_3[4][3]<= rom_font_4[3];
                    vram_input_data_3[4][4]<= rom_font_4[4];
                    vram_input_data_3[4][5]<= rom_font_4[5];
                    vram_input_data_3[4][6]<= rom_font_4[6];
                    vram_input_data_3[4][7]<= rom_font_4[7];
                    vram_input_data_3[4][8]<= rom_font_4[8];
                    vram_input_data_3[4][9]<= rom_font_4[9];
                    vram_input_data_3[4][10]<= rom_font_4[10];
                    vram_input_data_3[4][11]<= rom_font_4[11];
                    vram_input_data_3[4][12]<= rom_font_4[12];
                    vram_input_data_3[4][13]<= rom_font_4[13];
                    vram_input_data_3[4][14]<= rom_font_4[14];
                    vram_input_data_3[4][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_3[4][0]<= rom_font_5[0];
                    vram_input_data_3[4][1]<= rom_font_5[1];
                    vram_input_data_3[4][2]<= rom_font_5[2];
                    vram_input_data_3[4][3]<= rom_font_5[3];
                    vram_input_data_3[4][4]<= rom_font_5[4];
                    vram_input_data_3[4][5]<= rom_font_5[5];
                    vram_input_data_3[4][6]<= rom_font_5[6];
                    vram_input_data_3[4][7]<= rom_font_5[7];
                    vram_input_data_3[4][8]<= rom_font_5[8];
                    vram_input_data_3[4][9]<= rom_font_5[9];
                    vram_input_data_3[4][10]<= rom_font_5[10];
                    vram_input_data_3[4][11]<= rom_font_5[11];
                    vram_input_data_3[4][12]<= rom_font_5[12];
                    vram_input_data_3[4][13]<= rom_font_5[13];
                    vram_input_data_3[4][14]<= rom_font_5[14];
                    vram_input_data_3[4][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_3[4][0]<= rom_font_6[0];
                    vram_input_data_3[4][1]<= rom_font_6[1];
                    vram_input_data_3[4][2]<= rom_font_6[2];
                    vram_input_data_3[4][3]<= rom_font_6[3];
                    vram_input_data_3[4][4]<= rom_font_6[4];
                    vram_input_data_3[4][5]<= rom_font_6[5];
                    vram_input_data_3[4][6]<= rom_font_6[6];
                    vram_input_data_3[4][7]<= rom_font_6[7];
                    vram_input_data_3[4][8]<= rom_font_6[8];
                    vram_input_data_3[4][9]<= rom_font_6[9];
                    vram_input_data_3[4][10]<= rom_font_6[10];
                    vram_input_data_3[4][11]<= rom_font_6[11];
                    vram_input_data_3[4][12]<= rom_font_6[12];
                    vram_input_data_3[4][13]<= rom_font_6[13];
                    vram_input_data_3[4][14]<= rom_font_6[14];
                    vram_input_data_3[4][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_3[4][0]<= rom_font_7[0];
                    vram_input_data_3[4][1]<= rom_font_7[1];
                    vram_input_data_3[4][2]<= rom_font_7[2];
                    vram_input_data_3[4][3]<= rom_font_7[3];
                    vram_input_data_3[4][4]<= rom_font_7[4];
                    vram_input_data_3[4][5]<= rom_font_7[5];
                    vram_input_data_3[4][6]<= rom_font_7[6];
                    vram_input_data_3[4][7]<= rom_font_7[7];
                    vram_input_data_3[4][8]<= rom_font_7[8];
                    vram_input_data_3[4][9]<= rom_font_7[9];
                    vram_input_data_3[4][10]<= rom_font_7[10];
                    vram_input_data_3[4][11]<= rom_font_7[11];
                    vram_input_data_3[4][12]<= rom_font_7[12];
                    vram_input_data_3[4][13]<= rom_font_7[13];
                    vram_input_data_3[4][14]<= rom_font_7[14];
                    vram_input_data_3[4][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_3[4][0]<= rom_font_8[0];
                    vram_input_data_3[4][1]<= rom_font_8[1];
                    vram_input_data_3[4][2]<= rom_font_8[2];
                    vram_input_data_3[4][3]<= rom_font_8[3];
                    vram_input_data_3[4][4]<= rom_font_8[4];
                    vram_input_data_3[4][5]<= rom_font_8[5];
                    vram_input_data_3[4][6]<= rom_font_8[6];
                    vram_input_data_3[4][7]<= rom_font_8[7];
                    vram_input_data_3[4][8]<= rom_font_8[8];
                    vram_input_data_3[4][9]<= rom_font_8[9];
                    vram_input_data_3[4][10]<= rom_font_8[10];
                    vram_input_data_3[4][11]<= rom_font_8[11];
                    vram_input_data_3[4][12]<= rom_font_8[12];
                    vram_input_data_3[4][13]<= rom_font_8[13];
                    vram_input_data_3[4][14]<= rom_font_8[14];
                    vram_input_data_3[4][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_3[4][0]<= rom_font_9[0];
                    vram_input_data_3[4][1]<= rom_font_9[1];
                    vram_input_data_3[4][2]<= rom_font_9[2];
                    vram_input_data_3[4][3]<= rom_font_9[3];
                    vram_input_data_3[4][4]<= rom_font_9[4];
                    vram_input_data_3[4][5]<= rom_font_9[5];
                    vram_input_data_3[4][6]<= rom_font_9[6];
                    vram_input_data_3[4][7]<= rom_font_9[7];
                    vram_input_data_3[4][8]<= rom_font_9[8];
                    vram_input_data_3[4][9]<= rom_font_9[9];
                    vram_input_data_3[4][10]<= rom_font_9[10];
                    vram_input_data_3[4][11]<= rom_font_9[11];
                    vram_input_data_3[4][12]<= rom_font_9[12];
                    vram_input_data_3[4][13]<= rom_font_9[13];
                    vram_input_data_3[4][14]<= rom_font_9[14];
                    vram_input_data_3[4][15]<= rom_font_9[15];
                end
            endcase case((user_data_rough_freq % 100) / 10) // user_data_rough_freq的十位
                24'd0 : begin
                    vram_input_data_3[3][0]<= rom_font_0[0];
                    vram_input_data_3[3][1]<= rom_font_0[1];
                    vram_input_data_3[3][2]<= rom_font_0[2];
                    vram_input_data_3[3][3]<= rom_font_0[3];
                    vram_input_data_3[3][4]<= rom_font_0[4];
                    vram_input_data_3[3][5]<= rom_font_0[5];
                    vram_input_data_3[3][6]<= rom_font_0[6];
                    vram_input_data_3[3][7]<= rom_font_0[7];
                    vram_input_data_3[3][8]<= rom_font_0[8];
                    vram_input_data_3[3][9]<= rom_font_0[9];
                    vram_input_data_3[3][10]<= rom_font_0[10];
                    vram_input_data_3[3][11]<= rom_font_0[11];
                    vram_input_data_3[3][12]<= rom_font_0[12];
                    vram_input_data_3[3][13]<= rom_font_0[13];
                    vram_input_data_3[3][14]<= rom_font_0[14];
                    vram_input_data_3[3][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_3[3][0]<= rom_font_1[0];
                    vram_input_data_3[3][1]<= rom_font_1[1];
                    vram_input_data_3[3][2]<= rom_font_1[2];
                    vram_input_data_3[3][3]<= rom_font_1[3];
                    vram_input_data_3[3][4]<= rom_font_1[4];
                    vram_input_data_3[3][5]<= rom_font_1[5];
                    vram_input_data_3[3][6]<= rom_font_1[6];
                    vram_input_data_3[3][7]<= rom_font_1[7];
                    vram_input_data_3[3][8]<= rom_font_1[8];
                    vram_input_data_3[3][9]<= rom_font_1[9];
                    vram_input_data_3[3][10]<= rom_font_1[10];
                    vram_input_data_3[3][11]<= rom_font_1[11];
                    vram_input_data_3[3][12]<= rom_font_1[12];
                    vram_input_data_3[3][13]<= rom_font_1[13];
                    vram_input_data_3[3][14]<= rom_font_1[14];
                    vram_input_data_3[3][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_3[3][0]<= rom_font_2[0];
                    vram_input_data_3[3][1]<= rom_font_2[1];
                    vram_input_data_3[3][2]<= rom_font_2[2];
                    vram_input_data_3[3][3]<= rom_font_2[3];
                    vram_input_data_3[3][4]<= rom_font_2[4];
                    vram_input_data_3[3][5]<= rom_font_2[5];
                    vram_input_data_3[3][6]<= rom_font_2[6];
                    vram_input_data_3[3][7]<= rom_font_2[7];
                    vram_input_data_3[3][8]<= rom_font_2[8];
                    vram_input_data_3[3][9]<= rom_font_2[9];
                    vram_input_data_3[3][10]<= rom_font_2[10];
                    vram_input_data_3[3][11]<= rom_font_2[11];
                    vram_input_data_3[3][12]<= rom_font_2[12];
                    vram_input_data_3[3][13]<= rom_font_2[13];
                    vram_input_data_3[3][14]<= rom_font_2[14];
                    vram_input_data_3[3][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_3[3][0]<= rom_font_3[0];
                    vram_input_data_3[3][1]<= rom_font_3[1];
                    vram_input_data_3[3][2]<= rom_font_3[2];
                    vram_input_data_3[3][3]<= rom_font_3[3];
                    vram_input_data_3[3][4]<= rom_font_3[4];
                    vram_input_data_3[3][5]<= rom_font_3[5];
                    vram_input_data_3[3][6]<= rom_font_3[6];
                    vram_input_data_3[3][7]<= rom_font_3[7];
                    vram_input_data_3[3][8]<= rom_font_3[8];
                    vram_input_data_3[3][9]<= rom_font_3[9];
                    vram_input_data_3[3][10]<= rom_font_3[10];
                    vram_input_data_3[3][11]<= rom_font_3[11];
                    vram_input_data_3[3][12]<= rom_font_3[12];
                    vram_input_data_3[3][13]<= rom_font_3[13];
                    vram_input_data_3[3][14]<= rom_font_3[14];
                    vram_input_data_3[3][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_3[3][0]<= rom_font_4[0];
                    vram_input_data_3[3][1]<= rom_font_4[1];
                    vram_input_data_3[3][2]<= rom_font_4[2];
                    vram_input_data_3[3][3]<= rom_font_4[3];
                    vram_input_data_3[3][4]<= rom_font_4[4];
                    vram_input_data_3[3][5]<= rom_font_4[5];
                    vram_input_data_3[3][6]<= rom_font_4[6];
                    vram_input_data_3[3][7]<= rom_font_4[7];
                    vram_input_data_3[3][8]<= rom_font_4[8];
                    vram_input_data_3[3][9]<= rom_font_4[9];
                    vram_input_data_3[3][10]<= rom_font_4[10];
                    vram_input_data_3[3][11]<= rom_font_4[11];
                    vram_input_data_3[3][12]<= rom_font_4[12];
                    vram_input_data_3[3][13]<= rom_font_4[13];
                    vram_input_data_3[3][14]<= rom_font_4[14];
                    vram_input_data_3[3][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_3[3][0]<= rom_font_5[0];
                    vram_input_data_3[3][1]<= rom_font_5[1];
                    vram_input_data_3[3][2]<= rom_font_5[2];
                    vram_input_data_3[3][3]<= rom_font_5[3];
                    vram_input_data_3[3][4]<= rom_font_5[4];
                    vram_input_data_3[3][5]<= rom_font_5[5];
                    vram_input_data_3[3][6]<= rom_font_5[6];
                    vram_input_data_3[3][7]<= rom_font_5[7];
                    vram_input_data_3[3][8]<= rom_font_5[8];
                    vram_input_data_3[3][9]<= rom_font_5[9];
                    vram_input_data_3[3][10]<= rom_font_5[10];
                    vram_input_data_3[3][11]<= rom_font_5[11];
                    vram_input_data_3[3][12]<= rom_font_5[12];
                    vram_input_data_3[3][13]<= rom_font_5[13];
                    vram_input_data_3[3][14]<= rom_font_5[14];
                    vram_input_data_3[3][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_3[3][0]<= rom_font_6[0];
                    vram_input_data_3[3][1]<= rom_font_6[1];
                    vram_input_data_3[3][2]<= rom_font_6[2];
                    vram_input_data_3[3][3]<= rom_font_6[3];
                    vram_input_data_3[3][4]<= rom_font_6[4];
                    vram_input_data_3[3][5]<= rom_font_6[5];
                    vram_input_data_3[3][6]<= rom_font_6[6];
                    vram_input_data_3[3][7]<= rom_font_6[7];
                    vram_input_data_3[3][8]<= rom_font_6[8];
                    vram_input_data_3[3][9]<= rom_font_6[9];
                    vram_input_data_3[3][10]<= rom_font_6[10];
                    vram_input_data_3[3][11]<= rom_font_6[11];
                    vram_input_data_3[3][12]<= rom_font_6[12];
                    vram_input_data_3[3][13]<= rom_font_6[13];
                    vram_input_data_3[3][14]<= rom_font_6[14];
                    vram_input_data_3[3][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_3[3][0]<= rom_font_7[0];
                    vram_input_data_3[3][1]<= rom_font_7[1];
                    vram_input_data_3[3][2]<= rom_font_7[2];
                    vram_input_data_3[3][3]<= rom_font_7[3];
                    vram_input_data_3[3][4]<= rom_font_7[4];
                    vram_input_data_3[3][5]<= rom_font_7[5];
                    vram_input_data_3[3][6]<= rom_font_7[6];
                    vram_input_data_3[3][7]<= rom_font_7[7];
                    vram_input_data_3[3][8]<= rom_font_7[8];
                    vram_input_data_3[3][9]<= rom_font_7[9];
                    vram_input_data_3[3][10]<= rom_font_7[10];
                    vram_input_data_3[3][11]<= rom_font_7[11];
                    vram_input_data_3[3][12]<= rom_font_7[12];
                    vram_input_data_3[3][13]<= rom_font_7[13];
                    vram_input_data_3[3][14]<= rom_font_7[14];
                    vram_input_data_3[3][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_3[3][0]<= rom_font_8[0];
                    vram_input_data_3[3][1]<= rom_font_8[1];
                    vram_input_data_3[3][2]<= rom_font_8[2];
                    vram_input_data_3[3][3]<= rom_font_8[3];
                    vram_input_data_3[3][4]<= rom_font_8[4];
                    vram_input_data_3[3][5]<= rom_font_8[5];
                    vram_input_data_3[3][6]<= rom_font_8[6];
                    vram_input_data_3[3][7]<= rom_font_8[7];
                    vram_input_data_3[3][8]<= rom_font_8[8];
                    vram_input_data_3[3][9]<= rom_font_8[9];
                    vram_input_data_3[3][10]<= rom_font_8[10];
                    vram_input_data_3[3][11]<= rom_font_8[11];
                    vram_input_data_3[3][12]<= rom_font_8[12];
                    vram_input_data_3[3][13]<= rom_font_8[13];
                    vram_input_data_3[3][14]<= rom_font_8[14];
                    vram_input_data_3[3][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_3[3][0]<= rom_font_9[0];
                    vram_input_data_3[3][1]<= rom_font_9[1];
                    vram_input_data_3[3][2]<= rom_font_9[2];
                    vram_input_data_3[3][3]<= rom_font_9[3];
                    vram_input_data_3[3][4]<= rom_font_9[4];
                    vram_input_data_3[3][5]<= rom_font_9[5];
                    vram_input_data_3[3][6]<= rom_font_9[6];
                    vram_input_data_3[3][7]<= rom_font_9[7];
                    vram_input_data_3[3][8]<= rom_font_9[8];
                    vram_input_data_3[3][9]<= rom_font_9[9];
                    vram_input_data_3[3][10]<= rom_font_9[10];
                    vram_input_data_3[3][11]<= rom_font_9[11];
                    vram_input_data_3[3][12]<= rom_font_9[12];
                    vram_input_data_3[3][13]<= rom_font_9[13];
                    vram_input_data_3[3][14]<= rom_font_9[14];
                    vram_input_data_3[3][15]<= rom_font_9[15];
                end
            endcase case((user_data_rough_freq % 1000) / 100) // user_data_rough_freq的百位
                24'd0 : begin
                    vram_input_data_3[2][0]<= rom_font_0[0];
                    vram_input_data_3[2][1]<= rom_font_0[1];
                    vram_input_data_3[2][2]<= rom_font_0[2];
                    vram_input_data_3[2][3]<= rom_font_0[3];
                    vram_input_data_3[2][4]<= rom_font_0[4];
                    vram_input_data_3[2][5]<= rom_font_0[5];
                    vram_input_data_3[2][6]<= rom_font_0[6];
                    vram_input_data_3[2][7]<= rom_font_0[7];
                    vram_input_data_3[2][8]<= rom_font_0[8];
                    vram_input_data_3[2][9]<= rom_font_0[9];
                    vram_input_data_3[2][10]<= rom_font_0[10];
                    vram_input_data_3[2][11]<= rom_font_0[11];
                    vram_input_data_3[2][12]<= rom_font_0[12];
                    vram_input_data_3[2][13]<= rom_font_0[13];
                    vram_input_data_3[2][14]<= rom_font_0[14];
                    vram_input_data_3[2][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_3[2][0]<= rom_font_1[0];
                    vram_input_data_3[2][1]<= rom_font_1[1];
                    vram_input_data_3[2][2]<= rom_font_1[2];
                    vram_input_data_3[2][3]<= rom_font_1[3];
                    vram_input_data_3[2][4]<= rom_font_1[4];
                    vram_input_data_3[2][5]<= rom_font_1[5];
                    vram_input_data_3[2][6]<= rom_font_1[6];
                    vram_input_data_3[2][7]<= rom_font_1[7];
                    vram_input_data_3[2][8]<= rom_font_1[8];
                    vram_input_data_3[2][9]<= rom_font_1[9];
                    vram_input_data_3[2][10]<= rom_font_1[10];
                    vram_input_data_3[2][11]<= rom_font_1[11];
                    vram_input_data_3[2][12]<= rom_font_1[12];
                    vram_input_data_3[2][13]<= rom_font_1[13];
                    vram_input_data_3[2][14]<= rom_font_1[14];
                    vram_input_data_3[2][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_3[2][0]<= rom_font_2[0];
                    vram_input_data_3[2][1]<= rom_font_2[1];
                    vram_input_data_3[2][2]<= rom_font_2[2];
                    vram_input_data_3[2][3]<= rom_font_2[3];
                    vram_input_data_3[2][4]<= rom_font_2[4];
                    vram_input_data_3[2][5]<= rom_font_2[5];
                    vram_input_data_3[2][6]<= rom_font_2[6];
                    vram_input_data_3[2][7]<= rom_font_2[7];
                    vram_input_data_3[2][8]<= rom_font_2[8];
                    vram_input_data_3[2][9]<= rom_font_2[9];
                    vram_input_data_3[2][10]<= rom_font_2[10];
                    vram_input_data_3[2][11]<= rom_font_2[11];
                    vram_input_data_3[2][12]<= rom_font_2[12];
                    vram_input_data_3[2][13]<= rom_font_2[13];
                    vram_input_data_3[2][14]<= rom_font_2[14];
                    vram_input_data_3[2][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_3[2][0]<= rom_font_3[0];
                    vram_input_data_3[2][1]<= rom_font_3[1];
                    vram_input_data_3[2][2]<= rom_font_3[2];
                    vram_input_data_3[2][3]<= rom_font_3[3];
                    vram_input_data_3[2][4]<= rom_font_3[4];
                    vram_input_data_3[2][5]<= rom_font_3[5];
                    vram_input_data_3[2][6]<= rom_font_3[6];
                    vram_input_data_3[2][7]<= rom_font_3[7];
                    vram_input_data_3[2][8]<= rom_font_3[8];
                    vram_input_data_3[2][9]<= rom_font_3[9];
                    vram_input_data_3[2][10]<= rom_font_3[10];
                    vram_input_data_3[2][11]<= rom_font_3[11];
                    vram_input_data_3[2][12]<= rom_font_3[12];
                    vram_input_data_3[2][13]<= rom_font_3[13];
                    vram_input_data_3[2][14]<= rom_font_3[14];
                    vram_input_data_3[2][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_3[2][0]<= rom_font_4[0];
                    vram_input_data_3[2][1]<= rom_font_4[1];
                    vram_input_data_3[2][2]<= rom_font_4[2];
                    vram_input_data_3[2][3]<= rom_font_4[3];
                    vram_input_data_3[2][4]<= rom_font_4[4];
                    vram_input_data_3[2][5]<= rom_font_4[5];
                    vram_input_data_3[2][6]<= rom_font_4[6];
                    vram_input_data_3[2][7]<= rom_font_4[7];
                    vram_input_data_3[2][8]<= rom_font_4[8];
                    vram_input_data_3[2][9]<= rom_font_4[9];
                    vram_input_data_3[2][10]<= rom_font_4[10];
                    vram_input_data_3[2][11]<= rom_font_4[11];
                    vram_input_data_3[2][12]<= rom_font_4[12];
                    vram_input_data_3[2][13]<= rom_font_4[13];
                    vram_input_data_3[2][14]<= rom_font_4[14];
                    vram_input_data_3[2][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_3[2][0]<= rom_font_5[0];
                    vram_input_data_3[2][1]<= rom_font_5[1];
                    vram_input_data_3[2][2]<= rom_font_5[2];
                    vram_input_data_3[2][3]<= rom_font_5[3];
                    vram_input_data_3[2][4]<= rom_font_5[4];
                    vram_input_data_3[2][5]<= rom_font_5[5];
                    vram_input_data_3[2][6]<= rom_font_5[6];
                    vram_input_data_3[2][7]<= rom_font_5[7];
                    vram_input_data_3[2][8]<= rom_font_5[8];
                    vram_input_data_3[2][9]<= rom_font_5[9];
                    vram_input_data_3[2][10]<= rom_font_5[10];
                    vram_input_data_3[2][11]<= rom_font_5[11];
                    vram_input_data_3[2][12]<= rom_font_5[12];
                    vram_input_data_3[2][13]<= rom_font_5[13];
                    vram_input_data_3[2][14]<= rom_font_5[14];
                    vram_input_data_3[2][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_3[2][0]<= rom_font_6[0];
                    vram_input_data_3[2][1]<= rom_font_6[1];
                    vram_input_data_3[2][2]<= rom_font_6[2];
                    vram_input_data_3[2][3]<= rom_font_6[3];
                    vram_input_data_3[2][4]<= rom_font_6[4];
                    vram_input_data_3[2][5]<= rom_font_6[5];
                    vram_input_data_3[2][6]<= rom_font_6[6];
                    vram_input_data_3[2][7]<= rom_font_6[7];
                    vram_input_data_3[2][8]<= rom_font_6[8];
                    vram_input_data_3[2][9]<= rom_font_6[9];
                    vram_input_data_3[2][10]<= rom_font_6[10];
                    vram_input_data_3[2][11]<= rom_font_6[11];
                    vram_input_data_3[2][12]<= rom_font_6[12];
                    vram_input_data_3[2][13]<= rom_font_6[13];
                    vram_input_data_3[2][14]<= rom_font_6[14];
                    vram_input_data_3[2][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_3[2][0]<= rom_font_7[0];
                    vram_input_data_3[2][1]<= rom_font_7[1];
                    vram_input_data_3[2][2]<= rom_font_7[2];
                    vram_input_data_3[2][3]<= rom_font_7[3];
                    vram_input_data_3[2][4]<= rom_font_7[4];
                    vram_input_data_3[2][5]<= rom_font_7[5];
                    vram_input_data_3[2][6]<= rom_font_7[6];
                    vram_input_data_3[2][7]<= rom_font_7[7];
                    vram_input_data_3[2][8]<= rom_font_7[8];
                    vram_input_data_3[2][9]<= rom_font_7[9];
                    vram_input_data_3[2][10]<= rom_font_7[10];
                    vram_input_data_3[2][11]<= rom_font_7[11];
                    vram_input_data_3[2][12]<= rom_font_7[12];
                    vram_input_data_3[2][13]<= rom_font_7[13];
                    vram_input_data_3[2][14]<= rom_font_7[14];
                    vram_input_data_3[2][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_3[2][0]<= rom_font_8[0];
                    vram_input_data_3[2][1]<= rom_font_8[1];
                    vram_input_data_3[2][2]<= rom_font_8[2];
                    vram_input_data_3[2][3]<= rom_font_8[3];
                    vram_input_data_3[2][4]<= rom_font_8[4];
                    vram_input_data_3[2][5]<= rom_font_8[5];
                    vram_input_data_3[2][6]<= rom_font_8[6];
                    vram_input_data_3[2][7]<= rom_font_8[7];
                    vram_input_data_3[2][8]<= rom_font_8[8];
                    vram_input_data_3[2][9]<= rom_font_8[9];
                    vram_input_data_3[2][10]<= rom_font_8[10];
                    vram_input_data_3[2][11]<= rom_font_8[11];
                    vram_input_data_3[2][12]<= rom_font_8[12];
                    vram_input_data_3[2][13]<= rom_font_8[13];
                    vram_input_data_3[2][14]<= rom_font_8[14];
                    vram_input_data_3[2][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_3[2][0]<= rom_font_9[0];
                    vram_input_data_3[2][1]<= rom_font_9[1];
                    vram_input_data_3[2][2]<= rom_font_9[2];
                    vram_input_data_3[2][3]<= rom_font_9[3];
                    vram_input_data_3[2][4]<= rom_font_9[4];
                    vram_input_data_3[2][5]<= rom_font_9[5];
                    vram_input_data_3[2][6]<= rom_font_9[6];
                    vram_input_data_3[2][7]<= rom_font_9[7];
                    vram_input_data_3[2][8]<= rom_font_9[8];
                    vram_input_data_3[2][9]<= rom_font_9[9];
                    vram_input_data_3[2][10]<= rom_font_9[10];
                    vram_input_data_3[2][11]<= rom_font_9[11];
                    vram_input_data_3[2][12]<= rom_font_9[12];
                    vram_input_data_3[2][13]<= rom_font_9[13];
                    vram_input_data_3[2][14]<= rom_font_9[14];
                    vram_input_data_3[2][15]<= rom_font_9[15];
                end
            endcase case((user_data_rough_freq % 10000) / 1000) // user_data_rough_freq的千位
                24'd0 : begin
                    vram_input_data_3[1][0]<= rom_font_0[0];
                    vram_input_data_3[1][1]<= rom_font_0[1];
                    vram_input_data_3[1][2]<= rom_font_0[2];
                    vram_input_data_3[1][3]<= rom_font_0[3];
                    vram_input_data_3[1][4]<= rom_font_0[4];
                    vram_input_data_3[1][5]<= rom_font_0[5];
                    vram_input_data_3[1][6]<= rom_font_0[6];
                    vram_input_data_3[1][7]<= rom_font_0[7];
                    vram_input_data_3[1][8]<= rom_font_0[8];
                    vram_input_data_3[1][9]<= rom_font_0[9];
                    vram_input_data_3[1][10]<= rom_font_0[10];
                    vram_input_data_3[1][11]<= rom_font_0[11];
                    vram_input_data_3[1][12]<= rom_font_0[12];
                    vram_input_data_3[1][13]<= rom_font_0[13];
                    vram_input_data_3[1][14]<= rom_font_0[14];
                    vram_input_data_3[1][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_2[1][0]<= rom_font_1[0];
                    vram_input_data_3[1][1]<= rom_font_1[1];
                    vram_input_data_3[1][2]<= rom_font_1[2];
                    vram_input_data_3[1][3]<= rom_font_1[3];
                    vram_input_data_3[1][4]<= rom_font_1[4];
                    vram_input_data_3[1][5]<= rom_font_1[5];
                    vram_input_data_3[1][6]<= rom_font_1[6];
                    vram_input_data_3[1][7]<= rom_font_1[7];
                    vram_input_data_3[1][8]<= rom_font_1[8];
                    vram_input_data_3[1][9]<= rom_font_1[9];
                    vram_input_data_3[1][10]<= rom_font_1[10];
                    vram_input_data_3[1][11]<= rom_font_1[11];
                    vram_input_data_3[1][12]<= rom_font_1[12];
                    vram_input_data_3[1][13]<= rom_font_1[13];
                    vram_input_data_3[1][14]<= rom_font_1[14];
                    vram_input_data_3[1][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_3[1][0]<= rom_font_2[0];
                    vram_input_data_3[1][1]<= rom_font_2[1];
                    vram_input_data_3[1][2]<= rom_font_2[2];
                    vram_input_data_3[1][3]<= rom_font_2[3];
                    vram_input_data_3[1][4]<= rom_font_2[4];
                    vram_input_data_3[1][5]<= rom_font_2[5];
                    vram_input_data_3[1][6]<= rom_font_2[6];
                    vram_input_data_3[1][7]<= rom_font_2[7];
                    vram_input_data_3[1][8]<= rom_font_2[8];
                    vram_input_data_3[1][9]<= rom_font_2[9];
                    vram_input_data_3[1][10]<= rom_font_2[10];
                    vram_input_data_3[1][11]<= rom_font_2[11];
                    vram_input_data_3[1][12]<= rom_font_2[12];
                    vram_input_data_3[1][13]<= rom_font_2[13];
                    vram_input_data_3[1][14]<= rom_font_2[14];
                    vram_input_data_3[1][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_3[1][0]<= rom_font_3[0];
                    vram_input_data_3[1][1]<= rom_font_3[1];
                    vram_input_data_3[1][2]<= rom_font_3[2];
                    vram_input_data_3[1][3]<= rom_font_3[3];
                    vram_input_data_3[1][4]<= rom_font_3[4];
                    vram_input_data_3[1][5]<= rom_font_3[5];
                    vram_input_data_3[1][6]<= rom_font_3[6];
                    vram_input_data_3[1][7]<= rom_font_3[7];
                    vram_input_data_3[1][8]<= rom_font_3[8];
                    vram_input_data_3[1][9]<= rom_font_3[9];
                    vram_input_data_3[1][10]<= rom_font_3[10];
                    vram_input_data_3[1][11]<= rom_font_3[11];
                    vram_input_data_3[1][12]<= rom_font_3[12];
                    vram_input_data_3[1][13]<= rom_font_3[13];
                    vram_input_data_3[1][14]<= rom_font_3[14];
                    vram_input_data_3[1][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_3[1][0]<= rom_font_4[0];
                    vram_input_data_3[1][1]<= rom_font_4[1];
                    vram_input_data_3[1][2]<= rom_font_4[2];
                    vram_input_data_3[1][3]<= rom_font_4[3];
                    vram_input_data_3[1][4]<= rom_font_4[4];
                    vram_input_data_3[1][5]<= rom_font_4[5];
                    vram_input_data_3[1][6]<= rom_font_4[6];
                    vram_input_data_3[1][7]<= rom_font_4[7];
                    vram_input_data_3[1][8]<= rom_font_4[8];
                    vram_input_data_3[1][9]<= rom_font_4[9];
                    vram_input_data_3[1][10]<= rom_font_4[10];
                    vram_input_data_3[1][11]<= rom_font_4[11];
                    vram_input_data_3[1][12]<= rom_font_4[12];
                    vram_input_data_3[1][13]<= rom_font_4[13];
                    vram_input_data_3[1][14]<= rom_font_4[14];
                    vram_input_data_3[1][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_3[1][0]<= rom_font_5[0];
                    vram_input_data_3[1][1]<= rom_font_5[1];
                    vram_input_data_3[1][2]<= rom_font_5[2];
                    vram_input_data_3[1][3]<= rom_font_5[3];
                    vram_input_data_3[1][4]<= rom_font_5[4];
                    vram_input_data_3[1][5]<= rom_font_5[5];
                    vram_input_data_3[1][6]<= rom_font_5[6];
                    vram_input_data_3[1][7]<= rom_font_5[7];
                    vram_input_data_3[1][8]<= rom_font_5[8];
                    vram_input_data_3[1][9]<= rom_font_5[9];
                    vram_input_data_3[1][10]<= rom_font_5[10];
                    vram_input_data_3[1][11]<= rom_font_5[11];
                    vram_input_data_3[1][12]<= rom_font_5[12];
                    vram_input_data_3[1][13]<= rom_font_5[13];
                    vram_input_data_3[1][14]<= rom_font_5[14];
                    vram_input_data_3[1][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_3[1][0]<= rom_font_6[0];
                    vram_input_data_3[1][1]<= rom_font_6[1];
                    vram_input_data_3[1][2]<= rom_font_6[2];
                    vram_input_data_3[1][3]<= rom_font_6[3];
                    vram_input_data_3[1][4]<= rom_font_6[4];
                    vram_input_data_3[1][5]<= rom_font_6[5];
                    vram_input_data_3[1][6]<= rom_font_6[6];
                    vram_input_data_3[1][7]<= rom_font_6[7];
                    vram_input_data_3[1][8]<= rom_font_6[8];
                    vram_input_data_3[1][9]<= rom_font_6[9];
                    vram_input_data_3[1][10]<= rom_font_6[10];
                    vram_input_data_3[1][11]<= rom_font_6[11];
                    vram_input_data_3[1][12]<= rom_font_6[12];
                    vram_input_data_3[1][13]<= rom_font_6[13];
                    vram_input_data_3[1][14]<= rom_font_6[14];
                    vram_input_data_3[1][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_3[1][0]<= rom_font_7[0];
                    vram_input_data_3[1][1]<= rom_font_7[1];
                    vram_input_data_3[1][2]<= rom_font_7[2];
                    vram_input_data_3[1][3]<= rom_font_7[3];
                    vram_input_data_3[1][4]<= rom_font_7[4];
                    vram_input_data_3[1][5]<= rom_font_7[5];
                    vram_input_data_3[1][6]<= rom_font_7[6];
                    vram_input_data_3[1][7]<= rom_font_7[7];
                    vram_input_data_3[1][8]<= rom_font_7[8];
                    vram_input_data_3[1][9]<= rom_font_7[9];
                    vram_input_data_3[1][10]<= rom_font_7[10];
                    vram_input_data_3[1][11]<= rom_font_7[11];
                    vram_input_data_3[1][12]<= rom_font_7[12];
                    vram_input_data_3[1][13]<= rom_font_7[13];
                    vram_input_data_3[1][14]<= rom_font_7[14];
                    vram_input_data_3[1][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_3[1][0]<= rom_font_8[0];
                    vram_input_data_3[1][1]<= rom_font_8[1];
                    vram_input_data_3[1][2]<= rom_font_8[2];
                    vram_input_data_3[1][3]<= rom_font_8[3];
                    vram_input_data_3[1][4]<= rom_font_8[4];
                    vram_input_data_3[1][5]<= rom_font_8[5];
                    vram_input_data_3[1][6]<= rom_font_8[6];
                    vram_input_data_3[1][7]<= rom_font_8[7];
                    vram_input_data_3[1][8]<= rom_font_8[8];
                    vram_input_data_3[1][9]<= rom_font_8[9];
                    vram_input_data_3[1][10]<= rom_font_8[10];
                    vram_input_data_3[1][11]<= rom_font_8[11];
                    vram_input_data_3[1][12]<= rom_font_8[12];
                    vram_input_data_3[1][13]<= rom_font_8[13];
                    vram_input_data_3[1][14]<= rom_font_8[14];
                    vram_input_data_3[1][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_3[1][0]<= rom_font_9[0];
                    vram_input_data_3[1][1]<= rom_font_9[1];
                    vram_input_data_3[1][2]<= rom_font_9[2];
                    vram_input_data_3[1][3]<= rom_font_9[3];
                    vram_input_data_3[1][4]<= rom_font_9[4];
                    vram_input_data_3[1][5]<= rom_font_9[5];
                    vram_input_data_3[1][6]<= rom_font_9[6];
                    vram_input_data_3[1][7]<= rom_font_9[7];
                    vram_input_data_3[1][8]<= rom_font_9[8];
                    vram_input_data_3[1][9]<= rom_font_9[9];
                    vram_input_data_3[1][10]<= rom_font_9[10];
                    vram_input_data_3[1][11]<= rom_font_9[11];
                    vram_input_data_3[1][12]<= rom_font_9[12];
                    vram_input_data_3[1][13]<= rom_font_9[13];
                    vram_input_data_3[1][14]<= rom_font_9[14];
                    vram_input_data_3[1][15]<= rom_font_9[15];
                end
            endcase case(user_data_rough_freq / 10000) // user_data_rough_freq的万位
                24'd0 : begin
                    vram_input_data_3[0][0]<= rom_font_0[0];
                    vram_input_data_3[0][1]<= rom_font_0[1];
                    vram_input_data_3[0][2]<= rom_font_0[2];
                    vram_input_data_3[0][3]<= rom_font_0[3];
                    vram_input_data_3[0][4]<= rom_font_0[4];
                    vram_input_data_3[0][5]<= rom_font_0[5];
                    vram_input_data_3[0][6]<= rom_font_0[6];
                    vram_input_data_3[0][7]<= rom_font_0[7];
                    vram_input_data_3[0][8]<= rom_font_0[8];
                    vram_input_data_3[0][9]<= rom_font_0[9];
                    vram_input_data_3[0][10]<= rom_font_0[10];
                    vram_input_data_3[0][11]<= rom_font_0[11];
                    vram_input_data_3[0][12]<= rom_font_0[12];
                    vram_input_data_3[0][13]<= rom_font_0[13];
                    vram_input_data_3[0][14]<= rom_font_0[14];
                    vram_input_data_3[0][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_3[0][0]<= rom_font_1[0];
                    vram_input_data_3[0][1]<= rom_font_1[1];
                    vram_input_data_3[0][2]<= rom_font_1[2];
                    vram_input_data_3[0][3]<= rom_font_1[3];
                    vram_input_data_3[0][4]<= rom_font_1[4];
                    vram_input_data_3[0][5]<= rom_font_1[5];
                    vram_input_data_3[0][6]<= rom_font_1[6];
                    vram_input_data_3[0][7]<= rom_font_1[7];
                    vram_input_data_3[0][8]<= rom_font_1[8];
                    vram_input_data_3[0][9]<= rom_font_1[9];
                    vram_input_data_3[0][10]<= rom_font_1[10];
                    vram_input_data_3[0][11]<= rom_font_1[11];
                    vram_input_data_3[0][12]<= rom_font_1[12];
                    vram_input_data_3[0][13]<= rom_font_1[13];
                    vram_input_data_3[0][14]<= rom_font_1[14];
                    vram_input_data_3[0][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_3[0][0]<= rom_font_2[0];
                    vram_input_data_3[0][1]<= rom_font_2[1];
                    vram_input_data_3[0][2]<= rom_font_2[2];
                    vram_input_data_3[0][3]<= rom_font_2[3];
                    vram_input_data_3[0][4]<= rom_font_2[4];
                    vram_input_data_3[0][5]<= rom_font_2[5];
                    vram_input_data_3[0][6]<= rom_font_2[6];
                    vram_input_data_3[0][7]<= rom_font_2[7];
                    vram_input_data_3[0][8]<= rom_font_2[8];
                    vram_input_data_3[0][9]<= rom_font_2[9];
                    vram_input_data_3[0][10]<= rom_font_2[10];
                    vram_input_data_3[0][11]<= rom_font_2[11];
                    vram_input_data_3[0][12]<= rom_font_2[12];
                    vram_input_data_3[0][13]<= rom_font_2[13];
                    vram_input_data_3[0][14]<= rom_font_2[14];
                    vram_input_data_3[0][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_3[0][0]<= rom_font_3[0];
                    vram_input_data_3[0][1]<= rom_font_3[1];
                    vram_input_data_3[0][2]<= rom_font_3[2];
                    vram_input_data_3[0][3]<= rom_font_3[3];
                    vram_input_data_3[0][4]<= rom_font_3[4];
                    vram_input_data_3[0][5]<= rom_font_3[5];
                    vram_input_data_3[0][6]<= rom_font_3[6];
                    vram_input_data_3[0][7]<= rom_font_3[7];
                    vram_input_data_3[0][8]<= rom_font_3[8];
                    vram_input_data_3[0][9]<= rom_font_3[9];
                    vram_input_data_3[0][10]<= rom_font_3[10];
                    vram_input_data_3[0][11]<= rom_font_3[11];
                    vram_input_data_3[0][12]<= rom_font_3[12];
                    vram_input_data_3[0][13]<= rom_font_3[13];
                    vram_input_data_3[0][14]<= rom_font_3[14];
                    vram_input_data_3[0][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_3[0][0]<= rom_font_4[0];
                    vram_input_data_3[0][1]<= rom_font_4[1];
                    vram_input_data_3[0][2]<= rom_font_4[2];
                    vram_input_data_3[0][3]<= rom_font_4[3];
                    vram_input_data_3[0][4]<= rom_font_4[4];
                    vram_input_data_3[0][5]<= rom_font_4[5];
                    vram_input_data_3[0][6]<= rom_font_4[6];
                    vram_input_data_3[0][7]<= rom_font_4[7];
                    vram_input_data_3[0][8]<= rom_font_4[8];
                    vram_input_data_3[0][9]<= rom_font_4[9];
                    vram_input_data_3[0][10]<= rom_font_4[10];
                    vram_input_data_3[0][11]<= rom_font_4[11];
                    vram_input_data_3[0][12]<= rom_font_4[12];
                    vram_input_data_3[0][13]<= rom_font_4[13];
                    vram_input_data_3[0][14]<= rom_font_4[14];
                    vram_input_data_3[0][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_3[0][0]<= rom_font_5[0];
                    vram_input_data_3[0][1]<= rom_font_5[1];
                    vram_input_data_3[0][2]<= rom_font_5[2];
                    vram_input_data_3[0][3]<= rom_font_5[3];
                    vram_input_data_3[0][4]<= rom_font_5[4];
                    vram_input_data_3[0][5]<= rom_font_5[5];
                    vram_input_data_3[0][6]<= rom_font_5[6];
                    vram_input_data_3[0][7]<= rom_font_5[7];
                    vram_input_data_3[0][8]<= rom_font_5[8];
                    vram_input_data_3[0][9]<= rom_font_5[9];
                    vram_input_data_3[0][10]<= rom_font_5[10];
                    vram_input_data_3[0][11]<= rom_font_5[11];
                    vram_input_data_3[0][12]<= rom_font_5[12];
                    vram_input_data_3[0][13]<= rom_font_5[13];
                    vram_input_data_3[0][14]<= rom_font_5[14];
                    vram_input_data_3[0][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_3[0][0]<= rom_font_6[0];
                    vram_input_data_3[0][1]<= rom_font_6[1];
                    vram_input_data_3[0][2]<= rom_font_6[2];
                    vram_input_data_3[0][3]<= rom_font_6[3];
                    vram_input_data_3[0][4]<= rom_font_6[4];
                    vram_input_data_3[0][5]<= rom_font_6[5];
                    vram_input_data_3[0][6]<= rom_font_6[6];
                    vram_input_data_3[0][7]<= rom_font_6[7];
                    vram_input_data_3[0][8]<= rom_font_6[8];
                    vram_input_data_3[0][9]<= rom_font_6[9];
                    vram_input_data_3[0][10]<= rom_font_6[10];
                    vram_input_data_3[0][11]<= rom_font_6[11];
                    vram_input_data_3[0][12]<= rom_font_6[12];
                    vram_input_data_3[0][13]<= rom_font_6[13];
                    vram_input_data_3[0][14]<= rom_font_6[14];
                    vram_input_data_3[0][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_3[0][0]<= rom_font_7[0];
                    vram_input_data_3[0][1]<= rom_font_7[1];
                    vram_input_data_3[0][2]<= rom_font_7[2];
                    vram_input_data_3[0][3]<= rom_font_7[3];
                    vram_input_data_3[0][4]<= rom_font_7[4];
                    vram_input_data_3[0][5]<= rom_font_7[5];
                    vram_input_data_3[0][6]<= rom_font_7[6];
                    vram_input_data_3[0][7]<= rom_font_7[7];
                    vram_input_data_3[0][8]<= rom_font_7[8];
                    vram_input_data_3[0][9]<= rom_font_7[9];
                    vram_input_data_3[0][10]<= rom_font_7[10];
                    vram_input_data_3[0][11]<= rom_font_7[11];
                    vram_input_data_3[0][12]<= rom_font_7[12];
                    vram_input_data_3[0][13]<= rom_font_7[13];
                    vram_input_data_3[0][14]<= rom_font_7[14];
                    vram_input_data_3[0][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_3[0][0]<= rom_font_8[0];
                    vram_input_data_3[0][1]<= rom_font_8[1];
                    vram_input_data_3[0][2]<= rom_font_8[2];
                    vram_input_data_3[0][3]<= rom_font_8[3];
                    vram_input_data_3[0][4]<= rom_font_8[4];
                    vram_input_data_3[0][5]<= rom_font_8[5];
                    vram_input_data_3[0][6]<= rom_font_8[6];
                    vram_input_data_3[0][7]<= rom_font_8[7];
                    vram_input_data_3[0][8]<= rom_font_8[8];
                    vram_input_data_3[0][9]<= rom_font_8[9];
                    vram_input_data_3[0][10]<= rom_font_8[10];
                    vram_input_data_3[0][11]<= rom_font_8[11];
                    vram_input_data_3[0][12]<= rom_font_8[12];
                    vram_input_data_3[0][13]<= rom_font_8[13];
                    vram_input_data_3[0][14]<= rom_font_8[14];
                    vram_input_data_3[0][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_3[0][0]<= rom_font_9[0];
                    vram_input_data_3[0][1]<= rom_font_9[1];
                    vram_input_data_3[0][2]<= rom_font_9[2];
                    vram_input_data_3[0][3]<= rom_font_9[3];
                    vram_input_data_3[0][4]<= rom_font_9[4];
                    vram_input_data_3[0][5]<= rom_font_9[5];
                    vram_input_data_3[0][6]<= rom_font_9[6];
                    vram_input_data_3[0][7]<= rom_font_9[7];
                    vram_input_data_3[0][8]<= rom_font_9[8];
                    vram_input_data_3[0][9]<= rom_font_9[9];
                    vram_input_data_3[0][10]<= rom_font_9[10];
                    vram_input_data_3[0][11]<= rom_font_9[11];
                    vram_input_data_3[0][12]<= rom_font_9[12];
                    vram_input_data_3[0][13]<= rom_font_9[13];
                    vram_input_data_3[0][14]<= rom_font_9[14];
                    vram_input_data_3[0][15]<= rom_font_9[15];
                end
            endcase 
            //------------------------------------------------------//
            case(user_data_accurate_freq % 10) // user_data_accurate_freq的个位
                24'd0 : begin
                    vram_input_data_4[4][0]<= rom_font_0[0];
                    vram_input_data_4[4][1]<= rom_font_0[1];
                    vram_input_data_4[4][2]<= rom_font_0[2];
                    vram_input_data_4[4][3]<= rom_font_0[3];
                    vram_input_data_4[4][4]<= rom_font_0[4];
                    vram_input_data_4[4][5]<= rom_font_0[5];
                    vram_input_data_4[4][6]<= rom_font_0[6];
                    vram_input_data_4[4][7]<= rom_font_0[7];
                    vram_input_data_4[4][8]<= rom_font_0[8];
                    vram_input_data_4[4][9]<= rom_font_0[9];
                    vram_input_data_4[4][10]<= rom_font_0[10];
                    vram_input_data_4[4][11]<= rom_font_0[11];
                    vram_input_data_4[4][12]<= rom_font_0[12];
                    vram_input_data_4[4][13]<= rom_font_0[13];
                    vram_input_data_4[4][14]<= rom_font_0[14];
                    vram_input_data_4[4][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_4[4][0]<= rom_font_1[0];
                    vram_input_data_4[4][1]<= rom_font_1[1];
                    vram_input_data_4[4][2]<= rom_font_1[2];
                    vram_input_data_4[4][3]<= rom_font_1[3];
                    vram_input_data_4[4][4]<= rom_font_1[4];
                    vram_input_data_4[4][5]<= rom_font_1[5];
                    vram_input_data_4[4][6]<= rom_font_1[6];
                    vram_input_data_4[4][7]<= rom_font_1[7];
                    vram_input_data_4[4][8]<= rom_font_1[8];
                    vram_input_data_4[4][9]<= rom_font_1[9];
                    vram_input_data_4[4][10]<= rom_font_1[10];
                    vram_input_data_4[4][11]<= rom_font_1[11];
                    vram_input_data_4[4][12]<= rom_font_1[12];
                    vram_input_data_4[4][13]<= rom_font_1[13];
                    vram_input_data_4[4][14]<= rom_font_1[14];
                    vram_input_data_4[4][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_4[4][0]<= rom_font_2[0];
                    vram_input_data_4[4][1]<= rom_font_2[1];
                    vram_input_data_4[4][2]<= rom_font_2[2];
                    vram_input_data_4[4][3]<= rom_font_2[3];
                    vram_input_data_4[4][4]<= rom_font_2[4];
                    vram_input_data_4[4][5]<= rom_font_2[5];
                    vram_input_data_4[4][6]<= rom_font_2[6];
                    vram_input_data_4[4][7]<= rom_font_2[7];
                    vram_input_data_4[4][8]<= rom_font_2[8];
                    vram_input_data_4[4][9]<= rom_font_2[9];
                    vram_input_data_4[4][10]<= rom_font_2[10];
                    vram_input_data_4[4][11]<= rom_font_2[11];
                    vram_input_data_4[4][12]<= rom_font_2[12];
                    vram_input_data_4[4][13]<= rom_font_2[13];
                    vram_input_data_4[4][14]<= rom_font_2[14];
                    vram_input_data_4[4][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_4[4][0]<= rom_font_3[0];
                    vram_input_data_4[4][1]<= rom_font_3[1];
                    vram_input_data_4[4][2]<= rom_font_3[2];
                    vram_input_data_4[4][3]<= rom_font_3[3];
                    vram_input_data_4[4][4]<= rom_font_3[4];
                    vram_input_data_4[4][5]<= rom_font_3[5];
                    vram_input_data_4[4][6]<= rom_font_3[6];
                    vram_input_data_4[4][7]<= rom_font_3[7];
                    vram_input_data_4[4][8]<= rom_font_3[8];
                    vram_input_data_4[4][9]<= rom_font_3[9];
                    vram_input_data_4[4][10]<= rom_font_3[10];
                    vram_input_data_4[4][11]<= rom_font_3[11];
                    vram_input_data_4[4][12]<= rom_font_3[12];
                    vram_input_data_4[4][13]<= rom_font_3[13];
                    vram_input_data_4[4][14]<= rom_font_3[14];
                    vram_input_data_4[4][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_4[4][0]<= rom_font_4[0];
                    vram_input_data_4[4][1]<= rom_font_4[1];
                    vram_input_data_4[4][2]<= rom_font_4[2];
                    vram_input_data_4[4][3]<= rom_font_4[3];
                    vram_input_data_4[4][4]<= rom_font_4[4];
                    vram_input_data_4[4][5]<= rom_font_4[5];
                    vram_input_data_4[4][6]<= rom_font_4[6];
                    vram_input_data_4[4][7]<= rom_font_4[7];
                    vram_input_data_4[4][8]<= rom_font_4[8];
                    vram_input_data_4[4][9]<= rom_font_4[9];
                    vram_input_data_4[4][10]<= rom_font_4[10];
                    vram_input_data_4[4][11]<= rom_font_4[11];
                    vram_input_data_4[4][12]<= rom_font_4[12];
                    vram_input_data_4[4][13]<= rom_font_4[13];
                    vram_input_data_4[4][14]<= rom_font_4[14];
                    vram_input_data_4[4][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_4[4][0]<= rom_font_5[0];
                    vram_input_data_4[4][1]<= rom_font_5[1];
                    vram_input_data_4[4][2]<= rom_font_5[2];
                    vram_input_data_4[4][3]<= rom_font_5[3];
                    vram_input_data_4[4][4]<= rom_font_5[4];
                    vram_input_data_4[4][5]<= rom_font_5[5];
                    vram_input_data_4[4][6]<= rom_font_5[6];
                    vram_input_data_4[4][7]<= rom_font_5[7];
                    vram_input_data_4[4][8]<= rom_font_5[8];
                    vram_input_data_4[4][9]<= rom_font_5[9];
                    vram_input_data_4[4][10]<= rom_font_5[10];
                    vram_input_data_4[4][11]<= rom_font_5[11];
                    vram_input_data_4[4][12]<= rom_font_5[12];
                    vram_input_data_4[4][13]<= rom_font_5[13];
                    vram_input_data_4[4][14]<= rom_font_5[14];
                    vram_input_data_4[4][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_4[4][0]<= rom_font_6[0];
                    vram_input_data_4[4][1]<= rom_font_6[1];
                    vram_input_data_4[4][2]<= rom_font_6[2];
                    vram_input_data_4[4][3]<= rom_font_6[3];
                    vram_input_data_4[4][4]<= rom_font_6[4];
                    vram_input_data_4[4][5]<= rom_font_6[5];
                    vram_input_data_4[4][6]<= rom_font_6[6];
                    vram_input_data_4[4][7]<= rom_font_6[7];
                    vram_input_data_4[4][8]<= rom_font_6[8];
                    vram_input_data_4[4][9]<= rom_font_6[9];
                    vram_input_data_4[4][10]<= rom_font_6[10];
                    vram_input_data_4[4][11]<= rom_font_6[11];
                    vram_input_data_4[4][12]<= rom_font_6[12];
                    vram_input_data_4[4][13]<= rom_font_6[13];
                    vram_input_data_4[4][14]<= rom_font_6[14];
                    vram_input_data_4[4][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_4[4][0]<= rom_font_7[0];
                    vram_input_data_4[4][1]<= rom_font_7[1];
                    vram_input_data_4[4][2]<= rom_font_7[2];
                    vram_input_data_4[4][3]<= rom_font_7[3];
                    vram_input_data_4[4][4]<= rom_font_7[4];
                    vram_input_data_4[4][5]<= rom_font_7[5];
                    vram_input_data_4[4][6]<= rom_font_7[6];
                    vram_input_data_4[4][7]<= rom_font_7[7];
                    vram_input_data_4[4][8]<= rom_font_7[8];
                    vram_input_data_4[4][9]<= rom_font_7[9];
                    vram_input_data_4[4][10]<= rom_font_7[10];
                    vram_input_data_4[4][11]<= rom_font_7[11];
                    vram_input_data_4[4][12]<= rom_font_7[12];
                    vram_input_data_4[4][13]<= rom_font_7[13];
                    vram_input_data_4[4][14]<= rom_font_7[14];
                    vram_input_data_4[4][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_4[4][0]<= rom_font_8[0];
                    vram_input_data_4[4][1]<= rom_font_8[1];
                    vram_input_data_4[4][2]<= rom_font_8[2];
                    vram_input_data_4[4][3]<= rom_font_8[3];
                    vram_input_data_4[4][4]<= rom_font_8[4];
                    vram_input_data_4[4][5]<= rom_font_8[5];
                    vram_input_data_4[4][6]<= rom_font_8[6];
                    vram_input_data_4[4][7]<= rom_font_8[7];
                    vram_input_data_4[4][8]<= rom_font_8[8];
                    vram_input_data_4[4][9]<= rom_font_8[9];
                    vram_input_data_4[4][10]<= rom_font_8[10];
                    vram_input_data_4[4][11]<= rom_font_8[11];
                    vram_input_data_4[4][12]<= rom_font_8[12];
                    vram_input_data_4[4][13]<= rom_font_8[13];
                    vram_input_data_4[4][14]<= rom_font_8[14];
                    vram_input_data_4[4][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_4[4][0]<= rom_font_9[0];
                    vram_input_data_4[4][1]<= rom_font_9[1];
                    vram_input_data_4[4][2]<= rom_font_9[2];
                    vram_input_data_4[4][3]<= rom_font_9[3];
                    vram_input_data_4[4][4]<= rom_font_9[4];
                    vram_input_data_4[4][5]<= rom_font_9[5];
                    vram_input_data_4[4][6]<= rom_font_9[6];
                    vram_input_data_4[4][7]<= rom_font_9[7];
                    vram_input_data_4[4][8]<= rom_font_9[8];
                    vram_input_data_4[4][9]<= rom_font_9[9];
                    vram_input_data_4[4][10]<= rom_font_9[10];
                    vram_input_data_4[4][11]<= rom_font_9[11];
                    vram_input_data_4[4][12]<= rom_font_9[12];
                    vram_input_data_4[4][13]<= rom_font_9[13];
                    vram_input_data_4[4][14]<= rom_font_9[14];
                    vram_input_data_4[4][15]<= rom_font_9[15];
                end
            endcase case((user_data_accurate_freq % 100) / 10) // user_data_accurate_freq的十位
                24'd0 : begin
                    vram_input_data_4[3][0]<= rom_font_0[0];
                    vram_input_data_4[3][1]<= rom_font_0[1];
                    vram_input_data_4[3][2]<= rom_font_0[2];
                    vram_input_data_4[3][3]<= rom_font_0[3];
                    vram_input_data_4[3][4]<= rom_font_0[4];
                    vram_input_data_4[3][5]<= rom_font_0[5];
                    vram_input_data_4[3][6]<= rom_font_0[6];
                    vram_input_data_4[3][7]<= rom_font_0[7];
                    vram_input_data_4[3][8]<= rom_font_0[8];
                    vram_input_data_4[3][9]<= rom_font_0[9];
                    vram_input_data_4[3][10]<= rom_font_0[10];
                    vram_input_data_4[3][11]<= rom_font_0[11];
                    vram_input_data_4[3][12]<= rom_font_0[12];
                    vram_input_data_4[3][13]<= rom_font_0[13];
                    vram_input_data_4[3][14]<= rom_font_0[14];
                    vram_input_data_4[3][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_4[3][0]<= rom_font_1[0];
                    vram_input_data_4[3][1]<= rom_font_1[1];
                    vram_input_data_4[3][2]<= rom_font_1[2];
                    vram_input_data_4[3][3]<= rom_font_1[3];
                    vram_input_data_4[3][4]<= rom_font_1[4];
                    vram_input_data_4[3][5]<= rom_font_1[5];
                    vram_input_data_4[3][6]<= rom_font_1[6];
                    vram_input_data_4[3][7]<= rom_font_1[7];
                    vram_input_data_4[3][8]<= rom_font_1[8];
                    vram_input_data_4[3][9]<= rom_font_1[9];
                    vram_input_data_4[3][10]<= rom_font_1[10];
                    vram_input_data_4[3][11]<= rom_font_1[11];
                    vram_input_data_4[3][12]<= rom_font_1[12];
                    vram_input_data_4[3][13]<= rom_font_1[13];
                    vram_input_data_4[3][14]<= rom_font_1[14];
                    vram_input_data_4[3][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_4[3][0]<= rom_font_2[0];
                    vram_input_data_4[3][1]<= rom_font_2[1];
                    vram_input_data_4[3][2]<= rom_font_2[2];
                    vram_input_data_4[3][3]<= rom_font_2[3];
                    vram_input_data_4[3][4]<= rom_font_2[4];
                    vram_input_data_4[3][5]<= rom_font_2[5];
                    vram_input_data_4[3][6]<= rom_font_2[6];
                    vram_input_data_4[3][7]<= rom_font_2[7];
                    vram_input_data_4[3][8]<= rom_font_2[8];
                    vram_input_data_4[3][9]<= rom_font_2[9];
                    vram_input_data_4[3][10]<= rom_font_2[10];
                    vram_input_data_4[3][11]<= rom_font_2[11];
                    vram_input_data_4[3][12]<= rom_font_2[12];
                    vram_input_data_4[3][13]<= rom_font_2[13];
                    vram_input_data_4[3][14]<= rom_font_2[14];
                    vram_input_data_4[3][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_4[3][0]<= rom_font_3[0];
                    vram_input_data_4[3][1]<= rom_font_3[1];
                    vram_input_data_4[3][2]<= rom_font_3[2];
                    vram_input_data_4[3][3]<= rom_font_3[3];
                    vram_input_data_4[3][4]<= rom_font_3[4];
                    vram_input_data_4[3][5]<= rom_font_3[5];
                    vram_input_data_4[3][6]<= rom_font_3[6];
                    vram_input_data_4[3][7]<= rom_font_3[7];
                    vram_input_data_4[3][8]<= rom_font_3[8];
                    vram_input_data_4[3][9]<= rom_font_3[9];
                    vram_input_data_4[3][10]<= rom_font_3[10];
                    vram_input_data_4[3][11]<= rom_font_3[11];
                    vram_input_data_4[3][12]<= rom_font_3[12];
                    vram_input_data_4[3][13]<= rom_font_3[13];
                    vram_input_data_4[3][14]<= rom_font_3[14];
                    vram_input_data_4[3][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_4[3][0]<= rom_font_4[0];
                    vram_input_data_4[3][1]<= rom_font_4[1];
                    vram_input_data_4[3][2]<= rom_font_4[2];
                    vram_input_data_4[3][3]<= rom_font_4[3];
                    vram_input_data_4[3][4]<= rom_font_4[4];
                    vram_input_data_4[3][5]<= rom_font_4[5];
                    vram_input_data_4[3][6]<= rom_font_4[6];
                    vram_input_data_4[3][7]<= rom_font_4[7];
                    vram_input_data_4[3][8]<= rom_font_4[8];
                    vram_input_data_4[3][9]<= rom_font_4[9];
                    vram_input_data_4[3][10]<= rom_font_4[10];
                    vram_input_data_4[3][11]<= rom_font_4[11];
                    vram_input_data_4[3][12]<= rom_font_4[12];
                    vram_input_data_4[3][13]<= rom_font_4[13];
                    vram_input_data_4[3][14]<= rom_font_4[14];
                    vram_input_data_4[3][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_4[3][0]<= rom_font_5[0];
                    vram_input_data_4[3][1]<= rom_font_5[1];
                    vram_input_data_4[3][2]<= rom_font_5[2];
                    vram_input_data_4[3][3]<= rom_font_5[3];
                    vram_input_data_4[3][4]<= rom_font_5[4];
                    vram_input_data_4[3][5]<= rom_font_5[5];
                    vram_input_data_4[3][6]<= rom_font_5[6];
                    vram_input_data_4[3][7]<= rom_font_5[7];
                    vram_input_data_4[3][8]<= rom_font_5[8];
                    vram_input_data_4[3][9]<= rom_font_5[9];
                    vram_input_data_4[3][10]<= rom_font_5[10];
                    vram_input_data_4[3][11]<= rom_font_5[11];
                    vram_input_data_4[3][12]<= rom_font_5[12];
                    vram_input_data_4[3][13]<= rom_font_5[13];
                    vram_input_data_4[3][14]<= rom_font_5[14];
                    vram_input_data_4[3][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_4[3][0]<= rom_font_6[0];
                    vram_input_data_4[3][1]<= rom_font_6[1];
                    vram_input_data_4[3][2]<= rom_font_6[2];
                    vram_input_data_4[3][3]<= rom_font_6[3];
                    vram_input_data_4[3][4]<= rom_font_6[4];
                    vram_input_data_4[3][5]<= rom_font_6[5];
                    vram_input_data_4[3][6]<= rom_font_6[6];
                    vram_input_data_4[3][7]<= rom_font_6[7];
                    vram_input_data_4[3][8]<= rom_font_6[8];
                    vram_input_data_4[3][9]<= rom_font_6[9];
                    vram_input_data_4[3][10]<= rom_font_6[10];
                    vram_input_data_4[3][11]<= rom_font_6[11];
                    vram_input_data_4[3][12]<= rom_font_6[12];
                    vram_input_data_4[3][13]<= rom_font_6[13];
                    vram_input_data_4[3][14]<= rom_font_6[14];
                    vram_input_data_4[3][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_4[3][0]<= rom_font_7[0];
                    vram_input_data_4[3][1]<= rom_font_7[1];
                    vram_input_data_4[3][2]<= rom_font_7[2];
                    vram_input_data_4[3][3]<= rom_font_7[3];
                    vram_input_data_4[3][4]<= rom_font_7[4];
                    vram_input_data_4[3][5]<= rom_font_7[5];
                    vram_input_data_4[3][6]<= rom_font_7[6];
                    vram_input_data_4[3][7]<= rom_font_7[7];
                    vram_input_data_4[3][8]<= rom_font_7[8];
                    vram_input_data_4[3][9]<= rom_font_7[9];
                    vram_input_data_4[3][10]<= rom_font_7[10];
                    vram_input_data_4[3][11]<= rom_font_7[11];
                    vram_input_data_4[3][12]<= rom_font_7[12];
                    vram_input_data_4[3][13]<= rom_font_7[13];
                    vram_input_data_4[3][14]<= rom_font_7[14];
                    vram_input_data_4[3][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_4[3][0]<= rom_font_8[0];
                    vram_input_data_4[3][1]<= rom_font_8[1];
                    vram_input_data_4[3][2]<= rom_font_8[2];
                    vram_input_data_4[3][3]<= rom_font_8[3];
                    vram_input_data_4[3][4]<= rom_font_8[4];
                    vram_input_data_4[3][5]<= rom_font_8[5];
                    vram_input_data_4[3][6]<= rom_font_8[6];
                    vram_input_data_4[3][7]<= rom_font_8[7];
                    vram_input_data_4[3][8]<= rom_font_8[8];
                    vram_input_data_4[3][9]<= rom_font_8[9];
                    vram_input_data_4[3][10]<= rom_font_8[10];
                    vram_input_data_4[3][11]<= rom_font_8[11];
                    vram_input_data_4[3][12]<= rom_font_8[12];
                    vram_input_data_4[3][13]<= rom_font_8[13];
                    vram_input_data_4[3][14]<= rom_font_8[14];
                    vram_input_data_4[3][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_4[3][0]<= rom_font_9[0];
                    vram_input_data_4[3][1]<= rom_font_9[1];
                    vram_input_data_4[3][2]<= rom_font_9[2];
                    vram_input_data_4[3][3]<= rom_font_9[3];
                    vram_input_data_4[3][4]<= rom_font_9[4];
                    vram_input_data_4[3][5]<= rom_font_9[5];
                    vram_input_data_4[3][6]<= rom_font_9[6];
                    vram_input_data_4[3][7]<= rom_font_9[7];
                    vram_input_data_4[3][8]<= rom_font_9[8];
                    vram_input_data_4[3][9]<= rom_font_9[9];
                    vram_input_data_4[3][10]<= rom_font_9[10];
                    vram_input_data_4[3][11]<= rom_font_9[11];
                    vram_input_data_4[3][12]<= rom_font_9[12];
                    vram_input_data_4[3][13]<= rom_font_9[13];
                    vram_input_data_4[3][14]<= rom_font_9[14];
                    vram_input_data_4[3][15]<= rom_font_9[15];
                end
            endcase case((user_data_accurate_freq % 1000) / 100) // user_data_accurate_freq的百位
                24'd0 : begin
                    vram_input_data_4[2][0]<= rom_font_0[0];
                    vram_input_data_4[2][1]<= rom_font_0[1];
                    vram_input_data_4[2][2]<= rom_font_0[2];
                    vram_input_data_4[2][3]<= rom_font_0[3];
                    vram_input_data_4[2][4]<= rom_font_0[4];
                    vram_input_data_4[2][5]<= rom_font_0[5];
                    vram_input_data_4[2][6]<= rom_font_0[6];
                    vram_input_data_4[2][7]<= rom_font_0[7];
                    vram_input_data_4[2][8]<= rom_font_0[8];
                    vram_input_data_4[2][9]<= rom_font_0[9];
                    vram_input_data_4[2][10]<= rom_font_0[10];
                    vram_input_data_4[2][11]<= rom_font_0[11];
                    vram_input_data_4[2][12]<= rom_font_0[12];
                    vram_input_data_4[2][13]<= rom_font_0[13];
                    vram_input_data_4[2][14]<= rom_font_0[14];
                    vram_input_data_4[2][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_4[2][0]<= rom_font_1[0];
                    vram_input_data_4[2][1]<= rom_font_1[1];
                    vram_input_data_4[2][2]<= rom_font_1[2];
                    vram_input_data_4[2][3]<= rom_font_1[3];
                    vram_input_data_4[2][4]<= rom_font_1[4];
                    vram_input_data_4[2][5]<= rom_font_1[5];
                    vram_input_data_4[2][6]<= rom_font_1[6];
                    vram_input_data_4[2][7]<= rom_font_1[7];
                    vram_input_data_4[2][8]<= rom_font_1[8];
                    vram_input_data_4[2][9]<= rom_font_1[9];
                    vram_input_data_4[2][10]<= rom_font_1[10];
                    vram_input_data_4[2][11]<= rom_font_1[11];
                    vram_input_data_4[2][12]<= rom_font_1[12];
                    vram_input_data_4[2][13]<= rom_font_1[13];
                    vram_input_data_4[2][14]<= rom_font_1[14];
                    vram_input_data_4[2][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_4[2][0]<= rom_font_2[0];
                    vram_input_data_4[2][1]<= rom_font_2[1];
                    vram_input_data_4[2][2]<= rom_font_2[2];
                    vram_input_data_4[2][3]<= rom_font_2[3];
                    vram_input_data_4[2][4]<= rom_font_2[4];
                    vram_input_data_4[2][5]<= rom_font_2[5];
                    vram_input_data_4[2][6]<= rom_font_2[6];
                    vram_input_data_4[2][7]<= rom_font_2[7];
                    vram_input_data_4[2][8]<= rom_font_2[8];
                    vram_input_data_4[2][9]<= rom_font_2[9];
                    vram_input_data_4[2][10]<= rom_font_2[10];
                    vram_input_data_4[2][11]<= rom_font_2[11];
                    vram_input_data_4[2][12]<= rom_font_2[12];
                    vram_input_data_4[2][13]<= rom_font_2[13];
                    vram_input_data_4[2][14]<= rom_font_2[14];
                    vram_input_data_4[2][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_4[2][0]<= rom_font_3[0];
                    vram_input_data_4[2][1]<= rom_font_3[1];
                    vram_input_data_4[2][2]<= rom_font_3[2];
                    vram_input_data_4[2][3]<= rom_font_3[3];
                    vram_input_data_4[2][4]<= rom_font_3[4];
                    vram_input_data_4[2][5]<= rom_font_3[5];
                    vram_input_data_4[2][6]<= rom_font_3[6];
                    vram_input_data_4[2][7]<= rom_font_3[7];
                    vram_input_data_4[2][8]<= rom_font_3[8];
                    vram_input_data_4[2][9]<= rom_font_3[9];
                    vram_input_data_4[2][10]<= rom_font_3[10];
                    vram_input_data_4[2][11]<= rom_font_3[11];
                    vram_input_data_4[2][12]<= rom_font_3[12];
                    vram_input_data_4[2][13]<= rom_font_3[13];
                    vram_input_data_4[2][14]<= rom_font_3[14];
                    vram_input_data_4[2][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_4[2][0]<= rom_font_4[0];
                    vram_input_data_4[2][1]<= rom_font_4[1];
                    vram_input_data_4[2][2]<= rom_font_4[2];
                    vram_input_data_4[2][3]<= rom_font_4[3];
                    vram_input_data_4[2][4]<= rom_font_4[4];
                    vram_input_data_4[2][5]<= rom_font_4[5];
                    vram_input_data_4[2][6]<= rom_font_4[6];
                    vram_input_data_4[2][7]<= rom_font_4[7];
                    vram_input_data_4[2][8]<= rom_font_4[8];
                    vram_input_data_4[2][9]<= rom_font_4[9];
                    vram_input_data_4[2][10]<= rom_font_4[10];
                    vram_input_data_4[2][11]<= rom_font_4[11];
                    vram_input_data_4[2][12]<= rom_font_4[12];
                    vram_input_data_4[2][13]<= rom_font_4[13];
                    vram_input_data_4[2][14]<= rom_font_4[14];
                    vram_input_data_4[2][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_4[2][0]<= rom_font_5[0];
                    vram_input_data_4[2][1]<= rom_font_5[1];
                    vram_input_data_4[2][2]<= rom_font_5[2];
                    vram_input_data_4[2][3]<= rom_font_5[3];
                    vram_input_data_4[2][4]<= rom_font_5[4];
                    vram_input_data_4[2][5]<= rom_font_5[5];
                    vram_input_data_4[2][6]<= rom_font_5[6];
                    vram_input_data_4[2][7]<= rom_font_5[7];
                    vram_input_data_4[2][8]<= rom_font_5[8];
                    vram_input_data_4[2][9]<= rom_font_5[9];
                    vram_input_data_4[2][10]<= rom_font_5[10];
                    vram_input_data_4[2][11]<= rom_font_5[11];
                    vram_input_data_4[2][12]<= rom_font_5[12];
                    vram_input_data_4[2][13]<= rom_font_5[13];
                    vram_input_data_4[2][14]<= rom_font_5[14];
                    vram_input_data_4[2][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_4[2][0]<= rom_font_6[0];
                    vram_input_data_4[2][1]<= rom_font_6[1];
                    vram_input_data_4[2][2]<= rom_font_6[2];
                    vram_input_data_4[2][3]<= rom_font_6[3];
                    vram_input_data_4[2][4]<= rom_font_6[4];
                    vram_input_data_4[2][5]<= rom_font_6[5];
                    vram_input_data_4[2][6]<= rom_font_6[6];
                    vram_input_data_4[2][7]<= rom_font_6[7];
                    vram_input_data_4[2][8]<= rom_font_6[8];
                    vram_input_data_4[2][9]<= rom_font_6[9];
                    vram_input_data_4[2][10]<= rom_font_6[10];
                    vram_input_data_4[2][11]<= rom_font_6[11];
                    vram_input_data_4[2][12]<= rom_font_6[12];
                    vram_input_data_4[2][13]<= rom_font_6[13];
                    vram_input_data_4[2][14]<= rom_font_6[14];
                    vram_input_data_4[2][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_4[2][0]<= rom_font_7[0];
                    vram_input_data_4[2][1]<= rom_font_7[1];
                    vram_input_data_4[2][2]<= rom_font_7[2];
                    vram_input_data_4[2][3]<= rom_font_7[3];
                    vram_input_data_4[2][4]<= rom_font_7[4];
                    vram_input_data_4[2][5]<= rom_font_7[5];
                    vram_input_data_4[2][6]<= rom_font_7[6];
                    vram_input_data_4[2][7]<= rom_font_7[7];
                    vram_input_data_4[2][8]<= rom_font_7[8];
                    vram_input_data_4[2][9]<= rom_font_7[9];
                    vram_input_data_4[2][10]<= rom_font_7[10];
                    vram_input_data_4[2][11]<= rom_font_7[11];
                    vram_input_data_4[2][12]<= rom_font_7[12];
                    vram_input_data_4[2][13]<= rom_font_7[13];
                    vram_input_data_4[2][14]<= rom_font_7[14];
                    vram_input_data_4[2][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_4[2][0]<= rom_font_8[0];
                    vram_input_data_4[2][1]<= rom_font_8[1];
                    vram_input_data_4[2][2]<= rom_font_8[2];
                    vram_input_data_4[2][3]<= rom_font_8[3];
                    vram_input_data_4[2][4]<= rom_font_8[4];
                    vram_input_data_4[2][5]<= rom_font_8[5];
                    vram_input_data_4[2][6]<= rom_font_8[6];
                    vram_input_data_4[2][7]<= rom_font_8[7];
                    vram_input_data_4[2][8]<= rom_font_8[8];
                    vram_input_data_4[2][9]<= rom_font_8[9];
                    vram_input_data_4[2][10]<= rom_font_8[10];
                    vram_input_data_4[2][11]<= rom_font_8[11];
                    vram_input_data_4[2][12]<= rom_font_8[12];
                    vram_input_data_4[2][13]<= rom_font_8[13];
                    vram_input_data_4[2][14]<= rom_font_8[14];
                    vram_input_data_4[2][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_4[2][0]<= rom_font_9[0];
                    vram_input_data_4[2][1]<= rom_font_9[1];
                    vram_input_data_4[2][2]<= rom_font_9[2];
                    vram_input_data_4[2][3]<= rom_font_9[3];
                    vram_input_data_4[2][4]<= rom_font_9[4];
                    vram_input_data_4[2][5]<= rom_font_9[5];
                    vram_input_data_4[2][6]<= rom_font_9[6];
                    vram_input_data_4[2][7]<= rom_font_9[7];
                    vram_input_data_4[2][8]<= rom_font_9[8];
                    vram_input_data_4[2][9]<= rom_font_9[9];
                    vram_input_data_4[2][10]<= rom_font_9[10];
                    vram_input_data_4[2][11]<= rom_font_9[11];
                    vram_input_data_4[2][12]<= rom_font_9[12];
                    vram_input_data_4[2][13]<= rom_font_9[13];
                    vram_input_data_4[2][14]<= rom_font_9[14];
                    vram_input_data_4[2][15]<= rom_font_9[15];
                end
            endcase case((user_data_accurate_freq % 10000) / 1000) // user_data_accurate_freq的千位
                24'd0 : begin
                    vram_input_data_4[1][0]<= rom_font_0[0];
                    vram_input_data_4[1][1]<= rom_font_0[1];
                    vram_input_data_4[1][2]<= rom_font_0[2];
                    vram_input_data_4[1][3]<= rom_font_0[3];
                    vram_input_data_4[1][4]<= rom_font_0[4];
                    vram_input_data_4[1][5]<= rom_font_0[5];
                    vram_input_data_4[1][6]<= rom_font_0[6];
                    vram_input_data_4[1][7]<= rom_font_0[7];
                    vram_input_data_4[1][8]<= rom_font_0[8];
                    vram_input_data_4[1][9]<= rom_font_0[9];
                    vram_input_data_4[1][10]<= rom_font_0[10];
                    vram_input_data_4[1][11]<= rom_font_0[11];
                    vram_input_data_4[1][12]<= rom_font_0[12];
                    vram_input_data_4[1][13]<= rom_font_0[13];
                    vram_input_data_4[1][14]<= rom_font_0[14];
                    vram_input_data_4[1][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_4[1][0]<= rom_font_1[0];
                    vram_input_data_4[1][1]<= rom_font_1[1];
                    vram_input_data_4[1][2]<= rom_font_1[2];
                    vram_input_data_4[1][3]<= rom_font_1[3];
                    vram_input_data_4[1][4]<= rom_font_1[4];
                    vram_input_data_4[1][5]<= rom_font_1[5];
                    vram_input_data_4[1][6]<= rom_font_1[6];
                    vram_input_data_4[1][7]<= rom_font_1[7];
                    vram_input_data_4[1][8]<= rom_font_1[8];
                    vram_input_data_4[1][9]<= rom_font_1[9];
                    vram_input_data_4[1][10]<= rom_font_1[10];
                    vram_input_data_4[1][11]<= rom_font_1[11];
                    vram_input_data_4[1][12]<= rom_font_1[12];
                    vram_input_data_4[1][13]<= rom_font_1[13];
                    vram_input_data_4[1][14]<= rom_font_1[14];
                    vram_input_data_4[1][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_4[1][0]<= rom_font_2[0];
                    vram_input_data_4[1][1]<= rom_font_2[1];
                    vram_input_data_4[1][2]<= rom_font_2[2];
                    vram_input_data_4[1][3]<= rom_font_2[3];
                    vram_input_data_4[1][4]<= rom_font_2[4];
                    vram_input_data_4[1][5]<= rom_font_2[5];
                    vram_input_data_4[1][6]<= rom_font_2[6];
                    vram_input_data_4[1][7]<= rom_font_2[7];
                    vram_input_data_4[1][8]<= rom_font_2[8];
                    vram_input_data_4[1][9]<= rom_font_2[9];
                    vram_input_data_4[1][10]<= rom_font_2[10];
                    vram_input_data_4[1][11]<= rom_font_2[11];
                    vram_input_data_4[1][12]<= rom_font_2[12];
                    vram_input_data_4[1][13]<= rom_font_2[13];
                    vram_input_data_4[1][14]<= rom_font_2[14];
                    vram_input_data_4[1][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_4[1][0]<= rom_font_3[0];
                    vram_input_data_4[1][1]<= rom_font_3[1];
                    vram_input_data_4[1][2]<= rom_font_3[2];
                    vram_input_data_4[1][3]<= rom_font_3[3];
                    vram_input_data_4[1][4]<= rom_font_3[4];
                    vram_input_data_4[1][5]<= rom_font_3[5];
                    vram_input_data_4[1][6]<= rom_font_3[6];
                    vram_input_data_4[1][7]<= rom_font_3[7];
                    vram_input_data_4[1][8]<= rom_font_3[8];
                    vram_input_data_4[1][9]<= rom_font_3[9];
                    vram_input_data_4[1][10]<= rom_font_3[10];
                    vram_input_data_4[1][11]<= rom_font_3[11];
                    vram_input_data_4[1][12]<= rom_font_3[12];
                    vram_input_data_4[1][13]<= rom_font_3[13];
                    vram_input_data_4[1][14]<= rom_font_3[14];
                    vram_input_data_4[1][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_4[1][0]<= rom_font_4[0];
                    vram_input_data_4[1][1]<= rom_font_4[1];
                    vram_input_data_4[1][2]<= rom_font_4[2];
                    vram_input_data_4[1][3]<= rom_font_4[3];
                    vram_input_data_4[1][4]<= rom_font_4[4];
                    vram_input_data_4[1][5]<= rom_font_4[5];
                    vram_input_data_4[1][6]<= rom_font_4[6];
                    vram_input_data_4[1][7]<= rom_font_4[7];
                    vram_input_data_4[1][8]<= rom_font_4[8];
                    vram_input_data_4[1][9]<= rom_font_4[9];
                    vram_input_data_4[1][10]<= rom_font_4[10];
                    vram_input_data_4[1][11]<= rom_font_4[11];
                    vram_input_data_4[1][12]<= rom_font_4[12];
                    vram_input_data_4[1][13]<= rom_font_4[13];
                    vram_input_data_4[1][14]<= rom_font_4[14];
                    vram_input_data_4[1][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_4[1][0]<= rom_font_5[0];
                    vram_input_data_4[1][1]<= rom_font_5[1];
                    vram_input_data_4[1][2]<= rom_font_5[2];
                    vram_input_data_4[1][3]<= rom_font_5[3];
                    vram_input_data_4[1][4]<= rom_font_5[4];
                    vram_input_data_4[1][5]<= rom_font_5[5];
                    vram_input_data_4[1][6]<= rom_font_5[6];
                    vram_input_data_4[1][7]<= rom_font_5[7];
                    vram_input_data_4[1][8]<= rom_font_5[8];
                    vram_input_data_4[1][9]<= rom_font_5[9];
                    vram_input_data_4[1][10]<= rom_font_5[10];
                    vram_input_data_4[1][11]<= rom_font_5[11];
                    vram_input_data_4[1][12]<= rom_font_5[12];
                    vram_input_data_4[1][13]<= rom_font_5[13];
                    vram_input_data_4[1][14]<= rom_font_5[14];
                    vram_input_data_4[1][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_4[1][0]<= rom_font_6[0];
                    vram_input_data_4[1][1]<= rom_font_6[1];
                    vram_input_data_4[1][2]<= rom_font_6[2];
                    vram_input_data_4[1][3]<= rom_font_6[3];
                    vram_input_data_4[1][4]<= rom_font_6[4];
                    vram_input_data_4[1][5]<= rom_font_6[5];
                    vram_input_data_4[1][6]<= rom_font_6[6];
                    vram_input_data_4[1][7]<= rom_font_6[7];
                    vram_input_data_4[1][8]<= rom_font_6[8];
                    vram_input_data_4[1][9]<= rom_font_6[9];
                    vram_input_data_4[1][10]<= rom_font_6[10];
                    vram_input_data_4[1][11]<= rom_font_6[11];
                    vram_input_data_4[1][12]<= rom_font_6[12];
                    vram_input_data_4[1][13]<= rom_font_6[13];
                    vram_input_data_4[1][14]<= rom_font_6[14];
                    vram_input_data_4[1][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_4[1][0]<= rom_font_7[0];
                    vram_input_data_4[1][1]<= rom_font_7[1];
                    vram_input_data_4[1][2]<= rom_font_7[2];
                    vram_input_data_4[1][3]<= rom_font_7[3];
                    vram_input_data_4[1][4]<= rom_font_7[4];
                    vram_input_data_4[1][5]<= rom_font_7[5];
                    vram_input_data_4[1][6]<= rom_font_7[6];
                    vram_input_data_4[1][7]<= rom_font_7[7];
                    vram_input_data_4[1][8]<= rom_font_7[8];
                    vram_input_data_4[1][9]<= rom_font_7[9];
                    vram_input_data_4[1][10]<= rom_font_7[10];
                    vram_input_data_4[1][11]<= rom_font_7[11];
                    vram_input_data_4[1][12]<= rom_font_7[12];
                    vram_input_data_4[1][13]<= rom_font_7[13];
                    vram_input_data_4[1][14]<= rom_font_7[14];
                    vram_input_data_4[1][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_4[1][0]<= rom_font_8[0];
                    vram_input_data_4[1][1]<= rom_font_8[1];
                    vram_input_data_4[1][2]<= rom_font_8[2];
                    vram_input_data_4[1][3]<= rom_font_8[3];
                    vram_input_data_4[1][4]<= rom_font_8[4];
                    vram_input_data_4[1][5]<= rom_font_8[5];
                    vram_input_data_4[1][6]<= rom_font_8[6];
                    vram_input_data_4[1][7]<= rom_font_8[7];
                    vram_input_data_4[1][8]<= rom_font_8[8];
                    vram_input_data_4[1][9]<= rom_font_8[9];
                    vram_input_data_4[1][10]<= rom_font_8[10];
                    vram_input_data_4[1][11]<= rom_font_8[11];
                    vram_input_data_4[1][12]<= rom_font_8[12];
                    vram_input_data_4[1][13]<= rom_font_8[13];
                    vram_input_data_4[1][14]<= rom_font_8[14];
                    vram_input_data_4[1][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_4[1][0]<= rom_font_9[0];
                    vram_input_data_4[1][1]<= rom_font_9[1];
                    vram_input_data_4[1][2]<= rom_font_9[2];
                    vram_input_data_4[1][3]<= rom_font_9[3];
                    vram_input_data_4[1][4]<= rom_font_9[4];
                    vram_input_data_4[1][5]<= rom_font_9[5];
                    vram_input_data_4[1][6]<= rom_font_9[6];
                    vram_input_data_4[1][7]<= rom_font_9[7];
                    vram_input_data_4[1][8]<= rom_font_9[8];
                    vram_input_data_4[1][9]<= rom_font_9[9];
                    vram_input_data_4[1][10]<= rom_font_9[10];
                    vram_input_data_4[1][11]<= rom_font_9[11];
                    vram_input_data_4[1][12]<= rom_font_9[12];
                    vram_input_data_4[1][13]<= rom_font_9[13];
                    vram_input_data_4[1][14]<= rom_font_9[14];
                    vram_input_data_4[1][15]<= rom_font_9[15];
                end
            endcase case(user_data_accurate_freq / 10000) // user_data_accurate_freq的万位
                24'd0 : begin
                    vram_input_data_4[0][0]<= rom_font_0[0];
                    vram_input_data_4[0][1]<= rom_font_0[1];
                    vram_input_data_4[0][2]<= rom_font_0[2];
                    vram_input_data_4[0][3]<= rom_font_0[3];
                    vram_input_data_4[0][4]<= rom_font_0[4];
                    vram_input_data_4[0][5]<= rom_font_0[5];
                    vram_input_data_4[0][6]<= rom_font_0[6];
                    vram_input_data_4[0][7]<= rom_font_0[7];
                    vram_input_data_4[0][8]<= rom_font_0[8];
                    vram_input_data_4[0][9]<= rom_font_0[9];
                    vram_input_data_4[0][10]<= rom_font_0[10];
                    vram_input_data_4[0][11]<= rom_font_0[11];
                    vram_input_data_4[0][12]<= rom_font_0[12];
                    vram_input_data_4[0][13]<= rom_font_0[13];
                    vram_input_data_4[0][14]<= rom_font_0[14];
                    vram_input_data_4[0][15]<= rom_font_0[15];
                end 24'd1 : begin
                    vram_input_data_4[0][0]<= rom_font_1[0];
                    vram_input_data_4[0][1]<= rom_font_1[1];
                    vram_input_data_4[0][2]<= rom_font_1[2];
                    vram_input_data_4[0][3]<= rom_font_1[3];
                    vram_input_data_4[0][4]<= rom_font_1[4];
                    vram_input_data_4[0][5]<= rom_font_1[5];
                    vram_input_data_4[0][6]<= rom_font_1[6];
                    vram_input_data_4[0][7]<= rom_font_1[7];
                    vram_input_data_4[0][8]<= rom_font_1[8];
                    vram_input_data_4[0][9]<= rom_font_1[9];
                    vram_input_data_4[0][10]<= rom_font_1[10];
                    vram_input_data_4[0][11]<= rom_font_1[11];
                    vram_input_data_4[0][12]<= rom_font_1[12];
                    vram_input_data_4[0][13]<= rom_font_1[13];
                    vram_input_data_4[0][14]<= rom_font_1[14];
                    vram_input_data_4[0][15]<= rom_font_1[15];
                end 24'd2 : begin
                    vram_input_data_4[0][0]<= rom_font_2[0];
                    vram_input_data_4[0][1]<= rom_font_2[1];
                    vram_input_data_4[0][2]<= rom_font_2[2];
                    vram_input_data_4[0][3]<= rom_font_2[3];
                    vram_input_data_4[0][4]<= rom_font_2[4];
                    vram_input_data_4[0][5]<= rom_font_2[5];
                    vram_input_data_4[0][6]<= rom_font_2[6];
                    vram_input_data_4[0][7]<= rom_font_2[7];
                    vram_input_data_4[0][8]<= rom_font_2[8];
                    vram_input_data_4[0][9]<= rom_font_2[9];
                    vram_input_data_4[0][10]<= rom_font_2[10];
                    vram_input_data_4[0][11]<= rom_font_2[11];
                    vram_input_data_4[0][12]<= rom_font_2[12];
                    vram_input_data_4[0][13]<= rom_font_2[13];
                    vram_input_data_4[0][14]<= rom_font_2[14];
                    vram_input_data_4[0][15]<= rom_font_2[15];
                end 24'd3 : begin
                    vram_input_data_4[0][0]<= rom_font_3[0];
                    vram_input_data_4[0][1]<= rom_font_3[1];
                    vram_input_data_4[0][2]<= rom_font_3[2];
                    vram_input_data_4[0][3]<= rom_font_3[3];
                    vram_input_data_4[0][4]<= rom_font_3[4];
                    vram_input_data_4[0][5]<= rom_font_3[5];
                    vram_input_data_4[0][6]<= rom_font_3[6];
                    vram_input_data_4[0][7]<= rom_font_3[7];
                    vram_input_data_4[0][8]<= rom_font_3[8];
                    vram_input_data_4[0][9]<= rom_font_3[9];
                    vram_input_data_4[0][10]<= rom_font_3[10];
                    vram_input_data_4[0][11]<= rom_font_3[11];
                    vram_input_data_4[0][12]<= rom_font_3[12];
                    vram_input_data_4[0][13]<= rom_font_3[13];
                    vram_input_data_4[0][14]<= rom_font_3[14];
                    vram_input_data_4[0][15]<= rom_font_3[15];
                end 24'd4 : begin
                    vram_input_data_4[0][0]<= rom_font_4[0];
                    vram_input_data_4[0][1]<= rom_font_4[1];
                    vram_input_data_4[0][2]<= rom_font_4[2];
                    vram_input_data_4[0][3]<= rom_font_4[3];
                    vram_input_data_4[0][4]<= rom_font_4[4];
                    vram_input_data_4[0][5]<= rom_font_4[5];
                    vram_input_data_4[0][6]<= rom_font_4[6];
                    vram_input_data_4[0][7]<= rom_font_4[7];
                    vram_input_data_4[0][8]<= rom_font_4[8];
                    vram_input_data_4[0][9]<= rom_font_4[9];
                    vram_input_data_4[0][10]<= rom_font_4[10];
                    vram_input_data_4[0][11]<= rom_font_4[11];
                    vram_input_data_4[0][12]<= rom_font_4[12];
                    vram_input_data_4[0][13]<= rom_font_4[13];
                    vram_input_data_4[0][14]<= rom_font_4[14];
                    vram_input_data_4[0][15]<= rom_font_4[15];
                end 24'd5 : begin
                    vram_input_data_4[0][0]<= rom_font_5[0];
                    vram_input_data_4[0][1]<= rom_font_5[1];
                    vram_input_data_4[0][2]<= rom_font_5[2];
                    vram_input_data_4[0][3]<= rom_font_5[3];
                    vram_input_data_4[0][4]<= rom_font_5[4];
                    vram_input_data_4[0][5]<= rom_font_5[5];
                    vram_input_data_4[0][6]<= rom_font_5[6];
                    vram_input_data_4[0][7]<= rom_font_5[7];
                    vram_input_data_4[0][8]<= rom_font_5[8];
                    vram_input_data_4[0][9]<= rom_font_5[9];
                    vram_input_data_4[0][10]<= rom_font_5[10];
                    vram_input_data_4[0][11]<= rom_font_5[11];
                    vram_input_data_4[0][12]<= rom_font_5[12];
                    vram_input_data_4[0][13]<= rom_font_5[13];
                    vram_input_data_4[0][14]<= rom_font_5[14];
                    vram_input_data_4[0][15]<= rom_font_5[15];
                end 24'd6 : begin
                    vram_input_data_4[0][0]<= rom_font_6[0];
                    vram_input_data_4[0][1]<= rom_font_6[1];
                    vram_input_data_4[0][2]<= rom_font_6[2];
                    vram_input_data_4[0][3]<= rom_font_6[3];
                    vram_input_data_4[0][4]<= rom_font_6[4];
                    vram_input_data_4[0][5]<= rom_font_6[5];
                    vram_input_data_4[0][6]<= rom_font_6[6];
                    vram_input_data_4[0][7]<= rom_font_6[7];
                    vram_input_data_4[0][8]<= rom_font_6[8];
                    vram_input_data_4[0][9]<= rom_font_6[9];
                    vram_input_data_4[0][10]<= rom_font_6[10];
                    vram_input_data_4[0][11]<= rom_font_6[11];
                    vram_input_data_4[0][12]<= rom_font_6[12];
                    vram_input_data_4[0][13]<= rom_font_6[13];
                    vram_input_data_4[0][14]<= rom_font_6[14];
                    vram_input_data_4[0][15]<= rom_font_6[15];
                end 24'd7 : begin
                    vram_input_data_4[0][0]<= rom_font_7[0];
                    vram_input_data_4[0][1]<= rom_font_7[1];
                    vram_input_data_4[0][2]<= rom_font_7[2];
                    vram_input_data_4[0][3]<= rom_font_7[3];
                    vram_input_data_4[0][4]<= rom_font_7[4];
                    vram_input_data_4[0][5]<= rom_font_7[5];
                    vram_input_data_4[0][6]<= rom_font_7[6];
                    vram_input_data_4[0][7]<= rom_font_7[7];
                    vram_input_data_4[0][8]<= rom_font_7[8];
                    vram_input_data_4[0][9]<= rom_font_7[9];
                    vram_input_data_4[0][10]<= rom_font_7[10];
                    vram_input_data_4[0][11]<= rom_font_7[11];
                    vram_input_data_4[0][12]<= rom_font_7[12];
                    vram_input_data_4[0][13]<= rom_font_7[13];
                    vram_input_data_4[0][14]<= rom_font_7[14];
                    vram_input_data_4[0][15]<= rom_font_7[15];
                end 24'd8 : begin
                    vram_input_data_4[0][0]<= rom_font_8[0];
                    vram_input_data_4[0][1]<= rom_font_8[1];
                    vram_input_data_4[0][2]<= rom_font_8[2];
                    vram_input_data_4[0][3]<= rom_font_8[3];
                    vram_input_data_4[0][4]<= rom_font_8[4];
                    vram_input_data_4[0][5]<= rom_font_8[5];
                    vram_input_data_4[0][6]<= rom_font_8[6];
                    vram_input_data_4[0][7]<= rom_font_8[7];
                    vram_input_data_4[0][8]<= rom_font_8[8];
                    vram_input_data_4[0][9]<= rom_font_8[9];
                    vram_input_data_4[0][10]<= rom_font_8[10];
                    vram_input_data_4[0][11]<= rom_font_8[11];
                    vram_input_data_4[0][12]<= rom_font_8[12];
                    vram_input_data_4[0][13]<= rom_font_8[13];
                    vram_input_data_4[0][14]<= rom_font_8[14];
                    vram_input_data_4[0][15]<= rom_font_8[15];
                end 24'd9 : begin
                    vram_input_data_4[0][0]<= rom_font_9[0];
                    vram_input_data_4[0][1]<= rom_font_9[1];
                    vram_input_data_4[0][2]<= rom_font_9[2];
                    vram_input_data_4[0][3]<= rom_font_9[3];
                    vram_input_data_4[0][4]<= rom_font_9[4];
                    vram_input_data_4[0][5]<= rom_font_9[5];
                    vram_input_data_4[0][6]<= rom_font_9[6];
                    vram_input_data_4[0][7]<= rom_font_9[7];
                    vram_input_data_4[0][8]<= rom_font_9[8];
                    vram_input_data_4[0][9]<= rom_font_9[9];
                    vram_input_data_4[0][10]<= rom_font_9[10];
                    vram_input_data_4[0][11]<= rom_font_9[11];
                    vram_input_data_4[0][12]<= rom_font_9[12];
                    vram_input_data_4[0][13]<= rom_font_9[13];
                    vram_input_data_4[0][14]<= rom_font_9[14];
                    vram_input_data_4[0][15]<= rom_font_9[15];
                end
            endcase 
        end
    end
    
    // 截断数据
    assign tdata_truncation = tvalid ? {tdata[msb], tdata[msb - 1], tdata[msb - 2], tdata[msb - 3], tdata[msb - 4], tdata[msb - 5]} : 6'b0;
    
    // 载入单周期
    always @(posedge clk_calc or negedge rst_n) begin
        if(~rst_n)begin
            tvalid_truncation <= 1'b0;
            enter_flag        <= 1'b0;
        end else if((tvalid == 1'b1) && (enter_flag == 1'b0))begin
            if(tuser == 11'd0)begin
                tvalid_truncation <= 1'b1;
            end else if((tvalid_truncation == 1'b1) && (tuser == 11'd2047))begin
                tvalid_truncation <= 1'b0;
                enter_flag        <= 1'b1;
            end
        end else if(tvalid == 1'b0)begin
            tvalid_truncation <= 1'b0;   // 清零数据有效标志
            enter_flag        <= 1'b0;   // 清零进入标志
        end else begin
            tvalid_truncation <= tvalid_truncation;
            enter_flag        <= enter_flag;
        end
    end
    
    // 加载czt结果频谱
    always @(posedge clk_calc or negedge rst_n) begin
        if (!rst_n) begin
            vram_czt_result[0] <= 8'h0;vram_czt_result[1] <= 8'h0;vram_czt_result[2] <= 8'h0;vram_czt_result[3] <= 8'h0;vram_czt_result[4] <= 8'h0;vram_czt_result[5] <= 8'h0;vram_czt_result[6] <= 8'h0;vram_czt_result[7] <= 8'h0;vram_czt_result[8] <= 8'h0;vram_czt_result[9] <= 8'h0;
            vram_czt_result[10] <= 8'h0;vram_czt_result[11] <= 8'h0;vram_czt_result[12] <= 8'h0;vram_czt_result[13] <= 8'h0;vram_czt_result[14] <= 8'h0;vram_czt_result[15] <= 8'h0;vram_czt_result[16] <= 8'h0;vram_czt_result[17] <= 8'h0;
            vram_czt_result[18] <= 8'h0;vram_czt_result[19] <= 8'h0;vram_czt_result[20] <= 8'h0;vram_czt_result[21] <= 8'h0;vram_czt_result[22] <= 8'h0;vram_czt_result[23] <= 8'h0;vram_czt_result[24] <= 8'h0;vram_czt_result[25] <= 8'h0;
            vram_czt_result[26] <= 8'h0;vram_czt_result[27] <= 8'h0;vram_czt_result[28] <= 8'h0;vram_czt_result[29] <= 8'h0;vram_czt_result[30] <= 8'h0;vram_czt_result[31] <= 8'h0;vram_czt_result[32] <= 8'h0;vram_czt_result[33] <= 8'h0;
            vram_czt_result[34] <= 8'h0;vram_czt_result[35] <= 8'h0;vram_czt_result[36] <= 8'h0;vram_czt_result[37] <= 8'h0;vram_czt_result[38] <= 8'h0;vram_czt_result[39] <= 8'h0;vram_czt_result[40] <= 8'h0;vram_czt_result[41] <= 8'h0;
            vram_czt_result[42] <= 8'h0;vram_czt_result[43] <= 8'h0;vram_czt_result[44] <= 8'h0;vram_czt_result[45] <= 8'h0;vram_czt_result[46] <= 8'h0;vram_czt_result[47] <= 8'h0;vram_czt_result[48] <= 8'h0;vram_czt_result[49] <= 8'h0;
            vram_czt_result[50] <= 8'h0;vram_czt_result[51] <= 8'h0;vram_czt_result[52] <= 8'h0;vram_czt_result[53] <= 8'h0;vram_czt_result[54] <= 8'h0;vram_czt_result[55] <= 8'h0;vram_czt_result[56] <= 8'h0;vram_czt_result[57] <= 8'h0;
            vram_czt_result[58] <= 8'h0;vram_czt_result[59] <= 8'h0;vram_czt_result[60] <= 8'h0;vram_czt_result[61] <= 8'h0;vram_czt_result[62] <= 8'h0;vram_czt_result[63] <= 8'h0;vram_czt_result[64] <= 8'h0;vram_czt_result[65] <= 8'h0;
            vram_czt_result[66] <= 8'h0;vram_czt_result[67] <= 8'h0;vram_czt_result[68] <= 8'h0;vram_czt_result[69] <= 8'h0;vram_czt_result[70] <= 8'h0;vram_czt_result[71] <= 8'h0;vram_czt_result[72] <= 8'h0;vram_czt_result[73] <= 8'h0;
            vram_czt_result[74] <= 8'h0;vram_czt_result[75] <= 8'h0;vram_czt_result[76] <= 8'h0;vram_czt_result[77] <= 8'h0;vram_czt_result[78] <= 8'h0;vram_czt_result[79] <= 8'h0;vram_czt_result[80] <= 8'h0;vram_czt_result[81] <= 8'h0;
            vram_czt_result[82] <= 8'h0;vram_czt_result[83] <= 8'h0;vram_czt_result[84] <= 8'h0;vram_czt_result[85] <= 8'h0;vram_czt_result[86] <= 8'h0;vram_czt_result[87] <= 8'h0;vram_czt_result[88] <= 8'h0;vram_czt_result[89] <= 8'h0;
            vram_czt_result[90] <= 8'h0;vram_czt_result[91] <= 8'h0;vram_czt_result[92] <= 8'h0;vram_czt_result[93] <= 8'h0;vram_czt_result[94] <= 8'h0;vram_czt_result[95] <= 8'h0;vram_czt_result[96] <= 8'h0;vram_czt_result[97] <= 8'h0;
            vram_czt_result[98] <= 8'h0;vram_czt_result[99] <= 8'h0;vram_czt_result[100] <= 8'h0;vram_czt_result[101] <= 8'h0;vram_czt_result[102] <= 8'h0;vram_czt_result[103] <= 8'h0;vram_czt_result[104] <= 8'h0;vram_czt_result[105] <= 8'h0;
            vram_czt_result[106] <= 8'h0;vram_czt_result[107] <= 8'h0;vram_czt_result[108] <= 8'h0;vram_czt_result[109] <= 8'h0;vram_czt_result[110] <= 8'h0;vram_czt_result[111] <= 8'h0;vram_czt_result[112] <= 8'h0;vram_czt_result[113] <= 8'h0;
            vram_czt_result[114] <= 8'h0;vram_czt_result[115] <= 8'h0;vram_czt_result[116] <= 8'h0;vram_czt_result[117] <= 8'h0;vram_czt_result[118] <= 8'h0;vram_czt_result[119] <= 8'h0;vram_czt_result[120] <= 8'h0;vram_czt_result[121] <= 8'h0;
            vram_czt_result[122] <= 8'h0;vram_czt_result[123] <= 8'h0;vram_czt_result[124] <= 8'h0;vram_czt_result[125] <= 8'h0;vram_czt_result[126] <= 8'h0;vram_czt_result[127] <= 8'h0;vram_czt_result[128] <= 8'h0;vram_czt_result[129] <= 8'h0;
            vram_czt_result[130] <= 8'h0;vram_czt_result[131] <= 8'h0;vram_czt_result[132] <= 8'h0;vram_czt_result[133] <= 8'h0;vram_czt_result[134] <= 8'h0;vram_czt_result[135] <= 8'h0;vram_czt_result[136] <= 8'h0;vram_czt_result[137] <= 8'h0;
            vram_czt_result[138] <= 8'h0;vram_czt_result[139] <= 8'h0;vram_czt_result[140] <= 8'h0;vram_czt_result[141] <= 8'h0;vram_czt_result[142] <= 8'h0;vram_czt_result[143] <= 8'h0;vram_czt_result[144] <= 8'h0;vram_czt_result[145] <= 8'h0;
            vram_czt_result[146] <= 8'h0;vram_czt_result[147] <= 8'h0;vram_czt_result[148] <= 8'h0;vram_czt_result[149] <= 8'h0;vram_czt_result[150] <= 8'h0;vram_czt_result[151] <= 8'h0;vram_czt_result[152] <= 8'h0;vram_czt_result[153] <= 8'h0;
            vram_czt_result[154] <= 8'h0;vram_czt_result[155] <= 8'h0;vram_czt_result[156] <= 8'h0;vram_czt_result[157] <= 8'h0;vram_czt_result[158] <= 8'h0;vram_czt_result[159] <= 8'h0;vram_czt_result[160] <= 8'h0;vram_czt_result[161] <= 8'h0;
            vram_czt_result[162] <= 8'h0;vram_czt_result[163] <= 8'h0;vram_czt_result[164] <= 8'h0;vram_czt_result[165] <= 8'h0;vram_czt_result[166] <= 8'h0;vram_czt_result[167] <= 8'h0;vram_czt_result[168] <= 8'h0;vram_czt_result[169] <= 8'h0;
            vram_czt_result[170] <= 8'h0;vram_czt_result[171] <= 8'h0;vram_czt_result[172] <= 8'h0;vram_czt_result[173] <= 8'h0;vram_czt_result[174] <= 8'h0;vram_czt_result[175] <= 8'h0;vram_czt_result[176] <= 8'h0;vram_czt_result[177] <= 8'h0;
            vram_czt_result[178] <= 8'h0;vram_czt_result[179] <= 8'h0;vram_czt_result[180] <= 8'h0;vram_czt_result[181] <= 8'h0;vram_czt_result[182] <= 8'h0;vram_czt_result[183] <= 8'h0;vram_czt_result[184] <= 8'h0;vram_czt_result[185] <= 8'h0;
            vram_czt_result[186] <= 8'h0;vram_czt_result[187] <= 8'h0;vram_czt_result[188] <= 8'h0;vram_czt_result[189] <= 8'h0;vram_czt_result[190] <= 8'h0;vram_czt_result[191] <= 8'h0;vram_czt_result[192] <= 8'h0;vram_czt_result[193] <= 8'h0;
            vram_czt_result[194] <= 8'h0;vram_czt_result[195] <= 8'h0;vram_czt_result[196] <= 8'h0;vram_czt_result[197] <= 8'h0;vram_czt_result[198] <= 8'h0;vram_czt_result[199] <= 8'h0;vram_czt_result[200] <= 8'h0;vram_czt_result[201] <= 8'h0;
            vram_czt_result[202] <= 8'h0;vram_czt_result[203] <= 8'h0;vram_czt_result[204] <= 8'h0;vram_czt_result[205] <= 8'h0;vram_czt_result[206] <= 8'h0;vram_czt_result[207] <= 8'h0;vram_czt_result[208] <= 8'h0;vram_czt_result[209] <= 8'h0;
            vram_czt_result[210] <= 8'h0;vram_czt_result[211] <= 8'h0;vram_czt_result[212] <= 8'h0;vram_czt_result[213] <= 8'h0;vram_czt_result[214] <= 8'h0;vram_czt_result[215] <= 8'h0;vram_czt_result[216] <= 8'h0;vram_czt_result[217] <= 8'h0;
            vram_czt_result[218] <= 8'h0;vram_czt_result[219] <= 8'h0;vram_czt_result[220] <= 8'h0;vram_czt_result[221] <= 8'h0;vram_czt_result[222] <= 8'h0;vram_czt_result[223] <= 8'h0;vram_czt_result[224] <= 8'h0;vram_czt_result[225] <= 8'h0;
            vram_czt_result[226] <= 8'h0;vram_czt_result[227] <= 8'h0;vram_czt_result[228] <= 8'h0;vram_czt_result[229] <= 8'h0;vram_czt_result[230] <= 8'h0;vram_czt_result[231] <= 8'h0;vram_czt_result[232] <= 8'h0;vram_czt_result[233] <= 8'h0;
            vram_czt_result[234] <= 8'h0;vram_czt_result[235] <= 8'h0;vram_czt_result[236] <= 8'h0;vram_czt_result[237] <= 8'h0;vram_czt_result[238] <= 8'h0;vram_czt_result[239] <= 8'h0;vram_czt_result[240] <= 8'h0;vram_czt_result[241] <= 8'h0;
            vram_czt_result[242] <= 8'h0;vram_czt_result[243] <= 8'h0;vram_czt_result[244] <= 8'h0;vram_czt_result[245] <= 8'h0;vram_czt_result[246] <= 8'h0;vram_czt_result[247] <= 8'h0;vram_czt_result[248] <= 8'h0;vram_czt_result[249] <= 8'h0;
            vram_czt_result[250] <= 8'h0;vram_czt_result[251] <= 8'h0;vram_czt_result[252] <= 8'h0;vram_czt_result[253] <= 8'h0;vram_czt_result[254] <= 8'h0;vram_czt_result[255] <= 8'h0;vram_czt_result[256] <= 8'h0;vram_czt_result[257] <= 8'h0;
            vram_czt_result[258] <= 8'h0;vram_czt_result[259] <= 8'h0;vram_czt_result[260] <= 8'h0;vram_czt_result[261] <= 8'h0;vram_czt_result[262] <= 8'h0;vram_czt_result[263] <= 8'h0;vram_czt_result[264] <= 8'h0;vram_czt_result[265] <= 8'h0;
            vram_czt_result[266] <= 8'h0;vram_czt_result[267] <= 8'h0;vram_czt_result[268] <= 8'h0;vram_czt_result[269] <= 8'h0;vram_czt_result[270] <= 8'h0;vram_czt_result[271] <= 8'h0;vram_czt_result[272] <= 8'h0;vram_czt_result[273] <= 8'h0;
            vram_czt_result[274] <= 8'h0;vram_czt_result[275] <= 8'h0;vram_czt_result[276] <= 8'h0;vram_czt_result[277] <= 8'h0;vram_czt_result[278] <= 8'h0;vram_czt_result[279] <= 8'h0;vram_czt_result[280] <= 8'h0;vram_czt_result[281] <= 8'h0;
            vram_czt_result[282] <= 8'h0;vram_czt_result[283] <= 8'h0;vram_czt_result[284] <= 8'h0;vram_czt_result[285] <= 8'h0;vram_czt_result[286] <= 8'h0;vram_czt_result[287] <= 8'h0;vram_czt_result[288] <= 8'h0;vram_czt_result[289] <= 8'h0;
            vram_czt_result[290] <= 8'h0;vram_czt_result[291] <= 8'h0;vram_czt_result[292] <= 8'h0;vram_czt_result[293] <= 8'h0;vram_czt_result[294] <= 8'h0;vram_czt_result[295] <= 8'h0;vram_czt_result[296] <= 8'h0;vram_czt_result[297] <= 8'h0;
            vram_czt_result[298] <= 8'h0;vram_czt_result[299] <= 8'h0;vram_czt_result[300] <= 8'h0;vram_czt_result[301] <= 8'h0;vram_czt_result[302] <= 8'h0;vram_czt_result[303] <= 8'h0;vram_czt_result[304] <= 8'h0;vram_czt_result[305] <= 8'h0;
            vram_czt_result[306] <= 8'h0;vram_czt_result[307] <= 8'h0;vram_czt_result[308] <= 8'h0;vram_czt_result[309] <= 8'h0;vram_czt_result[310] <= 8'h0;vram_czt_result[311] <= 8'h0;vram_czt_result[312] <= 8'h0;vram_czt_result[313] <= 8'h0;
            vram_czt_result[314] <= 8'h0;vram_czt_result[315] <= 8'h0;vram_czt_result[316] <= 8'h0;vram_czt_result[317] <= 8'h0;vram_czt_result[318] <= 8'h0;vram_czt_result[319] <= 8'h0;vram_czt_result[320] <= 8'h0;vram_czt_result[321] <= 8'h0;
            vram_czt_result[322] <= 8'h0;vram_czt_result[323] <= 8'h0;vram_czt_result[324] <= 8'h0;vram_czt_result[325] <= 8'h0;vram_czt_result[326] <= 8'h0;vram_czt_result[327] <= 8'h0;vram_czt_result[328] <= 8'h0;vram_czt_result[329] <= 8'h0;
            vram_czt_result[330] <= 8'h0;vram_czt_result[331] <= 8'h0;vram_czt_result[332] <= 8'h0;vram_czt_result[333] <= 8'h0;vram_czt_result[334] <= 8'h0;vram_czt_result[335] <= 8'h0;vram_czt_result[336] <= 8'h0;vram_czt_result[337] <= 8'h0;
            vram_czt_result[338] <= 8'h0;vram_czt_result[339] <= 8'h0;vram_czt_result[340] <= 8'h0;vram_czt_result[341] <= 8'h0;vram_czt_result[342] <= 8'h0;vram_czt_result[343] <= 8'h0;vram_czt_result[344] <= 8'h0;vram_czt_result[345] <= 8'h0;
            vram_czt_result[346] <= 8'h0;vram_czt_result[347] <= 8'h0;vram_czt_result[348] <= 8'h0;vram_czt_result[349] <= 8'h0;vram_czt_result[350] <= 8'h0;vram_czt_result[351] <= 8'h0;vram_czt_result[352] <= 8'h0;vram_czt_result[353] <= 8'h0;
            vram_czt_result[354] <= 8'h0;vram_czt_result[355] <= 8'h0;vram_czt_result[356] <= 8'h0;vram_czt_result[357] <= 8'h0;vram_czt_result[358] <= 8'h0;vram_czt_result[359] <= 8'h0;vram_czt_result[360] <= 8'h0;vram_czt_result[361] <= 8'h0;
            vram_czt_result[362] <= 8'h0;vram_czt_result[363] <= 8'h0;vram_czt_result[364] <= 8'h0;vram_czt_result[365] <= 8'h0;vram_czt_result[366] <= 8'h0;vram_czt_result[367] <= 8'h0;vram_czt_result[368] <= 8'h0;vram_czt_result[369] <= 8'h0;
            vram_czt_result[370] <= 8'h0;vram_czt_result[371] <= 8'h0;vram_czt_result[372] <= 8'h0;vram_czt_result[373] <= 8'h0;vram_czt_result[374] <= 8'h0;vram_czt_result[375] <= 8'h0;vram_czt_result[376] <= 8'h0;vram_czt_result[377] <= 8'h0;
            vram_czt_result[378] <= 8'h0;vram_czt_result[379] <= 8'h0;vram_czt_result[380] <= 8'h0;vram_czt_result[381] <= 8'h0;vram_czt_result[382] <= 8'h0;vram_czt_result[383] <= 8'h0;vram_czt_result[384] <= 8'h0;vram_czt_result[385] <= 8'h0;
            vram_czt_result[386] <= 8'h0;vram_czt_result[387] <= 8'h0;vram_czt_result[388] <= 8'h0;vram_czt_result[389] <= 8'h0;vram_czt_result[390] <= 8'h0;vram_czt_result[391] <= 8'h0;vram_czt_result[392] <= 8'h0;vram_czt_result[393] <= 8'h0;
            vram_czt_result[394] <= 8'h0;vram_czt_result[395] <= 8'h0;vram_czt_result[396] <= 8'h0;vram_czt_result[397] <= 8'h0;vram_czt_result[398] <= 8'h0;vram_czt_result[399] <= 8'h0;vram_czt_result[400] <= 8'h0;vram_czt_result[401] <= 8'h0;
            vram_czt_result[402] <= 8'h0;vram_czt_result[403] <= 8'h0;vram_czt_result[404] <= 8'h0;vram_czt_result[405] <= 8'h0;vram_czt_result[406] <= 8'h0;vram_czt_result[407] <= 8'h0;vram_czt_result[408] <= 8'h0;vram_czt_result[409] <= 8'h0;
            vram_czt_result[410] <= 8'h0;vram_czt_result[411] <= 8'h0;vram_czt_result[412] <= 8'h0;vram_czt_result[413] <= 8'h0;vram_czt_result[414] <= 8'h0;vram_czt_result[415] <= 8'h0;vram_czt_result[416] <= 8'h0;vram_czt_result[417] <= 8'h0;
            vram_czt_result[418] <= 8'h0;vram_czt_result[419] <= 8'h0;vram_czt_result[420] <= 8'h0;vram_czt_result[421] <= 8'h0;vram_czt_result[422] <= 8'h0;vram_czt_result[423] <= 8'h0;vram_czt_result[424] <= 8'h0;vram_czt_result[425] <= 8'h0;
            vram_czt_result[426] <= 8'h0;vram_czt_result[427] <= 8'h0;vram_czt_result[428] <= 8'h0;vram_czt_result[429] <= 8'h0;vram_czt_result[430] <= 8'h0;vram_czt_result[431] <= 8'h0;vram_czt_result[432] <= 8'h0;vram_czt_result[433] <= 8'h0;
            vram_czt_result[434] <= 8'h0;vram_czt_result[435] <= 8'h0;vram_czt_result[436] <= 8'h0;vram_czt_result[437] <= 8'h0;vram_czt_result[438] <= 8'h0;vram_czt_result[439] <= 8'h0;vram_czt_result[440] <= 8'h0;vram_czt_result[441] <= 8'h0;
            vram_czt_result[442] <= 8'h0;vram_czt_result[443] <= 8'h0;vram_czt_result[444] <= 8'h0;vram_czt_result[445] <= 8'h0;vram_czt_result[446] <= 8'h0;vram_czt_result[447] <= 8'h0;vram_czt_result[448] <= 8'h0;vram_czt_result[449] <= 8'h0;
            vram_czt_result[450] <= 8'h0;vram_czt_result[451] <= 8'h0;vram_czt_result[452] <= 8'h0;vram_czt_result[453] <= 8'h0;vram_czt_result[454] <= 8'h0;vram_czt_result[455] <= 8'h0;vram_czt_result[456] <= 8'h0;vram_czt_result[457] <= 8'h0;
            vram_czt_result[458] <= 8'h0;vram_czt_result[459] <= 8'h0;vram_czt_result[460] <= 8'h0;vram_czt_result[461] <= 8'h0;vram_czt_result[462] <= 8'h0;vram_czt_result[463] <= 8'h0;vram_czt_result[464] <= 8'h0;vram_czt_result[465] <= 8'h0;
            vram_czt_result[466] <= 8'h0;vram_czt_result[467] <= 8'h0;vram_czt_result[468] <= 8'h0;vram_czt_result[469] <= 8'h0;vram_czt_result[470] <= 8'h0;vram_czt_result[471] <= 8'h0;vram_czt_result[472] <= 8'h0;vram_czt_result[473] <= 8'h0;
            vram_czt_result[474] <= 8'h0;vram_czt_result[475] <= 8'h0;vram_czt_result[476] <= 8'h0;vram_czt_result[477] <= 8'h0;vram_czt_result[478] <= 8'h0;vram_czt_result[479] <= 8'h0;vram_czt_result[480] <= 8'h0;vram_czt_result[481] <= 8'h0;
            vram_czt_result[482] <= 8'h0;vram_czt_result[483] <= 8'h0;vram_czt_result[484] <= 8'h0;vram_czt_result[485] <= 8'h0;vram_czt_result[486] <= 8'h0;vram_czt_result[487] <= 8'h0;vram_czt_result[488] <= 8'h0;vram_czt_result[489] <= 8'h0;
            vram_czt_result[490] <= 8'h0;vram_czt_result[491] <= 8'h0;vram_czt_result[492] <= 8'h0;vram_czt_result[493] <= 8'h0;vram_czt_result[494] <= 8'h0;vram_czt_result[495] <= 8'h0;vram_czt_result[496] <= 8'h0;vram_czt_result[497] <= 8'h0;
            vram_czt_result[498] <= 8'h0;vram_czt_result[499] <= 8'h0;vram_czt_result[500] <= 8'h0;vram_czt_result[501] <= 8'h0;vram_czt_result[502] <= 8'h0;vram_czt_result[503] <= 8'h0;vram_czt_result[504] <= 8'h0;vram_czt_result[505] <= 8'h0;
            vram_czt_result[506] <= 8'h0;vram_czt_result[507] <= 8'h0;vram_czt_result[508] <= 8'h0;vram_czt_result[509] <= 8'h0;vram_czt_result[510] <= 8'h0;vram_czt_result[511] <= 8'h0;vram_czt_result[512] <= 8'h0;vram_czt_result[513] <= 8'h0;
            vram_czt_result[514] <= 8'h0;vram_czt_result[515] <= 8'h0;vram_czt_result[516] <= 8'h0;vram_czt_result[517] <= 8'h0;vram_czt_result[518] <= 8'h0;vram_czt_result[519] <= 8'h0;vram_czt_result[520] <= 8'h0;vram_czt_result[521] <= 8'h0;
            vram_czt_result[522] <= 8'h0;vram_czt_result[523] <= 8'h0;vram_czt_result[524] <= 8'h0;vram_czt_result[525] <= 8'h0;vram_czt_result[526] <= 8'h0;vram_czt_result[527] <= 8'h0;vram_czt_result[528] <= 8'h0;vram_czt_result[529] <= 8'h0;
            vram_czt_result[530] <= 8'h0;vram_czt_result[531] <= 8'h0;vram_czt_result[532] <= 8'h0;vram_czt_result[533] <= 8'h0;vram_czt_result[534] <= 8'h0;vram_czt_result[535] <= 8'h0;vram_czt_result[536] <= 8'h0;vram_czt_result[537] <= 8'h0;
            vram_czt_result[538] <= 8'h0;vram_czt_result[539] <= 8'h0;vram_czt_result[540] <= 8'h0;vram_czt_result[541] <= 8'h0;vram_czt_result[542] <= 8'h0;vram_czt_result[543] <= 8'h0;vram_czt_result[544] <= 8'h0;vram_czt_result[545] <= 8'h0;
            vram_czt_result[546] <= 8'h0;vram_czt_result[547] <= 8'h0;vram_czt_result[548] <= 8'h0;vram_czt_result[549] <= 8'h0;vram_czt_result[550] <= 8'h0;vram_czt_result[551] <= 8'h0;vram_czt_result[552] <= 8'h0;vram_czt_result[553] <= 8'h0;
            vram_czt_result[554] <= 8'h0;vram_czt_result[555] <= 8'h0;vram_czt_result[556] <= 8'h0;vram_czt_result[557] <= 8'h0;vram_czt_result[558] <= 8'h0;vram_czt_result[559] <= 8'h0;vram_czt_result[560] <= 8'h0;vram_czt_result[561] <= 8'h0;
            vram_czt_result[562] <= 8'h0;vram_czt_result[563] <= 8'h0;vram_czt_result[564] <= 8'h0;vram_czt_result[565] <= 8'h0;vram_czt_result[566] <= 8'h0;vram_czt_result[567] <= 8'h0;vram_czt_result[568] <= 8'h0;vram_czt_result[569] <= 8'h0;
            vram_czt_result[570] <= 8'h0;vram_czt_result[571] <= 8'h0;vram_czt_result[572] <= 8'h0;vram_czt_result[573] <= 8'h0;vram_czt_result[574] <= 8'h0;vram_czt_result[575] <= 8'h0;vram_czt_result[576] <= 8'h0;vram_czt_result[577] <= 8'h0;
            vram_czt_result[578] <= 8'h0;vram_czt_result[579] <= 8'h0;vram_czt_result[580] <= 8'h0;vram_czt_result[581] <= 8'h0;vram_czt_result[582] <= 8'h0;vram_czt_result[583] <= 8'h0;vram_czt_result[584] <= 8'h0;vram_czt_result[585] <= 8'h0;
            vram_czt_result[586] <= 8'h0;vram_czt_result[587] <= 8'h0;vram_czt_result[588] <= 8'h0;vram_czt_result[589] <= 8'h0;vram_czt_result[590] <= 8'h0;vram_czt_result[591] <= 8'h0;vram_czt_result[592] <= 8'h0;vram_czt_result[593] <= 8'h0;
            vram_czt_result[594] <= 8'h0;vram_czt_result[595] <= 8'h0;vram_czt_result[596] <= 8'h0;vram_czt_result[597] <= 8'h0;vram_czt_result[598] <= 8'h0;vram_czt_result[599] <= 8'h0;vram_czt_result[600] <= 8'h0;vram_czt_result[601] <= 8'h0;
            vram_czt_result[602] <= 8'h0;vram_czt_result[603] <= 8'h0;vram_czt_result[604] <= 8'h0;vram_czt_result[605] <= 8'h0;vram_czt_result[606] <= 8'h0;vram_czt_result[607] <= 8'h0;vram_czt_result[608] <= 8'h0;vram_czt_result[609] <= 8'h0;
            vram_czt_result[610] <= 8'h0;vram_czt_result[611] <= 8'h0;vram_czt_result[612] <= 8'h0;vram_czt_result[613] <= 8'h0;vram_czt_result[614] <= 8'h0;vram_czt_result[615] <= 8'h0;vram_czt_result[616] <= 8'h0;vram_czt_result[617] <= 8'h0;
            vram_czt_result[618] <= 8'h0;vram_czt_result[619] <= 8'h0;vram_czt_result[620] <= 8'h0;vram_czt_result[621] <= 8'h0;vram_czt_result[622] <= 8'h0;vram_czt_result[623] <= 8'h0;vram_czt_result[624] <= 8'h0;vram_czt_result[625] <= 8'h0;
            vram_czt_result[626] <= 8'h0;vram_czt_result[627] <= 8'h0;vram_czt_result[628] <= 8'h0;vram_czt_result[629] <= 8'h0;vram_czt_result[630] <= 8'h0;vram_czt_result[631] <= 8'h0;vram_czt_result[632] <= 8'h0;vram_czt_result[633] <= 8'h0;
            vram_czt_result[634] <= 8'h0;vram_czt_result[635] <= 8'h0;vram_czt_result[636] <= 8'h0;vram_czt_result[637] <= 8'h0;vram_czt_result[638] <= 8'h0;vram_czt_result[639] <= 8'h0;vram_czt_result[640] <= 8'h0;vram_czt_result[641] <= 8'h0;
            vram_czt_result[642] <= 8'h0;vram_czt_result[643] <= 8'h0;vram_czt_result[644] <= 8'h0;vram_czt_result[645] <= 8'h0;vram_czt_result[646] <= 8'h0;vram_czt_result[647] <= 8'h0;vram_czt_result[648] <= 8'h0;vram_czt_result[649] <= 8'h0;
            vram_czt_result[650] <= 8'h0;vram_czt_result[651] <= 8'h0;vram_czt_result[652] <= 8'h0;vram_czt_result[653] <= 8'h0;vram_czt_result[654] <= 8'h0;vram_czt_result[655] <= 8'h0;vram_czt_result[656] <= 8'h0;vram_czt_result[657] <= 8'h0;
            vram_czt_result[658] <= 8'h0;vram_czt_result[659] <= 8'h0;vram_czt_result[660] <= 8'h0;vram_czt_result[661] <= 8'h0;vram_czt_result[662] <= 8'h0;vram_czt_result[663] <= 8'h0;vram_czt_result[664] <= 8'h0;vram_czt_result[665] <= 8'h0;
            vram_czt_result[666] <= 8'h0;vram_czt_result[667] <= 8'h0;vram_czt_result[668] <= 8'h0;vram_czt_result[669] <= 8'h0;vram_czt_result[670] <= 8'h0;vram_czt_result[671] <= 8'h0;vram_czt_result[672] <= 8'h0;vram_czt_result[673] <= 8'h0;
            vram_czt_result[674] <= 8'h0;vram_czt_result[675] <= 8'h0;vram_czt_result[676] <= 8'h0;vram_czt_result[677] <= 8'h0;vram_czt_result[678] <= 8'h0;vram_czt_result[679] <= 8'h0;vram_czt_result[680] <= 8'h0;vram_czt_result[681] <= 8'h0;vram_czt_result[682] <= 8'h0;
        end else if(tvalid_truncation == 1'b1)begin
            vram_czt_result[tuser / 3] <= vram_czt_result[tuser / 3] + tdata_truncation;
        end
    end
    
    // 坐标轴显示区域
    parameter XPOS_START   = 11'd50;
    parameter YPOS_START   = 11'd165;
    parameter XPOS_WIDTH   = 11'd684;
    parameter YPOS_END     = 11'd420; // 茶255=2^8-1
    // 文字显示区域
    parameter TEXT_X_START = 11'd9; 
    parameter TEXT_Y_START = 11'd9; 
    parameter TEXT_WIDTH   = 11'd152; 
    parameter TEXT_HEIGHT  = 11'd128; 
    // 输入数据显示区域
    parameter DATA_X_START = 11'd161; 
    parameter DATA_Y_START = 11'd9; 
    parameter DATA_WIDTH   = 11'd8; 
    parameter DATA_HEIGHT  = 11'd16; 
    // 结果频谱显示区域
    parameter FIG_X_START = 11'd51; 
    parameter FIG_Y_START = 11'd165; 
    parameter FIG_WIDTH   = 11'd683; 
    parameter FIG_HEIGHT  = 11'd255; 
    parameter FIG_Y_END   = 11'd420;     
    
    assign x_text_cnt  = pixel_xpos - TEXT_X_START;                     // 像素点相对于文字区域起始点水平坐标
    assign y_text_cnt  = pixel_ypos - TEXT_Y_START;                     // 像素点相对于文字区域起始点垂直坐标
    assign x4_data_cnt = pixel_xpos - (DATA_X_START + 4 * DATA_WIDTH);  // 像素点相对于数据区域起始点垂直坐标
    assign x3_data_cnt = pixel_xpos - (DATA_X_START + 3 * DATA_WIDTH);  // 像素点相对于数据区域起始点垂直坐标
    assign x2_data_cnt = pixel_xpos - (DATA_X_START + 2 * DATA_WIDTH);  // 像素点相对于数据区域起始点垂直坐标
    assign x1_data_cnt = pixel_xpos - (DATA_X_START + 1 * DATA_WIDTH);  // 像素点相对于数据区域起始点垂直坐标
    assign x0_data_cnt = pixel_xpos - (DATA_X_START + 0 * DATA_WIDTH);  // 像素点相对于数据区域起始点垂直坐标
    assign y0_data_cnt = pixel_ypos - (DATA_Y_START + 0 * DATA_HEIGHT); // 像素点相对于数据区域起始点垂直坐标
    assign y1_data_cnt = pixel_ypos - (DATA_Y_START + 2 * DATA_HEIGHT); // 像素点相对于数据区域起始点垂直坐标
    assign y2_data_cnt = pixel_ypos - (DATA_Y_START + 4 * DATA_HEIGHT); // 像素点相对于数据区域起始点垂直坐标
    assign y3_data_cnt = pixel_ypos - (DATA_Y_START + 6 * DATA_HEIGHT); // 像素点相对于数据区域起始点垂直坐标
    assign x_fig_cnt   = pixel_xpos - FIG_X_START;                      // 像素点相对于数据区域起始点垂直坐标
    
// 需要显示幅度谱峰值对应的频率；需要将幅度谱归一化或者按比例压缩到坐标轴区间内
// 1.粗测频谱时：2048点，x轴像素点仅有800个，将2个点合并到一起显示后，仅需要512个x轴像素点
// 2.频谱细化时：2048点，将2个点合并到一起显示后需要512个x轴像素点
always @(posedge lcd_pclk or negedge rst_n) begin
    if(!rst_n)
        pixel_data <= BLACK;
    else begin 
        // 1.显示坐标轴
        if( (pixel_ypos == YPOS_END) && (pixel_xpos >= (XPOS_START - 1)) && (pixel_xpos < XPOS_START + XPOS_WIDTH) )begin // 绘制x轴
            pixel_data <= CYAN;
        end else if( (pixel_xpos == (XPOS_START - 1)) && (pixel_ypos >= YPOS_START) && (pixel_ypos < YPOS_END) )begin // 绘制y轴
            pixel_data <= CYAN;
        // 2.绘制x轴刻度信息
        end else if( (pixel_xpos >= XPOS_START) && (pixel_xpos < XPOS_START + XPOS_WIDTH) && ((pixel_xpos - XPOS_START) % 51 == 0) && 
                     (pixel_ypos >= YPOS_END) && (pixel_ypos < (YPOS_END + 8)) )begin 
            pixel_data <= CYAN;
        // 3.显示文字提示
        end else if( (pixel_xpos >= TEXT_X_START) && (pixel_xpos < TEXT_X_START + TEXT_WIDTH) && 
                     (pixel_ypos >= TEXT_Y_START) && (pixel_ypos < TEXT_Y_START + TEXT_HEIGHT) )begin
            // 顺序扫描，从高字节到低字节，以显示字符
            if(vram_init_data[y_text_cnt][TEXT_WIDTH -1'b1 - x_text_cnt] == 1'b1)
                pixel_data <= PURPLE;
            else
                pixel_data <= BLACK;
        // 4.显示输入数据和计算结果
        // 4.1.1.f0的个位
        end else if( (pixel_xpos >= DATA_X_START + 4 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 5 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 0 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 1 * DATA_HEIGHT) )begin
            if(vram_input_data_1[4][y0_data_cnt][DATA_WIDTH -1'b1 - x4_data_cnt] == 1'b1)
                pixel_data <= RED;
            else
                pixel_data <= BLACK;
        // 4.1.2.f0的十位
        end else if( (pixel_xpos >= DATA_X_START + 3 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 4 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 0 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 1 * DATA_HEIGHT) )begin
            if(vram_input_data_1[3][y0_data_cnt][DATA_WIDTH -1'b1 - x3_data_cnt] == 1'b1)
                pixel_data <= RED;
            else
                pixel_data <= BLACK;
        // 4.1.3.f0的百位
        end else if( (pixel_xpos >= DATA_X_START + 2 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 3 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 0 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 1 * DATA_HEIGHT) )begin
            if(vram_input_data_1[2][y0_data_cnt][DATA_WIDTH -1'b1 - x2_data_cnt] == 1'b1)
                pixel_data <= RED;
            else
                pixel_data <= BLACK;
        // 4.1.4.f0的千位
        end else if( (pixel_xpos >= DATA_X_START + 1 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 2 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 0 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 1 * DATA_HEIGHT) )begin
            if(vram_input_data_1[1][y0_data_cnt][DATA_WIDTH -1'b1 - x1_data_cnt] == 1'b1)
                pixel_data <= RED;
            else
                pixel_data <= BLACK;
        // 4.1.5.f0的万位
        end else if( (pixel_xpos >= DATA_X_START + 0 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 1 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 0 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 1 * DATA_HEIGHT) )begin
            if(vram_input_data_1[0][y0_data_cnt][DATA_WIDTH -1'b1 - x0_data_cnt] == 1'b1)
                pixel_data <= RED;
            else
                pixel_data <= BLACK;
        // 4.2.1.fl的个位
        end else if( (pixel_xpos >= DATA_X_START + 4 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 5 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 2 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 3 * DATA_HEIGHT) )begin
            if(vram_input_data_2[4][y1_data_cnt][DATA_WIDTH -1'b1 - x4_data_cnt] == 1'b1)
                pixel_data <= YELLOW;
            else
                pixel_data <= BLACK;
        // 4.2.2.fl的十位
        end else if( (pixel_xpos >= DATA_X_START + 3 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 4 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 2 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 3 * DATA_HEIGHT) )begin
            if(vram_input_data_2[3][y1_data_cnt][DATA_WIDTH -1'b1 - x3_data_cnt] == 1'b1)
                pixel_data <= YELLOW;
            else
                pixel_data <= BLACK;
        // 4.2.3.fl的百位
        end else if( (pixel_xpos >= DATA_X_START + 2 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 3 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 2 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 3 * DATA_HEIGHT) )begin
            if(vram_input_data_2[2][y1_data_cnt][DATA_WIDTH -1'b1 - x2_data_cnt] == 1'b1)
                pixel_data <= YELLOW;
            else
                pixel_data <= BLACK;
        // 4.2.4.fl的千位
        end else if( (pixel_xpos >= DATA_X_START + 1 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 2 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 2 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 3 * DATA_HEIGHT) )begin
            if(vram_input_data_2[1][y1_data_cnt][DATA_WIDTH -1'b1 - x1_data_cnt] == 1'b1)
                pixel_data <= YELLOW;
            else
                pixel_data <= BLACK;
        // 4.2.5.fl的万位
        end else if( (pixel_xpos >= DATA_X_START + 0 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 1 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 2 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 3 * DATA_HEIGHT) )begin
            if(vram_input_data_2[0][y1_data_cnt][DATA_WIDTH -1'b1 - x0_data_cnt] == 1'b1)
                pixel_data <= YELLOW;
            else
                pixel_data <= BLACK;
        // 4.3.1.rough_calc的个位
        end else if( (pixel_xpos >= DATA_X_START + 4 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 5 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 4 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 5 * DATA_HEIGHT) )begin
            if(vram_input_data_3[4][y2_data_cnt][DATA_WIDTH -1'b1 - x4_data_cnt] == 1'b1)
                pixel_data <= BLUE;
            else
                pixel_data <= BLACK;
        // 4.3.2.rough_calc的十位
        end else if( (pixel_xpos >= DATA_X_START + 3 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 4 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 4 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 5 * DATA_HEIGHT) )begin
            if(vram_input_data_3[3][y2_data_cnt][DATA_WIDTH -1'b1 - x3_data_cnt] == 1'b1)
                pixel_data <= BLUE;
            else
                pixel_data <= BLACK;
        // 4.3.3.rough_calc的百位
        end else if( (pixel_xpos >= DATA_X_START + 2 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 3 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 4 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 5 * DATA_HEIGHT) )begin
            if(vram_input_data_3[2][y2_data_cnt][DATA_WIDTH -1'b1 - x2_data_cnt] == 1'b1)
                pixel_data <= BLUE;
            else
                pixel_data <= BLACK;
        // 4.3.4.rough_calc的千位
        end else if( (pixel_xpos >= DATA_X_START + 1 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 2 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 4 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 5 * DATA_HEIGHT) )begin
            if(vram_input_data_3[1][y2_data_cnt][DATA_WIDTH -1'b1 - x1_data_cnt] == 1'b1)
                pixel_data <= BLUE;
            else
                pixel_data <= BLACK;
        // 4.3.5.rough_calc的万位
        end else if( (pixel_xpos >= DATA_X_START + 0 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 1 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 4 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 5 * DATA_HEIGHT) )begin
            if(vram_input_data_3[0][y2_data_cnt][DATA_WIDTH -1'b1 - x0_data_cnt] == 1'b1)
                pixel_data <= BLUE;
            else
                pixel_data <= BLACK;
        // 4.4.1.accurate_calc的个位
        end else if( (pixel_xpos >= DATA_X_START + 4 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 5 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 6 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 7 * DATA_HEIGHT) )begin
            if(vram_input_data_4[4][y3_data_cnt][DATA_WIDTH -1'b1 - x4_data_cnt] == 1'b1)
                pixel_data <= GREEN;
            else
                pixel_data <= BLACK;
        // 4.4.2.accurate_calc的十位
        end else if( (pixel_xpos >= DATA_X_START + 3 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 4 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 6 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 7 * DATA_HEIGHT) )begin
            if(vram_input_data_4[3][y3_data_cnt][DATA_WIDTH -1'b1 - x3_data_cnt] == 1'b1)
                pixel_data <= GREEN;
            else
                pixel_data <= BLACK;
        // 4.4.3.accurate_calc的百位
        end else if( (pixel_xpos >= DATA_X_START + 2 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 3 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 6 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 7 * DATA_HEIGHT) )begin
            if(vram_input_data_4[2][y3_data_cnt][DATA_WIDTH -1'b1 - x2_data_cnt] == 1'b1)
                pixel_data <= GREEN;
            else
                pixel_data <= BLACK;
        // 4.4.4.accurate_calc的千位
        end else if( (pixel_xpos >= DATA_X_START + 1 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 2 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 6 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 7 * DATA_HEIGHT) )begin
            if(vram_input_data_4[1][y3_data_cnt][DATA_WIDTH -1'b1 - x1_data_cnt] == 1'b1)
                pixel_data <= GREEN;
            else
                pixel_data <= BLACK;
        // 4.4.5.accurate_calc的万位
        end else if( (pixel_xpos >= DATA_X_START + 0 * DATA_WIDTH)  && (pixel_xpos < DATA_X_START + 1 * DATA_WIDTH) && 
                     (pixel_ypos >= DATA_Y_START + 6 * DATA_HEIGHT) && (pixel_ypos < DATA_Y_START + 7 * DATA_HEIGHT) )begin
            if(vram_input_data_4[0][y3_data_cnt][DATA_WIDTH -1'b1 - x0_data_cnt] == 1'b1)
                pixel_data <= GREEN;
            else
                pixel_data <= BLACK;
        // 5.显示瀑布图
        end else if( (pixel_xpos >= FIG_X_START) && (pixel_xpos < FIG_X_START + FIG_WIDTH) && 
                     (pixel_ypos >= FIG_Y_START) && (pixel_ypos < FIG_Y_START + FIG_HEIGHT) )begin
            if((pixel_ypos <= (FIG_Y_START + FIG_HEIGHT)) && (pixel_ypos > (FIG_Y_END - vram_czt_result[x_fig_cnt])))
                pixel_data <= WHITE;
            else
                pixel_data <= BLACK;
        // 剩余区域使用黑色填充
        end else begin
            pixel_data <= BLACK;
        end
    end    
end
    
    
    
endmodule



// 8*16（width*height）
//00 00 00 00 00 00 00 38 44 0C 34 44 4C 36 00 00;//"a",0
//00 00 00 00 C0 40 40 58 64 42 42 42 64 58 00 00;//"b",1
//00 00 00 00 00 00 00 1C 22 40 40 40 22 1C 00 00;//"c",2
//00 00 00 00 06 02 02 3E 42 42 42 42 46 3B 00 00;//"d",3
//00 00 00 00 00 00 00 3C 42 42 7E 40 42 3C 00 00;//"e",4
//00 00 00 00 0C 12 10 7C 10 10 10 10 10 7C 00 00;//"f",5
//00 00 00 00 00 00 00 3E 44 44 38 40 3C 42 42 3C;//"g",6
//00 00 00 00 C0 40 40 5C 62 42 42 42 42 E7 00 00;//"h",7
//00 00 00 30 30 00 00 70 10 10 10 10 10 7C 00 00;//"i",8
//00 00 00 0C 0C 00 00 1C 04 04 04 04 04 04 44 78;//"j",9
//00 00 00 00 C0 40 40 4E 48 50 70 48 44 EE 00 00;//"k",10
//00 00 00 10 70 10 10 10 10 10 10 10 10 7C 00 00;//"l",11
//00 00 00 00 00 00 00 FE 49 49 49 49 49 ED 00 00;//"m",12
//00 00 00 00 00 00 00 DC 62 42 42 42 42 E7 00 00;//"n",13
//00 00 00 00 00 00 00 3C 42 42 42 42 42 3C 00 00;//"o",14
//00 00 00 00 00 00 00 D8 64 42 42 42 64 58 40 E0;//"p",15
//00 00 00 00 00 00 00 1A 26 42 42 42 26 1A 02 07;//"q",16
//00 00 00 00 00 00 00 EE 32 20 20 20 20 F8 00 00;//"r",17
//00 00 00 00 00 00 00 3E 42 40 3C 02 42 7C 00 00;//"s",18
//00 00 00 00 00 10 10 7C 10 10 10 10 12 0C 00 00;//"t",19
//00 00 00 00 00 00 00 C6 42 42 42 42 46 3B 00 00;//"u",20
//00 00 00 00 00 00 00 EE 44 44 28 28 10 10 00 00;//"v",21
//00 00 00 00 00 00 00 DB 89 4A 5A 54 24 24 00 00;//"w",22
//00 00 00 00 00 00 00 76 24 18 18 18 24 6E 00 00;//"x",23
//00 00 00 00 00 00 00 E7 42 24 24 18 18 10 10 60;//"y",24
//00 00 00 00 00 00 00 7E 44 08 10 10 22 7E 00 00;//"z",25
//00 00 00 00 00 00 18 18 00 00 00 00 18 18 00 00;//":",26
//00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00;//" ",27
//00 02 04 08 08 10 10 10 10 10 10 08 08 04 02 00;//"(",28
//00 40 20 10 10 08 08 08 08 08 08 10 10 20 40 00;//")",29
//00 00 00 08 38 08 08 08 08 08 08 08 08 3E 00 00;//"1",30
//00 00 00 3C 42 42 42 02 04 08 10 20 42 7E 00 00;//"2",31
//00 00 00 3C 42 42 02 04 18 04 02 42 42 3C 00 00;//"3",32
//00 00 00 04 0C 0C 14 24 24 44 7F 04 04 1F 00 00;//"4",33
//00 00 00 7E 40 40 40 78 44 02 02 42 44 38 00 00;//"5",34
//00 00 00 18 24 40 40 5C 62 42 42 42 22 1C 00 00;//"6",35
//00 00 00 7E 42 04 04 08 08 10 10 10 10 10 00 00;//"7",36
//00 00 00 3C 42 42 42 24 18 24 42 42 42 3C 00 00;//"8",37
//00 00 00 38 44 42 42 42 46 3A 02 02 24 18 00 00;//"9",38
//00 00 00 18 24 42 42 42 42 42 42 42 24 18 00 00;//"0",39




