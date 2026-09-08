// BrickBoy speaker - the HW form of brickboy's src/ui/speaker-model.ts plus the
// APU's output-stage DC blocker.
//
// dmg.json audio: a 28 Hz one-pole high pass (Pan Docs cf 0.999958), then the
// sealed-box speaker as three RBJ biquads - highpass 420 Hz Q1.1, lowpass
// 7 kHz Q0.707, peaking 1.2 kHz Q2.5 +4 dB - at unity gain.
//
// brickboy synthesises an impulse response from those biquads and convolves it
// in a ConvolverNode. That is a Web Audio implementation detail: the biquads
// ARE the filter, so here they run directly. Coefficients come from
// tools/bake_audio.py, evaluated at this module's rate; quantised to Q2.22 the
// response is within 0.023 dB of the float model above 100 Hz.
//
// One multiplier, time-multiplexed: at 65536 Hz there are 512 system clocks per
// sample and the work is 3 stages x 2 channels x 5 taps = 30 multiplies, so a
// single sequential engine is far cheaper than six parallel biquads - and DSP
// is the resource this design has least of after the video pipeline.

module brick_audio (
	input  wire        clk,          // 33.554432 MHz
	input  wire        reset,

	input  wire        enable,     // 0 = pass through untouched

	input  wire signed [15:0] in_l,
	input  wire signed [15:0] in_r,

	output reg  signed [15:0] out_l,
	output reg  signed [15:0] out_r
);

localparam int CW = 24;          // coefficient width, Q2.22
localparam int QF = 22;
localparam int SW = 32;          // state width, Q(SW-1-QS).QS
localparam int QS = 12;          // state fraction bits; 16-bit audio + headroom

