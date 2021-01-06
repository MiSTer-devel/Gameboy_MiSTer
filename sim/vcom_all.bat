
vcom -93 -quiet -work  sim/tb ^
src/tb/globals.vhd

vcom -93 -quiet -work  sim/mem ^
src/mem/SyncRamDualByteEnable.vhd ^
src/mem/SyncFifo.vhd 

vcom -quiet -work  sim/rs232 ^
src/rs232/rs232_receiver.vhd ^
src/rs232/rs232_transmitter.vhd ^
src/rs232/tbrs232_receiver.vhd ^
src/rs232/tbrs232_transmitter.vhd

vcom -quiet -work sim/procbus ^
src/procbus/proc_bus.vhd ^
src/procbus/testprocessor.vhd

vcom -quiet -work sim/reg_map ^
src/reg_map/reg_gameboy.vhd

vcom -quiet -work sim/gameboy ^
../rtl/bus_savestates.vhd ^
../rtl/reg_savestates.vhd ^
../rtl/gb_statemanager.vhd ^
../rtl/gb_savestates.vhd

vcom -quiet -work sim/gameboy ^
../rtl/T80/T80_Pack.vhd ^
../rtl/T80/T80_Reg.vhd ^
../rtl/T80/T80_MCode.vhd ^
../rtl/T80/T80_ALU.vhd ^
../rtl/T80/T80.vhd ^
../rtl/T80/GBse.vhd

vcom -quiet -work sim/gameboy ^
../rtl/gbc_snd.vhd ^
../rtl/speedcontrol.vhd ^
../rtl/dpram.vhd ^
../rtl/spram.vhd 

vlog -sv -quiet -work sim/gameboy ^
../rtl/sprites.v ^
../rtl/timer.v ^
../rtl/video.v ^
../rtl/link.v ^
../rtl/hdma.v

vlog -sv -quiet -work sim/gameboy ^
../rtl/gb.v

vlog -sv -quiet -work sim/gameboy ^
src/gameboy/mbc.sv ^
src/gameboy/cheatcodes.sv

vcom -quiet -work sim/gameboy ^
src/gameboy/boot_rom.vhd

vlog -sv -quiet -work sim/tb ^
../rtl/ddram.sv

vcom -quiet -work sim/tb ^
src/tb/stringprocessor.vhd ^
src/tb/tb_interpreter.vhd ^
src/tb/framebuffer.vhd ^
src/tb/gb_bios.vhd ^
src/tb/sdram_model.vhd ^
src/tb/ddrram_model.vhd ^
src/tb/tb.vhd