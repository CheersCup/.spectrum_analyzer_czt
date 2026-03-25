`timescale 1ns / 1ps

module da_gen(
    input rst_n  ,      //复位信号，低电平有效
    input clk,          
    input key0_value           ,       //消抖后的按键值
    input key0_flag            ,       //消抖后的按键值的效标志
    input key1_value           ,       //消抖后的按键值
    input key1_flag            ,       //消抖后的按键值的效标志
                                         
    input  [7:0]    rd_data,     //ROM读出的数据
    output reg  [10:0]    rd_addr,      //读ROM地址
    //DA芯片接口                        
    output da_clk ,      //DA(AD9708)驱动时钟,最大支持125Mhz时钟
    output [7:0]    da_data       //输出给DA的数据  
    );
    
 //parameter
 parameter  sine_wave_addr     = 11'd0;   // 正弦波起始位置 
 
 //频率调节控制，FREQ_ADJ的越大,最终输出的频率越低,范围0~255
 parameter  FREQ_ADJ0 = 8'd0;            //参数0对应输出1Mhz波形频率
 parameter  FREQ_ADJ1 = 8'd1;            //参数1对应输出500khz波形频率
 parameter  FREQ_ADJ2 = 8'd3;            //参数3对应输出250khz波形频率
 parameter  FREQ_ADJ3 = 8'd7;            //参数7对应输出125khz波形频率
                                         
 //reg define                            
 reg    [7:0]     freq_adj    ;          //频率调节参数寄存器
 reg    [7:0]     freq_cnt    ;          //频率调节计数器
 reg    [1:0]     freq_select ;          //切换波形频率寄存器
 
 //*****************************************************
 //**                    main code
 //*****************************************************
 
 //数据rd_data是在clk_100M的上升沿更新的，
 //所以DA芯片在clk_100M的下降沿锁存数据是稳定的时刻。
 //而DA实际上在da_clk的上升沿锁存数据,所以时钟取反,
 //这样 clk_100M 的下降沿相当于 da_clk 的上升沿。           
 assign  da_clk =~clk;       
 assign  da_data = rd_data;  //将读到的ROM数据赋值给DA数据端口
    

 //切换波形频率
 always @(posedge clk or negedge rst_n) begin
     if(rst_n == 1'b0)
         freq_select <= 2'd0;
     else if((key1_flag ==1) && (key1_value ==0)) begin //确保按键key1确实被有效按下
            if(freq_select < 2'd3)
               freq_select <= freq_select+1'd1;
            else  
                freq_select <= 0;
           end
          else 
              freq_select <= freq_select;
 end
 always @(posedge clk or negedge rst_n) begin
     if(rst_n == 1'b0)
       freq_adj <= 8'd0;
     else case(freq_select)
              2'd0:freq_adj <= FREQ_ADJ0;
              2'd1:freq_adj <= FREQ_ADJ1;   
              2'd2:freq_adj <= FREQ_ADJ2;
              2'd3:freq_adj <= FREQ_ADJ3;
             default:freq_adj <= FREQ_ADJ0;
          endcase
 end
 
 //频率调节计数器
 always @(posedge clk or negedge rst_n) begin
     if(rst_n == 1'b0)
         freq_cnt <= 8'd0;
     else if(freq_cnt == freq_adj)    
         freq_cnt <= 8'd0;
     else         
         freq_cnt <= freq_cnt + 8'd1;
 end
 
 //读ROM地址,按照100M的频率去读
 always @(posedge clk or negedge rst_n) begin
     if(rst_n == 1'b0)
        rd_addr <= 11'd0;
     else if(freq_cnt == freq_adj) begin
                 if(rd_addr >= sine_wave_addr && rd_addr <= sine_wave_addr+11'd2047)    
                   if(rd_addr == sine_wave_addr+11'd2047)  
                      rd_addr <= sine_wave_addr;
                   else 
                       rd_addr <= rd_addr+11'd1; 
                 else 
                     rd_addr <= sine_wave_addr;      
     end else  rd_addr <= rd_addr;             
 end
    
    
    
endmodule



