#ifndef TL16C2552_H
#define TL16C2552_H

#define UART_BASE 0x00C20000        /* Base address of the UART */

#define UART_CHA 0x8                /* A3 high to access ch A regs.
                                     * Ch B is accessed with A3 low. */

#define UART_RBR_REG (0)            /* Receiver Buffer Register (r) */
#define UART_THR_REG (0)            /* Transmitter Holding Register (w) */
#define UART_IER_REG (0x1)          /* Interrupt Enable Register (r/w) */
#define UART_IIR_REG (0x2)          /* Interrupt Ident Register (r) */
#define UART_FCR_REG (0x2)          /* FIFO Control Register (w) */
#define UART_LCR_REG (0x3)          /* Line Control Register (r/w) */
#define UART_MCR_REG (0x4)          /* Modem Control Register (r/w) */
#define UART_LSR_REG (0x5)          /* Line Status Register (r/w) */
#define UART_MSR_REG (0x6)          /* Modem Status Register (r/w) */
#define UART_SCR_REG (0x7)          /* Scratch Register (r/w) */

/* The following 3 registers are only accessible when DLAB (bit 7) of the LCR
 * register is set to 1 */

#define UART_DLL_REG (0)            /* LSB of divisor (r/w) */
#define UART_DLM_REG (0x1)          /* MSB of divisor (r/w) */
#define UART_AFR_REG (0x2)          /* Alternate Function Register (r/w) */

#ifndef __ASSEMBLER__

#include <stdint.h>

