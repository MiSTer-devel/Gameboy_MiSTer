// Screen-space finish - the HW form of brickboy's FRAG_PASSTHROUGH.
//
// The last pass in brickboy's chain lays three screen-space terms over the
// finished panel. They are what a reflective panel under room light actually
// looks like, and leaving them out is why this port came out uniformly darker
// than brickboy and why its reflector grain vanished at a distance:
//
//   gradient  brighter toward the reflection source at module-uv (0.30, 0.72),
//             +-8%. This is the term that was missing: it is worth ~3% at the
//             centre of the screen, and it is most of the low-frequency
//             variation that survives when the eye averages the grain.
//   vignette  corner darkening, 8% at the corners, 0 at the centre.
//   grain     a matte luma grain, one hash per output pixel, +-1.2% added
//             equally to all channels. White noise by design - it is the
//             viewer's screen, not the console's reflector sheet, so it does
//             NOT get the coarse bands brick_grain carries.
//
//     prox = 1 - clamp(distance(vUv, SHEEN_CENTER), 0, 1)
//     col *= 1 + uGradient * (prox - 0.5) * 2
//     col *= 1 - uVignette * dot(vUv - 0.5, vUv - 0.5) * 2
//     col += (hash21(floor(vUv * uResolution)) - 0.5) * uGrain
//
// Computed arithmetically rather than from a table: a lattice ROM would have
// been simpler, but M10K is the resource this design is short of and DSP is
// not. Coordinates are module-uv - brickboy renders the whole 168 x 152 module
// and the Pocket only shows the 160 x 144 dot field, so the game area sits at
// (16, 16) of 672 x 608 output pixels.

(* multstyle = "logic" *)
module brick_finish (
	input  wire        clk,
	input  wire [9:0]  gx,          // output pixel within the game area
	input  wire [9:0]  gy,
	input  wire [2:0]  set_bright,  // panel trim, 3 = neutral
	input  wire [2:0]  set_warm,    // panel trim, 3 = neutral
	input  wire [2:0]  set_ink_r,   // dark-shade tone, per channel, 0 = off
	input  wire [2:0]  set_ink_g,
	input  wire [2:0]  set_ink_b,
	input  wire [2:0]  set_refsat,  // reflector desaturation, 0 = off
	input  wire [1:0]  set_gradient,
	input  wire [1:0]  set_vignette,
	input  wire [1:0]  set_matte,
	input  wire [23:0] in_rgb,
	output reg  [23:0] out_rgb
);

localparam [15:0] CX = 16'd19661;   // 0.30 in Q0.16
localparam [15:0] CY = 16'd47186;   // 0.72
localparam [15:0] HALF = 16'd32768;

// 65536 / 672 and 65536 / 608, as Q6.10 multipliers
localparam [16:0] SX = 17'd99864;   // 97.5238 * 1024
localparam [16:0] SY = 17'd110376;  // 107.7895 * 1024

function automatic [15:0] finish_level(input [1:0] i);
	case (i)
		2'd0: finish_level = 16'd10486; // original 0.08 * 2
		2'd1: finish_level = 16'd0;
		2'd2: finish_level = 16'd5243;
		default: finish_level = 16'd15729;
	endcase
endfunction

function automatic [7:0] matte_level(input [1:0] i);
	case (i)
		2'd0: matte_level = 8'd3; // original 0.012 * 255
		2'd1: matte_level = 8'd0;
		2'd2: matte_level = 8'd2;
		default: matte_level = 8'd6;
	endcase
endfunction

wire [15:0] K_GRAD = finish_level(set_gradient);
wire [15:0] K_VIGN = finish_level(set_vignette);
wire [7:0]  K_FGRAIN = matte_level(set_matte);

