// Dead electrode lines - brickboy's FRAG_DEFECTS dead-line block.
//
// A ribbon or heat-seal bond failure floats a whole electrode, so its LC relaxes
// to the un-driven state: on a normally-white reflective panel that is the light
// reflector, which is why real dead lines are overwhelmingly white. A minority
// settle dark instead, from leakage bias on the floating electrode
// (deadLineLit 0.06).
//
// Everything about WHICH lines die is a pure function of the line index and the
// seed - the per-line hash, the spatial clumping that makes dropouts arrive as
// contiguous bands, the surveyed edge concentration (the flex is lap-bonded
// along one edge and a lap joint peels from the ends of its overlap), and the
// dial's ^2.2 curve. None of that has to run on the FPGA: tools/bake_deadlines.py
// evaluates the shader's own functions and emits one dead/alive bit per line per
// severity step, plus 16 bits of per-line state.
//
// Where it is applied is the one deliberate difference. The shader is a
// screen-space pass, so it draws dead lines AFTER the grid and re-applies a dot
// mask to them. Here the dead shade is substituted into the cell BEFORE the grid
// stage, which is where the failure physically is - the electrode, not the
// picture. The dot structure, the inter-pixel gaps and the drop shadows the
// neighbouring live dots cast onto the dead line all then follow for free,
// instead of having to be reconstructed.
//
// Flicker (deadFlicker) is not implemented yet: it needs a time input and the
// static layout is worth confirming on hardware first.

(* multstyle = "logic" *)
module brick_deadline (
	input  wire        clk,

	input  wire [2:0]  sev,          // severity dial, 0 = none
	input  wire [1:0]  flicker,      // 0 stable, 1..3 increasing instability
	input  wire [1:0]  edge_bias,
	input  wire [1:0]  lit_ratio,
	input  wire [1:0]  row_ratio,
	input  wire [7:0]  phase,        // advances once per displayed frame
	input  wire [7:0]  nx,           // native column 0..159
	input  wire [7:0]  ny,           // native row 0..143
	input  wire [23:0] in_rgb,       // the cell from the line buffer

	output reg  [23:0] out_rgb
);

`include "brick_dl_col.svh"
`include "brick_dl_row.svh"
`include "brick_dl_col_st.svh"
`include "brick_dl_row_st.svh"
`include "brick_dl_col_opt.svh"
`include "brick_dl_row_opt.svh"
`include "brick_dl_col_lit_opt.svh"
`include "brick_dl_row_lit_opt.svh"