/* C stuff not done yet */
#define UARBR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_RBR_REG))
#define UATHR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_THR_REG))
#define UAIER (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_IER_REG))
typedef union {
    struct {
        uint8_t :4;
        uint8_t MSTAT:1;
        uint8_t LSTAT:1;
        uint8_t TXEMPTY:1;
        uint8_t RXDAT:1;
    };
    struct {
        uint8_t u8;
    };
} __UARTIERbits_t;
#define UAIERbits (*(volatile __UARTIERbits_t *)(UART_BASE + UART_CHA + UART_IER_REG))
#define UAIIR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_IIR_REG))
typedef union {
    struct {
        uint8_t FIFOEN1:1;
        uint8_t FIFOEN0:1;
        uint8_t :2;
        uint8_t IPEND3:1;
        uint8_t IPEND2:1;
        uint8_t IPEND1:1;
        uint8_t IPEND0:1;
    };
    struct {
        uint8_t FIFOEN:2;
        uint8_t :2;
        uint8_t IPEND:4;
    };
    struct {
        uint8_t u8;
    };
} __UARTIIRbits_t;
#define UAIIRbits (*(volatile __UARTIIRbits_t *)(UART_BASE + UART_CHA + UART_IIR_REG))
#define UAFCR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_FCR_REG))
typedef union {
    struct {
        uint8_t RXTRG1:1;
        uint8_t RXTRG0:1;
        uint8_t :2;
        uint8_t DMASEL:1;
        uint8_t TXRST:1;
        uint8_t RXRST:1;
        uint8_t EN:1;
    };
    struct {
        uint8_t RXTRG:2;
        uint8_t :6;
    };
    struct {
        uint8_t u8;
    };
} __UARTFCRbits_t;
#define UAFCRbits (*(volatile __UARTFCRbits_t *)(UART_BASE + UART_CHA + UART_FCR_REG))
#define UALCR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_LCR_REG))
typedef union {
    struct {
        uint8_t DLAB:1;
        uint8_t TXBRK:1;
        uint8_t PFORCE:1;
        uint8_t PEVEN:1;
        uint8_t PEN:1;
        uint8_t SLEN:1;
        uint8_t WLEN1:1;
        uint8_t WLEN0:1;
    };
    struct {
        uint8_t :6;
        uint8_t WLEN:2;
    };
    struct {
        uint8_t u8;
    };
} __UARTLCRbits_t;
#define UALCRbits (*(volatile __UARTLCRbits_t *)(UART_BASE + UART_CHA + UART_LCR_REG))
#define UAMCR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_MCR_REG))
typedef union {
    struct {
        uint8_t :2;
        uint8_t AUTOFLOW:1;
        uint8_t LOOP:1;
        uint8_t OP2:1;
        uint8_t OP1:1;
        uint8_t RTSOC:1;
        uint8_t DTROC:1;
    };
    struct {
        uint8_t u8;
    };
} __UARTMCRbits_t;
#define UAMCRbits (*(volatile __UARTMCRbits_t *)(UART_BASE + UART_CHA + UART_MCR_REG))
#define UALSR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_LSR_REG))
typedef union {
    struct {
        uint8_t RXERR:1;
        uint8_t TXIDL:1;
        uint8_t THRE:1;
        uint8_t RXBRK:1;
        uint8_t FERR:1;
        uint8_t PERR:1;
        uint8_t OERR:1;
        uint8_t RXD:1;
    };
    struct {
        uint8_t u8;
    };
} __UARTLSRbits_t;
#define UALSRbits (*(volatile __UARTLSRbits_t *)(UART_BASE + UART_CHA + UART_LSR_REG))
#define UAMSR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_MSR_REG))
typedef union {
    struct {
        uint8_t CDSTAT:1;
        uint8_t RISTAT:1;
        uint8_t DSRSTAT:1;
        uint8_t CTSSTAT:1;
        uint8_t CDCHG:1;
        uint8_t RICHG:1;
        uint8_t DSRCHG:1;
        uint8_t CTSCHG:1;
    };
    struct {
        uint8_t u8;
    };
} __UARTMSRbits_t;
#define UAMSRbits (*(volatile __UARTMSRbits_t *)(UART_BASE + UART_CHA + UART_MSR_REG))
#define UASCR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_SCR_REG))
#define UADLL (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_DLL_REG))
#define UADLM (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_DLM_REG))
#define UAAFR (*(volatile uint8_t *)(UART_BASE + UART_CHA + UART_AFR_REG))
typedef union {
    struct {
        uint8_t :5;
        uint8_t MFSEL1:1;
        uint8_t MFSEL0:1;
        uint8_t BOTH:1;
    };
    struct {
        uint8_t :5;
        uint8_t MFSEL:2;
        uint8_t :1;
    };
    struct {
        uint8_t u8;
    };
} __UARTAFRbits_t;
#define UAAFRbits (*(volatile __UARTAFRbits_t *)(UART_BASE + UART_AFR_REG))

#define UBRBR (*(volatile uint8_t *)(UART_BASE + UART_RBR_REG))
#define UBTHR (*(volatile uint8_t *)(UART_BASE + UART_THR_REG))
#define UBIER (*(volatile uint8_t *)(UART_BASE + UART_IER_REG))
#define UBIERbits (*(volatile __UARTIERbits_t *)(UART_BASE + UART_IER_REG))
#define UBIIR (*(volatile uint8_t *)(UART_BASE + UART_IIR_REG))
#define UBIIRbits (*(volatile __UARTIIRbits_t *)(UART_BASE + UART_IIR_REG))
#define UBFCR (*(volatile uint8_t *)(UART_BASE + UART_FCR_REG))
#define UBFCRbits (*(volatile __UARTFCRbits_t *)(UART_BASE + UART_FCR_REG))
#define UBLCR (*(volatile uint8_t *)(UART_BASE + UART_LCR_REG))
#define UBLCRbits (*(volatile __UARTLCRbits_t *)(UART_BASE + UART_LCR_REG))
#define UBMCR (*(volatile uint8_t *)(UART_BASE + UART_MCR_REG))
#define UBMCRbits (*(volatile __UARTMCRbits_t *)(UART_BASE + UART_MCR_REG))
#define UBLSR (*(volatile uint8_t *)(UART_BASE + UART_LSR_REG))
#define UBLSRbits (*(volatile __UARTLSRbits_t *)(UART_BASE + UART_LSR_REG))
#define UBMSR (*(volatile uint8_t *)(UART_BASE + UART_MSR_REG))
#define UBMSRbits (*(volatile __UARTMSRbits_t *)(UART_BASE + UART_MSR_REG))
#define UBSCR (*(volatile uint8_t *)(UART_BASE + UART_SCR_REG))
#define UBDLL (*(volatile uint8_t *)(UART_BASE + UART_DLL_REG))
#define UBDLM (*(volatile uint8_t *)(UART_BASE + UART_DLM_REG))
#define UBAFR (*(volatile uint8_t *)(UART_BASE + UART_AFR_REG))
#define UBAFRbits (*(volatile __UARTAFRbits_t *)(UART_BASE + UART_AFR_REG))

