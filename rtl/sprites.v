//
// sprites.v
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

module sprites (
	input clk,
	input ce,
	input ce_cpu,
	input size16,
	input isGBC,
	input sprite_en,

	input lcd_on,

	// pixel position input which the current pixel is generated for
	input [7:0] v_cnt,
	input [7:0] h_cnt,

	input sprite_fetch_c1,
	input sprite_fetch_done,
	output sprite_fetch,

	input oam_fetch,
	input oam_eval_reset,
	output oam_eval,

	output [10:0] sprite_addr,
	output [7:0] sprite_attr,
	output [3:0] sprite_index,

	output oam_eval_end,

	// oam memory interface
	input dma_active,
	input oam_wr,
	input [7:0] oam_addr_in,
	input [7:0] oam_di,
	output [7:0] oam_do,

	input extra_spr_en,
	input extra_wait,

	output extra_tile_fetch,
	output [11:0] extra_tile_addr,
	input [7:0] tile_data_in,

	output spr_extra_found,
	output [7:0] spr_extra_tile0,
	output [7:0] spr_extra_tile1,
	output [2:0] spr_extra_cgb_pal,
	output [3:0] spr_extra_index,
	output spr_extra_pal,
	output spr_extra_prio,
   
   // savestates
   input [7:0] Savestate_OAMRAMAddr,     
   input       Savestate_OAMRAMRWrEn,    
   input [7:0] Savestate_OAMRAMWriteData,
   output[7:0] Savestate_OAMRAMReadData  
);

localparam SPRITES_PER_LINE = 10;

wire [7:2] oam_eval_addr, oam_fetch_addr;
wire [7:0] oam_l_q, oam_h_q;

reg oam_eval_en;
assign oam_eval = lcd_on & ~oam_eval_end & oam_eval_en & ~oam_eval_reset;

wire [3:0] fetch_row;

wire oam_eval_extra;
wire [7:1] oam_extra_addr;
wire [7:0] spr_extra_fetch_attr;

