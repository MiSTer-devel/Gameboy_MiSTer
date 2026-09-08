// BrickBoy colour stage - the HW form of brickboy's FRAG_COLOR_CORRECT
// (dmg-lut path) plus a running-IIR form of FRAG_COLUMN_REDUCE.
//
// One native row is processed per display row, four raster lines ahead of the
// scanout that consumes it. All arithmetic goes through explicit wide
// intermediates - Verilog sizes an expression by its context, and an 8-bit
// context silently truncates a 16-bit product, which is exactly the class of
// bug the first revision of this file shipped.
//
// Order (display-pipeline.md 3-2): palette -> bleed -> density -> offTint ->
// crosstalk -> panelGamma -> saturation -> warm -> contrast -> brightness ->
// blackLift.
//
// Crosstalk field (plan 3-3(2)) is the running-IIR form of the shader's taps:
//   down  A[x] <- exp(-1/12) * (A[x] + d^2)   rows, top to bottom
//   row   H    <- exp(-1/8)  * (H + d^2)      pixels, left to right
//   edge  0.4 * |d(below) - d(above)|
//   col   per-column gain noise (#49), baked - see the f1b stage
// The weak upward bleed (0.4x of the content BELOW each pixel) is still
// pending: it needs the frame read bottom-to-top, which a top-to-bottom scan
// cannot do without buffering the field.

(* multstyle = "logic" *)
module brick_color (
	input  wire        clk,

	input  wire        start_frame,   // prepare rows 0/1, process row 0
	input  wire        row_tick,      // process the next row
	input  wire        up_tick,       // active area done: run the upward pre-pass
	input  wire [7:0]  row_disp,      // native row entering display
	input  wire [2:0]  set_offtint,   // off-element tint; 2 = dmg.json's 0.1
	input  wire        set_real,     // 0 = nostalgia palette, 1 = measured
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

	output reg  [14:0] fb_addr,
	input  wire [1:0]  fb_q,

	output reg  [7:0]  lb_waddr,
	output reg  [23:0] lb_wdata,
	output reg         lb_wren,
	output reg         lb_wbank,
	output reg  [7:0]  lb_wrow
);