#else /* __ASSEMBLER__ */

#define UARBR (UART_BASE + UART_CHA + UART_RBR_REG)
#define UATHR (UART_BASE + UART_CHA + UART_THR_REG)
#define UAIER (UART_BASE + UART_CHA + UART_IER_REG)
#define UAIIR (UART_BASE + UART_CHA + UART_IIR_REG)
#define UAFCR (UART_BASE + UART_CHA + UART_FCR_REG)
#define UALCR (UART_BASE + UART_CHA + UART_LCR_REG)
#define UAMCR (UART_BASE + UART_CHA + UART_MCR_REG)
#define UALSR (UART_BASE + UART_CHA + UART_LSR_REG)
#define UAMSR (UART_BASE + UART_CHA + UART_MSR_REG)
#define UASCR (UART_BASE + UART_CHA + UART_SCR_REG)
#define UADLL (UART_BASE + UART_CHA + UART_DLL_REG)
#define UADLM (UART_BASE + UART_CHA + UART_DLM_REG)
#define UAAFR (UART_BASE + UART_CHA + UART_AFR_REG)

#define UBRBR (UART_BASE + UART_RBR_REG)
#define UBTHR (UART_BASE + UART_THR_REG)
#define UBIER (UART_BASE + UART_IER_REG)
#define UBIIR (UART_BASE + UART_IIR_REG)
#define UBFCR (UART_BASE + UART_FCR_REG)
#define UBLCR (UART_BASE + UART_LCR_REG)
#define UBMCR (UART_BASE + UART_MCR_REG)
#define UBLSR (UART_BASE + UART_LSR_REG)
#define UBMSR (UART_BASE + UART_MSR_REG)
#define UBSCR (UART_BASE + UART_SCR_REG)
#define UBDLL (UART_BASE + UART_DLL_REG)
#define UBDLM (UART_BASE + UART_DLM_REG)
#define UBAFR (UART_BASE + UART_AFR_REG)

#endif /* __ASSEMBLER__ */

#define _UAIER_MSTAT_POSITION          0x00000003
#define _UAIER_MSTAT_MASK              0x00000001
#define _UAIER_MSTAT_LENGTH            0x00000001

#define _UAIER_LSTAT_POSITION          0x00000002
#define _UAIER_LSTAT_MASK              0x00000001
#define _UAIER_LSTAT_LENGTH            0x00000001

#define _UAIER_TXEMPTY_POSITION        0x00000001
#define _UAIER_TXEMPTY_MASK            0x00000001
#define _UAIER_TXEMPTY_LENGTH          0x00000001

#define _UAIER_RXDAT_POSITION          0x00000000
#define _UAIER_RXDAT_MASK              0x00000001
#define _UAIER_RXDAT_LENGTH            0x00000001

#define _UBIER_MSTAT_POSITION          0x00000003
#define _UBIER_MSTAT_MASK              0x00000001
#define _UBIER_MSTAT_LENGTH            0x00000001

#define _UBIER_LSTAT_POSITION          0x00000002
#define _UBIER_LSTAT_MASK              0x00000001
#define _UBIER_LSTAT_LENGTH            0x00000001

