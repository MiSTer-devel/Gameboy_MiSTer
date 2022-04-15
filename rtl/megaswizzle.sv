module megaduck_swizzle
(
	input megaduck,
	input [15:0] a_in,
	output [15:0] a_out
);

// Swizzle around MegaDuck register to match GB registers.

	always_comb begin
		a_out = a_in;
		if (megaduck) begin
			case (a_in)
				16'hFF10:  a_out = 16'hFF40; //  LCDC
				16'hFF11:  a_out = 16'hFF41; //  STAT
				16'hFF12:  a_out = 16'hFF42; //  SCY
				16'hFF13:  a_out = 16'hFF43; //  SCX
				16'hFF18:  a_out = 16'hFF44; //  LY
				16'hFF19:  a_out = 16'hFF45; //  LYC
				16'hFF1A:  a_out = 16'hFF46; //  DMA
				16'hFF1B:  a_out = 16'hFF47; //  BGP
				16'hFF14:  a_out = 16'hFF48; //  OBP0
				16'hFF15:  a_out = 16'hFF49; //  OBP1
				16'hFF16:  a_out = 16'hFF4A; //  WY
				16'hFF17:  a_out = 16'hFF4B; //  WX

				16'hFF20:  a_out = 16'hFF10; // Audio registers
				16'hFF21:  a_out = 16'hFF12;
				16'hFF22:  a_out = 16'hFF11;
				16'hFF23:  a_out = 16'hFF13;
				16'hFF24:  a_out = 16'hFF14;
				16'hFF25:  a_out = 16'hFF16;
				16'hFF26:  a_out = 16'hFF15;
				16'hFF27:  a_out = 16'hFF17;
				16'hFF28:  a_out = 16'hFF18;
				16'hFF29:  a_out = 16'hFF19;
				16'hFF2A:  a_out = 16'hFF1A;
				16'hFF2B:  a_out = 16'hFF1B;
				16'hFF2C:  a_out = 16'hFF1C;
				16'hFF2D:  a_out = 16'hFF1D;
				16'hFF2E:  a_out = 16'hFF1E;
				16'hFF2F:  a_out = 16'hFF1F;
				16'hFF40:  a_out = 16'hFF20; // The final 7 registers are after the audio ram
				16'hFF41:  a_out = 16'hFF22;
				16'hFF42:  a_out = 16'hFF21;
				16'hFF43:  a_out = 16'hFF23;
				16'hFF44:  a_out = 16'hFF24;
				16'hFF45:  a_out = 16'hFF26;
				16'hFF46:  a_out = 16'hFF25;
				default: a_out = a_in;
			endcase
		end
	end
endmodule