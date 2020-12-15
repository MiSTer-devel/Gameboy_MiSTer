require("vsim_comm")
require("luareg")

wait_ns(10000)

reg_set(0, gameboy.Reg_GB_on)

reg_set_file("tests\\tetris.gb", 0, 0, 0)

wait_ns(10000)
reg_set(1, gameboy.Reg_GB_on)

print("GB ON")

brk()