#define _UBIER_TXEMPTY_POSITION        0x00000001
#define _UBIER_TXEMPTY_MASK            0x00000001
#define _UBIER_TXEMPTY_LENGTH          0x00000001

#define _UBIER_RXDAT_POSITION          0x00000000
#define _UBIER_RXDAT_MASK              0x00000001
#define _UBIER_RXDAT_LENGTH            0x00000001

#define _UAIIR_FIFOEN1_POSITION        0x00000007
#define _UAIIR_FIFOEN1_MASK            0x00000001
#define _UAIIR_FIFOEN1_LENGTH          0x00000001

#define _UAIIR_FIFOEN0_POSITION        0x00000006
#define _UAIIR_FIFOEN0_MASK            0x00000001
#define _UAIIR_FIFOEN0_LENGTH          0x00000001

#define _UAIIR_FIFOEN_POSITION         0x00000006
#define _UAIIR_FIFOEN_MASK             0x00000003
#define _UAIIR_FIFOEN_LENGTH           0x00000002

#define _UAIIR_IPEND3_POSITION         0x00000003
#define _UAIIR_IPEND3_MASK             0x00000001
#define _UAIIR_IPEND3_LENGTH           0x00000001

#define _UAIIR_IPEND2_POSITION         0x00000002
#define _UAIIR_IPEND2_MASK             0x00000001
#define _UAIIR_IPEND2_LENGTH           0x00000001

#define _UAIIR_IPEND1_POSITION         0x00000001
#define _UAIIR_IPEND1_MASK             0x00000001
#define _UAIIR_IPEND1_LENGTH           0x00000001

#define _UAIIR_IPEND0_POSITION         0x00000000
#define _UAIIR_IPEND0_MASK             0x00000001
#define _UAIIR_IPEND0_LENGTH           0x00000001

#define _UAIIR_IPEND_POSITION          0x00000000
#define _UAIIR_IPEND_MASK              0x0000000F
#define _UAIIR_IPEND_LENGTH            0x00000004

#define _UBIIR_FIFOEN1_POSITION        0x00000007
#define _UBIIR_FIFOEN1_MASK            0x00000001
#define _UBIIR_FIFOEN1_LENGTH          0x00000001

#define _UBIIR_FIFOEN0_POSITION        0x00000006
#define _UBIIR_FIFOEN0_MASK            0x00000001
#define _UBIIR_FIFOEN0_LENGTH          0x00000001

#define _UBIIR_FIFOEN_POSITION         0x00000006
#define _UBIIR_FIFOEN_MASK             0x00000003
#define _UBIIR_FIFOEN_LENGTH           0x00000002

#define _UBIIR_IPEND3_POSITION         0x00000003
#define _UBIIR_IPEND3_MASK             0x00000001
#define _UBIIR_IPEND3_LENGTH           0x00000001

#define _UBIIR_IPEND2_POSITION         0x00000002
#define _UBIIR_IPEND2_MASK             0x00000001
#define _UBIIR_IPEND2_LENGTH           0x00000001

#define _UBIIR_IPEND1_POSITION         0x00000001
#define _UBIIR_IPEND1_MASK             0x00000001
#define _UBIIR_IPEND1_LENGTH           0x00000001

#define _UBIIR_IPEND0_POSITION         0x00000000
#define _UBIIR_IPEND0_MASK             0x00000001
#define _UBIIR_IPEND0_LENGTH           0x00000001

#define _UBIIR_IPEND_POSITION          0x00000000
#define _UBIIR_IPEND_MASK              0x0000000F
#define _UBIIR_IPEND_LENGTH            0x00000004

#define _UAFCR_RXTRG1_POSITION         0x00000007
#define _UAFCR_RXTRG1_MASK             0x00000001
#define _UAFCR_RXTRG1_LENGTH           0x00000001

#define _UAFCR_RXTRG0_POSITION         0x00000006
#define _UAFCR_RXTRG0_MASK             0x00000001
#define _UAFCR_RXTRG0_LENGTH           0x00000001

