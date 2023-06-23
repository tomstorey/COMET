        .title "crt0.S for COMET68k bootloader"

        /* A bunch of variables supplied by the linker */
        .extern _stack_end
        .extern _rom_base
        .extern _bss_start
        .extern _bss_end
        .extern _rodata_end
        .extern _data_start
        .extern _data_end
        .weak hardware_init_hook
        .weak software_init_hook
        .extern main

        .section .text
        .align 2

        .type _start, @function
        .globl _start
_start:
        move.w  #0x2700, %sr            /* Mask interrupts, supervisor mode */

        movea.l #_stack_end, %sp        /* Manually configure the SP value,
                                         * this allows the SP value in the ROM
                                         * image to be used e.g. to store a
                                         * checksum instead. */

        /* Initialise (clear) the BSS area */
1:      movea.l #_bss_start, %a0        /* Starting address */
        movea.l #_bss_end, %a1          /* End address */

2:      cmpa.l  %a1, %a0                /* Check if start < end */
        bge     3f

        clr.w   %a0@+                   /* Clear word and increment start */

        bra     2b

        /* Copy initialised data from ROM to RAM */
3:      movea.l #_rodata_end, %a0       /* Source address */
        movea.l #_data_start, %a1       /* Destination start address */
        movea.l #_data_end, %a2         /* Destination end address */

4:      cmpa.l  %a2, %a1                /* Check if start < end */
        bge     5f

        move.w  %a0@+, %a1@+            /* Copy a word from ROM to RAM */

        bra     4b

        /* Execute hardware init hook if present */
5:      move.l  #hardware_init_hook, %d0
        beq     6f
        movea.l %d0, %a0
        jsr     (%a0)

        /* Execute software init hook if present */
6:      move.l  #software_init_hook, %d0
        beq     7f
        movea.l %d0, %a0
        jsr     (%a0)

        /* Jump to main() */
7:      jmp     main

        /* In a bare metal environment, main() should not return as there is
         * nowhere to resume execution from. Behaviour is undefined if this
         * happens! */

/*
 * __DefaultInterrupt handles all interrupt and exception vectors that have not
 * been overridden by the programmer.
 *
 * Unless handled more specifically, all exceptions and interrupts are masked
 * and the CPU stops executing.
 */
        .type __DefaultInterrupt, @function
        .weak __DefaultInterrupt
        .globl __DefaultInterrupt
__DefaultInterrupt:
        stop    #0x2700
        bra     .

        .end
