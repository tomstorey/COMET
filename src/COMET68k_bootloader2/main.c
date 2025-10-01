#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "TL16C2552.h"

/* The number of bytes to be transferred as part of a flash program chunk. Must be sync'd with PC side script!
 * Be mindful of the stack size... */
#define FLASH_PROGRAM_CHUNK 256

enum command {
    COMMAND_NONE = 0,
    COMMAND_PING = 1,
    COMMAND_PEEK = 2,
    COMMAND_POKE = 3,
    COMMAND_BOOT = 4,
    COMMAND_JMP = 5,
    COMMAND_JSR = 6,
    COMMAND_FLASH_ID = 7,
    COMMAND_FLASH_CHIP_ERASE = 8,
    COMMAND_FLASH_PROGRAM = 9
};

enum response {
    RESPONSE_NONE = 0,
    RESPONSE_ACK = 1,
    RESPONSE_NAK = 2
};

struct flags {
    union {
        struct {
            uint8_t :5;
            uint8_t SIXTEEN:1;
            uint8_t BLOCK:1;
            uint8_t ALT:1;
        };
        struct {
            uint8_t u8;
        };
    };
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

/* Monitors the status register of a flash memory configured to operate in 16-bit bus mode, using the toggle bit method
 * to check for success or failure of an operation
 *
 * Inputs
 *      cmd                 A pointer to an address at which flash memory commands can be executed
 *      compare_address     A pointer to an address at which data will be compared
 *      compare_data        The data that should be compared with compare_address
 *
 * For a data comparison check to be made, compare_address should be a non-NULL value.
 *
 * Returns
 *      bool                true if the operation completes successfully, and if the compare data matches,
 *                          otherwise false
 *
 * Side effects
 *      If the operation being executed aborts due to an error, the flash memory is returned to the reading mode
 */
bool
flash_16bit_toggle_bit(void *cmd, void *compare_address, const uint16_t compare_data)
{
    for (;;) {
        uint16_t sr1 = *(volatile uint16_t*)cmd;
        uint16_t sr2 = *(volatile uint16_t*)cmd;

        if ((sr1 & 0x0040) ^ (sr2 & 0x0040)) {
            /* DQ6 is toggling, the operation is in progress */

            if (sr2 & 0x0020) {
                /* DQ5 is set, the operation may have failed - check again if DQ6 is toggling (it could just be that the
                 * programmed data sets DQ5...) */
                sr1 = *(volatile uint16_t*)cmd;
                sr2 = *(volatile uint16_t*)cmd;

                if ((sr1 & 0x0040) ^ (sr2 & 0x0040)) {
                    /* DQ6 is still toggling, operation has failed. Execute READ/RESET command to return to reading
                     * mode. */
                    *(volatile uint16_t *)cmd = 0x00F0;

                    return false;
                } else {
                    /* DQ6 is not toggling, operation succeeded */
                    break;
                }

            }
        } else {
            /* DQ6 is not toggling, operation succeeded */
            break;
        }
    }

    /* If the compare address is not NULL, check the value to verify the data */
    if (compare_address != NULL) {
        if (*(uint16_t *)compare_address != compare_data) {
            return false;
        }
    }

    /* If we get this far, everything checks out */
    return true;
}

/* Monitors the status register of a flash memory configured to operate in 8-bit bus mode, using the toggle bit method
 * to check for success or failure of an operation
 *
 * Inputs
 *      cmd                 A pointer to an address at which flash memory commands can be executed
 *      compare_address     A pointer to an address at which data will be compared
 *      compare_data        The data that should be compared with compare_address
 *
 * For a data comparison check to be made, compare_address should be a non-NULL value.
 *
 * Returns
 *      bool                true if the operation completes successfully, and if the compare data matches,
 *                          otherwise false
 *
 * Side effects
 *      If the operation being executed aborts due to an error, the flash memory is returned to the reading mode
 */
bool
flash_8bit_toggle_bit(void *cmd, void *compare_address, const uint8_t compare_data)
{
    for (;;) {
        uint8_t sr1 = *(volatile uint8_t*)cmd;
        uint8_t sr2 = *(volatile uint8_t*)cmd;

        if ((sr1 & 0x40) ^ (sr2 & 0x40)) {
            /* DQ6 is toggling, the operation is in progress */

            if (sr2 & 0x20) {
                /* DQ5 is set, the operation may have failed - check again if DQ6 is toggling (it could just be that the
                 * programmed data sets DQ5...) */
                sr1 = *(volatile uint8_t*)cmd;
                sr2 = *(volatile uint8_t*)cmd;

                if ((sr1 & 0x40) ^ (sr2 & 0x40)) {
                    /* DQ6 is still toggling, operation has failed. Execute READ/RESET command to return to reading
                     * mode. */
                    *(volatile uint8_t *)cmd = 0xF0;

                    return false;
                } else {
                    /* DQ6 is not toggling, operation succeeded */
                    break;
                }

            }
        } else {
            /* DQ6 is not toggling, operation succeeded */
            break;
        }
    }

    /* If the compare address is not NULL, check the value to verify the data */
    if (compare_address != NULL) {
        if (*(uint8_t *)compare_address != compare_data) {
            return false;
        }
    }

    /* If we get this far, everything checks out */
    return true;
}

void
flash_id(const struct flags flags, void *address)
{
    uint32_t offset1 = 0xAAA;
    uint32_t offset2 = 0x555;
    volatile uint8_t *cmd8 = NULL;
    volatile uint16_t *cmd16 = NULL;

    if (flags.ALT || flags.SIXTEEN) {
        /* 8-bit flash memories on even or odd addresses, and 16-bit flash memories do not have the CPUs A0 signal
         * connected to them, therefore we drop the LSb of offset 2 to make it look like 2AA left shifted by 1 */
        offset2 &= 0xFFE;
    }

    if (flags.ALT || !flags.SIXTEEN) {
        /* Set up a pointer to an 8-bit flash memory for the purposes of executing commands, keeping the LSb to
         * differentiate between even and odd devices */
        cmd8 = (volatile uint8_t *)((uint32_t)address & 0xFFFFF001);
    } else {
        /* Otherwise the pointer is setup for a 16-bit flash memory without keeping the LSb */
        cmd16 = (volatile uint16_t *)((uint32_t)address & 0xFFFFF000);

        /* Offsets need to be adjusted for 16-bit pointer */
        offset1 >>= 1;
        offset2 >>= 1;
    }

    if (flags.SIXTEEN) {
        /* Identify a flash memory that operates in 16-bit bus mode */

        /* Execute AUTO SELECT command */
        *(cmd16 + offset1) = 0x00AA;
        *(cmd16 + offset2) = 0x0055;
        *(cmd16 + offset1) = 0x0090;

        /* Read the electronic signature */
        UATHR = *cmd16;              /* Manufacturer ID */
        UATHR = *(cmd16 + 1);        /* Device ID */

        /* Execute READ/RESET command to return to reading mode */
        *cmd16 = 0x00F0;
    } else {
        /* Identify a flash memory that operates in 8-bit bus mode */

        /* Execute AUTO SELECT command */
        *(cmd8 + offset1) = 0xAA;
        *(cmd8 + offset2) = 0x55;
        *(cmd8 + offset1) = 0x90;

        /* Read the electronic signature and send it back to the host */
        UATHR = *cmd8;               /* Manufacturer ID */

        if (flags.ALT) {
            /* Skip an additional address for memories on even or odd addresses */
            UATHR = *(cmd8 + 2);     /* Device ID */
        } else {
            /* Otherwise, read the next address for 8-bit flash memories in a linear address space */
            UATHR = *(cmd8 + 1);     /* Device ID */
        }

        /* Execute READ/RESET command to return to reading mode */
        *cmd8 = 0xF0;
    }
}

void
flash_chip_erase(const struct flags flags, void *address)
{
    uint32_t offset1 = 0xAAA;
    uint32_t offset2 = 0x555;
    volatile uint8_t *cmd8 = NULL;
    volatile uint16_t *cmd16 = NULL;

    if (flags.ALT || flags.SIXTEEN) {
        /* 8-bit flash memories on even or odd addresses, and 16-bit flash memories do not have the CPUs A0 signal
         * connected to them, therefore we drop the LSb of offset 2 to make it look like 2AA left shifted by 1 */
        offset2 &= 0xFFE;
    }

    if (flags.ALT || !flags.SIXTEEN) {
        /* Set up a pointer to an 8-bit flash memory for the purposes of executing commands, keeping the LSb to
         * differentiate between even and odd devices */
        cmd8 = (volatile uint8_t *)((uint32_t)address & 0xFFFFF001);
    } else {
        /* Otherwise the pointer is setup for a 16-bit flash memory without keeping the LSb */
        cmd16 = (volatile uint16_t *)((uint32_t)address & 0xFFFFF000);

        /* Offsets need to be adjusted for 16-bit pointer */
        offset1 >>= 1;
        offset2 >>= 1;
    }

    if (flags.SIXTEEN) {
        /* Erase a flash memory that operates in 16-bit bus mode */

        /* Execute CHIP ERASE command */
        *(cmd16 + offset1) = 0x00AA;
        *(cmd16 + offset2) = 0x0055;
        *(cmd16 + offset1) = 0x0080;
        *(cmd16 + offset1) = 0x00AA;
        *(cmd16 + offset2) = 0x0055;
        *(cmd16 + offset1) = 0x0010;

        /* Monitor the operation until the end using the Toggle Bit method */
        if (flash_16bit_toggle_bit((void *)cmd16, (void *)cmd16, 0xFFFF) == true) {
            /* Operation succeeded */
            uart_send_char(RESPONSE_ACK);
        } else {
            /* Operation failed */
            uart_send_char(RESPONSE_NAK);
        }
    } else {
        /* Erase a flash memory that operates in 8-bit bus mode */

        /* Execute CHIP ERASE command */
        *(cmd8 + offset1) = 0xAA;
        *(cmd8 + offset2) = 0x55;
        *(cmd8 + offset1) = 0x80;
        *(cmd8 + offset1) = 0xAA;
        *(cmd8 + offset2) = 0x55;
        *(cmd8 + offset1) = 0x10;

        /* Monitor the operation until the end using the Toggle Bit method */
        if (flash_8bit_toggle_bit((void *)cmd8, (void *)cmd8, 0xFF) == true) {
            /* Operation succeeded */
            uart_send_char(RESPONSE_ACK);
        } else {
            /* Operation failed */
            uart_send_char(RESPONSE_NAK);
        }
    }
}

void
flash_program(const struct flags flags, void *address, uint32_t length)
{
    uint32_t offset1 = 0xAAA;
    uint32_t offset2 = 0x555;
    volatile uint8_t *addr8 = NULL;
    volatile uint16_t *addr16 = NULL;
    volatile uint8_t *cmd8 = NULL;
    volatile uint16_t *cmd16 = NULL;
    uint8_t buf[FLASH_PROGRAM_CHUNK];
    uint32_t counter;
    uint32_t i;

    if (flags.ALT || flags.SIXTEEN) {
        /* 8-bit flash memories on even or odd addresses, and 16-bit flash memories do not have the CPUs A0 signal
         * connected to them, therefore we drop the LSb of offset 2 to make it look like 2AA left shifted by 1 */
        offset2 &= 0xFFE;
    }

    if (flags.ALT || !flags.SIXTEEN) {
        /* Set up a pointer to an 8-bit flash memory for the purposes of executing commands, keeping the LSb to
         * differentiate between even and odd devices */
        addr8 = (volatile uint8_t *)address;
        cmd8 = (volatile uint8_t *)((uint32_t)address & 0xFFFFF001);
    } else {
        /* Otherwise the pointer is setup for a 16-bit flash memory without keeping the LSb */
        addr16 = (volatile uint16_t *)((uint32_t)address & 0xFFFFFFFE);
        cmd16 = (volatile uint16_t *)((uint32_t)address & 0xFFFFF000);

        /* Offsets need to be adjusted for 16-bit pointer */
        offset1 >>= 1;
        offset2 >>= 1;
    }

    while (length > 0) {
        /* How many bytes to receive? */
        if (length > FLASH_PROGRAM_CHUNK) {
            counter = FLASH_PROGRAM_CHUNK;
        } else {
            counter = length;
        }

        /* Receive that many bytes into buffer */
        for (i = 0; i < counter; i++) {
            buf[i] = uart_get_char();
        }

        if (flags.SIXTEEN) {
            /* Program a flash memory that operates in 16-bit bus mode */
            for (i = 0; i < counter; i += 2) {
                /* Execute PROGRAM command */
                *(cmd16 + offset1) = 0x00AA;
                *(cmd16 + offset2) = 0x0055;
                *(cmd16 + offset1) = 0x00A0;

                const uint16_t data = buf[i] << 8 | buf[i + 1];

                // *(volatile uint16_t *)address = data;
                *addr16 = data;

                /* Monitor the operation until the end using the Toggle Bit method */
                if (flash_16bit_toggle_bit((void *)cmd16, address, data) == false) {
                    /* Program operation failed */
                    uart_send_char(RESPONSE_NAK);

                    /* TODO: Send failed address */

                    return;
                }

                /* Increment to next address */
                // address += 2;
                addr16++;
            }
        } else {
            /* Program a flash memory that operates in 8-bit bus mode */
            for (i = 0; i < counter; i++) {
                /* Execute PROGRAM command */
                *(cmd8 + offset1) = 0xAA;
                *(cmd8 + offset2) = 0x55;
                *(cmd8 + offset1) = 0xA0;

                // *(volatile uint8_t *)address = buf[i];
                *addr8 = buf[i];

                /* Monitor the operation until the end using the Toggle Bit method */
                if (flash_8bit_toggle_bit((void *)cmd8, address, buf[i]) == false) {
                    /* Program operation failed */
                    uart_send_char(RESPONSE_NAK);

                    /* TODO: Send failed address */

                    return;
                }

                /* Increment to next address */
                // address++;
                addr8++;
            }
        }

        /* Adjust how much data is left to receive */
        length -= counter;

        /* Programming of this chunk of 16 bytes succeeded, send ACK to receive next chunk */
        uart_send_char(RESPONSE_ACK);
    }
}

int __attribute__((noreturn))
main(void)
{
    init_uart();

    /* The current command being executed by the state machine */
    enum command cmd = COMMAND_NONE;

    /* Packet fields */
    static struct flags flags = {0};
    uint8_t data_type = 0;
    void *address = NULL;
    volatile uint8_t *addr8 = NULL;
    volatile uint16_t *addr16 = NULL;
    volatile uint32_t *addr32 = NULL;
    uint32_t length = 0;

    /* Holds data that has been read or is to be written */
    uint32_t data = 0;

    /* A counter */
    uint32_t ctr = 0;

    /* Infinite loop for the state machine */
    for (;;)
    {
        switch (cmd) {
            case COMMAND_PING:
                /* The loader script can "ping" the bootloader to test its availability. All we have to do is return an
                 * ACK to let it know we are alive. */
                uart_send_char(RESPONSE_ACK);

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_PEEK:
                /* Peek at memory. The format of the packet is:
                 *
                 * FF SS AAAAAAAA LLLLLLLL
                 *
                 * FF are the flags
                 *      .... ...A   alternate byte reads
                 *      .... ..B.   block access (non-incrementing pointer)
                 * SS is the size of the bus cycle/data type: 1=byte, 2=word, 4=long
                 * AAAAAAAA is the starting address
                 * LLLLLLLL is the length of the data to read in bytes
                 */

                /* Receive the various fields */
                flags.u8 = uart_get_char();
                data_type = uart_get_char();
                address = (void *)uart_get_long();
                length = uart_get_long();

                /* Assign pointers */
                addr8 = (uint8_t *)address;
                addr16 = (uint16_t *)address;
                addr32 = (uint32_t *)address;

                /* Respond with ACK to indicate that data is following */
                uart_send_char(RESPONSE_ACK);

                /* Read the data */
                while (length) {
                    /* Wait for TX FIFO to be empty */
                    while (UALSRbits.THRE == 0) {};

                    /* Queue bytes until either 16 bytes are queued or length is decremented to zero */
                    if (data_type == 1) {
                        ctr = 16;
                    } else if (data_type == 2) {
                        ctr = 8;
                    } else if (data_type == 4) {
                        ctr = 4;
                    }

                    for (; ctr && length; ctr--) {
                        if (data_type == 1) {
                            UATHR = *addr8;

                            length--;

                            if (flags.ALT) {
                                addr8 += 2;
                            } else {
                                if (!flags.BLOCK) {
                                    addr8++;
                                }
                            }
                        } else if (data_type == 2) {
                            data = *addr16;

                            UATHR = data >> 8;
                            UATHR = data;

                            length -= 2;

                            if (!flags.BLOCK) {
                                addr16++;
                            }
                        } else if (data_type == 4) {
                            data = *addr32;

                            UATHR = data >> 24;
                            UATHR = data >> 16;
                            UATHR = data >> 8;
                            UATHR = data;

                            length -= 4;

                            if (!flags.BLOCK) {
                                addr32++;
                            }
                        }
                    }
                }

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_POKE:
                /* Poke at memory. The format of the packet is:
                 *
                 * FF SS AAAAAAAA LLLLLLLL ...
                 *
                 * FF are the flags
                 *      .... ...A   alternate byte reads
                 *      .... ..B.   block access (non-incrementing pointer)
                 * SS is the size of the bus cycle/data type: 1=byte, 2=word, 4=long
                 * AAAAAAAA is the starting address
                 * LLLLLLLL is the length of the data to write in bytes
                 *
                 * The data to be written then follows.
                 */

                /* Receive the various fields */
                flags.u8 = uart_get_char();
                data_type = uart_get_char();
                address = (void *)uart_get_long();
                length = uart_get_long();

                /* Assign pointers */
                addr8 = (uint8_t *)address;
                addr16 = (uint16_t *)address;
                addr32 = (uint32_t *)address;

                while (length) {
                    if (data_type == 1) {
                        *addr8 = uart_get_char();

                        length--;

                        if (flags.ALT) {
                            addr8 += 2;
                        } else {
                            if (!flags.BLOCK) {
                                addr8++;
                            }
                        }
                    } else if (data_type == 2) {
                        *addr16 = uart_get_word();

                        length -= 2;

                        if (!flags.BLOCK) {
                            addr16++;
                        }
                    } else if (data_type == 4) {
                        *addr32 = uart_get_long();

                        length -= 4;

                        if (!flags.BLOCK) {
                            addr32++;
                        }
                    }
                }

                /* Respond with ACK to indicate that data has been received */
                uart_send_char(RESPONSE_ACK);

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_BOOT:
            case COMMAND_JMP:
            case COMMAND_JSR:
                /* Instructs the bootloader to perform a JMP, JSR, or simulated boot to a specified address. The format
                 * of the packet is:
                 *
                 * AAAAAAAA
                 *
                 * AAAAAAAA is the address to transfer execution to
                 */

                /* Receive the various fields */
                address = (void *)uart_get_long();

                /* Respond with ACK to indicate that execution will be transferred */
                uart_send_char(RESPONSE_ACK);

                /* Wait until transmit shift register is empty to ensure the host has received the response */
                while (UALSRbits.TXIDL == 0);

                if (cmd == COMMAND_BOOT) {
                    /* COMMAND_BOOT takes the first two LONGs at the specified address and loads the first into the
                     * stack pointer, then jumps to the address in the second, emulating a CPU booting up.
                     */
                    asm volatile(
                        /* Put the first long into SP  */
                        "movea.l    %[address], %%a0                \n\t"
                        "movea.l    %%a0@+, %%sp                    \n\t"

                        /* Move the second long into A0 and then JMP to it */
                        "movea.l    %%a0@, %%a0                     \n\t"
                        "jmp        %%a0@                           \n\t"

                        /* User code cannot return from a JMP... */

                        :
                        :[address]"rm"(address)
                        :
                    );
                } else if (cmd == COMMAND_JMP) {
                    asm volatile(
                        /* Put address into A0 then JMP  */
                        "movea.l    %[address], %%a0                \n\t"
                        "jmp        %%a0@                           \n\t"

                        /* User code cannot return from a JMP... */

                        :
                        :[address]"rm"(address)
                        :
                    );
                } else {
                    asm volatile(
                        /* Put address into A0 then JSR */
                        "movea.l    %[address], %%a0                \n\t"
                        "jsr        %%a0@                           \n\t"

                        /* User code can in theory return from a JSR and return into the bootloader. As long as the
                         * bootloader memory/stack has not been clobbered ... */

                        :
                        :[address]"rm"(address)
                        :
                    );
                }

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_FLASH_ID:
                /* Identifies a flash memory device at a given address using the AUTO SELECT command method.
                 *
                 * The format of the packet is:
                 *
                 * FF AAAAAAAA
                 *
                 * FF are the flags
                 *      .... ...A   even/odd mode
                 *      .... .S..   16-bit interface mode
                 * AAAAAAAA is an address within the address space of the flash memory to identify
                 *
                 * Two bytes are returned, the first being the manufacturer ID and the second the device ID.
                 */

                /* Receive the various fields */
                flags.u8 = uart_get_char();
                address = (void *)uart_get_long();

                /* Respond with ACK to indicate that data is following */
                uart_send_char(RESPONSE_ACK);

                /* Execute the operation */
                flash_id(flags, address);

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_FLASH_CHIP_ERASE:
                /* Performs a full chip erase of a flash memory device at a given address.
                 *
                 * The format of the packet is:
                 *
                 * FF AAAAAAAA
                 *
                 * FF are the flags
                 *      .... ...A   even/odd mode
                 *      .... .S..   16-bit interface mode
                 * AAAAAAAA is an address within the address space of the flash memory to erase
                 *
                 * An initiak ACK is returned to indicate that the process has begun, and a follow up ACK or NAK is
                 * returned to indicate success or failure of the erase operation.
                 */

                /* Receive the various fields */
                flags.u8 = uart_get_char();
                address = (void *)uart_get_long();

                /* Respond with ACK to indicate that the process is beginning */
                uart_send_char(RESPONSE_ACK);

                /* Execute the operation */
                flash_chip_erase(flags, address);

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_FLASH_PROGRAM:
                /* Programs data into a flash memory device at a given address.
                 *
                 * The format of the initial packet is:
                 *
                 * FF AAAAAAAA LLLLLLLL DD[16]
                 *
                 * FF are the flags
                 *      .... ...A   even/odd mode
                 *      .... .S..   16-bit interface mode
                 * AAAAAAAA is an address within the address space of the flash memory to program
                 * LLLLLLLL is the total length of the data to write in bytes
                 * DD is upto 16 initial bytes of data to program
                 *
                 * Where the length of the data to program is 16 bytes or less, no further packets will be sent. If the
                 * length of the data is greater than 16 bytes, the data continues to follow in 16 byte chunks until all
                 * data has been transferred and programmed. At the successful completion of programming a 16 byte
                 * chunk, an ACK is sent to the host. If programming fails a NAK is sent, followed by the address at
                 * which programming failed.
                 */

                /* Receive the various fields */
                flags.u8 = uart_get_char();
                address = (void *)uart_get_long();
                length = uart_get_long();

                /* Execute the operation by transferring control to start receiving data to be programmed */
                flash_program(flags, address, length);

                /* Return and wait for another command */
                cmd = COMMAND_NONE;

                break;

            case COMMAND_NONE:
                /* Receive a command */
                cmd = (enum command)uart_get_char();

                break;

            default:
                /* Respond with NAK to indicate that the command has not been accepted */
                uart_send_char(RESPONSE_NAK);

                /* Return and wait for another command */
                cmd = COMMAND_NONE;
        }
    }
}
