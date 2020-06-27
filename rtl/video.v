//
// video.v
//
// Gameboy for the MIST board https://github.com/mist-devel
//
// Copyright (c) 2015 Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module video (
	input  reset,
	input  clk,
	input  ce, // 4 Mhz cpu clock
	input  ce_cpu, // 4 or 8Mhz
	input  isGBC,
	input  isGBC_game,

	// cpu register adn oam interface
	input  cpu_sel_oam,
	input  cpu_sel_reg,
	input [7:0] cpu_addr,
	input  cpu_wr,
	input [7:0] cpu_di,
	output [7:0] cpu_do,

	// output to lcd
	output lcd_on,
	output lcd_clkena,
	output [14:0] lcd_data,

	output irq,
	output vblank_irq,

	// vram connection
	output [1:0] mode,
	output vram_rd,
	output [12:0] vram_addr,
	input [7:0] vram_data,

	// vram connection bank1 (GBC)
	input [7:0] vram1_data,

	// dma connection
	output dma_rd,
	output [15:0] dma_addr,
	input [7:0] dma_data
);

wire [7:0] oam_do;
wire [10:0] sprite_addr;

wire sprite_found;
wire [7:0] sprite_attr;
wire [3:0] sprite_index;

wire oam_eval_end;
sprites sprites (
	.clk      ( clk          ),
	.ce       ( ce           ),
	.ce_cpu   ( ce_cpu       ),
	.size16   ( lcdc_spr_siz ),
	.isGBC_game ( isGBC&&isGBC_game ),

	.lcd_on   ( lcd_on       ),

	.v_cnt    ( v_cnt        ),
	.h_cnt    ( pcnt        ),

	.oam_eval  ( oam ),
	.oam_fetch ( mode3 ),
	.oam_eval_reset ( end_of_line & ~vblank ),
	.oam_eval_end ( oam_eval_end ),

	.sprite_fetch (sprite_found),
	.sprite_addr ( sprite_addr                 ),
	.sprite_attr ( sprite_attr ),
	.sprite_index ( sprite_index ),
	.sprite_fetch_done ( sprite_fetch_done) ,

	.dma_active ( dma_active),
	.oam_wr     ( oam_wr       ),
	.oam_addr_in( oam_addr     ),
	.oam_di     ( oam_di       ),
	.oam_do     ( oam_do       )
);

// give dma access to oam
wire [7:0] oam_addr = dma_active?dma_addr[7:0]:cpu_addr;
wire oam_wr = dma_active?(dma_cnt[1:0] == 2):(cpu_wr && cpu_sel_oam && !(mode==3 || mode==2));
wire [7:0] oam_di = dma_active?dma_data:cpu_di;


assign lcd_on = lcdc_on;

// $ff40 LCDC
wire lcdc_on = lcdc[7];
wire lcdc_win_tile_map_sel = lcdc[6];
wire lcdc_win_ena = lcdc[5];
wire lcdc_tile_data_sel = lcdc[4];
wire lcdc_bg_tile_map_sel = lcdc[3];
wire lcdc_spr_siz = lcdc[2];
wire lcdc_spr_ena = lcdc[1];
// "CGB in CGB Mode: BG and Window Master Priority
//  When Bit 0 is cleared, the background and window lose their priority
//  - the sprites will be always displayed on top of background and window,
//  independently of the priority flags in OAM and BG Map attributes."
wire lcdc_bg_ena = lcdc[0] | (isGBC&&isGBC_game);
wire lcdc_bg_prio = lcdc[0];

reg [7:0] lcdc;

// ff41 STAT
reg [7:0] stat;

// ff42, ff43 background scroll registers
reg [7:0] scy;
reg [7:0] scx;

// ff44 line counter
wire [7:0] ly = v_cnt;

// ff45 line counter compare
wire lyc_match = (ly == lyc);
reg [7:0] lyc;

reg [7:0] bgp;
reg [7:0] obp0;
reg [7:0] obp1;

reg [7:0] wy;
reg [7:0] wx;

//ff68-ff6A GBC
//FF68 - BCPS/BGPI  - Background Palette Index
reg [5:0] bgpi; //Bit 0-5   Index (00-3F)
reg bgpi_ai;    //Bit 7     Auto Increment  (0=Disabled, 1=Increment after Writing)

//FF69 - BCPD/BGPD - Background Palette Data
reg[7:0] bgpd [63:0]; //64 bytes

