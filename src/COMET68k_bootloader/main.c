#include <stddef.h>
#include <stdint.h>
#include "TL16C2552.h"

typedef enum {
    STATE_DEFAULT = 0,
    STATE_PING,
    STATE_LOAD_CODE,
    STATE_EXECUTE,
    STATE_JUMP,
    STATE_READ_MEM,
    STATE_WRITE_MEM,
    STATE_READ_BLOCK
} state_machine_state_t;

enum {
    COMMAND_NONE = 0,
    COMMAND_RX_PING,
    COMMAND_TX_PONG,
    COMMAND_RX_LOAD_CODE,
    COMMAND_TX_CODE_LOADED,
    COMMAND_RX_EXECUTE,
    COMMAND_RX_JUMP,
    COMMAND_TX_RUNNING,
    COMMAND_RX_READ_MEM,
    COMMAND_TX_READ_MEM,
    COMMAND_RX_WRITE_MEM,
    COMMAND_TX_WRITE_MEM,
    COMMAND_RX_READ_BLOCK,
    COMMAND_TX_READ_BLOCK
};

void
init_uart(void)
{
    /* Configure UART channel A */
    UALCRbits.WLEN = 3;             /* 8 bits per byte */
    UALCRbits.SLEN = 0;             /* 1 stop bit */
    UALCRbits.PEN = 0;              /* Parity is disabled */

    UALCRbits.DLAB = 1;             /* Access the divisor registers */
    UADLL = 2;                      /* Divide input freq for 230400 baud at
                                     * 7.3728MHz */
    UADLM = 0;
    UALCRbits.DLAB = 0;

    UAFCR = 0x7;                    /* Reset FIFOs and enable tx and rx */
}


uint8_t
uart_get_char(void)
{
    while (UALSRbits.RXD == 0);     /* Wait for a char to be available */

    return UARBR;
}

uint16_t
uart_get_word(void)
{
    uint16_t val = 0;
    uint8_t ctr = 2;                /* Receive 2 bytes for a word */

    for (; ctr; ctr--) {
        while (UALSRbits.RXD == 0); /* Wait for a char to be available */

        val |= UARBR;

        if (ctr > 1) {
            val <<= 8;
        }
    }

    return val;
}

uint32_t
uart_get_long(void)
{
    uint32_t val = 0;
    uint8_t ctr = 4;                /* Receive 4 bytes for a long */

    for (; ctr; ctr--) {
        while (UALSRbits.RXD == 0); /* Wait for a char to be available */

        val |= UARBR;

        if (ctr > 1) {
            val <<= 8;
        }
    }

    return val;
}

void
uart_send_char(uint8_t data)
{
    while (UALSRbits.THRE == 0);    /* Wait for transmit FIFO to be empty. We
                                     * cant easily know how many spaces are
                                     * free, so just wait until its empty. */

    UATHR = data;
}

