module font_ram_busif(
	reset, sysclk,
	select,
	write, uds, lds,
	
	dtack, berr,
	ram_ce, ram_oe, ram_we,
	en
);
	/* Inputs */
	input reset, sysclk;
	input select;
	input write, uds, lds;
	
	/* Outputs */
	output dtack, berr;
	output ram_ce, ram_oe, ram_we;
	output en;
	
	/* DTACK timer ********************************************************************************/
	reg dtack_timer;
	
	always @(posedge sysclk) begin
		if (reset) begin
			dtack_timer <= 1'b0;
		end
		else begin
			if (uds && !berr) begin
				dtack_timer <= 1'b1;
			end
			else begin
				dtack_timer <= 1'b0;
			end
		end
	end
	
	/* Buffer Enable is asserted as soon as the font RAM is selected */
	wire en = select;
	
	/* DTACK is asserted once the DTACK timer is set */
	wire dtack = select & dtack_timer;
	
	/* Any access involving LDS causes a Bus Error exception */
	wire berr = select & lds;	
	
	/* Chip select is asserted for the full bus cycle */
	wire ram_ce = select;
	
	/* Read strobe is asserted for the full bus cycle */
	wire ram_oe = select & ~write;
	
	/* Write strobe is asserted once UDS is asserted and until DTACK is asserted */
	wire ram_we = select & write & uds & ~dtack;
endmodule /* font_ram_busif */

