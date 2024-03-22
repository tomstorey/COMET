`timescale 1ns/1ps

module CF_CPLD
#(parameter SU_TIMER_BITS=3,        /* Number of bits required for setup timer */
            C_TIMER_BITS=18         /* Number of bits required for cycle timer (incl recovery) */
)
(
    /* Clocks */
    input osc_40mhz,

    /* Global reset */
    input n_reset,

    /* Bus interface */
    input n_sel,
    input n_uds,
    input n_lds,
    input n_write,
    input [2:0] fc,
    input [5:4] addr,
    output logic n_dtack_drv,
    output logic ddir,
    output logic n_dben,
    
    /* Status/control register interface */
    input [1:0] t,
    output logic n_rdstat,
    output logic n_wrcon,

    /* CF interface */
    output logic n_cs0,
    output logic n_cs1,
    output logic n_rd,
    output logic n_wr,
    output logic cf_ddir,
    
    /* Other */
    output logic debug1
);
    /* Signal synchronisation */
    reg n_sel_reg1;
    reg n_sel_reg2;
    reg n_uds_reg1;
    reg n_uds_reg2;
    reg n_lds_reg1;
    reg n_lds_reg2;
    wire n_sel_regd = ~(!n_sel_reg1 && !n_sel_reg2);
    wire n_uds_regd = ~(!n_uds_reg1 && !n_uds_reg2);
    wire n_lds_regd = ~(!n_lds_reg1 && !n_lds_reg2);
    
    /* Cycle timing modes 
     *
     * MODE_PIO01 provides timing that is standards compatible with PIO mode 0 and by extension PIO
     * mode 1.
     *
     * MODE_PIO23 provides timing that is standards compatible with PIO mode 2 and by extension PIO
     * mode 3.
     *
     * MODE_PIO4 provides timing that is standards compatible with PIO mode 4 and by extension
     * higher PIO modes.
     *
     * MODE_ASYNC provides fully asynchronous read/write cycles, derived from the CPUs control
     * signals. Faster CPUs will generate shorter cycles, and may not be compatible with many older
     * or slower cards. It is provided for legacy reasons only, and its use is not generally
     * recommended. */
    localparam
        MODE_PIO01 = 2'b00,
        MODE_PIO23 = 2'b01,
        MODE_PIO4 = 2'b10,
        MODE_ASYNC = 2'b11;

    /* Shift registers used to generate all of the timings based on the selected PIO mode */
    reg [SU_TIMER_BITS-1:0] su_timer;
    reg [C_TIMER_BITS-1:0] c_timer;
    
    /* State machine */
    reg [1:0] m_state;
    
    localparam
        M_IDLE = 2'd0,
        M_ACCESS = 2'd1,
        M_RECOVERY = 2'd2;
    
    /* For creating a mux'ed select signals */
    wire selected;
    wire selected_pio;
    
    /* A flag that indicates that the setup time for the selected PIO mode has been met */
    wire su_time_met;
    
    /* Motorola 68000 CPU function codes */
    localparam
        FC_USER_DATA = 3'b001,
        FC_USER_PROG = 3'b010,
        FC_SUP_DATA = 3'b101,
        FC_SUP_PROG = 3'b110,
        FC_CPU_SPACE = 3'b111;

    always_comb begin
        /* Select signals */
        selected     = (t == MODE_ASYNC) ? (!n_sel      && (fc == FC_SUP_DATA)) :
                                           (!n_sel_regd && (fc == FC_SUP_DATA));
        selected_pio = (t == MODE_ASYNC) ? 1'b0 : (!n_sel_regd && (fc == FC_SUP_DATA));
        
        /* Generate the "setup time met" flag */
        su_time_met = ((t == MODE_PIO01) && su_timer[2]) ||
                      ((t == MODE_PIO23) && su_timer[1]) ||
                      ((t == MODE_PIO4)  && su_timer[0]);
    
        /* Enable the system bus buffer when the card is decoded */
        n_dben = n_sel;
        
        /* Set the direction of the system bus buffer based on the write signal. The direction is
         * high when reading, and low when writing. */
        ddir = n_write;
        
        /* Set the direction of the CF card data buffers. The direction is high when not decoded or
         * when writing, and low when reading. */
        cf_ddir = ~(selected && !addr[5] && n_write);
        
        /* Chip selects based on A4: CS0 for the primary register set, CS1 for the alternative
         * register set */
        n_cs0 = (t == MODE_ASYNC) ? ~(!addr[4] && selected) :
                                    ~(!addr[4] && selected && (m_state == M_ACCESS));
        n_cs1 = (t == MODE_ASYNC) ? ~( addr[4] && selected) :
                                    ~( addr[4] && selected && (m_state == M_ACCESS));
        
        /* CF read/write signals */
        n_rd = ~(selected && !addr[5] && n_write &&
                 (
                  ((!n_uds_regd || !n_lds_regd) && (m_state == M_ACCESS) &&
                   (
                    ((t == MODE_PIO01) && su_timer[2]) ||
                    ((t == MODE_PIO23) && su_timer[1]) ||
                    ((t == MODE_PIO4)  && su_timer[0])
                   )
                  ) ||
                  ((t == MODE_ASYNC) && (!n_uds      || !n_lds))
                 )
                );
        n_wr = ~(selected && !addr[5] && !n_write &&
                 (
                  ((!n_uds_regd || !n_lds_regd) && (m_state == M_ACCESS) &&
                   (
                    ((t == MODE_PIO01) && su_timer[2] && !c_timer[6]) ||
                    ((t == MODE_PIO23) && su_timer[1] && !c_timer[3]) ||
                    ((t == MODE_PIO4)  && su_timer[0] && !c_timer[2])
                   )
                  ) ||
                  ((t == MODE_ASYNC) && (!n_uds || !n_lds))
                 )
                );
        
        /* Read or write the status/control register (always async) */
        n_rdstat = ~(selected &&  n_write && addr[5] && !n_uds);
        n_wrcon  = ~(selected && !n_write && addr[5] && !n_uds);
        
        /* Assert DTACK on any decoded opreation */
        n_dtack_drv = ~((selected && addr[5] && !n_uds) ||
                        ((m_state == M_ACCESS) && (!n_uds_regd || !n_lds_regd) &&
                         (
                          ((t == MODE_PIO01) && c_timer[7]) ||
                          ((t == MODE_PIO23) && c_timer[4]) ||
                          ((t == MODE_PIO4)  && c_timer[3])
                         )
                        ) ||
                        ((t == MODE_ASYNC) && selected && (!n_uds || !n_lds))
                       );
        
        /* Debug */
        debug1 = 1'b0;
    end
    
    /* Synchroniser phase 1 - first stage on falling edge of clock */
    always_ff @(negedge osc_40mhz or negedge n_reset) begin
        if (!n_reset) begin
            n_sel_reg1 <= 1'b1;
            n_uds_reg1 <= 1'b1;
            n_lds_reg1 <= 1'b1;
        end
        else begin
            n_sel_reg1 <= n_sel;
            n_uds_reg1 <= n_uds;
            n_lds_reg1 <= n_lds;
        end
    end
    
    /* Synchroniser phase 2 - second stage on rising edge of clock such that signals are available
     * at next falling edge */
    always_ff @(posedge osc_40mhz or negedge n_reset) begin
        if (!n_reset) begin
            n_sel_reg2 <= 1'b1;
            n_uds_reg2 <= 1'b1;
            n_lds_reg2 <= 1'b1;
        end
        else begin
            n_sel_reg2 <= n_sel_reg1;
            n_uds_reg2 <= n_uds_reg1;
            n_lds_reg2 <= n_lds_reg1;
        end
    end

    always_ff @(negedge osc_40mhz) begin
        /* Timers */
        if (m_state == M_IDLE) begin
            /* When the state machine is idle, no cycle is in progress so the timer is reset */
            su_timer <= 'd0;
            c_timer <= 'd0;
        end
        else begin
            /* Otherwise, fill timers with 1's from the LSb */
            su_timer <= {su_timer[SU_TIMER_BITS-2:0], 1'b1};
            
            if (su_time_met && (!n_uds_regd || !n_lds_regd) || (m_state == M_RECOVERY)) begin
                c_timer <= {c_timer[C_TIMER_BITS-2:0], 1'b1};
            end
        end

        /* State machine */
        if (!n_reset) begin
            m_state <= M_IDLE;
        end
        else begin
            case (m_state)
                M_IDLE:
                    begin
                        /* When the select signal is asserted with A5 being low a CF access cycle
                         * is beginning */
                        if (selected_pio && !addr[5]) begin
                            m_state <= M_ACCESS;
                        end
                    end
                
                M_ACCESS:
                    begin
                        /* Once select is negated, proceed to implement the cycle recovery delay */
                        if (!selected_pio) begin
                            m_state <= M_RECOVERY;
                        end
                    end
                
                M_RECOVERY:
                    begin
                        /* Time out the recovery period based on the selected PIO mode then return
                         * to the idle state where a new cycle can begin */
                        if ((t == MODE_PIO01) && c_timer[17] ||
                            (t == MODE_PIO23) && c_timer[9] ||
                            (t == MODE_PIO4)  && c_timer[4]) begin
                            m_state <= M_IDLE;
                        end
                    end
            endcase
        end
    end
endmodule

/* END */
