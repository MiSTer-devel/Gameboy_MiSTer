--space.name = {address, upper, lower, size, default}
gameboy = {}
gameboy.Reg_GB_on = {1056768,0,0,1,0,"gameboy.Reg_GB_on"} -- on = 1
gameboy.Reg_GB_lockspeed = {1056769,0,0,1,0,"gameboy.Reg_GB_lockspeed"} -- 1 = 100% speed
gameboy.Reg_GB_TestDone = {1056770,0,0,1,0,"gameboy.Reg_GB_TestDone"}
gameboy.Reg_GB_TestOk   = {1056770,1,1,1,0,"gameboy.Reg_GB_TestOk"}
gameboy.Reg_GB_CyclePrecalc = {1056771,15,0,1,100,"gameboy.Reg_GB_CyclePrecalc"}
gameboy.Reg_GB_CyclesMissing = {1056772,31,0,1,0,"gameboy.Reg_GB_CyclesMissing"}
gameboy.Reg_GB_BusAddr = {1056773,27,0,1,0,"gameboy.Reg_GB_BusAddr"}
gameboy.Reg_GB_BusRnW = {1056773,28,28,1,0,"gameboy.Reg_GB_BusRnW"}
gameboy.Reg_GB_BusACC = {1056773,30,29,1,0,"gameboy.Reg_GB_BusACC"}
gameboy.Reg_GB_BusWriteData = {1056774,31,0,1,0,"gameboy.Reg_GB_BusWriteData"}
gameboy.Reg_GB_BusReadData = {1056775,31,0,1,0,"gameboy.Reg_GB_BusReadData"}
gameboy.Reg_GB_MaxPakAddr = {1056776,24,0,1,0,"gameboy.Reg_GB_MaxPakAddr"}
gameboy.Reg_GB_VsyncSpeed = {1056777,31,0,1,0,"gameboy.Reg_GB_VsyncSpeed"}
gameboy.Reg_GB_KeyUp = {1056778,0,0,1,0,"gameboy.Reg_GB_KeyUp"}
gameboy.Reg_GB_KeyDown = {1056778,1,1,1,0,"gameboy.Reg_GB_KeyDown"}
gameboy.Reg_GB_KeyLeft = {1056778,2,2,1,0,"gameboy.Reg_GB_KeyLeft"}
gameboy.Reg_GB_KeyRight = {1056778,3,3,1,0,"gameboy.Reg_GB_KeyRight"}
gameboy.Reg_GB_KeyA = {1056778,4,4,1,0,"gameboy.Reg_GB_KeyA"}
gameboy.Reg_GB_KeyB = {1056778,5,5,1,0,"gameboy.Reg_GB_KeyB"}
gameboy.Reg_GB_KeyL = {1056778,6,6,1,0,"gameboy.Reg_GB_KeyL"}
gameboy.Reg_GB_KeyR = {1056778,7,7,1,0,"gameboy.Reg_GB_KeyR"}
gameboy.Reg_GB_KeyStart = {1056778,8,8,1,0,"gameboy.Reg_GB_KeyStart"}
gameboy.Reg_GB_KeySelect = {1056778,9,9,1,0,"gameboy.Reg_GB_KeySelect"}
gameboy.Reg_GB_cputurbo = {1056780,0,0,1,0,"gameboy.Reg_GB_cputurbo"} -- 1 = cpu free running, all other 16 mhz
gameboy.Reg_GB_SramFlashEna = {1056781,0,0,1,0,"gameboy.Reg_GB_SramFlashEna"} -- 1 = enabled, 0 = disable (disable for copy protection in some games)
gameboy.Reg_GB_MemoryRemap = {1056782,0,0,1,0,"gameboy.Reg_GB_MemoryRemap"} -- 1 = enabled, 0 = disable (enable for copy protection in some games)
gameboy.Reg_GB_SaveState = {1056783,0,0,1,0,"gameboy.Reg_GB_SaveState"}
gameboy.Reg_GB_LoadState = {1056784,0,0,1,0,"gameboy.Reg_GB_LoadState"}
gameboy.Reg_GB_FrameBlend = {1056785,0,0,1,0,"gameboy.Reg_GB_FrameBlend"} -- mix last and current frame
gameboy.Reg_GB_Pixelshade = {1056786,2,0,1,0,"gameboy.Reg_GB_Pixelshade"} -- pixel shade 1..4, 0 = off
gameboy.Reg_GB_SaveStateAddr = {1056787,25,0,1,0,"gameboy.Reg_GB_SaveStateAddr"} -- address to save/load savestate
gameboy.Reg_GB_Rewind_on = {1056788,0,0,1,0,"gameboy.Reg_GB_Rewind_on"}
gameboy.Reg_GB_Rewind_active = {1056789,0,0,1,0,"gameboy.Reg_GB_Rewind_active"}
gameboy.Reg_GB_DEBUG_CPU_PC = {1056800,31,0,1,0,"gameboy.Reg_GB_DEBUG_CPU_PC"}
gameboy.Reg_GB_DEBUG_CPU_MIX = {1056801,31,0,1,0,"gameboy.Reg_GB_DEBUG_CPU_MIX"}
gameboy.Reg_GB_DEBUG_IRQ = {1056802,31,0,1,0,"gameboy.Reg_GB_DEBUG_IRQ"}
gameboy.Reg_GB_DEBUG_DMA = {1056803,31,0,1,0,"gameboy.Reg_GB_DEBUG_DMA"}
gameboy.Reg_GB_DEBUG_MEM = {1056804,31,0,1,0,"gameboy.Reg_GB_DEBUG_MEM"}
gameboy.Reg_GB_CHEAT_FLAGS = {1056810,31,0,1,0,"gameboy.Reg_GB_CHEAT_FLAGS"}
gameboy.Reg_GB_CHEAT_ADDRESS = {1056811,31,0,1,0,"gameboy.Reg_GB_CHEAT_ADDRESS"}
gameboy.Reg_GB_CHEAT_COMPARE = {1056812,31,0,1,0,"gameboy.Reg_GB_CHEAT_COMPARE"}
gameboy.Reg_GB_CHEAT_REPLACE = {1056813,31,0,1,0,"gameboy.Reg_GB_CHEAT_REPLACE"}
gameboy.Reg_GB_CHEAT_RESET = {1056814,0,0,1,0,"gameboy.Reg_GB_CHEAT_RESET"}