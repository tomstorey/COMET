/* X-bus Machine
 *
 * The X-bus is an 8-bit bus on the board that connects all of the smaller peripherals to the rest
 * of the system. It also houses the ROMs.
 *
 * To permit all 8-bit devices to be readable and writeable at byte addresses, the X-bus machine
 * implements the required handling of buffers and latches between the X-bus and the CPU local bus
 * along with a synthesised A0 address signal derived from the LDS.
 *
 * Through the latches and buffers it enables words to be read from a single ROM. At the original
 * design frequency of 10MHz CPU and 40MHz CPLD clocks, this can be accomplished within a single
 * bus cycle, requiring no wait states.
 *
 * ROM remapping is performed. After a system reset, ROM1 is accessible from address 0 until the
 * CPU has read the initial SP and PC values. Once the CPU makes an access to the ROM1 address
 * space (0xF8XXXX+), it is remapped to that address space and DRAM becomes available from address
 * 0 instead. This is accomplished through the boot_ff flag.
 *
 * The following address map is implemented in this module:
 *
 * 0xCXXXXX     On-board peripherals
 *    0XXXX         Debug display - always decoded and assumed to exist, generate DTACK for it
 *    1XXXX         On-board IO (LEDs, configuration jumpers, etc)
 *    2XXXX         TL16C2552 dual UART
 *    3XXXX         DP8570A timer/RTC
 * 0xFXXXXX     ROMs
 *
 * Note: Ethernet chip select is decoded and handled through the ethernet interface module.
 */