// sqrt(x) for x in [0,1), Q0.16 in and out, indexed by the top 8 bits.
localparam bit [15:0] LUT_SQRT[0:255] = '{
`include "brick_sqrt.svh"
};

// Panel trim. NOT part of the port: brickboy's numbers are reproduced exactly
// and these ride on top, because the Pocket's LTPS LCD and the phone OLED
// brickboy is authored against have different primaries and Analogue publishes
// no colorimetry for the panel. Guessing a correction into the pipeline would
// corrupt the port; a knob leaves the reference intact and lets the person
// looking at the screen decide.
//
// The centre is what the Pocket's own panel wants, measured by eye on hardware:
// -9% brightness and +9% warmth. Those are panel corrections, not brickboy's
// numbers - the reference pipeline is untouched and these ride on top - so the
// centre of the dial is the place the panel looks right, and the dial moves
// around it. Index 3 is the centre; run_settings is zero before the Pocket
// writes, so index 0 must still be usable.
function automatic [16:0] k_bright(input [2:0] i);
	case (i)
		3'd0: k_bright = 17'd53740;   // 0.820
		3'd1: k_bright = 17'd55706;   // 0.850
		3'd2: k_bright = 17'd57672;   // 0.880
		3'd3: k_bright = 17'd59638;   // 0.910  <- centre, the panel's -9%
		3'd4: k_bright = 17'd61604;   // 0.940
		3'd5: k_bright = 17'd63570;   // 0.970
		3'd6: k_bright = 17'd65536;   // 1.000
		3'd7: k_bright = 17'd67502;   // 1.030
	endcase
endfunction

// Warmth trades red against blue at constant green, so it moves the hue without
// moving the luminance much.
function automatic [16:0] k_warm_r(input [2:0] i);
	case (i)
		3'd0: k_warm_r = 17'd61604;   // 0.940
		3'd1: k_warm_r = 17'd63570;
		3'd2: k_warm_r = 17'd65536;
		3'd3: k_warm_r = 17'd71434;   // 1.090  <- centre, the panel's +9%
		3'd4: k_warm_r = 17'd73400;
		3'd5: k_warm_r = 17'd75366;
		3'd6: k_warm_r = 17'd77332;
		3'd7: k_warm_r = 17'd79298;   // 1.210
	endcase
endfunction

function automatic [16:0] k_warm_b(input [2:0] i);
	case (i)
		3'd0: k_warm_b = 17'd69468;   // 1.060
		3'd1: k_warm_b = 17'd67502;
		3'd2: k_warm_b = 17'd65536;
		3'd3: k_warm_b = 17'd59638;   // 0.910  <- centre
		3'd4: k_warm_b = 17'd57672;
		3'd5: k_warm_b = 17'd55706;
		3'd6: k_warm_b = 17'd53740;
		3'd7: k_warm_b = 17'd51774;   // 0.790
	endcase
endfunction

// Ink tone: pushes the DARK shades toward navy and darker, weighted by how dark
// the pixel already is, so the reflector and the light shades are untouched.
// The Pocket's panel reads green-heavy exactly where the ink is.
function automatic [7:0] k_ink(input [2:0] i);
	case (i)
		3'd0: k_ink = 8'd0;     // off
		3'd1: k_ink = 8'd20;
		3'd2: k_ink = 8'd40;
		3'd3: k_ink = 8'd64;
		3'd4: k_ink = 8'd96;
		3'd5: k_ink = 8'd136;
		3'd6: k_ink = 8'd184;
		3'd7: k_ink = 8'd240;   // very nearly black, with a navy cast
	endcase
endfunction

// ---- s0: module-uv ----------------------------------------------------------
// vUv.y is measured up from the bottom, so the flip is folded in here.
reg [15:0] ux, uy;
reg [23:0] c0;
reg [9:0]  x0, y0;

wire [26:0] uxw = ({17'd0, gx} + 27'd16) * SX;
wire [26:0] uyw = ({17'd0, gy} + 27'd16) * SY;

always @(posedge clk) begin
	ux <= uxw[25:10];
	uy <= 16'd65535 - uyw[25:10];
	c0 <= in_rgb;
	x0 <= gx; y0 <= gy;
end

// ---- s1: the two squared distances ------------------------------------------
reg [31:0] r2_sheen, r2_centre;
reg [23:0] c1;
reg [9:0]  x1, y1;

wire signed [16:0] dx = $signed({1'b0, ux}) - $signed({1'b0, CX});
wire signed [16:0] dy = $signed({1'b0, uy}) - $signed({1'b0, CY});
wire signed [16:0] vx = $signed({1'b0, ux}) - $signed({1'b0, HALF});
wire signed [16:0] vy = $signed({1'b0, uy}) - $signed({1'b0, HALF});

always @(posedge clk) begin
	r2_sheen  <= dx * dx + dy * dy;
	r2_centre <= vx * vx + vy * vy;
	c1 <= c0;
	x1 <= x0; y1 <= y0;
end

// ---- s2: distance, and the two scale terms ----------------------------------
reg signed [17:0] grad2, vign2;
reg [23:0] c2;
reg [9:0]  x2, y2;

// r2 is Q0.32 of a value that never exceeds 1.0 here, so the top 16 bits are
// Q0.16. Saturate anyway - the shader clamps the distance to 1.
wire [15:0] r2s = (r2_sheen[31:16] > 16'd65535) ? 16'd65535 : r2_sheen[31:16];
wire [15:0] sqdist = LUT_SQRT[r2s[15:8]];
wire signed [17:0] prox = 18'sd65536 - $signed({2'b0, sqdist});

wire signed [33:0] gradw = (prox - 18'sd32768) * $signed({2'b0, K_GRAD});
wire [31:0]        vignw = r2_centre[31:16] * K_VIGN;

always @(posedge clk) begin
	grad2 <= gradw[33:16];
	vign2 <= $signed({2'b0, vignw[31:16]});
	c2 <= c1;
	x2 <= x1; y2 <= y1;
end

// ---- s3: apply ---------------------------------------------------------------
// One factor per channel (the trim splits them), then the matte grain added
// equally.
reg [23:0] c3;
reg signed [9:0] fg3;

function automatic [31:0] mix32(input [31:0] v);
	reg [31:0] t;
	begin
		t = v ^ (v >> 16);
		t = t * 32'h7feb352d;
		t = t ^ (t >> 15);
		t = t * 32'h846ca68b;
		mix32 = t ^ (t >> 16);
	end
endfunction

wire [31:0] fh = mix32({6'b0, y2, 6'b0, x2} ^ 32'h5bd1e995);

// The trim is constant, so it is folded into the per-pixel factor once. Three
// multiplies rather than three more in the output stage, and the widths stay
// small because both terms are near unity.
wire signed [17:0] fac_now = 18'sd65536 + grad2 - vign2;
wire [34:0] tb = $unsigned(fac_now) * k_bright(set_bright);
wire [16:0] fb17 = tb[32:16];
wire [33:0] tr = fb17 * k_warm_r(set_warm);
wire [33:0] tbb = fb17 * k_warm_b(set_warm);

reg signed [17:0] fac3g, fac3r, fac3b;

always @(posedge clk) begin
	fac3g <= $signed({1'b0, fb17});
	fac3r <= $signed({1'b0, tr[32:16]});
	fac3b <= $signed({1'b0, tbb[32:16]});
	c3    <= c2;
	fg3   <= $signed({2'b0, fh[31:24]}) - 10'sd128;
end

// Reflector desaturation. The mirror of the ink dials: the weight is the
// pixel's LIGHTNESS squared, so it works on the reflector and the off elements
// and leaves the ink alone. Pulls toward luma, which is what taking saturation
// out of a surface means.
function automatic [7:0] k_refsat(input [2:0] i);
	case (i)
		3'd0: k_refsat = 8'd0;     // off - brickboy's own reflector
		3'd1: k_refsat = 8'd32;    // 12%
		3'd2: k_refsat = 8'd64;    // 25%
		3'd3: k_refsat = 8'd96;
		3'd4: k_refsat = 8'd128;   // half
		3'd5: k_refsat = 8'd160;
		3'd6: k_refsat = 8'd192;
		3'd7: k_refsat = 8'd255;   // fully grey
	endcase
endfunction

// Ink tone. The weight is the pixel's darkness squared, so it concentrates on
// the element and leaves the reflector alone.
//
// One dial per channel. Three fixed ratios were tried and all three were wrong -
// holding blue back added a blue cast, holding green back saturated into a deep
// green that would not sink, and equal ratios land on black without passing
// through navy because the ink's blue is already its lowest channel. The right
// mix depends on the panel in front of the person looking at it, which is not
// something to guess at from here.
function automatic [7:0] luma8(input [23:0] c);
	reg [16:0] s;
	begin
		s = 17'd77*c[23:16] + 17'd150*c[15:8] + 17'd29*c[7:0] + 17'd128;
		luma8 = s[15:8];
	end
endfunction

// ---- s4: luma and the two weights ------------------------------------------
// The ink and the reflector dials both need the pixel's luma, then its square,
// then a multiply, then a per-channel difference. That is four dependent
// operations and it does not close in one clock at 33.5 MHz - it cost -7.7 ns
// when it was all in the output stage. Two stages, and the output stage does
// nothing but add.
reg [7:0]  lum4;
reg [23:0] c4;
reg signed [9:0] fg4;
reg signed [17:0] fac4r, fac4g, fac4b;

wire [7:0] lum_now = luma8(c3);

always @(posedge clk) begin
	lum4  <= lum_now;
	c4    <= c3;
	fg4   <= fg3;
	fac4r <= fac3r; fac4g <= fac3g; fac4b <= fac3b;
end

// ---- s5: the per-channel offsets -------------------------------------------
wire [7:0]  ink_d  = 8'd255 - lum4;
wire [15:0] ink_w  = ink_d * ink_d;
wire [15:0] rs_w   = lum4 * lum4;
wire [15:0] ink_ar = ink_w[15:8] * k_ink(set_ink_r);
wire [15:0] ink_ag = ink_w[15:8] * k_ink(set_ink_g);
wire [15:0] ink_ab = ink_w[15:8] * k_ink(set_ink_b);
wire [15:0] rs_a   = rs_w[15:8] * k_refsat(set_refsat);

function automatic signed [11:0] desat(input [7:0] v, input [7:0] l,
                                       input [7:0] amt);
	reg signed [19:0] d;
	begin
		d = ($signed({1'b0, l}) - $signed({1'b0, v})) * $signed({1'b0, amt})
		    + 20'sd128;
		desat = d[19:8];
	end
endfunction

reg signed [11:0] off5r, off5g, off5b;
reg [23:0] c5;
reg signed [9:0] fg5;
reg signed [17:0] fac5r, fac5g, fac5b;

always @(posedge clk) begin
	off5r <= $signed({4'b0, ink_ar[15:8]}) - desat(c4[23:16], lum4, rs_a[15:8]);
	off5g <= $signed({4'b0, ink_ag[15:8]}) - desat(c4[15:8],  lum4, rs_a[15:8]);
	off5b <= $signed({4'b0, ink_ab[15:8]}) - desat(c4[7:0],   lum4, rs_a[15:8]);
	c5    <= c4;
	fg5   <= fg4;
	fac5r <= fac4r; fac5g <= fac4g; fac5b <= fac4b;
end

// ---- s6: apply ------------------------------------------------------------
function automatic [7:0] sat8(input signed [19:0] v);
	sat8 = (v < 0) ? 8'd0 : (v > 255) ? 8'd255 : v[7:0];
endfunction

function automatic [7:0] apply(input [7:0] v, input signed [17:0] f,
                               input signed [9:0] g, input signed [11:0] off);
	reg signed [27:0] p;
	reg signed [19:0] q;
	begin
		p = $signed({10'b0, v}) * f + 28'sd32768;
		q = $signed(p[27:16]) + (($signed({10'b0, K_FGRAIN}) * g) >>> 7)
		    - $signed(off);
		apply = sat8(q);
	end
endfunction

always @(posedge clk) begin
	out_rgb <= { apply(c5[23:16], fac5r, fg5, off5r),
	             apply(c5[15:8],  fac5g, fg5, off5g),
	             apply(c5[7:0],   fac5b, fg5, off5b) };
end

endmodule
