/* Video formatter
 *
 * Works in conjunction with the CRTC to format the pixel data to be displayed on the screen.
 *
 * Modes of operation:
 *
 *	000		80x25 text mode 1, 9x16 character boxes
 *	001		80x25 text mode 2, 8x16 character boxes
 *  010
 *	011
 *	100		320x200 graphics mode 1, upscaled to 640x400, 256 colours
 *	101
 *	110
 *	111
 *
 * The intensity input is used to select between two alternate text modes:
 *
 *	0: 16fg/8bg colours with blinking text
 *	1: 16fg/16bg colours with static text
 *
 * where 0 indicates the signal is negated.
 *
 * Individual formats may be enabled or disabled during compilation by modifying the directives
 * below. Uncomment a directive to include the formatter for that mode....
 */

`define INCLUDE_TEXT1
`define INCLUDE_TEXT2
`define INCLUDE_GRAF1

module formatter(
	/* Inputs */
	pclk, cclk, reset, mode,		/* System interface */
	dispen, cursor_en, text_blink,	/* CRTC interface */
	h_sync_in, v_sync_in,
	md, fd,							/* Regen memory interface */
	intensity,						/* Enable 16bg colours instead of blinking text in text modes */
		
	/* Outputs */
	ramdac_clk, pal, blank,			/* RAMDAC interface */
	h_sync_out, v_sync_out
);
	/* Inputs */
	input pclk, cclk, reset;
	input [2:0] mode;
	
	input dispen, cursor_en, text_blink, h_sync_in, v_sync_in;
	
	input [15:0] md;
	input [7:0] fd;
	
	input intensity;
	
	/* Outputs */
	output ramdac_clk;
	output [7:0] pal;
	output blank;
	output h_sync_out, v_sync_out;
	
	wire [7:0] cc = md[15:8];
	wire [7:0] ac = md[7:0];
	wire [7:0] pix0 = md[15:8];
	wire [7:0] pix1 = md[7:0];
	
	parameter FMT_MODE_TEXT1 = 'b000;
	parameter FMT_MODE_TEXT2 = 'b001;
	parameter FMT_MODE_GRAF1 = 'b100;
	
	/* Re-register signals ************************************************************************/
	reg dispen_reg;
	reg h_sync_out, v_sync_out;
	reg cursor_en_reg;
	
	always @(posedge cclk) begin
		dispen_reg <= dispen;
	end
	
	always @(negedge cclk) begin
		h_sync_out <= h_sync_in;
		v_sync_out <= v_sync_in;
		cursor_en_reg <= cursor_en;
	end
	
`ifdef INCLUDE_TEXT1
	/* Text mode 1 formatter **********************************************************************/
	reg [3:0] tm1_ctr;
	reg [3:0] tm1_ctr_next;
	reg [8:0] tm1_fd;
	reg [8:0] tm1_fd_next;
	reg [7:0] tm1_ac;
	reg [7:0] tm1_ac_next;
	
	always @(negedge pclk or posedge reset) begin
		if (reset) begin
			tm1_ctr <= 'd8;
		end
		else begin
			tm1_ctr <= tm1_ctr_next;
		end
	end
	
	always begin
		tm1_ctr_next = tm1_ctr;
		
		if (~dispen_reg) begin
			/* When the display is disabled, hold the counter at its maximum value and disable the
			 * display */
			tm1_ctr_next = 'd8;
		end
		else begin
			if (tm1_ctr == 'd8) begin
				tm1_ctr_next = 'd0;
			end
			else begin
				tm1_ctr_next = tm1_ctr + 'd1;
			end
		end
	end
	
	always @(negedge pclk) begin
		tm1_fd <= tm1_fd_next;
		tm1_ac <= tm1_ac_next;
	end
	
	always begin
		tm1_fd_next = tm1_fd;
		tm1_ac_next = tm1_ac;
		
		if (mode == FMT_MODE_TEXT1) begin
			if (tm1_ctr == 'd8) begin
				/* Latch the font pixel data. For 9xN character boxes, the right hand most pixel is
				 * duplicated into the 9th column for certain character codes. */
				if (cc == 8'b110XXXXX) begin
					tm1_fd_next = {fd[7:0], fd[0]};
				end
				else begin
					tm1_fd_next = {fd[7:0], 1'b0};
				end
				
				/* Latch the attribude code now too */
				tm1_ac_next = ac;
			end
			else begin
				/* Shift pixel data */
				tm1_fd_next = {tm1_fd[7:0], 1'b0};
			end
		end
	end
`endif
	
`ifdef INCLUDE_TEXT2
	/* Text mode 2 formatter **********************************************************************/
	reg [2:0] tm2_ctr;
	reg [2:0] tm2_ctr_next;
	reg [7:0] tm2_fd;
	reg [7:0] tm2_fd_next;
	reg [7:0] tm2_ac;
	reg [7:0] tm2_ac_next;
	
	always @(negedge pclk or posedge reset) begin
		if (reset) begin
			tm2_ctr <= 'd7;
		end
		else begin
			tm2_ctr <= tm2_ctr_next;
		end
	end
	
	always begin
		tm2_ctr_next = tm2_ctr;
		
		if (~dispen_reg) begin
			/* When the display is disabled, hold the counter at its maximum value and disable the
			 * display */
			tm2_ctr_next = 'd7;
		end
		else begin
			tm2_ctr_next = tm2_ctr + 'd1;
		end
	end
	
	always @(negedge pclk) begin
		tm2_fd <= tm2_fd_next;
		tm2_ac <= tm2_ac_next;
	end
	
	always begin
		tm2_fd_next = tm2_fd;
		tm2_ac_next = tm2_ac;
		
		if (mode == FMT_MODE_TEXT2) begin
			if (tm2_ctr == 'd7) begin
				/* Latch the pixel data. No special handling for 8xN character boxes. */
				tm2_fd_next = fd;
				
				/* Latch the attribude code now too */
				tm2_ac_next = ac;
			end
			else begin
				/* Shift pixel data */
				tm2_fd_next = {tm2_fd[6:0], 1'b0};
			end
		end
	end
`endif
	
`ifdef INCLUDE_GRAF1
	/* Graphics mode 1 formatter ******************************************************************/
	reg [1:0] gm1_ctr;
	reg [1:0] gm1_ctr_next;
	reg [7:0] gm1_pix0;
	reg [7:0] gm1_pix0_next;
	reg [7:0] gm1_pix1;
	reg [7:0] gm1_pix1_next;
	
	always @(negedge pclk or posedge reset) begin
		if (reset) begin
			gm1_ctr <= 'd3;
		end
		else begin
			gm1_ctr <= gm1_ctr_next;
		end
	end
	
	always begin
		gm1_ctr_next = gm1_ctr;
		
		if (~dispen_reg) begin
			/* When the display is disabled, hold the counter at its maximum value and disable the
			 * display */
			gm1_ctr_next = 'd3;
		end
		else begin
			gm1_ctr_next = gm1_ctr + 'd1;
		end
	end
	
	always @(negedge pclk) begin
		gm1_pix0 <= gm1_pix0_next;
		gm1_pix1 <= gm1_pix1_next;
	end
	
	always begin
		gm1_pix0_next = gm1_pix0;
		gm1_pix1_next = gm1_pix1;
		
		if (mode == FMT_MODE_GRAF1) begin
			if (gm1_ctr == 'd3) begin
				/* Latch the pixel data */
				gm1_pix0_next = pix0;
				gm1_pix1_next = pix1;
			end
		end
	end
`endif
	
	/* Palette assignment *************************************************************************/
`ifdef INCLUDE_TEXT1
	reg [7:0] tm1_pal;
	reg [7:0] tm1_pal_next;
`endif
`ifdef INCLUDE_TEXT2
	reg [7:0] tm2_pal;
	reg [7:0] tm2_pal_next;
`endif
`ifdef INCLUDE_GRAF1
	reg [7:0] gm1_pal;
	reg [7:0] gm1_pal_next;
`endif
	reg [7:0] pal;
	reg [7:0] pal_next;
	
	always @(negedge pclk) begin
`ifdef INCLUDE_TEXT1
		tm1_pal <= tm1_pal_next;
`endif
`ifdef INCLUDE_TEXT2
		tm2_pal <= tm2_pal_next;
`endif
`ifdef INCLUDE_GRAF1
		gm1_pal <= gm1_pal_next;
`endif
	end
	
	always begin
`ifdef INCLUDE_TEXT1
		/* Text mode 1 palette selection */
		tm1_pal_next = 'd0;
		
		if (intensity) begin
			/* 16fg/bg colour mode */
			tm1_pal_next = tm1_fd[8] ? tm1_ac[3:0] : tm1_ac[7:4];
		end
		else begin
			/* Blinking text mode */
			if (tm1_ac[7] & text_blink) begin
				/* Text is not visible, force background colour */
				tm1_pal_next = {1'b0, tm1_ac[6:4]};
			end
			else begin
				/* Text is visible, choose foreground or background based on pixel */
				tm1_pal_next = tm1_fd[8] ? tm1_ac[3:0] : {1'b0, tm1_ac[6:4]};
			end
		end
		
		/* When the cursor is active, force the foreground colour */
		if (cursor_en_reg) begin
			tm1_pal_next = tm1_ac[3:0];
		end
`endif
		
`ifdef INCLUDE_TEXT2
		/* Text mode 2 palette selection */
		tm2_pal_next = 'd0;
		
		if (intensity) begin
			/* 16fg/bg colour mode */
			tm2_pal_next = tm2_fd[7] ? tm2_ac[3:0] : tm2_ac[7:4];
		end
		else begin
			/* Blinking text mode */
			if (tm2_ac[7] & text_blink) begin
				/* Text is not visible, force background colour */
				tm2_pal_next = {1'b0, tm2_ac[6:4]};
			end
			else begin
				/* Text is visible, choose foreground or background based on pixel */
				tm2_pal_next = tm2_fd[7] ? tm2_ac[3:0] : {1'b0, tm2_ac[6:4]};
			end
		end
		
		/* When the cursor is active, force the foreground colour */
		if (cursor_en_reg) begin
			tm2_pal_next = tm2_ac[3:0];
		end
`endif
		
`ifdef INCLUDE_GRAF1
		/* Graphics mode 1 palette selection */
		gm1_pal_next = 'd0;
		
		if (~gm1_ctr[1]) begin
			/* For the first two clocks supply pix0 */
			gm1_pal_next = gm1_pix0;
		end
		else begin
			/* For the second two clocks supply pix1 */
			gm1_pal_next = gm1_pix1;
		end
`endif
	end
	
	always @(negedge pclk) begin
		pal <= pal_next;
	end
	
	always begin
		case (mode)
`ifdef INCLUDE_TEXT1
			FMT_MODE_TEXT1: begin
				pal_next = tm1_pal_next;
			end
`endif
			
`ifdef INCLUDE_TEXT2
			FMT_MODE_TEXT2: begin
				pal_next = tm2_pal_next;
			end
`endif
			
`ifdef INCLUDE_GRAF1
			FMT_MODE_GRAF1: begin
				pal_next = gm1_pal_next;
			end
`endif
		endcase
	end
	
	/* Display blank output ***********************************************************************/
	reg blank, blank_s;
	
	always @(negedge pclk or posedge reset) begin
		if (reset) begin
			blank <= 1'b1;
			blank_s <= 1'b1;
		end
		else begin
			blank_s <= ~dispen_reg;
			blank <= blank_s;
		end
	end
	
	/* RAMDAC clock *******************************************************************************/
	wire ramdac_clk = pclk;
endmodule

