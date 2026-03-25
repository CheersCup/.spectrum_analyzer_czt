`timescale 1ns / 1ps

module testbench();

    // 系统接口
    reg clk_50M,clk_25M,clk_32M;
    reg resetn;
    
    // 信号发生器接口，调试用
    reg  ram_rd_en;
    reg  [10 : 0] ram_addra;
    wire [7 : 0] ram_dout;
    
    // 粗算频谱模块接口
    wire [18 : 0] rough_calc_dout;
    wire [10 : 0] rough_calc_idx;
    wire [9 : 0]  rough_calc_max_index;
    wire [18 : 0] rough_calc_max_data;
    
    // chirp_gen模块接口
    reg chirp_gen_enable;
    wire [31 : 0] chirp_gen_din_init;
    wire [31 : 0] chirp_gen_din_step;
    wire [24 : 0] chirp_gen_dout_real;
    wire [24 : 0] chirp_gen_dout_imag;
    wire [31 : 0] chirp_gen_dout_phase;
    wire [11 : 0] chirp_gen_dout_index;
    wire chirp_gen_dout_valid;
    reg  [1 : 0] chirp_gen_dout_enable;
    
    // param_calc模块接口
    reg  param_calc_enable;
    wire [23 : 0] param_calc_din_f0;
    wire [23 : 0] param_calc_din_fl;
    wire [31 : 0] param_calc_dout_theta;
    wire [31 : 0] param_calc_dout_phi;
    wire param_calc_dout_valid;
    
    // dual_port_ram模块接口
    wire [0 : 0] dual_port_ram_load_enable;
    reg  [10 : 0] dual_port_ram_wr_addra;
    reg  [10 : 0] dual_port_ram_rd_addra;
    wire [7 : 0] dual_port_ram_dout_xn;
    reg  dual_port_ram_rd_enable;
    reg  sync_output_1_enable;
    
    // 复数乘法器1接口
    reg  cmpy_1_aclken;
    wire cmpy_1_s_axis_a_tvalid;
    wire cmpy_1_s_axis_b_tvalid;
    wire cmpy_1_m_axis_dout_tvalid;
    wire [47 : 0] cmpy_1_s_axis_a_tdata;
    wire [31 : 0] cmpy_1_s_axis_b_tdata;
    wire [79 : 0] cmpy_1_m_axis_dout_tdata;
    wire [31 : 0] cmpy_1_m_axis_dout_tdata_real;
    wire [31 : 0] cmpy_1_m_axis_dout_tdata_imag;
    reg  cmpy_1_s_axis_aandb_tvalid;
    
    // L点FFT（输出G(r)）模块接口
    wire [15 : 0] xfft_dout_Gr_s_axis_config_tdata;
    wire [47 : 0] xfft_dout_Gr_s_axis_data_tdata;
    wire xfft_dout_Gr_s_axis_config_tready;
    reg  xfft_dout_Gr_s_axis_data_tvalid;
    wire xfft_dout_Gr_s_axis_data_tready;
    reg  xfft_dout_Gr_s_axis_data_tlast;
    wire [47 : 0] xfft_dout_Gr_m_axis_data_tdata;
    wire [15 : 0] xfft_dout_Gr_m_axis_data_tuser;
    wire xfft_dout_Gr_m_axis_data_tvalid;
    wire xfft_dout_Gr_m_axis_data_tlast;
    reg  [11 : 0] fft_din_cnt;
    wire [22 : 0] xfft_dout_Gr_m_axis_data_tdata_real;
    wire [22 : 0] xfft_dout_Gr_m_axis_data_tdata_imag;
    wire xfft_dout_Gr_event_frame_started;
    wire xfft_dout_Gr_event_tlast_missing;
    reg  aclken;
    reg  aresetn;
    
    // czt接口
    reg  thinning_czt_enable;
    reg  [23 : 0] thinning_czt_param_calc_din_f0;
    reg  [23 : 0] thinning_czt_param_calc_din_fl;
    reg  thinning_czt_dout_enable;
    reg  [11 : 0] thinning_czt_dout_index;
    wire [91 : 0] thinning_czt_dout_data;
    wire thinning_czt_finish_flag;
    wire [10 : 0] thinning_czt_max_index;
    wire thinning_czt_dout_valid;
    wire [6 : 0] thinning_czt_msb_position;
    
    // 控制信号
    reg  load_enable;
    
    // 控制状态
    reg  loaded_flag;
    

// 生成时钟
always #10 clk_50M = ~clk_50M;
always #20 clk_25M = ~clk_25M;
always #15.625 clk_32M = ~clk_32M;

initial begin
   clk_50M = 0;
   clk_25M = 0;
   clk_32M = 0;
   resetn = 0;
   ram_rd_en = 0;
   param_calc_enable = 0;
   chirp_gen_enable = 0;
   cmpy_1_aclken = 0;
   cmpy_1_s_axis_aandb_tvalid = 0;
   chirp_gen_dout_enable = 2'b01;
   xfft_dout_Gr_s_axis_data_tvalid = 1'b0;
   aclken = 1'b0;
   thinning_czt_param_calc_din_f0 = 24'd800_000;
   thinning_czt_param_calc_din_fl = 24'd200_000;
   thinning_czt_enable = 0;
   
   //chirp_gen_da_trig = 1'b0;
   # 200 resetn = 1;
         param_calc_enable = 1;
   # 100 chirp_gen_enable = 1;
         
   # 0 ram_rd_en= 1;
      cmpy_1_aclken = 1'b1;
      cmpy_1_s_axis_aandb_tvalid = 1;
      xfft_dout_Gr_s_axis_data_tvalid = 1'b1;
      #30000 aclken = 1'b1;
   # 1000 cmpy_1_aclken = 0;
        thinning_czt_enable = 1;
        # 20 
        thinning_czt_enable = 0;
   # 200 cmpy_1_aclken = 1;
   # 100 chirp_gen_enable = 1;
         chirp_gen_dout_enable = 2'b10;
   //chirp_gen_da_trig = 1'b1;
   //# 20  chirp_gen_da_trig = 1'b0;
   # 10000  param_calc_enable = 1'b0;
            cmpy_1_s_axis_aandb_tvalid = 0;
            cmpy_1_aclken = 1'b0;
   # 3000000 aclken = 1'b0;
            thinning_czt_enable = 1;
            # 20 
            thinning_czt_enable = 0;
//   # 300    aclken = 1'b1;
end

// 分辨率15.625Khz
//----------------------------------------2048点信号生成部分：----------------------------------------
// 周期性产生2048点正弦信号地址    
always@(posedge clk_32M or negedge resetn)begin
	if(resetn == 1'b0)
		ram_addra <= 11'd325;
	else if(ram_rd_en == 1'b1)
	    ram_addra <= ram_addra + 11'd61; // 953.125kHz
end

// 生成单口RAM的IP模块，读使能信号Ram_rd_en由外部测试信号给出
blk_mem_gen_simulation blk_mem_gen_simulation_inst (
  .clka(clk_32M),       // input wire clka
  .ena(ram_rd_en),      // input wire ena
  .wea(1'b0),           // input wire [0 : 0] wea
  .addra(ram_addra),    // input wire [10 : 0] addra
  .dina(8'b0),          // input wire [7 : 0] dina
  .douta(ram_dout)      // output wire [7 : 0] douta
);

//-------------------------------------------CZT模块：---------------------------------------------
thinning_czt u_thinning_czt(
    .calc_clk           (clk_50M),
    .ad_clk             (clk_32M),
    .rst_n              (resetn),
    
    // A/D采样数据
    .ad_data            (ram_dout),
    
    // czt转换使能信号，脉冲信号，不可长时间有效
    .czt_enable         (thinning_czt_enable),
    // 
    .param_calc_din_f0  (thinning_czt_param_calc_din_f0),
    .param_calc_din_fl  (thinning_czt_param_calc_din_fl),
    
    .czt_finish_flag    (thinning_czt_finish_flag),
    .czt_dout_index     (thinning_czt_dout_index),          // czt输出结果索引
    .czt_dout_data      (thinning_czt_dout_data),           // czt输出结果值
    .max_index          (thinning_czt_max_index),
    .czt_dout_valid     (thinning_czt_dout_valid),
    .msb_position       (thinning_czt_msb_position)
    );


//----------------------------------------ADC采样缓存部分：----------------------------------------
    // 装载2048个采样点，写时钟与ADC驱动时钟同频
//    always@(posedge clk_50M or negedge resetn)begin
//        if(resetn == 1'b0)begin
//            dual_port_ram_wr_addra <= 11'd0;
//            loaded_flag <= 1'b0;
//        end else if(load_enable == 1'b1)begin
//            if(dual_port_ram_wr_addra == 11'd2047)begin
//                dual_port_ram_wr_addra <= 11'd0;
//                loaded_flag <= 1'b1;
//            end else begin
//                dual_port_ram_wr_addra <= dual_port_ram_wr_addra + 11'd1;
//                loaded_flag <= 1'b0;
//            end
//        end else begin
//            dual_port_ram_wr_addra <= dual_port_ram_wr_addra;
//            loaded_flag <= loaded_flag;
//        end
//    end  

// 缓存2048点数据
//dual_port_ram_xn u_dual_port_ram_xn(
//  .clka(clk_50M),                    // input wire clka
//  .wea(load_enable),                 // input wire [0 : 0] wea
//  .addra(dual_port_ram_wr_addra),    // input wire [10 : 0] addra
//  .dina(ram_dout),                   // input wire [7 : 0] dina
//  .clkb(clk_50M),                    // input wire clkb
//  .enb(sync_output_1_enable),        // input wire enb
//  .addrb(dual_port_ram_rd_addra),    // input wire [10 : 0] addrb
//  .doutb(dual_port_ram_dout_xn)      // output wire [7 : 0] doutb
//);
    
    // 读出数据
//    always@(posedge clk_50M or negedge resetn)begin
//        if(resetn == 1'b0)begin
//            dual_port_ram_rd_addra <= 11'd0;
//        end else if(sync_output_1_enable == 1'b1)begin
//            if(dual_port_ram_rd_addra == 11'd2047)begin
//                dual_port_ram_rd_addra <= 11'd0;
//            end else begin
//                dual_port_ram_rd_addra <= dual_port_ram_rd_addra + 11'd1;
//            end
//        end else begin
//            dual_port_ram_rd_addra <= dual_port_ram_rd_addra;
//        end
//    end  

// 粗算频谱模块
//rough_calc rough_calc_inst(
//    .clk            (clk_50M),
//    .rst_n          (resetn),
//    .start          (1'b1), 
//    .ad_data        (ram_dout),
//    .fft_dout_abs   (rough_calc_dout),
//    .fft_dout_idx   (rough_calc_idx),
//    .max_index      (rough_calc_max_index),
//    .max_data       (rough_calc_max_data)
//    );

// chirp信号生成模块1
//assign chirp_gen_din_init = 32'd13_421_772;
//assign chirp_gen_din_step = 32'd65_536;

//chirp_gen_1 chirp_gen_1_inst(
//    .clk        (clk_50M),
//    .rst_n      (resetn),
//    .enable     (chirp_gen_enable),      // 产生chirp信号的触发标志
//    .init_phase (chirp_gen_din_init),
//    .step_phase (chirp_gen_din_step),
//    .dout_valid (chirp_gen_dout_valid),
//    .chirp_real (chirp_gen_dout_real),   // 生成的chirp信号实部
//    .chirp_imag (chirp_gen_dout_imag),   // 生成的chirp信号虚部
//    .chirp_phase(chirp_gen_dout_phase),
//    .chirp_index(chirp_gen_dout_index)
//);

// chirp信号生成模块2
//assign chirp_gen_din_step = 32'd65_536;

//chirp_gen_2 u_chirp_gen_2(
//    .clk            (clk_50M),
//    .rst_n          (resetn),
//    .enable         (chirp_gen_enable),        // 产生chirp信号的触发标志，一个周期的脉冲信号
//    .dout_switch    (chirp_gen_dout_enable),   // 输出chirp信号源选择：2'b01为输出2048点原始的chirp信号；2'b10为输出4096点进行周期延拓后的chirp信号
//    .step_phase     (chirp_gen_din_step),      // step_phase = φ；数据类型为ufix32_32
//    .dout_valid     (chirp_gen_dout_valid),    // 输出数据有效
//    .chirp_real     (chirp_gen_dout_real),     // cos，fix13_11;生成的chirp信号实部
//    .chirp_imag     (chirp_gen_dout_imag),     // sin，fix13_11;生成的chirp信号虚部
//    .chirp_phase    (chirp_gen_dout_phase),    // 生成的chirp相位信号；弧度值，ufix32_32
//    .chirp_index    (chirp_gen_dout_index)     // 生成的chirp信号的索引
//    );

// chirp信号参数计算模块
//assign param_calc_din_f0 = 24'd100_000;
//assign param_calc_din_fl = 24'd1_000_000;

//param_calc param_calc(
//    .clk        (clk_50M),
//    .rst_n      (resetn),
//    .enable     (param_calc_enable),        // 使能除法运算,此时数据线有效；高电平有效
//    .f0         (param_calc_din_f0),        // 频谱分析的起点
//    .fl         (param_calc_din_fl),        // 频谱分析的长度
//    .theta      (param_calc_dout_theta),    // theta
//    .phi        (param_calc_dout_phi),      // phi
//    .dout_valid (param_calc_dout_valid)     // 输出角度有效
//    );


// 复数乘法器1
//assign cmpy_1_s_axis_a_tvalid = 1'b1;
//assign cmpy_1_s_axis_b_tvalid = 1'b1;
//assign cmpy_1_s_axis_a_tdata =  {1'b0, 1'b0, 22'd7, 1'b0, 1'b0, 22'd11};
//assign cmpy_1_s_axis_b_tdata =  {3'b0, 1'b0, 12'd10, 3'b0, 1'b0, 12'd6};
//assign cmpy_1_m_axis_dout_tdata_real = cmpy_1_m_axis_dout_tdata[31 : 0];
//assign cmpy_1_m_axis_dout_tdata_imag = cmpy_1_m_axis_dout_tdata[63 : 32];

//cmpy_1 u_cmpy_dout_gn(
//  .aclk(clk_50M),                                  // input wire aclk
//  .aclken(cmpy_1_aclken),                          // input wire aclken
//  .s_axis_a_tvalid(cmpy_1_s_axis_aandb_tvalid),        // input wire s_axis_a_tvalid
//  .s_axis_a_tdata(cmpy_1_s_axis_a_tdata),          // input wire [31 : 0] s_axis_a_tdata
//  .s_axis_b_tvalid(cmpy_1_s_axis_aandb_tvalid),        // input wire s_axis_b_tvalid
//  .s_axis_b_tdata(cmpy_1_s_axis_b_tdata),          // input wire [31 : 0] s_axis_b_tdata
//  .m_axis_dout_tvalid(cmpy_1_m_axis_dout_tvalid),  // output wire m_axis_dout_tvalid
//  .m_axis_dout_tdata(cmpy_1_m_axis_dout_tdata)    // output wire [47 : 0] m_axis_dout_tdata
//);

//
//cmpy_2 your_instance_name (
//  .aclk(clk_50M),                              // input wire aclk
//  .aresetn(cmpy_1_aclken),                        // input wire aresetn
//  .s_axis_a_tvalid(cmpy_1_s_axis_aandb_tvalid),        // input wire s_axis_a_tvalid
//  .s_axis_a_tdata(cmpy_1_s_axis_a_tdata),          // input wire [47 : 0] s_axis_a_tdata
//  .s_axis_b_tvalid(cmpy_1_s_axis_aandb_tvalid),        // input wire s_axis_b_tvalid
//  .s_axis_b_tdata(cmpy_1_s_axis_b_tdata),          // input wire [31 : 0] s_axis_b_tdata
//  .m_axis_dout_tvalid(cmpy_1_m_axis_dout_tvalid),  // output wire m_axis_dout_tvalid
//  .m_axis_dout_tdata(cmpy_1_m_axis_dout_tdata)    // output wire [79 : 0] m_axis_dout_tdata
//);

//// radix-2 fft
//    parameter FFT_LEN = 4096;
//    parameter PAD_0 = 3'b0;      // （15 : 13），bit3；边界对齐8bit整数倍
//    parameter SCALE_SCH_0 = 12'b10_10_10_10_10_10;  // （12 ：1），bit12；2*ceil(0.5*log2(N))=12bit;在每层蝶形单元输出上加权，按比例减小输出;N点压缩N倍；保守缩放
//    parameter FWD_INV_0 = 1'b1;  // （0 : 0），bit1；进行fft正变换 

//assign xfft_dout_Gr_s_axis_config_tdata = {PAD_0, SCALE_SCH_0, FWD_INV_0};

//assign xfft_dout_Gr_s_axis_data_tdata = {1'b0, 23'b0, 1'b0, 15'b0, ram_dout};

//xfft_dout_Gr u_xfft_dout_Gr(
//  .aclk(clk_50M),                                                          // input wire aclk
//  .aresetn(aclken),                                          // input wire aresetn
  
//  .s_axis_config_tdata(xfft_dout_Gr_s_axis_config_tdata),                  // input wire [31 : 0] s_axis_config_tdata
//  .s_axis_config_tvalid(1'b1),                                             // input wire s_axis_config_tvalid
//  .s_axis_config_tready(xfft_dout_Gr_s_axis_config_tready),                // output wire s_axis_config_tready
  
//  .s_axis_data_tdata(xfft_dout_Gr_s_axis_data_tdata),                      // input wire [47 : 0] s_axis_data_tdata
//  .s_axis_data_tvalid(xfft_dout_Gr_s_axis_data_tvalid),                    // input wire s_axis_data_tvalid
//  .s_axis_data_tready(xfft_dout_Gr_s_axis_data_tready),                    // output wire s_axis_data_tready
//  .s_axis_data_tlast(xfft_dout_Gr_s_axis_data_tlast),                      // input wire s_axis_data_tlast
  
//  .m_axis_data_tdata(xfft_dout_Gr_m_axis_data_tdata),                      // output wire [47 : 0] m_axis_data_tdata
//  .m_axis_data_tuser(xfft_dout_Gr_m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
//  .m_axis_data_tvalid(xfft_dout_Gr_m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
//  .m_axis_data_tready(1'b1),                                               // input wire m_axis_data_tready
//  .m_axis_data_tlast(xfft_dout_Gr_m_axis_data_tlast),                      // output wire m_axis_data_tlast
  
//  .event_frame_started(xfft_dout_Gr_event_frame_started),                  // output wire event_frame_started
//  .event_tlast_unexpected(),            // output wire event_tlast_unexpected
//  .event_tlast_missing(xfft_dout_Gr_event_tlast_missing),                  // output wire event_tlast_missing
//  .event_status_channel_halt(),      // output wire event_status_channel_halt
//  .event_data_in_channel_halt(),    // output wire event_data_in_channel_halt
//  .event_data_out_channel_halt()  // output wire event_data_out_channel_halt
//);
    
//    always@(posedge clk_50M or negedge resetn)begin
//        if(resetn == 1'b0)
//            fft_din_cnt <= 12'd0;
//        else if((fft_din_cnt == FFT_LEN - 1) && (xfft_dout_Gr_s_axis_data_tvalid == 1'b1) && aclken)
//            fft_din_cnt <= 12'd0;        
//        else if(xfft_dout_Gr_s_axis_data_tvalid == 1'b1)
//            fft_din_cnt <= fft_din_cnt + 12'b1;
//        else if(aclken == 1'b0)
//            fft_din_cnt <= 12'b0;
//    end
    
//    always@(posedge clk_50M or negedge resetn)begin
//        if(resetn == 1'b0)
//            xfft_dout_Gr_s_axis_data_tlast <= 1'b0;
//        else if(fft_din_cnt == FFT_LEN - 2)
//            xfft_dout_Gr_s_axis_data_tlast <= 1'b1;
//        else
//            xfft_dout_Gr_s_axis_data_tlast <= 1'b0;                    
//    end
    
//    assign xfft_dout_Gr_m_axis_data_tdata_real = xfft_dout_Gr_m_axis_data_tdata[22 : 0];
//    assign xfft_dout_Gr_m_axis_data_tdata_imag = xfft_dout_Gr_m_axis_data_tdata[46 : 24];

endmodule
