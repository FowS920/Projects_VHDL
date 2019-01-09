onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider PROPAGATE_TB
add wave -noupdate /propagate_tb/clk
add wave -noupdate /propagate_tb/reset
add wave -noupdate /propagate_tb/clk_en
add wave -noupdate /propagate_tb/dataa
add wave -noupdate /propagate_tb/datab
add wave -noupdate /propagate_tb/result
add wave -noupdate /propagate_tb/start
add wave -noupdate /propagate_tb/done
add wave -noupdate /propagate_tb/mem_clk
add wave -noupdate /propagate_tb/mem_reset
add wave -noupdate /propagate_tb/mem_address
add wave -noupdate /propagate_tb/mem_address_q0
add wave -noupdate /propagate_tb/mem_chipselect
add wave -noupdate /propagate_tb/mem_write
add wave -noupdate /propagate_tb/mem_read_data
add wave -noupdate /propagate_tb/mem_write_data
add wave -noupdate /propagate_tb/mem_byteenable
add wave -noupdate /propagate_tb/sub_image_data
add wave -noupdate /propagate_tb/sub_image_done
add wave -noupdate -divider PROPAGATE
add wave -noupdate /propagate_tb/xpropagate/clk
add wave -noupdate /propagate_tb/xpropagate/reset
add wave -noupdate /propagate_tb/xpropagate/mem_clk
add wave -noupdate /propagate_tb/xpropagate/mem_reset
add wave -noupdate /propagate_tb/xpropagate/mem_start
add wave -noupdate /propagate_tb/xpropagate/memory_access_state_p0
add wave -noupdate /propagate_tb/xpropagate/memory_access_state
add wave -noupdate /propagate_tb/xpropagate/memory_access_state_q0
add wave -noupdate -divider {Memory access}
add wave -noupdate /propagate_tb/xpropagate/mem_access_layer_p0
add wave -noupdate /propagate_tb/xpropagate/mem_access_layer
add wave -noupdate /propagate_tb/xpropagate/mem_access_input_p0
add wave -noupdate /propagate_tb/xpropagate/mem_access_input
add wave -noupdate /propagate_tb/xpropagate/mem_access_value_p0
add wave -noupdate /propagate_tb/xpropagate/mem_access_value
add wave -noupdate -divider Informations
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_layer_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_layer
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_input_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_input
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_input_modulo_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_input_modulo
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_value_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_value
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_value_modulo_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/cnt_value_modulo
add wave -noupdate -radix decimal /propagate_tb/xpropagate/nb_layer_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/nb_layer
add wave -noupdate -radix decimal /propagate_tb/xpropagate/nb_input_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/nb_input
add wave -noupdate -radix decimal /propagate_tb/xpropagate/nb_value_p0
add wave -noupdate -radix decimal /propagate_tb/xpropagate/nb_value
add wave -noupdate -divider Calculations
add wave -noupdate /propagate_tb/xpropagate/value_calculated_p0
add wave -noupdate /propagate_tb/xpropagate/value_calculated
add wave -noupdate /propagate_tb/xpropagate/calculated_values_p0
add wave -noupdate /propagate_tb/xpropagate/calculated_values
add wave -noupdate /propagate_tb/xpropagate/inputs
add wave -noupdate /propagate_tb/xpropagate/weights
add wave -noupdate /propagate_tb/xpropagate/value
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {84 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 206
configure wave -valuecolwidth 134
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1050 ns}
