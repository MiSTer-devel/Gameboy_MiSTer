RMDIR /s /q sim
MKDIR sim

vmap altera_mf altera_mf

vlib sim/mem
vmap mem sim/mem

vlib sim/rs232
vmap rs232 sim/rs232

vlib sim/procbus
vmap procbus sim/procbus

vlib sim/reg_map
vmap reg_map sim/reg_map

vlib sim/gameboy
vmap gameboy sim/gameboy

vlib sim/tb
vmap tb sim/tb

