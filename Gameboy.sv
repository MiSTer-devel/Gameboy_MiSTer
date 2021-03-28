//============================================================================
//  Gameboy
//  Copyright (c) 2015 Till Harbaum <till@harbaum.org>  
//
//  Port to MiSTer
//  Copyright (C) 2017,2018 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign VGA_F1 = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = ioctl_download | sav_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;

assign AUDIO_MIX = status[8:7];

// Status Bit Map:
// 0         1         2         3 
// 01234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v" 
localparam CONF_STR = {
	"GAMEBOY;SS3E000000:100000;",
	"FS1,GBCGB ,Load ROM;",
	"OEF,System,Auto,Gameboy,Gameboy Color;",
	"ONO,Super Game Boy,Off,Palette,On;",
	"d5FC2,SGB,Load SGB border;",
	"-;",
	"C,Cheats;",
	"h0OH,Cheats enabled,Yes,No;",
	"-;",
	"h2R9,Load Backup RAM;",
	"h2RA,Save Backup RAM;",
	"OD,Autosave,Off,On;",
	"-;",
	"h3RS,Save state (Alt-F1);",
	"h3RT,Restore state (F1);",
	"-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1OC,Inverted color,No,Yes;",
	"P1O12,Custom Palette,Off,Auto,On;",
	"h1P1FC3,GBP,Load Palette;",
	"P1-;",
	"P1O34,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OLM,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1OIK,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1O5,Stabilize video(buffer),Off,On;",
	"P1OG,Frame blend,Off,On;",
	"d4P1OU,GBC Colors,Corrected,Raw;",
	"P1-;",
	"P1O78,Stereo mix,none,25%,50%,100%;",

	"P2,Misc.;",
	"P2-;",
	"P2OB,Boot,Normal,Fast;",
	"P2O6,Link Port,Disabled,Enabled;",
	"P2-;",
	"P2OP,FastForward Sound,On,Off;",
	"P2OQ,Pause when OSD is open,Off,On;",
	"P2OR,Rewind Capture,Off,On;",

	"-;",
	"R0,Reset;",
	"J1,A,B,Select,Start,FastForward,SaveState,LoadState,Rewind;",
	"I,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4,",
	"Rewinding...;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_ram;
wire pll_locked;

assign CLK_VIDEO = clk_ram;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_ram),
	.outclk_1(clk_sys),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire [21:0] gamma_bus;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
reg         ioctl_wait;

wire [15:0] joystick_0, joystick_1, joystick_2, joystick_3;
wire [10:0] ps2_key;

wire [7:0]  filetype;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire [32:0] RTC_time;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.conf_str(CONF_STR),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(filetype),
	
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.buttons(buttons),
	.status(status),
	.status_menumask({sgb_border_en,isGBC,cart_ready,sav_supported,|tint,gg_available}),
	.direct_video(direct_video),
	.gamma_bus(gamma_bus),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	
	.ps2_key(ps2_key),
	
	.info_req(ss_info_req),
	.info(ss_info),
	
	.TIMESTAMP(RTC_time)
);

///////////////////////////////////////////////////

