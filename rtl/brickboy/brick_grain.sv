// Reflector sheet grain - brickboy's reflector.ts, split by band.
//
// reflector.ts bakes three bands into one texture at 4 texels per dot:
//
//   fine   ~0.45 dot   the わら半紙 read, sigma 0.307 of full scale
//   mottle ~5 dots     evaluated once per dot and bilinearly expanded
//   blotch ~18 dots    likewise, at half weight
//
// The whole module at 4 texels/dot is 3.2 Mbit - more than this device has - so
// the bands are split the way reflector.ts already splits them internally:
//
//   fine    generated at runtime, one hash per 2x2 output pixels. reflector.ts
//           uses two decorrelated value-noise octaves at 0.45 and 0.77 dot; a
//           blocky hash at 0.5 dot has the same feature size and the same sigma,
//           and at 0.11 mm on the Pocket's panel the difference is well under
//           what the panel resolves.
//   coarse  baked by tools/bake_grain.py using reflector.ts's own hash2/vnoise/
//           fbm and seed, on a lattice every 4 dots, bilinearly interpolated
//           here exactly as reflector.ts interpolates its per-dot `coarse`.
//
// What this replaces: one independent hash per OUTPUT pixel and no coarse band
// at all. That is white noise - it averages away completely over any area, so
// on the Pocket it read as no grain at all, while brickboy's stays visible.
// Measured on brickboy's own renderfarm output at 4x: the per-dot grain sigma is
// 0.87% of mean and still 0.52% after averaging over 16x16 dots. White noise
// would be 0.05%. The surviving 60% is the coarse band, and it was missing.
//
// The grain field is not registered to the dot grid - it is a separate physical
// sheet behind the LC - so the pipeline delay through here does not need to line
// up with the grid stage to the pixel.

module brick_grain (
	input  wire        clk,
	input  wire [9:0]  gx,      // output pixel within the game area, 0..639
	input  wire [9:0]  gy,      // 0..575
	input  wire [7:0]  seed,
	input  wire [2:0]  contrast,   // drives the visible bands only; 2 = brickboy
	output reg  signed [9:0] g  // +-127 = +-1 of the stored grain range
);