// dmgPalette / grid.bgTint, x255, for both of brickboy's DMG profiles.
//
// dmg-real is measured off the owner's DMG-01. Its ramp sits greener and much
// narrower than the familiar one, and both are real: a reflective panel sends
// outside light through the iodine-PVA polariser TWICE, so its yellow-green
// transmission applies squared - the green is the light PATH, not the reflector
// - and the panel genuinely is that low-contrast. Which is exactly why it is
// not the default. Accurate and legible are different targets, and a handheld
// nobody can read is a worse answer than one that remembers slightly wrong.
localparam [23:0] PAL0_N = {8'd219, 8'd207, 8'd136};   // nostalgia (dmg.json)
localparam [23:0] PAL1_N = {8'd140, 8'd179, 8'd102};
localparam [23:0] PAL2_N = {8'd71,  8'd130, 8'd66 };
localparam [23:0] PAL3_N = {8'd33,  8'd92,  8'd43 };
localparam [23:0] PBG_N  = {8'd237, 8'd217, 8'd149};
localparam [23:0] PAL0_R = {8'd146, 8'd196, 8'd82 };   // measured (dmg-real)
localparam [23:0] PAL1_R = {8'd69,  8'd181, 8'd71 };
localparam [23:0] PAL2_R = {8'd54,  8'd162, 8'd97 };
localparam [23:0] PAL3_R = {8'd32,  8'd147, 8'd105};
localparam [23:0] PBG_R  = {8'd189, 8'd172, 8'd84 };

wire [23:0] PAL0 = set_real ? PAL0_R : PAL0_N;
wire [23:0] PAL1 = set_real ? PAL1_R : PAL1_N;
wire [23:0] PAL2 = set_real ? PAL2_R : PAL2_N;
wire [23:0] PAL3 = set_real ? PAL3_R : PAL3_N;
wire [23:0] PBG  = set_real ? PBG_R  : PBG_N;

// Q0.8 constants (dmg.json x256)
wire [7:0] K_BLEED = (set_bleed == 2'd0) ? 8'd41 :  // original .16
	                  (set_bleed == 2'd1) ? 8'd0  :
	                  (set_bleed == 2'd2) ? 8'd20 : 8'd82;
// offTint 0.1 x density 0.5 = 13. Runtime, because how much the off elements
// still hold is the thing that decides whether the unlit part of the panel
// reads as bare reflector or as an LC that never fully clears - and how much of
// that survives depends on the panel doing the showing.
function automatic [7:0] k_offtint(input [2:0] i);
	case (i)
		3'd0: k_offtint = 8'd0;    // off - the reflector shows through clean
		3'd1: k_offtint = 8'd7;
		3'd2: k_offtint = 8'd13;   // dmg.json
		3'd3: k_offtint = 8'd20;
		3'd4: k_offtint = 8'd28;
		3'd5: k_offtint = 8'd38;
		3'd6: k_offtint = 8'd50;
		3'd7: k_offtint = 8'd64;
	endcase
endfunction
localparam [7:0] K_XT_GRAY  = 8'd102;   // crosstalkGrayField 0.4
localparam [7:0] K_XT_SIGN  = 8'd56;    // crosstalkSigned 0.22
localparam [7:0] K_XT_CLAMP = 8'd166;   // darken clamp 0.65
wire [8:0] K_SAT = (set_saturation == 2'd0) ? 9'd218 : // original .85
	                 (set_saturation == 2'd1) ? 9'd0   :
	                 (set_saturation == 2'd2) ? 9'd256 : 9'd384;
localparam [7:0] K_WARM_R   = 8'd8;     // warm 0.06 x (0.5, 0.15, -0.4)
localparam [7:0] K_WARM_G   = 8'd2;
localparam [7:0] K_WARM_B   = 8'd6;     // subtracted
wire [8:0] K_CONTRAST = (set_contrast == 2'd0) ? 9'd225 : // original .88
	                      (set_contrast == 2'd1) ? 9'd166 :
	                      (set_contrast == 2'd2) ? 9'd256 : 9'd320;
wire [8:0] K_BRIGHT_N = (set_brightness == 2'd0) ? 9'd225 : // original .88
	                      (set_brightness == 2'd1) ? 9'd166 :
	                      (set_brightness == 2'd2) ? 9'd256 : 9'd320;
wire [8:0] K_BRIGHT_R = (set_brightness == 2'd0) ? 9'd256 : // dmg-real original 1.0
	                      (set_brightness == 2'd1) ? 9'd166 :
	                      (set_brightness == 2'd2) ? 9'd256 : 9'd320;
wire [7:0] K_BLACKL = (set_blacklift == 2'd0) ? 8'd26 : // original .10
	                    (set_blacklift == 2'd1) ? 8'd0  :
	                    (set_blacklift == 2'd2) ? 8'd64 : 8'd128;
localparam [7:0] K_BETA_V   = 8'd235;   // exp(-1/12)
localparam [7:0] K_WN_V     = 8'd20;    // 1 - exp(-1/12)
localparam [7:0] K_BETA_H   = 8'd226;   // exp(-1/8)
localparam [7:0] K_WN_H     = 8'd30;    // 1 - exp(-1/8)
wire [7:0] K_XT_EDGE = (set_xtedge == 2'd0) ? 8'd102 : // original .40
	                     (set_xtedge == 2'd1) ? 8'd0   :
	                     (set_xtedge == 2'd2) ? 8'd51  : 8'd204;

wire [8:0] K_DENSITY = (set_density == 2'd0) ? 9'd128 : // original .50
	                    (set_density == 2'd1) ? 9'd64  :
	                    (set_density == 2'd2) ? 9'd192 : 9'd255;
wire [8:0] K_XT_RAW = (set_xtalk == 2'd0) ? 9'd87 : // original .34
	                   (set_xtalk == 2'd1) ? 9'd0  :
	                   (set_xtalk == 2'd2) ? 9'd44 : 9'd174;
wire [9:0] K_TEMP = (set_cold == 2'd0) ? 10'd256 : // 1 + 2*temperature
	                 (set_cold == 2'd1) ? 10'd384 :
	                 (set_cold == 2'd2) ? 10'd512 : 10'd768;
wire [17:0] xt_density_w = K_XT_RAW * K_DENSITY;
wire [27:0] xt_temp_w = xt_density_w * K_TEMP;
wire [28:0] xt_temp_round = {1'b0, xt_temp_w} + 29'd32768;
wire [11:0] K_XTALK_RUN = xt_temp_round[27:16];

localparam byte unsigned LUT_GAMMA[0:255] = '{
  8'd0, 8'd1, 8'd1, 8'd2, 8'd3, 8'd3, 8'd4, 8'd5, 8'd6, 8'd6, 8'd7, 8'd8, 8'd9, 8'd10, 8'd10, 8'd11,
  8'd12, 8'd13, 8'd14, 8'd15, 8'd16, 8'd16, 8'd17, 8'd18, 8'd19, 8'd20, 8'd21, 8'd22, 8'd22, 8'd23, 8'd24, 8'd25,
  8'd26, 8'd27, 8'd28, 8'd29, 8'd30, 8'd31, 8'd31, 8'd32, 8'd33, 8'd34, 8'd35, 8'd36, 8'd37, 8'd38, 8'd39, 8'd40,
  8'd41, 8'd42, 8'd42, 8'd43, 8'd44, 8'd45, 8'd46, 8'd47, 8'd48, 8'd49, 8'd50, 8'd51, 8'd52, 8'd53, 8'd54, 8'd55,
  8'd56, 8'd57, 8'd58, 8'd59, 8'd60, 8'd61, 8'd62, 8'd62, 8'd63, 8'd64, 8'd65, 8'd66, 8'd67, 8'd68, 8'd69, 8'd70,
  8'd71, 8'd72, 8'd73, 8'd74, 8'd75, 8'd76, 8'd77, 8'd78, 8'd79, 8'd80, 8'd81, 8'd82, 8'd83, 8'd84, 8'd85, 8'd86,
  8'd87, 8'd88, 8'd89, 8'd90, 8'd91, 8'd92, 8'd93, 8'd94, 8'd95, 8'd96, 8'd97, 8'd98, 8'd99, 8'd100, 8'd101, 8'd102,
  8'd103, 8'd104, 8'd105, 8'd106, 8'd107, 8'd108, 8'd109, 8'd110, 8'd111, 8'd112, 8'd113, 8'd114, 8'd115, 8'd116, 8'd117, 8'd118,
  8'd119, 8'd121, 8'd122, 8'd123, 8'd124, 8'd125, 8'd126, 8'd127, 8'd128, 8'd129, 8'd130, 8'd131, 8'd132, 8'd133, 8'd134, 8'd135,
  8'd136, 8'd137, 8'd138, 8'd139, 8'd140, 8'd141, 8'd142, 8'd143, 8'd144, 8'd145, 8'd146, 8'd147, 8'd149, 8'd150, 8'd151, 8'd152,
  8'd153, 8'd154, 8'd155, 8'd156, 8'd157, 8'd158, 8'd159, 8'd160, 8'd161, 8'd162, 8'd163, 8'd164, 8'd165, 8'd166, 8'd167, 8'd169,
  8'd170, 8'd171, 8'd172, 8'd173, 8'd174, 8'd175, 8'd176, 8'd177, 8'd178, 8'd179, 8'd180, 8'd181, 8'd182, 8'd183, 8'd184, 8'd186,
  8'd187, 8'd188, 8'd189, 8'd190, 8'd191, 8'd192, 8'd193, 8'd194, 8'd195, 8'd196, 8'd197, 8'd198, 8'd199, 8'd201, 8'd202, 8'd203,
  8'd204, 8'd205, 8'd206, 8'd207, 8'd208, 8'd209, 8'd210, 8'd211, 8'd212, 8'd214, 8'd215, 8'd216, 8'd217, 8'd218, 8'd219, 8'd220,
  8'd221, 8'd222, 8'd223, 8'd224, 8'd225, 8'd227, 8'd228, 8'd229, 8'd230, 8'd231, 8'd232, 8'd233, 8'd234, 8'd235, 8'd236, 8'd237,
  8'd239, 8'd240, 8'd241, 8'd242, 8'd243, 8'd244, 8'd245, 8'd246, 8'd247, 8'd248, 8'd250, 8'd251, 8'd252, 8'd253, 8'd254, 8'd255
};

localparam byte unsigned LUT_OFFW[0:255] = '{
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
  8'd0, 8'd0, 8'd0, 8'd1, 8'd1, 8'd1, 8'd2, 8'd3, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9, 8'd10,
  8'd12, 8'd13, 8'd15, 8'd16, 8'd18, 8'd19, 8'd21, 8'd23, 8'd25, 8'd27, 8'd28, 8'd30, 8'd33, 8'd35, 8'd37, 8'd39,
  8'd41, 8'd44, 8'd46, 8'd48, 8'd51, 8'd53, 8'd56, 8'd58, 8'd61, 8'd63, 8'd66, 8'd69, 8'd72, 8'd74, 8'd77, 8'd80,
  8'd83, 8'd85, 8'd88, 8'd91, 8'd94, 8'd97, 8'd100, 8'd103, 8'd106, 8'd109, 8'd112, 8'd115, 8'd118, 8'd121, 8'd124, 8'd127,
  8'd130, 8'd133, 8'd136, 8'd139, 8'd142, 8'd145, 8'd148, 8'd151, 8'd154, 8'd157, 8'd159, 8'd162, 8'd165, 8'd168, 8'd171, 8'd174,
  8'd177, 8'd179, 8'd182, 8'd185, 8'd188, 8'd190, 8'd193, 8'd195, 8'd198, 8'd201, 8'd203, 8'd205, 8'd208, 8'd210, 8'd213, 8'd215,
  8'd217, 8'd219, 8'd221, 8'd224, 8'd226, 8'd228, 8'd229, 8'd231, 8'd233, 8'd235, 8'd237, 8'd238, 8'd240, 8'd241, 8'd243, 8'd244,
  8'd245, 8'd246, 8'd248, 8'd249, 8'd250, 8'd251, 8'd251, 8'd252, 8'd253, 8'd253, 8'd254, 8'd254, 8'd255, 8'd255, 8'd255, 8'd255
};

// Four source-parameter samples: original 1.10, linear 1.0, 1.5 and 2.0.
// Three simultaneous registered reads infer replicated M10K ROMs.
(* ramstyle = "M10K" *) reg [7:0] COLOR_GAMMA [0:1023];
initial $readmemh("rtl/brickboy/brick_color_gamma.hex", COLOR_GAMMA);


function automatic [7:0] dsq(input [1:0] s);  // (shade/3)^2, Q0.8
	case (s)
		2'd0: dsq = 8'd0;
		2'd1: dsq = 8'd28;
		2'd2: dsq = 8'd114;
		2'd3: dsq = 8'd255;
	endcase
endfunction

function automatic [7:0] dlin(input [1:0] s); // shade/3, Q0.8
	case (s)
		2'd0: dlin = 8'd0;
		2'd1: dlin = 8'd85;
		2'd2: dlin = 8'd170;
		2'd3: dlin = 8'd255;
	endcase
endfunction

function automatic [23:0] pal(input [1:0] s);
	case (s)
		2'd0: pal = PAL0;
		2'd1: pal = PAL1;
		2'd2: pal = PAL2;
		2'd3: pal = PAL3;
	endcase
endfunction

function automatic [7:0] sat8(input signed [19:0] v);
	sat8 = (v < 0) ? 8'd0 : (v > 255) ? 8'd255 : v[7:0];
endfunction

// a + (b - a) * k / 256. Never leaves [0,255], so no clamp is needed, but the
// intermediate is computed wide and signed.
//
// The +128 rounds instead of truncating. Truncation is a one-sided error: every
// stage loses on average half an LSB downward, and there are nine of them, so
// the pipeline came out 1-3 levels dark at every shade. That reads as a green
// cast rather than as dimness, because the palette's darkest shade is
// (33, 92, 43) - strongly green - so darkening the image pulls it toward the
// ink's hue. Rounding costs one adder per stage.
function automatic [7:0] mix8(input [7:0] a, input [7:0] b, input [7:0] k);
	reg signed [17:0] d;
	begin
		d = ($signed({1'b0, b}) - $signed({1'b0, a})) * $signed({1'b0, k})
		    + 18'sd128;
		mix8 = a + d[15:8];
	end
endfunction

// luma, exact: (77 R + 150 G + 29 B + 128) >> 8
function automatic [7:0] luma8(input [7:0] r, input [7:0] g, input [7:0] b);
	reg [16:0] t;
	begin
		t = 17'd77 * r + 17'd150 * g + 17'd29 * b + 17'd128;
		luma8 = t[15:8];
	end
endfunction

// --------------------------------------------------------------- row cache ---

reg [1:0] row_up[0:159], row_cur[0:159], row_dn[0:159];

// ---------------------------------------------------------- column IIR RAM ---

reg [13:0] colA[0:159];
reg [13:0] colA_q;
reg [15:0] rowH;

// --------------------------------------------------------------------- FSM ---

localparam S_IDLE = 3'd0, S_PF0 = 3'd1, S_PF1 = 3'd2, S_PROC = 3'd3, S_UP = 3'd4;

reg [2:0]  state = S_IDLE;
reg [8:0]  x;                    // 9 bits: runs past 159 during pipeline flush
reg [8:0]  x_d1;
reg [7:0]  cur_row;
reg        first_frame_row;
reg        pf_lat;

function automatic [14:0] fbaddr(input [7:0] r, input [7:0] xx);
	fbaddr = {r, 7'b0} + {2'b0, r, 5'b0} + xx;
endfunction

wire [7:0] row_below = (cur_row == 8'd143) ? 8'd143 : cur_row + 8'd1;

// ------------------------------------------------- upward crosstalk field ---
// FRAG_COLUMN_REDUCE is BIDIRECTIONAL: content BELOW a pixel bleeds upward onto
// it at 0.4x the downward weight. Its comment is explicit that this is what
// makes the effect read as crosstalk SURROUNDING dark content rather than as a
// second copy of the pixel drop-shadow - and without it a wide dark block just
// gets a flat skirt underneath.
//
// A top-to-bottom scan cannot see the rows below, so the field is computed once
// per frame by a pre-pass that walks rows 143 -> 0 during blanking, using the
// same one-pole recurrence as the downward accumulator:
//
//     U(r) = exp(-1/12) * (d(r+1)^2 + U(r+1)),   U(143) = 0
//
// Storing it for every row would cost 160 x 144 bytes. The decay constant is 12
// dots, so the field is smooth vertically and one sample every 8 rows carries
// it: 18 lattice rows, packed as pairs {U at 8(cy+1), U at 8cy} so the linear
// interpolation the forward pass does needs a single read. 2880 x 16 bits.
//
// The pre-pass reads the frame buffer through the same port the row prefetch
// uses; it runs in the gap after the last row and before the next frame's
// start_frame, which is about 47k clocks against the 23k it needs. The capture
// is writing the NEXT frame meanwhile, but only into rows the walk has already
// passed, so what it reads is one consistent frame.
localparam int UP_LROWS = 18;

reg [15:0] upbuf[0:UP_LROWS*160-1];
reg [13:0] colU[0:159];
reg [7:0]  up_hi[0:159];
reg [7:0]  up_row;
reg [8:0]  up_x, up_xd;      // up_xd trails up_x, matching fb_q's one-cycle lag
reg        up_lat;
reg        up_valid = 1'b0;      // no field until the first pre-pass finishes

// cy * 160 = cy*128 + cy*32
function automatic [11:0] upaddr(input [4:0] cy, input [7:0] xx);
	upaddr = {cy, 7'b0} + {cy, 5'b0} + xx;
endfunction

wire [7:0]  up_sample = colU[up_xd[7:0]][11:4];      // U >> 4, in 8 bits
wire [22:0] colU_new  = K_BETA_V * (colU[up_xd[7:0]] + {6'd0, dsq(fb_q)});

// Transition assignments live at the END of each branch so nothing can
// override them - the first revision incremented x after setting it to zero,
// and the increment won.
always @(posedge clk) begin
	case (state)
	S_IDLE: begin
		if (start_frame) begin
			cur_row <= 8'd0;
			first_frame_row <= 1'b1;
			fb_addr <= fbaddr(8'd0, 8'd0);
			x <= 0; x_d1 <= 0; pf_lat <= 0;
			state <= S_PF0;
		end else if (row_tick) begin
			for (int i = 0; i < 160; i++) begin
				`ifdef VERILATOR
				row_up[i]  = row_cur[i];
				row_cur[i] = row_dn[i];
				`else
				row_up[i]  <= row_cur[i];
				row_cur[i] <= row_dn[i];
				`endif
			end
			cur_row <= row_disp + 8'd1;
			first_frame_row <= 1'b0;
			fb_addr <= fbaddr((row_disp >= 8'd142) ? 8'd143 : row_disp + 8'd2, 8'd0);
			x <= 0; x_d1 <= 0; pf_lat <= 0;
			state <= S_PF1;
		end else if (up_tick) begin
			up_row <= 8'd143;
			up_x   <= 0; up_xd <= 0;
			up_lat <= 0;
			fb_addr <= fbaddr(8'd143, 8'd0);
			for (int i = 0; i < 160; i++) begin
				`ifdef VERILATOR
				colU[i]  = 14'd0;
				up_hi[i] = 8'd0;
				`else
				colU[i]  <= 14'd0;
				up_hi[i] <= 8'd0;      // U at row 144, off the bottom
				`endif
			end
			state <= S_UP;
		end
	end

	// One column per clock, rows 143 -> 0. fb_q lags the address by a cycle, so
	// up_lat skips the first result the way the row prefetch does.
	S_UP: begin
		up_x  <= up_x + 1'd1;
		up_xd <= up_x;
		fb_addr <= fbaddr(up_row, up_x[7:0] + 8'd1);
		if (!up_lat) up_lat <= 1'b1;
		else begin
			// Record U before the update: colU currently holds U(up_row), the
			// sum over the rows BELOW this one.
			if (up_row[2:0] == 3'd0) begin
				upbuf[upaddr(up_row[7:3], up_xd[7:0])]
				    <= {up_hi[up_xd[7:0]], up_sample};
				up_hi[up_xd[7:0]] <= up_sample;
			end
			colU[up_xd[7:0]] <= colU_new[21:8];   // becomes U(up_row - 1)
			if (up_xd == 9'd159) begin
				up_x <= 0; up_xd <= 0; up_lat <= 0;
				if (up_row == 8'd0) begin
					up_valid <= 1'b1;
					state <= S_IDLE;
				end else begin
					up_row <= up_row - 8'd1;
					fb_addr <= fbaddr(up_row - 8'd1, 8'd0);
				end
			end
		end
	end

	S_PF0: begin
		x <= x + 1'd1;
		x_d1 <= x;
		fb_addr <= fbaddr(8'd0, x[7:0] + 8'd1);
		if (!pf_lat) pf_lat <= 1'b1;
		else begin
			row_cur[x_d1[7:0]] <= fb_q;
			row_up[x_d1[7:0]]  <= fb_q;      // clamp: row -1 = row 0
			if (x_d1 == 9'd159) begin
				fb_addr <= fbaddr(8'd1, 8'd0);
				x <= 0; x_d1 <= 0; pf_lat <= 0;
				state <= S_PF1;
			end
		end
	end

	S_PF1: begin
		x <= x + 1'd1;
		x_d1 <= x;
		fb_addr <= fbaddr(first_frame_row ? 8'd1 : row_below, x[7:0] + 8'd1);
		if (!pf_lat) pf_lat <= 1'b1;
		else begin
			row_dn[x_d1[7:0]] <= fb_q;
			if (x_d1 == 9'd159) begin
				x <= 0; x_d1 <= 0;
				state <= S_PROC;
			end
		end
	end

	S_PROC: begin
		x <= x + 1'd1;
		if (p5_done) begin
			x <= 0;
			state <= S_IDLE;
		end
	end
	endcase
end

// ------------------------------------------------------------ the pipeline ---

wire        px_v  = (state == S_PROC) && (x < 9'd160);
wire [7:0]  px    = x[7:0];
wire [7:0]  xm1   = (px == 8'd0)   ? 8'd0   : px - 8'd1;
wire [7:0]  xp1   = (px == 8'd159) ? 8'd159 : px + 8'd1;

// f0: taps + column/row IIR state
reg [1:0]  s_c, s_l, s_r, s_u, s_d;
reg [7:0]  f0_x;  reg f0_v;
reg [15:0] rowH_use;

wire [24:0] rowH_new = K_BETA_H * (rowH + {8'd0, dsq(row_cur[px])});

// The lattice word for the row being processed, and the weight inside it. Read
// with the f0 taps so it lands with them.
reg [15:0] up_q;
reg [2:0]  up_f0;

always @(posedge clk) begin
	up_q  <= upbuf[upaddr(cur_row[7:3], px)];
	up_f0 <= cur_row[2:0];
end

always @(posedge clk) begin
	f0_v <= px_v;
	f0_x <= px;
	s_c  <= row_cur[px];
	s_l  <= row_cur[xm1];
	s_r  <= row_cur[xp1];
	s_u  <= row_up[px];
	s_d  <= row_dn[px];
	colA_q   <= first_frame_row ? 14'd0 : colA[px];
	rowH_use <= rowH;
	if (px_v) rowH <= rowH_new[23:8];
	else if (state != S_PROC) rowH <= 16'd0;
end

// f1: palette + bleed + crosstalk field, colA writeback
reg [7:0]  c1r, c1g, c1b;
reg [9:0]  field1;
reg [7:0]  f1_x;  reg f1_v;

wire [23:0] pc = pal(s_c);
wire [23:0] pl = pal(s_l);
wire [23:0] pr = pal(s_r);
wire [23:0] pu = pal(s_u);
wire [23:0] pd = pal(s_d);
wire [9:0]  avg_r = ({2'b0, pl[23:16]} + {2'b0, pr[23:16]} + {2'b0, pu[23:16]} + {2'b0, pd[23:16]}) >> 2;
wire [9:0]  avg_g = ({2'b0, pl[15:8]}  + {2'b0, pr[15:8]}  + {2'b0, pu[15:8]}  + {2'b0, pd[15:8]})  >> 2;
wire [9:0]  avg_b = ({2'b0, pl[7:0]}   + {2'b0, pr[7:0]}   + {2'b0, pu[7:0]}   + {2'b0, pd[7:0]})   >> 2;

wire [7:0]  edge_d = (dlin(s_d) > dlin(s_u)) ? dlin(s_d) - dlin(s_u)
                                             : dlin(s_u) - dlin(s_d);
wire [22:0] colA_new = K_BETA_V * (colA_q + {6'd0, dsq(s_c)});
// Interpolate the upward field between the two lattice rows, then weight it.
// The stored value is U >> 4 and the shader's weight is 0.4 * wnV = 0.4 * 20,
// so the contribution is (u << 4) * 8 = u << 7.
wire [7:0] up_lo = up_q[7:0], up_hi_q = up_q[15:8];
wire signed [12:0] up_d = ($signed({1'b0, up_hi_q}) - $signed({1'b0, up_lo}))
                          * $signed({1'b0, up_f0});
wire [7:0] up_v = up_valid ? (up_lo + up_d[10:3]) : 8'd0;

wire [21:0] fld = ({8'd0, colA_q} * K_WN_V)
                + (({6'd0, rowH_use} * K_WN_H) >> 2)
                + ({14'd0, edge_d} * K_XT_EDGE)
                + {7'd0, up_v, 7'd0};

always @(posedge clk) begin
	f1_v <= f0_v; f1_x <= f0_x;
	c1r <= mix8(pc[23:16], avg_r[7:0], K_BLEED);
	c1g <= mix8(pc[15:8],  avg_g[7:0], K_BLEED);
	c1b <= mix8(pc[7:0],   avg_b[7:0], K_BLEED);
	field1 <= (fld[21:8] > 14'd1023) ? 10'd1023 : fld[17:8];
	if (f0_v) colA[f0_x] <= colA_new[21:8];
end

// f1d: physical contrast wheel. Density moves every cell together toward the
// darkest LC shade or the bare reflector; .50 is neutral and is the default.
reg [7:0] c1dr, c1dg, c1db;
reg [9:0] field1d;
reg [7:0] f1d_x; reg f1d_v;
wire [7:0] dens_dark = (K_DENSITY > 9'd128) ?
	((K_DENSITY == 9'd255) ? 8'd255 : (K_DENSITY - 9'd128) << 1) : 8'd0;
wire [7:0] dens_light = (K_DENSITY < 9'd128) ? (9'd128 - K_DENSITY) << 1 : 8'd0;

always @(posedge clk) begin
	f1d_v <= f1_v; f1d_x <= f1_x;
	field1d <= field1;
	if (K_DENSITY > 9'd128) begin
		c1dr <= mix8(c1r, PAL3[23:16], dens_dark);
		c1dg <= mix8(c1g, PAL3[15:8],  dens_dark);
		c1db <= mix8(c1b, PAL3[7:0],   dens_dark);
	end else begin
		c1dr <= mix8(c1r, PBG[23:16], dens_light);
		c1dg <= mix8(c1g, PBG[15:8],  dens_light);
		c1db <= mix8(c1b, PBG[7:0],   dens_light);
	end
end

// f1b: luma, and the per-column crosstalk gain (#49).
//
// Feeding a 3-term dot product straight into a LUT and then into three
// interpolations does not close in one hop, so the luma gets its own stage; the
// column gain rides along in it.
//
// The gain is the last piece of FRAG_COLUMN_REDUCE:
//     field *= 1.0 + uXtalkNoise * (hash21(col, seed) - 0.5)
// a +-9% per-column variation, baked by tools/bake_grain.py. Without it every
// column of a wide dark block is shaded identically and the crosstalk below it
// reads as a flat fill instead of as panel behaviour.
reg [7:0] c1br, c1bg, c1bb, luma1b;
reg [9:0] field1b;
reg [7:0] f1b_x; reg f1b_v;

`include "brick_xtalk_col.svh"

wire signed [8:0] xtn_orig = {XT_COL[f1d_x][7], XT_COL[f1d_x]};
wire signed [9:0] xtn_run = (set_xtnoise == 2'd1) ? 10'sd0 :
	                         (set_xtnoise == 2'd2) ? (xtn_orig >>> 1) :
	                         (set_xtnoise == 2'd3) ? (xtn_orig <<< 1) : xtn_orig;
wire signed [20:0] xt_adj = $signed({10'b0, field1d}) * xtn_run + 21'sd128;
wire signed [11:0] xt_sum = $signed({2'b0, field1d}) + xt_adj[20:8];

always @(posedge clk) begin
	f1b_v <= f1d_v; f1b_x <= f1d_x;
	c1br <= c1dr; c1bg <= c1dg; c1bb <= c1db;
	field1b <= (xt_sum < 0) ? 10'd0 :
	           (xt_sum > 12'sd1023) ? 10'd1023 : xt_sum[9:0];
	luma1b <= luma8(c1dr, c1dg, c1db);
end

// f2: offTint (density 0.5 folded into the constants)
reg [7:0]  c2r, c2g, c2b, luma2;
reg [9:0]  field2;
reg [7:0]  f2_x;  reg f2_v;

wire [15:0] koff_density_w = k_offtint(set_offtint) * K_DENSITY;
wire [8:0] koff_density = (koff_density_w[15:7] > 9'd255) ? 9'd255 : koff_density_w[15:7];
wire [16:0] offm_w = koff_density[7:0] * LUT_OFFW[luma1b] + 17'd128;
wire [7:0]  offm   = offm_w[15:8];

always @(posedge clk) begin
	f2_v <= f1b_v; f2_x <= f1b_x;
	luma2 <= luma1b;
	field2 <= field1b;
	c2r <= mix8(c1br, PAL3[23:16], offm);
	c2g <= mix8(c1bg, PAL3[15:8],  offm);
	c2b <= mix8(c1bb, PAL3[7:0],   offm);
end

// f2b: how much the crosstalk darkens this pixel. The grey-field weight, the
// clamp and the signed term are a chain of three multiplies; applying them to
// the colour in the same hop was the last path over budget.
reg [7:0]  dk2;
reg signed [9:0] sgn2;
reg [7:0]  c2br, c2bg, c2bb;
reg [7:0]  f2b_x; reg f2b_v;

wire [7:0]  mg    = (luma2 > 8'd128) ? 8'd255 - ((luma2 - 8'd128) << 1)
                                     : 8'd255 - ((8'd128 - luma2) << 1);
wire [15:0] gry_w = K_XT_GRAY * mg;
wire [8:0]  gryf  = (9'd255 - K_XT_GRAY) + gry_w[15:8];
wire [21:0] amt0  = K_XTALK_RUN * field2;
wire [30:0] amt1  = amt0 * gryf;
wire [14:0] amt   = amt1[30:16];
wire [7:0]  dk_w  = (amt > {7'b0, K_XT_CLAMP}) ? K_XT_CLAMP : amt[7:0];
wire signed [8:0]  pol   = $signed({1'b0, luma2}) - 9'sd128;
wire signed [24:0] sgn_w = $signed({1'b0, K_XT_SIGN}) * $signed({1'b0, dk_w}) * pol;

always @(posedge clk) begin
	f2b_v <= f2_v; f2b_x <= f2_x;
	c2br <= c2r; c2bg <= c2g; c2bb <= c2b;
	dk2  <= dk_w;
	sgn2 <= sgn_w >>> 15;
end

// f3: apply it
reg [7:0]  c3r, c3g, c3b;
reg [7:0]  f3_x;  reg f3_v;

wire [16:0] xr = c2br * (9'd256 - dk2);
wire [16:0] xg = c2bg * (9'd256 - dk2);
wire [16:0] xb = c2bb * (9'd256 - dk2);

always @(posedge clk) begin
	f3_v <= f2b_v; f3_x <= f2b_x;
	c3r <= sat8($signed({11'b0, xr[16:8]}) + sgn2);
	c3g <= sat8($signed({11'b0, xg[16:8]}) + sgn2);
	c3b <= sat8($signed({11'b0, xb[16:8]}) + sgn2);
end

// f3b: gamma LUT + its luma, split off for the same reason as f1b
reg [7:0] g3r, g3g, g3b, g3l;
reg [7:0] f3b_x; reg f3b_v;

wire [7:0] gamma_r = COLOR_GAMMA[{set_gamma, c3r}];
wire [7:0] gamma_g = COLOR_GAMMA[{set_gamma, c3g}];
wire [7:0] gamma_b = COLOR_GAMMA[{set_gamma, c3b}];

always @(posedge clk) begin
	f3b_v <= f3_v; f3b_x <= f3_x;
	g3r <= gamma_r;
	g3g <= gamma_g;
	g3b <= gamma_b;
	g3l <= luma8(gamma_r, gamma_g, gamma_b);
end

// f4: saturation + warm
reg [7:0]  c4r, c4g, c4b;
reg [7:0]  f4_x;  reg f4_v;

wire [7:0] gr = g3r, gg = g3g, gb = g3b, gl = g3l;

// +128 on every product: see mix8 for why these round rather than truncate.
wire signed [17:0] sat_r = ($signed({1'b0, gr}) - $signed({1'b0, gl})) * $signed({1'b0, K_SAT}) + 18'sd128;
wire signed [17:0] sat_g = ($signed({1'b0, gg}) - $signed({1'b0, gl})) * $signed({1'b0, K_SAT}) + 18'sd128;
wire signed [17:0] sat_b = ($signed({1'b0, gb}) - $signed({1'b0, gl})) * $signed({1'b0, K_SAT}) + 18'sd128;
wire [15:0] w_r = gl * K_WARM_R + 16'd128;
wire [15:0] w_g = gl * K_WARM_G + 16'd128;
wire [15:0] w_b = gl * K_WARM_B + 16'd128;

always @(posedge clk) begin
	f4_v <= f3b_v; f4_x <= f3b_x;
	c4r <= sat8($signed({12'b0, gl}) + (sat_r >>> 8) + $signed({12'b0, w_r[15:8]}));
	c4g <= sat8($signed({12'b0, gl}) + (sat_g >>> 8) + $signed({12'b0, w_g[15:8]}));
	c4b <= sat8($signed({12'b0, gl}) + (sat_b >>> 8) - $signed({12'b0, w_b[15:8]}));
end

// f5: contrast + brightness + blackLift, retire
reg p5_done;

function automatic [7:0] tone(input [7:0] v);
	reg signed [17:0] t;
	reg signed [17:0] u;
	begin
		t = (($signed({1'b0, v}) - 18'sd128) * $signed({1'b0, K_CONTRAST})) + 18'sd128;
		t = (t >>> 8) + 18'sd128;
		// dmg-real's brightness is 1.0 - the owner matched the panel by eye at
		// the end of the second measuring pass and needed no lift - so that
		// profile skips the multiply outright rather than writing it as x256.
		u = t * $signed({1'b0, (set_real ? K_BRIGHT_R : K_BRIGHT_N)}) + 18'sd128;
		tone = sat8(u >>> 8);
	end
endfunction

always @(posedge clk) begin
	p5_done  <= f4_v && (f4_x == 8'd159);
	lb_wren  <= f4_v;
	lb_waddr <= f4_x;
	lb_wbank <= cur_row[0];
	lb_wrow  <= cur_row;
	lb_wdata <= { mix8(tone(c4r), PBG[23:16], K_BLACKL),
	              mix8(tone(c4g), PBG[15:8],  K_BLACKL),
	              mix8(tone(c4b), PBG[7:0],   K_BLACKL) };
end

endmodule
