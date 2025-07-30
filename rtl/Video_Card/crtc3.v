//`define SIM

module crtc3(
	/* Inputs */
	clk, reset,
	h_total, h_disp, h_sync_pos, h_sync_width,
	v_sync_width, v_total, v_adj, v_disp, v_sync_pos, row_size,
	cursor,
	regen_start,
	cursor_addr,
	regen_inc,
	
	/* Outputs */
	dispen, cursor_en, text_blink,
	h_sync, v_sync,
	ra, ma,
	v_blank
	
//	h_tc, r_tc, v_tc,
//	v_total_ctr,
//	v_adj_ctr
);
	/* Inputs */
	input clk, reset;
	input [9:0] h_total;
	input [9:0] h_disp;
	input [9:0] h_sync_pos;
	input [7:0] h_sync_width;
	input [4:0] v_sync_width;
	input [9:0] v_total;
	input [5:0] v_adj;
	input [9:0] v_disp;
	input [9:0] v_sync_pos;
	input [4:0] row_size;
	input [15:0] cursor;
	input [15:0] regen_start;
	input [15:0] cursor_addr;
	input [9:0] regen_inc;
	
`ifdef SIM
	/* Params for simulation */
	parameter H_TOTAL = 10'd15;				/* ---- --RR RRRR RRRR */
	parameter H_DISP = 10'd8;				/* ---- --RR RRRR RRRR */
	parameter H_SYNC_POS = 10'd10;			/* ---- --RR RRRR RRRR */
	parameter H_SYNC_WIDTH = 8'h03;			/* ---V VVVV HHHH HHHH */
	parameter V_SYNC_WIDTH = 5'h02;
	parameter V_TOTAL = 10'd7;				/* ---- --RR RRRR RRRR */
	parameter V_ADJ = 6'd3;					/* ---- ---- --RR RRRR */
	parameter V_DISP = 10'd3;				/* ---- --RR RRRR RRRR */
	parameter V_SYNC_POS = 10'd5;			/* ---- --RR RRRR RRRR */
	parameter ROW_SIZE = 5'd3;				/* ---- ---- ---R RRRR */
	parameter CURSOR = 16'h6003;			/* IBPS SSSS ---E EEEE */
	parameter START_ADDR = 16'hA000;		/* RRRR RRRR RRRR RRRR */
	parameter CURSOR_ADDR = 16'hA000;		/* RRRR RRRR RRRR RRRR */
	parameter START_ADDR_INC = 10'h10;		/* ---- --RR RRRR RRRR */
	
	wire [9:0] h_total = H_TOTAL;
	wire [9:0] h_disp = H_DISP;
	wire [9:0] h_sync_pos = H_SYNC_POS;
	wire [7:0] h_sync_width = H_SYNC_WIDTH;
	wire [4:0] v_sync_width = V_SYNC_WIDTH;
	wire [9:0] v_total = V_TOTAL;
	wire [5:0] v_adj = V_ADJ;
	wire [9:0] v_disp = V_DISP;
	wire [9:0] v_sync_pos = V_SYNC_POS;
	wire [4:0] row_size = ROW_SIZE;
	wire [15:0] cursor = CURSOR;
	wire [15:0] regen_start = START_ADDR;
	wire [15:0] cursor_addr = CURSOR_ADDR;
	wire [8:0] regen_inc = START_ADDR_INC;
`endif	
	
	/* Outputs */
	output dispen, cursor_en, text_blink;
	output h_sync, v_sync;
	output [4:0] ra;
	output [15:0] ma;
	output v_blank;
	
