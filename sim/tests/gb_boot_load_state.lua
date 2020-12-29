require("vsim_comm")
require("luareg")

wait_ns(10000)

reg_set(0, gameboy.Reg_GB_on)

reg_set_file("tests\\tetris.gb", 0, 0, 0)
print("Game transfered")

reg_set_file("C:\\Users\\FPGADev\\Desktop\\savestates_gb\\Tetris (World) (Rev A).ss", 58720256 + 0xC000000, 0, 0)
print("Savestate transfered")

wait_ns(10000)
reg_set(1, gameboy.Reg_GB_on)

--wait_ns(26000000)

reg_set(1, gameboy.Reg_GB_LoadState)

print("GB ON")

brk()