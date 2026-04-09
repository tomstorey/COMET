/* Clock Divider
 *
 * Divides the incomming 40MHz oscillator into several sub clocks:
 *
 * 1:2 division produces 20MHz for the ethernet controller
 * 1:4 division produces 10MHz for the CPU
 * 1:64 division produces 625KHz for the timers
 */
`default_nettype none

module clock_divider
#(parameter BITS=6,
            ETH_CLK_TAP=0,
            CPU_CLK_TAP=1,
            TIMER_CLK_TAP=5)
(
	input osc_40mhz,
	
	output logic eth_clk,
	output logic cpu_clk,
	output logic timer_clk
);
	logic [BITS-1:0] divider;
	
	always_ff @(posedge osc_40mhz) begin
		divider <= divider + {{BITS-1{'0}}, '1};
	end
	
	always_comb begin
		eth_clk = divider[ETH_CLK_TAP];
		cpu_clk = divider[CPU_CLK_TAP];
		timer_clk = divider[TIMER_CLK_TAP];
	end
endmodule /* clock_divider */
