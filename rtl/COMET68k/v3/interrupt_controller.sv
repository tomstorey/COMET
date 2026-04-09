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
	
	/* Synchronise certain interrupt requests */
	logic nmi_s, uart_irq_s, eth_irq_s, irq1_s, timer_irq_s, soft_irq_s;
	
	always_ff @(posedge clk) begin
		nmi_s <= nmi;
		uart_irq_s <= uart_irq;
		eth_irq_s <= eth_irq;
		irq1_s <= irq1;
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
	wire irq7_sources = |{(nmi & !nmi_ack), irq7};
	wire irq5_sources = |{uart_irq, irq5};
	wire irq4_sources = |{eth_irq, irq4};
	wire irq1_sources = |{irq1, timer_irq, soft_irq};
	wire [6:0] irqs = {irq7_sources, irq6, irq5_sources, irq4_sources, irq3, irq2, irq1_sources};
	
	always_comb begin
		if (boot_ff) begin
			if      (irqs[6])                 ipl = ~3'd7;
			else if (irqs[6:5] == 2'b01)      ipl = ~3'd6;
			else if (irqs[6:4] == 3'b001)     ipl = ~3'd5;
			else if (irqs[6:3] == 4'b0001)    ipl = ~3'd4;
			else if (irqs[6:2] == 5'b00001)   ipl = ~3'd3;
			else if (irqs[6:1] == 6'b000001)  ipl = ~3'd2;
			else if (irqs      == 7'b0000001) ipl = ~3'd1;
			else                              ipl = ~3'd0;
		end
		else begin
			ipl = ~3'd0;
		end
	end
	
	/* State machine */
	typedef enum logic [1:0] {
		M_IDLE,
		M_EXTERNAL,
		M_ONBOARD,
		XXXX
	} state_e;
	
	state_e state, state_next;
	logic vpa_next, iack_out_next;
	
	always_ff @(posedge clk) begin
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
	
	always_comb begin
		state_next = state;
		vpa_next = vpa;
		iack_out_next = iack_out;
		
		case (state)
			M_IDLE: begin
				if (iack) begin
					if (nmi_s || uart_irq_s || eth_irq_s || timer_irq_s && !irq1_s || soft_irq_s && !irq1_s) begin
						state_next = M_ONBOARD;
						vpa_next = '1;
					end
					else begin
						state_next = M_EXTERNAL;
						iack_out_next = '1;
					end
				end
			end
			
			M_EXTERNAL: begin
				if (!iack) begin
					state_next = M_IDLE;
					vpa_next = '0;
					iack_out_next = '0;
				end
				else begin
					vpa_next = autovec;
				end
			end
			
			M_ONBOARD: begin
				if (!iack) begin
					state_next = M_IDLE;
					vpa_next = '0;
				end
			end
			
			default: state_next = XXXX;
		endcase
	end
endmodule /* interrupt_controller */