#define _UAFCR_RXTRG_POSITION          0x00000006
#define _UAFCR_RXTRG_MASK              0x00000003
#define _UAFCR_RXTRG_LENGTH            0x00000002

#define _UAFCR_DMASEL_POSITION         0x00000003
#define _UAFCR_DMASEL_MASK             0x00000001
#define _UAFCR_DMASEL_LENGTH           0x00000001

#define _UAFCR_TXRST_POSITION          0x00000002
#define _UAFCR_TXRST_MASK              0x00000001
#define _UAFCR_TXRST_LENGTH            0x00000001

#define _UAFCR_RXRST_POSITION          0x00000001
#define _UAFCR_RXRST_MASK              0x00000001
#define _UAFCR_RXRST_LENGTH            0x00000001

#define _UAFCR_EN_POSITION             0x00000000
#define _UAFCR_EN_MASK                 0x00000001
#define _UAFCR_EN_LENGTH               0x00000001

#define _UBFCR_RXTRG1_POSITION         0x00000007
#define _UBFCR_RXTRG1_MASK             0x00000001
#define _UBFCR_RXTRG1_LENGTH           0x00000001

#define _UBFCR_RXTRG0_POSITION         0x00000006
#define _UBFCR_RXTRG0_MASK             0x00000001
#define _UBFCR_RXTRG0_LENGTH           0x00000001

#define _UBFCR_RXTRG_POSITION          0x00000006
#define _UBFCR_RXTRG_MASK              0x00000003
#define _UBFCR_RXTRG_LENGTH            0x00000002

#define _UBFCR_DMASEL_POSITION         0x00000003
#define _UBFCR_DMASEL_MASK             0x00000001
#define _UBFCR_DMASEL_LENGTH           0x00000001

#define _UBFCR_TXRST_POSITION          0x00000002
#define _UBFCR_TXRST_MASK              0x00000001
#define _UBFCR_TXRST_LENGTH            0x00000001

#define _UBFCR_RXRST_POSITION          0x00000001
#define _UBFCR_RXRST_MASK              0x00000001
#define _UBFCR_RXRST_LENGTH            0x00000001

#define _UBFCR_EN_POSITION             0x00000000
#define _UBFCR_EN_MASK                 0x00000001
#define _UBFCR_EN_LENGTH               0x00000001

#define _UALCR_DLAB_POSITION           0x00000007
#define _UALCR_DLAB_MASK               0x00000001
#define _UALCR_DLAB_LENGTH             0x00000001

#define _UALCR_TXBRK_POSITION          0x00000006
#define _UALCR_TXBRK_MASK              0x00000001
#define _UALCR_TXBRK_LENGTH            0x00000001

#define _UALCR_PFORCE_POSITION         0x00000005
#define _UALCR_PFORCE_MASK             0x00000001
#define _UALCR_PFORCE_LENGTH           0x00000001

#define _UALCR_PEVEN_POSITION          0x00000004
#define _UALCR_PEVEN_MASK              0x00000001
#define _UALCR_PEVEN_LENGTH            0x00000001

#define _UALCR_PEN_POSITION            0x00000003
#define _UALCR_PEN_MASK                0x00000001
#define _UALCR_PEN_LENGTH              0x00000001

#define _UALCR_SLEN_POSITION           0x00000002
#define _UALCR_SLEN_MASK               0x00000001
#define _UALCR_SLEN_LENGTH             0x00000001

#define _UALCR_WLEN1_POSITION          0x00000001
#define _UALCR_WLEN1_MASK              0x00000001
#define _UALCR_WLEN1_LENGTH            0x00000001

#define _UALCR_WLEN0_POSITION          0x00000000
#define _UALCR_WLEN0_MASK              0x00000001
#define _UALCR_WLEN0_LENGTH            0x00000001

#define _UALCR_WLEN_POSITION           0x00000000
#define _UALCR_WLEN_MASK               0x00000003
#define _UALCR_WLEN_LENGTH             0x00000002

