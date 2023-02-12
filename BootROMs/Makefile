PLATFORM := $(shell uname -s)
ifneq ($(findstring MINGW,$(PLATFORM)),)
PLATFORM := windows32
USE_WINDRES := true
endif

ifneq ($(findstring MSYS,$(PLATFORM)),)
PLATFORM := windows32
endif

SRC := ./src
OBJ := ./obj
BIN := ./bin

ifeq ($(PLATFORM),windows32)
_ := $(shell chcp 65001)
EXESUFFIX:=.exe
NATIVE_CC = clang -IWindows -Wno-deprecated-declarations --target=i386-pc-windows
# To force use of the Unix version instead of the Windows version
MKDIR := $(shell which mkdir)
NULL := NUL
else
EXESUFFIX:=
NATIVE_CC := cc
MKDIR := mkdir
NULL := /dev/null
endif

IMG_COMPRESS := $(OBJ)/logo-compress$(EXESUFFIX)

# MiSTer CGB, DMG and SGB bootroms are compiled into a memory initialization file to be stored in the GameBoy core at built time.
.PHONY : default
default: cgb_boot.mif

.PHONY : all
all: default bootroms checksum

# All bins, including non-standard bootroms (e.g. CGB0, MGB)
.PHONY : bootroms
bootroms: $(BIN)/cgb0_boot.bin $(BIN)/cgb_boot.bin $(BIN)/dmg_boot.bin $(BIN)/mgb_boot.bin $(BIN)/sgb_boot.bin $(BIN)/sgb2_boot.bin


# MiSTer bootrom has a specific memory mapping for each variant (CGB is allocated 2308 bytes, DMG and SGB have 256)
%.mif: $(BIN)/cgb_boot.bin $(BIN)/dmg_boot.bin $(BIN)/sgb_boot.bin
	srec_cat \
    $(BIN)/cgb_boot.bin -Binary -offset 0x000 -fill 0x00 0x000 0x900 \
    $(BIN)/dmg_boot.bin -Binary -offset 0x900 -fill 0x00 0x900 0xA00 \
    $(BIN)/sgb_boot.bin -Binary -offset 0xA00 -fill 0x00 0xA00 0xB00 \
    -fill 0x00 0xB00 0x1000 \
    -Output_Block_Size 16 -o $@ --mif
	@# Insert helpful comments
	@sed -i "/0000/i --CGB" $@
	@sed -i "/0900/i --DMG" $@
	@sed -i "/0A00/i --SGB" $@
	@sed -i "/0B00/i --Padding" $@

# Binary compiler
$(BIN)/%.bin: $(SRC)/%.asm $(OBJ)/CGB_logo.rle
	-@$(MKDIR) -p $(dir $@)
	rgbasm -l -i $(OBJ) -i $(SRC) -o $@.tmp $<
	rgblink -o $@.tmp2 $@.tmp
	dd if=$@.tmp2 of=$@ count=1 bs=$(if $(findstring mgb,$@)$(findstring dmg,$@)$(findstring sgb,$@),256,2304) 2> $(NULL)
	@rm $@.tmp $@.tmp2

# CGB logo compression
$(OBJ)/%.rle: $(OBJ)/%.1bpp $(IMG_COMPRESS)
	-@$(MKDIR) -p $(dir $@)
	$(realpath $(IMG_COMPRESS)) < $< > $@

# Make CGB logo
$(OBJ)/%.1bpp: %.png
	-@$(MKDIR) -p $(dir $@)
	rgbgfx -d 1 -L 0,0:16,3 -Z -o $@ $<

$(OBJ)/%$(EXESUFFIX): $(SRC)/%.c
	-@$(MKDIR) -p $(dir $@)
	$(NATIVE_CC) -std=c99 -Wall -Werror $< -o $@

.PHONY : checksum
checksum: $(OBJ)/checksum$(EXESUFFIX)

.PHONY : clean
clean:
	rm -rf $(OBJ)
	rm -rf $(BIN)	
	rm -f *.mif
