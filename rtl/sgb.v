module sgb (
	input        reset,
	input        clk_sys,
	input        ce,

	input        clk_vid,
	input        ce_pix,

	input        sgb_en,
	input        tint,

	input        lcd_clkena,
	input [14:0] lcd_data,
	input [1:0]  lcd_mode,
	input        lcd_on,

	input [8:0]  h_cnt,
	input [8:0]  v_cnt,

	input [7:0]  joystick_0,
	input [7:0]  joystick_1,
	input [7:0]  joystick_2,
	input [7:0]  joystick_3,

	input [1:0]  joy_p54,
	output [3:0] joy_do,

	output reg [15:0] sgb_border_pix,

	output reg        sgb_pal_en,
	output reg [14:0] sgb_lcd_data,
	output reg        sgb_lcd_clkena,
	output reg [1:0]  sgb_lcd_mode,
	output reg        sgb_lcd_on
);

localparam CMD_PAL01    = 5'h00;
localparam CMD_PAL23    = 5'h01;
localparam CMD_PAL03    = 5'h02;
localparam CMD_PAL12    = 5'h03;
localparam CMD_ATTR_BLK = 5'h04;
localparam CMD_ATTR_LIN = 5'h05;
localparam CMD_ATTR_DIV = 5'h06;
localparam CMD_ATTR_CHR = 5'h07;
localparam CMD_PAL_SET  = 5'h0A;
localparam CMD_PAL_TRN  = 5'h0B;
localparam CMD_MLT_REQ  = 5'h11;
localparam CMD_CHR_TRN  = 5'h13;
localparam CMD_PCT_TRN  = 5'h14;
localparam CMD_ATTR_TRN = 5'h15;
localparam CMD_ATTR_SET = 5'h16;
localparam CMD_MASK_EN  = 5'h17;



wire p14 = joy_p54[0];
wire p15 = joy_p54[1];

reg old_p15, old_p14;
reg [7:0] data;
reg [3:0] byte_cnt;
reg [2:0] cnt, packet_cnt;
reg [2:0] length;
reg byte_done, packet_end;
reg [8:0] data_set_len, data_set_cnt;
reg [2:0] data_set_byte_cnt;
reg [4:0] cmd;

reg [1:0] mlt_ctrl;
reg trn_start, char_trn_tile, pal_set, attr_set;

reg [1:0] pal0123_no, pal0123_col_no;
reg [14:0] pal_color;
reg pal0123_wr;

reg [8:0] sys_pal_no[4];
reg [5:0] attr_file_no;
reg [1:0] mask_en;
reg cancel_mask;

reg [2:0] attr_blk_ctrl;
reg [5:0] attr_blk_pal;
reg [4:0] attr_blk_x1,attr_blk_x2,attr_blk_y1,attr_blk_y2;
reg attr_blk_set;

reg [7:0] attr_lin_data;
reg attr_lin_set;

reg [5:0] attr_div_pal;
reg attr_div_hv;
reg [4:0] attr_div_xy;
reg attr_div_set;

reg [7:0] attr_chr_data;
reg [4:0] attr_chr_data_x;
reg [8:0] attr_chr_data_offset, attr_chr_len;
reg attr_chr_set, attr_chr_dir, attr_chr_start;