wire [7:1] oam_addr = dma_active ? oam_addr_in[7:1] :
						oam_eval_extra ? { oam_extra_addr } :
						oam_eval ? { oam_eval_addr, 1'b0 } :
						oam_fetch ? { oam_fetch_addr, 1'b1 } :
						oam_addr_in[7:1];
                  
wire valid_oam_addr = (oam_addr[7:4] < 4'hA); // $FEA0 - $FEFF unused range
assign oam_do = ~valid_oam_addr ? 8'd0 : (oam_addr_in[0] ? oam_h_q : oam_l_q);

wire [7:0] Savestate_OAMRAMReadDataL, Savestate_OAMRAMReadDataH;

dpram #(7,8) oam_data_l (
	.clock_a   (clk      ),
	.address_a (oam_addr[7:1]),
	.wren_a    (ce_cpu && oam_wr && valid_oam_addr && ~oam_addr_in[0]),
	.data_a    (oam_di   ),
	.q_a       (oam_l_q  ),
	
	.clock_b   (clk),
	.address_b (Savestate_OAMRAMAddr[7:1]),
	.wren_b    (Savestate_OAMRAMRWrEn & ~Savestate_OAMRAMAddr[0]),
	.data_b    (Savestate_OAMRAMWriteData),
	.q_b       (Savestate_OAMRAMReadDataL)
);

dpram #(7,8) oam_data_h (
	.clock_a   (clk      ),
	.address_a (oam_addr[7:1] ),
	.wren_a    (ce_cpu && oam_wr && valid_oam_addr && oam_addr_in[0]),
	.data_a    (oam_di   ),
	.q_a       (oam_h_q  ),

	.clock_b   (clk),
	.address_b (Savestate_OAMRAMAddr[7:1]),
	.wren_b    (Savestate_OAMRAMRWrEn & Savestate_OAMRAMAddr[0]),
	.data_b    (Savestate_OAMRAMWriteData),
	.q_b       (Savestate_OAMRAMReadDataH)
);

assign Savestate_OAMRAMReadData = Savestate_OAMRAMAddr[0] ? Savestate_OAMRAMReadDataH : Savestate_OAMRAMReadDataL;

reg [7:0] sprite_x[0:SPRITES_PER_LINE-1];
reg [3:0] sprite_y[0:SPRITES_PER_LINE-1];
reg [5:0] sprite_no[0:SPRITES_PER_LINE-1];

// OAM evaluation. Get the first 10 sprites on the current line.
reg [5:0] spr_index, spr_index_d; // 40 sprites
reg [3:0] sprite_cnt;
reg oam_eval_clk, oam_eval_clk_d, oam_eval_save;

reg [7:0] sprite_x_attr, tile_index_y;
wire [7:0] spr_height = size16 ? 8'd16 : 8'd8;
wire sprite_on_line = (v_cnt + 8'd16 >= tile_index_y) && (v_cnt + 8'd16 < tile_index_y + spr_height);
wire sprite_save = oam_eval_clk_d & oam_eval_en & sprite_on_line;

assign oam_eval_end = (spr_index == 6'd40);

wire [0:9] sprite_x_matches;

reg old_fetch_done;
integer spr_i = 0;
always @(posedge clk) begin
	if (ce) begin

		if (oam_eval_reset | ~lcd_on) begin
			sprite_cnt <= 0;
			spr_index <= ~lcd_on ? 6'd1 : 6'd0;
			oam_eval_clk <= 0;
			oam_eval_clk_d <= 0;
			oam_eval_en <= oam_eval_reset ? 1'b1 : 1'b0; // OAM evaluation does not run on the first line after enabling the lcd
			for (spr_i=0; spr_i < SPRITES_PER_LINE; spr_i=spr_i+1) begin
				sprite_x[spr_i] <= 8'hFF;
				sprite_no[spr_i] <= 6'd0;
			end
		end else begin

			if (~oam_eval_end) begin
				if (oam_eval_clk) begin
					spr_index <= spr_index + 1'b1;
					spr_index_d <= spr_index;
				end
				oam_eval_clk <= ~oam_eval_clk;
			end

			oam_eval_clk_d <= oam_eval_clk;
			if (sprite_save & (sprite_cnt < SPRITES_PER_LINE)) begin
				sprite_no[sprite_cnt] <= spr_index_d;
				sprite_x[sprite_cnt] <= sprite_x_attr;
				sprite_y[sprite_cnt] <= v_cnt[3:0] - tile_index_y[3:0];
				sprite_cnt <= sprite_cnt + 1'b1;
			end

			// Set X-position to FF after fetching the sprite to prevent fetching it again.
			old_fetch_done <= sprite_fetch_done;
			if (~old_fetch_done & sprite_fetch_done) begin
				if (sprite_x_matches[0]) sprite_x[0] <= 8'hFF;
				else if (sprite_x_matches[1]) sprite_x[1] <= 8'hFF;
				else if (sprite_x_matches[2]) sprite_x[2] <= 8'hFF;
				else if (sprite_x_matches[3]) sprite_x[3] <= 8'hFF;
				else if (sprite_x_matches[4]) sprite_x[4] <= 8'hFF;
				else if (sprite_x_matches[5]) sprite_x[5] <= 8'hFF;
				else if (sprite_x_matches[6]) sprite_x[6] <= 8'hFF;
				else if (sprite_x_matches[7]) sprite_x[7] <= 8'hFF;
				else if (sprite_x_matches[8]) sprite_x[8] <= 8'hFF;
				else if (sprite_x_matches[9]) sprite_x[9] <= 8'hFF;
			end

		end
	end
end

assign oam_eval_addr = spr_index;

wire eval_save_xy = (~oam_eval_end & oam_eval_en & oam_eval_clk & ~dma_active);
wire fetch_save_index_attr = (sprite_fetch & sprite_fetch_c1);
always @(posedge clk) begin
	if (ce) begin
		if (eval_save_xy | fetch_save_index_attr) begin
			tile_index_y <= oam_l_q;
			sprite_x_attr <= oam_h_q;
		end
	end
end

// Sprite fetching
assign sprite_x_matches = {
		sprite_x[0] == h_cnt,
		sprite_x[1] == h_cnt,
		sprite_x[2] == h_cnt,
		sprite_x[3] == h_cnt,
		sprite_x[4] == h_cnt,
		sprite_x[5] == h_cnt,
		sprite_x[6] == h_cnt,
		sprite_x[7] == h_cnt,
		sprite_x[8] == h_cnt,
		sprite_x[9] == h_cnt
};

assign sprite_fetch = |sprite_x_matches & oam_fetch & (isGBC | sprite_en);

wire [3:0] active_sprite =
		sprite_x_matches[0] ? 4'd0 :
		sprite_x_matches[1] ? 4'd1 :
		sprite_x_matches[2] ? 4'd2 :
		sprite_x_matches[3] ? 4'd3 :
		sprite_x_matches[4] ? 4'd4 :
		sprite_x_matches[5] ? 4'd5 :
		sprite_x_matches[6] ? 4'd6 :
		sprite_x_matches[7] ? 4'd7 :
		sprite_x_matches[8] ? 4'd8 :
							  4'd9;
assign sprite_index = active_sprite;
assign sprite_attr = oam_eval_extra ? spr_extra_fetch_attr : sprite_x_attr;

assign oam_fetch_addr = sprite_no[active_sprite];

assign fetch_row = sprite_attr[6] ? ~sprite_y[active_sprite] : sprite_y[active_sprite];

assign sprite_addr = size16 ? {tile_index_y[7:1],fetch_row} : {tile_index_y,fetch_row[2:0]};

// Extra sprites:
// Sprite tile fetching during mode3 reduces the length of HBlank.
// Simply adding more sprites will shorten HBlank even more which breaks timing.
// Instead, this module will try to fetch tile data for extra sprites during mode2 if VRAM is idle.
sprites_extra sprites_extra (
	.clk            ( clk ),
	.ce             ( ce  ),

	.extra_spr_en   ( extra_spr_en ),

	.v_cnt          ( v_cnt ),
	.h_cnt          ( h_cnt ),

	.oam_eval_clk   ( oam_eval_clk ),
	.oam_eval_reset ( oam_eval_reset | ~lcd_on),
	.oam_eval_end   ( oam_eval_end ),

	.size16         ( size16 ),

	.oam_index      ( spr_index ),
	.sprite_cnt     ( sprite_cnt ),

	.oam_l_q        ( oam_l_q ),
	.oam_h_q        ( oam_h_q ),

	.extra_wait     ( extra_wait ),
	.oam_eval_extra ( oam_eval_extra ),
	.oam_extra_addr ( oam_extra_addr ) ,

	.spr_fetch_attr ( spr_extra_fetch_attr ),

	.tile_fetch     ( extra_tile_fetch ),
	.tile_data_in   ( tile_data_in ),
	.tile_addr      ( extra_tile_addr ),

	.spr_found      ( spr_extra_found ),
	.spr_tile0      ( spr_extra_tile0 ),
	.spr_tile1      ( spr_extra_tile1 ),
	.spr_pal        ( spr_extra_pal ),
	.spr_prio       ( spr_extra_prio ),
	.spr_cgb_pal    ( spr_extra_cgb_pal ),
	.spr_index      ( spr_extra_index )
);

endmodule