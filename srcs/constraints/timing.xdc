# ----------------------------------timing constraints----------------------------------
# ----------------------------------------clocks----------------------------------------
# primary clocks
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]

# virtual clocks

# generated clocks
# 1.ad_clk
create_generated_clock -name ad_clk -source [get_pins u_clk_wiz_global/clk_32M] -multiply_by 1 [get_ports ad_clk]
# 2.key_clk
#create_generated_clock -name key_clk -source [get_pins u_clk_wiz_global/clk_50M] -divide_by 1048576 [get_pins u_key_board/key_clk]
# 3.lcd_pclk
create_generated_clock -name lcd_pclk_25M -source [get_pins u_clk_wiz_global/clk_50M] -divide_by 2 [get_pins u_results_waterfall/lcd_clk_div_inst/clk_25m]
create_generated_clock -name lcd_pclk_12_5M -source [get_pins u_clk_wiz_global/clk_50M] -divide_by 4 [get_pins u_results_waterfall/lcd_clk_div_inst/clk_12_5m]

# clock groups


# bus skew constraints


# ------------------------------------i/o constrains------------------------------------



# --------------------------------------exceptions--------------------------------------
# multicycle paths，提高运算时钟频率时添加对应约束
# 1.u_thinning_czt/calc_clk 2 u_thinning_czt/ad_clk
#set_multicycle_path 2 -setup -start -from [get_pins u_thinning_czt/clk_100M] -to [get_pins u_thinning_czt/clk_32M]
#set_multicycle_path 1 -hold -start -from [get_pins u_thinning_czt/clk_100M] -to [get_pins u_thinning_czt/clk_32M]
            
# false paths
# 1.false约束覆盖key_clk 2 clk_50M
#set_false_path -from [get_clocks key_clk] -to [get_clocks -of_objects [get_pins u_clk_wiz_global/inst/mmcm_adv_inst/CLKOUT0]]
#set_false_path -from [get_clocks -of_objects [get_pins u_clk_wiz_global/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks key_clk]
# 2.1.false约束覆盖lcd_pclk_25M 2 clk_50M
#set_false_path -from [get_clocks lcd_pclk_25M] -to [get_clocks -of_objects [get_pins u_clk_wiz_global/inst/mmcm_adv_inst/CLKOUT0]]
#set_false_path -from [get_clocks -of_objects [get_pins u_clk_wiz_global/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks lcd_pclk_25M]
# 2.2.false约束覆盖lcd_pclk_12_5M 2 clk_50M
#set_false_path -from [get_clocks lcd_pclk_12_5M] -to [get_clocks -of_objects [get_pins u_clk_wiz_global/inst/mmcm_adv_inst/CLKOUT0]]
#set_false_path -from [get_clocks -of_objects [get_pins u_clk_wiz_global/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks lcd_pclk_12_5M]

# 4.thinning
#set_false_path -from [get_pins u_thinning_czt/loaded_xn_flag_reg/C] -to [get_pins {u_thinning_czt/cache_reg[0]/D}]

# max/min dalay


