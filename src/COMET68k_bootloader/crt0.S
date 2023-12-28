        .title "crt0.S for m68k bare metal"

/* Uncomment the following define if remapping RAM to start at addr 0 */
/* #define ROMRAM_REMAP */

/* Along with the ROMRAM_REMAP define, uncomment the following define if you
 * are using a 68010 CPU. Rather than copying the exception vector table into
 * RAM, the VBR register will be adjusted instead. */
/* #define MC68010 */

        /* A bunch of variables supplied by the linker */
        .extern __rom_base
        .extern __ram_base
        .extern _bss_start
        .extern _bss_end
        .extern _rodata_end
        .extern _data_start
        .extern _data_end
        .extern main

        .section .text
        .align 2

        .type _start, @function
        .globl _start
_start:
        move.w  #0x2700, %sr            /* Ensure interrupts are "disabled" */

        move.w  #1000, %d0              /* DRAM start-up delay */
0:      dbf     %d0, 0b

#ifdef MC68010
        /* Whether or not ROM/RAM remapping is being performed, if using a
         * 68010 CPU, configure the VBR to point to the beginning of ROM */
        movea.l #__rom_base, %a0
        movec   %a0, %vbr
#else /* MC68010 */
#ifdef ROMRAM_REMAP
        /* For non 68010 CPU, if ROM/RAM remapping is being used, copy the
         * exception vector table to RAM */
        move.w  #511, %d0               /* Number of words to copy, less 1 for
                                         * dbf loop */
        movea.l #__rom_base, %a0        /* Source address */
        movea.l #0, %a1                 /* Destination address */

1:      move.w  %a0@+, %a1@+
        dbf     %d0, 1b
#endif /* ROMRAM_REMAP */
#endif /* MC68010 */

        /* Initialise (clear) the BSS area */
        movea.l #_bss_start, %a0        /* Starting address */
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

        /* Jump to main() */
5:      jmp     main

        /* If main() happens to return, behaviour is undefined - dont return
         * from main() !!! */

/*
 * __DefaultInterrupt handles all interrupt and exception vectors that have not
 * been overridden by the programmer.
 *
 * Unless handled more specifically, all exceptions and interrupts are masked
 * and the handler busy loops.
 */
    .type __DefaultInterrupt, @function
    .weak __DefaultInterrupt
    .globl __DefaultInterrupt
__DefaultInterrupt:
    ori.w   #0x0700, %sr
    bra     .

#if 0
    .globl BusError
BusError:
    bra     .

    .globl AddressError
AddressError:
    bra     .

    .globl IllegalInstruction
IllegalInstruction:
    bra     .

    .globl ZeroDivide
ZeroDivide:
    bra     .

    .globl CHKInstruction
CHKInstruction:
    bra     .

    .globl TRAPVInstruction
TRAPVInstruction:
    bra     .

    .globl PrivilegeViolation
PrivilegeViolation:
    bra     .

    .globl Trace
Trace:
    bra     .

    .globl Line1010Emulator
Line1010Emulator:
    bra     .

    .globl Line1111Emulator
Line1111Emulator:
    bra     .

    .globl FormatError
FormatError:
    bra     .

    .globl SpuriousInterrupt
SpuriousInterrupt:
    bra     .

    .globl IRQ1
IRQ1:
    bra     .

    .globl IRQ2
IRQ2:
    bra     .

    .globl IRQ3
IRQ3:
    bra     .

    .globl IRQ4
IRQ4:
    bra     .

    .globl IRQ5
IRQ5:
    bra     .

    .globl IRQ6
IRQ6:
    bra     .

    .globl IRQ7
IRQ7:
    bra     .

    .globl TRAP0
TRAP0:
    bra     .

    .globl TRAP1
TRAP1:
    bra     .

    .globl TRAP2
TRAP2:
    bra     .

    .globl TRAP3
TRAP3:
    bra     .

    .globl TRAP4
TRAP4:
    bra     .

    .globl TRAP5
TRAP5:
    bra     .

    .globl TRAP6
TRAP6:
    bra     .

    .globl TRAP7
TRAP7:
    bra     .

    .globl TRAP8
TRAP8:
    bra     .

    .globl TRAP9
TRAP9:
    bra     .

    .globl TRAP10
TRAP10:
    bra     .

    .globl TRAP11
TRAP11:
    bra     .

    .globl TRAP12
TRAP12:
    bra     .

    .globl TRAP13
TRAP13:
    bra     .

    .globl TRAP14
TRAP14:
    bra     .

    .globl TRAP15
TRAP15:
    bra     .
#endif /* 0 */

    .end
