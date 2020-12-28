require("vsim_comm")
require("luareg")

wait_ns(10000)

reg_set(0, gameboy.Reg_GB_on)

reg_set_file("C:\\Users\\FPGADev\\Desktop\\COLORS.gbc", 0, 0, 0)

wait_ns(10000)
reg_set(1, gameboy.Reg_GB_on)
print("GB ON")
wait_ns(26000000)

print("Save")
reg_set(1, gameboy.Reg_GB_SaveState)
wait_ns(10000000)

print("Load")
reg_set(1, gameboy.Reg_GB_LoadState)

brk()