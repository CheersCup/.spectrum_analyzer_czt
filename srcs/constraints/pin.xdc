# ---------------------------------------管脚约束---------------------------------------
# 系统接口
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U18} [get_ports sys_clk]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN N16} [get_ports sys_rst_n]

# 按键接口
#set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN K16} [get_ports key]

# A/D接口，接按键一侧的排母
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U14} [get_ports {ad_data[7]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U15} [get_ports {ad_data[6]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN V12} [get_ports {ad_data[5]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W13} [get_ports {ad_data[4]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W14} [get_ports {ad_data[3]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y14} [get_ports {ad_data[2]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN V15} [get_ports {ad_data[1]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W15} [get_ports {ad_data[0]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN V13} [get_ports ad_clk]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN U13} [get_ports ad_otr]

# D/A接口
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y12} [get_ports {da_data[7]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y13} [get_ports {da_data[6]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN V10} [get_ports {da_data[5]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN V11} [get_ports {da_data[4]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W9 } [get_ports {da_data[3]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN W10} [get_ports {da_data[2]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y8 } [get_ports {da_data[1]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y9 } [get_ports {da_data[0]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN Y11} [get_ports da_clk]

# LCD接口
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[0]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[1]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[2]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[3]}]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[4]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[5]}]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[6]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[7]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[8]}]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[9]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[10]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[11]}]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[12]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[13]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[14]}]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[15]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[16]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[17]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[18]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[19]}]
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[20]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[21]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[22]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[23]}]

set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports lcd_hs]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports lcd_vs]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports lcd_de]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports lcd_bl]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports lcd_clk]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports lcd_rst]

# 4*4矩阵键盘接口
set_property -dict {PACKAGE_PIN V5  IOSTANDARD LVCMOS33} [get_ports {keyboard_row[0]}]
set_property -dict {PACKAGE_PIN U5  IOSTANDARD LVCMOS33} [get_ports {keyboard_row[1]}]
set_property -dict {PACKAGE_PIN V7  IOSTANDARD LVCMOS33} [get_ports {keyboard_row[2]}]
set_property -dict {PACKAGE_PIN W8  IOSTANDARD LVCMOS33} [get_ports {keyboard_row[3]}]
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS33} [get_ports {keyboard_col[0]}]
set_property -dict {PACKAGE_PIN U7  IOSTANDARD LVCMOS33} [get_ports {keyboard_col[1]}]
set_property -dict {PACKAGE_PIN T5  IOSTANDARD LVCMOS33} [get_ports {keyboard_col[2]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {keyboard_col[3]}]

# DEBUG_LED接口
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports led_1]
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33} [get_ports led_2]