//	output h_tc, r_tc, v_tc;
//	output [9:0] v_total_ctr;
//	output [5:0] v_adj_ctr;
	
	/* Globals */
	wire h_tc;
	wire r_tc;
	wire v_tc;
	reg in_v_adj;
	
	/* Horizontal counter *************************************************************************/
	reg [9:0] h_total_ctr;
	reg [9:0] h_total_ctr_next;
	
	assign h_tc = (h_total_ctr == h_total);
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			h_total_ctr <= 'd0;
		end
		else begin
			h_total_ctr <= h_total_ctr_next;
		end
	end
	
	always begin
		if (h_tc) begin
			h_total_ctr_next = 'd0;
		end
		else begin
			h_total_ctr_next = h_total_ctr + 'd1;
		end
	end
	
	/* Horizontal display enable ******************************************************************/
	reg h_dispen;
	reg h_dispen_next;
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			h_dispen <= 1'b0;
		end
		else begin
			h_dispen <= h_dispen_next;
		end
	end
	
	always begin
		h_dispen_next = (h_total_ctr < h_disp);
	end
	
	/* Horizontal sync pulse **********************************************************************/
	reg [7:0] h_sync_width_ctr;
	reg [7:0] h_sync_width_ctr_next;
	reg h_sync;
	reg h_sync_next;
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			h_sync <= 1'b0;
			h_sync_width_ctr <= 'd0;
		end
		else begin
			h_sync <= h_sync_next;
			h_sync_width_ctr <= h_sync_width_ctr_next;
		end
	end
	
	always begin
		h_sync_next = h_sync;
		
		if (!h_sync) begin
			if (h_total_ctr == h_sync_pos) begin
				h_sync_next = 1'b1;
			end
		end
		else begin
			if (h_sync_width_ctr_next == h_sync_width) begin
				h_sync_next = 1'b0;
			end
		end
	end
	
	always begin
		h_sync_width_ctr_next = 'd0;
		
		if (h_sync) begin
			h_sync_width_ctr_next = h_sync_width_ctr + 'd1;
		end
	end
	
	/* Scan line counter **************************************************************************/
	reg [4:0] row_size_ctr;
	reg [4:0] row_size_ctr_next;
	
	assign r_tc = (row_size_ctr == row_size);
		
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			row_size_ctr <= 'd0;
		end
		else begin
			row_size_ctr <= row_size_ctr_next;
		end
	end
	
	always begin
		row_size_ctr_next = row_size_ctr;
		
		if (!in_v_adj) begin
			if (h_tc) begin
				if (r_tc) begin
					row_size_ctr_next = 'd0;
				end
				else begin
					row_size_ctr_next = row_size_ctr + 'd1;
				end
			end
		end
	end
	
	/* Vertical/character row counter *************************************************************/
	reg [9:0] v_total_ctr;
	reg [9:0] v_total_ctr_next;
	
	assign v_tc = (v_total_ctr == v_total);
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			v_total_ctr <= 'd0;
		end
		else begin
			v_total_ctr <= v_total_ctr_next;
		end
	end
	
	always begin
		v_total_ctr_next = v_total_ctr;
		
		if (h_tc && r_tc) begin
			if (v_tc) begin
				v_total_ctr_next = 'd0;
			end
			else begin
				v_total_ctr_next = v_total_ctr + 'd1;
			end
		end
	end
	
	/* Vertical display enable ********************************************************************/
	reg v_dispen;
	reg v_dispen_next;
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			v_dispen <= 1'b0;
		end
		else begin
			v_dispen <= v_dispen_next;
		end
	end
	
	always begin
		v_dispen_next = (v_total_ctr < v_disp);
	end
		
	/* Vertical adjust counter ********************************************************************/
	reg [5:0] v_adj_ctr;
	reg [5:0] v_adj_ctr_next;
	reg in_v_adj_next;
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			v_adj_ctr <= 'd0;
			in_v_adj <= 1'b0;
		end
		else begin
			v_adj_ctr <= v_adj_ctr_next;
			in_v_adj <= in_v_adj_next;
		end
	end
	
	always begin
		v_adj_ctr_next = v_adj_ctr;
		in_v_adj_next = in_v_adj;
		
		if (!in_v_adj) begin
			if (h_tc && r_tc && v_tc) begin
				if (|v_adj) begin
					in_v_adj_next = 1'b1;
				end
			end
		end
		else begin
			if (v_adj_ctr == v_adj) begin
				in_v_adj_next = 1'b0;
			end
		end
		
		if (in_v_adj) begin
			if (h_tc) begin
				v_adj_ctr_next = v_adj_ctr + 'd1;
			end
		end
		else begin
			v_adj_ctr_next = 'd0;
		end
	end
	
	/* Vertical sync pulse ************************************************************************/
	reg [4:0] v_sync_width_ctr;
	reg [4:0] v_sync_width_ctr_next;
	reg v_sync;
	reg v_sync_next;
	reg v_sync_state;
	reg v_sync_state_next;
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			v_sync <= 1'b0;
			v_sync_state <= 1'b0;
			v_sync_width_ctr <= 'd0;
		end
		else begin
			v_sync <= v_sync_next;
			v_sync_state <= v_sync_state_next;
			v_sync_width_ctr <= v_sync_width_ctr_next;
		end
	end
	
	always begin
		v_sync_next = v_sync;
		v_sync_state_next = v_sync_state;
		
		if (!v_sync_state) begin
			if (v_total_ctr == v_sync_pos) begin
				v_sync_next = 1'b1;
				v_sync_state_next = 1'b1;
			end
		end
		else begin
			if (v_sync_width_ctr == v_sync_width) begin
				v_sync_next = 1'b0;
			end
			
			if (v_tc) begin
				v_sync_state_next = 1'b0;
			end
		end
	end
	
	always begin
		v_sync_width_ctr_next = v_sync_width_ctr;
		
		if (v_sync) begin
			if (h_tc) begin
				v_sync_width_ctr_next = v_sync_width_ctr + 'd1;
			end
		end
		else begin
			v_sync_width_ctr_next = 'd0;
		end
	end	
	
	/* Cursor *************************************************************************************/
	reg cursor_state;
	reg cursor_state_next;
	wire [1:0] cursor_bp = cursor[14:13];
	wire [4:0] cursor_sl_start = cursor[12:8];
	wire [4:0] cursor_sl_end = cursor[4:0];
	reg [5:0] cursor_prescaler;
	reg cursor_vis;
	
	parameter CURSOR_NOBLINK = 2'b00;
	parameter CURSOR_OFF = 2'b01;
	parameter CURSOR_FAST = 2'b10;
	parameter CURSOR_SLOW = 2'b11;
	
	always @(negedge clk or posedge reset) begin
		if (reset) begin
			cursor_state <= 1'b0;
		end
		else begin
			cursor_state <= cursor_state_next;
		end
	end
	
	always begin
		cursor_state_next = cursor_state;
		
		if (!cursor_state) begin
			if (ra == cursor_sl_start) begin
				cursor_state_next = 1'b1;
			end
		end
		else begin
			if (h_tc && !in_v_adj) begin
				if (ra == cursor_sl_end) begin
					cursor_state_next = 1'b0;
				end
			end
		end
	end
	
	always @(posedge v_tc) begin
		cursor_prescaler <= cursor_prescaler + 'd1;
	end
	
	always begin
		case (cursor_bp)
			CURSOR_NOBLINK: begin
				cursor_vis = 1'b1;
			end
			
			CURSOR_FAST: begin
				cursor_vis = cursor_prescaler[3];
			end
			
			CURSOR_SLOW: begin
				cursor_vis = !cursor_prescaler[5];
			end
			
			default: begin
				/* CURSOR_OFF */
				cursor_vis = 1'b0;
			end
		endcase
	end
	
	wire cursor_en = cursor_vis & cursor_state & (ma == cursor_addr);
	wire text_blink = ~cursor_prescaler[4];
	
	/* Memory address outputs *********************************************************************/
	reg [15:0] row_addr;
	reg [15:0] row_addr_next;
	reg [15:0] ma;
	reg [15:0] ma_next;
	
	always @(negedge clk) begin
		if (reset) begin
			row_addr <= regen_start;
			ma <= regen_start;
		end
		else begin
			row_addr <= row_addr_next;
			ma <= ma_next;
		end
	end
	
	always begin
		row_addr_next = row_addr;
		ma_next = ma;
		
		if (h_tc) begin
			if (r_tc) begin
				if (v_tc) begin
					/* H & R & V: Restart the frame over from scratch */
					row_addr_next = regen_start;
				end
				else begin
					/* H & R: Next character row */
					row_addr_next = row_addr + regen_inc;
				end
				
				ma_next = row_addr_next;
			end
			else begin
				/* H: Repeat the row */
				ma_next = row_addr;
			end
		end
		else begin
			if (dispen) begin
				/* Increment memory address */
				ma_next = ma + 'd1;
			end
		end
	end
	
	assign ra = row_size_ctr;
	
	/* Display enable output **********************************************************************/
	wire dispen = h_dispen & v_dispen & ~in_v_adj;
	
	wire v_blank = ~v_dispen;
endmodule /* crtc */

