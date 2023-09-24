`timescale 1ns/1ns

/* These defines determine which machines are compiled in to the design */
`define INCLUDE_BUS_WATCHDOG
`define INCLUDE_DRAM_MACHINE
`define INCLUDE_XBUS_MACHINE
`define INCLUDE_INTERRUPT_CONTROLLER
`define INCLUDE_BUS_ARBITER
`define INCLUDE_ETHERNET_MACHINE

/* Uncomment this define to source the CPU clock frequency from an external oscillator, rather than
 * producing the CPU clock ourselves */
//`define CPU_CLOCK_IS_EXTERNAL

/* Top module */
module COMET68k_CPLD(
    /* Clocks */
    input osc_40mhz,
    output logic eth_clk,
`ifndef CPU_CLOCK_IS_EXTERNAL
    output logic cpu_clk,
`else
    input cpu_clk,
`endif
    output logic timer_clk,
    
    /* Global reset */
    input n_reset,
    
    /* Debug signals */
    output logic debug1,
    output logic debug2,
    
    /* Non-specific CPU signals */
    input [23:16] addr,
    input a1,
    input a2,
    input a3,
    input n_as,
    input n_uds,
    input n_lds,
    input n_write,
    input n_dtack,
    input [2:0] fc,
    
    /* Non-specific bus signals */
    output logic n_berr_drv,
    
    /* DRAM machine */
    output logic n_ras0,
    output logic n_ras1,
    output logic n_ucas,
    output logic n_lcas,
    output logic masel,
    
    /* X-bus machine */
    output logic xa0,
    output logic n_xd_lreg_le,
    output logic n_xd_lreg_oe,
    output logic n_xd_ubuf_oe,
    output logic n_xd_lbuf_oe,
    output logic n_rom0_cs,
    output logic n_rom1_cs,
    output logic n_io_cs,
    output logic n_uart_cs,
    output logic n_timer_cs,
    
    /* Expansion bus signals */
    output logic own,
    output logic ddir,
    output logic n_dben,
    output logic n_dtack_drv,
    
    /* Ethernet machine */
    output logic n_eth_cs,
    inout n_eth_das,
    inout n_eth_ready,
    
    /* Interrupt controller signals */
    input nmi,
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
    input n_autovec,
    output logic [2:0] n_ipl,
    output logic n_vpa,
    output logic n_iack_out,
    
    /* Bus arbiter */
    output logic n_br,
    input n_bg,
    input n_eth_br,
    output logic n_eth_bg,
    input n_br0,
    output logic n_bg0,
    input n_br1,
    output logic n_bg1
);
    /* Setup default pin states */
    initial begin
`ifndef INCLUDE_DRAM_MACHINE
        /* DRAM machine */
        n_ras0 = 1'b1;
        n_ras1 = 1'b1;
        n_ucas = 1'b1;
        n_lcas = 1'b1;
        masel = 1'b0;
`endif
        
`ifndef INCLUDE_XBUS_MACHINE
        /* X-bus machine */
        xa0 = 1'b0;
        n_xd_lreg_le = 1'b1;
        n_xd_lreg_oe = 1'b1;
        n_xd_ubuf_oe = 1'b1;
        n_xd_lbuf_oe = 1'b1;
        n_rom0_cs = 1'b1;
        n_rom1_cs = 1'b1;
        n_io_cs = 1'b1;
        n_uart_cs = 1'b1;
        n_timer_cs = 1'b1;
`endif
        
`ifndef INCLUDE_INTERRUPT_CONTROLLER
        /* Interrupt controller */
        n_ipl = 3'b111;
        n_vpa = 1'b1;
        n_iack_out = 1'b1;
`endif

`ifndef INCLUDE_BUS_ARBITER
        /* Bus arbiter */
        n_br = 1'b1;
        n_eth_bg = 1'b1;
        n_bg0 = 1'b1;
        n_bg1 = 1'b1;
`endif
        
`ifndef INCLUDE_ETHERNET_MACHINE
        /* Ethernet machine */
        n_eth_cs = 1'b1;
        n_eth_das = 1'bZ;
        n_eth_ready = 1'bZ;
`endif
        
        /* Expansion bus */
        own = 1'b1;
        ddir = 1'b1;
        n_dben = 1'b1;
    end
    
    /* Clock divider */
    clock_divider clock_divider(
        .osc_40mhz(osc_40mhz),
        .eth_clk(eth_clk),
`ifndef CPU_CLOCK_IS_EXTERNAL
        .cpu_clk(cpu_clk),
`endif
        .timer_clk(timer_clk)
    );
    
    /* Bus watchdog */
`ifdef INCLUDE_BUS_WATCHDOG
    wire n_wd_berr;
    
    bus_watchdog bus_watchdog(
        .cpu_clk(cpu_clk),
        .n_as(n_as),
        .n_eth_bg(n_eth_bg),
        .n_bg0(n_bg0),
        .n_bg1(n_bg1),
        .n_berr(n_wd_berr)
    );
`else
    wire n_wd_berr = 1'b1;
`endif /* INCLUDE_BUS_WATCHDOG */
    
    /* X-bus machine */
`ifdef INCLUDE_XBUS_MACHINE
    wire n_xb_dtack;
    wire boot_ff;
    
    xbus_machine xbus_machine(
        .clk(osc_40mhz),
        .n_reset(n_reset),
        .addr(addr),
        .n_as(n_as),
        .n_uds(n_uds),
        .n_lds(n_lds),
        .n_write(n_write),
        .fc(fc),
        .xa0(xa0),
        .n_xd_lreg_le(n_xd_lreg_le),
        .n_xd_lreg_oe(n_xd_lreg_oe),
        .n_xd_ubuf_oe(n_xd_ubuf_oe),
        .n_xd_lbuf_oe(n_xd_lbuf_oe),
        .n_rom0_cs(n_rom0_cs),
        .n_rom1_cs(n_rom1_cs),
        .n_debug_cs(n_debug_cs),
        .n_io_cs(n_io_cs),
        .n_uart_cs(n_uart_cs),
        .n_timer_cs(n_timer_cs),
        .n_dtack(n_xb_dtack),
        .boot_ff(boot_ff)
    );
`else
    wire n_xb_dtack = 1'b1;
    wire boot_ff = 1'b0;
`endif
    
    /* DRAM machine */
`ifdef INCLUDE_DRAM_MACHINE
    wire n_dram_dtack;
    
    dram_machine dram_machine(
        .clk(osc_40mhz),
        .boot_ff(boot_ff),
        .addr(addr),
        .n_as(n_as),
        .n_uds(n_uds),
        .n_lds(n_lds),
        .fc(fc),
        .n_eth_bg(n_eth_bg),
        .n_ras0(n_ras0),
        .n_ras1(n_ras1),
        .n_ucas(n_ucas),
        .n_lcas(n_lcas),
        .masel(masel),
        .n_dtack(n_dram_dtack)
    );
`else
    wire n_dram_dtack = 1'b1;
`endif
    
    /* Interrupt controller */
`ifdef INCLUDE_INTERRUPT_CONTROLLER
    interrupt_controller interrupt_controller(
        .clk(osc_40mhz),
        .n_reset(n_reset),
        .boot_ff(boot_ff),
        .addr(addr),
        .a3(a3),
        .a2(a2),
        .a1(a1),
        .n_as(n_as),
        .fc(fc),
        .nmi(nmi),
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
        .n_autovec(n_autovec),
        .n_ipl(n_ipl),
        .n_vpa(n_vpa),
        .n_iack_out(n_iack_out)
    );
`endif /* INCLUDE_INTERRUPT_CONTROLLER */

    /* Bus arbiter */
`ifdef INCLUDE_BUS_ARBITER
    bus_arbiter bus_arbiter(
        .clk(osc_40mhz),
        .n_reset(n_reset),
        .n_as(n_as),
        .n_br(n_br),
        .n_bg(n_bg),
        .n_eth_br(n_eth_br),
        .n_eth_bg(n_eth_bg),
        .n_br0(n_br0),
        .n_bg0(n_bg0),
        .n_br1(n_br1),
        .n_bg1(n_bg1)
    );
`endif /* INCLUDE_BUS_ARBITER */

    /* Ethernet machine */
`ifdef INCLUDE_ETHERNET_MACHINE
    wire n_eth_dtack;
    
    ethernet_machine ethernet_machine(
        .clk(osc_40mhz),
        .n_reset(n_reset),
        .addr(addr),
        .n_as(n_as),
        .n_uds(n_uds),
        .n_lds(n_lds),
        .n_eth_bg(n_eth_bg),
        .n_dtack_in(n_dtack),
        .n_eth_das(n_eth_das),
        .n_eth_ready(n_eth_ready),
        .n_eth_cs(n_eth_cs),
        .n_dtack(n_eth_dtack)
    );
`else
    wire n_eth_dtack = 1'b1;
`endif /* INCLUDE_ETHERNET_MACHINE */
    
    wire onboard_decodes = n_rom0_cs && n_rom1_cs && n_io_cs && n_uart_cs && n_timer_cs && n_eth_cs;
    wire onboard_others = n_eth_bg && n_ras0 && n_ras1;
    wire onboard_accesses = (onboard_decodes || onboard_others);
    
    always_comb begin
        /* Composite signals */
        n_dtack_drv = (n_xb_dtack && n_dram_dtack && n_eth_dtack);
        n_berr_drv = n_wd_berr;
    
        /* Expansion bus control signals
         *
         * own indicates whether an on-board device is currently the bus master. This is determined
         * simply by both external bus grants being negated. When the bus is mastered by an on-board
         * device, control signals are propagated outwards to the expansion bus. When the bus is
         * mastered by an external device, control signals are propagated inwards from the expansion
         * bus.
         *
         * ddir determines in which direction the data bus buffers will be configured for reads and
         * writes. The direction is dependent on whether the bus is mastered by an on-board or
         * external device. Using the nomenclature of the expansion bus buffers, A side pins are
         * facing the on-board direction, and B side pins are facing the external direction.
         *
         * Master     Operation   Direction
         * ------     ---------   ---------
         * On-board   Read        B->A
         * On-board   Write       A->B
         * External   Read        A->B
         * External   Write       B->A
         *
         * n_dben enables the data bus buffers for read and write operations according to the
         * following table.
         *
         * Master     Accessing   dben
         * ------     ---------   ----
         * On-board   On-board    Disable
         * On-board   External    Enable
         * External   External    Disable
         * External   On-board    Enable
         *
         */
        own = n_bg0 && n_bg1;
        ddir = own ^ n_write;
//        n_dben = !own || (own && !n_as && onboard_decodes && onboard_others) // needs work
        
        /* Debug signals */
        debug1 = 1'b0;
        debug2 = 1'b0;
    end
endmodule


/* Clock Divider
 *
 * Divides the incomming 40MHz oscillator into several sub clocks:
 *
 * 1:2 division produces 20MHz for the ethernet controller
 * 1:4 division produces 10MHz for the CPU
 * 1:64 division produces 625KHz for the timers
 *
 * No reset is implemented, all of the sub clocks are produced continuously.
 */
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
    /* A n bit counter to act as the divider */
    reg [BITS-1:0] divider;
    
    /* Start the counter at 0 */
    initial begin
        divider = 0;
    end
    
    /* For every incoming clock edge, increment the counter */
    always_ff @(negedge osc_40mhz) begin
      divider <= divider + 1'b1;
    end

    /* Assign clock outputs */
    always_comb begin
        eth_clk = divider[ETH_CLK_TAP];
        cpu_clk = divider[CPU_CLK_TAP];
        timer_clk = divider[TIMER_CLK_TAP];
    end
endmodule /* clock_divider */

`ifdef INCLUDE_BUS_WATCHDOG
/* Bus Watchdog
 *
 * The bus watchdog monitors the AS/ signal, and when ever it is asserted, a countdown timer is
 * started. If that timer reaches zero while AS/ is still asserted, the watchdog will assert BERR/
 * to end the current bus cycle.
 *
 * The following bus cycle types are covered by this watchdog:
 *
 * Cycle type               Termination method                      Timeout side effect
 * ----------------------   -------------------------------------   --------------------------------
 * Memory or peripheral     DTACK/ asserted                         Bus error exception
 * Vectored interrupt       DTACK/ asserted by interruptor          Spurious interrupt exception
 * Autovectored interrupt   VPA/ asserted by interrupt controller   Spurious interrupt exception
 *                          (internally asserted, or externally
 *                           through n_autovec signal)
 */
module bus_watchdog
#(parameter BITS=5)
(
    input cpu_clk,
    input n_as,
    input n_eth_bg,
    input n_bg0,
    input n_bg1,
    output logic n_berr
);
    /* A n bit counter to determine the timeout period */
    reg [BITS-1:0] timeout;
    
    /* Start timer at maximal value */
    initial begin
        timeout = -'d1;
    end
    
    wire cpu_is_master = (n_eth_bg && n_bg0 && n_bg1);
    
    always_ff @(posedge cpu_clk) begin
        if (n_as) begin
            /* The watchdog is effectively in reset whenever AS/ is negated */
            timeout <= -'d1;
        end
        else begin
            if (timeout != 'd0) begin
                /* Decrement timer whenever AS/ is asserted */
                timeout <= timeout + -'d1;
            end
        end
    end
    
    /* Assert BERR/ whenever the timer reaches zero */
    always_comb begin
        n_berr = !((timeout == 'd0) && cpu_is_master);
    end
endmodule /* bus_watchdog */
`endif /* INCLUDE_BUS_WATCHDOG */

`ifdef INCLUDE_XBUS_MACHINE
/* X-bus Machine
 *
 * The X-bus is an 8-bit bus within the computer that connects all of the smaller peripherals to
 * the rest of the system. It also houses the ROMs.
 *
 * To permit all 8-bit devices to be readable and writeable at byte addresses, the X-bus machine
 * implements the required handling of buffers and latches between the X-bus and the CPU bus along
 * with a synthesised A0 address signal derived from the UDS.
 *
 * Through the latches and buffers it enables words to be read from a single ROM.
 *
 * ROM remapping is performed. After a system reset, ROM is accessible from address 0 until the
 * CPU has read the initial SP and PC values. Once the CPU makes an access to the 0xFXXXXX address
 * space, the ROMs are remapped to that address space and DRAM becomes available from address 0
 * after boot_ff is set.
 *
 * The following address map is implemented in this machine:
 *
 * 0xCXXXXX     On-board peripherals
 *    0XXXX         Debug display - always decoded and assumed to exist
 *    1XXXX         On-board IO (LEDs, configuration jumpers, etc)
 *    2XXXX         TL16C2552 dual UART
 *    3XXXX         DP8570A timer/RTC
 * 0xFXXXXX     ROMs
 *
 * Note: Ethernet chip select is decoded and handled through the ethernet machine. */
module xbus_machine
#(parameter ROM_WAIT_STATES=3)
(
    input clk,
    input n_reset,
    input [23:16] addr,
    input n_as,
    input n_uds,
    input n_lds,
    input n_write,
    input [2:0] fc,
    output logic xa0,
    output logic n_xd_lreg_le,
    output logic n_xd_lreg_oe,
    output logic n_xd_ubuf_oe,
    output logic n_xd_lbuf_oe,
    output logic n_rom0_cs,
    output logic n_rom1_cs,
    output logic n_debug_cs,
    output logic n_io_cs,
    output logic n_uart_cs,
    output logic n_timer_cs,
    output logic n_dtack,
    output logic boot_ff
);
    /* X-bus state machine states */
    reg [2:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_ROM_LATCH_LOWER = 'd1,
        M_PERIPH_CS_DELAY = 'd2,
        M_WAIT_AS_NEGATE = 'd3,
        M_RESET_BUS = 'd4;
    
    /* Counter used throughout the machine to time various delays */
    reg [1:0] delay;
    
    /* Register defaults */
    initial begin
        m_state = M_IDLE;
        delay = 'd0;
        xa0 = 1'b1;
        n_xd_lreg_le = 1'b1;
        n_xd_lreg_oe = 1'b1;
        n_xd_ubuf_oe = 1'b1;
        n_xd_lbuf_oe = 1'b1;
        boot_ff = 1'b0;
    end
    
    wire mem_cycle = (!n_as && (!n_uds || !n_lds) && (fc[2:0] != 3'b111));
    wire rom_decoded_reset = (mem_cycle && !boot_ff && (addr[23:20] == 4'h0));
    wire rom_decoded_booted = (mem_cycle && boot_ff && (addr[23:20] == 4'hF));
    wire rom_decoded = (rom_decoded_reset || rom_decoded_booted);
    wire debug_decoded = (mem_cycle && (addr[23:16] == 8'hC0));
    wire io_decoded = (mem_cycle && (addr[23:16] == 8'hC1));
    wire uart_decoded = (mem_cycle && (addr[23:16] == 8'hC2));
    wire timer_decoded = (mem_cycle && (addr[23:16] == 8'hC3));
    wire periph_decoded = (io_decoded || uart_decoded || timer_decoded);
    
    /* Assert chip selects and DTACK */
    always_comb begin
        n_rom0_cs = !(rom_decoded_booted && !addr[19]);
        n_rom1_cs = !((rom_decoded_booted && addr[19]) || rom_decoded_reset);
        n_debug_cs = !(debug_decoded && (m_state == M_WAIT_AS_NEGATE));
        n_io_cs = !(io_decoded && (m_state == M_WAIT_AS_NEGATE));
        n_uart_cs = !(uart_decoded && (m_state == M_WAIT_AS_NEGATE));
        n_timer_cs = !(timer_decoded && (m_state == M_WAIT_AS_NEGATE));
        
        /* Assert DTACK once we start waiting for AS to negate */
        n_dtack = !(!(n_rom0_cs && n_rom1_cs && n_debug_cs && n_io_cs && n_uart_cs && n_timer_cs) &&
                    (m_state == M_WAIT_AS_NEGATE));
    end
    
    always_ff @(negedge clk) begin
        if (!n_reset) begin
            /* Clear boot_ff any time the CPU is reset */
            boot_ff <= 1'b0;
        end
        
        case (m_state)
            M_IDLE:
                begin
                    if (mem_cycle && !boot_ff && (addr[23:19] == 5'h1F)) begin
                        /* Set boot_ff on the first access to the address space of ROM1. This means
                         * that boot code must be stored in ROM1, which takes the upper most 512KB
                         * of the CPU address space.
                         *
                         * The first access to this space indicates that the CPU has begun executing
                         * code, and RAM can thus be enabled and become accessible from address 0.
                         */
                        boot_ff <= 1'b1;
                    end
                    
                    if (rom_decoded) begin
                        /* Setup for latching lower byte - whether or not a byte or word is being
                         * accessed, always load a word out of the ROM. The CPU will pick which bits
                         * it needs. */
                        xa0 <= 1'b1;
                        n_xd_lreg_le <= 1'b0;
                        n_xd_lreg_oe <= 1'b0;
                        
                        /* ROM access delay before latching */
                        delay <= ROM_WAIT_STATES;
                        m_state <= M_ROM_LATCH_LOWER;
                    end
                    else if (periph_decoded) begin
                        /* Setup XA0 based on UDS */
                        xa0 <= n_uds;
                        
                        if (n_write) begin
                            /* Reading IO - output to both the upper and lower halves of the data
                             * bus from the X-bus - the CPU will take what it needs */
                            n_xd_lreg_le <= 1'b0;
                            n_xd_lreg_oe <= 1'b0;
                            n_xd_ubuf_oe <= 1'b0;
                        end
                        else begin
                            /* Writing IO - based on xDS, enable only a single buffer towards
                             * the X-bus */
                            if (!n_uds) begin
                                n_xd_ubuf_oe <= 1'b0;
                            end
                            else begin
                                n_xd_lbuf_oe <= 1'b0;
                            end
                        end
                        
                        /* Some X-bus peripherals, particularly the TL16C2552, seem to be sensitive
                         * to XA0 setup times. Therefore, peripheral chip selects are gated by the
                         * X-bus machine being in the M_WAIT_AS_NEGATE state. Make a short detour
                         * through M_PERIPH_CS_DELAY to allow some setup time for XA0. */
                        m_state <= M_PERIPH_CS_DELAY;
                    end
                end
            
            M_ROM_LATCH_LOWER:
                if (delay == 'd0) begin
                    /* Latch lower byte now */
                    n_xd_lreg_le <= 1'b1;
                    
                    /* Setup for buffering upper byte */
                    xa0 <= 1'b0;
                    n_xd_ubuf_oe <= 1'b0;
                    
                    /* Now we just wait for AS to negate */
                    m_state <= M_WAIT_AS_NEGATE;
                end
                else begin
                    delay <= delay + -'d1;
                end
            
            M_PERIPH_CS_DELAY:
                begin
                    /* Move straight to the next state */
                    m_state <= M_WAIT_AS_NEGATE;
                end
            
            M_WAIT_AS_NEGATE:
                if (n_as) begin
                    m_state <= M_RESET_BUS;
                end
            
            M_RESET_BUS:
                begin
                    /* Set defaults */
                    xa0 <= 1'b1;
                    n_xd_lreg_le <= 1'b1;
                    n_xd_lreg_oe <= 1'b1;
                    n_xd_ubuf_oe <= 1'b1;
                    n_xd_lbuf_oe <= 1'b1;
                    
                    m_state <= M_IDLE;
                end
        endcase
    end
endmodule /* xbus_machine */
`endif /* INCLUDE_XBUS_MACHINE */

`ifdef INCLUDE_DRAM_MACHINE
/* DRAM Machine
 *
 * Implements a state machine that refreshes the DRAM modules, as well as sequencing reads and
 * writes.
 *
 * The DRAM machine decodes address 0-0x3FFFFF as long as boot_ff, which indicates that the CPU
 * has begun executing code after fetching the ISP and IPC values, is set. Otherwise it lays
 * dormant and does not perform any function other than refresh. */
module dram_machine
#(parameter REFRESH_CLOCKS=625,
            REFRESH_WAIT_STATES=3,
            ACCESS_RAS_WAIT_STATES=1,
            ACCESS_CAS_WAIT_STATES=2,
            PRECHARGE_WAIT_STATES=2)
(
    input clk,
    input boot_ff,
    input [23:16] addr,
    input n_as,
    input n_uds,
    input n_lds,
    input [2:0] fc,
    input n_eth_bg,
    output logic n_ras0,
    output logic n_ras1,
    output logic n_ucas,
    output logic n_lcas,
    output logic masel,
    output logic n_dtack
);
    /* DRAM state machine states */
    reg [2:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_REFRESH_RAS = 'd1,
        M_ACCESS_WAIT_XDS = 'd2,
        M_ACCESS_CAS = 'd3,
        M_PRECHARGE = 'd7;
    
    /* DRAM refresh timer */
    reg [9:0] dram_refresh_timer;
    reg refresh_due;
    
    /* Counter used throughout the machine to time various delays */
    reg [1:0] delay;
    
    /* por_delay inhibits refreshes until boot_ff is set. This satisfies the initial 200uS
     * power-on-delay required by the DRAM modules prior to refresh cycles beginning. */
    reg por_delay;
    
    /* Register defaults */
    initial begin
        n_ras0 = 1'b1;
        n_ras1 = 1'b1;
        n_ucas = 1'b1;
        n_lcas = 1'b1;
        masel = 1'b0;
        m_state = M_IDLE;
        dram_refresh_timer = REFRESH_CLOCKS;
        refresh_due = 1'b0;
        delay = 'd0;
        por_delay = 1'b0;
    end
    
    /* DRAM access is allowed whenever the Ethernet controller is the bus master, or when it isnt
     * and the function code is not 7 */
    wire permitted_access = (n_eth_bg && (fc != 3'b111) || !n_eth_bg);
    
    always_comb begin
        /* Assert DTACK/ when ever the machine is in the CAS portion of a cycle */
        n_dtack = !(m_state == M_ACCESS_CAS && delay == 'd0);
    end
    
    always_ff @(negedge clk) begin
        /* The DRAM modules used in COMET require a minimum of 200uS delay prior to starting refresh
         * cycles, after which 8 refresh cycles are then required to achieve proper operation. Use
         * boot_ff going high for the very first time as an initial power on delay. Software should
         * then implement a delay loop to satisfy the initial 8 refresh cycles prior to making reads
         * or writes. por_delay should not be reset thereafter to allow refreshes to continue, and
         * thus maintain DRAM contents between CPU resets. */
        if (!por_delay && boot_ff) begin
            por_delay <= 1'b1;
        end
        
        /* Decrement the refresh timer. Set refresh_due flag once the timer reaches 0. */
        if (dram_refresh_timer == 'd0) begin
            refresh_due <= 1'b1;
            dram_refresh_timer <= REFRESH_CLOCKS;
        end
        else begin
            if (por_delay) begin
                dram_refresh_timer <= dram_refresh_timer + -'d1;
            end
        end
        
        case (m_state)
            /* In the idle state, the machine is waiting for either a memory access cycle from an
             * external device, or the refresh_due flag to be set to perform a refresh cycle. */
            M_IDLE:
                if (refresh_due) begin
                    /* Refresh cycle to be performed */
                    refresh_due <= 1'b0;
                    
                    /* Assert CAS to both DRAM modules */
                    n_ucas <= 1'b0;
                    n_lcas <= 1'b0;
                    
                    /* Move to assert RAS for refresh */
                    delay <= REFRESH_WAIT_STATES;
                    m_state <= M_REFRESH_RAS;
                end
                else if (boot_ff && !n_as && (addr[23:22] == 2'b00) && permitted_access) begin
                    /* Memory access cycle - assert RAS according to DRAM bank */
                    if (addr[21] == 1'b0) begin
                        /* DRAM module 0 if A21 is low */
                        n_ras1 <= 1'b0;
                    end
                    else begin
                        /* DRAM module 1 if A21 is high */
                        n_ras0 <= 1'b0;
                    end
                    
                    /* Move to wait for xDS strobes */
                    delay <= ACCESS_RAS_WAIT_STATES;
                    m_state <= M_ACCESS_WAIT_XDS;
                end
            
            /* DRAM refresh: assert RAS towards DRAM modules, and delay */
            M_REFRESH_RAS:
                if (delay == 'd0) begin
                    /* Refresh cycle is ending now. Deassert all signals. */
                    n_ras0 <= 1'b1;
                    n_ras1 <= 1'b1;
                    n_ucas <= 1'b1;
                    n_lcas <= 1'b1;
                    
                    /* Move to precharge */
                    delay <= PRECHARGE_WAIT_STATES;
                    m_state <= M_PRECHARGE;
                end
                else begin
                    /* Assert RAS to both DRAM modules while delaying */
                    n_ras0 <= 1'b0;
                    n_ras1 <= 1'b0;
                    
                    delay <= delay + -'d1;
                end
            
            /* Wait for xDS to be asserted before moving to CAS access delay */
            M_ACCESS_WAIT_XDS:
                if (delay == 'd0) begin
                    if (!n_uds || !n_lds) begin
                        /* Change to presenting column address */
                        masel <= 1'b1;
                        
                        /* Move to CAS access delay - add one wait state to account for the fact that
                         * CAS's will be asserted in the next state */
                        delay <= ACCESS_CAS_WAIT_STATES + 'd1;
                        m_state <= M_ACCESS_CAS;
                    end
                end
                else begin
                    delay <= delay + -'d1;
                end
            
            /* CAS portion of memory access cycle */
            M_ACCESS_CAS:
                begin
                    /* Strobe CAS based on CPU data strobes - to guarantee setup times, CAS's are
                     * asserted here instead of ahead of time */
                    n_ucas <= n_uds;
                    n_lcas <= n_lds;
                    
                    if (delay == 'd0) begin
                        /* Wait for AS to go idle before negating signals */
                        if (n_as) begin
                            masel <= 1'b0;
                            n_ras0 <= 1'b1;
                            n_ras1 <= 1'b1;
                            n_ucas <= 1'b1;
                            n_lcas <= 1'b1;
                            
                            /* Move to precharge */
                            delay <= PRECHARGE_WAIT_STATES;
                            m_state <= M_PRECHARGE;
                        end
                        else if (!n_as && n_uds && n_lds) begin
                            /* Looks like we're in a RMW cycle. Proceed back to wait for xDS to be
                             * strobed again. */
                            m_state <= M_ACCESS_WAIT_XDS;
                        end
                    end
                    else begin
                        delay <= delay + -'d1;
                    end
                end
            
            /* Precharge delay in between cycles */
            M_PRECHARGE:
                if (delay == 'd0) begin
                    /* After precharge, move back to IDLE state to handle next cycle */
                    m_state <= M_IDLE;
                end
                else begin
                    delay <= delay + -'d1;
                end
        endcase
    end
endmodule /* dram_machine */
`endif /* INCLUDE_DRAM_MACHINE */

`ifdef INCLUDE_INTERRUPT_CONTROLLER
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
 *  Lowest: On-board timer/RTC at IRQ 1
 *
 * The NMI button must be externally debounced.
 */
module interrupt_controller(
    input clk,
    input n_reset,
    input boot_ff,
    input [23:16] addr,
    input a3,
    input a2,
    input a1,
    input n_as,
    input [2:0] fc,
    input nmi,
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
    input n_autovec,
    output logic [2:0] n_ipl,
    output logic n_vpa,
    output logic n_iack_out
);
    /* Interrupt controller state machine */
    reg [1:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_ACKNOWLEDGED = 'd1,
        M_EXTERNAL = 'd2;
        
    /* A register that determines if the NMI input has been acknowledged as asserted, and causes it
     * to be masked until it is negated */
    reg nmi_acked;
    
    /* Register defaults */
    initial begin
        m_state = M_IDLE;
        nmi_acked = 1'b1;
        n_vpa = 1'b1;
        n_iack_out = 1'b1;
    end
    
    wire iack = (!n_as && (addr[19:16] == 4'b1111) && (fc[2:0] == 3'b111));
    wire level7 = ( a3 &&  a2 &&  a1);
    wire level6 = ( a3 &&  a2 && !a1);
    wire level5 = ( a3 && !a2 &&  a1);
    wire level4 = ( a3 && !a2 && !a1);
    wire level3 = (!a3 &&  a2 &&  a1);
    wire level2 = (!a3 &&  a2 && !a1);
    wire level1 = (!a3 && !a2 &&  a1);
    wire nmi_ack = (nmi && !nmi_acked && level7);
    wire uart_ack = (uart_irq && level5);
    wire eth_ack = (!n_eth_irq && level4);
    wire timer_ack = (!n_timer_irq && n_irq1 && level1);
    wire ext_irq7 = (!nmi && level7);
    wire ext_irq5 = (!uart_irq && level5);
    wire ext_irq4 = (n_eth_irq && level4);
    wire onboard_irq = (nmi_ack || uart_ack || eth_ack || timer_ack);
    wire external_irq = (ext_irq7 || level6 || ext_irq5 || ext_irq4 || level3 || level2 || level1);
    
    /* Priority encoder for IPLx */
    always_comb begin
        /* Default to no pending interrupt */
        n_ipl = ~3'd0;
        
        if (boot_ff) begin
            /* Interrupts other than NMI are only pended to the CPU once it has fetched the reset
             * vector and begun executing code from its run-time address map */
            if (!n_irq1 || !n_timer_irq) begin
                /* IPL 1: external IRQ 1 or on-board timer/RTC */
                n_ipl = ~3'd1;
            end
            
            if (!n_irq2) begin
                /* IPL 2: external IRQ 2 */
                n_ipl = ~3'd2;
            end
            
            if (!n_irq3) begin
                /* IPL 3: external IRQ 3 */
                n_ipl = ~3'd3;
            end
            
            if (!n_eth_irq || !n_irq4) begin
                /* IPL 4: on-board Ethernet controller or external IRQ 4 */
                n_ipl = ~3'd4;
            end
            
            if (uart_irq || !n_irq5) begin
                /* IPL 5: on-board UART or external IRQ 5 */
                n_ipl = ~3'd5;
            end
            
            if (!n_irq6) begin
                /* IPL 6: external IRQ 6 */
                n_ipl = ~3'd6;
            end
        end
        
        if ((nmi && !nmi_acked) || !n_irq7) begin
            /* IPL 7: on-board NMI button or external IRQ 7 */
            n_ipl = ~3'd7;
        end
    end
    
    always_ff @(negedge clk) begin
        if (!n_reset) begin
            /* Resetting */
            m_state <= M_IDLE;
            nmi_acked <= 1'b1;
            n_vpa <= 1'b1;
            n_iack_out <= 1'b1;
        end
        else begin
            /* If NMI is ack'd and the NMI signal becomes negated, clear the nmi_ack flag */
            if (nmi_acked && !nmi) begin
                nmi_acked <= 1'b0;
            end
            
            case (m_state)
                M_IDLE:
                    begin
                        if (iack) begin
                            if (onboard_irq) begin
                                /* Autovector all on-board interrupt sources */
                                n_vpa <= 1'b0;
                                
                                /* If NMI is asserted, set the nmi_ack flag to mask NMI until it is
                                 * negated */
                                if (nmi_ack) begin
                                    nmi_acked <= 1'b1;
                                end
                                
                                m_state <= M_ACKNOWLEDGED;
                            end
                            else begin
                                /* Assert IACK out to allow an external interruptor to either
                                 * generate a vectored or autovectored interrupt */
                                n_iack_out <= 1'b0;
                                
                                m_state <= M_EXTERNAL;
                            end
                        end
                    end
                
                /* Wait for the IACK cycle to end */
                M_ACKNOWLEDGED:
                    if (n_as) begin
                        n_vpa <= 1'b1;
                        
                        m_state <= M_IDLE;
                    end
                
                /* Wait for the IACK cycle to end. During this state, relay the n_autovec signal to
                 * VPA to allow external interruptors to autovector if required. Alternatively they
                 * may vector an interrupt. */
                M_EXTERNAL:
                    if (n_as) begin
                        n_vpa <= 1'b1;
                        n_iack_out <= 1'b1;
                        
                        m_state <= M_IDLE;
                    end
                    else begin
                        n_vpa <= n_autovec;
                    end
            endcase
        end
    end
endmodule /* interrupt_controller */
`endif /* INCLUDE_INTERRUPT_CONTROLLER */


`ifdef INCLUDE_BUS_ARBITER
/* Bus Arbiter
 *
 * Manages access to the system busses, prioritising requests between the following sources:
 *
 * Highest: On-board Ethernet controller
 *          External request level 0
 *  Lowest: External request level 1
 */
module bus_arbiter(
    input clk,
    input n_reset,
    input n_as,
    output logic n_br,
    input n_bg,
    input n_eth_br,
    output logic n_eth_bg,
    input n_br0,
    output logic n_bg0,
    input n_br1,
    output logic n_bg1
);
    /* Bus arbiter state machine */
    reg [1:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_WAIT_CPU_ASSERT_GRANT = 'd1,
        M_WAIT_REQUEST_COMPLETE = 'd2,
        M_WAIT_CPU_NEGATE_GRANT = 'd3;
    
    /* Register defaults */
    initial begin
        m_state = M_IDLE;
        n_br = 1'b1;
        n_eth_bg = 1'b1;
        n_bg0 = 1'b1;
        n_bg1 = 1'b1;
    end
    
    always_ff @(negedge clk) begin
        if (!n_reset) begin
            /* Resetting */
            m_state <= M_IDLE;
            n_br <= 1'b1;
            n_eth_bg <= 1'b1;
            n_bg0 <= 1'b1;
            n_bg1 <= 1'b1;
        end
        else begin
            case (m_state)
                /* The idle state waits for a request to be received from either the on-board
                 * Ethernet controller, or one of the two external request signals */
                M_IDLE:
                    if (!n_eth_br || !n_br0 || !n_br1) begin
                        /* Request bus from CPU */
                        n_br <= 1'b0;
                        
                        /* Wait for CPU to grant the bus */
                        m_state <= M_WAIT_CPU_ASSERT_GRANT;
                    end
                
                /* Wait for the CPU to grant access to the bus and complete current cycle */
                M_WAIT_CPU_ASSERT_GRANT:
                    if (!n_bg && n_as) begin
                        /* Assert appropriate bus grant */
                        n_eth_bg <= n_eth_br;
                        n_bg0 <= !(n_eth_br && !n_br0);
                        n_bg1 <= !(n_eth_br && n_br0 && !n_br1);
                        
                        /* Wait for requestor to finish its request */
                        m_state <= M_WAIT_REQUEST_COMPLETE;
                    end
                
                /* Wait for the requesting device to hand the bus back */
                M_WAIT_REQUEST_COMPLETE:
                    if ((!n_eth_bg && n_eth_br) || (!n_bg0 && n_br0) || (!n_bg1 && n_br1)) begin
                        /* Withdraw grant to requesting device and then wait for the CPU to regain
                         * control of the bus before granting any further requests */
                        n_br <= 1'b1;
                        
                        n_eth_bg <= 1'b1;
                        n_bg0 <= 1'b1;
                        n_bg1 <= 1'b1;
                        
                        m_state <= M_WAIT_CPU_NEGATE_GRANT;
                    end
                
                /* Wait for the CPU to regain the bus */
                M_WAIT_CPU_NEGATE_GRANT:
                    if (n_bg) begin
                        m_state <= M_IDLE;
                    end
            endcase
        end
    end
endmodule /* bus_arbiter */
`endif /* INCLUDE_BUS_ARBITER */

`ifdef INCLUDE_ETHERNET_MACHINE
/* Ethernet Machine
 *
 * The Ethernet machine is responsible for decoding accesses to the Ethernet controller, as well as
 * sequencing accesses to and from it through the use of the DAS and READY signals.
 *
 * The Ethernet controller is decoded in the address space 0xC4XXXX.
 */
module ethernet_machine(
    input clk,
    input n_reset,
    input [23:16] addr,
    input n_as,
    input n_uds,
    input n_lds,
    input n_eth_bg,
    input n_dtack_in,
    inout n_eth_das,
    inout n_eth_ready,
    output logic n_eth_cs,
    output logic n_dtack
);
    /* Ethernet machine state machine */
    reg [1:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_SLAVE_CYCLE = 'd1,
        M_MASTER_CYCLE = 'd2;
    
    /* Register defaults */
    initial begin
        m_state = M_IDLE;
    end
    
    /* Access to the Ethernet controller is by word only */
    wire eth_decoded = (n_eth_bg && !n_as && !n_uds && !n_lds && (addr[23:16] == 8'hC4));
    
    always_comb begin
        /* Chipselect */
        n_eth_cs = !eth_decoded;
        
        /* DTACK/ is only driven during a slave cycle, and is essentially just a relayed copy of
         * the Ethernet controllers READY/ signal */
        n_dtack = !((m_state == M_SLAVE_CYCLE) && !n_eth_ready);
        
        /* Assert DAS to the Ethernet controller when we are in a slave cycle */
        n_eth_das = (m_state == M_SLAVE_CYCLE) ? 1'b0 : 1'bZ;
        
        /* Assert READY towards the Ethernet controller during master cycles when DTACK has been
         * asserted by some other device in the system */
        n_eth_ready = ((m_state == M_MASTER_CYCLE) && !n_dtack_in) ? 1'b0 : 1'bZ;
    end
    
    always_ff @(negedge clk) begin
        if (!n_reset) begin
            /* Resetting */
            m_state <= M_IDLE;
        end
        else begin
            case (m_state)
                M_IDLE:
                    if (eth_decoded) begin
                        m_state <= M_SLAVE_CYCLE;
                    end
                    else if (!n_eth_bg && !n_eth_das) begin
                        m_state <= M_MASTER_CYCLE;
                    end
                
                /* In this state we are waiting for the Ethernet controller to assert its READY/
                 * signal, which indicates that it has accepted data during a write or presented
                 * data during a read. This is then relayed to the CPU as DTACK/, and we then wait
                 * for AS/ to go high to indicate the bus cycle is complete. */
                M_SLAVE_CYCLE:
                    if (n_as) begin
                        m_state <= M_IDLE;
                    end
                
                /* When the Ethernet controller is a master, we only need relay the state of DTACK/
                 * to it so that it knows when it can end its own bus cycles. This is done by
                 * mirroring our DTACK/ input to the n_eth_ready signal once it is asserted, and
                 * until AS/ is negated. */
                M_MASTER_CYCLE:
                    if (n_as) begin
                        m_state <= M_IDLE;
                    end
            endcase
        end
    end
endmodule /* ethernet_machine */
`endif /* INCLUDE_ETHERNET_MACHINE */

/* END */
