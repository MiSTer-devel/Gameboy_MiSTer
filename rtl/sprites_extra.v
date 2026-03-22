module sprites_extra (
	input clk,
	input ce,

	input extra_spr_en,

	input oam_eval_end,
	input oam_eval_clk,
	input oam_eval_reset,

	input size16,

	input [5:0] oam_index,
	input [3:0] sprite_cnt,

	input [7:0] oam_l_q,
	input [7:0] oam_h_q,

	input [7:0] v_cnt,
	input [7:0] h_cnt,

	input extra_wait,
	output oam_eval_extra,
	output [7:1] oam_extra_addr,

	output [7:0] spr_fetch_attr,

	output tile_fetch,
	output [11:0] tile_addr,
	input [7:0] tile_data_in,

	output spr_found,
	output [7:0] spr_tile0,
	output [7:0] spr_tile1,
	output [2:0] spr_cgb_pal,
	output [3:0] spr_index,
	output spr_pal,
	output spr_prio
);

// Maximum extra sprites is 6 currently because sprite index in the pixel shifters is 4 bits.
localparam SPRITES_PER_LINE = 10;
localparam SPRITES_EXTRA    =  6;

wire [SPRITES_EXTRA-1:0] sprite_x_matches;

reg [7:0] sprite_x;
reg [3:0] sprite_y;

reg [5:0] extra_oam_index;
reg [3:0] new_sprite_x_index;
reg [4:0] extra_sprite_index;

reg oam_attr_fetch;

reg [7:0] tile_index;
reg [7:0] tile_y;
reg [3:0] tile_row;
reg [7:0] tile_attr;

reg extra_waiting;
wire extra_pause = extra_wait | extra_waiting;

wire oam_extra_start = extra_spr_en & (sprite_cnt == SPRITES_PER_LINE);

assign oam_eval_extra = oam_extra_start & ~oam_eval_end & ~extra_pause;
assign oam_extra_addr = { extra_oam_index, oam_attr_fetch };

assign spr_fetch_attr = tile_attr;

wire [7:0] spr_height = size16 ? 8'd16 : 8'd8;
wire sprite_on_line = (v_cnt + 8'd16 >= oam_l_q) && (v_cnt + 8'd16 < oam_l_q + spr_height);

reg tile_fetching;
reg [3:0] tile_fetch_x_index;
reg [3:0] tile_fetch_sprite_index;
reg [1:0] tile_fetch_cnt;
reg tile1_fetch;

wire tile_save;
reg save_x;

always @(posedge clk) begin
	if (ce) begin
		if (~oam_extra_start) begin
			extra_waiting <= 0;
		end else if (oam_eval_clk) begin
			extra_waiting <= extra_wait;
		end
	end
end

always @(posedge clk) begin
	if (ce) begin

		save_x <= 0;

		if (~oam_extra_start) begin
			extra_oam_index <= oam_index;
			oam_attr_fetch <= 0;
			new_sprite_x_index <= 0;
			extra_sprite_index <= SPRITES_PER_LINE[4:0];
		end else begin
			if (oam_eval_clk & ~extra_pause) begin
				if (~oam_attr_fetch) begin
					if (sprite_on_line) begin
						sprite_x <= oam_h_q;
						sprite_y <= v_cnt[3:0] - oam_l_q[3:0];
						oam_attr_fetch <= 1;
					end else begin
						extra_oam_index <= extra_oam_index + 1'b1;
					end
				end else begin // Fetched attributes
					extra_oam_index <= extra_oam_index + 1'b1;
					oam_attr_fetch <= 0;

					tile_index <= oam_l_q;
					tile_attr <= oam_h_q;
					tile_row <= oam_h_q[6] ? ~sprite_y : sprite_y;
					tile_fetch_sprite_index <= extra_sprite_index[3:0];

					if (extra_sprite_index != SPRITES_PER_LINE+SPRITES_EXTRA) begin
						if (~spr_found) begin // Skip sprite if this X position was already found
							tile_fetch_x_index <= new_sprite_x_index;
							save_x <= 1; // Store X position and start tile fetch

							new_sprite_x_index <= new_sprite_x_index + 1'b1;
						end

						extra_sprite_index <= extra_sprite_index + 1'b1;
					end
				end
			end
		end
	end
end

assign tile_addr[11:5] = tile_index[7:1];
assign tile_addr[4:1] = size16 ? tile_row : { tile_index[0],tile_row[2:0] };
assign tile_addr[0] = tile1_fetch;

assign tile_fetch = (save_x | tile_fetching) & ~extra_pause;
assign tile_save = tile_fetch & oam_eval_clk & tile1_fetch;

reg [7:0] tile_data_0;

always @(posedge clk) begin
	if (ce) begin
		if (oam_eval_reset | oam_eval_end) begin
			tile_fetching <= 0;
			tile1_fetch <= 0;
		end else begin
			if (save_x) begin
				tile_fetching <= 1;
			end

			if (tile_fetch & oam_eval_clk ) begin
				if (~tile1_fetch) begin
					tile_data_0 <= tile_data_in;
				end else begin
					tile_fetching <= 0;
				end
				tile1_fetch <= ~tile1_fetch;
			end
		end
	end
end

wire [7:0] sprite_x_sel = oam_eval_extra ? sprite_x : h_cnt;

genvar j;

generate
	for (j = 0; j < SPRITES_EXTRA; j = j + 1) begin : gen_sprite_extra_store
		sprites_extra_store st (
			.clk        ( clk ),
			.ce         ( ce  ),

			.reset      ( oam_eval_reset ),

			.save_x     ( save_x & (tile_fetch_x_index == (j)) ),
			.xpos       ( sprite_x_sel ),

			.tile_save  ( tile_save & (tile_fetch_x_index == (j)) ),
			.tile0_in   ( tile_data_0 ),
			.tile1_in   ( tile_data_in ),
			.index_in   ( tile_fetch_sprite_index ),
			.cgb_pal_in ( tile_attr[2:0] ),
			.pal_in     ( tile_attr[4]   ),
			.prio_in    ( tile_attr[7]   ),

			.x_match    ( sprite_x_matches[j] ),
			.tile0_o    ( spr_tile0 ),
			.tile1_o    ( spr_tile1 ),
			.pal_o      ( spr_pal ),
			.prio_o     ( spr_prio ),
			.cgb_pal_o  ( spr_cgb_pal ),
			.index_o    ( spr_index )
		);
	end
endgenerate

assign spr_found = |{sprite_x_matches} & extra_spr_en;

endmodule