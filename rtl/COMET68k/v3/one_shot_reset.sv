/* One-shot Reset
 *
 * Generates a single reset pulse from the incomming reset. Subsequent reset pulses are masked out.
 *
 * This is useful for initialising logic once per power-up. An example use case in the COMET68k
 * system is the DRAM controller - it will continue to refresh DRAM contents through all but the
 * first reset. This permits memory contents to be maintained across reboots.
 */
`default_nettype none

module one_shot_reset(
	input reset_in,
	output logic reset_out
);
	wire gate;
	
	dff gate_i(
		.d('1),
		.clk(!reset_in),
		.q(gate)
	);
	
	always_comb begin
		reset_out = reset_in & !gate;
	end
endmodule /* one_shot_reset */
