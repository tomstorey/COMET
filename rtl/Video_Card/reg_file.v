/* Register file
 *
 * The register file stores values used to configure the timing of the CRTC, and via the CSR0 and
 * CSR1 registers, allows control of various other functions of the video system. Most of the bits
 * in these two registers are both readable and writeable.
 *
 * The remaining 13 registers are associated with the CRTC, and are used to control the timing of
 * the video display. All of these registers are write-only.
 *
 * CSR0 contains bits and fields which are largely concerned with control of the chip as a whole,
 * including reset, video mode, and other configurable parameters.
 *
 * CSR1 is largely concerned with the interrupt facilities of the chip. It holds the vector that
 * is supplied during interrupt acknowledge, and bits to enable and check the status of various
 * interrupt sources. The vector number is stored in the upper byte of the register, and during
 * interrupt acknowledge, the whole register is output to the bus to supply that vector.
 *
 * All CRTC registers are write-only. CSR0 and CSR1 are both read/write. All registers must be
 * accessed with word sized transfers, otherwise a bus error exception is generated.
 *
 * The register file should be clocked in the CPU domain.
 *
 * Register file bit/field map (lower case bits are supplied externally, but documented here for
 * completeness):
 *
 * Reg	Addr	Access	Format					Function
 * ---	----	------	------					--------
 * 0	00		RW		U--a FBSD IMMM VHER		Control/status register 0
 * 													U	15		rw	In-use LED off (0) or on (1)
 *														14..13	r	Unimplemented, read as 0
 *													v	12		r	V blank
 *													F	11		rw	Font select
 *													B	10		rw	Bank 0 buffer select
 *													S	9		rw	Regen bank select
 * 													D	8		rw	Regen bank decode enable (1)
 *													I	7		rw	Intensity (1=16FG and BG colours)
 * 													M	6..4	rw	Video mode
 * 													V	3		rw	V sync pulse polarity (0=positive)
 * 													H	2		rw	H sync pulse polarity (0=positive)
 * 													E	1		rw	Display blank (0) or enable (1)
 * 													R	0		rw	Reset (0) or run (1)
 * 1	02		RW		icks -CKS VVVV VVvv 		Control/status register 1
 *													i	15		r	Interrupt active (k OR c OR s)
 *													k	14		r	Keyboard interrupt active
 *													c	13		r	CRTC V blank interrupt active
 *													s	12		r	I2C interrupt active
 *														11		r	Unimplemented, read as 0
 *													K	10		rw	Keyboard interrupt enable (1)
 *													C	9		rw	CRTC V blank interrupt enable (1)
 *													S	8		rw	I2C interrupt enable (1)
 *													V	7..2	rw	Vector number
 *													v	1..0	r	Sub-vector number
 *																	00	Keyboard controller interrupt
 *																	01	V blank interrupt
 *																	10	I2C controller interrupt
 *																	11	Reserved
 *																	Valid only during IACK cycle
 * 2	04		WO		---- --RR RRRR RRRR		Horizontal total
 * 3	06		WO		---- --RR RRRR RRRR		Horizontal displayed
 * 4	08		WO		---- --RR RRRR RRRR		Horizontal sync position
 * 5	0A		WO		---V VVVV HHHH HHHH		H/V sync width
 *													V	12..8	Veritcal width
 *													H	7..0	Horizontal width
 * 6	0C		WO		---- --RR RRRR RRRR		Vertical total
 * 7	0E		WO		---- ---- --RR RRRR		Vertical adjust
 * 8	10		WO		---- --RR RRRR RRRR		Vertical displayed
 * 9	12		WO		---- --RR RRRR RRRR		Vertical sync position
 * 10	14		WO		---- ---- ---R RRRR		Row size
 * 11	16		WO		-BPS SSSS ---E EEEE		Cursor
 *														15		Unimplemented
 *													B	14		Blink
 *													P	13		Blink pattern
 *													S	12..8	Start scanline
 *														7..5	Unimplemented
 *													E	4..0	End scanline
 * 12	18		WO		RRRR RRRR RRRR RRRR		Regen start address
 * 13	1A		WO		RRRR RRRR RRRR RRRR		Cursor address
 * 14	1C		WO		---- --RR RRRR RRRR		Regen address increment
 * 15	1E										Unused - BERR
 */

