`timescale 1ns/1ns

module COMET_PCH_tb();
    reg osc_40mhz;
    reg n_reset;
    
    /* Clocks */
    wire eth_clk;
    wire cpu_clk;
    wire timer_clk;
    
    /* CPU signals */
    reg [23:16] addr;
    reg [2:0] fc;
    reg n_as;
    reg n_uds;
    reg n_lds;
    reg n_write;
    reg n_bg;
    
    wire n_dtack; /* inout */
    
    wire n_berr;
    wire n_vpa;
    wire n_br;
    wire a0;
    
    /* Interrupt handling */
    reg n_nmi_irq;
    reg n_irq7;
    reg n_irq6;
    reg uart_irq;
    reg n_irq5;
    reg n_eth_irq;
    reg n_irq4;
    reg n_irq3;
    reg n_irq2;
    reg n_irq1;
    reg n_timer_irq;
    reg cpu_iack;
    reg n_iack_in;
    wire [2:0] ipl;
    wire n_iack_out;
    
    /* Bus arbitration */
    reg n_eth_br;
    reg n_br1;
    reg n_br0;
    wire n_eth_bg;
    wire n_bg1;
    wire n_bg0;

    /* Address decoding, XDATA control signals, DRAM interface */
    wire n_rom_cs;
    wire n_io_cs;
    wire n_uart_cs;
    wire n_timer_cs;
    wire n_eth_cs;
    wire n_xdata_ubuf_oe;
    wire n_xdata_lbuf_oe;
    wire n_xdata_lreg_oe;
    wire n_xdata_lreg_le;
    wire n_ras0;
    wire n_ras1;
    wire n_ucas;
    wire n_lcas;
    wire n_ras_mux;
    wire n_cas_mux;
    
    /********************************************/
    
    /* Clock Divider */
    clk_div clk_div_UUT(
        .osc_40mhz(osc_40mhz),
        .eth_clk(eth_clk),
        .cpu_clk(cpu_clk),
        .timer_clk(timer_clk)
    );
    
    /* Interrupt Controller */
    int_ctl int_ctl_UUT(
        .clk(osc_40mhz),
        .n_nmi_irq(n_nmi_irq),
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
        .cpu_iack(cpu_iack),
        .n_iack_in(n_iack_in),
        .ipl(ipl),
        .n_vpa(n_vpa),
        .n_iack_out(n_iack_out)
    );
    
    bus_arb bus_arb_UUT(
        .clk(osc_40mhz),
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
    
    mem_mach #(.REFRESH_CLOCKS(32)) mem_mach_UUT(
        .clk(osc_40mhz),
        .cpu_clk(osc_40mhz),
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
    
    /* Bus watchdog
     *
     * Instantiate with a few less bits to make the count go quicker during testing */
    wire n_wdog_berr;
    
    bus_wdog #(.BITS(4)) bus_wdog_UUT(
        .clk(osc_40mhz),
        .n_reset(n_reset),
        .n_as(n_as),
        .n_dtack(n_dtack),
        .n_berr(n_wdog_berr)
    );
    
    assign n_berr = (n_mm_berr & n_wdog_berr) ? 1'bZ : 1'b0;
    
    /* Initialise */
    initial
    begin
        osc_40mhz = 1;
        n_reset = 1;
        
        /* CPU signals */
        addr = 0;
        n_as = 1;
        n_uds = 1;
        n_lds = 1;
        n_write = 1;
        n_bg = 1;
          
        /* Interrupts */
        n_nmi_irq = 1;
        n_irq7 = 1;
        n_irq6 = 1;
        uart_irq = 0;
        n_irq5 = 1;
        n_eth_irq = 1;
        n_irq4 = 1;
        n_irq3 = 1;
        n_irq2 = 1;
        n_irq1 = 1;
        n_timer_irq = 1;
        cpu_iack = 0;
        n_iack_in = 1;
        
        /* Bus arbitration */
        n_eth_br = 1;
        n_br1 = 1;
        n_br0 = 1;
    end
    
    /* Step the input clock (ala 40MHz) */
    always #1 osc_40mhz <= ~osc_40mhz;
    
    /* Simulate */
    initial
    begin
        /* Run for a few clocks with reset asserted, then release */
        repeat (1) @(posedge osc_40mhz);
        n_reset = 0;
        repeat (5) @(posedge osc_40mhz);
        n_reset = 1;
        repeat (2) @(posedge osc_40mhz);
        
//        /* Run for a bit to generate some clock waveforms */
//        repeat (200) @(posedge osc_40mhz);

        /* Test memory machine *********************************************************************/
        
        /* Test reading reset vector through to executing code. After reset we should not be in
         * running state. */
        assert(mem_mach_UUT.running == 0);
        assert(n_berr === 1'bZ);
        assert(n_dtack === 1'bZ);

        /* Adjust the number of clocks so that AS aligns with a rising edge of the CPU clock */
        repeat (3) @(posedge osc_40mhz);

//        /******************************************************************************************/
//        
//        /* Test BERR assertion if trying to make an invalid access before the reset vector has been
//         * read */
//        
//        /* Change the address on the falling edge of the CPU clock */
//        addr = 8'h50;
//        
//        /* After two more clocks the CPU asserts AS and some data strobes */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        n_lds = 0;
//        n_as = 0;
//        
//        /* Now expect the memory machine to have asserted BERR due to accessing an invalid memory
//         * range during reset vector acquisition */
//        repeat (3) @(posedge osc_40mhz);
//
//        assert(n_berr == 0);
//        
//        /* End the bus cycle */
//        repeat (3) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_lds = 1;
//        n_as = 1;
//        
//        /******************************************************************************************/
//        
//        /* CPU asserts UDS/LDS/AS to start a bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        addr = 8'h00;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        n_lds = 0;
//        n_as = 0;
//        
//        /* Memory machine moves to access the lower byte of a word (odd address), which is to be
//         * latched */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack == 1'b0);
//        assert(a0 == 1);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 0);
//        assert(n_rom_cs == 0);
//        
//        /* After 4 more clocks the memory machine moves to access the upper byte of a word (even
//         * address) */
//        repeat (4) @(posedge osc_40mhz);
//        
//        assert(n_dtack == 1'b0);
//        assert(a0 == 0);
//        assert(n_xdata_ubuf_oe == 0);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 1);
//        assert(n_rom_cs == 0);
//        
//        /* After 4 more clocks the CPU has recognised DTACK low and ends its bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_lds = 1;
//        n_as = 1;
//        
//        /* 2 more clocks and the memory machine releases all signals and tri-states buffers. Buffer
//         * directions and the state of XDATA A0 are inconsequential. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 1);
//        
        /******************************************************************************************/
        
        /* Now test reading the first instruction from the ROM space, which should cause the running
         * flag to become set. 2 more clocks and we hit a falling edge of the CPU clock where the
         * address set set up by the CPU. */
        repeat (2) @(posedge osc_40mhz);
        
        addr = 8'h40;
        
        /* 2 more clocks and the memory machine should be in the running state, and the CPU starts a
         * new bus cycle to read a word (instruction) */
        repeat (2) @(posedge osc_40mhz);
        
        assert(mem_mach_UUT.running == 1);
        
        n_uds = 0;
        n_lds = 0;
        n_as = 0;
        
        /* 10 more clocks to finish the cycle */
        repeat (10) @(posedge osc_40mhz);
        
        n_uds = 1;
        n_lds = 1;
        n_as = 1;
        
//        /******************************************************************************************/
//        
//        /* Test watchdog timeout - set an address that is not decoded by the PCH */
//        repeat (4) @(posedge osc_40mhz);
//        
//        addr = 8'h60;
//        
//        /* CPU asserts AS */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_as = 0;
//        
//        /* No chip selects or other signals should be asserted */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_xdata_lreg_le == 1);
//        assert(n_berr === 1'bZ);
//        assert(n_dtack === 1'bZ);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 1);
//        assert(n_uart_cs == 1);
//        assert(n_timer_cs == 1);
//        assert(n_eth_cs == 1);
//        
//        /* Run out the counter, afterwhich BERR should be asserted */
//        repeat (16) @(posedge osc_40mhz);
//        
//        assert(n_berr == 1'b0);
//        
//        /* End the bus cycle and BERR should be negated */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_as = 1;
//
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        
//        /******************************************************************************************/
//        
//        /* Test reading individual bytes - start with lower (odd) byte. 6 clocks to the start of
//         * the next CPU bus cycle. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        addr = 8'h40;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_as = 0;
//        
//        /* Memory machine should be setup for latching */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(a0 == 1);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 0);
//        assert(n_rom_cs == 0);
//        
//        /* After 4 more clocks the data should be latched and ready for the CPU */
//        repeat (4) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 1);
//        assert(n_rom_cs == 0);
//        
//        /* After 4 more clocks the CPU ends the bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_as = 1;
//        
//        /* 2 more clocks and the memory machine releases all signals and tri-states buffers. Buffer
//         * directions and the state of XDATA A0 are inconsequential. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Read upper (even) byte - 4 clocks to the start of the next CPU cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        n_as = 0;
//        
//        /* Memory machine should be setup to buffer */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(a0 == 0);
//        assert(n_xdata_ubuf_oe == 0);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_xdata_lreg_le == 1);
//        assert(n_rom_cs == 0);
//        
//        /* After 8 more clocks the CPU ends the bus cycle. Upper bytes require no latching, so
//         * proceed straight to the end of the bus cycle. */
//        repeat (8) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_as = 1;
//        
//        /* 2 more clocks and the memory machine releases all signals and tri-states buffers. Buffer
//         * directions and the state of XDATA A0 are inconsequential. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Write lower (odd) byte */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_write = 0;
//        n_as = 0;
//        
//        /* Since a data strobe has not been asserted, the memory machine should not be trying to
//         * set up any buffering or latching. The chip select is also not asserted at this time. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 1);
//        
//        /* The CPU then asserts LDS */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        
//        /* Now the memory machine should be buffering the lower byte (not latching!), and the chip
//         * select is asserted */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 0);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 0);
//        
//        /* The CPU ends the bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_as = 1;
//        
//        /******************************************************************************************/
//        
//        /* Write upper (even) byte */
//        repeat (6) @(posedge osc_40mhz);
//        
//        n_write = 0;
//        n_as = 0;
//        
//        /* Since a data strobe has not been asserted, the memory machine should not be trying to
//         * set up any buffering or latching. The chip select is also not asserted at this time. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 1);
//        
//        /* The CPU then asserts UDS */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        
//        /* Now the memory machine should be buffering the upper byte, and the chip select is
//         * asserted. The upper byte buffer direction should also be configured for the writing
//         * direction. */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_xdata_ubuf_oe == 0);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_rom_cs == 0);
//        
//        /* The CPU ends the bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_as = 1;
//        
//        /******************************************************************************************/
//        
//        /* Access on-board IO as a word, should result in BERR */
//        repeat (4) @(posedge osc_40mhz);
//        
//        addr = 8'h50;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_uds = 0;
//        n_as = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr == 0);
//        assert(n_dtack === 1'bZ);
//        assert(n_io_cs == 1);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_uds = 1;
//        n_as = 1;
//        
//        /******************************************************************************************/
//        
//        /* Perform a valid access to on-board IO - upper (even) byte */
//        repeat (6) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        n_as = 0;
//        n_write = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 0);
//        assert(n_uart_cs == 1);
//        assert(n_timer_cs == 1);
//        assert(n_eth_cs == 1);
//        assert(n_xdata_ubuf_oe == 0);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_xdata_lreg_le == 1);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_as = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_io_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Perform a valid access to on-board IO - lower (odd) byte */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_as = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 0);
//        assert(n_uart_cs == 1);
//        assert(n_timer_cs == 1);
//        assert(n_eth_cs == 1);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 0);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_as = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_io_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Perform a valid access to UART - upper (even) byte */
//        repeat (2) @(posedge osc_40mhz);
//        
//        addr = 8'h51;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        n_as = 0;
//        n_write = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 1);
//        assert(n_uart_cs == 0);
//        assert(n_timer_cs == 1);
//        assert(n_eth_cs == 1);
//        assert(n_xdata_ubuf_oe == 0);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_xdata_lreg_le == 1);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_as = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_uart_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Perform a valid access to UART - lower (odd) byte */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_as = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 1);
//        assert(n_uart_cs == 0);
//        assert(n_timer_cs == 1);
//        assert(n_eth_cs == 1);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 0);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_as = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_uart_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Perform a valid access to timer - upper (even) byte */
//        repeat (2) @(posedge osc_40mhz);
//        
//        addr = 8'h52;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_uds = 0;
//        n_as = 0;
//        n_write = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 1);
//        assert(n_uart_cs == 1);
//        assert(n_timer_cs == 0);
//        assert(n_eth_cs == 1);
//        assert(n_xdata_ubuf_oe == 0);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_xdata_lreg_le == 1);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_uds = 1;
//        n_as = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_timer_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Perform a valid access to timer - lower (odd) byte */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_as = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 1);
//        assert(n_uart_cs == 1);
//        assert(n_timer_cs == 0);
//        assert(n_eth_cs == 1);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 0);
//        assert(n_xdata_lreg_le == 0);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_as = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_dtack === 1'bZ);
//        assert(n_timer_cs == 1);
//        
//        /******************************************************************************************/
//        
//        /* Attempt a byte access to the ethernet controller - should result in BERR */
//        repeat (2) @(posedge osc_40mhz);
//        
//        addr = 8'h53;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_as = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr == 0);
//        assert(n_dtack === 1'bZ);
//        assert(n_eth_cs == 1);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_as = 1;
//
//        /******************************************************************************************/
//        
//        /* Perform a valid word access to the ethernet controller */
//        repeat (6) @(posedge osc_40mhz);
//        
//        n_lds = 0;
//        n_uds = 0;
//        n_as = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_berr === 1'bZ);
//        assert(n_dtack == 1'b0);
//        assert(n_rom_cs == 1);
//        assert(n_io_cs == 1);
//        assert(n_uart_cs == 1);
//        assert(n_timer_cs == 1);
//        assert(n_eth_cs == 0);
//        assert(n_xdata_ubuf_oe == 1);
//        assert(n_xdata_lbuf_oe == 1);
//        assert(n_xdata_lreg_oe == 1);
//        assert(n_xdata_lreg_le == 1);
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_lds = 1;
//        n_uds = 1;
//        n_as = 1;
        
        /******************************************************************************************/
        
        /* Test word access to DRAM, first bank (RAS0) */
        repeat (2) @(posedge osc_40mhz);
        addr = 8'h10;
        
        /* CPU accesses a word */
        repeat (2) @(posedge osc_40mhz);
        n_lds = 0;
        n_uds = 0;
        n_as = 0;
        
        /* After 2 clocks, the row address should be strobed */
        repeat (2) @(posedge osc_40mhz);
        
        assert(n_dtack == 1'b0);
        assert(n_ras0 == 1'b0);
        assert(n_ras1 == 1'b1);
        assert(n_ucas == 1'b1);
        assert(n_lcas == 1'b1);
        assert(n_ras_mux == 1'b0);
        assert(n_cas_mux == 1'b1);
        assert(mem_mach_UUT.accessing_dram == 1'b1);
        assert(n_rom_cs == 1'b1);
        assert(n_io_cs == 1'b1);
        assert(n_uart_cs == 1'b1);
        assert(n_timer_cs == 1'b1);
        assert(n_eth_cs == 1'b1);
        
        /* After 2 clocks, the column address should be strobed */
        repeat (2) @(posedge osc_40mhz);
        
        assert(n_ras0 == 1'b0);
        assert(n_ras1 == 1'b1);
        assert(n_ucas == 1'b0);
        assert(n_lcas == 1'b0);
        assert(n_ras_mux == 1'b1);
        assert(n_cas_mux == 1'b0);
        
        repeat (6) @(posedge osc_40mhz);
        
        n_lds = 1;
        n_uds = 1;
        n_as = 1;
        
        /* Test a RMW cycle */
        repeat (6) @(posedge osc_40mhz);
        n_uds = 0;
        n_as = 0;
        
        repeat (10) @(posedge osc_40mhz);
        n_uds = 1;
        
        repeat (14) @(posedge osc_40mhz);
        n_write = 0;
        
        repeat (4) @(posedge osc_40mhz);
        n_uds = 0;
        
        repeat (6) @(posedge osc_40mhz);
        n_uds = 1;
        n_as = 1;
        
        repeat (2) @(posedge osc_40mhz);
        n_write = 1;
        
        
        
        
        
        
        
        
        
        
//        /* Test bus arbitrator *********************************************************************/
//        
//        /* CPU is currently in a bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        n_as = 0;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//        /* Ethernet controller makes a bus request which causes the arbiter to request the bus from
//         * the CPU */
//        n_eth_br = 0;
//        
//        /* After a few clocks, the CPU grants the bus but is still completing its bus cycle */
//        repeat (4) @(posedge osc_40mhz);
//        
//        assert(n_br == 0);
//        
//        n_bg = 0;
//        
//        /* The CPU then finishes its bus cycle which allows the arbitrator to hand the bus over to
//         * the ethernet controller */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_eth_bg == 1);
//
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_as = 1;
//        
//        /* Ethernet controller should now be granted the bus */
//        repeat (2) @(posedge osc_40mhz);
//        
//        assert(n_eth_bg == 0);
//        assert(n_bg1 == 1);
//        assert(n_bg0 == 1);
//        
//        /* Now BR1 and BR0 make a request */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_br1 = 0;
//        n_br0 = 0;
//        
//        /* After some time the ethernet controller releases the bus */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_eth_br = 1;
//        
//        /* The arbitrator then releases the ethernet controllers grant, and with BR1 being the next
//         * highest pending bus request, it proceeds to grant BG0 */
//        repeat (4) @(posedge osc_40mhz);
//        
//        assert(n_eth_bg == 1);
//        assert(n_bg1 == 0);
//        assert(n_bg0 == 1);
//        
//        /******************************************************************************************/
//        
//        /* After some time, BR1 is deaserted */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_br1 = 1;
//        
//        /* And the arbiter then releases BG0, and now with BG0 being the only remaining bus request,
//         * BG0 is granted */
//        repeat (4) @(posedge osc_40mhz);
//        
//        assert(n_eth_bg == 1);
//        assert(n_bg1 == 1);
//        assert(n_bg0 == 0);
//        
//        /******************************************************************************************/
//        
//        /* BR0 is then released after some time */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_br0 = 1;
//        
//        /* And the arbiter then releases BG0, and shortly after BR is negated towards the CPU */
//        repeat (4) @(posedge osc_40mhz);
//        
//        assert(n_br == 1);
//        
//        assert(n_eth_bg == 1);
//        assert(n_bg1 == 1);
//        assert(n_bg0 == 1);
//        
//        /* Now the CPU releases its grant and retakes the bus */
//        repeat (2) @(posedge osc_40mhz);
//        
//        n_bg = 1;
      
          
        
//        /* Test interrupt controller **************************************************************/
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* IPL should be fully negated, VPA should be deasserted (floating), and iack_out should
//             * also be deasserted */
//            assert(ipl == ~3'd0);
//            assert(vpa === 1'bZ);
//            assert(iack_out == 1);
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* After some time IRQ7 is asserted */
//            nmi_irq = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* IPL should represent IRQ7 */
//            assert(ipl == ~3'd7);
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* The CPU then begins to acknowledge the change in IPL from 0 to 7 */
//            cpu_iack = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* VPA should be asserted */
//            assert(vpa == 0);
//        
//            /* iack_out should be deasserted */
//            assert(iack_out == 1);
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* An interrupt for the timer comes in while in IRQ7 is being acknowledged */
//            timer_irq = 0;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should still represent IRQ7 */
//            assert(ipl == ~3'd7);
//        
//            /* The CPU has finished acking IRQ7 */
//            cpu_iack = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* VPA should be deasserted */
//            assert(vpa === 1'bZ);
//        
//            /* iack_out should still be deasserted */
//            assert(iack_out == 1);
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* IRQ7 becomes deasserted, the IPL for the timer interrupt is presented to the CPU */
//            nmi_irq = 1;
//        
//            /* Above this line we test that a lower priority IRQ does not affect the IPL presented
//             * to the CPU from a higher priority IRQ until the higher priority IRQ is cleared */
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should now represent IRQ1 */
//            assert(ipl == ~3'd1);
//        
//            /* Since the IPL has not been fully negated, the CPU begins to acknowledge IRQ1 */
//            cpu_iack = 1;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IRQ4 becomes asserted during acknowledgement of IRQ1 */
//            eth_irq = 0;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should now represent IRQ4 */
//            assert(ipl == ~3'd1);
//        
//            /* The CPU has finished acking IRQ1 */
//            cpu_iack = 0;
//        
//        repeat (3) @(posedge osc_40mhz);
//        
//            /* Once the CPU has completed the interrupt acknowledge process, the next highest
//             * pending IPL may then be presented to the CPU */
//            assert(ipl == ~3'd4);
//         
//        repeat (1) @(posedge osc_40mhz);
//        
//            /* The CPU now begins to ack the change to a higher priority IPL (1 to 4) */
//            cpu_iack = 1;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* And finishes acking IRQ4 */
//            cpu_iack = 0;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IRQ4 becomes deasserted after the software clears the asserting condition. The IPL
//             * will return to the next highest value which will be for IRQ1, and since the IPL field
//             * in the status word of the CPU is also restored to IPL1, no acknowledgement is
//             * performed and the software continues to clear the asserting condition of IRQ1. */
//            eth_irq = 1;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should be back to IRQ1 */
//            assert(ipl == ~3'd1);
//        
//            /* IRQ1 is released after the asserting condition is cleared */
//            timer_irq = 1;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should be fully negated */
//            assert(ipl == ~3'd0);
//        
//            /* Above this line we test that a lower priority IRQ can be interrupted (nested) with a
//             * higher priority IRQ, and that once the higher priority IRQ is cleared that we return
//             * to the lower priority IRQ */
//        
//            /* Now test external interrupt acknowledgement passthrough */
//            irq3 = 0;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* CPU acks the change in IPL from 0 to 3 */
//            cpu_iack = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* IPL should represent IRQ3 */
//            assert(ipl == ~3'd3);
//            
//            /* VPA should be deasserted */
//            assert(vpa === 1'bZ);
//            
//            /* iack_out should be asserted for external interrupt */
//            assert(iack_out == 0);
//
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* Test asserting a higher priority IRQ input */
//            irq6 = 0;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* IPL should still represent IRQ3 as it is still being acknowledged */
//            assert(ipl == ~3'd3);
//            
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* Asserting condition for external IRQ3 is cleared */
//            irq3 = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* Interrupt acknowledgement no longer in progress */
//            cpu_iack = 0;
//        
//        repeat (4) @(posedge osc_40mhz);
//
//            /* IPL should now represent IRQ6 */
//            assert(ipl == ~3'd6);
//            
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* CPU acks the change in IPL from 3 to 6 */
//            cpu_iack = 1;
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* IPL should represent IRQ6 */
//            assert(ipl == ~3'd6);
//            
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* The source of IRQ6 is going to auto-vector its interrupt, so asserts iack_in */
//            iack_in = 0;
//            
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* VPA should then be asserted towards the CPU */
//            assert(vpa == 0);
//        
//        repeat (2) @(posedge osc_40mhz);
//        
//            /* Interrupt acknowledgement no longer in progress */
//            cpu_iack = 0;
//            
//        repeat (4) @(posedge osc_40mhz);
//            irq6 = 1;
//            iack_in = 1;
//        
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should now be fully negated */
//            assert(ipl == ~3'd0);
//            
//            /* IRQ6 has cleared, so VPA should be deasserted */
//            assert(vpa === 1'bZ);
//            
//        repeat (4) @(posedge osc_40mhz);
//        
//            /* IPL should now be fully negated */
//            assert(ipl == ~3'd0);
//        
//        repeat (2) @(posedge osc_40mhz);
    end
endmodule
