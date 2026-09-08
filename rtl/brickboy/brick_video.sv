// BrickBoy video: capture the DMG's 2-bit stream and scan it out on the
// BrickBoy raster.
//
// The raster is 896 x 627 at 33.554432 MHz. That is exactly 561,792 clocks -
// one GB frame (70224 cpu cycles x 8) - so the scanout locks to the emulated
// frame with no drift and no resampling: 59.7275 Hz on both sides.
//
// Geometry (output pixels):
//   active   640 x 576   the game area, 1 GB dot = 4x4
//   blanking 256 x 51
//
// The module margin (exposed reflector + printed mask) is NOT part of the
// active area. This matches brickboy's own default, Fill mode: the game runs
// edge to edge and the module border falls off-screen - on the Pocket, the
// bezel plays that part. Shadows cast by the outermost dots get clipped at the
// edge, exactly as they do in brickboy's Fill mode.
//
// Phase: h/v reset on the GB's vsync (start of vblank). The GB then spends 10
// lines of vblank before drawing row 0, while the raster spends V_BEG+16 lines
// before reading it, and the arithmetic works out so the reader is always at
// least ~2.4 GB lines behind the writer and never a whole frame behind - i.e.
// tear-free with about one frame of latency, the same discipline the upstream
// lcd.v used. Fast-forward breaks the lockstep and may roll; normal play never
// does.
//
// M4: the scanout no longer reads shades - it reads rows that brick_color has
// pushed through the brickboy colour stage (palette, bleed, density, offTint,
// crosstalk, gamma, saturation, warm, tone, black lift), processed one native
// row ahead of display into a pair of RGB888 line buffers.

module brick_video #(parameter ENABLE_PERSISTENCE = 1, parameter ENABLE_VINEGAR = 1) (
	input  wire        clk_sys,      // 33.554432 MHz; also the pixel clock domain
	input  wire        ce,           // 4.194304 MHz strobe (cpu clock enable)

	input  wire        lcd_clkena,
	input  wire [1:0]  lcd_data,
	input  wire [1:0]  lcd_mode,     // 01 = vblank
	input  wire        lcd_on,
	input  wire        lcd_vsync,

	input  wire [2:0]  set_bright,   // panel trim from interact.json
	input  wire [2:0]  set_warm,
	input  wire [2:0]  set_ink_r, set_ink_g, set_ink_b,
	input  wire [2:0]  set_offtint,
	input  wire [2:0]  set_refsat,
	input  wire [2:0]  set_deadline,
	input  wire [2:0]  set_grain,
	input  wire        set_real,     // 0 = nostalgia palette, 1 = measured
	input  wire [1:0]  set_vinegar,  // original screenRot sampled at .25/.50/1.0
	input  wire        set_rot_blob, // original rotMode: centre or blobs
	input  wire [2:0]  set_rot_seed, // original unit seed, selectable blob layout
	input  wire [1:0]  set_flicker,  // experimental dead-electrode instability
	input  wire [1:0]  set_grid,
	input  wire [1:0]  set_shadow,
	input  wire [1:0]  set_ghost,
	input  wire [1:0]  set_gradient,
	input  wire [1:0]  set_vignette,
	input  wire [1:0]  set_matte,
	input  wire [1:0]  set_fill,
	input  wire [1:0]  set_gap,
	input  wire [1:0]  set_gate,
	input  wire [1:0]  set_dimming,
	input  wire [1:0]  set_frontlight,
	input  wire [1:0]  set_backlight,
	input  wire [1:0]  set_contrast_fade,
	input  wire [1:0]  set_dust,
	input  wire [1:0]  set_brightness,
	input  wire [1:0]  set_contrast,
	input  wire [1:0]  set_saturation,
	input  wire [1:0]  set_gamma,
	input  wire [1:0]  set_blacklift,
	input  wire [1:0]  set_density,
	input  wire [1:0]  set_bleed,
	input  wire [1:0]  set_xtalk,
	input  wire [1:0]  set_xtnoise,
	input  wire [1:0]  set_xtedge,
	input  wire [1:0]  set_cold,
	input  wire [1:0]  set_depth,
	input  wire [1:0]  set_blur,
	input  wire [1:0]  set_ghost_gamma,
	input  wire [1:0]  set_dead_edge,
	input  wire [1:0]  set_dead_lit,
	input  wire [1:0]  set_dead_rows,

	output reg         hs,
	output reg         vs,
	output reg         de,
	output wire        hblank,
	output wire        vblank,
	output reg  [23:0] rgb
);

