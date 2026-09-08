// BrickBoy dust/blemish specks from FRAG_DEFECTS. The source hash is baked at
// its native 160x144 cell resolution with defects.seed=7. Each menu step selects
// the exact source threshold for dust=.25, .50 or 1.0.
module brick_dust (
	input  wire        clk,
	input  wire [9:0]  gx,
	input  wire [9:0]  gy,
	input  wire [1:0]  level,
	input  wire [23:0] in_rgb,
	output reg  [23:0] out_rgb
);

// defects.slang uses module UV, including the four-native-dot reflector margin.
// MiSTer presents only the 640x576 active region, hence the 16-pixel offset.
wire [9:0] mx = gx + 10'd16;
wire [9:0] my = 10'd592 - gy; // source UV is y-up
wire [17:0] cx_w = mx * 18'd160;
wire [17:0] cy_w = my * 18'd144;
wire [7:0] cx = cx_w / 10'd672;
wire [7:0] cy = cy_w / 10'd608;
wire [14:0] address = cy * 8'd160 + cx;

// Four 2-bit cells per byte avoids a Quartus 17 width warning for every HEX
// digit while retaining exactly the same 46,080 stored bits.
// Implement this sparse ROM in logic in the combined core, reserving M10Ks
// for upstream frame stores and Vinegar. Data/read latency are unchanged.
(* romstyle = "logic" *) reg [7:0] dust_map [0:5759];
initial $readmemh("rtl/brickboy/brick_dust_map.hex", dust_map);

reg [7:0] word0;
reg [1:0] slot0, level0;
reg [23:0] rgb0;
reg [1:0] code0;
always @(*) begin
	case (slot0)
		2'd0: code0 = word0[1:0];
		2'd1: code0 = word0[3:2];
		2'd2: code0 = word0[5:4];
		default: code0 = word0[7:6];
	endcase
end

always @(posedge clk) begin
	word0 <= dust_map[address[14:2]];
	slot0 <= address[1:0];
	level0 <= level;
	rgb0 <= in_rgb;
	out_rgb <= ((level0 == 2'd1 && code0 == 2'd3) ||
	            (level0 == 2'd2 && code0 >= 2'd2) ||
	            (level0 == 2'd3 && code0 >= 2'd1))
	         ? {2'b00,rgb0[23:18],2'b00,rgb0[15:10],2'b00,rgb0[7:2]}
	         : rgb0;
end

endmodule
