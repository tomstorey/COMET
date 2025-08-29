/* I2C bus interface
 *
 * This module provides a bus control interface for a PCF8584 I2C controller. It generates the
 * reset, chip select and clock signals requires to access and operate the chip in the 68000 bus
 * mode, and generates DTACK and BERR for valid and invalid accesses respectively.
 *
 * In this implementation, the I2C controller is expected to be accessible only via the upper half
 * of the data bus. Access to the I2C controller via the lower half of the data bus will generate a
 * Bus Error exception.
 *
 * Input signals from the CPU clock domain are synchronised to the modules clock domain.
 */

/* Uncomment to produce an 8MHz I2C clock from a nominal 40MHz input. If commented out, the clock
 * will be 5MHz.
 *
 * The datasheet for the PCF8584 mentions that additional clock cycles are required in between
 * CPU bus cycles when the controller is run at 8 or 12MHz. */
//`define I2C_CLK_8MHZ

module i2c_busif(
	/* Inputs */
	reset, clk_40,
	select,
	write, uds, lds,
	i2c_dtack,
	
	/* Outputs */
	dtack, berr,
	i2c_clk, i2c_reset, i2c_cs
);
	/* Inputs */
	input reset, clk_40;
	input select;
	input write, uds, lds;
	input i2c_dtack;
	
	/* Outputs */
	output dtack, berr;
	output i2c_clk, i2c_cs, i2c_reset;
	
	/* I2C clock **********************************************************************************/
`ifdef I2C_CLK_8MHZ
	reg [3:0] clk_divider;
	reg clk_divider_a;
	
	always @(negedge clk_40) begin
		if (clk_divider[3]) begin
			clk_divider <= 'd0;
		end
		else begin
			clk_divider <= {clk_divider[2:0], 1'b1};
		end
	end
	
	always @(posedge clk_40) begin
		clk_divider_a <= clk_divider[1];
	end
	
	wire i2c_clk = clk_divider[1] & clk_divider_a;
`else
	reg [2:0] divider;
	
	always @(negedge clk_40) begin
		divider <= divider + 'd1;
	end
	
	wire i2c_clk = divider[2];
`endif
	
	/* Synchronise SELECT and UDS *****************************************************************/
	reg select_s, select_ss;
	reg ds_s, ds_ss;
	
	always @(negedge clk_40 or posedge reset) begin
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
	
	/* I2C reset **********************************************************************************/
	
	/* The reset pin of the PCF8584 must be asserted for a minimum of 30 clock cycles to pass
	 * through an internal filter. Generate a reset pulse that meets the 30 clock minimum, and
	 * remains asserted as long as the reset input is asserted. */
	reg reset_s, reset_ss;
	reg m_reset;
	reg m_reset_next;
	reg [4:0] reset_timer;
	reg [4:0] reset_timer_next;
	
	parameter M_IDLE = 1'b0;
	parameter M_RESETTING = 1'b1;
	
	always @(negedge i2c_clk) begin
		/* Synchronise the reset signal to the I2C clock */
		reset_s <= reset;
		reset_ss <= reset_s;
		
		m_reset <= m_reset_next;
		reset_timer <= reset_timer_next;
	end
	
	always begin
		m_reset_next = m_reset;
		reset_timer_next = reset_timer;
		
		case (m_reset)
			M_IDLE: begin
				if (reset_ss) begin
					m_reset_next = M_RESETTING;
				end
				
				reset_timer_next = 'd0;
			end
			
			M_RESETTING: begin
				if (&reset_timer) begin
					/* Once the timer reaches all 1's we stop incrementing and wait for the reset
					 * signal to be negated */
					if (!reset_ss) begin
						m_reset_next = M_IDLE;
					end
				end
				else begin
					reset_timer_next = reset_timer + 'd1;
				end
			end
		endcase
	end
	
	wire i2c_reset = (m_reset == M_RESETTING);
	
	/* Outputs ************************************************************************************/
	
	/* The PCF8584 is used in 68000 bus mode, so it will generate its own DTACK, which is relayed to
	 * the host CPU. */
	wire dtack = i2c_dtack;
	
	/* Any access involving LDS causes a Bus Error exception */
	wire berr = select & lds;
	
	/* Chip select is asserted constantly for reads, but is negated after the PCF8584 asserts its
	 * DTACK to end the bus cycle during writes */
	wire i2c_cs = select & select_ss & ds_ss &
				  (~write |
				   write & ~i2c_dtack);
endmodule /* i2c_busif */

