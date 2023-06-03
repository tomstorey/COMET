`timescale 1ns/1ns

/* Top module */
module COMET68k_CPLD(
    /* Primary oscillator from which all (most) other clocks are derived */
    input osc_40mhz,
    
    /* Global reset */
    input n_reset,
    
    /* Debug signals */
    output debug1,
    
    /* CPU signals */
    output cpu_clk,
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
    output reg n_br,
    input n_bg,
    output reg [2:0] n_ipl,
    output reg n_vpa,
    
    /* DRAM control */
    output reg n_ras0,
    output reg n_ras1,
    output reg n_ucas,
    output reg n_lcas,
    output reg masel,
    
    /* ROM control */
    output n_rom0_cs,
    output n_rom1_cs,
    
    /* X-bus control */
    output xa0,
    output n_xd_lreg_le,
    output n_xd_lreg_oe,
    output n_xd_ubuf_oe,
    output n_xd_lbuf_oe,
    
    /* Expansion bus signals */
    output reg own,
    output reg ddir,
    output reg n_dben,
    output n_berr_drv,
    output n_dtack_drv,
    input n_br0,
    output reg n_bg0,
    input n_br1,
    output reg n_bg1,
    
    /* UART signals */
    output n_uart_cs,
    input uart_irq,
    
    /* Timer signals */
    output n_timer_cs,
    output timer_clk,
    input n_timer_irq,
    
    /* On-board IO signals */
    /* input func1, */
    output n_io_cs,
    
    /* Ethernet signals */
    output reg n_eth_cs,
    output reg n_eth_das,
    output eth_clk,
    inout n_eth_ready,
    input n_eth_br,
    output reg n_eth_bg,
    input n_eth_irq,
    
    /* Interrupt controller signals */
    input n_nmi,
    input n_irq7,
    input n_irq6,
    input n_irq5,
    input n_irq4,
    input n_irq3,
    input n_irq2,
    input n_irq1,
    input n_autovec,
    output reg n_iack_out
);

    /* Setup default pin states */
    initial begin
        /* CPU */
        n_br = 1'b1;
        n_ipl = 3'b111;
        n_vpa = 1'b1;
        
        /* DRAM */
        n_ras0 = 1'b1;
        n_ras1 = 1'b1;
        n_ucas = 1'b1;
        n_lcas = 1'b1;
        masel = 1'b0;
        
        /* Expansion bus */
        own = 1'b1;
        ddir = 1'b1;
        n_dben = 1'b1;
        n_bg0 = 1'b1;
        n_bg1 = 1'b1;
        
        /* Ethernet */
        n_eth_cs = 1'b1;
        n_eth_das = 1'b1;
        n_eth_bg = 1'b1;
        
        /* Interrupt */
        n_iack_out = 1'b1;
    end
    
    /* Clock divider */
    clock_divider clock_divider(
        .osc_40mhz(osc_40mhz),
        .eth_clk(eth_clk),
        .cpu_clk(cpu_clk),
        .timer_clk(timer_clk)
    );
    
    /* Bus watchdog */
    wire n_wd_berr;
    
    bus_watchdog bus_watchdog(
        .cpu_clk(cpu_clk),
        .n_as(n_as),
        .n_dtack(n_dtack),
        .n_berr(n_wd_berr)
    );
    
    /* X-bus machine */
    wire n_xb_dtack;
    wire boot_ff;
    
    xbus_machine xbus_machine(
        .osc_40mhz(osc_40mhz),
        .n_reset(n_reset),
        .addr(addr),
        .n_as(n_as),
        .n_uds(n_uds),
        .n_lds(n_lds),
        .n_write(n_write),
        .xa0(xa0),
        .n_xd_lreg_le(n_xd_lreg_le),
        .n_xd_lreg_oe(n_xd_lreg_oe),
        .n_xd_ubuf_oe(n_xd_ubuf_oe),
        .n_xd_lbuf_oe(n_xd_lbuf_oe),
        .n_rom0_cs(n_rom0_cs),
        .n_rom1_cs(n_rom1_cs),
        .n_io_cs(n_io_cs),
        .n_uart_cs(n_uart_cs),
        .n_timer_cs(n_timer_cs),
        .n_dtack(n_xb_dtack),
        .boot_ff(boot_ff)
    );
    
    /* DRAM machine */
    wire n_dram_dtack;
    
    dram_machine dram_machine(
        .osc_40mhz(osc_40mhz),
        .boot_ff(boot_ff),
        .addr(addr),
        .n_as(n_as),
        .n_uds(n_uds),
        .n_lds(n_lds),
        .n_ras0(n_ras0),
        .n_ras1(n_ras1),
        .n_ucas(n_ucas),
        .n_lcas(n_lcas),
        .masel(masel),
        .n_dtack(n_dram_dtack)
    );
    
    /* Composite signals */
    assign n_dtack_drv = n_xb_dtack && n_dram_dtack;
    assign n_berr_drv = n_wd_berr;
    
    assign debug1 = boot_ff;
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
module clock_divider(
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
    always_ff @(negedge osc_40mhz) begin
      divider <= divider + 1'b1;
    end

    /* Assign clock outputs */
    assign eth_clk = divider[0];
    assign cpu_clk = divider[1];
    assign timer_clk = divider[5];
endmodule

/* Bus Watchdog
 *
 * The bus watchdog monitors the AS/ signal, and when ever it is asserted, a countdown timer is
 * started. If that timer reaches zero without DTACK/ being asserted, the watchdog will assert BERR/
 * to attempt to end the current bus cycle. */
module bus_watchdog(
    input cpu_clk,
    input n_as,
    input n_dtack,
    output n_berr
);
    /* A 5 bit counter to act as the timeout counter */
    reg [4:0] timeout;
    
    /* Start timer at maximal value */
    initial timeout = -'d1;
    
    always @(posedge cpu_clk) begin
        if (n_as) begin
            /* The watchdog is effectively in reset whenever AS/ is negated */
            timeout <= -'d1;
        end
        else begin
            if (timeout == 'd0) begin
                /* Assert BERR/ whenever AS/ is asserted and the timer has reached zero */
            end
            else begin
                /* Decrement timer whenever AS/ is asserted and DTACK/ is not */
                if (n_dtack) begin
                    timeout <= timeout - 'd1;
                end
            end
        end
    end
    
    /* Assert BERR/ when timeout occurrs, negate whenever AS/ is high or the timer is non-zero */
    assign n_berr = !(timeout == 0) || n_as;
endmodule

/* X-bus Machine
 *
 * The X-bus is an 8-bit bus within the computer that connects all of the smaller peripherals to
 * the rest of the system. It also houses the ROMs.
 *
 * To permit all 8-bit devices to be readable and writeable at byte addresses, the X-bus machine
 * implements the required handling of buffers and latches between the X-bus and the CPU bus along
 * with a synthesized A0 address signal.
 *
 * Additionally, it provides functionality to allow words to be read from a single ROM.
 *
 * Finally, ROM remapping is performed. After a reset, ROM is accessible from address 0 until the
 * CPU has read the initial SP and PC values. Once the CPU makes an access to the 0xFXXXXX address
 * space, the ROMs are remapped to that address space and DRAM becomes available from address 0
 * after boot_ff is set.
 *
 * The following address map is implemented in this machine:
 *
 * 0xCXXXXX     On-board peripherals
 *    1XXXX         On-board IO (LEDs, configuration jumpers, etc)
 *    2XXXX         TL16C2552 dual UART
 *    3XXXX         DP8570A timer/RTC
 * 0xFXXXXX     ROMs
 *
 * Note: Ethernet chip select is decoded and handled through the ethernet machine. */
module xbus_machine
#(parameter ROM_WAIT_STATES=3)
(
    input osc_40mhz,
    input n_reset,
    input [23:16] addr,
    input n_as,
    input n_uds,
    input n_lds,
    input n_write,
    output reg xa0,
    output reg n_xd_lreg_le,
    output reg n_xd_lreg_oe,
    output reg n_xd_ubuf_oe,
    output reg n_xd_lbuf_oe,
    output n_rom0_cs,
    output n_rom1_cs,
    output n_io_cs,
    output reg n_uart_cs,
    output n_timer_cs,
    output reg n_dtack,
    output reg boot_ff
);
    /* X-bus state machine states */
    reg [2:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_ROM_LATCH_LOWER = 'd1,
        M_UART_CS_ASSERT = 'd2,
        M_TIMER_CS_ASSERT = 'd2,
        M_WAIT_AS_NEGATE = 'd7;
    
    /* Counter used throughout the machine to time various delays */
    reg [2:0] delay;
    
    /* Register defaults */
    initial begin
        m_state = M_IDLE;
        delay = 'd0;
        xa0 = 1'b1;
        n_xd_lreg_le = 1'b1;
        n_xd_lreg_oe = 1'b1;
        n_xd_ubuf_oe = 1'b1;
        n_xd_lbuf_oe = 1'b1;
        n_uart_cs = 1'b1;
        n_dtack = 1'b1;
        boot_ff = 1'b0;
    end
    
    wire in_cycle = (!n_as && (!n_uds || !n_lds));
    wire word_read = (n_write && !n_uds && !n_lds);
    wire word_write = (!n_write && !n_uds && !n_lds);
    wire byte_access = (!word_read && !word_write);
    wire rom_reset = (!boot_ff && (addr[23:20] == 4'h0));
    wire rom_booted = (addr[23:20] == 4'hF);
    wire rom_decoded = (!word_write && (rom_reset || rom_booted));
    wire io_decoded = (byte_access && (addr[23:16] == 8'hC1));
    wire uart_decoded = (byte_access && (addr[23:16] == 8'hC2));
    wire timer_decoded = (byte_access && (addr[23:16] == 8'hC3));
    wire xbus_decoded = (!n_as && (rom_decoded || io_decoded || uart_decoded || timer_decoded));
    
    /* Assert chip selects based on above decoding logic */
    always_comb begin
        n_rom0_cs = !(in_cycle && rom_decoded && !addr[19]);
        n_rom1_cs = !(in_cycle && rom_decoded && addr[19]);
        n_io_cs = !(in_cycle && io_decoded);
        n_timer_cs = !(in_cycle && timer_decoded);
    end
    
    always @(negedge osc_40mhz) begin
        if (!n_reset) begin
            boot_ff <= 1'b0;
        end
        
        /* DTACK can be asserted immediately for any X-bus access, because all X-bus accesses will
         * complete within a CPU cycle with no wait states required */
        n_dtack <= !xbus_decoded;
        
        case (m_state)
            M_IDLE:
                if (!n_as && (!n_uds || !n_lds)) begin
                    /* On the first access to the 0xFXXXXX address space, set the boot_ff to remap
                     * the ROMs from address 0 into this space */
                    if (rom_booted) begin
                        boot_ff <= 1'b1;
                    end
                    
                    if (rom_decoded) begin
                        /* Setup for latching lower byte */
                        xa0 <= 1'b1;
                        n_xd_lreg_le <= 1'b0;
                        n_xd_lreg_oe <= 1'b0;
                        
                        /* ROM access delay before latching */
                        delay <= ROM_WAIT_STATES;
                        m_state <= M_ROM_LATCH_LOWER;
                    end
                    
                    if (io_decoded || uart_decoded || timer_decoded) begin
                        /* Logic that is common to all X-bus peripherals (excl ROM) */
                        
                        /* Setup XA0 */
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
                    end
                    
                    if (io_decoded || timer_decoded) begin
                        /* All there is to do is wait for AS to negate */
                        m_state <= M_WAIT_AS_NEGATE;
                    end
                    
                    if (uart_decoded) begin
                        /* XA0 is setup based on the state of UDS, but the TL16C2552 is sensitive
                         * to its setup time. Insert one clock worth of delay before manually
                         * asserting the UART CS. */
                        m_state <= M_UART_CS_ASSERT;
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
                    delay <= delay - 'd1;
                end
            
            M_UART_CS_ASSERT:
                begin
                    /* Assert UART CS now that some setup time has passed */
                    n_uart_cs <= 1'b0;
                    
                    /* Now we just wait for AS to negate */
                    m_state <= M_WAIT_AS_NEGATE;
                end
            
            M_WAIT_AS_NEGATE:
                if (n_as) begin
                    n_xd_lreg_le <= 1'b1;
                    n_xd_lreg_oe <= 1'b1;
                    n_xd_ubuf_oe <= 1'b1;
                    n_xd_lbuf_oe <= 1'b1;
                    n_uart_cs <= 1'b1;
                    
                    m_state <= M_IDLE;
                end
        endcase
    end
endmodule

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
            ACCESS_CAS_WAIT_STATES=2,
            PRECHARGE_WAIT_STATES=2)
(
    input osc_40mhz,
    input boot_ff,
    input [23:16] addr,
    input n_as,
    input n_uds,
    input n_lds,
    output reg n_ras0,
    output reg n_ras1,
    output reg n_ucas,
    output reg n_lcas,
    output reg masel,
    output n_dtack
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
    reg [2:0] delay;
    
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
    end
    
    always_comb begin
        /* Assert DTACK/ when ever the machine is in the CAS portion of a cycle */
        n_dtack = !(m_state == M_ACCESS_CAS);
    end
    
    always @(negedge osc_40mhz) begin
        /* If not resetting, decrement the refresh timer. Set refresh_due flag once the timer
         * reaches 0. */
        if (dram_refresh_timer == 'd0) begin
            refresh_due <= 1'b1;
            dram_refresh_timer <= REFRESH_CLOCKS;
        end
        else begin
            dram_refresh_timer <= dram_refresh_timer - 'd1;
        end
        
        case (m_state)
            /* In the idle state, the machine is waiting for either a memory access cycle from an
             * external device, or the refresh_due flag to be set to perform a refresh cycle. */
            M_IDLE: /* 0 */
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
                else if (boot_ff && !n_as && addr[23:22] == 2'b00) begin
                    /* Memory access cycle - assert RAS according to DRAM bank */
                    if (addr[21] == 1'b0) begin
                        /* DRAM module 0 if A21 is low */
                        n_ras0 <= 1'b0;
                    end
                    else begin
                        /* DRAM module 1 if A21 is high */
                        n_ras1 <= 1'b0;
                    end
                    
                    /* Move to wait for xDS strobes */
                    m_state <= M_ACCESS_WAIT_XDS;
                end
            
            /* DRAM refresh: assert RAS towards DRAM modules, and delay */
            M_REFRESH_RAS: /* 1 */
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
                    
                    delay <= delay - 'd1;
                end
            
            /* Wait for xDS to be asserted before moving to CAS access delay */
            M_ACCESS_WAIT_XDS: /* 2 */
                if (!n_uds || !n_lds) begin
                    /* Change to presenting column address */
                    masel <= 1'b1;
                    
                    /* Move to CAS access delay - add one wait state to account for the fact that
                     * CAS's will be asserted in the next state */
                    delay <= ACCESS_CAS_WAIT_STATES + 'd1;
                    m_state <= M_ACCESS_CAS;
                end
            
            /* CAS portion of memory access cycle */
            M_ACCESS_CAS: /* 3 */
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
                        delay <= delay - 'd1;
                    end
                end
            
            /* Precharge delay in between cycles */
            M_PRECHARGE: /* 7 */
                if (delay == 'd0) begin
                    /* After precharge, move back to IDLE state to handle next cycle */
                    m_state <= M_IDLE;
                end
                else begin
                    delay <= delay - 'd1;
                end
        endcase
    end
endmodule

/* END */
