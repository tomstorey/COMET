/* This module implements a VMEbus like interruptor which is level sensitive, for use specifically
 * with COMETbus systems.
 *
 * COMETbus IACK drivers generate a fully qualified IACK signal on the CPU card, therefore the
 * interruptor does not need to qualify any signals itself. This likely makes this module
 * incompatible with systems that are strictly VME compliant.
 *
 * This interruptor is level sensitive, which means the interrupt request is generated as long as
 * the IRQ input is asserted, if the module is enabled. This is intended for use with interrupt
 * sources which remain active until the interrupting condition is cleared.
 *
 * The ILMATCH parameter should be supplied to enable an instance of this module to determine when
 * it is the serviced interruptor. This should ideally be supplied as a parameter attached to the
 * instance, rather than modifying this module file.
 */
module interruptor(
	/* Inputs */
	reset, sysclk,
	as, addr,
	enable,
	iackin,
	irq,
	
	/* Outputs */
	iackout,
	vec,
	irq_drv
);
	/* Inputs */
	input sysclk, reset;
	input as;
	input [3:1] addr;
	input enable;
	input iackin;
	input irq;
	
	/* Outputs */
	output iackout;
	output vec;
	output irq_drv;
	
	/* Public parameters **************************************************************************/
	parameter ILMATCH = 0;		/* Supply as parameter to instance */
	
	/* IRQ input synchroniser *********************************************************************/
	reg irq_s, irq_ss;
	
	always @(posedge sysclk) begin
		irq_s <= irq & enable;
		irq_ss <= irq_s;
	end
	
	/* Interruptor state machine ******************************************************************/
	reg state;
	reg state_next;
	
	parameter M_WAITING = 1'b0;
	parameter M_REQUESTING = 1'b1;
	
	always @(posedge sysclk or posedge reset) begin
		if (reset) begin
			state <= M_WAITING;
		end
		else begin
			state <= state_next;
		end
	end
	
	always begin
		state_next = state;
		
		case (state)
			M_WAITING: begin
				if (enable && irq_ss && !iackin) begin
					state_next = M_REQUESTING;
				end
			end
			
			M_REQUESTING: begin
				if (!enable || !irq_ss) begin
					state_next = M_WAITING;
				end
			end
		endcase
	end
	
	/* Interrupt level match */
	wire ilmatch = as & (addr[3:1] == ILMATCH);
	
	/* Generate an interrupt when ever interrupts are enabled and the IRQ input is asserted (and
	 * synchronised) */
	wire irq_drv = irq_ss & enable;
	
	/* IACKIN may be propagated whenever this requestor is:
	 *
	 * a) not actively requesting an interrupt, or when this interruptor is disabled
	 * b) actively requesting an interrupt, but the acknowledged interrupt level does not match this
	 *    interruptors request
	 *
	 * Otherwise, IACKIN is not propagated as this interruptor is being acknowledged. */
	wire iackout = iackin & as & ((state == M_WAITING) |
							      (state == M_REQUESTING) & !ilmatch);
	
	/* Assert the vector acquire output when this interruptor is acknowledged */
	wire vec = iackin & as & (state == M_REQUESTING) & ilmatch;
endmodule /* interruptor */