wire cart_download = ioctl_download && (filetype == 8'h01 || filetype == 8'h41 || filetype == 8'h80);
wire palette_download = ioctl_download && (filetype == 3 || !filetype);
wire bios_download = ioctl_download && (filetype == 8'h40);
wire sgb_border_download = ioctl_download && (filetype == 2);

wire  [1:0] sdram_ds = cart_download ? 2'b11 : {cart_addr[0], ~cart_addr[0]};
wire [15:0] sdram_do;
wire [15:0] sdram_di = cart_download ? ioctl_dout : 16'd0;
wire [23:0] sdram_addr = cart_download? ioctl_addr[24:1]: {2'b00, mbc_bank, cart_addr[12:1]};
wire sdram_oe = ~cart_download & cart_rd & ~cram_rd;
wire sdram_we = cart_download & dn_write;
wire sdram_refresh_force;
wire sdram_autorefresh = !ff_on;

assign SDRAM_CKE = 1;

sdram sdram (
   // interface to the MT48LC16M16 chip
   .sd_data        ( SDRAM_DQ                  ),
   .sd_addr        ( SDRAM_A                   ),
   .sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML}  ),
   .sd_cs          ( SDRAM_nCS                 ),
   .sd_ba          ( SDRAM_BA                  ),
   .sd_we          ( SDRAM_nWE                 ),
   .sd_ras         ( SDRAM_nRAS                ),
   .sd_cas         ( SDRAM_nCAS                ),
   .sd_clk         ( SDRAM_CLK                 ),

    // system interface
   .clk            ( clk_ram                   ),
   .sync           ( ce_cpu2x                  ),
   .init           ( ~pll_locked               ),

   // cpu interface
   .din            ( sdram_di                  ),
   .addr           ( sdram_addr                ),
   .ds             ( sdram_ds                  ),
   .we             ( sdram_we                  ),
   .oe             ( sdram_oe                  ),
   .autorefresh    ( sdram_autorefresh         ),
   .refresh        ( sdram_refresh_force       ),
   .dout           ( sdram_do                  )
);

reg cart_ready = 0;
reg dn_write;
always @(posedge clk_sys) begin
	if(ioctl_wr) ioctl_wait <= 1;

	if(speed?ce_cpu2x:ce_cpu) begin
		dn_write <= ioctl_wait;
		if(dn_write) {ioctl_wait, dn_write} <= 0;
		if(dn_write) cart_ready <= 1;
	end
end

///////////////////////////////////////////////////


// http://fms.komkon.org/GameBoy/Tech/Carts.html

// 32MB SDRAM memory map using word addresses
// 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 D
// 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 S
// -------------------------------------------------
// 0 0 0 0 X X X X X X X X X X X X X X X X X X X X X up to 2MB used as ROM (MBC1-3), 8MB for MBC5 
// 0 0 0 0 R R B B B B B C C C C C C C C C C C C C C MBC1 ROM (R=RAM bank in mode 0)

// ---------------------------------------------------------------
// ----------------------------- MBC1 ----------------------------
// ---------------------------------------------------------------

wire [9:0] mbc1_addr = {2'b00, mbc1_rom_bank, cart_addr[13]};	// 16k ROM Bank 0-127 or MBC1M Bank 0-63

wire [9:0] mbc2_addr = {2'b00, mbc2_rom_bank, cart_addr[13]};	// 16k ROM Bank 0-15

wire [9:0] mbc3_addr = {2'b00, mbc3_rom_bank, cart_addr[13]};	// 16k ROM Bank 0-127

wire [9:0] mbc5_addr = {       mbc5_rom_bank, cart_addr[13]};	// 16k ROM Bank 0-480 (0h-1E0h)

// https://forums.nesdev.com/viewtopic.php?p=168940#p168940
// https://gekkio.fi/files/gb-docs/gbctr.pdf
// MBC1 $6000 Mode register:
// 0: Bank2 ANDed with CPU A14. Bank2 affects ROM 0x4000-0x7FFF only
// 1: Passthrough. Bank2 affects ROM 0x0000-0x3FFF, 0x4000-0x7FFF, RAM 0xA000-0xBFFF
wire [1:0] mbc1_bank2 = mbc_ram_bank_reg[1:0] & {2{cart_addr[14] | mbc1_mode}};

// -------------------------- RAM banking ------------------------

wire [1:0] mbc1_ram_bank = mbc1_bank2 & ram_mask[1:0];
wire [1:0] mbc3_ram_bank = mbc_ram_bank_reg[1:0] & ram_mask[1:0];
wire [3:0] mbc5_ram_bank = mbc_ram_bank_reg & ram_mask;

// -------------------------- ROM banking ------------------------
   
// 0x0000-0x3FFF = Bank 0
wire [8:0] mbc_rom_bank = (cart_addr[15:14] == 2'b00) ? 9'd0 : mbc_rom_bank_reg;

// MBC1: 4x32 16KByte banks, MBC1M: 4x16 16KByte banks
wire [6:0] mbc1_rom_bank_mode = mbc1m ? { 1'b0, mbc1_bank2, mbc_rom_bank[3:0] }
                                      : {       mbc1_bank2, mbc_rom_bank[4:0] };

// in mode 0 map memory at A000-BFFF
// in mode 1 map rtc register at A000-BFFF
//wire [6:0] mbc3_ram_bank_addr = { mbc3_mode?2'b00:mbc3_ram_bank_reg, mbc3_rom_bank_reg};

// mask address lines to enable proper mirroring
wire [6:0] mbc1_rom_bank = mbc1_rom_bank_mode & rom_mask[6:0];	 //128
wire [6:0] mbc2_rom_bank = mbc_rom_bank[6:0] & rom_mask[6:0];  //16
wire [6:0] mbc3_rom_bank = mbc_rom_bank[6:0] & rom_mask[6:0];  //128
wire [8:0] mbc5_rom_bank = mbc_rom_bank & rom_mask;  //480

wire mbc_battery = (cart_mbc_type == 8'h03) || (cart_mbc_type == 8'h06) || (cart_mbc_type == 8'h09) || (cart_mbc_type == 8'h0D) ||
	(cart_mbc_type == 8'h10) || (cart_mbc_type == 8'h13) || (cart_mbc_type == 8'h1B) || (cart_mbc_type == 8'h1E) ||
	(cart_mbc_type == 8'h22) || (cart_mbc_type == 8'hFF);

// --------------------- CPU register interface ------------------
reg mbc_ram_enable;
reg mbc1_mode;
reg mbc3_mode;
reg [8:0] mbc_rom_bank_reg;
reg [3:0] mbc_ram_bank_reg; //0-15

assign SS_Ext_BACK[ 8: 0] = mbc_rom_bank_reg;
assign SS_Ext_BACK[12: 9] = mbc_ram_bank_reg;
assign SS_Ext_BACK[   13] = mbc1_mode;
assign SS_Ext_BACK[   14] = mbc3_mode;
assign SS_Ext_BACK[   15] = mbc_ram_enable;

always @(posedge clk_sys) begin
	if(savestate_load) begin
		mbc_rom_bank_reg <= SS_Ext[ 8: 0]; //5'd1;
		mbc_ram_bank_reg <= SS_Ext[12: 9]; //4'd0;
		mbc1_mode        <= SS_Ext[   13]; //1'b0;
		mbc3_mode        <= SS_Ext[   14]; //1'b0;
		mbc_ram_enable   <= SS_Ext[   15]; //1'b0;
	end else if(reset) begin
		mbc_rom_bank_reg <= 5'd1;
		mbc_ram_bank_reg <= 4'd0;
		mbc1_mode        <= 1'b0;
		mbc3_mode        <= 1'b0;
		mbc_ram_enable   <= 1'b0;
	end else if(ce_cpu2x) begin
		
		//write to ROM bank register
		if(cart_wr && (cart_addr[15:13] == 3'b001)) begin
			if(~mbc5 && (cart_di[6:0]==0 || (mbc1 && cart_di[4:0]==0) || (mbc2 && cart_di[3:0]==0))) //special case mbc1-3 rombank 0=1
				mbc_rom_bank_reg <= 5'd1;
			else if (mbc5) begin
				if (cart_addr[13:12] == 2'b11) //3000-3FFF High bit
					mbc_rom_bank_reg[8] <= cart_di[0];
				else //2000-2FFF low 8 bits
					mbc_rom_bank_reg[7:0] <= cart_di[7:0];
			end else
				mbc_rom_bank_reg <= {2'b00,cart_di[6:0]}; //mbc1-3
		end	
		
		//write to RAM bank register
		if(cart_wr && (cart_addr[15:13] == 3'b010)) begin
			if (mbc3) begin
				if (cart_di[3]==1) begin
					mbc3_mode <= 1'b1; //enable RTC
					rtc_index <= cart_di[2:0];
				end else begin
					mbc3_mode <= 1'b0; //enable RAM
					mbc_ram_bank_reg <= {2'b00,cart_di[1:0]};
				end
			end else
				if (mbc5)//can probably be simplified
					mbc_ram_bank_reg <= cart_di[3:0];
				else
					mbc_ram_bank_reg <= {2'b00,cart_di[1:0]};
		end

		// MBC1 ROM/RAM Mode Select
		if(mbc1 && cart_wr && (cart_addr[15:13] == 3'b011))
				mbc1_mode <= cart_di[0];
		
		//RAM enable/disable
		if(ce_cpu2x && cart_wr && (cart_addr[15:13] == 3'b000))
			mbc_ram_enable <= (cart_di[3:0] == 4'ha);
	end
end


// extract header fields extracted from cartridge
// during download
reg [7:0] cart_mbc_type;
reg [7:0] cart_rom_size;
reg [7:0] cart_ram_size;
reg [7:0] cart_cgb_flag;
reg [7:0] cart_sgb_flag;
reg [7:0] cart_old_licensee;
reg [15:0] cart_logo_data[0:7];

// RAM size
wire [3:0] ram_mask =               	// 0 - no ram
	   (cart_ram_size == 1)?4'b0000:   	// 1 - 2k, 1 bank
	   (cart_ram_size == 2)?4'b0000:   	// 2 - 8k, 1 bank
	   (cart_ram_size == 3)?4'b0011:		// 3 - 32k, 4 banks
		4'b1111;   						   	// 4 - 128k 16 banks
		
// ROM size
wire [8:0] rom_mask =                    	 // 0 - 2 banks, 32k direct mapped
	   (cart_rom_size == 1)? 9'b000000011:  // 1 - 4 banks = 64k
	   (cart_rom_size == 2)? 9'b000000111:  // 2 - 8 banks = 128k
	   (cart_rom_size == 3)? 9'b000001111:  // 3 - 16 banks = 256k
	   (cart_rom_size == 4)? 9'b000011111:  // 4 - 32 banks = 512k
	   (cart_rom_size == 5)? 9'b000111111:  // 5 - 64 banks = 1M
	   (cart_rom_size == 6)? 9'b001111111:  // 6 - 128 banks = 2M		
		(cart_rom_size == 7)? 9'b011111111:  // 7 - 256 banks = 4M
		(cart_rom_size == 8)? 9'b111111111:  // 8 - 512 banks = 8M
		(cart_rom_size == 82)?9'b001111111:  //$52 - 72 banks = 1.1M
		(cart_rom_size == 83)?9'b001111111:  //$53 - 80 banks = 1.2M
		(cart_rom_size == 84)?9'b001111111:
                            9'b001111111;  //$54 - 96 banks = 1.5M

wire mbc1 = (cart_mbc_type == 1) || (cart_mbc_type == 2) || (cart_mbc_type == 3);
wire mbc2 = (cart_mbc_type == 5) || (cart_mbc_type == 6);
//wire mmm01 = (cart_mbc_type == 11) || (cart_mbc_type == 12) || (cart_mbc_type == 13) || (cart_mbc_type == 14);
wire mbc3 = (cart_mbc_type == 15) || (cart_mbc_type == 16) || (cart_mbc_type == 17) || (cart_mbc_type == 18) || (cart_mbc_type == 19);
//wire mbc4 = (cart_mbc_type == 21) || (cart_mbc_type == 22) || (cart_mbc_type == 23);
wire mbc5 = (cart_mbc_type == 25) || (cart_mbc_type == 26) || (cart_mbc_type == 27) || (cart_mbc_type == 28) || (cart_mbc_type == 29) || (cart_mbc_type == 30);
//wire tama5 = (cart_mbc_type == 253);
//wire tama6 = (cart_mbc_type == ???);
//wire HuC1 = (cart_mbc_type == 254);
//wire HuC3 = (cart_mbc_type == 255);

wire [9:0] mbc_bank =
	mbc1?mbc1_addr:                  // MBC1, 16k bank 0, 16k bank 1-127 + ram
	mbc2?mbc2_addr:                  // MBC2, 16k bank 0, 16k bank 1-15 + ram
	mbc3?mbc3_addr:
	mbc5?mbc5_addr:
//	tama5?tama5_addr:
//	HuC1?HuC1_addr:
//	HuC3?HuC3_addr:              
	{8'd0, cart_addr[14:13]};  // no MBC, 32k linear address
	
wire isGBC_game = (cart_cgb_flag == 8'h80 || cart_cgb_flag == 8'hC0);
wire isSGB_game = (cart_sgb_flag == 8'h03 && cart_old_licensee == 8'h33);

reg [127:0] palette = 128'h828214517356305A5F1A3B4900000000;

// MBC1M detect
reg [7:0] cart_logo_check;
reg [2:0] cart_logo_idx;
wire mbc1m = &cart_logo_check;

always @(posedge clk_sys) begin
	if(~old_downloading & downloading) begin
		cart_logo_idx <= 3'd0;
		cart_logo_check <= 8'd0;
	end

	if(cart_download & ioctl_wr) begin
		case(ioctl_addr)
			'h142: cart_cgb_flag <= ioctl_dout[15:8];
			'h146: {cart_mbc_type, cart_sgb_flag} <= ioctl_dout;
			'h148: { cart_ram_size, cart_rom_size } <= ioctl_dout;
			'h14a: { cart_old_licensee } <= ioctl_dout[15:8];
		endcase

		//Store cart logo data
		if (ioctl_addr >= 'h104 && ioctl_addr <= 'h112) begin
			cart_logo_data[cart_logo_idx] <= ioctl_dout;
			cart_logo_idx <= cart_logo_idx + 1'b1;
		end

		// MBC1 Multicart detect: Compare 8 words of logo data at second 256KByte bank
		if (ioctl_addr >= 'h40104 && ioctl_addr <= 'h40112) begin
			cart_logo_check[cart_logo_idx] <= (ioctl_dout == cart_logo_data[cart_logo_idx]);
			cart_logo_idx <= cart_logo_idx + 1'b1;
		end

	end

	if (palette_download & ioctl_wr) begin
			palette[127:0] <= {palette[111:0], ioctl_dout[7:0], ioctl_dout[15:8]};
	end
end

//TODO: e.g. output and read timer register values from mbc3 when selected 
wire [7:0] cart_di;    // data from cpu to cart
wire [7:0] cart_do =
	~cart_ready ?
		8'h00 :
		cram_rd ? 
			cram_do :
			cart_addr[0] ?
				sdram_do[15:8]:
				sdram_do[7:0];


wire [15:0] cart_addr;
wire cart_rd;
wire cart_wr;

wire lcd_clkena;
wire [14:0] lcd_data;
wire [1:0] lcd_mode;
wire lcd_on;
wire lcd_vsync;

wire DMA_on;

assign AUDIO_S = 0;

wire reset = (RESET | status[0] | buttons[1] | cart_download | bk_loading);
wire speed;

reg isGBC = 0;
always @(posedge clk_sys) if(reset) begin
	if(status[15:14]) isGBC <= status[15];
	else if(cart_download) isGBC <= !filetype[7:4];
end

wire [15:0] GB_AUDIO_L;
wire [15:0] GB_AUDIO_R;

// the gameboy itself
gb gb (
	.reset	    ( reset      ),
	
	.clk_sys     ( clk_sys    ),
	.ce          ( ce_cpu     ),   // the whole gameboy runs on 4mhnz
	.ce_2x       ( ce_cpu2x   ),   // ~8MHz in dualspeed mode (GBC)
	
	.fast_boot   ( status[11]  ),

	.isGBC       ( isGBC      ),
	.isGBC_game  ( isGBC_game ),
	.isSGB       ( |sgb_en & ~isGBC ),

	.joy_p54     ( joy_p54     ),
	.joy_din     ( joy_do_sgb  ),

	// interface to the "external" game cartridge
	.cart_addr   ( cart_addr  ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),
	
	//gbc bios interface
	.gbc_bios_addr   ( bios_addr  ),
	.gbc_bios_do     ( bios_do    ),

	// audio
	.audio_l 	 ( GB_AUDIO_L ),
	.audio_r 	 ( GB_AUDIO_R ),
	
	// interface to the lcd
	.lcd_clkena  ( lcd_clkena ),
	.lcd_data    ( lcd_data   ),
	.lcd_mode    ( lcd_mode   ),
	.lcd_on      ( lcd_on     ),
	.lcd_vsync   ( lcd_vsync  ),
	
	.speed       ( speed      ),
	.DMA_on      ( DMA_on    ),
	
	// serial port
	.sc_int_clock2(sc_int_clock_out),
	.serial_clk_in(ser_clk_in),
	.serial_data_in(ser_data_in),
	.serial_clk_out(ser_clk_out),
	.serial_data_out(ser_data_out),
	
	// Palette download will disable cheats option (HPS doesn't distinguish downloads),
	// so clear the cheats and disable second option (chheats enable/disable)
	.gg_reset((code_download && ioctl_wr && !ioctl_addr) | cart_download | palette_download),
	.gg_en(~status[17]),
	.gg_code(gg_code),
	.gg_available(gg_available),
	
	// savestates
	.cart_ram_size   (cart_ram_size),
	.save_state      (ss_save),
	.load_state      (ss_load),
	.savestate_number(ss_base),
	.sleep_savestate (sleep_savestate),
	.state_loaded    (ss_loaded),
	
	.SaveStateExt_Din (SaveStateBus_Din),
	.SaveStateExt_Adr (SaveStateBus_Adr), 
	.SaveStateExt_wren(SaveStateBus_wren),
	.SaveStateExt_rst (SaveStateBus_rst),
	.SaveStateExt_Dout(SaveStateBus_Dout),
	.SaveStateExt_load(savestate_load),
	
	.Savestate_CRAMAddr     (Savestate_CRAMAddr),     
	.Savestate_CRAMRWrEn    (Savestate_CRAMRWrEn),   
	.Savestate_CRAMWriteData(Savestate_CRAMWriteData),
	.Savestate_CRAMReadData (Savestate_CRAMReadData),
	
	.SAVE_out_Din(ss_din),            // data read from savestate
	.SAVE_out_Dout(ss_dout),          // data written to savestate
	.SAVE_out_Adr(ss_addr),           // all addresses are DWORD addresses!
	.SAVE_out_rnw(ss_rnw),            // read = 1, write = 0
	.SAVE_out_ena(ss_req),            // one cycle high for each action
	.SAVE_out_done(ss_ack),            // should be one cycle high when write is done or read value is valid
	
	.rewind_on(status[27]),
	.rewind_active(status[27] & joystick_0[11])
);

assign AUDIO_L = (fast_forward && status[25]) ? 16'd0 : GB_AUDIO_L;
assign AUDIO_R = (fast_forward && status[25]) ? 16'd0 : GB_AUDIO_R;

// the lcd to vga converter
wire [7:0] R,G,B;
wire video_hs, video_vs;
wire HBlank, VBlank;
wire ce_pix;
wire [8:0] h_cnt, v_cnt;
wire [1:0] tint = status[2:1];

lcd lcd
(
	// serial interface
	.clk_sys( clk_sys    ),
	.ce     ( ce_cpu         ),

	.lcd_clkena ( sgb_lcd_clkena ),
	.data   ( sgb_lcd_data   ),
	.mode   ( sgb_lcd_mode   ),  // used to detect begin of new lines and frames
	.on     ( sgb_lcd_on     ),
	.lcd_vs ( sgb_lcd_vsync  ),

	.isGBC  ( isGBC      ),

	.tint   ( |tint       ),
	.inv    ( status[12]  ),
	.double_buffer( status[5]),
	.frame_blend( status[16] ),
	.originalcolors( status[30] ),

	// Palettes
	.pal1   (palette[127:104]),
	.pal2   (palette[103:80]),
	.pal3   (palette[79:56]),
	.pal4   (palette[55:32]),

	.sgb_border_pix ( sgb_border_pix),
	.sgb_pal_en     ( sgb_pal_en ),
	.sgb_en         ( sgb_border_en ),

	.clk_vid( CLK_VIDEO  ),
	.hs     ( video_hs   ),
	.vs     ( video_vs   ),
	.hbl    ( HBlank     ),
	.vbl    ( VBlank     ),
	.r      ( R          ),
	.g      ( G          ),
	.b      ( B          ),
	.ce_pix ( ce_pix     ),
	.h_cnt  ( h_cnt      ),
	.v_cnt  ( v_cnt      )
);

wire [1:0] joy_p54;
wire [3:0] joy_do_sgb;
wire [14:0] sgb_lcd_data;
wire [15:0] sgb_border_pix;
wire sgb_lcd_clkena, sgb_lcd_on, sgb_lcd_vsync;
wire [1:0] sgb_lcd_mode;
wire sgb_pal_en;
wire [1:0] sgb_en = status[24:23];
wire sgb_border_en = sgb_en[1];

sgb sgb (
	.reset       ( reset       ),
	.clk_sys     ( clk_sys     ),
	.ce          ( ce_cpu      ),

	.clk_vid     ( CLK_VIDEO   ),
	.ce_pix      ( ce_pix      ),

	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
	.joystick_2  ( joystick_2  ),
	.joystick_3  ( joystick_3  ),
	.joy_p54     ( joy_p54     ),
	.joy_do      ( joy_do_sgb  ),

	.sgb_en      ( |sgb_en & isSGB_game & ~isGBC ),
	.tint        ( tint[1]     ),

	.lcd_on      ( lcd_on      ),
	.lcd_clkena  ( lcd_clkena  ),
	.lcd_data    ( lcd_data    ),
	.lcd_mode    ( lcd_mode    ),
	.lcd_vsync   ( lcd_vsync   ),

	.h_cnt       ( h_cnt      ),
	.v_cnt       ( v_cnt      ),

	.border_download (sgb_border_download),
	.ioctl_wr        (ioctl_wr),
	.ioctl_addr      (ioctl_addr),
	.ioctl_dout      (ioctl_dout),

	.sgb_border_pix  ( sgb_border_pix  ),
	.sgb_pal_en      ( sgb_pal_en      ),
	.sgb_lcd_data    ( sgb_lcd_data    ),
	.sgb_lcd_on      ( sgb_lcd_on      ),
	.sgb_lcd_clkena  ( sgb_lcd_clkena  ),
	.sgb_lcd_mode    ( sgb_lcd_mode    ),
	.sgb_lcd_vsync   ( sgb_lcd_vsync   )
);

reg HSync, VSync;
always @(posedge CLK_VIDEO) begin
	if(ce_pix) begin
		HSync <= video_hs;
		if(~HSync & video_hs) VSync <= video_vs;
	end
end

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[20:18];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(200), .GAMMA(1)) video_mixer
(
	.*,
	.hq2x(scale==1)
);

wire [1:0] ar = status[4:3];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? (sgb_border_en ? 12'd16 : 12'd10) : (ar - 1'd1)),
	.ARY((!ar) ? (sgb_border_en ? 12'd14 : 12'd9 ) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[22:21])
);

//////////////////////////////// CE ////////////////////////////////////


wire ce_cpu, ce_cpu2x;
wire cart_act = cart_wr | cart_rd;

wire fastforward = joystick_0[8] && !ioctl_download && !OSD_STATUS;
wire ff_on;

wire sleep_savestate;

reg paused;
always_ff @(posedge clk_sys) begin
   paused <= sleep_savestate | (status[26] && OSD_STATUS && !ioctl_download && !reset && ~status[27]); // no pause when downloading rom, resetting or rewind capture is on
end

speedcontrol speedcontrol
(
	.clk_sys     (clk_sys),
	.pause       (paused),
	.speedup     (fast_forward),
	.cart_act    (cart_act),
	.DMA_on      (DMA_on),
	.ce          (ce_cpu),
	.ce_2x       (ce_cpu2x),
	.refresh     (sdram_refresh_force),
	.ff_on       (ff_on)
);

///////////////////////////// Fast Forward Latch /////////////////////////////////

reg fast_forward;
reg ff_latch;

always @(posedge clk_sys) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= fastforward;

	if (fastforward)
		ff_count <= ff_count + 1;

	if (~last_ffw & fastforward) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~fastforward)) begin // 32mhz clock, 0.2 seconds
		ff_was_held <= 0;

		if (ff_count < 3200000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (fastforward | ff_latch);
end

///////////////////////////// savestates /////////////////////////////////

wire [63:0] SaveStateBus_Din; 
wire [9:0]  SaveStateBus_Adr; 
wire        SaveStateBus_wren;
wire        SaveStateBus_rst; 
wire [63:0] SaveStateBus_Dout;
wire        savestate_load;

wire [19:0] Savestate_CRAMAddr;     
wire        Savestate_CRAMRWrEn;    
wire [7:0]  Savestate_CRAMWriteData;
wire [7:0]  Savestate_CRAMReadData;
	
wire [15:0] SS_Ext;
wire [15:0] SS_Ext_BACK;

eReg_SavestateV #(0, 32, 15, 0, 64'h0000000000000001) iREG_SAVESTATE_Ext (clk_sys, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_Ext_BACK, SS_Ext);  

wire [63:0] ss_dout, ss_din;
wire [27:2] ss_addr;
wire        ss_rnw, ss_req, ss_ack;

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,

	.ch1_addr({ss_addr, 1'b0}),
	.ch1_din(ss_din),
	.ch1_dout(ss_dout),
	.ch1_req(ss_req),
	.ch1_rnw(ss_rnw),
	.ch1_ready(ss_ack)
);

// saving with keyboard/OSD/gamepad
wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];

reg [1:0] ss_base = 0;
reg [7:0] ss_info;
reg ss_save, ss_load, ss_info_req;
wire ss_loaded;
always @(posedge clk_sys) begin
	reg old_state;
	reg alt = 0;
	reg [1:0] old_st;
	reg [1:0] old_st_joy;

	old_state <= ps2_key[10];

	if(cart_ready) begin
		if(old_state != ps2_key[10]) begin
			case(code)
				'h11: alt <= pressed;
				'h05: begin ss_save <= pressed & alt; ss_load <= pressed & ~alt; ss_base <= 0; end // F1
				'h06: begin ss_save <= pressed & alt; ss_load <= pressed & ~alt; ss_base <= 1; end // F2
				'h04: begin ss_save <= pressed & alt; ss_load <= pressed & ~alt; ss_base <= 2; end // F3
				'h0C: begin ss_save <= pressed & alt; ss_load <= pressed & ~alt; ss_base <= 3; end // F4
			endcase
		end

      old_st_joy <= joystick_0[10:9];
		if(old_st_joy[0] ^ joystick_0[9])  ss_save <= joystick_0[9];
		if(old_st_joy[1] ^ joystick_0[10]) ss_load <= joystick_0[10];
      if(joystick_0[10:9]) ss_base <= 0;

		old_st <= status[29:28];
		if(old_st[0] ^ status[28]) ss_save <= status[28];
		if(old_st[1] ^ status[29]) ss_load <= status[29];
		if(status[29:28])    ss_base <= 0;

		if(ss_load | ss_save) ss_info <= 7'd1 + {ss_base, ss_load};
		ss_info_req <= (ss_loaded | ss_save);

		// rewind info
		if (status[27] & joystick_0[11]) begin
			ss_info_req <= 1'b1;
			ss_info     <= 7'd9;
		end

	end
end

///////////////////////////// GBC BIOS /////////////////////////////////

wire [7:0] bios_do;
wire [11:0] bios_addr;

dpram_dif #(12,8,11,16,"BootROMs/cgb_boot.mif") boot_rom_gbc (
	.clock (clk_sys),
	
	.address_a (bios_addr),
	.q_a (bios_do),
	
	.address_b (ioctl_addr[11:1]),
	.wren_b (ioctl_wr && bios_download),
	.data_b (ioctl_dout)
);

///////////////////////////// CHEATS //////////////////////////////////
// Code loading for WIDE IO (16 bit)
reg [128:0] gg_code;
wire        gg_available;
wire        code_download = &filetype;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk_sys) begin
	gg_code[128] <= 1'b0;

	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_code[128]      <= 1'b1;       // Clock it in
			end
		endcase
	end
end

/////////////////////////////  Serial link  ///////////////////////////////

assign USER_OUT[2] = 1'b1;
assign USER_OUT[3] = 1'b1;
assign USER_OUT[4] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

wire sc_int_clock_out;
wire ser_data_in;
wire ser_data_out;
wire ser_clk_in;
wire ser_clk_out;
wire serial_ena = status[6];

assign ser_data_in = serial_ena ? USER_IN[2] : 1'b1;
assign USER_OUT[1] = serial_ena ? ser_data_out : 1'b1;

assign ser_clk_in = serial_ena ? USER_IN[0] : 1'b1;
assign USER_OUT[0] = (serial_ena & sc_int_clock_out) ? ser_clk_out : 1'b1;



/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////

wire [16:0] bk_addr = {sd_lba[7:0],sd_buff_addr};
wire bk_wr = (sd_lba[7:0] > ram_mask_file) ? 1'b0 : sd_buff_wr & sd_ack; // only restore data amount of saveram, don't save on RTC data
wire [15:0] bk_data = sd_buff_dout;
wire [15:0] bk_q;
assign sd_buff_din = (sd_lba[7:0] <= ram_mask_file) ? bk_q :  // normal saveram data or RTC data
					 (sd_buff_addr == 8'd0) ? RTC_timestampOut[15:0]  :
					 (sd_buff_addr == 8'd1) ? RTC_timestampOut[31:16] :
					 (sd_buff_addr == 8'd2) ? RTC_savedtimeOut[15:0]  :
					 (sd_buff_addr == 8'd3) ? RTC_savedtimeOut[31:16] :
					 16'hFFFF;

wire [7:0] cram_do =
	mbc_ram_enable ? 
		((cart_addr[15:9] == 7'b1010000) && mbc2) ? 
			{4'hF,cram_q[3:0]} : // 4 bit MBC2 Ram needs top half masked.
			mbc3_mode ?
				rtc_return:      // RTC mode 
				cram_q :         // Return normal value
		8'hFF;                   // Ram not enabled


reg read_low = 0;
always @(posedge clk_sys) begin
   read_low <= cram_addr[0];
end

assign Savestate_CRAMReadData = read_low ? cram_q_h : cram_q_l;

wire [7:0] cram_q = cram_addr[0] ? cram_q_h : cram_q_l;
wire [7:0] cram_q_h;
wire [7:0] cram_q_l;

wire is_cram_addr = (cart_addr[15:13] == 3'b101);
wire cram_rd = cart_rd & is_cram_addr;
wire cram_wr = sleep_savestate ? Savestate_CRAMRWrEn : cart_wr & is_cram_addr & mbc_ram_enable;
wire [16:0] cram_addr = sleep_savestate ? Savestate_CRAMAddr[16:0]:
                        mbc1? {2'b00,mbc1_ram_bank, cart_addr[12:0]}:
								mbc3? {2'b00,mbc3_ram_bank, cart_addr[12:0]}:
								mbc5?	{mbc5_ram_bank, cart_addr[12:0]}:
								{4'd0, cart_addr[12:0]};

wire [7:0] cram_di = sleep_savestate ? Savestate_CRAMWriteData : cart_di;

// Up to 8kb * 16banks of Cart Ram (128kb)

dpram #(16) cram_l (
	.clock_a (clk_sys),
	.address_a (cram_addr[16:1]),
	.wren_a (cram_wr & ~cram_addr[0]),
	.data_a (cram_di),
	.q_a (cram_q_l),
	
	.clock_b (clk_sys),
	.address_b (bk_addr[15:0]),
	.wren_b (bk_wr),
	.data_b (bk_data[7:0]),
	.q_b (bk_q[7:0])
);

dpram #(16) cram_h (
	.clock_a (clk_sys),
	.address_a (cram_addr[16:1]),
	.wren_a (cram_wr & cram_addr[0]),
	.data_a (cram_di),
	.q_a (cram_q_h),
	
	.clock_b (clk_sys),
	.address_b (bk_addr[15:0]),
	.wren_b (bk_wr),
	.data_b (bk_data[15:8]),
	.q_b (bk_q[15:8])
);

wire downloading = cart_download;

reg  bk_ena          = 0;
reg  new_load        = 0;
reg  old_downloading = 0;
reg  sav_pending     = 0;
wire sav_supported   = (mbc_battery && (cart_ram_size > 0 || mbc2) && bk_ena);

always @(posedge clk_sys) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;

	if (old_downloading & ~downloading & sav_supported)
		new_load <= 1'b1;
	else if (bk_state)
		new_load <= 1'b0;

	if (cram_wr & ~OSD_STATUS & sav_supported)
		sav_pending <= 1'b1;
	else if (bk_state)
		sav_pending <= 1'b0;
end

wire bk_load    = status[9] | new_load;
wire bk_save    = status[10] | (sav_pending & OSD_STATUS & status[13]);
reg  bk_loading = 0;
reg  bk_state   = 0;

// RAM size
wire [7:0] ram_mask_file =  											// 0 - no ram
		(mbc2)?8'h01:														// mbc2 512x4bits
	   (cart_ram_size == 1)?8'h03:   								// 1 - 2k, 1 bank		 sd_lba[1:0]
	   (cart_ram_size == 2)?8'h0F:   								// 2 - 8k, 1 bank		 sd_lba[3:0]
	   (cart_ram_size == 3)?8'h3F:									// 3 - 32k, 4 banks	 sd_lba[5:0]
		8'hFF;   						   								// 4 - 128k 16 banks  sd_lba[7:0] 1111

always @(posedge clk_sys) begin
	reg old_load = 0, old_save = 0, old_ack;

	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= sd_ack;
	
	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;
	
	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba <= 32'd0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_lba <= 0;
			sd_rd <= 1;
			sd_wr <= 0;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			
			if (RTC_inuse && sd_lba[7:0]>ram_mask_file) begin // save/load one block more when game/savefile uses RTC, only first 8 bytes used
				bk_loading <= 0;
				bk_state <= 0;
			end else if(!RTC_inuse && sd_lba[7:0]>=ram_mask_file) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end

/////////////////////////////  RTC  ///////////////////////////////
reg [2:0]  rtc_index;

reg [25:0] rtc_subseconds;
reg [5:0]  rtc_seconds;
reg [5:0]  rtc_minutes;
reg [4:0]  rtc_hours;
reg [9:0]  rtc_days;
reg        rtc_overflow;
reg        rtc_halt;

wire [7:0] rtc_return;

wire        RTC_timestampNew = RTC_time[32];
wire [31:0] RTC_timestampIn  = RTC_time[31:0];	

reg [31:0] RTC_timestampSaved = 0;
reg [31:0] RTC_savedtimeIn = 0;	
reg        RTC_saveLoaded = 0;

reg [31:0] RTC_timestampOut;
reg [31:0] RTC_savedtimeOut;
reg        RTC_inuse;

reg rtc_change;
reg RTC_saveLoaded_1;
reg RTC_timestampNew_1; 
reg [31:0] diffSeconds;

reg reset_1;

always_ff @(posedge clk_sys) begin

	reset_1 <= reset;

	if(!reset_1 && reset) begin
		rtc_halt  <= 1'b0;
		RTC_inuse <= 1'b0;
	end else begin
	
		if (rtc_change == 1'b0) begin // when RTC hasn't changed recently, update the register which will be written after savegame
			RTC_savedtimeOut <= {3'd0, rtc_halt, rtc_overflow, rtc_days, rtc_hours, rtc_minutes, rtc_seconds};
		end
	
		rtc_change	  <= 1'b0;
		rtc_subseconds <= rtc_subseconds + 1'd1;

		if (mbc3_mode || (bk_wr && mbc3 && img_size[9])) begin  // RTC is either used by game or already used in savegame
			RTC_inuse <= 1'b1;
		end

		RTC_saveLoaded <= 1'b0;
		if (sd_buff_wr && sd_ack && sd_lba[7:0] > ram_mask_file) begin // load data from savefile to intermediate register
			case (sd_buff_addr)
				0: RTC_timestampSaved[15:0]  <= sd_buff_dout;
				1: RTC_timestampSaved[31:16] <= sd_buff_dout;
				2: RTC_savedtimeIn[15:0]     <= sd_buff_dout;
				3: RTC_savedtimeIn[31:16]    <= sd_buff_dout;
				4: RTC_saveLoaded            <= 1'b1;
			endcase
		end
	
		if (RTC_saveLoaded == 1'b1) begin  // load data from intermediate register to RTC registers
			
			if (RTC_timestampOut > RTC_timestampSaved) begin
				diffSeconds <= RTC_timestampOut - RTC_timestampSaved;
			end
			
			rtc_seconds	 <= RTC_savedtimeIn[5:0];
			rtc_minutes	 <= RTC_savedtimeIn[11:6];
			rtc_hours	 <= RTC_savedtimeIn[16:12];
			rtc_days		 <= RTC_savedtimeIn[26:17];
			rtc_overflow <= RTC_savedtimeIn[27];
			rtc_halt		 <= RTC_savedtimeIn[28];

			RTC_inuse    <= 1'b1;

		end else if(cart_wr && (cart_addr[15:13] == 3'b101) && mbc3_mode == 1'b1) begin // setting RTC registers from game
		
			case (rtc_index)
				0: rtc_seconds	  <= cart_di[5:0]; 
				1: rtc_minutes	  <= cart_di[5:0]; 
				2: rtc_hours	  <= cart_di[4:0]; 
				3: rtc_days[7:0] <= cart_di; 
				4: begin
					rtc_days[8]   <= cart_di[0]; 
					rtc_halt      <= cart_di[6]; 
					rtc_overflow  <= cart_di[7];
				end
			endcase
			
		end else begin  // normal counting
			
			if (rtc_halt == 1'b0) begin
				if (rtc_seconds >= 60)	 begin rtc_seconds <= 6'd0;  rtc_minutes  <= rtc_minutes + 1'd1; rtc_change <= 1'b1; end
				if (rtc_minutes >= 60)	 begin rtc_minutes <= 6'd0;  rtc_hours    <= rtc_hours + 1'd1;	  rtc_change <= 1'b1; end
				if (rtc_hours   >= 24)	 begin rtc_hours   <= 5'd0;  rtc_days     <= rtc_days + 1'd1;    rtc_change <= 1'b1; end
				if (rtc_days    >= 512)	 begin rtc_days    <= 10'd0; rtc_overflow <= 1'b1;               rtc_change <= 1'b1; end
			end
			
			if (rtc_subseconds >= 33554432) begin 
				rtc_subseconds	  <= 26'd0; 
				RTC_timestampOut	<= RTC_timestampOut + 1'd1;
				if (rtc_halt == 1'b0) begin
					rtc_seconds	  <= rtc_seconds + 1'd1;
					rtc_change	<= 1'b1; 
				end
			end else if (diffSeconds > 0 && rtc_change == 1'b0) begin // fast counting loaded seconds
				diffSeconds		  <= diffSeconds - 1'd1; 
				if (rtc_halt == 1'b0) begin
					rtc_seconds	  <= rtc_seconds + 1'd1;
					rtc_change		<= 1'b1; 
				end
			end
	
		end
		
		RTC_timestampNew_1 <= RTC_timestampNew;  // saving timestamp from HPS
		if (RTC_timestampNew != RTC_timestampNew_1) begin
			RTC_timestampOut <= RTC_timestampIn;
		end
		
	end
end

assign rtc_return = 
	(rtc_index == 0) ? rtc_seconds   :
	(rtc_index == 1) ? rtc_minutes   :
	(rtc_index == 2) ? rtc_hours     :
	(rtc_index == 3) ? rtc_days[7:0] :
	(rtc_index == 4) ? {rtc_overflow, rtc_halt, 5'b00000, rtc_days[8]} :
	8'hFF;

endmodule