// ---------------------------------------------------------------- capture ---
// Same discipline as upstream lcd.v: a write pointer that advances on every
// lcd_clkena pixel and resets on any edge of "lcd off" (off or vblank).

localparam FB_SIZE = 160 * 144;

reg [1:0]  fb[FB_SIZE];
reg [14:0] wptr;
reg        lcd_off_r;

// read port for the colour stage
wire [14:0] col_fb_addr;
reg  [1:0]  col_fb_q;
always @(posedge clk_sys) col_fb_q <= fb[col_fb_addr];

wire lcd_off = ~lcd_on || (lcd_mode == 2'd1);

always @(posedge clk_sys) begin
	if (ce) begin
		if (lcd_clkena) begin
			fb[wptr] <= lcd_data;
			wptr     <= (wptr == FB_SIZE - 1) ? 15'd0 : wptr + 1'd1;
		end
		lcd_off_r <= lcd_off;
		if (lcd_off_r ^ lcd_off) wptr <= 0;
	end
end

// ----------------------------------------------------------------- raster ---

localparam H_TOT = 896, V_TOT = 627;
localparam [9:0] GX0 = 208, GY0 = 35;       // game area top-left

// ------------------------------------------------------------ colour stage ---
// Row triggers: row 0 is prepared two raster lines before the game area, and
// each subsequent row on the first raster line of the row before it - four
// lines (3584 clocks) ahead of when the scanout needs it, against a stage that
// takes ~490.

wire [7:0] disp_row = (v - GY0) >> 2;

reg [9:0] h, v;
reg       vsync_r;
reg [7:0] frame_phase = 8'd0;

assign hblank = (h < GX0) || (h >= GX0 + 640);
assign vblank = (v < GY0) || (v >= GY0 + 576);

always @(posedge clk_sys) begin
	vsync_r <= lcd_vsync;
	if (~vsync_r & lcd_vsync) begin
		h <= 0;
		v <= 0;
		frame_phase <= frame_phase + 1'd1;
	end else if (h == H_TOT - 1) begin
		h <= 0;
		v <= (v == V_TOT - 1) ? 10'd0 : v + 1'd1;
	end else begin
		h <= h + 1'd1;
	end
end

wire start_frame = (v == GY0 - 2) && (h == 0);
wire row_tick    = (v >= GY0) && (v < GY0 + 572) && (((v - GY0) & 10'd3) == 0) && (h == 0);
// The active area is done: the colour stage is idle from here until the next
// frame's start_frame, which is where its upward-crosstalk pre-pass runs.
wire up_tick     = (v == GY0 + 576) && (h == 0);

wire [7:0]  cc_x, cc_row;
wire [23:0] cc_rgb;
wire        cc_v, cc_bank;

brick_color color (
	.clk         ( clk_sys      ),
	.start_frame ( start_frame  ),
	.row_tick    ( row_tick     ),
	.up_tick     ( up_tick      ),
	.row_disp    ( disp_row     ),
	.set_offtint ( set_offtint  ),
	.set_real    ( set_real     ),
	.set_brightness(set_brightness),
	.set_contrast( set_contrast ),
	.set_saturation(set_saturation),
	.set_gamma   ( set_gamma    ),
	.set_blacklift(set_blacklift),
	.set_density ( set_density  ),
	.set_bleed   ( set_bleed    ),
	.set_xtalk   ( set_xtalk    ),
	.set_xtnoise ( set_xtnoise  ),
	.set_xtedge  ( set_xtedge   ),
	.set_cold    ( set_cold     ),
	.fb_addr     ( col_fb_addr  ),
	.fb_q        ( col_fb_q     ),
	.lb_waddr    ( cc_x         ),
	.lb_wdata    ( cc_rgb       ),
	.lb_wren     ( cc_v         ),
	.lb_wbank    ( cc_bank      ),
	.lb_wrow     ( cc_row       )
);

// Persistence: the analog cell state, read-modify-written once per native
// pixel per frame. Adds 7 cycles, well inside the 4-line lead.
wire [7:0]  gh_x;
wire [23:0] gh_rgb;
wire        gh_v;

generate if (ENABLE_PERSISTENCE) begin : with_persistence
brick_ghost ghost (
	.clk     ( clk_sys ),
	.in_v    ( cc_v    ),
	.in_row  ( cc_row  ),
	.in_x    ( cc_x    ),
	.in_rgb  ( cc_rgb  ),
	.strength( set_ghost ),
	.gate   ( set_gate ),
	.gamma  ( set_ghost_gamma ),
	.cold   ( set_cold ),
	.out_v   ( gh_v    ),
	.out_x   ( gh_x    ),
	.out_rgb ( gh_rgb  )
);

end else begin : without_persistence
 // Keep the original seven-cycle interface latency without a frame history.
 reg [23:0] pixels[0:6];
 reg [7:0] columns[0:6];
 reg [6:0] valid = 0;
 integer stage;
 always @(posedge clk_sys) begin
  pixels[0] <= cc_rgb; columns[0] <= cc_x; valid[0] <= cc_v;
  for (stage=1; stage<7; stage=stage+1) begin
   pixels[stage] <= pixels[stage-1];
   columns[stage] <= columns[stage-1];
   valid[stage] <= valid[stage-1];
  end
 end
 assign gh_rgb = pixels[6];
 assign gh_x = columns[6];
 assign gh_v = valid[6];
end endgenerate

// Which line-buffer bank the ghost's output belongs to, delayed to match its
// pipeline. Eight banks, indexed by native row mod 8: the drop shadow reaches
// three rows back (see below), and the colour stage is already a row ahead.
reg [2:0] wrow_dly[0:6];
integer wi;
always @(posedge clk_sys) begin
	wrow_dly[0] <= cc_row[2:0];
	for (wi = 1; wi < 7; wi = wi + 1) wrow_dly[wi] <= wrow_dly[wi-1];
end
wire [2:0] lb_wbank = wrow_dly[6];

// The scanout only ever reads the CURRENT row in colour - the shadow casters
// come out of the narrow darkness buffer below - so one copy is enough. The
// second copy this used to keep, purely so the row above could be read for the
// shadow, is gone.
reg [23:0] lb_a[0:2047];
always @(posedge clk_sys) if (gh_v) lb_a[{lb_wbank, gh_x}] <= gh_rgb;

// Shadow casters. The shader walks back along the light direction (upper-left)
// by shadowOffset 1.35 dots for the umbra and 2.4x that - 3.24 dots - for the
// penumbra, and reads the PRE-GRID image there. Along a 45-degree diagonal
// those land 0.95 and 2.29 dots back on each axis, so the casters are the cells
// at (-1,-1) and, for the far layer, the mean of (-2,-2) and (-3,-3).
//
// Only the caster's DARKNESS is needed, so this is a native-resolution 8-bit
// buffer rather than another 24-bit line store: 8 rows of 160, one M10K. The
// three reads are time-multiplexed across the four clocks of a cell, which is
// why one port suffices, and they are issued a cell early so the values stand
// still for the whole of the cell that uses them.
function automatic [7:0] luma8(input [23:0] c);
	reg [16:0] t;
	begin
		t = 17'd77*c[23:16] + 17'd150*c[15:8] + 17'd29*c[7:0];
		luma8 = t[15:8];
	end
endfunction

reg [7:0] dkbuf[0:2047];
always @(posedge clk_sys) if (gh_v)
	dkbuf[{lb_wbank, gh_x}] <= 8'd255 - luma8(gh_rgb);

// Fetch pipeline: the line buffer has a registered address and the colour is
// registered once more, so coordinates are taken 2 clocks ahead. The lookahead
// only wraps a line inside blanking (H_BEG >= 2), where it does not matter.

wire [9:0] h_pre = (h >= H_TOT - 2) ? h - (H_TOT - 2) : h + 10'd2;

wire       pre_game = (h_pre >= GX0) && (h_pre < GX0 + 640) &&
                      (v >= GY0)     && (v < GY0 + 576);

wire [7:0] nx = (h_pre - GX0) >> 2;         // native dot 0..159
wire [7:0] ny = (v - GY0) >> 2;             // native dot 0..143

reg [23:0] q_c;
reg [1:0]  sx1, sy1;
reg        p1_game;

wire [1:0] sx_now = (h_pre - GX0) & 2'd3;

// Caster reads for the NEXT cell, one per sub-pixel phase. Outside the dot
// field there is no element to cast, so those taps read as fully light - the
// same thing the shader gets, where the colour pass writes the bare panel
// colour beyond the active area.
wire [7:0] nxn = nx + 8'd1;
reg  [10:0] dk_addr;
reg         dk_ok;
always @(*) begin
	case (sx_now)
		2'd0: begin dk_addr = {ny[2:0] - 3'd1, nxn - 8'd1}; dk_ok = (ny >= 8'd1) && (nxn >= 8'd1); end
		2'd1: begin dk_addr = {ny[2:0] - 3'd2, nxn - 8'd2}; dk_ok = (ny >= 8'd2) && (nxn >= 8'd2); end
		2'd2: begin dk_addr = {ny[2:0] - 3'd3, nxn - 8'd3}; dk_ok = (ny >= 8'd3) && (nxn >= 8'd3); end
		default: begin dk_addr = {ny[2:0] - 3'd4, nxn - 8'd4}; dk_ok = (ny >= 8'd4) && (nxn >= 8'd4); end
	endcase
end

reg [7:0] dk_q;
reg       dk_ok1;
reg [1:0] sx_r;
always @(posedge clk_sys) begin
	dk_q   <= dkbuf[dk_addr];
	dk_ok1 <= dk_ok;
	sx_r   <= sx_now;
end

wire [7:0] dk_v = dk_ok1 ? dk_q : 8'd0;

reg [7:0] t_near, t_far1, t_far2;
reg [7:0] near_d, far_d;
always @(posedge clk_sys) begin
	case (sx_r)                    // the read issued one clock earlier
		2'd0: t_near <= dk_v;
		2'd1: t_far1 <= dk_v;
		2'd2: t_far2 <= dk_v;
		default: begin
			case (set_depth)
				2'd0: begin near_d <= t_near; far_d <= ({1'b0,t_far1}+{1'b0,t_far2}) >> 1; end
				2'd1: begin near_d <= t_near; far_d <= t_far1; end
				2'd2: begin near_d <= t_far1; far_d <= ({1'b0,t_far2}+{1'b0,dk_v}) >> 1; end
				default: begin near_d <= t_far2; far_d <= dk_v; end
			endcase
		end
	endcase
end

always @(posedge clk_sys) begin
	q_c <= lb_a[{ny[2:0], nx}];
	sx1  <= sx_now;
	sy1  <= (v - GY0) & 2'd3;
	p1_game <= pre_game;
end

// Grain is keyed to the reflector sheet, which sits behind the dot field and is
// not registered to it, so it is addressed in game-area pixels. Outside the game
// area the coordinates run past the baked field, but de is low there.
wire signed [9:0] grain_q;
brick_grain grain_gen (
	.clk  ( clk_sys        ),
	.gx   ( h_pre - GX0[9:0] ),
	.gy   ( v - GY0[9:0]     ),
	.seed ( 8'd7           ),   // dmg.json defects.seed
	.contrast ( set_grain  ),
	.g    ( grain_q        )
);

// Grain contrast, 2 = brickboy's own amplitude.
function automatic [7:0] k_paper_of(input [2:0] i);
	case (i)
		3'd0: k_paper_of = 8'd0;    // off
		3'd1: k_paper_of = 8'd4;
		3'd2: k_paper_of = 8'd8;    // brickboy
		3'd3: k_paper_of = 8'd12;
		3'd4: k_paper_of = 8'd16;
		3'd5: k_paper_of = 8'd24;
		3'd6: k_paper_of = 8'd32;
		3'd7: k_paper_of = 8'd40;
	endcase
endfunction
// brick_grain now carries the contrast knob per band; the paper weight here
// stays at brickboy's 0.03.
wire [7:0] grain_k = 8'd8;

// Dead electrode lines, substituted into the cell before the dot structure -
// see brick_deadline for why that is the right place. Adds 3 cycles, so the
// grid's coordinates need the same delay.
wire [23:0] dl_rgb;
brick_deadline deadline (
	.clk     ( clk_sys      ),
	.sev     ( set_deadline ),
	.flicker ( set_flicker  ),
	.edge_bias(set_dead_edge),
	.lit_ratio(set_dead_lit),
	.row_ratio(set_dead_rows),
	.phase   ( frame_phase  ),
	.nx      ( nx           ),
	.ny      ( ny           ),
	.in_rgb  ( q_c          ),
	.out_rgb ( dl_rgb       )
);

reg [1:0] sx2, sx3, sx4, sy2, sy3, sy4;
reg       p2_game, p3_game, p4_game;
always @(posedge clk_sys) begin
	sx2 <= sx1; sx3 <= sx2; sx4 <= sx3;
	sy2 <= sy1; sy3 <= sy2; sy4 <= sy3;
	p2_game <= p1_game; p3_game <= p2_game; p4_game <= p3_game;
end

wire [23:0] grid_rgb;
brick_grid grid (
	.clk      ( clk_sys  ),
	.cell_rgb ( dl_rgb   ),
	.near_d   ( near_d   ),
	.far_d    ( far_d    ),
	.sx       ( sx4      ),
	.sy       ( sy4      ),
	.grain    ( grain_q  ),
	.grain_k  ( grain_k  ),
	.set_real ( set_real ),
	.set_grid ( set_grid ),
	.set_shadow ( set_shadow ),
	.set_fill ( set_fill ),
	.set_gap ( set_gap ),
	.set_blur ( set_blur ),
	.out_rgb  ( grid_rgb )
);

// Screen-space finish: the reflection gradient, the corner vignette and the
// matte grain, laid over the finished panel exactly as brickboy's present pass
// does. Adds 4 cycles.
//
// The coordinates come straight off h_pre rather than being delayed to match
// the pixel leaving brick_grid, so the finish field sits about seven pixels
// ahead of the panel under it. Both terms vary over the whole screen and the
// matte grain is white noise, so nothing about that is observable; delaying
// two 10-bit counters through the grid pipeline would cost more than it buys.
wire [23:0] aging_rgb;
brick_aging aging (
	.clk           ( clk_sys ),
	.gx            ( h_pre - GX0 ),
	.gy            ( v - GY0 ),
	.dimming       ( set_dimming ),
	.frontlight    ( set_frontlight ),
	.backlight     ( set_backlight ),
	.contrast_fade ( set_contrast_fade ),
	.in_rgb        ( grid_rgb ),
	.out_rgb       ( aging_rgb )
);

wire [23:0] vinegar_rgb;
generate if (ENABLE_VINEGAR) begin : with_vinegar
brick_vinegar vinegar (
	.clk       ( clk_sys       ),
	.gx        ( h_pre - GX0   ),
	.gy        ( v - GY0       ),
	.depth     ( set_vinegar   ),
	.blob_mode ( set_rot_blob  ),
	.seed_sel  ( set_rot_seed  ),
	.in_rgb    ( aging_rgb     ),
	.out_rgb   ( vinegar_rgb   )
);
end else begin : without_vinegar
// Preserve the original three registered stages, including when rot is off.
reg [23:0] bypass0, bypass1, bypass2;
always @(posedge clk_sys) begin
 bypass0 <= aging_rgb;
 bypass1 <= bypass0;
 bypass2 <= bypass1;
end
assign vinegar_rgb = bypass2;
end endgenerate

// Dust is cell-addressed, so unlike the low-frequency aging/rot fields its
// coordinates must follow the colour pipeline exactly.
reg [9:0] dust_x_dly [0:11];
reg [9:0] dust_y_dly [0:11];
integer dust_i;
always @(posedge clk_sys) begin
	dust_x_dly[0] <= h_pre - GX0;
	dust_y_dly[0] <= v - GY0;
	for (dust_i = 1; dust_i < 12; dust_i = dust_i + 1) begin
		dust_x_dly[dust_i] <= dust_x_dly[dust_i-1];
		dust_y_dly[dust_i] <= dust_y_dly[dust_i-1];
	end
end

wire [23:0] dust_rgb;
brick_dust dust (
	.clk     ( clk_sys ),
	.gx      ( dust_x_dly[11] ),
	.gy      ( dust_y_dly[11] ),
	.level   ( set_dust ),
	.in_rgb  ( vinegar_rgb ),
	.out_rgb ( dust_rgb )
);

wire [23:0] fin_rgb;
brick_finish finish (
	.clk     ( clk_sys  ),
	.gx      ( h_pre - GX0 ),
	.gy      ( v - GY0     ),
	.set_bright ( set_bright ),
	.set_warm   ( set_warm   ),
	.set_ink_r  ( set_ink_r  ),
	.set_ink_g  ( set_ink_g  ),
	.set_ink_b  ( set_ink_b  ),
	.set_refsat ( set_refsat ),
	.set_gradient ( set_gradient ),
	.set_vignette ( set_vignette ),
	.set_matte    ( set_matte ),
	.in_rgb  ( dust_rgb ),
	.out_rgb ( fin_rgb  )
);

// grid 6 + aging 3 + vinegar 3 + dust 2 + finish 6 = 20 cycles.
reg [19:0] game_dly;
always @(posedge clk_sys) game_dly <= {game_dly[18:0], p4_game};

always @(posedge clk_sys) begin
	de  <= game_dly[19];
	rgb <= game_dly[19] ? fin_rgb : 24'h000000;

	// MiSTer's scaler expects level-width sync pulses. The Pocket target accepts
	// one-clock strobes, but a 30 ns VS strobe can be missed by the HDMI path.
	// Keep both pulses wholly inside blanking and span complete lines for VS.
	vs <= (v < 3);
	hs <= (h >= 32) && (h < 96);
end

endmodule
