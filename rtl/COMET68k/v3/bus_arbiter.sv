/* Bus Arbiter
 *
 * Manages access to the system busses, prioritising requests between the following sources:
 *
 * Highest: On-board Ethernet controller
 *          External request level 0
 * Lowest:  External request level 1
 *
 * The arbiter should be clocked from the CPU clock.
 */
`default_nettype none

module bus_arbiter(
	input cpu_clk, reset,
	input as, bg,
	input br0, br1, eth_br,
	
	output logic own,
	output logic br,
	output logic bg0, bg1, eth_bg
);
	/* State machine */
	typedef enum logic [2:0] {
		M_IDLE,
		M_CPU_GRANT,
		M_BUS_VACATE,
		M_REQUEST_NEGATE,
		M_CPU_NEGATE,
		XXXX
	} state_e;
	
	state_e state, state_next;
	
	/* Timer flip flop
	 *
	 * When granting the bus to the ethernet controller, we have to monitor the bus to determine
	 * when the CPU has vacated it, and only grant the bus to the ethernet controller once the CPU
	 * has given it up. This is determined by AS being negated for two clocks in a row. */
	logic timer;
	
	dffe timer_i(
		.clk(cpu_clk),
		.d('1),
		.ena(state == M_BUS_VACATE),
		.clrn(state == M_BUS_VACATE),
		.q(timer)
	);
	
	
	/* State machine logic */
	logic eth_bg_next, bg0_next, bg1_next;
	
	always_ff @(posedge cpu_clk or posedge reset) begin
		if (reset) begin
			state <= M_IDLE;
			
			eth_bg <= '0;
			bg0 <= '0;
			bg1 <= '0;
		end
		else begin
			state <= state_next;
			
			eth_bg <= eth_bg_next;
			bg0 <= bg0_next;
			bg1 <= bg1_next;
		end
	end
	
	always_comb begin
		state_next = state;
		
		eth_bg_next = eth_bg;
		bg0_next = bg0;
		bg1_next = bg1;
		
		case (state)
			M_IDLE: begin
				if (eth_br || br0 || br1) begin
					state_next = M_CPU_GRANT;
				end
			end
			
			M_CPU_GRANT: begin
				if (bg) begin
					if (eth_br) begin
						/* Ethernet controller is requesting the bus, we should monitor the bus and
						 * only grant to the ethernet controller once the CPU has vacated it */
						if (!as) begin
							state_next = M_BUS_VACATE;
						end
					end
					else begin
						/* External peripheral is requesting the bus, assert bus grant
						 * immediately - the external peripherals arbiter must properly monitor the
						 * bus to determine when the CPU has vacated it */
						state_next = M_REQUEST_NEGATE;
						
						if (br0) begin
							bg0_next = '1;
						end
						else begin
							bg1_next = '1;
						end
					end
				end
			end
			
			M_BUS_VACATE: begin
				if (timer) begin
					if (!as) begin
						/* AS is observed negated after two clocks, grant bus */
						state_next = M_REQUEST_NEGATE;
						
						eth_bg_next = '1;
					end
					else begin
						/* AS has become asserted again */
						state_next = M_CPU_GRANT;
					end
				end
			end
			
			M_REQUEST_NEGATE: begin
				if ((eth_bg && !eth_br) || (bg0 && !br0) || (bg1 && !br1)) begin
					/* The currently granted requestor has stopped requesting */
					state_next = M_CPU_NEGATE;
					
					eth_bg_next = '0;
					bg0_next = '0;
					bg1_next = '0;
				end
			end
			
			M_CPU_NEGATE: begin
				if (!bg) begin
					state_next = M_IDLE;
				end
			end
			
			default: state_next = XXXX;
		endcase
	end
	
	always_comb begin
		/* The CPU board owns the bus when it hasnt granted it to either external request level */
		own = !bg0 & !bg1;
		
		/* Assert bus request towards the CPU any time we aren't in the idle state */
		br = !(state == M_IDLE);
	end
endmodule /* bus_arbiter */