#define _UBLCR_DLAB_POSITION           0x00000007
#define _UBLCR_DLAB_MASK               0x00000001
#define _UBLCR_DLAB_LENGTH             0x00000001

#define _UBLCR_TXBRK_POSITION          0x00000006
#define _UBLCR_TXBRK_MASK              0x00000001
#define _UBLCR_TXBRK_LENGTH            0x00000001

#define _UBLCR_PFORCE_POSITION         0x00000005
#define _UBLCR_PFORCE_MASK             0x00000001
#define _UBLCR_PFORCE_LENGTH           0x00000001

#define _UBLCR_PEVEN_POSITION          0x00000004
#define _UBLCR_PEVEN_MASK              0x00000001
#define _UBLCR_PEVEN_LENGTH            0x00000001

#define _UBLCR_PEN_POSITION            0x00000003
#define _UBLCR_PEN_MASK                0x00000001
#define _UBLCR_PEN_LENGTH              0x00000001

#define _UBLCR_SLEN_POSITION           0x00000002
#define _UBLCR_SLEN_MASK               0x00000001
#define _UBLCR_SLEN_LENGTH             0x00000001

#define _UBLCR_WLEN1_POSITION          0x00000001
#define _UBLCR_WLEN1_MASK              0x00000001
#define _UBLCR_WLEN1_LENGTH            0x00000001

#define _UBLCR_WLEN0_POSITION          0x00000000
#define _UBLCR_WLEN0_MASK              0x00000001
#define _UBLCR_WLEN0_LENGTH            0x00000001

#define _UBLCR_WLEN_POSITION           0x00000000
#define _UBLCR_WLEN_MASK               0x00000003
#define _UBLCR_WLEN_LENGTH             0x00000002

#define _UAMCR_AUTOFLOW_POSITION       0x00000005
#define _UAMCR_AUTOFLOW_MASK           0x00000001
#define _UAMCR_AUTOFLOW_LENGTH         0x00000001

#define _UAMCR_LOOP_POSITION           0x00000004
#define _UAMCR_LOOP_MASK               0x00000001
#define _UAMCR_LOOP_LENGTH             0x00000001

#define _UAMCR_OP2_POSITION            0x00000003
#define _UAMCR_OP2_MASK                0x00000001
#define _UAMCR_OP2_LENGTH              0x00000001

#define _UAMCR_OP1_POSITION            0x00000002
#define _UAMCR_OP1_MASK                0x00000001
#define _UAMCR_OP1_LENGTH              0x00000001

#define _UAMCR_RTSOC_POSITION          0x00000001
#define _UAMCR_RTSOC_MASK              0x00000001
#define _UAMCR_RTSOC_LENGTH            0x00000001

#define _UAMCR_DTROC_POSITION          0x00000000
#define _UAMCR_DTROC_MASK              0x00000001
#define _UAMCR_DTROC_LENGTH            0x00000001

#define _UBMCR_AUTOFLOW_POSITION       0x00000005
#define _UBMCR_AUTOFLOW_MASK           0x00000001
#define _UBMCR_AUTOFLOW_LENGTH         0x00000001

#define _UBMCR_LOOP_POSITION           0x00000004
#define _UBMCR_LOOP_MASK               0x00000001
#define _UBMCR_LOOP_LENGTH             0x00000001

#define _UBMCR_OP2_POSITION            0x00000003
#define _UBMCR_OP2_MASK                0x00000001
#define _UBMCR_OP2_LENGTH              0x00000001

#define _UBMCR_OP1_POSITION            0x00000002
#define _UBMCR_OP1_MASK                0x00000001
#define _UBMCR_OP1_LENGTH              0x00000001

#define _UBMCR_RTSOC_POSITION          0x00000001
#define _UBMCR_RTSOC_MASK              0x00000001
#define _UBMCR_RTSOC_LENGTH            0x00000001