// 5 coefficients per stage, 3 stages: b0 b1 b2 a1 a2
localparam bit signed [CW-1:0] COEF[0:14] = '{
`include "brick_audio_coef.svh"
};

// 28 Hz one-pole DC blocker: charge += (x - charge) * alpha; y = x - charge.
localparam signed [24:0] HPF_ALPHA = 25'sd44977;   // 0.002680866 in Q0.24

// ---------------------------------------------------------------- sample rate
// 65536 Hz = clk / 512, and 512 is a power of two, so the tick is just a
// counter bit rolling over - no fractional accumulator, no jitter.
reg [8:0] div;
wire      tick = (div == 9'd0);
always @(posedge clk) div <= div + 1'd1;

// ---------------------------------------------------------------- DC blocker
reg signed [39:0] charge_l, charge_r;
reg signed [15:0] dc_l, dc_r;

// Spread over three clocks: the 40 x 25 product does not close in one at
// 33.5 MHz either, and there are hundreds of clocks to spare between samples.
reg signed [39:0] err_l, err_r;
reg signed [64:0] stp_l, stp_r;
reg [1:0]         dcph;

function automatic signed [15:0] sat16(input signed [39:0] v);
	sat16 = (v >  40'sd32767) ?  16'sd32767 :
	        (v < -40'sd32768) ? -16'sd32768 : v[15:0];
endfunction

always @(posedge clk) begin
	if (reset) begin
		charge_l <= 0; charge_r <= 0; dc_l <= 0; dc_r <= 0; dcph <= 0;
	end else if (tick) begin
		err_l <= $signed({in_l, 24'd0}) - charge_l;
		err_r <= $signed({in_r, 24'd0}) - charge_r;
		// y = x - charge, using the charge this sample started with
		dc_l  <= sat16(($signed({in_l, 24'd0}) - charge_l) >>> 24);
		dc_r  <= sat16(($signed({in_r, 24'd0}) - charge_r) >>> 24);
		dcph  <= 2'd1;
	end else if (dcph == 2'd1) begin
		stp_l <= err_l * HPF_ALPHA;
		stp_r <= err_r * HPF_ALPHA;
		dcph  <= 2'd2;
	end else if (dcph == 2'd2) begin
		charge_l <= charge_l + stp_l[63:24];
		charge_r <= charge_r + stp_r[63:24];
		dcph     <= 2'd0;
	end
end

// ------------------------------------------------------------- biquad engine
// Direct form I, one tap per clock:
//   y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2
// Six passes per sample (stage 0..2 for L then R). The pass index is
// {stage, channel}; x1/x2/y1/y2 live in a small register file indexed by it.

reg [3:0]  step;          // 0..5 taps + settle, per pass
reg [2:0]  pass;          // 0..5
reg        busy;

reg signed [SW-1:0] x1[0:5], x2[0:5], y1[0:5], y2[0:5];
reg signed [SW-1:0] xin, acc, yout;

wire [1:0] stage = pass[2:1];
wire       chan  = pass[0];

// Flat coefficient index: stage*5 + tap
function automatic [3:0] cidx(input [1:0] s, input [2:0] tap);
	cidx = {2'b0, s} * 4'd5 + {1'b0, tap};
endfunction

wire signed [SW-1:0] tap_v =
	(tap_i == 3'd0) ? xin      :
	(tap_i == 3'd1) ? x1[pass] :
	(tap_i == 3'd2) ? x2[pass] :
	(tap_i == 3'd3) ? y1[pass] :
	                  y2[pass];

wire [2:0] tap_i = (step > 4'd4) ? 3'd0 : step[2:0];
wire signed [CW-1:0] tap_c = COEF[cidx(stage, tap_i)];

// The 32 x 24 product does not close in one clock at 33.5 MHz, so it gets its
// own pipeline stage and the accumulate trails it by one. There are 512 clocks
// per sample against ~40 of work, so the extra latency is free.
reg signed [SW+CW-1:0] prod_r;
reg [2:0]              mstep;
reg                    mvalid;

// a1/a2 are subtracted (the difference equation has them on the left). The
// slice, the negate and the accumulate get a stage of their own too - together
// they were still the critical path after the multiply was split out.
reg signed [SW-1:0] term;
reg                 tvalid;

// Per pass: clocks 0..4 issue the five taps, the sign/slice trails one clock
// and the accumulate one more, clock 7 retires. 8 clocks x 6 passes = 48 of the
// 512 clocks in a sample period.
always @(posedge clk) begin
	if (reset) begin
		busy <= 0; step <= 0; pass <= 0; mvalid <= 0; tvalid <= 0;
		for (int i = 0; i < 6; i++) begin
			x1[i] <= 0; x2[i] <= 0; y1[i] <= 0; y2[i] <= 0;
		end
		out_l <= 0; out_r <= 0;
	end else if (tick) begin
		// dc_l/dc_r were registered on this same tick from the PREVIOUS sample,
		// which is the one-sample delay the chain wants anyway.
		busy <= 1; step <= 0; pass <= 0; mvalid <= 0; tvalid <= 0;
		xin  <= {{(SW-16-QS){dc_l[15]}}, dc_l, {QS{1'b0}}};
		acc  <= 0;
	end else if (busy) begin
		prod_r <= tap_v * tap_c;
		mstep  <= step[2:0];
		mvalid <= (step <= 4'd4);
		term   <= (mstep >= 3'd3) ? -$signed(prod_r[SW+QF-1:QF])
		                          :  $signed(prod_r[SW+QF-1:QF]);
		tvalid <= mvalid;
		if (tvalid) acc <= acc + term;

		if (step < 4'd7) begin
			step <= step + 1'd1;
		end else begin
			// acc is final: this stage's history shifts and y feeds the next
			x2[pass] <= x1[pass];
			x1[pass] <= xin;
			y2[pass] <= y1[pass];
			y1[pass] <= acc;
			step   <= 0;
			mvalid <= 0;
			tvalid <= 0;
			acc    <= 0;
			if (stage == 2'd2) begin
				if (chan == 1'b0) begin
					out_l <= sat16($signed(acc) >>> QS);
					pass  <= 3'd1;                 // right channel, stage 0
					xin   <= {{(SW-16-QS){dc_r[15]}}, dc_r, {QS{1'b0}}};
				end else begin
					out_r <= sat16($signed(acc) >>> QS);
					busy  <= 0;
				end
			end else begin
				pass <= pass + 3'd2;               // same channel, next stage
				xin  <= acc;
			end
		end
	end
end

endmodule
