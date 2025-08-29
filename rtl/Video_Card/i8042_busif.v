/* i8042 bus interface
 *
 * This module provides a bus control interface for a i8042 or compatible keyboard controller. It
 * generates the read, write, chip select and clock signals required to access and operate the chip,
 * and generates DTACK and BERR for valid and invalid accesses respectively.
 *
 * In this implementation, the keyboard controller is expected to be accessible only via the upper
 * hals of the data bus. Accesses to the keyboard controller via the lower half of the data bus will
 * generate a Bus Error exception.
 *
 * Input signals from the CPU clock domain are synchronised to the modules clock domain, which is
 * a nominal 40MHz.
 */

/* Uncomment to produce an 8MHz keyboard controller clock from a nominal 40MHz input. If commented
 * out, the clock will be 10MHz. */
`define KB_CLK_8MHZ

module i8042_busif(
	/* Inputs */
	reset, clk_40,
	select, write, uds, lds,
	
	/* Outputs */
	dtack, berr,
	kb_reset, kb_clk, kb_cs, kb_rd, kb_wr
);
	/* Inputs */
	input reset, clk_40;
	input select, write, uds, lds;
	
	/* Outputs */
	output dtack, berr;
	output kb_reset, kb_clk, kb_cs, kb_rd, kb_wr;
	
	/* Clock generator ****************************************************************************/
`ifdef KB_CLK_8MHZ
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
	
	wire kb_clk = clk_divider[1] & clk_divider_a;
`else
	reg [1:0] clk_divider;
	
	always @(negedge clk_40) begin
		clk_divider <= clk_divider + 'd1;
	end
	
	wire kb_clk = clk_divider[1];
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
	
	/* Reset generator ****************************************************************************/ 
	
	/* The reset pin of the VT82C42 must be asserted for a minimum of 10 clock cycles for a proper
	 * reset to be effected. Generate a reset pulse that meets the 10 clock minimum, and remains
	 * asserted as long as the reset input is asserted. */
	reg reset_s, reset_ss;
	reg m_reset;
	reg m_reset_next;
	reg [3:0] reset_timer;
	reg [3:0] reset_timer_next;
	
	parameter M_IDLE = 1'b0;
	parameter M_RESETTING = 1'b1;
	
	always @(negedge kb_clk) begin
		/* Synchronise the reset signal to the keyboard clock */
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
				if (reset_timer == 'd10) begin
					/* Once the timer reaches 10 we stop incrementing and wait for the reset signal
					 * to be negated */
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
	
	wire kb_reset = (m_reset == M_RESETTING);	
	
	/* Write timer ********************************************************************************/
	reg [2:0] wr_timer;
	
	always @(negedge clk_40 or posedge reset) begin
		if (reset) begin
			wr_timer <= 'd0;
		end
		else begin
			if (select_ss && ds_ss) begin
				if (!(&wr_timer)) begin
					wr_timer <= wr_timer + 'd1;
				end
			end
			else begin
				wr_timer <= 'd0;
			end
		end
	end
	
	/* De-glitching of read/write strobes and DTACK ***********************************************/
	reg kb_rd_reg;
	reg kb_wr_reg;
	reg dtack_reg;
	
	always @(negedge clk_40 or posedge reset) begin
		if (reset) begin
			kb_rd_reg <= 1'b0;
			kb_wr_reg <= 1'b0;
			dtack_reg <= 1'b0;
		end
		else begin
			kb_rd_reg <= select_ss & ds_ss & ~write;
			
			kb_wr_reg <= select_ss & ds_ss & write & ~(&wr_timer);
			
			
			dtack_reg <= select_ss & ds_ss &
				 		 (~write & wr_timer[2] |
				  		  write & (&wr_timer));
		end
	end
	
	/* Chipselect can be asserted immediately from the select input */
	wire kb_cs = select;
	
	wire kb_rd = select & kb_rd_reg;
	wire kb_wr = select & kb_wr_reg;
	wire dtack = select & dtack_reg;
	
	/* Any access involving LDS causes a Bus Error exception */
	wire berr = select & lds;
endmodule /* vt82c42_busif */

