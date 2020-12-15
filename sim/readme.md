# Purpose of this document

This readme shall deliver a small introduction on what the simulation can be used for and how to simulate the GB core.

Requirements: Modelsim or compatible Simulator. Windows 7/10 for viewing gpu output.
Tested Version: Modelsim 10.5 

# Available features

The simulation framework allows:
- running ROM like on real hardware

Debugging options:
- waveform viewer in modelsim
- live graphical output

Speed:
1 second realtime(FPGA) will take in the range of 5 Minutes in simulation. So don't expect to run deep into a game. 

# Shortcoming

- The HPS Framework/Top level is not simulated at all, Cart download is done through a debug interface
- Sound cannot be checked other than viewing waveform

# How to start

- run sim/vmap_all.bat
- run sim/vcom_all.bat
- run sim/vsim_start.bat

Simualtion will now open. 
- Start it with "Run All" button or command
- go with a cmd tool into sim/tests
- run "lua gb_bootrom.lua"

Test is now running. Watch command line or waveform.

# Debug graphic

In the sim folder, there is a "graeval.exe"
When the simulation has run for a while and the file "gra_fb_out.gra" exists and the size is not zero,
you can pull this file onto the graeval.exe
A new window will open and draw everything the core outputs in simulation.

# How to simulate a specific ROM

Change the path to the ROM in the luascript "sim/tests/gb_bootrom.lua"
As the script and the simulator run in different paths, you may have to change the path or copy the file locally.