int
main(void)
{
    init_uart();

    uint32_t data_len = 0;
    uint32_t addr = 0;
    uint8_t *data_ptr;
    uint16_t *data_ptr16;
    uint32_t *data_ptr32;
    uint16_t ctr = 0;
    uint8_t data_type = 0;
    uint16_t word_data;
    uint32_t long_data;

    /* Current command received from the host */
    uint8_t command = COMMAND_NONE;

    /* Current state of the bootloader state machine */
    state_machine_state_t state = STATE_DEFAULT;

    /* Infinite loop for the state machine */
    for (;;) {
        switch (state) {
            case STATE_PING:
                /* The loader script can ping the bootloader to see when it is
                 * ready to accept data */
                uart_send_char((uint8_t)COMMAND_TX_PONG);

                state = STATE_DEFAULT;

                break;

            case STATE_LOAD_CODE:
                /* Loading code
                 *
                 * The first thing to do is get the length of the data that
                 * is being received */
                data_len = uart_get_long();

                /* Next get the address where the data is to be loaded */
                data_ptr = (uint8_t *)uart_get_long();

                /* Now receive further bytes until code_len is decremented to
                 * zero */
                for (; data_len; data_len--, data_ptr++) {
                    *data_ptr = uart_get_char();
                }

                /* Respond with code loaded */
                uart_send_char((uint8_t)COMMAND_TX_CODE_LOADED);

                state = STATE_DEFAULT;

                break;

            case STATE_EXECUTE:
            case STATE_JUMP:
                /* When executing, receive 4 bytes that will form the address
                 * to jump to, then JSR or JMP to that address */
                addr = uart_get_long();

                /* Respond with running */
                uart_send_char((uint8_t)COMMAND_TX_RUNNING);

                /* Wait until transmit shift register is empty to ensure the
                 * host has received the response */
                while (UALSRbits.TXIDL == 0);

                if (state == STATE_EXECUTE) {
                    asm volatile(
                        /* Put addr into A0 then jump to subroutine. Reset
                         * peripherals so user code gets a fresh start. */
                        "movea.l    %[addr], %%a0                   \n\t"
                        "reset                                      \n\t"
                        "jsr        %%a0@                           \n\t"

                        /* If the user code should happen to return, and if
                         * it should happen to work successfully, go back
                         * to default state */
                        :
                        :[addr]"rm"(addr)
                        :
                    );

                    state = STATE_DEFAULT;
                } else {
                    asm volatile(
                        /* Put addr into A0 then jump  */
                        "movea.l    %[addr], %%a0                   \n\t"
                        "jmp        %%a0@                           \n\t"

                        /* User code cannot return from a jump */
                        :
                        :[addr]"rm"(addr)
                        :
                    );
                }

                break;

            case STATE_READ_MEM:
                /* Reading memory
                 *
                 * Memory can be read as byte, word, or long types.
                 * 
                 * The first step is to receive the type that is to be read.
                 * This comes in the form of a single byte specifying the byte
                 * width of the type (1 for byte, 2 for word, 4 for long). */
                data_type = uart_get_char();

                /* Next is a 32 bit value specifying the number of reads of
                 * that type to be performed. */
                data_len = uart_get_long();

                /* Next get the address where the data is to be read from */
                data_ptr = (uint8_t *)uart_get_long();
                data_ptr16 = (uint16_t *)data_ptr;
                data_ptr32 = (uint32_t *)data_ptr;

                /* Respond to say that data will follow */
                uart_send_char((uint8_t)COMMAND_TX_READ_MEM);

                for (; data_len;) {
                    /* Wait for the TX FIFO to empty, then we can queue 16
                     * bytes in one go */
                    while (UALSRbits.THRE == 0);

                    /* Queue bytes until either 16 bytes are queued or data_len
                     * is decremented to zero */
                    if (data_type == 0x01) {
                        ctr = 16;
                    } else if (data_type == 0x02) {
                        ctr = 8;
                    } else if (data_type == 0x04) {
                        ctr = 4;
                    }

                    for (; ctr && data_len; ctr--, data_len--) {
                        if (data_type == 0x01) {
                            UATHR = *data_ptr++;
                        } else if (data_type == 0x02) {
                            word_data = *data_ptr16++;

                            UATHR = (word_data >> 8);
                            UATHR = word_data;
                        } else if (data_type == 0x04) {
                            long_data = *data_ptr32++;

                            UATHR = (long_data >> 24);
                            UATHR = (long_data >> 16);
                            UATHR = (long_data >> 8);
                            UATHR = long_data;
                        }
                        
                    }
                }

                state = STATE_DEFAULT;

                break;

            case STATE_WRITE_MEM:
                /* Writing memory
                 *
                 * Memory can be written as byte, word, or long types.
                 * 
                 * The first step is to receive the type that is to be written.
                 * This comes in the form of a single byte specifying the byte
                 * width of the type (1 for byte, 2 for word, 4 for long). */
                data_type = uart_get_char();

                /* Next is a 32 bit value specifying the number of writes of
                 * that type to be performed. */
                data_len = uart_get_long();

                /* Next get the address where the data is to be loaded */
                data_ptr = (uint8_t *)uart_get_long();
                data_ptr16 = (uint16_t *)data_ptr;
                data_ptr32 = (uint32_t *)data_ptr;

                /* All subsequent data is then the data to be written */
                for (; data_len; data_len--) {
                    if (data_type == 0x01) {
                        *data_ptr++ = uart_get_char();
                    } else if (data_type == 0x02) {
                        *data_ptr16++ = uart_get_word();
                    } else if (data_type == 0x04) {
                        *data_ptr32++ = uart_get_long();
                    }
                }

                /* Respond with data loaded */
                uart_send_char((uint8_t)COMMAND_TX_WRITE_MEM);

                state = STATE_DEFAULT;

                break;

            case STATE_READ_BLOCK:
                /* Reading memory block (i.e. without incrementing the read pointer)
                 *
                 * Memory can be read as byte, word, or long types.
                 * 
                 * The first step is to receive the type that is to be read.
                 * This comes in the form of a single byte specifying the byte
                 * width of the type (1 for byte, 2 for word, 4 for long). */
                data_type = uart_get_char();

                /* Next is a 32 bit value specifying the number of reads of
                 * that type to be performed. */
                data_len = uart_get_long();

                /* Next get the address where the data is to be read from */
                data_ptr = (uint8_t *)uart_get_long();
                data_ptr16 = (uint16_t *)data_ptr;
                data_ptr32 = (uint32_t *)data_ptr;

                /* Respond to say that data will follow */
                uart_send_char((uint8_t)COMMAND_TX_READ_MEM);

                for (; data_len;) {
                    /* Wait for the TX FIFO to empty, then we can queue 16
                     * bytes in one go */
                    while (UALSRbits.THRE == 0);

                    /* Queue bytes until either 16 bytes are queued or data_len
                     * is decremented to zero */
                    if (data_type == 0x01) {
                        ctr = 16;
                    } else if (data_type == 0x02) {
                        ctr = 8;
                    } else if (data_type == 0x04) {
                        ctr = 4;
                    }

                    for (; ctr && data_len; ctr--, data_len--) {
                        if (data_type == 0x01) {
                            UATHR = *data_ptr;
                        } else if (data_type == 0x02) {
                            word_data = *data_ptr16;

                            UATHR = (word_data >> 8);
                            UATHR = word_data;
                        } else if (data_type == 0x04) {
                            long_data = *data_ptr32;

                            UATHR = (long_data >> 24);
                            UATHR = (long_data >> 16);
                            UATHR = (long_data >> 8);
                            UATHR = long_data;
                        }
                        
                    }
                }

                state = STATE_DEFAULT;

                break;

            case STATE_DEFAULT:
            default:
                /* Receive a command */
                command = uart_get_char();

                /* Set the next state machine state based on the command */
                switch (command) {
                    case COMMAND_RX_PING:
                        /* Respond to ping */
                        state = STATE_PING;

                        break;

                    case COMMAND_RX_LOAD_CODE:
                        /* Loading code */
                        state = STATE_LOAD_CODE;

                        break;

                    case COMMAND_RX_EXECUTE:
                        /* Execute (JSR) to an address */
                        state = STATE_EXECUTE;

                        break;

                    case COMMAND_RX_JUMP:
                        /* Execute (JMP) to an address */
                        state = STATE_JUMP;

                        break;

                    case COMMAND_RX_READ_MEM:
                        /* Reading memory */
                        state = STATE_READ_MEM;

                        break;

                    case COMMAND_RX_WRITE_MEM:
                        /* Writing memory */
                        state = STATE_WRITE_MEM;

                        break;

                    case COMMAND_RX_READ_BLOCK:
                        /* Reading memory block (i.e. without incrementing read pointer) */
                        state = STATE_READ_BLOCK;

                        break;

                    default:
                        /* Invalid command */
                        command = COMMAND_NONE;

                        break;
                }

                break;
        }
    }

    return 0;
}
