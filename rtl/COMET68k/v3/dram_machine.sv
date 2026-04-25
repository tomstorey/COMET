/* DRAM Machine
 *
 * Implements a state machine that refreshes the DRAM modules, as well as sequencing reads and
 * writes.
 *
 * The DRAM machine decodes address 0-0x3FFFFF as long as boot_ff, which indicates that the CPU
 * has begun executing code from ROM after fetching the ISP and IPC values, is set. Otherwise it
 * lays dormant and does not perform any function other than refresh.
 */
`default_nettype none

module dram_machine
#(parameter REFRESH_TIMER_COUNT=625,
			REFRESH_TIMER_BITS=10,		// clog2(REFRESH_TIMER_BITS)
			REFRESH_WAIT_STATES=2,
			ACCESS_CAS_WAIT_STATES=1,
			STATE_TIMER_BITS=3,			// clog2(max(REFRESH_WAIT_STATES + 1, ACCESS_CAS_WAIT_STATES))
			PRECHARGE_WAIT_STATES=2		// 0, 1 or 2
)
(
	input boot_ff,
	input reset,
	input clk,
	input [23:21] addr,
	input as, uds, lds,
	input [2:0] fc,
	
	output logic ras0, ras1, ucas, lcas, masel,
	output logic dtack,
	output logic decoded
);
	/* State machine variables */
	typedef enum bit [2:0] {
		M_IDLE,
		M_REFRESH,
		M_MUX,
		M_CAS,
		M_RMW,
		M_PRECHARGE,
		XXXX
	} state_e;
	
	state_e state, state_next;
	
	/* Refresh timer
	 *
	 * The refresh timer is a free-running timer with a modulus of REFRESH_TIMER_COUNT. It is
	 * allowed to count once boot_ff is set, and continuously counts and resets itself to create a
	 * timer from which DRAM refreshes are scheduled. */
	logic [REFRESH_TIMER_BITS-1:0] refresh_timer;
	logic [REFRESH_TIMER_BITS-1:0] refresh_timer_next;
	
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			refresh_timer <= '0;
		end
		else begin
			refresh_timer <= refresh_timer_next;
		end
	end
	
	always_comb begin
		if (refresh_timer == REFRESH_TIMER_COUNT-1) begin
			refresh_timer_next = '0;
		end
		else begin
			refresh_timer_next = refresh_timer + {{REFRESH_TIMER_BITS-1{'0}}, '1};
		end
	end
	
	/* Refresh due flag
	 *
	 * The refresh due flag is set at the terminal count of the refresh timer. It indicates to the
	 * state machine that a refresh cycle should be performed.
	 *
	 * Refresh cycles are handled with priority over access cycles. If a refresh and access cycle
	 * are requested simultaneously, the refresh cycle will be performed before then servicing the
	 * access cycle. */
	logic refresh_due;
	
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			refresh_due <= '0;
		end
		else if (state == M_REFRESH) begin
			refresh_due <= '0;
		end
		else if (refresh_timer == REFRESH_TIMER_COUNT-1) begin
			refresh_due <= '1;
		end
		else begin
			refresh_due <= refresh_due;
		end
	end
	
	/* State timer
	 *
	 * The state timer is a simple shift register which progressively clocks in 1's during certain
	 * states of the state machine, and whos stages can be used to time various events, such as
	 * wait states or delays to produce required timing */
	logic [STATE_TIMER_BITS-1:0] timer;
	logic [STATE_TIMER_BITS-1:0] timer_next;
	
	always_ff @(posedge clk) begin
		timer <= timer_next;
	end
	
	always_comb begin
		timer_next = '0;
		
		if (!reset) begin
			if ((state == M_REFRESH) || (state == M_CAS)) begin
				timer_next = {timer[STATE_TIMER_BITS-2:0], '1};
			end
		end
	end
	
	/* State machine logic */
	logic ras0_next, ras1_next, ucas_next, lcas_next, masel_next;
	
	always_comb begin
		decoded = as & (addr[23:22] == 2'b00) & (fc != 3'b111) & boot_ff;
	end
	
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			state <= M_IDLE;
			ras0 <= '0;
			ras1 <= '0;
			ucas <= '0;
			lcas <= '0;
			masel <= '0;
		end
		else begin
			state <= state_next;
			ras0 <= ras0_next;
			ras1 <= ras1_next;
			ucas <= ucas_next;
			lcas <= lcas_next;
			masel <= masel_next;
		end
	end
	
	always_comb begin
		state_next = state;
		ras0_next = ras0;
		ras1_next = ras1;
		ucas_next = ucas;
		lcas_next = lcas;
		masel_next = masel;
		
		case (state)
			M_IDLE: begin
				/* Wait for either the refresh due flag to be set (highest priority) or an access
				 * cycle to commence */
				if (refresh_due) begin
					state_next = M_REFRESH;
					
					/* We do CBR refreshes, so assert CAS's first ... */
					ucas_next = '1;
					lcas_next = '1;
				end
				else if (decoded && (uds || lds)) begin
					state_next = M_MUX;
					
					/* Assert one of the RAS's based on address 21 */
					ras0_next = !addr[21];
					ras1_next = addr[21];
				end
			end
			
			M_REFRESH: begin
				/* ... then assert RAS's */
				ras0_next = '1;
				ras1_next = '1;
				
				/* Wait out the refresh cycle period before negating control signals and returning
				 * back to the idle state */
				if (timer[REFRESH_WAIT_STATES]) begin
					ras0_next = '0;
					ras1_next = '0;
					ucas_next = '0;
					lcas_next = '0;
					
					if (PRECHARGE_WAIT_STATES < 2) begin
						state_next = M_IDLE;
					end
					else begin
						state_next = M_PRECHARGE;
					end
				end
			end
			
			M_MUX: begin
				/* Flip the address mux from row to column */
				state_next = M_CAS;
				
				masel_next = '1;
			end
			
			M_CAS: begin
				/* Assert CAS's based on the data strobes for this bus cycle */
				ucas_next = uds;
				lcas_next = lds;
				
				if (timer[ACCESS_CAS_WAIT_STATES-1]) begin
					if (!uds && !lds && as) begin
						/* If the data strobes are negated, but AS is still asserted, this indicates
						 * that a read-modify-write cycle is in progress. Negate CAS's while keeping
						 * RAS asserted. */
						state_next = M_RMW;
						
						ucas_next = '0;
						lcas_next = '0;
					end
					else if (!as) begin
						/* Ending the current cycle, negate all and return to the idle state */
						ras0_next = '0;
						ras1_next = '0;
						ucas_next = '0;
						lcas_next = '0;
						masel_next = '0;
						
						if (PRECHARGE_WAIT_STATES < 2) begin
							state_next = M_IDLE;
						end
						else begin
							state_next = M_PRECHARGE;
						end
					end
				end
			end
			
			M_RMW: begin
				/* Wait for the data strobes to be re-asserted and move back to the CAS state to
				 * complete the write portion of the cycle */
				if (uds || lds) begin
					state_next = M_CAS;
				end
			end
			
			M_PRECHARGE: begin
				/* Wait out the required precharge delay before returning to the idle state */
				if (PRECHARGE_WAIT_STATES == 1) begin
					state_next = M_IDLE;
				end
				else begin
					if (timer[PRECHARGE_WAIT_STATES-1]) begin
						state_next = M_IDLE;
					end
				end
			end
			
			default: state_next = XXXX;
		endcase
	end
	
	always_comb begin
		/* Assert DTACK */
		dtack = (state == M_MUX) | (state == M_CAS);
	end
endmodule /* dram_machine */
