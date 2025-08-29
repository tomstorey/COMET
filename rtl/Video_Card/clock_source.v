/* CRTC/formatter clock source
 *
 * This module provide the pixel and character clock sources used by the CRTC and formatter.
 *
 * The pixel clock is switched glitch free between either a 28.322MHz or 25.175MHz based on the
 * operating mode to supply the formatter, and further from this clock and operating mode a
 * character clock is provided for the CRTC.
 *
 * The character clock consists of a high pulse at the terminal count value. The positive edge of
 * this pulse is intended to synchronise signals between the CRTC and formatter, such as the dispen
 * signal which causes the formatter to begin shifting pixels, while the falling edge is used in a
 * significant manner within the CRTC. These two clock edges allow maximum time betwen the CRTC
 * output changing and propagation through video memory banks before the formatter latches the
 * resulting pixel data.
 */

module clock_source(
	/* Inputs */
	clk_28,
	clk_25,
	mode,
	
	/* Outputs */
	pclk,
	cclk
);
	/* Inputs */
	input clk_28, clk_25;
	input [2:0] mode;
	
	/* Outputs */
	output cclk, pclk;
	
	parameter MODE_TEXT1 = 3'b000;
	parameter MODE_TEXT2 = 3'b001;
	parameter MODE_GRAF1 = 3'b100;
	
	/* Pixel clock selector ***********************************************************************/
	reg pclk_28_s, pclk_28_ss;
	reg pclk_25_s, pclk_25_ss;
	
	always @(negedge clk_28) begin
		pclk_28_s <= (mode == MODE_TEXT1);
		pclk_28_ss <= pclk_28_s;
	end
	
	always @(negedge clk_25) begin
		pclk_25_s <= (mode == MODE_TEXT2) | (mode == MODE_GRAF1);
		pclk_25_ss <= pclk_25_s;
	end
	
	assign pclk = (pclk_28_s & pclk_28_ss & clk_28) | (pclk_25_s & pclk_25_ss & clk_25);
	
	/* Terminal count selector ********************************************************************/
	reg [3:0] tc_val;
	
	always begin
		case (mode)
			MODE_TEXT1: begin
				tc_val = 'd7;
			end
			
			MODE_TEXT2: begin
				tc_val = 'd6;
			end
			
			MODE_GRAF1: begin
				tc_val = 'd2;
			end
		endcase
	end
	
	/* Character clock generator ******************************************************************/
	reg [3:0] cclk_ctr;
	reg [3:0] cclk_ctr_next;
	reg cclk;
	reg cclk_next;
	
	always @(negedge pclk) begin
		cclk_ctr <= cclk_ctr_next;
		cclk <= cclk_next;
	end
	
	always begin
		cclk_next = cclk;
		
		if (cclk == 1'b1) begin
			cclk_ctr_next = 'd0;
			cclk_next = 1'b0;
		end
		else begin
			if (cclk_ctr == tc_val) begin
				cclk_next = 1'b1;
			end
			
			cclk_ctr_next = cclk_ctr + 'd1;
		end
	end
endmodule /* clock_source */

