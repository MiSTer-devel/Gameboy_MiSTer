# Attribution
The bootrom source code here has been adapted from the [SameBoy project](https://github.com/LIJI32/SameBoy/)
The MIT license is included in these files.

# Compilation
Bootrom compilation follows the same approach as [SameBoy](https://github.com/LIJI32/SameBoy/#compilation).

The following tools and libraries are required to build bootroms:
 * clang or GCC
 * make
 * [rgbds](https://github.com/gbdev/rgbds/releases/)
 * [SRecord](https://srecord.sourceforge.net/)

The Makefile contains to following targets:
 * `default` compiles `dmg_boot.bin`, `cgb_boot.bin` and `sgb_boot.bin` and concatenates them into `cgb_boot.mif`
 * `bootroms` compiles all `default` binaries as well as `mgb_boot.bin`, `cgb0_boot.bin` and `sgb2_boot.bin`
 * `checksum` compiles a program to calculate simple checksums of binary files
 * `all` all of the above
 * `clean` delete all bootroms and object files, as well as `cgb_boot.mif`

# Checksum
A tool is provided to calculate the checksum of a binary file. This is used in the core to verify if the enhanced boot features are available.
 
# Enhancements
## Fast boot
Fast boot skips the boot animation for the following bootroms:
 * `cgb_boot.bin`
 * `cgb0_boot.bin`
 * `dmg_boot.bin`

## AGB emulation
The Game Boy Advance had a slightly different CGB bootrom, which enabled special features in a small number of games. AGB emulation is avilable for:
 * `cgb_boot.bin`
 * `cgb0_boot.bin`
 * The original CGB bootrom (not provided)