#define _UBMCR_DTROC_POSITION          0x00000000
#define _UBMCR_DTROC_MASK              0x00000001
#define _UBMCR_DTROC_LENGTH            0x00000001

#define _UALSR_RXERR_POSITION          0x00000007
#define _UALSR_RXERR_MASK              0x00000001
#define _UALSR_RXERR_LENGTH            0x00000001

#define _UALSR_TXIDL_POSITION          0x00000006
#define _UALSR_TXIDL_MASK              0x00000001
#define _UALSR_TXIDL_LENGTH            0x00000001

#define _UALSR_THRE_POSITION           0x00000005
#define _UALSR_THRE_MASK               0x00000001
#define _UALSR_THRE_LENGTH             0x00000001

#define _UALSR_RXBRK_POSITION          0x00000004
#define _UALSR_RXBRK_MASK              0x00000001
#define _UALSR_RXBRK_LENGTH            0x00000001

#define _UALSR_FERR_POSITION           0x00000003
#define _UALSR_FERR_MASK               0x00000001
#define _UALSR_FERR_LENGTH             0x00000001

#define _UALSR_PERR_POSITION           0x00000002
#define _UALSR_PERR_MASK               0x00000001
#define _UALSR_PERR_LENGTH             0x00000001

#define _UALSR_OERR_POSITION           0x00000001
#define _UALSR_OERR_MASK               0x00000001
#define _UALSR_OERR_LENGTH             0x00000001

#define _UALSR_RXD_POSITION            0x00000000
#define _UALSR_RXD_MASK                0x00000001
#define _UALSR_RXD_LENGTH              0x00000001

#define _UBLSR_RXERR_POSITION          0x00000007
#define _UBLSR_RXERR_MASK              0x00000001
#define _UBLSR_RXERR_LENGTH            0x00000001

#define _UBLSR_TXIDL_POSITION          0x00000006
#define _UBLSR_TXIDL_MASK              0x00000001
#define _UBLSR_TXIDL_LENGTH            0x00000001

#define _UBLSR_THRE_POSITION           0x00000005
#define _UBLSR_THRE_MASK               0x00000001
#define _UBLSR_THRE_LENGTH             0x00000001

#define _UBLSR_RXBRK_POSITION          0x00000004
#define _UBLSR_RXBRK_MASK              0x00000001
#define _UBLSR_RXBRK_LENGTH            0x00000001

#define _UBLSR_FERR_POSITION           0x00000003
#define _UBLSR_FERR_MASK               0x00000001
#define _UBLSR_FERR_LENGTH             0x00000001

#define _UBLSR_PERR_POSITION           0x00000002
#define _UBLSR_PERR_MASK               0x00000001
#define _UBLSR_PERR_LENGTH             0x00000001

#define _UBLSR_OERR_POSITION           0x00000001
#define _UBLSR_OERR_MASK               0x00000001
#define _UBLSR_OERR_LENGTH             0x00000001

#define _UBLSR_RXD_POSITION            0x00000000
#define _UBLSR_RXD_MASK                0x00000001
#define _UBLSR_RXD_LENGTH              0x00000001

#define _UAMSR_CDSTAT_POSITION         0x00000007
#define _UAMSR_CDSTAT_MASK             0x00000001
#define _UAMSR_CDSTAT_LENGTH           0x00000001

#define _UAMSR_RISTAT_POSITION         0x00000006
#define _UAMSR_RISTAT_MASK             0x00000001
#define _UAMSR_RISTAT_LENGTH           0x00000001

#define _UAMSR_DSRSTAT_POSITION        0x00000005
#define _UAMSR_DSRSTAT_MASK            0x00000001
#define _UAMSR_DSRSTAT_LENGTH          0x00000001

#define _UAMSR_CTSSTAT_POSITION        0x00000004
#define _UAMSR_CTSSTAT_MASK            0x00000001
#define _UAMSR_CTSSTAT_LENGTH          0x00000001

