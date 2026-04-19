/* Am7990 Interface Controller
 *
 * This module is responsible for decoding accesses to the Ethernet controller, as well as
 * sequencing accesses to and from it through the use of the DAS and READY signals.
 *
 * The Ethernet controller is decoded in the address space 0xC4XXXX.
 */
`default_nettype none

module am7990_interface(
	input [23:16] addr,
	input as,
	input uds,
	input lds,
	input eth_bg,
	input dtack_in,
	input eth_das_in,
	input eth_ready_in,
	
	output logic dtack,
	output logic decoded,
	output logic eth_das,
	output logic eth_ready,
	output logic eth_cs
);
	always_comb begin
		/* Access to the Ethernet controller is by word only in the address space 0xC4XXXX */
		decoded = !eth_bg & as & uds & lds & (addr[23:16] == 8'hC4);
		
		/* Chip select */
		eth_cs = decoded;
		
		/* DTACK is only asserted during a slave cycle, and is essentially just a relayed copy of
		 * the Ethernet controllers READY signal */
		dtack = decoded & eth_ready_in;
		
		/* Assert DAS to the Ethernet controller when its address space is decoded (slave cycle) */
		eth_das = decoded;
		
		/* Assert READY towards the Ethernet controller during master cycles when DTACK has been
		 * asserted by some other device in the system */
		eth_ready = eth_bg & eth_das_in & dtack_in;
	end
endmodule /* am7990_interface */