//FF6A - OCPS/OBPI - Sprite Palette Index
reg [5:0] obpi; //Bit 0-5   Index (00-3F)
reg obpi_ai;    //Bit 7     Auto Increment  (0=Disabled, 1=Increment after Writing)

//FF6B - OCPD/OBPD - Sprite Palette Data
reg[7:0] obpd [63:0]; //64 bytes

// --------------------------------------------------------------------
// ----------------------------- DMA engine ---------------------------
// --------------------------------------------------------------------

assign dma_addr = { dma, dma_cnt[9:2] };
assign dma_rd = dma_active;

reg dma_active;
reg [7:0] dma;
reg [9:0] dma_cnt;     // dma runs 4*160 clock cycles = 160us @ 4MHz
always @(posedge clk) begin
	if(reset)
		dma_active <= 1'b0;
	else if (ce_cpu) begin
		// writing the dma register engages the dma engine
		if(cpu_sel_reg && cpu_wr && (cpu_addr == 8'h46)) begin
			dma_active <= 1'b1;
			dma_cnt <= 10'd0;
		end else if(dma_cnt != 160*4-1)
			dma_cnt <= dma_cnt + 10'd1;
		else
			dma_active <= 1'b0;
	end
end

// --------------------------------------------------------------------
// ------------------------------- IRQs -------------------------------
// --------------------------------------------------------------------
//
// "The interrupt is triggered when transitioning from "No conditions met" to
// "Any condition met", which can cause the interrupt to not fire."
//
// Example: Altered Space enables OAM+Hblank+Vblank interrupt and requires the
// interrupt to trigger only on a Mode 3 to Hblank transition.
// OAM follows immediately after Hblank/Vblank so no OAM interrupt is triggered.

wire h455 = (h_cnt == 9'd455);
wire vblank  = (v_cnt >= 144);

reg vblank_l, end_of_line, lyc_match_l;
always @(posedge clk) begin
	if (!lcd_on) begin
		vblank_l <= 1'b0;
		end_of_line <= 1'b0;
	end else if (ce) begin
		if (h455) end_of_line <= 1'b1;
		else if (end_of_line) begin
			// Vblank is latched a few cycles after line end.
			// This causes an OAM interrupt at the beginning of line 144.
			// It also makes the OAM interrupt at line 0 after Vblank a few cycles late.
			if (h_cnt[1:0] == 2'b10) begin
				vblank_l <= vblank;
			end
			// end_of_line is active for 4 cycles
			if (&h_cnt[1:0]) begin
				end_of_line <= 1'b0;
			end
		end
	end
end

always @(posedge clk) begin
	if (reset) begin
		lyc_match_l <= 1'b0; // lyc_match does not reset when lcd is off
	end else if (ce) begin
		if (h_cnt[1:0] == 2'b10) begin
			lyc_match_l <= lyc_match;
		end
	end
end

wire mode3_end = ~sprite_found & (pcnt == 8'd167);
reg mode3_end_l;
always @(posedge clk) begin
	if (!lcd_on) begin
		mode3_end_l <= 1'b0;
	end else if (ce) begin
		if (end_of_line & ~vblank)
			mode3_end_l <= 1'b0;
		else
			mode3_end_l <= mode3_end;
	end
end

wire int_lyc = (stat[6] & lyc_match_l);
wire int_oam = (stat[5] & end_of_line & ~vblank_l);
wire int_vbl = (stat[4] & vblank_l);
wire int_hbl = (stat[3] & mode3_end & ~vblank_l);

assign irq = (int_lyc | int_oam | int_hbl | int_vbl);
assign vblank_irq = vblank_l;

// end_of_line is active for 4 cycles at the beginning of a line so
// OAM evaluation starts at cycle 4.
// Except on the first line when the LCD is enabled after being disabled
// where it starts at cycle 0.
wire oam     = lcd_on & ~end_of_line & ~oam_eval_end;
wire mode3   = lcd_on & ~mode3_end_l & oam_eval_end;

assign mode = 
	vblank_l ? 2'b01 :
	oam      ? 2'b10 :
	mode3    ? 2'b11 :
	           2'b00;

// --------------------------------------------------------------------
// --------------------- CPU register interface -----------------------
// --------------------------------------------------------------------
integer ii=0;
always @(posedge clk) begin
	if(reset) begin
		lcdc <= 8'h00;  // screen must be off since dmg rom writes to vram
		scy <= 8'h00;
		scx <= 8'h00;
		wy <= 8'h00;
		wx <= 8'h00;
		stat <= 8'h00;
		bgp <= 8'hfc;
		obp0 <= 8'hff;
		obp1 <= 8'hff;

		bgpi <= 6'h0;
		obpi <= 6'h0;
		bgpi_ai <= 1'b0;
		obpi_ai <= 1'b0;

		for (ii=0;ii<64;ii=ii+1)begin
			bgpd[ii] <= 8'h00;
			obpd[ii] <= 8'h00;
		end

	end else if (ce_cpu) begin
		if(cpu_sel_reg && cpu_wr) begin
			case(cpu_addr)
				8'h40:	lcdc <= cpu_di;
				8'h41:	stat <= cpu_di;
				8'h42:	scy <= cpu_di;
				8'h43:	scx <= cpu_di;
				// a write to 4 is supposed to reset the v_cnt
				8'h45:	lyc <= cpu_di;
				8'h46:	dma <= cpu_di;
				8'h47:	bgp <= cpu_di;
				8'h48:	obp0 <= cpu_di;
				8'h49:	obp1 <= cpu_di;
				8'h4a:	wy <= cpu_di;
				8'h4b:	wx <= cpu_di;

				//gbc
				8'h68: begin
							bgpi <= cpu_di[5:0];
							bgpi_ai <= cpu_di[7];
						 end
				8'h69: begin
							if (mode != 3) begin
								bgpd[bgpi] <= cpu_di;
							end
							//"Writing to FF69 during rendering still causes auto-increment to occur."
							if (bgpi_ai) bgpi <= bgpi + 6'h1;
						 end
				8'h6A: begin
							obpi <= cpu_di[5:0];
							obpi_ai <= cpu_di[7];
						 end
				8'h6B: begin
							if (mode != 3) begin
								obpd[obpi] <= cpu_di;
							end
							if (obpi_ai) obpi <= obpi + 6'h1;
						 end
			endcase
		end
	end
end

assign cpu_do =
	cpu_sel_oam?oam_do:
	(cpu_addr == 8'h40)?lcdc:
	(cpu_addr == 8'h41)?{1'b1,stat[6:3], lyc_match_l, mode}:
	(cpu_addr == 8'h42)?scy:
	(cpu_addr == 8'h43)?scx:
	(cpu_addr == 8'h44)?ly:
	(cpu_addr == 8'h45)?lyc:
	(cpu_addr == 8'h46)?dma:
	(cpu_addr == 8'h47)?bgp:
	(cpu_addr == 8'h48)?obp0:
	(cpu_addr == 8'h49)?obp1:
	(cpu_addr == 8'h4a)?wy:
	(cpu_addr == 8'h4b)?wx:
	isGBC?
		(cpu_addr == 8'h68)?{bgpi_ai,1'd0,bgpi}:
		(cpu_addr == 8'h69 && mode != 3)?bgpd[bgpi]:
		(cpu_addr == 8'h6a)?{obpi_ai,1'd0,obpi}:
		(cpu_addr == 8'h6b && mode != 3)?obpd[obpi]:
		8'hff:
	8'hff;

// --------------------------------------------------------------------
// -------------- counters & background tilemap address----------------
// --------------------------------------------------------------------

reg skip_en;
reg [7:0] skip;
reg [7:0] pcnt;

always @(posedge clk) begin
	if (!lcd_on) begin
		skip_en <= 1'b0;
		pcnt <= 8'd0;
		skip <= 8'd0;
	end else if (ce) begin
		// Only skip when not paused for sprites and fifo is not empty.
		// This makes it skip pixels when pcnt = 1 after the first tile fetch.
		// If window_x = 0 then window starts at pcnt = 1 when it is skipping pixels which scrolls the window.
		if (~sprite_fetch_hold & ~bg_shift_empty) begin
			if ((pcnt == 0) && |scx[2:0]) begin
				skip <= scx[2:0];
				skip_en <= 1'b1;
			end

			if(skip) skip <= skip - 1'd1;

			if(skip == 1) skip_en <= 1'b0;

			// Pixels 0-7 are for fetching partially offscreen sprites and window.
			// Pixels 8-167 are output to the display.
			if(~skip_en && pcnt != 8'd167)
				pcnt <= pcnt + 1'd1;

		end

		if (end_of_line & ~vblank) begin
			pcnt <= 8'd0;
		end
	end
end

reg [8:0] h_cnt;            // max 455
reg [7:0] v_cnt;            // max 153
reg [7:0] win_line;

// TODO: Fix window_x = A6. Hblank starts when it should be waiting for the window fetching to end
wire win_start = lcdc_win_ena && ~sprite_fetch_hold && ~skip_en && ~bg_shift_empty && (v_cnt >= wy) && (pcnt == wx) && (wx < 8'hA6);
reg window_ena;

// vcnt_reset goes high a few cycles after v_cnt is incremented to 153.
// It resets v_cnt back to 0 and keeps it in reset until the following line.
// This results in v_cnt 0 lasting for almost 2 lines.
wire line153 = (v_cnt == 8'd153);
reg vcnt_reset;
always @(posedge clk) begin
	if (!lcdc_on) begin
		v_cnt <= 8'd0;
		win_line <= 8'd0;
		vcnt_reset <= 1'b0;
	end else if (ce) begin
		if (~vcnt_reset && h_cnt == 9'd455) begin
			v_cnt <= v_cnt + 1'b1;
			if (window_ena) win_line <= win_line + 1'b1;
		end

		if (end_of_line && &h_cnt[1:0]) begin
			vcnt_reset <= line153;
			if (line153) begin
				v_cnt <= 8'd0;
				win_line <= 8'd0;
			end
		end
	end
end

// line inside the background currently being drawn
wire [7:0] bg_line = v_cnt + scy;
wire [7:0] bg_col  = pcnt + scx;
wire [9:0] bg_map_addr = {bg_line[7:3], bg_col[7:3]};

reg  [4:0] win_col;
wire [9:0] win_map_addr = {win_line[7:3], win_col[4:0]};

wire [9:0] bg_tile_map_addr = window_ena ? win_map_addr : bg_map_addr;
wire [2:0] tile_line = window_ena ? win_line[2:0] : bg_line[2:0];

always @(posedge clk) begin

	if (!lcdc_on) begin
		//reset counters
		h_cnt <= 9'd0;
		window_ena <= 1'b0;
	end else if (ce) begin

		if(h_cnt != 455) begin
			h_cnt <= h_cnt + 9'd1;

			if(win_start) begin
				win_col <= 5'd0; // window always start with its very left
				window_ena <= 1'b1;
			end

			// Increment when fetching is done and not waiting for sprites.
			if(window_ena && ~sprite_fetch_hold && bg_fetch_done && bg_reload_shift)
				win_col <= win_col + 1'b1;

		end else begin
			window_ena <= 1'b0;   // next line starts with background

			// end of line reached
			h_cnt <= 9'd0;

		end
	end
end


// --------------------------------------------------------------------
// ------------------- bg, window and sprite fetch  -------------------
// --------------------------------------------------------------------

function [7:0] bit_reverse;
	input [7:0] a;
	begin
		bit_reverse = {a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]};
	end
endfunction

// output shift registers for both video data bits
reg [7:0] tile_shift_0;
reg [7:0] tile_shift_1;

// sprite output shift registers
reg [7:0] spr_tile_shift_0;
reg [7:0] spr_tile_shift_1;
reg [7:0] spr_pal_shift;
reg [7:0] spr_prio_shift;
reg [7:0] spr_cgb_pal_shift[0:2];
reg [7:0] spr_cgb_index_shift[0:3];

reg [7:0] bg_tile;
reg [7:0] bg_tile_data0;
reg [7:0] bg_tile_data1;

reg [7:0] spr_tile_data0;

reg [7:0] bg_tile_attr,bg_tile_attr_new; //GBC
//gbc check tile bank
wire [7:0] bg_vram_data_a = (isGBC & isGBC_game & bg_tile_attr_new[3]) ? vram1_data : vram_data;
//gbc x-flip
wire [7:0] bg_vram_data_in = (isGBC & isGBC_game & bg_tile_attr_new[5]) ? bit_reverse(bg_vram_data_a) : bg_vram_data_a;

// A bg or sprite fetch takes 6 cycles
reg [2:0] bg_fetch_cycle;
reg [2:0] sprite_fetch_cycle;

wire bg_fetch_done = (bg_fetch_cycle >= 3'd5);
wire sprite_fetch_done = (sprite_fetch_hold && sprite_fetch_cycle >= 3'd5);

// The first B01 cycle does not fetch sprites so wait until the bg shift register is not empty
wire sprite_fetch_hold = sprite_found & ~bg_shift_empty;

reg [3:0] bg_shift_cnt;
wire bg_shift_empty = (bg_shift_cnt == 0);
wire bg_reload_shift = (bg_shift_cnt <= 1);

wire spr_prio          = sprite_attr[7];
wire spr_attr_h_flip   = sprite_attr[5];
wire spr_pal           = sprite_attr[4];
wire spr_attr_cgb_bank = sprite_attr[3];
wire [2:0] spr_cgb_pal = sprite_attr[2:0];

wire [7:0] spr_vram_data = (isGBC & isGBC_game & spr_attr_cgb_bank) ? vram1_data : vram_data;
wire [7:0] spr_tile_data_in = spr_attr_h_flip ? bit_reverse(spr_vram_data) : spr_vram_data;

// CGB sprite priority. Non-transparent pixels with lower sprite_index have priority.
function [7:0] spr_cgb_prio;
	input [7:0] a3,a2,a1,a0;
	integer i;
	begin
		for (i=0;i<8;i=i+1)
			spr_cgb_prio[i] = (sprite_index < {a3[i], a2[i], a1[i], a0[i]}) & (spr_tile_data_in[i] | spr_tile_data0[i]);
	end
endfunction

wire [7:0] spr_cgb_index_prio = spr_cgb_prio(spr_cgb_index_shift[3], spr_cgb_index_shift[2], spr_cgb_index_shift[1], spr_cgb_index_shift[0]);

// DMG sprite pixels are only loaded into the shift register if the old pixel is transparent.
// CGB will mask the old pixel to 0 if the new pixel has higher priority.
wire [7:0] spr_tile_mask = (spr_tile_shift_0 | spr_tile_shift_1) & ((isGBC & isGBC_game) ? ~spr_cgb_index_prio : 8'hFF);

always @(posedge clk) begin

	if (ce) begin

		// every memory access is two pixel cycles
		if (bg_fetch_cycle[0]) begin
			if(bg_tile_map_rd) begin
				bg_tile <= vram_data;
				if (isGBC & isGBC_game) bg_tile_attr_new <= vram1_data; //get tile attr from vram bank1
			end

			if(bg_tile_data0_rd) bg_tile_data0 <= bg_vram_data_in;
			if(bg_tile_data1_rd) bg_tile_data1 <= bg_vram_data_in;
		end

		// Shift sprite data out
		if (~sprite_fetch_hold & ~skip_en & ~bg_shift_empty) begin
			spr_tile_shift_0       <=  spr_tile_shift_0       << 1;
			spr_tile_shift_1       <=  spr_tile_shift_1       << 1;
			spr_pal_shift          <=  spr_pal_shift          << 1;
			spr_prio_shift         <=  spr_prio_shift         << 1;
			spr_cgb_pal_shift[0]   <=  spr_cgb_pal_shift[0]   << 1;
			spr_cgb_pal_shift[1]   <=  spr_cgb_pal_shift[1]   << 1;
			spr_cgb_pal_shift[2]   <=  spr_cgb_pal_shift[2]   << 1;
			spr_cgb_index_shift[0] <=  spr_cgb_index_shift[0] << 1;
			spr_cgb_index_shift[1] <=  spr_cgb_index_shift[1] << 1;
			spr_cgb_index_shift[2] <=  spr_cgb_index_shift[2] << 1;
			spr_cgb_index_shift[3] <=  spr_cgb_index_shift[3] << 1;
		end

		// Fetch sprite new data
		if (sprite_fetch_cycle[0]) begin
			if(bg_tile_obj0_rd) spr_tile_data0 <= spr_tile_data_in;

			if(bg_tile_obj1_rd) begin
				spr_tile_shift_0       <= (spr_tile_shift_0       & spr_tile_mask) | ( spr_tile_data0      & ~spr_tile_mask);
				spr_tile_shift_1       <= (spr_tile_shift_1       & spr_tile_mask) | ( spr_tile_data_in    & ~spr_tile_mask);
				spr_pal_shift          <= (spr_pal_shift          & spr_tile_mask) | ({8{spr_pal}}         & ~spr_tile_mask);
				spr_prio_shift         <= (spr_prio_shift         & spr_tile_mask) | ({8{spr_prio}}        & ~spr_tile_mask);
				spr_cgb_pal_shift[0]   <= (spr_cgb_pal_shift[0]   & spr_tile_mask) | ({8{spr_cgb_pal[0]}}  & ~spr_tile_mask);
				spr_cgb_pal_shift[1]   <= (spr_cgb_pal_shift[1]   & spr_tile_mask) | ({8{spr_cgb_pal[1]}}  & ~spr_tile_mask);
				spr_cgb_pal_shift[2]   <= (spr_cgb_pal_shift[2]   & spr_tile_mask) | ({8{spr_cgb_pal[2]}}  & ~spr_tile_mask);
				spr_cgb_index_shift[0] <= (spr_cgb_index_shift[0] & spr_tile_mask) | ({8{sprite_index[0]}} & ~spr_tile_mask);
				spr_cgb_index_shift[1] <= (spr_cgb_index_shift[1] & spr_tile_mask) | ({8{sprite_index[1]}} & ~spr_tile_mask);
				spr_cgb_index_shift[2] <= (spr_cgb_index_shift[2] & spr_tile_mask) | ({8{sprite_index[2]}} & ~spr_tile_mask);
				spr_cgb_index_shift[3] <= (spr_cgb_index_shift[3] & spr_tile_mask) | ({8{sprite_index[3]}} & ~spr_tile_mask);
			end
		end

		if (~&bg_fetch_cycle) begin
			bg_fetch_cycle <= bg_fetch_cycle + 1'b1;
		end

		if (~sprite_fetch_hold) begin
			// shift bg/window pixels out
			tile_shift_0 <= tile_shift_0 << 1;
			tile_shift_1 <= tile_shift_1 << 1;

			if (|bg_shift_cnt) bg_shift_cnt <= bg_shift_cnt - 1'b1;

			if (bg_fetch_done && bg_reload_shift) begin
				bg_tile_attr <= bg_tile_attr_new;
				tile_shift_0 <= bg_tile_data0;
				// bg_tile_data1 only has valid data at cycle 6 so at cycle 5 bg_vram_data_in is loaded instead.
				tile_shift_1 <= (bg_fetch_cycle == 3'd5) ? bg_vram_data_in : bg_tile_data1;
				bg_shift_cnt <= 4'd8;
				bg_fetch_cycle <= 0;
			end
		end

		// Start sprite fetch after background fetching is done
		// Sprite fetching continues until there are no more sprites on the current x position
		if (sprite_fetch_hold && bg_fetch_done) begin
			sprite_fetch_cycle <= sprite_fetch_cycle + 1'b1;
		end

		if (~sprite_fetch_hold || sprite_fetch_done) sprite_fetch_cycle <= 0;

		// Window start, reset fetching
		if (win_start || !mode3) begin
			bg_fetch_cycle <= 0;
			bg_shift_cnt <= 0;
		end

	end

end

// cycle through the B01s states
wire bg_tile_map_rd = (mode3 && bg_fetch_cycle[2:1] == 2'b00);
wire bg_tile_data0_rd = (mode3 && bg_fetch_cycle[2:1] == 2'b01);
wire bg_tile_data1_rd = (mode3 && bg_fetch_cycle[2:1] == 2'b10);
wire bg_tile_obj0_rd = (mode3 && sprite_fetch_cycle[2:1] == 2'b01);
wire bg_tile_obj1_rd = (mode3 && sprite_fetch_cycle[2:1] == 2'b10);

assign vram_rd = lcdc_on && (bg_tile_map_rd || bg_tile_data0_rd ||
										bg_tile_data1_rd || bg_tile_obj0_rd || bg_tile_obj1_rd);

wire bg_tile_a12 = !lcdc_tile_data_sel?(~bg_tile[7]):1'b0;

wire tile_map_sel = window_ena?lcdc_win_tile_map_sel:lcdc_bg_tile_map_sel;

//GBC: check if flipped y
wire [2:0] tile_line_flip = (isGBC && isGBC_game && bg_tile_attr_new[6]) ? ~tile_line : tile_line;

assign vram_addr =
	bg_tile_map_rd?{2'b11, tile_map_sel, bg_tile_map_addr}:
	bg_tile_data0_rd?{bg_tile_a12, bg_tile, tile_line_flip, 1'b0}:
	bg_tile_data1_rd?{bg_tile_a12, bg_tile, tile_line_flip, 1'b1}:
	bg_tile_obj0_rd ? {1'b0, sprite_addr, 1'b0} :
		{1'b0, sprite_addr, 1'b1};

// --------------------------------------------------------------------
// ----------------------- lcd output stage   -------------------------
// --------------------------------------------------------------------

// https://forums.nesdev.com/viewtopic.php?f=20&t=10771&sid=8fdb6e110fd9b5434d4a567b1199585e#p122222
// priority list: BG0 < OBJL < BGL < OBJH < BGH
wire bg_piority = isGBC && isGBC_game && bg_tile_attr[7];

reg sprite_pixel_visible;

wire [1:0] sprite_pixel_data = {spr_tile_shift_1[7], spr_tile_shift_0[7]};
wire sprite_pixel_prio = spr_prio_shift[7];

always @(*) begin
	sprite_pixel_visible = 1'b0;
	if (|sprite_pixel_data && lcdc_spr_ena) begin		// pixel active and sprites enabled

		if (isGBC&&isGBC_game) begin
			if (sprite_pixel_data == 2'b00)
				sprite_pixel_visible = 1'b0;
			else if (bg_pix_data == 2'b00)
				sprite_pixel_visible = 1'b1;
			else if (!lcdc_bg_prio)
				sprite_pixel_visible = 1'b1;
			else if (bg_piority)
				sprite_pixel_visible = 1'b0;
			else if (!sprite_pixel_prio) //sprite pixel priority is enabled
				sprite_pixel_visible = 1'b1;

		end else begin
			if (sprite_pixel_data == 2'b00)
				sprite_pixel_visible = 1'b0;
			else if (bg_pix_data == 2'b00)
				sprite_pixel_visible = 1'b1;
			else if (!sprite_pixel_prio) //sprite pixel priority is enabled
				sprite_pixel_visible = 1'b1;
		end

	end

end

wire [1:0] bg_pix_data = { tile_shift_1[7], tile_shift_0[7] };

// If lcdc_bg_ena is off in Non-GBC mode then both background and window are blank. (BG color 0)
wire [1:0] bgp_data = (!lcdc_bg_ena || bg_pix_data == 2'b00) ? bgp[1:0] :
									  (bg_pix_data == 2'b01) ? bgp[3:2] :
									  (bg_pix_data == 2'b10) ? bgp[5:4] :
															bgp[7:6];

wire sprite_pixel_cmap = spr_pal_shift[7];
wire [7:0] obp = sprite_pixel_cmap?obp1:obp0;
wire [1:0] obp_data =   (sprite_pixel_data == 2'b00) ? obp[1:0] :
						(sprite_pixel_data == 2'b01) ? obp[3:2] :
						(sprite_pixel_data == 2'b10) ? obp[5:4] :
													obp[7:6];

wire [5:0] palette_index = isGBC_game ? {bg_tile_attr[2:0], bg_pix_data, 1'b0} :  //GBC game
									{3'd0, bgp_data , 1'b0}; //GB game in GBC mode

// apply bg palette
wire [14:0] pix_rgb_data = isGBC ? {bgpd[palette_index+1][6:0],bgpd[palette_index]} : //gbc
							{13'd0,bgp_data};

// apply sprite palette
wire [2:0] spr_cgb_pal_out = {spr_cgb_pal_shift[2][7], spr_cgb_pal_shift[1][7],spr_cgb_pal_shift[0][7]};
wire [5:0] sprite_palette_index = isGBC_game? {spr_cgb_pal_out, sprite_pixel_data, 1'b0 } : //gbc game
								{sprite_pixel_cmap, obp_data, 1'b0}; //GB game in GBC mode

wire [14:0] sprite_pix = isGBC ? {obpd[sprite_palette_index+1][6:0],obpd[sprite_palette_index]} : //gbc
							{13'd0,obp_data};

wire lcd_clk = mode3 && ~skip_en && ~sprite_fetch_hold && ~bg_shift_empty && (pcnt >= 8);

reg [14:0] lcd_data_out;
reg lcd_clk_out;
always @(posedge clk) begin
	if (ce) begin
		lcd_clk_out <= lcd_clk;
		if (lcd_clk) begin
			lcd_data_out <= (sprite_pixel_visible) ? sprite_pix : pix_rgb_data;
		end
	end
end

assign lcd_data = lcd_data_out;
assign lcd_clkena = lcd_clk_out;

endmodule