#define _UAMSR_CDCHG_POSITION          0x00000003
#define _UAMSR_CDCHG_MASK              0x00000001
#define _UAMSR_CDCHG_LENGTH            0x00000001

#define _UAMSR_RICHG_POSITION          0x00000002
#define _UAMSR_RICHG_MASK              0x00000001
#define _UAMSR_RICHG_LENGTH            0x00000001

#define _UAMSR_DSRCHG_POSITION         0x00000001
#define _UAMSR_DSRCHG_MASK             0x00000001
#define _UAMSR_DSRCHG_LENGTH           0x00000001

#define _UAMSR_CTSCHG_POSITION         0x00000000
#define _UAMSR_CTSCHG_MASK             0x00000001
#define _UAMSR_CTSCHG_LENGTH           0x00000001

#define _UBMSR_CDSTAT_POSITION         0x00000007
#define _UBMSR_CDSTAT_MASK             0x00000001
#define _UBMSR_CDSTAT_LENGTH           0x00000001

#define _UBMSR_RISTAT_POSITION         0x00000006
#define _UBMSR_RISTAT_MASK             0x00000001
#define _UBMSR_RISTAT_LENGTH           0x00000001

#define _UBMSR_DSRSTAT_POSITION        0x00000005
#define _UBMSR_DSRSTAT_MASK            0x00000001
#define _UBMSR_DSRSTAT_LENGTH          0x00000001

#define _UBMSR_CTSSTAT_POSITION        0x00000004
#define _UBMSR_CTSSTAT_MASK            0x00000001
#define _UBMSR_CTSSTAT_LENGTH          0x00000001

#define _UBMSR_CDCHG_POSITION          0x00000003
#define _UBMSR_CDCHG_MASK              0x00000001
#define _UBMSR_CDCHG_LENGTH            0x00000001

#define _UBMSR_RICHG_POSITION          0x00000002
#define _UBMSR_RICHG_MASK              0x00000001
#define _UBMSR_RICHG_LENGTH            0x00000001

#define _UBMSR_DSRCHG_POSITION         0x00000001
#define _UBMSR_DSRCHG_MASK             0x00000001
#define _UBMSR_DSRCHG_LENGTH           0x00000001

#define _UBMSR_CTSCHG_POSITION         0x00000000
#define _UBMSR_CTSCHG_MASK             0x00000001
#define _UBMSR_CTSCHG_LENGTH           0x00000001

#define _UAAFR_MFSEL1_POSITION         0x00000002
#define _UAAFR_MFSEL1_MASK             0x00000001
#define _UAAFR_MFSEL1_LENGTH           0x00000001

#define _UAAFR_MFSEL0_POSITION         0x00000001
#define _UAAFR_MFSEL0_MASK             0x00000001
#define _UAAFR_MFSEL0_LENGTH           0x00000001

#define _UAAFR_MFSEL_POSITION          0x00000001
#define _UAAFR_MFSEL_MASK              0x00000003
#define _UAAFR_MFSEL_LENGTH            0x00000002

#define _UAAFR_BOTH_POSITION           0x00000000
#define _UAAFR_BOTH_MASK               0x00000001
#define _UAAFR_BOTH_LENGTH             0x00000001

#define _UBAFR_MFSEL1_POSITION         0x00000002
#define _UBAFR_MFSEL1_MASK             0x00000001
#define _UBAFR_MFSEL1_LENGTH           0x00000001

#define _UBAFR_MFSEL0_POSITION         0x00000001
#define _UBAFR_MFSEL0_MASK             0x00000001
#define _UBAFR_MFSEL0_LENGTH           0x00000001

#define _UBAFR_MFSEL_POSITION          0x00000001
#define _UBAFR_MFSEL_MASK              0x00000003
#define _UBAFR_MFSEL_LENGTH            0x00000002

#define _UBAFR_BOTH_POSITION           0x00000000
#define _UBAFR_BOTH_MASK               0x00000001
#define _UBAFR_BOTH_LENGTH             0x00000001

#endif /* TL16C2552_H */
