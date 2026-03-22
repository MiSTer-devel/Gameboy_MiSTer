// Implementation follows the gbdev pandocs
// https://gbdev.io/pandocs/Timer_Obscure_Behaviour.html


module timer (
	input  		reset,
	input  		clk_sys,
	input  		ce,    // 4 MiHz / 8 MiHz cpu clock
	input 		ce_4MHz,
	input 		cpu_speed,
	output		irq,
	
	// CPU register interface
	input  		 cpu_sel,
	input  [1:0] cpu_addr,
	input  		 cpu_wr,
	input  [7:0] cpu_di,
	output [7:0] cpu_do,
	output 		 apu_framecount_en,
	
	// Save states              
	input  [63:0] SaveStateBus_Din, 
	input  [9:0]  SaveStateBus_Adr, 
	input         SaveStateBus_wren,
	input         SaveStateBus_rst, 
	output [63:0] SaveStateBus_Dout
);
	assign cpu_do = 
		(cpu_addr == 2'b00) ? div  : 
		(cpu_addr == 2'b01) ? tima :
		(cpu_addr == 2'b10) ? tma  :
					{5'b11111, tac};	

	// https://gbdev.io/pandocs/Timer_Obscure_Behaviour.html#timer-global-circuit
	// Falling-edge of selected counter
	assign apu_framecount_en = clk_sound_r && !clk_sound;

	reg clk_sound_r;
	wire clk_sound = cpu_speed ? div[5] : div[4]; 

	// Use 4 MiHz clock to generate APU trigger to enforce alignment.
	always @(posedge clk_sys) begin : CLK_SOUND_BLK
		if (reset)
			clk_sound_r <= 1'b0;
		else if (ce_4MHz)
			clk_sound_r <= clk_sound;
	end

	// Save states
	wire [46:0] SS_Timer;
	wire [46:0] SS_Timer_BACK;

	eReg_SavestateV #(0, 6, 46, 0, 64'h0000000000000008) iREG_SAVESTATE_Timer (clk_sys, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_Timer_BACK, SS_Timer);  

	// Unused legacy bits: 8-9, 29, 39-41
	assign {SS_Timer_BACK[37:30], SS_Timer_BACK[ 7: 0]} = clk_div;
	assign SS_Timer_BACK[17:10] = tima;
	assign SS_Timer_BACK[25:18] = tma;
	assign SS_Timer_BACK[28:26] = tac;
	assign SS_Timer_BACK[38] 	= clk_tac_r;
	assign SS_Timer_BACK[46:42]	= tima_overflow_buffer;

	reg [15:0] clk_div;
	wire [7:0] div = clk_div[15:8];

	always @(posedge clk_sys) begin : CLK_DIV_BLK
		if (reset)
			clk_div <= {SS_Timer[37:30], SS_Timer[7:0]}; // 16'd8;
		else if(cpu_sel && cpu_wr && (cpu_addr == 2'b00)) // Writing any value to DIV register clears counter.
			clk_div <= 16'd2; // For some reason this needs to be set to 2, rather than zero. This differs from sameboy.
		else if (ce)
			clk_div <= clk_div + 16'd1;
	end

	reg [7:0] tma;

	always @(posedge clk_sys) begin : TMA_BLK
		if (reset)
			tma <= SS_Timer[25:18]; // 0
		else if (ce) begin
			if (cpu_sel && cpu_wr && (cpu_addr == 2'b10))
				tma <= cpu_di;
		end
	end

	reg [2:0] tac;
	// Disabling TAC can create a clock event to TIMA
	wire clk_tac =  tac[2] &&  (
						(tac[1:0] == 2'b00) ? clk_div[9]:
						(tac[1:0] == 2'b01) ? clk_div[3]:
						(tac[1:0] == 2'b10) ? clk_div[5]:
											  clk_div[7]
					);
	reg  clk_tac_r;
	always @(posedge clk_sys) begin : TAC_BLK
		if (reset) begin
			tac 	  <= SS_Timer[28:26]; // 0
			clk_tac_r <= SS_Timer[38]; // 0
		end else if (ce) begin
			clk_tac_r <= clk_tac;
			if (cpu_sel && cpu_wr && (cpu_addr == 2'b11))
				tac <= cpu_di[2:0];
		end
	end

	/* Overflow timing explanation (https://gbdev.io/pandocs/Timer_Obscure_Behaviour.html#timer-overflow-behaviour)
	Here, the timer clock operates at 1/4 of the system clock frequency. That is, the timer aligns with a machine cycle.

	Basic sequence of events with values at each cycle:
	Clock tick -1: TIMA overflow occurs, i.e. {OVERFLOW_FLAG, TIMA} == (8'hff + 1)
	Overflow cycle:
		Clock tick 0: OVERFLOW_BUFFER[0] = 1, TIMA = 0, IRQ = 0,
		Clock tick 1: OVERFLOW_BUFFER[1] = 1, TIMA = 0, IRQ = 0, 
		Clock tick 2: OVERFLOW_BUFFER[2] = 1, TIMA = 0, IRQ = 0,
		Clock tick 3: OVERFLOW_BUFFER[3] = 1, TIMA = 0, IRQ = 0,
	Interrupt Cycle:
		Clock tick 4: OVERFLOW_BUFFER[4] = 1, TIMA = 1?,  IRQ = 1,
		Clock tick 5: OVERFLOW_BUFFER    = X, TIMA = TMA, IRQ = 0,

	If TIMA is written to during the overflow cycle (ticks 0 to 3) the IRQ is prevented and the timer continues as normal.
	If TMA is written at the same time TMA is loaded into TIMA (tick 5), the new value is also loaded into TIMA.
	*/

	reg [7:0] tima;
	reg [4:0] tima_overflow_buffer;
	assign irq = tima_overflow_buffer[4];
	always @(posedge clk_sys) begin : TIMA_BLK
		if(reset) begin
			tima                 <= SS_Timer[17:10]; // 0
			tima_overflow_buffer <= SS_Timer[46:42]; // 0
		end else if (ce) begin			
			tima_overflow_buffer <= {tima_overflow_buffer[3:0], 1'b0};

			if(clk_tac_r && !clk_tac)
				{tima_overflow_buffer[0], tima} <= tima + 1'b1;
			
			// IRQ asserted with clock tick 4 (beginning of interrupt cycle), TIMA write takes place 1 clock TICK later
			if (irq) begin
				tima <= tma;
				if(cpu_sel && cpu_wr && cpu_addr == 2'b10) // Writing TMA when loading TIMA has instant effect
					tima <= cpu_di;
			end
			
			if(cpu_sel && cpu_wr && cpu_addr == 2'b01) begin
				tima_overflow_buffer[4:1] <= 4'b0; // Writing to TIMA during overflow cycle prevents interrupt
				
				if (!irq) // Writes to TIMA during interrupt cycle are ignored.
					tima <= cpu_di;
			end
		end
	end		
endmodule