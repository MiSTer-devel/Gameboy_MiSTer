// BrickBoy polariser rot / "Vinegar Syndrome".
//
// The ROMs are direct evaluations of Kathoc's FRAG_DEFECTS equations. Centre
// retains seed 7 at native-dot nodes. Blob mode selects one of three complete
// original unit-seed layouts (3, 7, 9), sampled at half-native nodes because its
// contours are broad. Both are bilinearly expanded with 8-bit opacity.

module brick_vinegar (
	input  wire        clk,
	input  wire [9:0]  gx,
	input  wire [9:0]  gy,
	input  wire [1:0]  depth,
	input  wire        blob_mode,
	input  wire [2:0]  seed_sel,
	input  wire [23:0] in_rgb,
	output reg  [23:0] out_rgb
);

// Depth/layout is part of the address, not a wide parallel word. This packs
// the exact same 8-bit samples more efficiently into M10K blocks.
reg [7:0] centre_ee[0:17738];
reg [7:0] centre_eo[0:17519];
reg [7:0] centre_oe[0:17495];
reg [7:0] centre_oo[0:17279];
reg [7:0] blob_ee[0:13652];
reg [7:0] blob_eo[0:13319];
reg [7:0] blob_oe[0:13283];
reg [7:0] blob_oo[0:12959];
initial begin
	$readmemh("rtl/brickboy/brick_vinegar_centre_ee.hex", centre_ee);
	$readmemh("rtl/brickboy/brick_vinegar_centre_eo.hex", centre_eo);
	$readmemh("rtl/brickboy/brick_vinegar_centre_oe.hex", centre_oe);
	$readmemh("rtl/brickboy/brick_vinegar_centre_oo.hex", centre_oo);
	$readmemh("rtl/brickboy/brick_vinegar_blob_ee.hex", blob_ee);
	$readmemh("rtl/brickboy/brick_vinegar_blob_eo.hex", blob_eo);
	$readmemh("rtl/brickboy/brick_vinegar_blob_oe.hex", blob_oe);
	$readmemh("rtl/brickboy/brick_vinegar_blob_oo.hex", blob_oo);
end

wire [7:0] cnx = gx[9:2];
wire [7:0] cny = gy[9:2];
wire [7:0] cix_even = {1'b0, cnx[7:1]} + cnx[0];
wire [7:0] cix_odd  = {1'b0, cnx[7:1]};
wire [7:0] ciy_even = {1'b0, cny[7:1]} + cny[0];
wire [7:0] ciy_odd  = {1'b0, cny[7:1]};
wire [12:0] caddr_ee = ciy_even * 81 + cix_even;
wire [12:0] caddr_eo = ciy_even * 80 + cix_odd;
wire [12:0] caddr_oe = ciy_odd  * 81 + cix_even;
wire [12:0] caddr_oo = ciy_odd  * 80 + cix_odd;

wire [6:0] bnx = gx[9:3];
wire [6:0] bny = gy[9:3];
wire [6:0] bix_even = {1'b0, bnx[6:1]} + bnx[0];
wire [6:0] bix_odd  = {1'b0, bnx[6:1]};
wire [6:0] biy_even = {1'b0, bny[6:1]} + bny[0];
wire [6:0] biy_odd  = {1'b0, bny[6:1]};
wire [10:0] baddr_ee = biy_even * 41 + bix_even;
wire [10:0] baddr_eo = biy_even * 40 + bix_odd;
wire [10:0] baddr_oe = biy_odd  * 41 + bix_even;
wire [10:0] baddr_oo = biy_odd  * 40 + bix_odd;

wire [1:0] depth_index = depth == 0 ? 2'd0 : depth - 1'b1;
wire [3:0] map_index = seed_sel * 3 + depth_index;
reg [7:0] cq_ee, cq_eo, cq_oe, cq_oo;
reg [7:0] bq_ee, bq_eo, bq_oe, bq_oo;
reg [2:0] frac_x0, frac_y0;
reg [1:0] depth0;
reg x_odd0, y_odd0, blob0;
reg [23:0] c0;
always @(posedge clk) begin
	cq_ee <= centre_ee[caddr_ee + depth_index * 5913];
	cq_eo <= centre_eo[caddr_eo + depth_index * 5840];
	cq_oe <= centre_oe[caddr_oe + depth_index * 5832];
	cq_oo <= centre_oo[caddr_oo + depth_index * 5760];
	bq_ee <= blob_ee[baddr_ee + map_index * 1517];
	bq_eo <= blob_eo[baddr_eo + map_index * 1480];
	bq_oe <= blob_oe[baddr_oe + map_index * 1476];
	bq_oo <= blob_oo[baddr_oo + map_index * 1440];
	frac_x0 <= blob_mode ? gx[2:0] : {gx[1:0], 1'b0};
	frac_y0 <= blob_mode ? gy[2:0] : {gy[1:0], 1'b0};
	depth0 <= depth;
	x_odd0 <= blob_mode ? bnx[0] : cnx[0];
	y_odd0 <= blob_mode ? bny[0] : cny[0];
	blob0 <= blob_mode;
	c0 <= in_rgb;
end

wire [7:0] v_ee = blob0 ? bq_ee : cq_ee;
wire [7:0] v_eo = blob0 ? bq_eo : cq_eo;
wire [7:0] v_oe = blob0 ? bq_oe : cq_oe;
wire [7:0] v_oo = blob0 ? bq_oo : cq_oo;
reg [7:0] a, b, c, d;
always @(*) begin
	case ({y_odd0, x_odd0})
		2'b00: begin a=v_ee; b=v_eo; c=v_oe; d=v_oo; end
		2'b01: begin a=v_eo; b=v_ee; c=v_oo; d=v_oe; end
		2'b10: begin a=v_oe; b=v_oo; c=v_ee; d=v_eo; end
		default: begin a=v_oo; b=v_oe; c=v_eo; d=v_ee; end
	endcase
end

wire [3:0] wx0 = 4'd8 - {1'b0, frac_x0};
wire [3:0] wy0 = 4'd8 - {1'b0, frac_y0};
wire [11:0] top = a * wx0 + b * {1'b0, frac_x0};
wire [11:0] bot = c * wx0 + d * {1'b0, frac_x0};
wire [14:0] op_i = top * wy0 + bot * {1'b0, frac_y0};

reg [7:0] op1;
reg [23:0] c1;
always @(posedge clk) begin
	op1 <= (depth0 == 0) ? 8'd0 : (op_i + 15'd32) >> 6;
	c1 <= c0;
end

function automatic [7:0] blend(input [7:0] v, input [7:0] rot, input [7:0] op);
	reg [16:0] p;
	begin
		p = v * (9'd256 - op) + rot * op + 17'd128;
		blend = p[15:8];
	end
endfunction

always @(posedge clk) begin
	out_rgb <= {blend(c1[23:16], 8'd28, op1),
	            blend(c1[15:8],  8'd18, op1),
	            blend(c1[7:0],   8'd36, op1)};
end

endmodule
