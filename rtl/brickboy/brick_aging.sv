// BrickBoy global panel-ageing terms from FRAG_DEFECTS.
// Defaults are all zero. MiSTer's four choices sample the original continuous
// controls at 0, .25, .50 and 1.0.
(* multstyle = "logic" *)
module brick_aging (
	input  wire        clk,
	input  wire [9:0]  gx,
	input  wire [9:0]  gy,
	input  wire [1:0]  dimming,
	input  wire [1:0]  frontlight,
	input  wire [1:0]  backlight,
	input  wire [1:0]  contrast_fade,
	input  wire [23:0] in_rgb,
	output reg  [23:0] out_rgb
);

function automatic [7:0] level8(input [1:0] v);
	case (v)
		2'd0: level8 = 8'd0;
		2'd1: level8 = 8'd64;
		2'd2: level8 = 8'd128;
		default: level8 = 8'd255;
	endcase
endfunction

function automatic [7:0] sat8(input signed [19:0] v);
	sat8 = (v < 0) ? 8'd0 : (v > 255) ? 8'd255 : v[7:0];
endfunction

// 1-smoothstep(0,.22,edgeDist), sampled in sixteenths. The final zero entry
// covers the rest of the panel, exactly like the shader's clamp.
function automatic [7:0] bleed_lut(input [3:0] i);
	case (i)
		4'd0: bleed_lut=8'd255; 4'd1: bleed_lut=8'd252;
		4'd2: bleed_lut=8'd244; 4'd3: bleed_lut=8'd230;
		4'd4: bleed_lut=8'd211; 4'd5: bleed_lut=8'd188;
		4'd6: bleed_lut=8'd161; 4'd7: bleed_lut=8'd134;
		4'd8: bleed_lut=8'd106; 4'd9: bleed_lut=8'd79;
		4'd10: bleed_lut=8'd55; 4'd11: bleed_lut=8'd34;
		4'd12: bleed_lut=8'd18; 4'd13: bleed_lut=8'd7;
		4'd14: bleed_lut=8'd1; default: bleed_lut=8'd0;
	endcase
endfunction

reg [23:0] c0;
reg [9:0] x0, y0;
reg [7:0] d0, f0, b0, cf0;
always @(posedge clk) begin
	c0 <= in_rgb; x0 <= gx; y0 <= gy;
	d0 <= level8(dimming); f0 <= level8(frontlight);
	b0 <= level8(backlight); cf0 <= level8(contrast_fade);
end

// Module UV includes BrickBoy's four-native-dot margin: 16 output pixels.
wire [9:0] mx = x0 + 10'd16;
wire [9:0] my = y0 + 10'd16;
wire [9:0] ex = (mx < 10'd336) ? mx : 10'd672 - mx;
wire [9:0] ey = (my < 10'd304) ? my : 10'd608 - my;
wire [17:0] exn_w = ex * 18'd390; // 256/672 in Q10
wire [17:0] eyn_w = ey * 18'd431; // 256/608 in Q10
wire [7:0] exn = exn_w[17:10];
wire [7:0] eyn = eyn_w[17:10];
wire [7:0] edge_dist = (exn < eyn) ? exn : eyn;
wire [3:0] bi = (edge_dist >= 8'd56) ? 4'd15 : edge_dist[5:2];

wire [17:0] uy_w = (10'd592 - my) * 18'd431;
wire [7:0] uy = uy_w[17:10];
wire signed [16:0] fl_slope = -17'sd77 + (($signed({1'b0,uy}) * 17'sd115) >>> 8);
wire signed [25:0] fl_w = $signed({1'b0,f0}) * fl_slope;
wire [16:0] dim_w = d0 * 8'd166;
wire signed [10:0] factor_now = 11'sd256 - $signed({3'b0,dim_w[15:8]}) + (fl_w >>> 8);
wire [15:0] ba_w = bleed_lut(bi) * b0;
wire [15:0] add_w = ba_w[15:8] * 8'd115;

reg [23:0] c1;
reg signed [10:0] factor1;
reg [7:0] add1, fade1;
always @(posedge clk) begin
	c1 <= c0;
	factor1 <= factor_now;
	add1 <= add_w[15:8];
	fade1 <= cf0 >> 1;
end

function automatic [7:0] apply(input [7:0] v);
	reg signed [20:0] scaled;
	reg signed [20:0] faded;
	begin
		scaled = $signed({1'b0,v}) * factor1 + 21'sd128;
		faded = scaled[20:8] + add1;
		faded = faded + ((($signed(21'sd128) - faded) * $signed({1'b0,fade1})) >>> 8);
		apply = sat8(faded);
	end
endfunction

always @(posedge clk) out_rgb <= {apply(c1[23:16]), apply(c1[15:8]), apply(c1[7:0])};

endmodule
