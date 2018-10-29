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
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

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
	output        SDRAM_nWE
);

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0; 
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[3] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[3] ? 8'd9  : 8'd3; 

assign AUDIO_MIX = status[8:7];

`include "build_id.v" 
localparam CONF_STR = {
	"GAMEBOY;;",
	"-;",
	"F,GB;",
	"-;",
   "O1,LCD tint,White,Yellow;",
   "O4,Inverted,No,Yes;",
	"O3,Aspect ratio,4:3,16:9;",
	"O78,Stereo mix,none,25%,50%,100%;",
	"-;",
   "O2,Boot,Normal,Fast;",
	"-;",
	"R6,Reset;",
	"J1,A,B,Select,Start;",
	"V,v1.01.",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire pll_locked;
		
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(SDRAM_CLK),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
reg         ioctl_wait;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joystick = joystick_0 | joystick_1;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),

	.buttons(buttons),
	.status(status),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

///////////////////////////////////////////////////

// TODO: ds for cart ram write
wire  [1:0] sdram_ds = ioctl_download ? 2'b11 : {cart_addr[0], ~cart_addr[0]};
wire [15:0] sdram_do;
wire [15:0] sdram_di = ioctl_download ? ioctl_dout : {cart_di, cart_di};
wire [23:0] sdram_addr = ioctl_download? ioctl_addr[24:1]: {3'b000, mbc_bank, cart_addr[12:1]};
wire sdram_oe = ~ioctl_download & cart_rd;
wire sdram_we = ioctl_download ? dn_write : cart_ram_wr;

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

    // system interface
   .clk            ( clk_sys                   ),
   .sync           ( ce_cpu                    ),
   .init           ( ~pll_locked               ),

   // cpu interface
   .din            ( sdram_di                  ),
   .addr           ( sdram_addr                ),
   .ds             ( sdram_ds                  ),
   .we             ( sdram_we                  ),
   .oe             ( sdram_oe                  ),
   .dout           ( sdram_do                  )
);

reg cart_ready = 0;
reg dn_write;
always @(posedge clk_sys) begin
	if(ioctl_wr) ioctl_wait <= 1;

	if(ce_cpu) begin
		dn_write <= ioctl_wait;
		if(dn_write) {ioctl_wait, dn_write} <= 0;
		if(dn_write) cart_ready <= 1;
	end
end

///////////////////////////////////////////////////


// TODO: RAM bank
// http://fms.komkon.org/GameBoy/Tech/Carts.html

// 32MB SDRAM memory map using word addresses
// 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 D
// 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 S
// -------------------------------------------------
// 0 0 0 0 X X X X X X X X X X X X X X X X X X X X X up to 2MB used as ROM
// 0 0 0 1 X X X X X X X X X X X X X X X X X X X X X up to 2MB used as RAM
// 0 0 0 0 R R B B B B B C C C C C C C C C C C C C C MBC1 ROM (R=RAM bank in mode 0)
// 0 0 0 1 0 0 0 0 0 0 R R C C C C C C C C C C C C C MBC1 RAM (R=RAM bank in mode 1)

// ---------------------------------------------------------------
// ----------------------------- MBC1 ----------------------------
// ---------------------------------------------------------------

wire [8:0] mbc1_addr = 
	(cart_addr[15:14] == 2'b00)?{8'b000000000, cart_addr[13]}:        // 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{1'b0, mbc1_rom_bank, cart_addr[13]}: // 16k ROM Bank 1-127
	(cart_addr[15:13] == 3'b101)?{7'b1000000, mbc1_ram_bank}:         // 8k RAM Bank 0-3
	9'd0;
	
wire [8:0] mbc2_addr = 
	(cart_addr[15:14] == 2'b00)?{8'b000000000, cart_addr[13]}:        // 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{1'b0, mbc2_rom_bank, cart_addr[13]}: // 16k ROM Bank 1-15
   //todo         																	// 512x4bits RAM, built-in into the MBC2 chip (Read/Write)
	9'd0;
	
wire [8:0] mbc3_addr = 
	(cart_addr[15:14] == 2'b00)?{8'b000000000, cart_addr[13]}:        // 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{mbc3_rom_bank, cart_addr[13]}: // 16k ROM Bank 1-127
	(cart_addr[15:13] == 3'b101)?((mbc3_mode==1'b0)?{7'b1000000, mbc3_ram_bank}:9'd0):         // 8k RAM Bank 0-3
	9'd0;

wire [8:0] mbc5_addr = 
	(cart_addr[15:14] == 2'b00)?{8'b000000000, cart_addr[13]}:        // 16k ROM Bank 0
	(cart_addr[15:14] == 2'b01)?{mbc5_rom_bank, cart_addr[13]}: // 16k ROM Bank 0-127 for now , TODO: 0-480 after remapping sdram memory
	(cart_addr[15:13] == 3'b101)?{7'b1000000, mbc5_ram_bank}:         // 8k RAM Bank 0-3
	9'd0;
	
// -------------------------- RAM banking ------------------------

// in mode 0 (16/8 mode) the ram is not banked 
// in mode 1 (4/32 mode) four ram banks are used
wire [1:0] mbc1_ram_bank = (mbc1_mode?mbc1_ram_bank_reg:2'b00) & ram_mask;
wire [1:0] mbc2_ram_bank = (mbc2_mode ? mbc2_ram_bank_reg:2'b00) & ram_mask;//todo
wire [1:0] mbc3_ram_bank = mbc3_ram_bank_reg & ram_mask;
wire [1:0] mbc5_ram_bank = mbc5_ram_bank_reg & ram_mask;

// -------------------------- ROM banking ------------------------
   
// in mode 0 (16/8 mode) the ram bank select signals are the upper rom address lines 
// in mode 1 (4/32 mode) the upper two rom address lines are 2'b00
wire [6:0] mbc1_rom_bank_mode = { mbc1_mode?2'b00:mbc1_ram_bank_reg, mbc1_rom_bank_reg};
wire [6:0] mbc2_rom_bank_mode = { mbc2_mode?2'b00:mbc2_ram_bank_reg, mbc2_rom_bank_reg};//todo

// in mode 0 map memory at A000-BFFF
// in mode 1 map rtc register at A000-BFFF
//wire [6:0] mbc3_ram_bank_addr = { mbc3_mode?2'b00:mbc3_ram_bank_reg, mbc3_rom_bank_reg};

// mask address lines to enable proper mirroring
wire [6:0] mbc1_rom_bank = mbc1_rom_bank_mode & rom_mask;//128
wire [6:0] mbc2_rom_bank = mbc2_rom_bank_mode & rom_mask;//16
wire [6:0] mbc3_rom_bank = mbc3_rom_bank_reg & rom_mask;//128
wire [6:0] mbc5_rom_bank = mbc5_rom_bank_reg & rom_mask;//128 for now 


// --------------------- CPU register interface ------------------
reg mbc_ram_enable;


reg mbc1_mode;
reg [4:0] mbc1_rom_bank_reg;
reg [1:0] mbc1_ram_bank_reg;

reg mbc2_mode;
reg [4:0] mbc2_rom_bank_reg;//todo
reg [1:0] mbc2_ram_bank_reg;//todo

reg mbc3_mode;
reg [6:0] mbc3_rom_bank_reg;
reg [1:0] mbc3_ram_bank_reg;

reg [6:0] mbc5_rom_bank_reg; // for now reg [8:0] when remapping sdram for 8mb rom
reg [1:0] mbc5_ram_bank_reg; // for now reg [2:0] when remapping sdram for 8mb rom

always @(posedge clk_sys) begin
   if(reset) begin
      mbc_ram_enable <= 1'b0;
	end else if(ce_cpu && cart_wr && (cart_addr[15:13] == 3'b000))
			mbc_ram_enable <= (cart_di[3:0] == 4'ha);
end	
		


always @(posedge clk_sys) begin
	if(reset) begin
		mbc1_rom_bank_reg <= 5'd1;
		mbc1_ram_bank_reg <= 2'd0;
      mbc1_mode <= 1'b0;
	end else if(ce_cpu) begin
		if(cart_wr && (cart_addr[15:13] == 3'b001)) begin
			if(cart_di[4:0]==0) mbc1_rom_bank_reg <= 5'd1;
			else   				  mbc1_rom_bank_reg <= cart_di[4:0];
		end	
		if(cart_wr && (cart_addr[15:13] == 3'b010))
			mbc1_ram_bank_reg <= cart_di[1:0];
		if(cart_wr && (cart_addr[15:13] == 3'b011))
			mbc1_mode <= cart_di[0];
	end
end

always @(posedge clk_sys) begin
	if(reset) begin
		mbc3_rom_bank_reg <= 5'd1;
		mbc3_ram_bank_reg <= 2'd0;
      mbc3_mode <= 1'b0;
	end else if(ce_cpu) begin
		if(cart_wr && (cart_addr[15:13] == 3'b001)) begin
			if(cart_di[4:0]==0) mbc3_rom_bank_reg <= 5'd1;
			else   				  mbc3_rom_bank_reg <= cart_di[6:0];
		end	
		if(cart_wr && (cart_addr[15:13] == 3'b010))
			if (cart_di[3]==1)
				mbc3_mode <= 1;
		   else begin
			  mbc3_mode <= 0;
			  mbc3_ram_bank_reg <= cart_di[1:0];
		   end
	 end
end

always @(posedge clk_sys) begin
	if(reset) begin
		mbc5_rom_bank_reg <= 5'd1;
		mbc5_ram_bank_reg <= 2'd0;
	end else if(ce_cpu) begin
		if(cart_wr && (cart_addr[15:13] == 3'b001))
		   mbc5_rom_bank_reg <= cart_di[6:0];
		if(cart_wr && (cart_addr[15:13] == 3'b010))
			  mbc5_ram_bank_reg <= cart_di[1:0];
	 end
end

// extract header fields extracted from cartridge
// during download
reg [7:0] cart_mbc_type;
reg [7:0] cart_rom_size;
reg [7:0] cart_ram_size;

// only write sdram if the write attept comes from the cart ram area
wire cart_ram_wr = cart_wr && mbc_ram_enable && (cart_addr[15:13] == 3'b101);
   
// RAM size
wire [1:0] ram_mask =              			// 0 - no ram
	   (cart_ram_size == 1)?2'b00:  			// 1 - 2k, 1 bank
	   (cart_ram_size == 2)?2'b00:  			// 2 - 8k, 1 bank
	   2'b11;                       			// 3 - 32k, 4 banks

// ROM size
wire [6:0] rom_mask =                   	// 0 - 2 banks, 32k direct mapped
	   (cart_rom_size == 1)?7'b0000011:  	// 1 - 4 banks = 64k
	   (cart_rom_size == 2)?7'b0000111:  	// 2 - 8 banks = 128k
	   (cart_rom_size == 3)?7'b0001111:  	// 3 - 16 banks = 256k
	   (cart_rom_size == 4)?7'b0011111:  	// 4 - 32 banks = 512k
	   (cart_rom_size == 5)?7'b0111111:  	// 5 - 64 banks = 1M
	   (cart_rom_size == 6)?7'b1111111:    // 6 - 128 banks = 2M		
//?		(cart_rom_size == 6)?7'b1111111:    // 7 - ??? banks = 4M
//?		(cart_rom_size == 6)?7'b1111111:    // 8 - ??? banks = 8M
		(cart_rom_size == 82)?7'b1000111:   //$52 - 72 banks = 1.1M
		(cart_rom_size == 83)?7'b1001111:   //$53 - 80 banks = 1.2M
//		(cart_rom_size == 84)?7'b1011111:
                            7'b1011111;   //$54 - 96 banks = 1.5M

wire mbc1 = (cart_mbc_type == 1) || (cart_mbc_type == 2) || (cart_mbc_type == 3) || ~status[6];
wire mbc2 = (cart_mbc_type == 5) || (cart_mbc_type == 6);
wire mmm01 = (cart_mbc_type == 11) || (cart_mbc_type == 12) || (cart_mbc_type == 13) || (cart_mbc_type == 14);
wire mbc3 = (cart_mbc_type == 15) || (cart_mbc_type == 16) || (cart_mbc_type == 17) || (cart_mbc_type == 18) || (cart_mbc_type == 19);
wire mbc4 = (cart_mbc_type == 21) || (cart_mbc_type == 22) || (cart_mbc_type == 23);
wire mbc5 = (cart_mbc_type == 25) || (cart_mbc_type == 26) || (cart_mbc_type == 27) || (cart_mbc_type == 28) || (cart_mbc_type == 29) || (cart_mbc_type == 30);
wire tama5 = (cart_mbc_type == 253);
//wire tama6 = (cart_mbc_type == ???);
wire HuC1 = (cart_mbc_type == 254);
wire HuC3 = (cart_mbc_type == 255);

wire [8:0] mbc_bank =
//	mbc2?mbc2_addr:                  // MBC2, 16k bank 0, 16k bank 1-15 + ram
	mbc3?mbc3_addr:
//	mbc4?mbc4_addr:
	mbc5?mbc5_addr:
//	tama5?tama5_addr:
//	HuC1?HuC1_addr:
//	HuC3?HuC3_addr:
	mbc1?mbc1_addr:                  // MBC1, 16k bank 0, 16k bank 1-127 + ram
	{7'b0000000, cart_addr[14:13]};  // no MBC, 32k linear address

always @(posedge clk_sys) begin
	if(!pll_locked) begin
		cart_mbc_type <= 8'h00;
		cart_rom_size <= 8'h00;
		cart_ram_size <= 8'h00;
	end else begin
		if(ioctl_download & ioctl_wr) begin
			case(ioctl_addr)
				'h146: cart_mbc_type <= ioctl_dout[15:8];
				'h148: { cart_ram_size, cart_rom_size } <= ioctl_dout;
			endcase
		end
	end
end

//TODO: e.g. output and read timer register values from mbc3 when selected
wire [7:0]  cart_di;    // data from cpu to cart
wire [7:0]  cart_do = ~cart_ready ? 8'h00 : ((cart_addr[15:13] == 3'b101) && ~mbc_ram_enable)?8'hFF:cart_addr[0] ? sdram_do[15:8] : sdram_do[7:0]; //return 0xff when reading from disabled ram
wire [15:0] cart_addr;
wire cart_rd;
wire cart_wr;

wire lcd_clkena;
wire [1:0] lcd_data;
wire [1:0] lcd_mode;
wire lcd_on;

assign AUDIO_S = 0;

wire reset = (RESET | status[0] | status[6] | buttons[1] | ioctl_download);


// the gameboy itself
gb gb (
	.reset	    ( reset      ),
	.clk         ( clk_cpu    ),   // the whole gameboy runs on 4mhnz

	.fast_boot   ( status[2]  ),
	.joystick    ( joystick   ),

	// interface to the "external" game cartridge
	.cart_addr   ( cart_addr  ),
	.cart_rd     ( cart_rd    ),
	.cart_wr     ( cart_wr    ),
	.cart_do     ( cart_do    ),
	.cart_di     ( cart_di    ),

	// audio
	.audio_l 	 ( AUDIO_L	  ),
	.audio_r 	 ( AUDIO_R	  ),
	
	// interface to the lcd
	.lcd_clkena  ( lcd_clkena ),
	.lcd_data    ( lcd_data   ),
	.lcd_mode    ( lcd_mode   ),
	.lcd_on      ( lcd_on     )
);

// the lcd to vga converter
wire [5:0] video_r, video_g, video_b;
wire video_hs, video_vs, video_bl;

lcd lcd (
	 .pclk   ( clk_sys    ),
	 .pce    ( ce_pix     ),
	 .clk    ( clk_cpu    ),

	 .tint   ( status[1]  ),
	 .inv    ( status[4]  ),

	 // serial interface
	 .clkena ( lcd_clkena ),
	 .data   ( lcd_data   ),
	 .mode   ( lcd_mode   ),  // used to detect begin of new lines and frames
	 .on     ( lcd_on     ),
	 
  	 .hs     ( VGA_HS     ),
	 .vs     ( VGA_VS     ),
	 .blank  ( video_bl   ),
	 .r      ( video_r    ),
	 .g      ( video_g    ),
	 .b      ( video_b    )
);

assign VGA_R  = {video_r,video_r[5:4]};
assign VGA_G  = {video_g,video_g[5:4]};
assign VGA_B  = {video_b,video_b[5:4]};
assign VGA_DE = ~video_bl;
assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix2;

wire clk_cpu = clk_sys & ce_cpu;

reg ce_pix, ce_cpu, ce_pix2;
always @(negedge clk_sys) begin
	reg [2:0] div = 0;

	div <= div + 1'd1;
	ce_pix2  <= !div[0];
	ce_pix   <= !div[1:0];
	ce_cpu   <= !div[2:0];
end

endmodule