// The un-driven reflector, and the colour stage's darkest output for the few
// lines that settle stuck-on. brickboy uses uReflector and uDmgPalette[3]; the
// substitution happens after the colour stage here, so these are that stage's
// own values rather than the raw palette.
localparam [23:0] DL_OFF = {8'd237, 8'd217, 8'd149};
localparam [23:0] DL_LIT = {8'd51,  8'd75,  8'd45 };

function automatic [7:0] mix8(input [7:0] a, input [7:0] b, input [7:0] k);
	reg signed [17:0] d;
	begin
		d = ($signed({1'b0, b}) - $signed({1'b0, a})) * $signed({1'b0, k}) + 18'sd128;
		mix8 = a + d[15:8];
	end
endfunction

// ---- s0: is this line dead, and with what state --------------------------
reg        d_col, d_row;
reg [15:0] st_col, st_row;
reg [23:0] c0;
reg [7:0]  pos_col, pos_row;

always @(posedge clk) begin
	d_col  <= DL_COL_OPT[{edge_bias,sev[1:0]}][nx];
	d_row  <= DL_ROW_OPT[{edge_bias,row_ratio,sev[1:0]}][ny];
	st_col <= DL_COL_ST[nx];
	st_row <= DL_ROW_ST[ny];
	// Position ALONG each line, for the contact-resistance gradient: a column
	// fades down the screen, a row fades across it.
	pos_col <= ny;
	pos_row <= nx;
	c0     <= in_rgb;
end

// ---- s1: gradient and strength -------------------------------------------
// vGrad = mix(gA, gB, along), both ends 0.55..1.0 from the seed, so one end of
// the line is always weaker - contact resistance along the electrode.
// recip is 255/span in Q0.8, so the position along the line becomes the blend
// weight with a multiply. A divide here is a divide per pixel, and it cost the
// whole clock: -11.5 ns.
function automatic [7:0] grad_of(input [15:0] st, input [7:0] along,
                                 input [8:0] recip);
	reg [7:0]  ga, gb;
	reg [16:0] t;
	begin
		ga = 8'd140 + {st[15:12], 4'b0} - {4'b0, st[15:12]};   // 0.55..1.0 x255
		gb = 8'd140 + {st[11:8],  4'b0} - {4'b0, st[11:8]};
		t  = along * recip;
		grad_of = mix8(ga, gb, (t[16:8] > 9'd255) ? 8'd255 : t[15:8]);
	end
endfunction

reg [7:0]  k_col, k_row;
reg [23:0] c1;
reg        lit_col, lit_row;

wire [7:0] gc = grad_of(st_col, pos_col, 9'd453);   // 255/144 in Q0.8
wire [7:0] gr = grad_of(st_row, pos_row, 9'd408);   // 255/160 in Q0.8

// A failing bond does not flicker as uniform video noise: each electrode has
// its own intermittent contact. Reuse the baked per-line state as its phase
// and rate, then attenuate the failure strength on selected frames.
function automatic [7:0] flicker_scale(input [1:0] level,
                                        input [15:0] st, input [7:0] t);
	reg [2:0] wave;
	begin
		wave = t[4:2] + st[10:8];
		case (level)
			2'd0: flicker_scale = 8'd255;
			2'd1: flicker_scale = wave[2:1] ? 8'd255 : 8'd224;
			2'd2: flicker_scale = wave[2] ? 8'd255 : (wave[1] ? 8'd208 : 8'd144);
			default: flicker_scale = wave[2] ? (wave[0] ? 8'd255 : 8'd176)
			                                  : (wave[1] ? 8'd112 : 8'd40);
		endcase
	end
endfunction

wire [7:0] kb_col = d_col ? mix8(8'd0, {st_col[6:0], 1'b0}, gc) : 8'd0;
wire [7:0] kb_row = d_row ? mix8(8'd0, {st_row[6:0], 1'b0}, gr) : 8'd0;
wire [15:0] kf_col = kb_col * flicker_scale(flicker, st_col, phase);
wire [15:0] kf_row = kb_row * flicker_scale(flicker, st_row, phase ^ 8'h59);

always @(posedge clk) begin
	// drop (0.86..1.0) x gradient
	k_col   <= (flicker == 0) ? kb_col : kf_col[15:8];
	k_row   <= (flicker == 0) ? kb_row : kf_row[15:8];
	lit_col <= DL_COL_LIT_OPT[lit_ratio][pos_row];
	lit_row <= DL_ROW_LIT_OPT[lit_ratio][pos_col];
	c1      <= c0;
end

// ---- s2: substitute -------------------------------------------------------
// A column and a row can both be dead where they cross; the column is applied
// second so the vertical failure wins there, which is what the photos show
// (columns outnumber rows 7:1 and are the more complete failure).
wire [23:0] dl_r = lit_row ? DL_LIT : DL_OFF;
wire [23:0] dl_c = lit_col ? DL_LIT : DL_OFF;

wire [23:0] step_r = { mix8(c1[23:16], dl_r[23:16], k_row),
                       mix8(c1[15:8],  dl_r[15:8],  k_row),
                       mix8(c1[7:0],   dl_r[7:0],   k_row) };

always @(posedge clk) begin
	out_rgb <= { mix8(step_r[23:16], dl_c[23:16], k_col),
	             mix8(step_r[15:8],  dl_c[15:8],  k_col),
	             mix8(step_r[7:0],   dl_c[7:0],   k_col) };
end

endmodule
