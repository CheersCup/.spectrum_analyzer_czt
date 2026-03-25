`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/14 19:43:41
// Design Name: 
// Module Name: key_board
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


module key_board(
    input clk,
    input rst_n,
    
    output reg led,
    input  [3:0] row,                    // 矩阵键盘 行
    output reg [3:0] col,                // 矩阵键盘 列
    output reg [3:0] keyboard_val,       // 键盘值
    output reg [23 : 0] input_f0,        // 输入值f0
    output reg [23 : 0] input_fl,        // 输入值fl
    output reg input_valid              // 输入有效
);

//++++++++++++++++++++++++++++++++++++++
// 分频部分 开始
//++++++++++++++++++++++++++++++++++++++
reg [19:0] cnt;                         // 去抖动计数器

always @ (posedge clk, negedge rst_n)
  if (!rst_n)
    cnt <= 0;
  else
    cnt <= cnt + 1'b1;

wire key_clk = cnt[19];                 //T =(2^20/50M = 20.97152)ms
//--------------------------------------
// 分频部分 结束
//--------------------------------------


//++++++++++++++++++++++++++++++++++++++
// 状态机部分 开始
//++++++++++++++++++++++++++++++++++++++
// 状态数较少，独热码编码
parameter NO_KEY_PRESSED = 6'b000_001;  // 没有按键按下
parameter SCAN_COL0      = 6'b000_010;  // 扫描第0列
parameter SCAN_COL1      = 6'b000_100;  // 扫描第1列
parameter SCAN_COL2      = 6'b001_000;  // 扫描第2列
parameter SCAN_COL3      = 6'b010_000;  // 扫描第3列
parameter KEY_PRESSED    = 6'b100_000;  // 有按键按下

reg [5:0] current_state, next_state;    // 现态、次态

always @ (posedge key_clk or negedge rst_n)
  if (!rst_n)
    current_state <= NO_KEY_PRESSED;
  else
    current_state <= next_state;

// 根据条件转移状态
always @(*)
  case (current_state)
    NO_KEY_PRESSED :                    // 没有按键按下
        if (row != 4'hF)
          next_state = SCAN_COL0;
        else
          next_state = NO_KEY_PRESSED;
    SCAN_COL0 :                         // 扫描第0列
        if (row != 4'hF)
          next_state = KEY_PRESSED;
        else
          next_state = SCAN_COL1;
    SCAN_COL1 :                         // 扫描第1列
        if (row != 4'hF)
          next_state = KEY_PRESSED;
        else
          next_state = SCAN_COL2;
    SCAN_COL2 :                         // 扫描第2列
        if (row != 4'hF)
          next_state = KEY_PRESSED;
        else
          next_state = SCAN_COL3;
    SCAN_COL3 :                         // 扫描第3列
        if (row != 4'hF)
          next_state = KEY_PRESSED;
        else
          next_state = NO_KEY_PRESSED;
    KEY_PRESSED :                       // 有按键按下
        if (row != 4'hF)
          next_state = KEY_PRESSED;
        else
          next_state = NO_KEY_PRESSED;
  endcase

reg       key_pressed_flag;             // 键盘按下标志
reg [3:0] col_val, row_val;             // 列值、行值

// 根据次态，给相应寄存器赋值
always @ (posedge key_clk or negedge rst_n)
  if (!rst_n)
  begin
    col              <= 4'h0;
    key_pressed_flag <=    0;
  end
  else
    case (next_state)
      NO_KEY_PRESSED :                  // 没有按键按下
      begin
        col              <= 4'h0;
        key_pressed_flag <=    0;       // 清键盘按下标志
      end
      SCAN_COL0 :                       // 扫描第0列
        col <= 4'b1110;
      SCAN_COL1 :                       // 扫描第1列
        col <= 4'b1101;
      SCAN_COL2 :                       // 扫描第2列
        col <= 4'b1011;
      SCAN_COL3 :                       // 扫描第3列
        col <= 4'b0111;
      KEY_PRESSED :                     // 有按键按下
      begin
        col_val          <= col;        // 锁存列值
        row_val          <= row;        // 锁存行值
        key_pressed_flag <= 1;          // 置键盘按下标志
      end
    endcase
//--------------------------------------
// 状态机部分 结束
//--------------------------------------
    wire key_pressed_flag_trig;
    reg  key_pressed_flag_d1;
    reg  key_pressed_flag_d2;
    reg  [1 : 0] input_switch;

    
    // 采样key_pressed_flag生成单脉冲
    always@(posedge key_clk or negedge rst_n)begin
        if(!rst_n)begin
            key_pressed_flag_d1 <= 1'b0;
            key_pressed_flag_d2 <= 1'b0;
        end else begin
            key_pressed_flag_d1 <= key_pressed_flag  ;
            key_pressed_flag_d2 <= key_pressed_flag_d1 ;
        end
    end
    
    // 生成使能信号的单脉冲
    assign key_pressed_flag_trig = (key_pressed_flag_d1) && (~key_pressed_flag_d2);

//++++++++++++++++++++++++++++++++++++++
// 扫描行列值部分 开始
//++++++++++++++++++++++++++++++++++++++
always @ (posedge key_clk, negedge rst_n)begin
    if (!rst_n)begin
        keyboard_val <= 4'h0;
    end else begin
        if (key_pressed_flag)begin
        
            case ({col_val, row_val})
                8'b1110_1110 : begin
                    keyboard_val <= 4'h0;
                end 8'b1110_1101 : begin
                    keyboard_val <= 4'h4;
                end 8'b1110_1011 : begin
                    keyboard_val <= 4'h8;
                end 8'b1110_0111 : begin
                    keyboard_val <= 4'hC; // 确定

                end 8'b1101_1110 : begin
                    keyboard_val <= 4'h1;
                end 8'b1101_1101 : begin
                    keyboard_val <= 4'h5;
                end 8'b1101_1011 : begin
                    keyboard_val <= 4'h9;
                end 8'b1101_0111 : begin
                    keyboard_val <= 4'hD; // 
        
                end 8'b1011_1110 : begin
                    keyboard_val <= 4'h2;
                end 8'b1011_1101 : begin
                    keyboard_val <= 4'h6;
                end 8'b1011_1011 : begin
                    keyboard_val <= 4'hA; // 按下表示输入f0
                end 8'b1011_0111 : begin
                    keyboard_val <= 4'hE;
        
                end 8'b0111_1110 : begin
                    keyboard_val <= 4'h3;
                end 8'b0111_1101 : begin
                    keyboard_val <= 4'h7;
                end 8'b0111_1011 : begin
                    keyboard_val <= 4'hB; // 按下表示输入fl
                end 8'b0111_0111 : begin
                    keyboard_val <= 4'hF;
                end
            endcase
        end else begin
            keyboard_val <= 4'hF;
        end
    end
end
//--------------------------------------
//  扫描行列值部分 结束
//--------------------------------------

//---------------------------------------输入判断模块：----------------------------------------
    always@(posedge key_clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            input_switch <= 2'b00;
            input_f0     <= 24'd0;
            input_fl     <= 24'd0;
            input_valid  <= 1'b0;
            // debug
            led          <= 1'b0;
        end else if(key_pressed_flag_trig)begin // 每次按下按键时，该信号保持一个周期的有效状态
            // 按“E”复位
            if(keyboard_val == 4'hE)begin
//                input_switch <= 2'b00;
//                input_f0     <= 24'd0;
//                input_fl     <= 24'd0;
//                input_valid  <= 1'b0;
//                led          <= 1'b0;
            // 按“A”先输入f0
            end else if(keyboard_val == 4'hA)begin
                input_switch <= 2'b01;
                input_f0     <= 24'd0;
                led          <= 1'b0;
            // 按“B”先输入fl
            end else if(keyboard_val == 4'hB)begin
                input_switch <= 2'b10;
                input_fl     <= 24'd0;
                led          <= 1'b0;
            // 按“C”确认输入最后一个数据（f0或f1）
            end else if(keyboard_val == 4'hC)begin
                input_switch <= 2'b00;
                input_valid  <= 1'b1;
                led          <= 1'b1;
            // 按“0”-“9”计算所有输入的键值，得到总的输入值
            end else if((keyboard_val >= 4'h0) && (keyboard_val <= 4'h9))begin
//                led          <= 1'b0;
                if(input_switch == 2'b01)begin
                    input_f0 <= input_f0 * 10 + keyboard_val; // 缓存f0输入值
                end else if(input_switch == 2'b10)begin
                    input_fl <= input_fl * 10 + keyboard_val; // 缓存fl输入值
                end else begin
                    input_f0 <= input_f0;
                    input_fl <= input_fl;
                end
            end else begin // 全部锁存
                input_switch <= input_switch;
                input_f0     <= input_f0;
                input_fl     <= input_fl;
                input_valid  <= input_valid;
            end
        end else begin // 锁存值，只能靠按键复位
            input_switch <= input_switch;
            input_f0     <= input_f0;
            input_fl     <= input_fl;
            input_valid  <= input_valid;
        end
    end  
    
endmodule






