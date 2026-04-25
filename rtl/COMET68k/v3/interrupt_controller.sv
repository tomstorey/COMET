/* Interrupt Controller
 *
 * The interrupt controller prioritises and pends interrupt requests to the CPU.
 *
 * The following interrupt sources are prioritised in the following order:
 *
 * Highest: On-board NMI button at IRQ 7
 *          External IRQ 7
 *          External IRQ 6
 *          On-board UART at IRQ 5
 *          External IRQ 5
 *          On-board Ethernet controller at IRQ 4
 *          External IRQ 4
 *          External IRQ 3
 *          External IRQ 2
 *          External IRQ 1
 *          On-board timer/RTC at IRQ 1
 *  Lowest: Soft IRQ at IRQ 1
 *
 * The NMI button must be externally debounced.
 */
`default_nettype none

module interrupt_controller(
	input clk, reset,
	input boot_ff,
	input [19:16] addr,
	input a1, a2, a3,
	input as,
	input [2:0] fc,
	input nmi, irq7,
	input irq6,
	input uart_irq, irq5,
	input eth_irq, irq4,
	input irq3,
	input irq2,
	input irq1, timer_irq, soft_irq,
	input autovec,
	
	output logic vpa,
	output logic iack_out,
	output logic [2:0] ipl
);
	wire iack = as && (addr[19:16] == 4'b1111) && (fc == 3'b111);
	wire [2:0] iack_level = {a3, a2, a1};
	
	/* Synchronise these interrupt inputs as they are used in the state machine to determine
	 * whether an on-board or external interrupt is being acknowledged */
	logic nmi_s, uart_irq_s, eth_irq_s, timer_irq_s, soft_irq_s;
	
	always @(posedge clk) begin
		nmi_s <= nmi;
		uart_irq_s <= uart_irq;
		eth_irq_s <= eth_irq;
		timer_irq_s <= timer_irq;
		soft_irq_s <= soft_irq;
	end
	
	/* NMI ack flag */
	logic nmi_ack;
	
	dffe nmi_ack_i(
		.d('1),
		.clk(clk),
		.ena(nmi & iack & (iack_level == 3'd7)),
		.clrn(nmi),
		.q(nmi_ack)
	);
	
	/* IPLx priority encoder */
	always_comb begin
		if (boot_ff) begin
			if      ((nmi & !nmi_ack) || irq7)      ipl = 3'd7;
			else if (irq6)                          ipl = 3'd6;
			else if (uart_irq || irq5)              ipl = 3'd5;
			else if (eth_irq || irq4)               ipl = 3'd4;
			else if (irq3)                          ipl = 3'd3;
			else if (irq2)                          ipl = 3'd2;
			else if (irq1 || timer_irq || soft_irq) ipl = 3'd1;
			else                                    ipl = 3'd0;
		end
		else begin
			ipl = 3'd0;
		end
	end
	
	/* State machine */
	typedef enum logic [1:0] {
		M_IDLE,
		M_ONBOARD,
		M_EXTERNAL,
		XXXX
	} state_e;
	
	state_e state, state_next;
	logic vpa_next, iack_out_next;
	
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			state <= M_IDLE;
			vpa <= '0;
			iack_out <= '0;
		end
		else begin
			state <= state_next;
			vpa <= vpa_next;
			iack_out <= iack_out_next;
		end
	end
	
	wire onboard_irq = nmi_s & !nmi_ack & (iack_level == 3'd7) |
					   uart_irq_s & (iack_level == 3'd5) |
					   eth_irq_s & (iack_level == 3'd4) |
					   timer_irq_s & !irq1 & (iack_level == 3'd1) |
					   soft_irq_s & !timer_irq_s & !irq1 & (iack_level == 3'd1);
	
	always_comb begin
		state_next = state;
		vpa_next = vpa;
		iack_out_next = iack_out;
		
		case (state)
			M_IDLE: begin
				if (iack) begin
					if (onboard_irq) begin
						/* All on-board interrupts are autovectored */
						state_next = M_ONBOARD;
						vpa_next = '1;
					end
					else begin
						state_next = M_EXTERNAL;
						iack_out_next = '1;
					end
				end
			end
			
			M_ONBOARD: begin
				/* Wait for the IACK cycle to complete then negate VPA */
				if (!as) begin
					state_next = M_IDLE;
					vpa_next = '0;
				end
			end
			
			M_EXTERNAL: begin
				/* Wait for the IACK cycle to complete then negate VPA to end the autovector cycle.
				 * Otherwise, while waiting for that to happen, relay the AUTOVEC signal to VPA to
				 * enable external peripherals to autovector interrupts. */
				if (!as) begin
					state_next = M_IDLE;
					vpa_next = '0;
					iack_out_next = '0;
				end
				else begin
					vpa_next = autovec;
				end
			end
			
			default: state_next = XXXX;
		endcase
	end
endmodule /* interrupt_controller */
