module mux_ctl2(
	/* Inputs */
	reset, sysclk,
	bank_sel,
	mode,
	select,
	write, uds, lds,
	
	/* Outputs */
	dben,
	dtack,
	regen_cs,
	muxcfg
);
	/* Inputs */
	input reset, sysclk;
	input bank_sel;
	input [2:0] mode;
	input select, write, uds, lds;
	
	/* Outputs */
	output dben, dtack;
	output regen_cs;
	output [2:0] muxcfg;
	
	/* Mux configuration **************************************************************************/
	reg [2:0] muxcfg;
	
	always begin
		if (mode == 3'b0XX) begin
			/* Text modes - regen bank 0 is always used regardless of the selected bank. Access to
			 * the bank is shared between the CPU and CRTC, with the CRTC yielding to the CPU when
			 * it wants access. */
			if (select) begin
				/* CPU accesses the regen memory - ports A1=B1 */
				muxcfg = 3'b001;
			end
			else begin
				/* CRTC accesses the regen memory - ports A2=B1 */
				muxcfg = 3'b011;
			end
		end
		else begin
			/* Graphics modes - switching is configured according to the selected bank. CPU and
			 * CRTC both have uncontented access to their respective banks. Bank selection is as
			 * viewed from the perspective of the CPU. */
			if (bank_sel == 1'b0) begin
				/* CPU accesses bank 0, CRTC access active bank 1 - ports A1=B1, A2=B2 */
				muxcfg = 3'b110;
			end
			else begin
				/* CPU accesses bank 1, CRTC access active bank 0 - ports A1=B2, A2=B1 */
				muxcfg = 3'b111;
			end
		end
	end
	
	/* Regen chipselect, data bus enable and DTACK ************************************************/
	
	/* Regen memory chips are expected to be very fast, so DTACK can be asserted immediately,
	 * providing 0 wait state access to the regen memory */
	wire dtack = select; 
	
	/* A write pulse will be generated that is one SYSCLK period long */
	reg wr_timer;
	
	always @(posedge sysclk) begin
		if (reset) begin
			wr_timer <= 1'b0;
		end
		else begin
			if (uds || lds) begin
				wr_timer <= 1'b1;
			end
			else begin
				wr_timer <= 1'b0;
			end
		end
	end
	
	/* For reads and writes, the regen chip select can be asserted immediately. During a read, chip
	 * select remains asserted for the entire bus cycle. For writes, chip select is only asserted
	 * for one SYSCLK period after the data strobes are asserted. */
	wire regen_cs = select & ((~write & (uds | lds)) |
							  (write & (uds | lds) & ~wr_timer));
	
	/* The data bus can be enabled as soon as the regen select signal is asserted, as some kind of
	 * access will be performed */
	wire dben = select;
endmodule /* mux_ctl */