`default_nettype none

module xbus_machine
#(parameter ROM_WAIT_STATES=3 // Min 3
)
(
	input clk, reset,
	input [23:16] addr,
	input as, uds, lds, write,
	input [2:0] fc,
	
	output logic xa0,
	output logic lreg_le, lreg_oe, ubuf_oe, lbuf_oe,
	output logic rom0_cs, rom1_cs,
	output logic debug_cs, io_cs, uart_cs, timer_cs,
	output logic dtack,
	output logic decoded,
	output logic boot_ff
);
	/* Decoders for various peripherals/ROMs */
	wire rom0_decoded = as & (addr[23:19] == 5'b11110) & (fc != 3'b111);
	wire rom1_0_decoded = as & (addr[23:19] == 5'b00000) & (fc != 3'b111) & !boot_ff;
	wire rom1_f_decoded = as & (addr[23:19] == 5'b11111) & (fc != 3'b111);
	wire debug_decoded = as & (addr[23:16] == 8'hC0) & (fc != 3'b111);
	wire io_decoded = as & (addr[23:16] == 8'hC1) & (fc != 3'b111);
	wire uart_decoded = as & (addr[23:16] == 8'hC2) & (fc != 3'b111);
	wire timer_decoded = as & (addr[23:16] == 8'hC3) & (fc != 3'b111);
	
	always_comb begin
		decoded = rom0_decoded | rom1_0_decoded | rom1_f_decoded | io_decoded | uart_decoded | timer_decoded;
	end
	
	/* Boot flip-flop
	 *
	 * After a reset, boot_ff is set once the CPU makes its first access to the ROM1 address space
	 * beginning at 0xF8XXXX. Once set, ROM1 is no longer accessible from address 0, and DRAM
	 * becomes available from address 0 instead. */
	dffe boot_ff_i(
		.d('1),
		.clk(clk),
		.ena(rom1_f_decoded),
		.clrn(!reset),
		.q(boot_ff)
	);
	
	/* State machine */
	typedef enum logic [2:0] {
		M_IDLE,
		M_ROM_LATCH_LOWER,
		M_ROM_CYCLE_END,
		M_XA0_SETUP,
		M_PERIPH_CYCLE_END,
		XXXX
	} state_e;
	
	state_e state, state_next;
	
	/* ROM wait state timer */
	logic [ROM_WAIT_STATES-2:0] rom_timer;
	logic [ROM_WAIT_STATES-2:0] rom_timer_next;
	
	always_ff @(posedge clk) begin
		if (reset) begin
			rom_timer <= '0;
		end
		else begin
			rom_timer <= rom_timer_next;
		end
	end
	
	always_comb begin
		rom_timer_next = '0;
		
		if (state == M_ROM_LATCH_LOWER) begin
			rom_timer_next = {rom_timer[ROM_WAIT_STATES-3:0], '1};
		end
	end
	
	/* State machine logic */
	logic xa0_next;
	
	always_ff @(posedge clk) begin
		if (reset) begin
			state <= M_IDLE;
			
			xa0 <= '0;
		end
		else begin
			state <= state_next;
			
			xa0 <= xa0_next;
		end
	end
	
	always_comb begin
		state_next = state;
		
		xa0_next = xa0;
		
		case (state)
			M_IDLE: begin
				if ((rom0_decoded || rom1_0_decoded || rom1_f_decoded) && (uds || lds) && !write) begin
					/* One of the ROMs is decoded, set up for latching the lower byte. We always
					 * do word reads from the ROMs regardless of what the CPU is asking for, it will
					 * take what it needs from the data bus at the end of the cycle. */
					state_next = M_ROM_LATCH_LOWER;
					
					xa0_next = '1;
				end
				else if (debug_decoded || (io_decoded || uart_decoded || timer_decoded) && (uds ^ lds)) begin
					/* Some X-bus peripherals, such as the TL16C2552, seem to be sensitive to
					 * address setup times. Hop through one state that allows XA0 to be set up
					 * with some amount of hold time before asserting a chipselect. */
					state_next = M_XA0_SETUP;
					
					xa0_next = lds;
				end
			end
			
			M_ROM_LATCH_LOWER: begin
				/* Wait out the number of required wait states for ROM accesses */
				if (rom_timer[ROM_WAIT_STATES-2]) begin
					state_next = M_ROM_CYCLE_END;
					
					xa0_next = '0;
				end
			end
			
			M_ROM_CYCLE_END: begin
				/* Wait for AS to be negated to end the bus cycle */
				if (!as) begin
					state_next = M_IDLE;
				end
			end
			
			M_XA0_SETUP: begin
				/* Hop through this state to provide some time to set up XA0 */
				state_next = M_PERIPH_CYCLE_END;
			end
			
			M_PERIPH_CYCLE_END: begin
				/* Wait for AS to be negated to end the bus cycle */
				if (!as) begin
					state_next = M_IDLE;
				end
			end
			
			default: state_next = XXXX;
		endcase
	end
	
	always_comb begin
		/* Control signals */
		lreg_le = (state == M_ROM_LATCH_LOWER) |
				  (state == M_PERIPH_CYCLE_END) & !write;
				  
		lreg_oe = (state == M_ROM_LATCH_LOWER) |
				  (state == M_ROM_CYCLE_END) |
				  (state == M_PERIPH_CYCLE_END) & !write;
				  
		ubuf_oe = (state == M_ROM_LATCH_LOWER) |
				  (state == M_ROM_CYCLE_END) |
				  (state == M_PERIPH_CYCLE_END) & !write |
				  (state == M_PERIPH_CYCLE_END) & write & uds;
				  
		lbuf_oe = (state == M_PERIPH_CYCLE_END) & write & lds;
		
		rom0_cs = rom0_decoded;
		
		rom1_cs = rom1_0_decoded | rom1_f_decoded;
		
		debug_cs = debug_decoded & (state == M_PERIPH_CYCLE_END);
		
		io_cs = io_decoded & (state == M_PERIPH_CYCLE_END);
		
		uart_cs = uart_decoded & (state == M_PERIPH_CYCLE_END);
		
		timer_cs = timer_decoded & (state == M_PERIPH_CYCLE_END);
		
		dtack = (state == M_ROM_CYCLE_END) |
				(state == M_XA0_SETUP) |
				(state == M_PERIPH_CYCLE_END);
	end
endmodule /* xbus_machine */
