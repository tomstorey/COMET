/* Bus Watchdog
 *
 * The bus watchdog monitors the AS signal, and when ever it is asserted, a timer is started. If
 * that timer reaches its terminal count while AS is still asserted, the watchdog will assert
 * BERR to end the current bus cycle.
 *
 * BG can be used to disable the watchdog during bus grants to peripherals which do not support
 * bus errors for cycle termination.
 *
 * The following bus cycle types are covered by this watchdog:
 *
 * Cycle type               Normal termination method               Timeout side effect
 * ----------------------   -------------------------------------   --------------------------------
 * Memory or peripheral     DTACK asserted                          Bus error exception
 * Vectored interrupt       DTACK asserted by interruptor           Spurious interrupt exception
 * Autovectored interrupt   VPA asserted by interrupt controller    Spurious interrupt exception
 *                          (internally asserted, or externally
 *                           through n_autovec signal)
 *
 * A reset input is not used, because negation of AS causes the timer to reset, and AS will negate
 * during system reset.
 */
`default_nettype none

module bus_watchdog
#(parameter BITS=6)
(
	input cpu_clk,
	input as,
	input bg,
	
	output logic berr
);
	logic [BITS-1:0] counter;
	
	always_ff @(posedge cpu_clk) begin
		if (!as || bg) begin
			counter <= '0;
		end
		else begin
			if (&counter) begin
				counter <= '1;
			end
			else begin
				counter <= counter + {{BITS-1{'0}}, '1};
			end
		end
	end
	
	always_comb begin
		/* Assert BERR once the terminal count is reached */
		berr = &counter;
	end
endmodule /* bus_watchdog */
