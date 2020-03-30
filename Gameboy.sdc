derive_pll_clocks
derive_clock_uncertainty

set clk_ram {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}
set clk_sys {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}

set_multicycle_path -from [get_clocks $clk_ram] -to [get_clocks $clk_sys] -start -setup 2
set_multicycle_path -from [get_clocks $clk_ram] -to [get_clocks $clk_sys] -start -hold 1

set_multicycle_path -from {emu|gb|video|*} -setup 2
set_multicycle_path -from {emu|gb|video|*} -hold 1
