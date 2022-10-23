`timescale 1ns/1ns

/* clk_div - Clock Divider
 *
 * Divides the incomming 40MHz clock into several sub clocks to drive various components:
 *
 * 1:2 division produces 20MHz for the ethernet controller
 * 1:4 division produces 10MHz for the CPU
 * 1:64 division produces 625KHz for the timers
 *
 * No reset is implemented, all of the sub clocks are produced continuously.
 */
module clk_div(
    input osc_40mhz,
    output eth_clk,
    output cpu_clk,
    output timer_clk
);
    /* A 6 bit counter to act as the divider */
    reg [5:0] divider;
    
    /* Start the counter at 0 */
    initial divider = 0;
    
    /* For every incoming clock edge, increment the counter */
    always_ff @(posedge osc_40mhz) begin
      divider <= divider + 1'b1;
    end

    /* Assign clock outputs */
    assign eth_clk = divider[0];
    assign cpu_clk = divider[1];
    assign timer_clk = divider[5];
endmodule

/* int_ctl - Interrupt Controller
 *
 * Prioritises and signals interrupts towards the CPU, in order of highest to lowest priority:
 *
 *       Active   Autovec
 * IRQ   Level    Internal?   Description
 * ---   ------   ---------   -----------
 *  7    Low      No          External IRQ7
 *  6    Low      No          External IRQ6
 *  5    High     Yes         UARTs
 *  5    Low      No          External IRQ5
 *  4    Low      Yes         Ethernet controller
 *  4    Low      No          External IRQ4
 *  3    Low      No          External IRQ3
 *  2    Low      No          External IRQ2
 *  1    Low      No          External IRQ1
 *  1    Low      Yes         Timer
 *
 * No reset is implemented, the interrupt priority level is asserted as long as an IRQ is pending.
 *
 * Interrupt sources handled by the PCH may be active high or low according to the above table. All
 * internally handled interrupts are autovectored.
 *
 * All external IRQ signals are active low, and are only autovectored by the PCH if the iack_in
 * signal is asserted by the interruptor. Otherwise, the interruptor may supply a vector to the CPU
 * by asserting DTACK/ instead.
 */
 module int_ctl(
    input clk,
    input n_irq7,
    input n_irq6,
    input uart_irq,
    input n_irq5,
    input n_eth_irq,
    input n_irq4,
    input n_irq3,
    input n_irq2,
    input n_irq1,
    input n_timer_irq,
    input cpu_iack,
    input n_autovec,
    output reg [2:0] ipl,
    output n_vpa,
    output n_iack_out
);
    /* IPL should start at 0 for no interrupt */
    initial ipl = ~3'd0;
    
    /* A flag that indicates the current highest priority on-board IRQ is acknowledged. Once set,
     * this prevents further interrupts, even of higher priority, from being signalled to the CPU
     * until the currently signalled interrupt has been fully acknowledged. */
    reg ob_irq_ack = 0;
    
    /* Ditto above except for external interrupt sources */
    reg ext_irq_ack = 0;
    
    /* On the rising edge of each clock, assert the highest interrupt priority level that exists,
     * as long as no other interrupt is currently in the process of being acknowledged */
    always_ff @(posedge clk) begin
        if (!ob_irq_ack && !ext_irq_ack) begin
            if (!n_irq7) begin
                /* Assert IPL 7 for external IRQ */
                ipl <= ~3'd7;
                ext_irq_ack <= 1;
            end
            else if (!n_irq6) begin
                /* Assert IPL 6 for external IRQ */
                ipl <= ~3'd6;
                ext_irq_ack <= 1;
            end
            else if (uart_irq) begin
                /* Assert IPL 5 for UART IRQs */
                ipl <= ~3'd5;
                ob_irq_ack <= 1;
            end
            else if (!n_irq5) begin
                /* Assert IPL 5 for external IRQ */
                ipl <= ~3'd5;
                ext_irq_ack <= 1;
            end
            else if (!n_eth_irq) begin
                /* Assert IPL 4 for ethernet controller IRQ */
                ipl <= ~3'd4;
                ob_irq_ack <= 1;
            end
            else if (!n_irq4) begin
                /* Assert IPL 4 for external IRQ */
                ipl <= ~3'd4;
                ext_irq_ack <= 1;
            end
            else if (!n_irq3) begin
                /* Assert IPL 3 for external IRQ */
                ipl <= ~3'd3;
                ext_irq_ack <= 1;
            end
            else if (!n_irq2) begin
                /* Assert IPL 2 for external IRQ */
                ipl <= ~3'd2;
                ext_irq_ack <= 1;
            end
            else if (!n_irq1) begin
                /* Assert IPL 1 for external IRQ */
                ipl <= ~3'd1;
                ext_irq_ack <= 1;
            end
            else if (!n_timer_irq) begin
                /* Assert IPL 1 for timer IRQ - the timer IRQ is handled slightly differently to all
                 * other IRQs - it is considered to be the absolute lowest priority of all to be
                 * most compliant with FreeRTOS tick interrupt requirements. This means it is
                 * treated with lower priority than an external IRQ1, whereas all other external
                 * IRQs are treated with lower priority than on-board IRQs. */
                ipl <= ~3'd1;
                ob_irq_ack <= 1;
            end
            else begin
                /* No internally handled IRQ is pending, fully negate IPL */
                ipl <= ~3'd0;
            end
        end
        
        if (!cpu_iack) begin
            /* If iack is no longer asserted, clear the IRQ ack flags */
            ob_irq_ack <= 0;
            ext_irq_ack <= 0;
        end
    end
    
    /* Assert the VPA signal when an IRQ is acknowledged to auto-vector it */
    assign n_vpa = ((ob_irq_ack & cpu_iack) | (ext_irq_ack & !n_autovec)) ? 1'b0 : 1'bZ;
    
    /* If an interrupt is being acknowledged by the CPU, but it is not in response to an on-board
     * IRQ, assert the downstream interrupt acknowledge signal to allow an off-board peripheral to
     * acknowledge the interrupt */
    assign n_iack_out = ~(ext_irq_ack & cpu_iack);
endmodule

/* bus_arb - Bus Arbiter
 *
 * Arbitrates bus access between the CPU and on-board and external requestors. Of the external bus
 * request signals, BR1 is considered to be of higher priority to conform with VME priority order.
 * Bus access is granted with the following priorities:
 *
 * Highest: On-board ethernet controller
 *          External BR1
 * Lowest:  External BR0
 *
 * Only the two-wire arbitration interface/protocol is implemented.
 *
 * TODO:
 * The running signal from the memory machine is taken as an input to prevent bus arbitration from
 * handing over to another device until the CPU has read the reset vector.
 */
module bus_arb(
    input clk,
    input n_reset,
    input n_as,
    input n_eth_br,
    input n_br1,
    input n_br0,
    input n_bg,
//    input running,
    output reg n_eth_bg,
    output reg n_bg1,
    output reg n_bg0,
    output reg n_br
);
    /* Arbiter state machine */
    localparam [2:0]
        ARB_WAIT_REQ = 3'd0,
        ARB_WAIT_CPU_GRANT = 3'd1,
        ARB_GRANT_ETH = 3'd2,
        ARB_GRANT_BR1 = 3'd3,
        ARB_GRANT_BR0 = 3'd4,
        ARB_WAIT_CPU_RELEASE = 3'd5;
    
    reg [2:0] arb_state = ARB_WAIT_REQ;
    
    always_ff @(posedge clk) begin
        if (!n_reset) begin
            /* Reset states to defaults, which assumes CPU control of the bus */
            n_br <= 1'b1;
            n_eth_bg <= 1'b1;
            n_bg1 <= 1'b1;
            n_bg0 <= 1'b1;
            arb_state <= ARB_WAIT_REQ;
        end
        else begin
            case (arb_state)
                /* Wait for a bus request */
                ARB_WAIT_REQ:
                    if (!(n_eth_br && n_br1 && n_br0)) begin
                        /* When the bus has been requested, assert BR towards the CPU */
                        n_br <= 1'b0;
                        
                        arb_state <= ARB_WAIT_CPU_GRANT;
                    end
                    
                /* Wait for the CPU to grant the bus - BG should be low while AS should be high to
                 * indicate that it has completed its bus cycle */
                ARB_WAIT_CPU_GRANT:
                    if (!n_bg && n_as) begin
                        /* Prioritise the bus requests and assert the bus grant signal for the
                         * highest pending priority */
                        if (!n_eth_br) begin
                            n_eth_bg <= 1'b0;
                            arb_state <= ARB_GRANT_ETH;
                        end
                        else if (!n_br1) begin
                            n_bg1 <= 1'b0;
                            arb_state <= ARB_GRANT_BR1;
                        end
                        else begin
                            n_bg0 <= 1'b0;
                            arb_state <= ARB_GRANT_BR0;
                        end
                    end
                    
                /* Wait for the ethernet controller to negate its bus request signal */
                ARB_GRANT_ETH:
                    if (n_eth_br) begin
                        n_eth_bg <= 1'b1;
                        arb_state <= ARB_WAIT_CPU_RELEASE;
                    end
                    
                /* Wait for BR1 to be negated */
                ARB_GRANT_BR1:
                    if (n_br1) begin
                        n_bg1 <= 1'b1;
                        arb_state <= ARB_WAIT_CPU_RELEASE;
                    end
                    
                /* Wait for BR0 to be negated */
                ARB_GRANT_BR0:
                    if (n_br0) begin
                        n_bg0 <= 1'b1;
                        arb_state <= ARB_WAIT_CPU_RELEASE;
                    end
                    
                /* Negate the bus request signal towards the CPU, and wait for it to negate the
                 * bus grant signal towards the arbiter. Or, if there is another pending bus
                 * request then proceed to grant access to that requestor. */
                ARB_WAIT_CPU_RELEASE:
                    if (!(n_eth_br && n_br1 && n_br0) && !n_br) begin
                        /* Only proceed to grant another pending bus request if one is pending and
                         * the arbiter has not negated BR towards the CPU. If BR is negated towards
                         * the CPU and then the arbiter recognises another pending bus request while
                         * still waiting for the CPU to negate its bus grant signal, this would
                         * result in two masters thinking they own the bus. */
                        arb_state <= ARB_WAIT_CPU_GRANT;
                    end
                    else begin
                        /* Negate our bus request signal towards the CPU - after this, the arbiter
                         * cannot grant another pending request until returning to the ARB_WAIT_REQ
                         * state and performing the bus arbitration sequence over again. */
                        n_br <= 1'b1;
                        
                        if (n_bg) begin
                            arb_state <= ARB_WAIT_REQ;
                        end
                    end
            endcase
        end
    end
endmodule



/* mem_mach - Memory Machine
 *
 * Implements a state machine that enabled read/write access to all of the various memories and
 * on-board peripherals.
 *
 * The memory machine also schedules and performs DRAM refreshes.
 *
 * The memory machine implements the following memory map:
 *
 * Address range     Size   Description
 * -------------     ----   -----------
 * 0x000000-0FFFFF   1MB    ROM space after reset to allow loading of initial SP and PC
 * 0x000000-3FFFFF   4MB    RAM space after SP and PC are loaded
 * 0x400000-4FFFFF   1MB    Operational ROM space after reset vector has been read
 * 0x500000-50FFFF   64KB   On-board IO ports (further decoding performed externally)
 * 0x510000-51FFFF   64KB   UARTs
 * 0x520000-52FFFF   64KB   Timer
 * 0x530000-53FFFF   64KB   Ethernet controller
 *
 * Remaining address space is to be decoded off-board by the peripheral(s) that use it. These
 * off-board peripherals should also generate DTACK and BERR accordingly.
 *
 * The PCH will generate DTACK for all on-board address spaces, and implements a timer that
 * asserts BERR if no DTACK is observed before it times out.
 *
 * TODO as an experiment: limit some address ranges to supervisor mode only - such as the on-board
 * IO and peripherals?
 */
module mem_mach
#(parameter REFRESH_CLOCKS=625)
(
    input clk,
    input cpu_clk,
    input n_reset,
    input [23:16] addr,
    input n_as,
    input n_uds,
    input n_lds,
    input n_write,
    
    inout n_dtack,
    
    output reg n_berr,
    output reg a0,
    
    //output mm_running,
    
    output reg n_xdata_ubuf_oe,
    output reg n_xdata_lbuf_oe,
    output reg n_xdata_lreg_oe,
    output reg n_xdata_lreg_le,
    
    output n_ras0,
    output n_ras1,
    output n_ucas,
    output n_lcas,
    output reg n_ras_mux,
    output reg n_cas_mux,
    
    output reg n_rom_cs,
    output reg n_io_cs,
    output reg n_uart_cs,
    output reg n_timer_cs,
    output reg n_eth_cs
);
    /* Characteristics of the memory machine. Wait state counts are inclusive of the zero count,
     * which is to say that a value of 1 results in 2 effective counts. */
    localparam
        /* 4 effective wait states for the ROMs enables support for upto 100ns ROMs to be used,
         * while permitting 0 CPU wait states before asserting DTACK */
        ROM_WAIT_STATES = 3'd3,
        
        /* xdata_ubuf_dir states for reads/writes */
        UPPER_BYTE_DIR_READ = 1'b0,
        UPPER_BYTE_DIR_WRITE = 1'b1,
        
        /* Wait states for RAS */
        RAS_WAIT_STATES = 3'd1,
        
        /* DRAM precharge wait states (delay in between DRAM accesses/refreshes) */
        PRECHARGE_WAIT_STATES = 3'd1,
        
        /* DRAM refresher parameters */
        REFRESH_WAIT_STATES = 3'd2;
    
    /* A latch that determines whether the CPU has completed its reset sequence and has begun to
     * execute code. This feeds into address decoding to determine whether the ROMs or RAM are
     * accessible from address 0. */
    reg running;
    
    /* Memory machine state machine */
    localparam [2:0]
        MM_WAIT_AS = 0,
        MM_ROM_LOWER_LATCH = 1,
        MM_DRAM_RAS = 2,
        MM_DRAM_RMW_OR_TERM = 3,
        MM_DRAM_PRECHARGE = 4,
        MM_WAIT_AS_NEGATE = 5;
    
    reg [2:0] mm_state;
    
    /* Wait state counters */
    reg [2:0] mm_wait_states;
    reg [2:0] dr_wait_states;
    
    /* DRAM refresh state machine */
    reg [9:0] dram_refresh_timer;
    reg refreshing_dram;
    
    localparam [2:0]
        DR_WAIT_FLAG = 0,
        DR_CHECK_MM_ACCESS = 1,
        DR_CAS = 2,
        DR_RAS = 3,
        DR_PRECHARGE = 4;
    
    reg [2:0] dr_state;
    
    /* A register to hold the state of DTACK as asserted by the memory machine */
    reg dtack_asserted;
    
    /* A flag that determines if the DRAM is currently in use by the memory machine for non-refresh
     * purposes */
    reg accessing_dram;
    
    /* Registers that can be set via various state machines, and which are then used to drive the
     * output RAS/CAS signals */
    reg n_mm_ras0;
    reg n_mm_ras1;
    reg n_mm_ucas;
    reg n_mm_lcas;
    reg n_dr_ras;
    reg n_dr_cas;
    
    /* Set the running flag when an address in the operational ROM space is seen */
    always @(posedge clk) begin
        if (!n_reset) begin
            running <= 1'b0;
        end
        else if (addr[23:20] == 4'h4) begin
            running <= 1'b1;
        end
    end
    
    /* DRAM refresher, implements CAS before RAS refreshing */
    always @(posedge clk) begin
        if (!n_reset) begin
            dram_refresh_timer <= REFRESH_CLOCKS;
            dr_state <= DR_WAIT_FLAG;
            refreshing_dram <= 1'b0;
            n_dr_ras <= 1'b1;
            n_dr_cas <= 1'b1;
            dr_wait_states <= 3'd0;
        end
        else begin
            if (dram_refresh_timer == 8'd0) begin
                refreshing_dram <= 1'b1;
                dram_refresh_timer <= REFRESH_CLOCKS;
            end
            else begin
                dram_refresh_timer <= dram_refresh_timer - 8'd1;
            end
        end
        
        case (dr_state)
            /* Wait for the refreshing_dram flag to be set. This flag indicates to the memory
             * machine that DRAM refreshing is occurring, and thus prevents it from making accesses
             * to DRAM until the flag clears so that the refresh can occurr. */
            DR_WAIT_FLAG:
                if (refreshing_dram == 1'b1) begin
                    dr_state <= DR_CHECK_MM_ACCESS;
                end
                
            /* In the case where a DRAM refresh is scheduled on the same clock as a DRAM access
             * begins, a second clock period is required before a DRAM refresh can commence. If a
             * DRAM access is in process, this will thus have priority over a refresh. */
            DR_CHECK_MM_ACCESS:
                if (accessing_dram == 1'b0) begin
                    dr_state <= DR_CAS;
                    n_dr_cas <= 1'b0;
                end
                
            /* Gives the CAS 1 clock to be asserted before asserting RAS, which effects the refresh
             * cycle */
            DR_CAS:
                begin
                    n_dr_ras <= 1'b0;
                    dr_wait_states <= 3'd2;
                    dr_state <= DR_RAS;
                end
                
            /* RAS timing */
            DR_RAS:
                if (dr_wait_states == 3'd0) begin
                    /* Negate all signals and commence precharge delay */
                    n_dr_ras <= 1'b1;
                    n_dr_cas <= 1'b1;
                    dr_wait_states <= PRECHARGE_WAIT_STATES;
                    dr_state <= DR_PRECHARGE;
                end
                else begin
                    dr_wait_states <= dr_wait_states - 3'd1;
                end
                
            /* Enforce a delay between DRAM accesses/refreshes to meet Trp timing */
            DR_PRECHARGE:
                if (dr_wait_states == 3'd0) begin
                    refreshing_dram <= 1'b0;
                    dr_state <= DR_WAIT_FLAG;
                end
                else begin
                    dr_wait_states <= dr_wait_states - 3'd1;
                end
        endcase
    end
    
    /* Decoder and sequencer */
    always @(posedge clk) begin
        if (!n_reset) begin
            /* Reset state machine etc */
            mm_wait_states <= 3'd0;
            mm_state <= MM_WAIT_AS;
            dtack_asserted <= 1'b0;
            accessing_dram <= 1'b0;
            n_berr <= 1'b1;
            a0 <= 1'b0;
            n_xdata_ubuf_oe <= 1'b1;
            n_xdata_lbuf_oe <= 1'b1;
            n_xdata_lreg_oe <= 1'b1;
            n_xdata_lreg_le <= 1'b1;
            n_mm_ras0 <= 1'b1;
            n_mm_ras1 <= 1'b1;
            n_mm_ucas <= 1'b1;
            n_mm_lcas <= 1'b1;
            n_ras_mux <= 1'b1;
            n_cas_mux <= 1'b1;
            n_rom_cs <= 1'b1;
            n_io_cs <= 1'b1;
            n_uart_cs <= 1'b1;
            n_timer_cs <= 1'b1;
            n_eth_cs <= 1'b1;
        end
        else begin
            case (mm_state)
                MM_WAIT_AS:
                    if (!n_as) begin
                        if (!running) begin
                            /* Performing a read from ROM during CPU initialisation */
                            if (addr[23:20] == 4'h0 && n_write) begin
                                /* CPU is reading the reset vector and will perform 4x word reads,
                                 * set up to read an odd byte from the ROM */
                                n_rom_cs <= 1'b0;
                                a0 <= 1'b1;
                                n_xdata_lreg_oe <= 1'b0;
                                n_xdata_lreg_le <= 1'b0;
                                mm_wait_states <= ROM_WAIT_STATES;
                                dtack_asserted <= 1'b1;
                                
                                mm_state <= MM_ROM_LOWER_LATCH;
                            end
                            else begin
                                /* Invalid access (write or address) */
                                n_berr <= 1'b0;
                                
                                mm_state <= MM_WAIT_AS_NEGATE;
                            end
                        end /* !running */
                        else begin
                            /* CPU is executing code */
                            if (addr[23:22] == 2'b00 && refreshing_dram == 1'b0) begin
                                /* On-board DRAM 0x[0123]XXXXX */
                                dtack_asserted <= 1'b1;
                                
                                /* Present row to DRAMs */
                                n_ras_mux <= 1'b0;
                                
                                /* Accessing DRAM, prevents the refresher from trying to assert DRAM
                                 * control signals at the same time */
                                accessing_dram <= 1'b1;
                                
                                /* Based on A21, select either of the two DRAMs */
                                if (addr[21] == 1'b0) begin
                                    n_mm_ras0 <= 1'b0;
                                end
                                else begin
                                    n_mm_ras1 <= 1'b0;
                                end
                                
                                /* Set RAS to CAS wait states */
                                mm_wait_states <= RAS_WAIT_STATES;
                                
                                /* Count down RAS wait states */
                                mm_state <= MM_DRAM_RAS;
                            end /* On-board DRAM 0x[0123]XXXXX */
                            else if (addr[23:20] == 4'h4) begin
                                /* ROM during run time 0x4XXXXX */
                                if (!n_write && !n_uds && !n_lds) begin
                                    /* Word writes to ROM unsupported */
                                    n_berr <= 1'b0;
                                    
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                                else if (!n_lds) begin
                                    /* Lower (odd) byte R/W, which can also lead to R/W of the upper
                                     * (even) byte for a word - set up for latching */
                                    n_rom_cs <= 1'b0;
                                    a0 <= 1'b1;
                                    dtack_asserted <= 1'b1;
                                    
                                    if (n_write) begin
                                        /* Reading - set up for latching */
                                        n_xdata_lreg_oe <= 1'b0;
                                        n_xdata_lreg_le <= 1'b0;
                                        mm_wait_states <= ROM_WAIT_STATES;
                                
                                        mm_state <= MM_ROM_LOWER_LATCH;
                                    end
                                    else begin
                                        /* Writing - set up for buffering the lower byte */
                                        n_xdata_lbuf_oe <= 1'b0;
                                        
                                        mm_state <= MM_WAIT_AS_NEGATE;
                                    end
                                end
                                else if (!n_uds) begin
                                    /* Upper (even) byte R/W - set up for buffering */
                                    n_rom_cs <= 1'b0;
                                    a0 <= 1'b0;
                                    dtack_asserted <= 1'b1;
                                    
                                    n_xdata_ubuf_oe <= 1'b0;
                                
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                            end /* Operational ROM 0x4XXXXX */
                            else if (addr[23:16] == 8'h50 || addr[23:16] == 8'h51 ||
                                     addr[23:16] == 8'h52) begin
                                /* On-board IO, UART and timer all share the same read/write
                                 * characteristics, only the chip select differs */
                                if (!n_uds && !n_lds) begin
                                    /* Word read/writes to on-board IO unsupported */
                                    n_berr <= 1'b0;
                                    
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                                else if (!n_lds) begin
                                    /* Lower (odd) byte R/W - set up for buffering */
                                    if (addr[23:16] == 8'h50) begin
                                        n_io_cs <= 1'b0;
                                    end
                                    else if (addr[23:16] == 8'h51) begin
                                        n_uart_cs <= 1'b0;
                                    end
                                    else begin
                                        n_timer_cs <= 1'b0;
                                    end
                                    
                                    a0 <= 1'b1;
                                    dtack_asserted <= 1'b1;
                                    
                                    if (n_write) begin
                                        /* Reading - can set up to buffer XDATA to the CPU by leaving
                                         * latch enable at logic low, then proceed straight to wait
                                         * for AS to negate. No wait states needed. */
                                        n_xdata_lreg_oe <= 1'b0;
                                        n_xdata_lreg_le <= 1'b0;
                                    end
                                    else begin
                                        /* Writing - set up for buffering the lower byte from CPU to
                                         * XDATA */
                                        n_xdata_lbuf_oe <= 1'b0;
                                    end
                                    
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                                else if (!n_uds) begin
                                    /* Upper (even) byte R/W - set up for buffering */
                                    if (addr[23:16] == 8'h50) begin
                                        n_io_cs <= 1'b0;
                                    end
                                    else if (addr[23:16] == 8'h51) begin
                                        n_uart_cs <= 1'b0;
                                    end
                                    else begin
                                        n_timer_cs <= 1'b0;
                                    end
                                    
                                    a0 <= 1'b0;
                                    dtack_asserted <= 1'b1;
                                    
                                    /* Buffer XDATA to CPU or vice versa, the direction is determined
                                     * externally so the memory machine only has to enable the
                                     * buffer */
                                    n_xdata_ubuf_oe <= 1'b0;
                                
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                            end /* On-board IO, UART, timer 0x5[012]XXXX */
                            else if (addr[23:16] == 8'h53) begin
                                /* Am79C90 Ethernet controller - not on the XDATA bus and as a slave
                                 * it only supports reading/writing of words for configuration and
                                 * status monitoring purposes */
                                if (n_uds || n_lds) begin
                                    /* Word read/writes must be performed */
                                    n_berr <= 1'b0;
                                    
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                                else begin
                                    /* No need to decode upper/lower byte accesses, just assert the
                                     * chipselect and DTACK and then wait for AS to be negated */
                                    n_eth_cs <= 1'b0;
                                    dtack_asserted <= 1'b1;
                                    
                                    mm_state <= MM_WAIT_AS_NEGATE;
                                end
                            end /* Ethernet controller 0x53XXXX */
                            else begin
                                /* All other addresses to be decoded externally, and DTACK/BERR
                                 * asserted as required. The bus watchdog will assert BERR if
                                 * nothing else ends the bus cycle. */
                            end
                        end /* running */
                    end
                    
                MM_ROM_LOWER_LATCH:
                    if (mm_wait_states == 3'd0) begin
                        /* Latch in the lower (odd) byte and then, if the upper (even) byte is also
                         * requested, setup to buffer it through to the CPU then proceed directly to
                         * wait for AS to negate. Otherwise once the lower byte is latched, proceed
                         * to wait for AS to negate. */
                        n_xdata_lreg_le <= 1'b1;
                        
                        if (!n_uds) begin
                            a0 <= 1'b0;
                            n_xdata_ubuf_oe <= 1'b0;
                        end
                        
                        /* In any case, proceed to wait for AS to be negated */
                        mm_state <= MM_WAIT_AS_NEGATE;
                    end
                    else begin
                        mm_wait_states <= mm_wait_states - 3'd1;
                    end
                    
                MM_DRAM_RAS: /* 2 */
                    /* For RMW cycles specifically, wait until at least one of the data strobes are
                     * low before re-asserting CAS signals */
                    if (!n_uds || !n_lds) begin
                        if (mm_wait_states == 3'd0) begin
                            /* Assert CAS signals based on UDS/LDS */
                            if (!n_uds) begin
                                n_mm_ucas <= 1'b0;
                            end
                            
                            if (!n_lds) begin
                                n_mm_lcas <= 1'b0;
                            end
                            
                            /* Swap from row to column address */
                            n_ras_mux <= 1'b1;
                            n_cas_mux <= 1'b0;
                            
                            /* For RMW cycles, (re)assert DTACK */
                            dtack_asserted <= 1'b1;
                            
                            /* Wait for AS to negate to end the bus cycle, or UDS/LDS to negate during a
                             * RMW cycle */
                            mm_state <= MM_DRAM_RMW_OR_TERM;
                        end
                        else begin
                            mm_wait_states <= mm_wait_states - 3'd1;
                        end
                    end
                    
                MM_DRAM_RMW_OR_TERM: /* 3 */
                    if (n_as) begin
                        /* AS negated, terminating the bus cycle */
                        n_mm_ras0 <= 1'b1;
                        n_mm_ras1 <= 1'b1;
                        n_mm_ucas <= 1'b1;
                        n_mm_lcas <= 1'b1;
                        n_cas_mux <= 1'b1;
                        
                        dtack_asserted <= 1'b0;
                        
                        mm_wait_states <= PRECHARGE_WAIT_STATES;
                        
                        mm_state <= MM_DRAM_PRECHARGE;
                    end
                    else if (n_uds && n_lds) begin
                        /* Must negate DTACK to end this portion of the RMW cycle */
                        dtack_asserted <= 1'b0;
                        
                        mm_state <= MM_DRAM_RAS;
                    end
                    
                /* Enforce a delay between DRAM accesses/refreshes to meet Trp timing */
                MM_DRAM_PRECHARGE:
                    if (mm_wait_states == 3'd0) begin
                        accessing_dram <= 1'b0;
                        mm_state <= MM_WAIT_AS;
                    end
                    else begin
                        mm_wait_states <= mm_wait_states - 3'd1;
                    end
                    
                MM_WAIT_AS_NEGATE:
                    if (n_as) begin
                        /* Negate all signals */
                        n_xdata_ubuf_oe <= 1'b1;
                        n_xdata_lbuf_oe <= 1'b1;
                        n_xdata_lreg_oe <= 1'b1;
                        n_xdata_lreg_le <= 1'b1;
                        
                        n_rom_cs <= 1'b1;
                        n_io_cs <= 1'b1;
                        n_uart_cs <= 1'b1;
                        n_timer_cs <= 1'b1;
                        n_eth_cs <= 1'b1;
                        
                        dtack_asserted <= 1'b0;
                        n_berr <= 1'b1;
                        
                        mm_state <= MM_WAIT_AS;
                    end
            endcase
        end
    end
    
    /* Assert DTACK low */
    assign n_dtack = dtack_asserted ? 1'b0 : 1'bZ;
    
    /* Assert RAS and CAS signals based on what the state machines are doing */
    assign n_ras0 = n_mm_ras0 & n_dr_ras;
    assign n_ras1 = n_mm_ras1 & n_dr_ras;
    assign n_ucas = n_mm_ucas & n_dr_cas;
    assign n_lcas = n_mm_lcas & n_dr_cas;
    
    /* Output the state of the running flag */
    //assign mm_running = running;
endmodule

/* bus_wdog - Bus Watchdog
 *
 * Monitors the bus, and whenever AS is asserter it starts a timer which, if it expires before DTACK
 * is asserted, will generate a bus error.
 */
module bus_wdog
#(parameter BITS=7)
(
    input clk,
    input n_reset,
    input n_as,
    input n_dtack,
    output reg n_berr
);
    /* Counter used to implement a timeout - maximum 2^BITS clocks (/4 for CPU clocks) */
    reg [BITS-1:0] timer;
    
    /* State machine */
    localparam [1:0]
        DOG_WAIT_AS_ASSERT = 2'd0,
        DOG_COUNT = 2'd1,
        DOG_WAIT_AS_NEGATE = 2'd2;
    
    reg [1:0] dog_state;
    
    always @(posedge clk) begin
        if (!n_reset) begin
            /* Reset to defaults */
            n_berr <= 1'b1;
            dog_state <= DOG_WAIT_AS_ASSERT;
        end
        else begin
            case (dog_state)
                /* Wait for AS to become asserted to indicate a bus cycle is starting */
                DOG_WAIT_AS_ASSERT:
                    if (!n_as) begin
                        timer <= {BITS{1'b1}};
                        dog_state <= DOG_COUNT;
                    end
                    
                /* Count down the timer, and wait for a terminating condition */
                DOG_COUNT:
                    begin
                        if (!n_dtack) begin
                            /* DTACK asserted, bus cycle will end successfully. Wait for AS to
                             * negate. */
                            dog_state <= DOG_WAIT_AS_NEGATE;
                        end
                        else if (n_as) begin
                            /* AS has been negated before a bus cycle has been terminated? */
                            dog_state <= DOG_WAIT_AS_ASSERT;
                        end
                        else if (timer == {BITS{1'b0}}) begin
                            /* Timer expired, assert BERR */
                            n_berr <= 1'b0;
                            dog_state <= DOG_WAIT_AS_NEGATE;
                        end
                        
                        /* Decrement the timer until it (maybe) reaches zero. Keeping this outside
                         * of the if/else block saves some macrocells. */
                        timer <= timer - 1'b1;
                    end
                    
                /* Wait until AS is negated, then ensure BERR is released */
                DOG_WAIT_AS_NEGATE:
                    if (n_as) begin
                        n_berr <= 1'b1;
                        dog_state <= DOG_WAIT_AS_ASSERT;
                    end
            endcase
        end
    end
endmodule






/* Top module */
module COMETPCH (
    input osc_40mhz,
    input n_reset,
    
    /* Clocks */
    output eth_clk,
    output cpu_clk,
    output timer_clk,
    
    /* CPU signals */
    input [23:16] addr,
    input [2:0] fc,
    input n_as,
    input n_uds,
    input n_lds,
    input n_write,
    input n_bg,
    
    inout n_dtack,
    
    output n_berr,
    output n_vpa,
    output n_br,
    output a0,
    
    /* Interrupt handling */
    input n_irq7,
    input n_irq6,
    input uart_irq,
    input n_irq5,
    input n_eth_irq,
    input n_irq4,
    input n_irq3,
    input n_irq2,
    input n_timer_irq,
    input n_irq1,
    input n_autovec,
    
    output [2:0] ipl,
    output n_iack_out,
    
    /* Bus arbitration */
    input n_eth_br,
    input n_br0,
    input n_br1,
    
    output n_eth_bg,
    output n_bg0,
    output n_bg1,
    
    /* DRAM control */
    output n_ras0,
    output n_ras1,
    output n_ucas,
    output n_lcas,
    output n_ras_mux,
    output n_cas_mux,
    
    /* Address decoding and XDATA control signals */
    output n_rom_cs,
    output n_io_cs,
    output n_uart_cs,
    output n_timer_cs,
    output n_eth_cs,
    output n_xdata_ubuf_oe,
    output n_xdata_lbuf_oe,
    output n_xdata_lreg_oe,
    output n_xdata_lreg_le
);
    /* Clock divider */
    clk_div clock_divider(
        .osc_40mhz(osc_40mhz),
        .eth_clk(eth_clk),
        .cpu_clk(cpu_clk),
        .timer_clk(timer_clk)
    );
    
    /* Interrupt controller */
    wire iack = (addr[19:16] == 4'b1111) & (fc[2:0] == 3'b111);
    
    int_ctl interrupt_controller(
        .clk(osc_40mhz),
        .n_irq7(n_irq7),
        .n_irq6(n_irq6),
        .uart_irq(uart_irq),
        .n_irq5(n_irq5),
        .n_eth_irq(n_eth_irq),
        .n_irq4(n_irq4),
        .n_irq3(n_irq3),
        .n_irq2(n_irq2),
        .n_irq1(n_irq1),
        .n_timer_irq(n_timer_irq),
        .cpu_iack(iack),
        .n_autovec(n_autovec),
        .ipl(ipl),
        .n_vpa(n_vpa),
        .n_iack_out(n_iack_out)
    );
    
    /* Bus arbiter */
    bus_arb bus_arbiter(
        .clk(cpu_clk),
        .n_reset(n_reset),
        .n_as(n_as),
        .n_eth_br(n_eth_br),
        .n_br1(n_br1),
        .n_br0(n_br0),
        .n_bg(n_bg),
        .n_eth_bg(n_eth_bg),
        .n_bg1(n_bg1),
        .n_bg0(n_bg0),
        .n_br(n_br)
    );
    
    /* Memory machine */
    wire n_mm_berr;
    
    mem_mach memory_machine(
        .clk(osc_40mhz),
        .cpu_clk(cpu_clk),
        .n_reset(n_reset),
        .addr(addr),
        .n_as(n_as),
        .n_uds(n_uds),
        .n_lds(n_lds),
        .n_write(n_write),
        .n_dtack(n_dtack),
        .n_berr(n_mm_berr),
        .a0(a0),
        .n_xdata_ubuf_oe(n_xdata_ubuf_oe),
        .n_xdata_lbuf_oe(n_xdata_lbuf_oe),
        .n_xdata_lreg_oe(n_xdata_lreg_oe),
        .n_xdata_lreg_le(n_xdata_lreg_le),
        .n_ras0(n_ras0),
        .n_ras1(n_ras1),
        .n_ucas(n_ucas),
        .n_lcas(n_lcas),
        .n_ras_mux(n_ras_mux),
        .n_cas_mux(n_cas_mux),
        .n_rom_cs(n_rom_cs),
        .n_io_cs(n_io_cs),
        .n_uart_cs(n_uart_cs),
        .n_timer_cs(n_timer_cs),
        .n_eth_cs(n_eth_cs)
    );
    
    /* Bus watchdog */
    wire n_wdog_berr;
    
    bus_wdog bus_watchdog(
        .clk(cpu_clk),
        .n_reset(n_reset),
        .n_as(n_as),
        .n_dtack(n_dtack),
        .n_berr(n_wdog_berr)
    );
    
    assign n_berr = (n_mm_berr & n_wdog_berr) ? 1'bZ : 1'b0;
endmodule

/* END */