`include "brick_grain_coarse.svh"

localparam int COLS = 41;      // lattice columns; 160 dots / 4 + 1
// Scales the uniform hash so the fine band matches reflector.ts's sigma at the
// DOT, not at the texel: the hash's 2x2 blocks are independent where value noise
// is correlated, so it would otherwise fade faster than the original under any
// averaging - and sub-dot detail is below what the Pocket's panel resolves
// anyway. tools/bake_grain.py prints this number.
localparam [8:0] K_FINE = 9'd167;

// The band the 4-dot lattice throws away, put back at runtime.
//
// reflector.ts evaluates its coarse band once per DOT; sampling it every 4 dots
// and interpolating drops everything between 1 and 3 dots - measured, sigma
// 0.0543 of full scale with correlation +0.70 at one dot and +0.04 at three.
// That is the band that makes individual dots differ in density from their
// neighbours, and without it the sheet reads as an even sand grain under a few
// big blotches, with nothing in between. Storing the lattice at 2 dots instead
// would be exact but costs 7 more M10K against 91% already used, so this is one
// hash per dot: shorter correlation than the original (1 dot against 2) at no
// memory at all. 0.0543 * 127 / (255/sqrt(12)) = 24/256.
localparam [8:0] K_MID = 9'd24;
localparam int   BG_UNIT = 256;   // band_gain at brickboy's own weight

// ---- s0: lattice address and the fine hash's first mix ----------------------
// One lattice step is 4 dots = 16 output pixels, so the cell index is gx[9:4]
// and the interpolation weight is gx[3:0].

wire [5:0] cx = gx[9:4];
wire [5:0] cy = gy[9:4];
wire [3:0] fx = gx[3:0];
wire [3:0] fy = gy[3:0];

// cy * 41 = cy<<5 + cy<<3 + cy
wire [11:0] rowbase = {cy, 5'b0} + {cy, 3'b0} + cy;

reg [11:0] a0, a1;
reg [3:0]  fx1, fy1;

// reflector.ts hash2, on the 2x2 output-pixel block, and again per native dot.
wire [31:0] hseed = seed * 32'd1442695041;
wire [31:0] hmix  = {22'b0, gx[9:1]} * 32'd374761393
                  + {22'b0, gy[9:1]} * 32'd668265263 + hseed;
wire [31:0] mmix  = {23'b0, gx[9:2]} * 32'd374761393
                  + {23'b0, gy[9:2]} * 32'd668265263 + hseed + 32'd91;

reg [31:0] h1, m1;

always @(posedge clk) begin
	a0  <= rowbase + cx;
	a1  <= rowbase + cx + 12'd1;
	fx1 <= fx;
	fy1 <= fy;
	h1  <= hmix ^ (hmix >> 13);
	m1  <= mmix ^ (mmix >> 13);
end

// ---- s1: both lattice columns, and the hash's second mix -------------------
// Two copies so the left and right lattice columns come out in the same cycle;
// one array with two read ports turns the ROM into logic. Each word holds the
// two lattice ROWS the bilinear needs: {row cy+1, row cy}.
// 36 lattice rows of PAIRS (576 output rows / 16), each word carrying rows
// cy and cy+1, so the 37th lattice row lives in the last word's high half.
reg [15:0] rom_a[0:COLS*36-1];
reg [15:0] rom_b[0:COLS*36-1];
initial begin
	rom_a = GRAIN_COARSE;
	rom_b = GRAIN_COARSE;
end

reg [15:0] q0, q1;
reg [3:0]  fx2, fy2;
reg [31:0] h2, m2;

always @(posedge clk) begin
	q0  <= rom_a[a0];
	q1  <= rom_b[a1];
	fx2 <= fx1;
	fy2 <= fy1;
	h2  <= h1 * 32'd1274126177;
	m2  <= m1 * 32'd1274126177;
end

// ---- s2: interpolate down the two columns, and finish the hash -------------
wire signed [8:0] c00 = {q0[7],  q0[7:0]};    // row cy,   column cx
wire signed [8:0] c01 = {q0[15], q0[15:8]};   // row cy+1, column cx
wire signed [8:0] c10 = {q1[7],  q1[7:0]};
wire signed [8:0] c11 = {q1[15], q1[15:8]};

function automatic signed [8:0] lerp4(input signed [8:0] a,
                                      input signed [8:0] b,
                                      input [3:0] f);
	reg signed [13:0] d;
	begin
		d = ($signed(b) - $signed(a)) * $signed({1'b0, f});
		lerp4 = a + d[12:4];
	end
endfunction

reg signed [8:0] cl, cr;
reg [3:0]        fx3;
reg [31:0]       h3, m3;

always @(posedge clk) begin
	cl  <= lerp4(c00, c01, fy2);
	cr  <= lerp4(c10, c11, fy2);
	fx3 <= fx2;
	h3  <= h2 ^ (h2 >> 16);
	m3  <= m2 ^ (m2 >> 16);
end

// ---- s3: interpolate across, add the fine band -----------------------------
wire signed [8:0]  coarse = lerp4(cl, cr, fx3);
wire signed [8:0]  fine   = $signed({1'b0, h3[31:24]}) - 9'sd128;
wire signed [8:0]  mid    = $signed({1'b0, m3[31:24]}) - 9'sd128;

// Driving all three bands together is what made turning the grain up produce
// water stains instead of grain. The blotch band is 18-36 dots across, so
// scaling it scales a slow, smooth blob; the fine band is half a dot, below what
// the panel resolves at any amplitude. Between them the screen gets blotchier
// without ever getting grainier, which is the opposite of the point.
//
// So above Normal the knob drives only the bands that read as grain - the
// half-dot fine band and the per-dot mid band - while the coarse band stops at
// brickboy's own weight. Below Normal everything comes down together, so Off is
// actually off.
//
// Leaving the coarse band always on (which this did) is worse than useless: the
// grain lands on an 8-bit output, so it can only shift a pixel by whole levels,
// and the coarse band alone varies far too slowly to dither that. With the fast
// bands off it posterises into flat plateaus of -1, 0 and +1 - contour bands the
// size of the blotches, which is the camouflage.
function automatic [9:0] band_gain(input [2:0] i);
	case (i)
		3'd0: band_gain = 10'd0;     // off
		3'd1: band_gain = 10'd128;   // half
		3'd2: band_gain = 10'd256;   // brickboy's own
		3'd3: band_gain = 10'd384;
		3'd4: band_gain = 10'd512;   // 2x
		3'd5: band_gain = 10'd768;   // 3x
		3'd6: band_gain = 10'd1023;  // 4x
		3'd7: band_gain = 10'd1023;
	endcase
endfunction

wire [9:0] bg = band_gain(contrast);
wire [9:0] cg = (bg > 10'd256) ? 10'd256 : bg;   // coarse stops at brickboy's

wire signed [17:0] fine_s = fine * $signed({1'b0, K_FINE});
wire signed [17:0] mid_s  = mid * $signed({1'b0, K_MID});
wire signed [28:0] vis_s  = ($signed(fine_s[16:8]) + $signed(mid_s[16:8]))
                            * $signed({1'b0, bg});
wire signed [19:0] crs_s  = coarse * $signed({1'b0, cg});
wire signed [10:0] sum    = crs_s[18:8] + vis_s[18:8];

// The two bands are independent, so their sum reaches +-152 while either alone
// stays inside +-127. Clamping to +-127 - which this did - does not just cap the
// amplitude: wherever the coarse band is near its extreme the sum saturates and
// the FINE band is flattened out with it, leaving smooth patches shaped exactly
// like the coarse blotches. That is the water-stain look, and it also collapses
// the range of dot densities to a single tone inside those patches. Carry the
// full range instead; 127 still means 1.0, the sum simply passes 1.0 sometimes,
// which is what a sum of two noise bands does.
always @(posedge clk) begin
	g <= (sum >  11'sd511) ?  10'sd511 :
	     (sum < -11'sd511) ? -10'sd511 : sum[9:0];
end

endmodule