/* For testing purposes, uncomment to compile only with CSR0 and CSR1 registers */
//`define CSRONLY

module reg_file(
	/* Inputs */
	reset, sysclk,
	write, uds, lds,
	addr,
	data_in,
	select,
	
	/* Outputs */
`ifdef CSRONLY
`else
	h_total,
	h_disp,
	h_sync_pos,
	h_sync_width,
	v_sync_width,
	v_total,
	v_adj,
	v_disp,
	v_sync_pos,
	row_size,
	cursor,
	regen_start,
	cursor_addr,
	regen_inc,
`endif
	dtack, berr,
	csr0,
	csr1,
	csr0_read,
	csr1_read
);
	/* Inputs */
	input reset, sysclk;
	input write, uds, lds;
	input [4:1] addr;
	input [15:0] data_in;
	input select;
	
	/* Outputs */
`ifdef CSRONLY
`else
	output [9:0] h_total;
	output [9:0] h_disp;
	output [9:0] h_sync_pos;
	output [7:0] h_sync_width;
	output [4:0] v_sync_width;
	output [9:0] v_total;
	output [5:0] v_adj;
	output [9:0] v_disp;
	output [9:0] v_sync_pos;
	output [4:0] row_size;
	output [15:0] cursor;
	output [15:0] regen_start;
	output [15:0] cursor_addr;
	output [9:0] regen_inc;
`endif
	output dtack, berr;
	output [15:0] csr0;
	output [15:0] csr1;
	output csr0_read;
	output csr1_read;
	
	/* Register address decoder, read/write control, DTACK and BERR *******************************/
	wire [15:0] reg_selects;
	
	lpm_decode reg_file_dec(
		.data(addr[4:1]),
		.enable(select),
		.eq(reg_selects)
	);
	defparam reg_file_dec.LPM_WIDTH = 4;
	defparam reg_file_dec.LPM_DECODES = 16;
	
	wire dtack;
	
	dff dtack_ff(
		.d(|reg_selects[14:0] & write & uds & lds | |reg_selects[1:0] & !write & uds & lds),
		.clk(sysclk),
		.clrn(select),
		.q(dtack)
	);
	
	wire reg_write = dtack & write & uds & lds;
	
	wire csr0_read = select & reg_selects[0] & !write & uds & lds;
	wire csr1_read = select & reg_selects[1] & !write & uds & lds;
	
	wire berr;
	
	dff berr_ff(
		.d(reg_selects[15] | |reg_selects & (uds & !lds | !uds & lds) | |reg_selects[14:2] & !write),
		.clk(sysclk),
		.clrn(select),
		.q(berr)
	);
	
	/* Register instances *************************************************************************/
	
	/* 0: Control/status register 0 (U--a FBSD IMMM VHER) */
	wire [12:0] csr0_val;
	wire [15:0] csr0 = {csr0_val[12], 3'b000, csr0_val[11:0]};
	
	lpm_ff csr0_reg(
		.clock(reg_selects[0] & reg_write),
		.aclr(reset),
		.data({data_in[15], data_in[11:0]}),
		.q(csr0_val)
	);
	defparam csr0_reg.LPM_WIDTH = 13;
	
	/* 1: Control/status register 1 (icks -CKS VVVV VVvv) */
	wire [8:0] csr1_val;
	wire [15:0] csr1 = {5'b00000, csr1_val[8:0], 2'b00};
	
	lpm_ff csr1_reg(
		.clock(reg_selects[1] & reg_write),
		.aclr(reset),
		.data(data_in[10:2]),
		.q(csr1_val)
	);
	defparam csr1_reg.LPM_WIDTH = 9;
	
`ifdef CSRONLY
`else
	/* 2: Horizontal total (---- --RR RRRR RRRR) */
	wire [9:0] h_total;
	
	lpm_ff h_total_reg(
		.clock(reg_selects[2] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(h_total)
	);
	defparam h_total_reg.LPM_WIDTH = 10;
	
	/* 3: Horizontal displayed (---- --RR RRRR RRRR) */
	wire [9:0] h_disp;
	
	lpm_ff h_disp_reg(
		.clock(reg_selects[3] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(h_disp)
	);
	defparam h_disp_reg.LPM_WIDTH = 10;
	
	/* 4: Horizontal sync position (---- --RR RRRR RRRR) */
	wire [9:0] h_sync_pos;
	
	lpm_ff h_sync_pos_reg(
		.clock(reg_selects[4] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(h_sync_pos)
	);
	defparam h_sync_pos_reg.LPM_WIDTH = 10;
	
	/* 5: Horizontal/vertical sync width (---V VVVV HHHH HHHH) */
	wire [12:0] hv_sync_width;
	wire [7:0] h_sync_width = hv_sync_width[7:0];
	wire [4:0] v_sync_width = hv_sync_width[12:8];
	
	lpm_ff hv_sync_width_reg(
		.clock(reg_selects[5] & reg_write),
		.aclr(reset),
		.data(data_in[12:0]),
		.q(hv_sync_width)
	);
	defparam hv_sync_width_reg.LPM_WIDTH = 13;
	
	/* 6: Vertical total (---- --RR RRRR RRRR) */
	wire [9:0] v_total;
	
	lpm_ff v_total_reg(
		.clock(reg_selects[6] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(v_total)
	);
	defparam v_total_reg.LPM_WIDTH = 10;
	
	/* 7: Vertical adjust (---- ---- --RR RRRR) */
	wire [5:0] v_adj;
	
	lpm_ff v_adj_reg(
		.clock(reg_selects[7] & reg_write),
		.aclr(reset),
		.data(data_in[5:0]),
		.q(v_adj)
	);
	defparam v_adj_reg.LPM_WIDTH = 6;
	
	/* 8: Vertical displayed (---- --RR RRRR RRRR) */
	wire [9:0] v_disp;
	
	lpm_ff v_disp_reg(
		.clock(reg_selects[8] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(v_disp)
	);
	defparam v_disp_reg.LPM_WIDTH = 10;
	
	/* 9: Vertical sync position (---- --RR RRRR RRRR) */
	wire [9:0] v_sync_pos;
	
	lpm_ff v_sync_pos_reg(
		.clock(reg_selects[9] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(v_sync_pos)
	);
	defparam v_sync_pos_reg.LPM_WIDTH = 10;
	
	/* 10: Row size (---- ---- ---R RRRR) */
	wire [4:0] row_size;
	
	lpm_ff row_size_reg(
		.clock(reg_selects[10] & reg_write),
		.aclr(reset),
		.data(data_in[4:0]),
		.q(row_size)
	);
	defparam row_size_reg.LPM_WIDTH = 5;
	
	/* 11: Cusor (-BPS SSSS ---E EEEE) */
	wire [11:0] cursor_val;
	wire [15:0] cursor = {1'b0, cursor_val[11:5], 3'b000, cursor_val[4:0]};
	
	lpm_ff cursor_reg(
		.clock(reg_selects[11] & reg_write),
		.aclr(reset),
		.data({data_in[14:8], data_in[4:0]}),
		.q(cursor_val)
	);
	defparam cursor_reg.LPM_WIDTH = 12;
	
	/* 12: Regen start address (RRRR RRRR RRRR RRRR) */
	wire [15:0] regen_start;
	
	lpm_ff regen_start_reg(
		.clock(reg_selects[12] & reg_write),
		.aclr(reset),
		.data(data_in),
		.q(regen_start)
	);
	defparam regen_start_reg.LPM_WIDTH = 16;
	
	/* 13: Cursor address (RRRR RRRR RRRR RRRR) */
	wire [15:0] cursor_addr;
	
	lpm_ff _reg(
		.clock(reg_selects[13] & reg_write),
		.aclr(reset),
		.data(data_in),
		.q(cursor_addr)
	);
	defparam _reg.LPM_WIDTH = 16;
	
	/* 14: Regen increment (---- --RR RRRR RRRR) */
	wire [9:0] regen_inc;
	
	lpm_ff regen_inc_reg(
		.clock(reg_selects[14] & reg_write),
		.aclr(reset),
		.data(data_in[9:0]),
		.q(regen_inc)
	);
	defparam regen_inc_reg.LPM_WIDTH = 10;
`endif
endmodule /* reg_file */

