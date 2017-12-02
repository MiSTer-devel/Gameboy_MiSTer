//
// ddram.v
//
// DE10-nano DDR3 memory interface
//
// Copyright (c) 2017 Sorgelig
//
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// ------------------------------------------
//

module ddram
(
	input         RESET,
	input         DDRAM_CLK,

	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	input             wb_clk,   // chipset clock to which sdram state machine is synchonized	
	input      [31:0] wb_dat_i,	// data input from chipset/cpu
	output reg [31:0] wb_dat_o,	// data output to chipset/cpu
	input      [27:0] wb_adr,	// lower 2 bits are ignored.
	input       [3:0] wb_sel,	// 
	input       [2:0] wb_cti,	// cycle type. 
	input             wb_stb, 	//	
	input             wb_cyc, 	// cpu/chipset requests cycle
	input             wb_we,   	// cpu/chipset requests write
	output reg        wb_ack
);

assign DDRAM_BURSTCNT = burst;
assign DDRAM_BE       = ({wb_sel&{4{wb_adr[2]}},wb_sel&{4{~wb_adr[2]}}}) | {8{ram_read}};
assign DDRAM_ADDR     = {4'b0011, wb_adr[27:3]}; // RAM at 0x30000000
assign DDRAM_DIN      = {wb_dat_i,wb_dat_i};
assign DDRAM_RD       = ram_read;
assign DDRAM_WE       = ram_write;

reg [31:0] ram_q[4];
reg        ram_read;
reg        ram_write;

reg op_req = 0, op_ack = 0;
reg op_we;

always @(posedge DDRAM_CLK)
begin
	reg state = 0;
	reg opr;
	reg [7:0] c;

	opr <= op_req;

	if(RESET)
	begin
		state     <= 0;
		ram_write <= 0;
		ram_read  <= 0;
	end
	else
	if(!DDRAM_BUSY)
	begin
		ram_write <= 0;
		ram_read  <= 0;

		case(state)
			0: if(op_ack != opr) begin
					ram_write <= op_we;
					ram_read  <= ~op_we;
					state     <= 1;
					c         <= 1;
				end
			1: if(op_we)
				begin
					op_ack <= opr;
					state  <= 0;
				end
				else
				if(DDRAM_DOUT_READY) begin
					if(c[1]) {ram_q[3], ram_q[2]} <= DDRAM_DOUT;
						else  {ram_q[1], ram_q[0]} <= DDRAM_DOUT;

					c <= c + 1'd1;
					if(c >= burst) begin
						state  <= 0;
						op_ack <= opr;
					end
				end
		endcase
	end
end

reg [7:0] burst;
always @(negedge wb_clk) begin
	reg       ack = 0;
	reg       state = 0;
	reg [1:0] sz;
	reg [1:0] cnt;

	ack <= op_ack;

	if(RESET) begin
		state <= 0;
		wb_ack <= 0;
	end
	else
	case(state)
		0: begin
				wb_ack <= 0;
				if(~wb_ack & wb_stb & wb_cyc) begin
					op_we <= wb_we;
					sz <= 0;
					burst <= 1;
					if((wb_cti == 2) && ~wb_we) begin
						sz <= 3;
						burst <= 2;
					end
					cnt <= wb_adr[2];
					op_req <= ~op_req;
					state <= 1;
				end
			end
		1: if(ack == op_req)
			begin
				wb_ack <= 1;
				if(~op_we) wb_dat_o <= ram_q[cnt];
				cnt <= cnt + 1'd1;
				if(cnt >= sz) state <= 0;
			end
	endcase
end

endmodule