always @(posedge clk_sys) begin
	 if (reset) begin
		attr_file_no <= 0;
		packet_cnt <= 0;
		cnt <= 0;
		byte_cnt <= 0;
		byte_done <= 0;
		data_set_len <= 0;
		data_set_cnt <= 0;
		mask_en <= 0;
		packet_end <= 1'b1;
		mlt_ctrl <= 0;
	 end else if (ce) begin
		old_p15 <= p15;
		old_p14 <= p14;

		if (old_p15 & old_p14 & sgb_en) begin

			// Reset pulse
			if (~p15 & ~p14) begin
				{cnt, byte_cnt, packet_end} <= 0;
			end

			if (p15 ^ p14) begin
				if (~packet_end) begin
					data <= {~p15,data[7:1]};
					cnt <= cnt + 1'b1;
					if (&cnt) byte_done <= 1'b1;
				end
			end

		end

		// Corrupt packet. p15 and p14 should both go high after one is low.
		if ( (old_p15 ^ p15) & (old_p15 ^ old_p14) & (p15 ^ p14) ) begin
			packet_end <= 1'b1;
		end

		trn_start <= 0;
		pal_set <= 0;
		attr_set <= 0;
		pal0123_wr <= 0;
		attr_blk_set <= 0;
		attr_lin_set <= 0;
		attr_div_set <= 0;
		attr_chr_set <= 0;

		if (pal_cancel_mask | attr_cancel_mask) mask_en <= 0;

		if (byte_done) begin
			byte_done <= 0;
			byte_cnt <= byte_cnt + 1'b1;

			if (!packet_cnt && !byte_cnt) {cmd,length} <= data;

			case (cmd)
				CMD_MLT_REQ: begin
					if (byte_cnt == 5'd1) mlt_ctrl <= data[1:0];
				end
				CMD_CHR_TRN: begin
					if (byte_cnt == 5'd1) begin
						trn_start <= 1'b1;
						char_trn_tile <= data[0];
					end
				end
				CMD_PCT_TRN,
				CMD_PAL_TRN,
				CMD_ATTR_TRN: begin
					if (byte_cnt == 5'd1) trn_start <= 1'b1;
				end
				CMD_PAL01,
				CMD_PAL23,
				CMD_PAL03,
				CMD_PAL12: begin
					if (byte_cnt >= 4'd1 && byte_cnt <= 4'd14) begin
						if (byte_cnt[0]) pal_color[7:0] <= data;
						else begin
							pal_color[14:8] <= data[6:0];
							pal0123_wr <= 1'b1;
						end
					end

					case (byte_cnt)
						1:    pal0123_col_no <= 2'd0;
						3,9:  pal0123_col_no <= 2'd1;
						5,11: pal0123_col_no <= 2'd2;
						7,13: pal0123_col_no <= 2'd3;
					endcase

					// color 0 always goes to palette 0
					case ({cmd,byte_cnt})
						{CMD_PAL01,4'd1},
						{CMD_PAL23,4'd1},
						{CMD_PAL03,4'd1},
						{CMD_PAL12,4'd1}: pal0123_no <= 2'd0;

						{CMD_PAL01,4'd9},
						{CMD_PAL12,4'd3}: pal0123_no <= 2'd1;

						{CMD_PAL12,4'd9},
						{CMD_PAL23,4'd3}: pal0123_no <= 2'd2;

						{CMD_PAL23,4'd9},
						{CMD_PAL03,4'd9}: pal0123_no <= 2'd3;
					endcase
				end
				CMD_PAL_SET:
					case (byte_cnt)
						1: sys_pal_no[0][7:0] <= data;
						2: sys_pal_no[0][8]   <= data[0];
						3: sys_pal_no[1][7:0] <= data;
						4: sys_pal_no[1][8]   <= data[0];
						5: sys_pal_no[2][7:0] <= data;
						6: sys_pal_no[2][8]   <= data[0];
						7: sys_pal_no[3][7:0] <= data;
						8: sys_pal_no[3][8]   <= data[0];
						9: begin
							attr_file_no <= data[5:0];
							cancel_mask <= data[6];
							if (data[7]) attr_set <= 1'b1;
							pal_set <= 1'b1;
						end
					endcase
				CMD_ATTR_SET: begin
					if (byte_cnt == 5'd1) begin
						attr_file_no <= data[5:0];
						cancel_mask <= data[6];
						attr_set <= 1'b1;
					end
				end
				CMD_ATTR_BLK: begin
					if (!packet_cnt && byte_cnt == 5'd1) begin
						data_set_len <= {4'd0,data[4:0]};
						data_set_cnt <= 0;
						data_set_byte_cnt <= 0;
					end

					if (|data_set_len && data_set_cnt < data_set_len) begin
						data_set_byte_cnt <= data_set_byte_cnt + 1'b1;

						case(data_set_byte_cnt)
							0: attr_blk_ctrl <= data[2:0];
							1: attr_blk_pal <= data[5:0];
							2: attr_blk_x1 <= data[4:0];
							3: attr_blk_y1 <= data[4:0];
							4: attr_blk_x2 <= data[4:0];
							5: begin
								attr_blk_y2 <= data[4:0];
								attr_blk_set <= 1'b1;
								data_set_byte_cnt <= 0;
								data_set_cnt <= data_set_cnt + 1'b1;
								if (data_set_cnt + 1'b1 == data_set_len) begin
									data_set_len <= 0;
								end
							end
						endcase
					end
				end
				CMD_ATTR_LIN: begin
					if (!packet_cnt && byte_cnt == 5'd1) begin
						data_set_len <= {2'd0,data[6:0]};
						data_set_cnt <= 0;
					end

					if (|data_set_len && data_set_cnt < data_set_len) begin
						attr_lin_data <= data;
						attr_lin_set <= 1'b1;
						data_set_cnt <= data_set_cnt + 1'b1;
						if (data_set_cnt + 1'b1 == data_set_len) begin
							data_set_len <= 0;
						end

					end
				end
				CMD_ATTR_DIV: begin
					case (byte_cnt)
						1: {attr_div_hv,attr_div_pal} <= data[6:0];
						2: begin
							attr_div_xy <= data[4:0];
							attr_div_set <= 1'b1;
						end
					endcase
				end
				CMD_ATTR_CHR: begin
					if (!packet_cnt) begin
						case (byte_cnt)
							1: attr_chr_data_x <= data[4:0];
							2: attr_chr_data_offset <= 5'd20 * data[4:0];
							3: attr_chr_len[7:0] <= data;
							4: attr_chr_len[8] <= data[0];
							5: begin
								attr_chr_dir <= data[0];
								data_set_len <= attr_chr_len;
								data_set_cnt <= 0;
								attr_chr_start <= 1'b1;
							end
						endcase
					end

					if (|data_set_len && data_set_cnt < data_set_len) begin
						attr_chr_data <= data;
						attr_chr_set <= 1'b1;
						if (|data_set_cnt) attr_chr_start <= 0;
						data_set_cnt <= data_set_cnt + 9'd4;
						if (data_set_cnt + 9'd4 >= data_set_len) begin
							data_set_len <= 0;
						end
					end
				end
				CMD_MASK_EN: begin
					if (byte_cnt == 5'd1) begin
						mask_en <= data[1:0];
					end
				end
			endcase

			// End of packet
			if (&byte_cnt) begin
				packet_cnt <= packet_cnt + 1'b1;
				if (packet_cnt + 1'b1 >= length) begin
					packet_cnt <= 0;
					packet_end <= 1'b1;
					data_set_len <= 0;
				end
			end
		end
	end

end


/*
  Lower 4 bits of FF00
  0Fh  Joypad 1
  0Eh  Joypad 2
  0Dh  Joypad 3
  0Ch  Joypad 4

  Setting P15 & P14 to high will decrement the joypad id if multiplayer
  is enabled with MLT_REQ.

  2 player: 0F,0E. 4 player: 0F,0E,0D,0C
  Normal Gameboy or Super Gameboy with multiplayer disabled will always return 0F.
*/

reg [1:0] joypad_id;
reg joypad_id_out;
reg joylock;
always @(posedge clk_sys) begin
	if (reset) begin
		joylock <= 0;
		joypad_id_out <= 0;
		joypad_id <= 0;
	end else if (ce) begin

		if (sgb_en & ~joylock & (~old_p15 | ~old_p14) & p15 & p14) begin
			joylock <= 1'b1;
			joypad_id_out <= 1'b1;
			joypad_id <= (joypad_id - 1'b1) | ~mlt_ctrl;
		end

		if (old_p15 & ~p15 & p14) begin
			joylock <= ~joylock;
		end

		if (~p15 | ~p14) begin
			joypad_id_out <= 0;
		end
	end

end

assign joy_do = joypad_id_out ? {2'b11,joypad_id} : joy_data;

wire [3:0] joy_dir     = ~{ joystick[2], joystick[3], joystick[1], joystick[0] } | {4{p14}};
wire [3:0] joy_buttons = ~{ joystick[7], joystick[6], joystick[5], joystick[4] } | {4{p15}};
wire [3:0] joy_data = joy_dir & joy_buttons;

wire [7:0] joystick =
				(~sgb_en | ~mlt_ctrl[0]) ? (joystick_0 | joystick_1) :
				(joypad_id == 2'b11) ? joystick_0 :
				(joypad_id == 2'b10) ? joystick_1 :
				(joypad_id == 2'b01) ? joystick_2 :
				                       joystick_3;

wire lcd_off = !lcd_on || (lcd_mode == 2'd01);
reg old_lcd_off;

reg [7:0] tile_cnt;
reg trn_en, trn_wait, frame_end;
reg [7:0] pix_x, pix_y;
reg [8:0] tile_offset;
reg [6:0] trn_data_h, trn_data_l;
reg output_border = 0;

wire [8:0] tile_number = {tile_offset+pix_x[7:3]};

wire [13:0] pixel_wr_addr = {tile_number[7:0], pix_y[2:0],pix_x[2:0]};

// Convert 2x 2bpp tiles to 1x 4bpp tile for border output
wire [13:0] tile_addr = {tile_number[7:1], pix_y[2:0],pix_x[2:0], tile_number[0]};

wire [15:0] trn_data = {trn_data_h,lcd_data[1],trn_data_l,lcd_data[0]};


always @(posedge clk_sys) begin
	if (ce) begin
		frame_end <= 0;

		old_lcd_off <= lcd_off;
		if(~old_lcd_off & lcd_off) begin
			trn_en <= 0;
			pix_x <= 0;
			pix_y <= 0;
			tile_offset <= 0;
			frame_end <= 1'b1;
		end

		if(lcd_clkena & ~lcd_off) begin
			pix_x <= pix_x + 1'b1;
			if (pix_x == 8'd159) begin
				pix_x <= 0;
				pix_y <= pix_y + 1'b1;
				if(&pix_y[2:0]) tile_offset <= tile_offset + 9'd20;
			end

			if (trn_en) begin
				// HLHLHLHLHLHLHLHL -> HHHHHHHH LLLLLLLL
				trn_data_h <= {trn_data_h[5:0],lcd_data[1]};
				trn_data_l <= {trn_data_l[5:0],lcd_data[0]};
			end

			if (pix_x == 8'd159 && pix_y == 8'd103) begin // 256 tiles
				trn_en <= 0;
				if (trn_en && cmd == CMD_PCT_TRN) output_border <= 1'b1;
			end
		end

		// Wait until start of frame
		if (trn_start) trn_wait <= 1'b1;

		if (old_lcd_off & ~lcd_off) begin
			trn_wait <= 0;
			if (trn_wait) begin
				trn_en <= 1'b1;
				if (cmd == CMD_CHR_TRN) output_border <= 0;
			end
		end

	end

end


(* ramstyle="no_rw_check" *) reg [15:0] tile_map_ram[32*28];
(* ramstyle="no_rw_check" *) reg [14:0] tile_pal_ram[4*16];
(* ramstyle="no_rw_check" *) reg [14:0] sys_pal_ram[512*4];
(* ramstyle="no_rw_check" *) reg [15:0] attr_files_ram[45*45];

wire trn_data_wr = (lcd_clkena && trn_en && &pix_x[2:0] && !tile_number[8]);

always @(posedge clk_sys) begin
	if (ce) begin

		if (trn_data_wr) begin
			// PCT_TRN Tile 0-111
			if (cmd == CMD_PCT_TRN && pixel_wr_addr[13:6] < 8'd112) begin
				tile_map_ram[pixel_wr_addr[12:3]] <= trn_data;
			end

			// PCT_TRN Tile 128-135
			if (cmd == CMD_PCT_TRN && pixel_wr_addr[13:9] == 6'b10000) begin
				tile_pal_ram[pixel_wr_addr[8:3]] <= trn_data[14:0];
			end

			if (cmd == CMD_PAL_TRN) begin
				sys_pal_ram[pixel_wr_addr[13:3]] <= trn_data[14:0];
			end

			if (cmd == CMD_ATTR_TRN && pixel_wr_addr[13:3] < 11'd2025) begin
				attr_files_ram[pixel_wr_addr[13:3]] <= {trn_data[7:0],trn_data[15:8]};
			end
		end

	end

end

dpram_dif #(15,2, 14,4) tile_ram (
	.clock    ( clk_vid ),

	.address_a  ( {char_trn_tile,tile_addr} ),
	.wren_a     ( lcd_clkena && trn_en && cmd == CMD_CHR_TRN),
	.data_a     ( lcd_data ),
	.q_a        (),

	.address_b (tile_rd_addr),
	.wren_b (1'b0),
	.data_b (),
	.q_b (tile_data)
);

reg [14:0] sys_pal_data, pal_wr_data;
reg [1:0] pal_wr_no, pal_wr_col_no;
reg [0:59] palette[4];
reg pal_set_wait, pal_set_busy, pal_wr, pal_cancel_mask, pal_clear;
reg [3:0] pal_set_cnt, pal_set_cnt_r;
reg [10:0] sys_pal_ram_addr;
reg output_sgb_pal;

always @(posedge clk_sys) begin
	if (reset) begin
		output_sgb_pal <= 0;
		pal_set_busy <= 0;
		pal_set_wait <= 0;
		pal_clear <= 1'b1;
		pal_set_cnt <= 0;
	end else if (ce) begin

		pal_cancel_mask <= 0;
		pal_wr <= 0;

		// PAL_SET
		if (pal_set) pal_set_wait <= 1'b1;

		if (pal_set_wait & frame_end) begin
			pal_set_wait <= 0;
			pal_set_busy <= 1'b1;
			pal_set_cnt <= 0;
		end

		sys_pal_data <= sys_pal_ram[{sys_pal_no[pal_set_cnt[3:2]], pal_set_cnt[1:0]}];

		if (pal_set_busy) begin

			pal_set_cnt <= pal_set_cnt + 1'b1;
			pal_set_cnt_r <= pal_set_cnt;

			if (&pal_set_cnt_r) begin
				pal_set_busy <= 0;
				output_sgb_pal <= 1'b1;
				if (cancel_mask) pal_cancel_mask <= 1'b1;
			end

			pal_wr <= 1'b1;
			pal_wr_data <= sys_pal_data;
			{pal_wr_no, pal_wr_col_no} <= pal_set_cnt_r;

		end

		// PAL01,PAL23,PAL03,PAL12
		if (pal0123_wr) begin
			output_sgb_pal <= 1'b1;

			pal_wr <= 1'b1;
			pal_wr_data <= pal_color;
			pal_wr_no <= pal0123_no;
			pal_wr_col_no <= pal0123_col_no;
		end

		if (pal_clear) begin
			pal_set_cnt <= pal_set_cnt + 1'b1;

			pal_wr <= 1'b1;
			pal_wr_data <= 0;
			{pal_wr_no, pal_wr_col_no} <= pal_set_cnt;

			if (&pal_set_cnt) pal_clear <= 0;
		end

		if (pal_wr) begin
			palette[pal_wr_no][pal_wr_col_no*15 +: 15] <= pal_wr_data;
		end

	end

end

reg [15:0] attr_file_data;
reg [0:719] attr_file;

reg attr_set_busy, attr_blk_busy, attr_lin_busy, attr_div_busy, attr_chr_busy;
reg [8:0] attr_set_cnt, attr_set_cnt_r;
reg [10:0] attr_file_ram_addr;
reg [5:0] attr_file_idx;
reg attr_cancel_mask;

reg [8:0] attr_tile_no, attr_tile_no_wr;
reg [4:0] attr_tile_cnt_x, attr_tile_cnt_y;
reg [1:0] attr_file_pal_wr;
reg attr_file_wr;

reg [8:0] attr_chr_pal_cnt;
reg [4:0] attr_chr_x;
reg [8:0] attr_chr_offset;

reg attr_clear;
always @(posedge clk_sys) begin
	if (reset) begin
		attr_set_busy <= 0;
		attr_blk_busy <= 0;
		attr_lin_busy <= 0;
		attr_div_busy <= 0;
		attr_chr_busy <= 0;
		attr_clear <= 1'b1;
		attr_set_cnt <= 0;
	end else if (ce) begin

		attr_cancel_mask <= 0;
		attr_file_wr <= 0;

		// ATTR_SET
		if (attr_set) begin
			attr_set_busy <= 1'b1;
			attr_set_cnt <= 0;
			attr_file_ram_addr <= 0;
			attr_file_idx <= 0;
		end

		attr_file_data <= attr_files_ram[attr_file_ram_addr];

		if (attr_set_busy) begin

			if (attr_file_idx != attr_file_no) begin
				attr_file_idx <= attr_file_idx + 1'b1;
				attr_file_ram_addr <= attr_file_ram_addr + 11'd45;
			end else begin
				attr_set_cnt <= attr_set_cnt + 1'b1;
				attr_set_cnt_r <= attr_set_cnt;

				if (&attr_set_cnt[2:0]) attr_file_ram_addr <= attr_file_ram_addr + 1'b1;

				attr_file_pal_wr <= attr_file_data[~attr_set_cnt_r[2:0]*2 +: 2];
				attr_tile_no_wr <= attr_set_cnt_r;
				attr_file_wr <= 1'b1;
			end

			if (attr_file_idx == 6'd45 || attr_set_cnt_r == 9'd359) begin
				attr_set_busy <= 0;
				if (cancel_mask) attr_cancel_mask <= 1'b1;
			end

		end

		if (attr_blk_set) attr_blk_busy <= 1'b1;
		if (attr_lin_set) attr_lin_busy <= 1'b1;
		if (attr_div_set) attr_div_busy <= 1'b1;

		if (attr_blk_set | attr_lin_set | attr_div_set) begin
			attr_tile_no <= 0;
			attr_tile_cnt_x <= 0;
			attr_tile_cnt_y <= 0;
		end

		if (attr_blk_busy | attr_lin_busy | attr_div_busy) begin
			attr_tile_no <= attr_tile_no + 1'b1;
			attr_tile_cnt_x <= attr_tile_cnt_x + 1'b1;
			attr_tile_no_wr <= attr_tile_no;

			if(attr_tile_cnt_x == 5'd19) begin
				attr_tile_cnt_x <= 0;
				attr_tile_cnt_y <= attr_tile_cnt_y + 1'b1;
				if (attr_tile_cnt_y == 5'd17) begin
					attr_blk_busy <= 0;
					attr_lin_busy <= 0;
					attr_div_busy <= 0;
				end
			end
		 end

		 // ATTR_BLK
		 if (attr_blk_busy) begin
			if (attr_tile_cnt_x > attr_blk_x1 && attr_tile_cnt_x < attr_blk_x2
				&& attr_tile_cnt_y > attr_blk_y1 && attr_tile_cnt_y < attr_blk_y2) begin
				// inside
				if (attr_blk_ctrl[0]) begin
					attr_file_pal_wr <= attr_blk_pal[1:0];
					attr_file_wr <= 1'b1;
				end
			end else if (attr_tile_cnt_x < attr_blk_x1 || attr_tile_cnt_x > attr_blk_x2
				|| attr_tile_cnt_y < attr_blk_y1 || attr_tile_cnt_y > attr_blk_y2) begin
				// outside
				if (attr_blk_ctrl[2]) begin
					attr_file_pal_wr <= attr_blk_pal[5:4];
					attr_file_wr <= 1'b1;
				end
			end else begin
				// on border
				// "Exception: When changing only the Inside or Outside, then the
				// Surrounding line becomes automatically changed to same color."
				casez (attr_blk_ctrl)
					3'b001: begin
						attr_file_pal_wr <= attr_blk_pal[1:0];
						attr_file_wr <= 1'b1;
					end
					3'b100: begin
						attr_file_pal_wr <= attr_blk_pal[5:4];
						attr_file_wr <= 1'b1;
					end
					3'b?1?:  begin
						attr_file_pal_wr <= attr_blk_pal[3:2];
						attr_file_wr <= 1'b1;
					end
				endcase
			end
		end

		// ATTR_LIN
		if (attr_lin_busy) begin
			if ( (attr_lin_data[7] && attr_tile_cnt_y == attr_lin_data[4:0])
				  || (~attr_lin_data[7] && attr_tile_cnt_x == attr_lin_data[4:0]) ) begin
				attr_file_wr <= 1'b1;
				attr_file_pal_wr <= attr_lin_data[6:5];
			end
		end

		// ATTR_DIV
		if (attr_div_busy) begin
			if ( (~attr_div_hv && attr_tile_cnt_x > attr_div_xy) || (attr_div_hv && attr_tile_cnt_y > attr_div_xy) ) begin
				// below/right
				attr_file_pal_wr <= attr_div_pal[1:0];
			end else if ( (~attr_div_hv && attr_tile_cnt_x < attr_div_xy) || (attr_div_hv && attr_tile_cnt_y < attr_div_xy) ) begin
				// above/left
				attr_file_pal_wr <= attr_div_pal[3:2];
			end else begin
				// on divider line
				attr_file_pal_wr <= attr_div_pal[5:4];
			end
			attr_file_wr <= 1'b1;
		end

		// ATTR_CHR
		if (attr_chr_set) begin
			attr_chr_busy <= 1'b1;
			if (attr_chr_start) begin
				attr_chr_pal_cnt <= 0;
				attr_chr_x <= attr_chr_data_x;
				attr_chr_offset <= attr_chr_data_offset;
			end
		end

		if (attr_chr_busy) begin
			attr_chr_pal_cnt <= attr_chr_pal_cnt + 1'b1;
			if (&attr_chr_pal_cnt[1:0] || attr_chr_pal_cnt+1'b1 == attr_chr_len) attr_chr_busy <= 0;

			if (attr_chr_dir) begin
				attr_chr_offset <= attr_chr_offset + 9'd20;
				if(attr_chr_offset == 9'd340) begin
					attr_chr_offset <= 0;
					attr_chr_x <= attr_chr_x + 1'b1;
					if (attr_chr_x == 5'd19) attr_chr_x <= 0;
				end
			end

			if (~attr_chr_dir) begin
				attr_chr_x <= attr_chr_x + 1'b1;
				if (attr_chr_x == 5'd19) begin
					attr_chr_x <= 0;
					attr_chr_offset <= attr_chr_offset + 9'd20;
					if (attr_chr_offset == 9'd340) attr_chr_offset <= 0;
				end
			end

			attr_tile_no_wr <= attr_chr_offset + attr_chr_x;
			case (attr_chr_pal_cnt[1:0])
				0: attr_file_pal_wr <= attr_chr_data[7:6];
				1: attr_file_pal_wr <= attr_chr_data[5:4];
				2: attr_file_pal_wr <= attr_chr_data[3:2];
				3: attr_file_pal_wr <= attr_chr_data[1:0];
			endcase
			attr_file_wr <= 1'b1;

		end

		if (attr_clear) begin
			attr_set_cnt <= attr_set_cnt + 1'b1;

			attr_file_pal_wr <= 0;
			attr_tile_no_wr <= attr_set_cnt;
			attr_file_wr <= 1'b1;

			if (attr_set_cnt == 9'd359) attr_clear <= 0;
		end

		if (attr_file_wr) begin
			attr_file[attr_tile_no_wr*2 +: 2] <= attr_file_pal_wr;
		end

	end
end

reg [15:0] bg_map_data;
reg [1:0] bg_pal_no;
reg [13:0] tile_rd_addr;
reg [3:0] tile_data;
reg [14:0] pal_data;
reg pix_visible;

wire [8:0] bg_vcnt = v_cnt >= 9'd65 ? (v_cnt-9'd65) : (v_cnt+9'd264-9'd65);

reg [8:0] h_cnt_r, v_cnt_r;
// border output
always @(posedge clk_vid) begin
	if (ce_pix) begin

		bg_map_data <= tile_map_ram[{bg_vcnt[7:3],h_cnt[7:3]}];
		h_cnt_r <= h_cnt;
		v_cnt_r <= bg_vcnt;

		bg_pal_no <= bg_map_data[11:10];
		tile_rd_addr <= {bg_map_data[7:0],bg_map_data[15] ? ~v_cnt_r[2:0] : v_cnt_r[2:0],bg_map_data[14] ? ~h_cnt_r[2:0] : h_cnt_r[2:0]};

		pix_visible <= |tile_data;
		pal_data <= |tile_data ? tile_pal_ram[{bg_pal_no, tile_data}] : palette[0][0:14];

		sgb_border_pix <= output_border ? {pix_visible, pal_data} : 16'd0;

	end

end


reg [14:0] lcd_data_r;
reg [1:0] pal_no;
reg lcd_clkena_r, lcd_on_r;
reg [1:0] lcd_mode_r;
wire [1:0] lcd_data_2 = lcd_data_r[1:0];
// Lcd pixel output
always @(posedge clk_sys) begin
	if (ce) begin

		pal_no <= attr_file[tile_number*2 +: 2];
		lcd_data_r <= lcd_data;
		lcd_clkena_r <= lcd_clkena;
		lcd_mode_r <= lcd_mode;
		lcd_on_r <= lcd_on;

		if (~sgb_en | ((~output_sgb_pal | tint) & !mask_en) ) begin
			sgb_lcd_data <= lcd_data_r;
		end else if (mask_en == 2'd2) begin
			sgb_lcd_data <= 0;
		end else if (!lcd_data_2 || mask_en == 2'd3) begin
			sgb_lcd_data <= palette[0][0:14];
		end else begin
			sgb_lcd_data <= palette[pal_no][lcd_data_2*15 +:15];
		end

		sgb_lcd_clkena <= (mask_en != 2'd1) ? lcd_clkena_r : 1'b0;
		sgb_lcd_mode <= lcd_mode_r;
		sgb_lcd_on <= lcd_on_r;
		sgb_pal_en <= sgb_en & (output_sgb_pal || |mask_en);
	end

end

endmodule