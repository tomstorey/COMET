/* RAMDAC bus interface
 *
 * This module provides a bus control interface to the RAMDAC. It generates the read and write
 * strobes required to access the RAMDAC, and generates DTACK and BERR for valid and invalid
 * accesses respectively.
 *
 * In this implementation, the RAMDAC is expected to be accessible only via the upper half of the
 * data bus. Accesses to the RAMDAC via the lower half of the data bus will generate a Bus Error
 * exception.
 *
 * Writes are synchronised to the pixel clock, which is a recommendation in the INMOS G171 datasheet
 * to prevent corruption of the lookup table address.
 *
 * Input signals from the CPU clock domain are synchronised to the pixel clock domain.
 */
module ramdac_busif(
	/* Inputs */
	reset, pclk,
	select,
	write, uds, lds,
	
	/* Outputs */
	dtack, berr,
	wr, rd
);
	/* Inputs */
	input reset, pclk;
	input select;
	input write, uds, lds;
	
	/* Outputs */
	output dtack, berr;
	output wr, rd;
	
	/* Synchronise SELECT and UDS to the pixel clock **********************************************/
	reg select_s, select_ss;
	reg ds_s, ds_ss;
	
	always @(posedge pclk or posedge reset) begin
		if (reset) begin
			select_s <= 1'b0;
			select_ss <= 1'b0;
			ds_s <= 1'b0;
			ds_ss <= 1'b0;
		end
		else begin
			select_s <= select;
			select_ss <= select_s;
			ds_s <= uds & ~lds;
			ds_ss <= ds_s;
		end
	end
	
	/* Read and write strobes, and DTACK **********************************************************/
	reg dtack_s, dtack_ss;
	
	always @(posedge pclk or posedge reset) begin
		if (reset) begin
			dtack_s <= 1'b0;
			dtack_ss <= 1'b0;
		end
		else begin
			dtack_s <= select_ss & ds_ss;
			dtack_ss <= dtack_s;
		end
	end
	
	/* DTACK is the result of both synchroniser stages, and masked by select */
	wire dtack = select & dtack_s & dtack_ss;
	
	/* Any access involving LDS causes a Bus Error exception */
	wire berr = select & lds;
	
	/* Generates a read pulse while the device is selected */
	wire rd = select & ds_ss & ~write;
	
	/* Generates a write pulse during the time when select is synchronised and until DTACK is
	 * asserted */
	wire wr = select & ds_ss & write & ~dtack;
endmodule /* ramdac_busif */

