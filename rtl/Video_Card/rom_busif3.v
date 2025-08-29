module rom_busif3(
	/* Inputs */
	reset, clk_40,
	select,
	write, uds, lds,
	
	/* Outputs */
	dben, dtack, berr,
	rom_ce, rom_oe, rom_we
);
	/* Inputs */
	input reset, clk_40;
	input select;
	input write, uds, lds;
	
	/* Outputs */
	output dben, dtack, berr;
	output rom_ce, rom_oe, rom_we;
	
	/* Synchroniser *******************************************************************************/
	reg ds_s;
	
	always @(negedge clk_40) begin
		ds_s <= ~write & (uds | lds) |
				 write & uds & lds;
	end
	
	/* Sequencer **********************************************************************************/
	reg [5:0] sequencer;
	
	always @(negedge clk_40 or posedge reset or negedge ds_s) begin
		if (reset) begin
			sequencer <= 'd0;
		end
		else if (!ds_s) begin
			sequencer <= 'd0;
		end
		else begin
			sequencer <= {sequencer[4:0], ds_s};
		end
	end
	
	/* Outputs ************************************************************************************/
	
	wire dtack = select & ~write & sequencer[0] |
				 select &  write & sequencer[0];
	
	/* Writes to the ROM must be performed as words - generate a bus error exception for attempts
	 * to write a byte. Register to avoid glitches. */
	reg berr;
	
	always @(negedge clk_40) begin
		berr <= select & write & ((uds & ~lds) | (lds & ~uds));
	end
	
	/* DBEN and chip select are asserted immediately when the ROM is selected, and held active for
	 * the whole bus cycle */
	wire dben = select;
	wire rom_ce = select;
	
	/* ROM output enable is asserted immediately when the ROM is selected, and held active for the
	 * whole bus cycle. The ROM will always present a word value to the CPU which can take what it
	 * needs. */
	wire rom_oe = select & ~write;
	
	/* ROM write enable is asserted immediately when the ROM is selected during a write cycle, and
	 * negated shortly afterwards to generate a write pulse. */
	wire rom_we = select & write & uds & lds & ~sequencer[1];
endmodule /* rom_busif3 */

