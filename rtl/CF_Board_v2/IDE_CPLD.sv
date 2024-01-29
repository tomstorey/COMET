`timescale 1ns/1ps

/* `define REREGISTER_CHIPSELECT */

/* Top module */
module IDE_CPLD(
    /* Clocks */
    input osc_40mhz,

    /* Global reset */
    input n_reset,
    
    /* Bus interface */
    input n_cs_in,
    input n_write,
    input n_uds,
    input n_lds,
    input a5,
    input a4,
    output logic n_dtack_drv,
    output logic n_berr_drv,
    
    /* IDE interface */
    output logic n_ide_cs0,
    output logic n_ide_cs1,
    output logic n_ide_rd,
    output logic n_ide_wr,
    
    /* Control signals */
    input [1:0] speed_sel
);
`ifdef REREGISTER_CHIPSELECT
    /* Registered copy of chipselect to cater for asynchronous clock domains */
    reg n_cs;
`else
    /* If not re-registering the chipselect signal, then simply duplicate it */
    wire n_cs = n_cs_in;
`endif
    
    /* State machine */
    reg [1:0] m_state;
    
    localparam
        M_IDLE = 'd0,
        M_IN_CYCLE = 'd1,
        M_RECOVERY_DELAY = 'd2;
    
    /* Cycle timing selections */
    localparam
        PIO_MODE01 = 2'b00,
        PIO_MODE23 = 2'b01,
        PIO_MODE4 = 2'b10;
    
    /* A shift register used to generate all timing */
    reg [23:0] timer;
    
    always_comb begin
        /* Assert chip selects towards the disk */
        n_ide_cs0 = !(!a5 && !a4 && (m_state == M_IN_CYCLE));
        n_ide_cs1 = !(!a5 &&  a4 && (m_state == M_IN_CYCLE));
        
        /* Assert read or write strobe towards the disk */
        n_ide_rd = !((m_state == M_IN_CYCLE) && !n_cs &&  n_write &&
                     (((speed_sel == PIO_MODE01) && timer[2]) ||
                      ((speed_sel == PIO_MODE01) && timer[2]) ||
                      ((speed_sel == PIO_MODE01) && timer[2])));
        n_ide_wr = !((m_state == M_IN_CYCLE) && !n_cs && !n_write &&
                     (((speed_sel == PIO_MODE01) && timer[2]) ||
                      ((speed_sel == PIO_MODE01) && timer[2]) ||
                      ((speed_sel == PIO_MODE01) && timer[2])));
        
        /* Assert DTACK once the minimum read/write strobe length has been reached */
        n_dtack_drv = !((m_state == M_IN_CYCLE) &&
                        (((speed_sel == PIO_MODE01) && timer[7]) ||
                         ((speed_sel == PIO_MODE23) && timer[4]) ||
                         ((speed_sel == PIO_MODE4) && timer[3])));
    end
    
`ifdef REREGISTER_CHIPSELECT
    always_ff @(posedge osc_40mhz or negedge n_reset) begin
        if (!n_reset) begin
            n_cs <= 1'b1;
        end
        else begin
            n_cs <= n_cs_in;
        end
    end
`endif
    
    always_ff @(negedge osc_40mhz) begin
        if (m_state == M_IDLE) begin
            /* In the idle state, the timer will continually be reset */
            timer <= 'd0;
        end
        else begin
            /* Otherwise it is continually shifting 1's in via the LSb */
            timer <= {timer[22:0], 1'b1};
        end
    end

    always_ff @(negedge osc_40mhz) begin
        if (!n_reset) begin
            m_state <= M_IDLE;
        end
        else begin
            case (m_state)
                M_IDLE:
                    begin
                        /* Once the CPLD chip select is asserted along with either or both data
                         * strobes, start timing the cycle */
                        if (!n_cs && (!n_uds || !n_lds)) begin
                            m_state <= M_IN_CYCLE;
                        end
                    end
                
                M_IN_CYCLE:
                    begin
                        if ((speed_sel == PIO_MODE01) && timer[8] ||
                            (speed_sel == PIO_MODE23) && timer[4] ||
                            (speed_sel == PIO_MODE4) && timer[2]) begin
                            /* Once the read/write strobe has been appropriately timed, wait for CS
                             * to be negated. For PIO mode 4 we can return directly to the idle state
                             * and all timing will be satisfied. For other modes, a delay may be
                             * required. */
                            if (n_cs) begin
                                if (speed_sel == PIO_MODE4) begin
                                    m_state <= M_IDLE;
                                end
                                else begin
                                    m_state <= M_RECOVERY_DELAY;
                                end
                            end
                        end
                    end
                
                M_RECOVERY_DELAY:
                    begin
                        /* Ensure that the overall minimum cycle time will be met before returning
                         * to the idle state where another cycle can begin */
                        if ((speed_sel == PIO_MODE01) && timer[21] ||
                            (speed_sel == PIO_MODE23) && timer[7]) begin
                            m_state <= M_IDLE;
                        end
                    end
            endcase
        end
    end
endmodule /* IDE_CPLD */

/* END */
