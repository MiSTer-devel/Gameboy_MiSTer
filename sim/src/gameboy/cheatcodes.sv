module CODES(
	input  clk,        
	input  reset,      
	input  enable,
	output available,
	input  [15:0] addr_in,
	input  [7:0] data_in,
	input  [128:0] code,
	output genie_ovr,
	output [7:0] genie_data
);

assign genie_ovr = 0;

endmodule
