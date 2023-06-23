#ifndef TL16C2552_H
#define TL16C2552_H

#define _UART_BASE 0x00C20000                   /* Base address for UART peripheral */
#define UART_CHA 0x8
#define UART_CHB 0
#define UART_RBR_REG 0
#define UART_THR_REG 0
#define UART_IER_REG 0x1
#define UART_IIR_REG 0x2
#define UART_FCR_REG 0x2
#define UART_LCR_REG 0x3
#define UART_MCR_REG 0x4
#define UART_LSR_REG 0x5
#define UART_MSR_REG 0x6
#define UART_SCR_REG 0x7
#define UART_DLL_REG 0
#define UART_DLM_REG 0x1
#define UART_AFR_REG 0x2

#ifndef __ASSEMBLY__
#include <stdint.h>

#define UART_REG(ch, reg) (*(volatile uint8_t *)(_UART_BASE + ch + reg))

#define UIERA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_IER_REG))
#define UIERB (*(volatile uint8_t *)(_UART_BASE + UART_IER_REG))
typedef union {
    struct {
        uint8_t :4;
        uint8_t EDSSI:1;
        uint8_t ELSI:1;
        uint8_t ETBEI:1;
        uint8_t ERBI:1;
    };
    struct {
        uint8_t u8;
    };
} __UIERbits_t;
#define UIERAbits (*(volatile __UIERbits_t *)(_UART_BASE + UART_CHA + UART_IER_REG))
#define UIERBbits (*(volatile __UIERbits_t *)(_UART_BASE + UART_IER_REG))

#define UIIRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_IIR_REG))
#define UIIRB (*(volatile uint8_t *)(_UART_BASE + UART_IIR_REG))
typedef union {
    struct {
        uint8_t FIFO1:1;
        uint8_t FIFO0:1;
        uint8_t :2;
        uint8_t IID3:1;
        uint8_t IID2:1;
        uint8_t IID1:1;
        uint8_t IID0:1;
    };
    struct {
        uint8_t FIFO:2;
        uint8_t :2;
        uint8_t IID:4;
    };
    struct {
        uint8_t u8;
    };
} __UIIRbits_t;
#define UIIRAbits (*(volatile __UIIRbits_t *)(_UART_BASE + UART_CHA + UART_IIR_REG))
#define UIIRBbits (*(volatile __UIIRbits_t *)(_UART_BASE + UART_IIR_REG))

#define UFCRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_FCR_REG))
#define UFCRB (*(volatile uint8_t *)(_UART_BASE + UART_FCR_REG))
typedef union {
    struct {
        uint8_t RXTRG1:1;
        uint8_t RXTRG0:1;
        uint8_t :2;
        uint8_t DMAMS:1;
        uint8_t TXFIFOR:1;
        uint8_t RXFIFOR:1;
        uint8_t FIFOEN:1;
    };
    struct {
        uint8_t RXTRG:2;
        uint8_t :6;
    };
    struct {
        uint8_t u8;
    };
} __UFCRbits_t;
#define UFCRAbits (*(volatile __UFCRbits_t *)(_UART_BASE + UART_CHA + UART_FCR_REG))
#define UFCRBbits (*(volatile __UFCRbits_t *)(_UART_BASE + UART_FCR_REG))

#define ULCRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_LCR_REG))
#define ULCRB (*(volatile uint8_t *)(_UART_BASE + UART_LCR_REG))
typedef union {
    struct {
        uint8_t DLAB:1;
        uint8_t BRK:1;
        uint8_t STP:1;
        uint8_t EPS:1;
        uint8_t PEN:1;
        uint8_t STB:1;
        uint8_t WLS1:1;
        uint8_t WLS0:1;
    };
    struct {
        uint8_t :6;
        uint8_t WLS:2;
    };
    struct {
        uint8_t u8;
    };
} __ULCRbits_t;
#define ULCRAbits (*(volatile __ULCRbits_t *)(_UART_BASE + UART_CHA + UART_LCR_REG))
#define ULCRBbits (*(volatile __ULCRbits_t *)(_UART_BASE + UART_LCR_REG))

#define UMCRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_MCR_REG))
#define UMCRB (*(volatile uint8_t *)(_UART_BASE + UART_MCR_REG))
typedef union {
    struct {
        uint8_t :2;
        uint8_t AFE:1;
        uint8_t LOOP:1;
        uint8_t INTE:1;
        uint8_t OUT1:1;
        uint8_t RTS:1;
        uint8_t DTR:1;
    };
    struct {
        uint8_t :4;
        uint8_t OUT2:1;
        uint8_t :3;
    };
    struct {
        uint8_t u8;
    };
} __UMCRbits_t;
#define UMCRAbits (*(volatile __UMCRbits_t *)(_UART_BASE + UART_CHA + UART_MCR_REG))
#define UMCRBbits (*(volatile __UMCRbits_t *)(_UART_BASE + UART_MCR_REG))

#define ULSRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_LSR_REG))
#define ULSRB (*(volatile uint8_t *)(_UART_BASE + UART_LSR_REG))
typedef union {
    struct {
        uint8_t RXERR:1;
        uint8_t TEMT:1;
        uint8_t THRE:1;
        uint8_t BI:1;
        uint8_t FE:1;
        uint8_t PE:1;
        uint8_t OE:1;
        uint8_t DR:1;
    };
    struct {
        uint8_t u8;
    };
} __ULSRbits_t;
#define ULSRAbits (*(volatile __ULSRbits_t *)(_UART_BASE + UART_CHA + UART_LSR_REG))
#define ULSRBbits (*(volatile __ULSRbits_t *)(_UART_BASE + UART_LSR_REG))

#define UMSRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_MSR_REG))
#define UMSRB (*(volatile uint8_t *)(_UART_BASE + UART_MSR_REG))
typedef union {
    struct {
        uint8_t DCD:1;
        uint8_t RI:1;
        uint8_t DSR:1;
        uint8_t CTS:1;
        uint8_t DDCD:1;
        uint8_t TERI:1;
        uint8_t DDSR:1;
        uint8_t DCTS:1;
    };
    struct {
        uint8_t u8;
    };
} __UMSRbits_t;
#define UMSRAbits (*(volatile __UMSRbits_t *)(_UART_BASE + UART_CHA + UART_MSR_REG))
#define UMSRBbits (*(volatile __UMSRbits_t *)(_UART_BASE + UART_MSR_REG))

#define UAFRA (*(volatile uint8_t *)(_UART_BASE + UART_CHA + UART_AFR_REG))
#define UAFRB (*(volatile uint8_t *)(_UART_BASE + UART_AFR_REG))
typedef union {
    struct {
        uint8_t :5;
        uint8_t XRDY:1;
        uint8_t BAUDOUT:1;
        uint8_t CONC:1;
    };
    struct {
        uint8_t u8;
    };
} __UAFRbits_t;
#define UAFRAbits (*(volatile __UAFRbits_t *)(_UART_BASE + UART_CHA + UART_AFR_REG))
#define UAFRBbits (*(volatile __UAFRbits_t *)(_UART_BASE + UART_AFR_REG))

#else /* __ASSEMBLY__ */
#endif /* __ASSEMBLY__ */

#define _UIER_EDSSI_POSITION                               0x00000003
#define _UIER_EDSSI_MASK                                   0x00000008
#define _UIER_EDSSI_LENGTH                                 0x00000001

#define _UIER_ELSI_POSITION                                0x00000002
#define _UIER_ELSI_MASK                                    0x00000004
#define _UIER_ELSI_LENGTH                                  0x00000001

#define _UIER_ETBEI_POSITION                               0x00000001
#define _UIER_ETBEI_MASK                                   0x00000002
#define _UIER_ETBEI_LENGTH                                 0x00000001

#define _UIER_ERBI_POSITION                                0x00000000
#define _UIER_ERBI_MASK                                    0x00000001
#define _UIER_ERBI_LENGTH                                  0x00000001

#define _UIIR_FIFO1_POSITION                               0x00000007
#define _UIIR_FIFO1_MASK                                   0x00000080
#define _UIIR_FIFO1_LENGTH                                 0x00000001

#define _UIIR_FIFO0_POSITION                               0x00000006
#define _UIIR_FIFO0_MASK                                   0x00000040
#define _UIIR_FIFO0_LENGTH                                 0x00000001

#define _UIIR_FIFO_POSITION                                0x00000006
#define _UIIR_FIFO_MASK                                    0x000000C0
#define _UIIR_FIFO_LENGTH                                  0x00000002

#define _UIIR_IID3_POSITION                                0x00000003
#define _UIIR_IID3_MASK                                    0x00000008
#define _UIIR_IID3_LENGTH                                  0x00000001

#define _UIIR_IID2_POSITION                                0x00000002
#define _UIIR_IID2_MASK                                    0x00000004
#define _UIIR_IID2_LENGTH                                  0x00000001

#define _UIIR_IID1_POSITION                                0x00000001
#define _UIIR_IID1_MASK                                    0x00000002
#define _UIIR_IID1_LENGTH                                  0x00000001

#define _UIIR_IID0_POSITION                                0x00000000
#define _UIIR_IID0_MASK                                    0x00000001
#define _UIIR_IID0_LENGTH                                  0x00000001

#define _UIIR_IID_POSITION                                 0x00000000
#define _UIIR_IID_MASK                                     0x0000000F
#define _UIIR_IID_LENGTH                                   0x00000004

#define _UFCR_RXTRG1_POSITION                              0x00000007
#define _UFCR_RXTRG1_MASK                                  0x00000080
#define _UFCR_RXTRG1_LENGTH                                0x00000001

#define _UFCR_RXTRG0_POSITION                              0x00000006
#define _UFCR_RXTRG0_MASK                                  0x00000040
#define _UFCR_RXTRG0_LENGTH                                0x00000001

#define _UFCR_RXTRG_POSITION                               0x00000006
#define _UFCR_RXTRG_MASK                                   0x000000C0
#define _UFCR_RXTRG_LENGTH                                 0x00000002

#define _UFCR_DMAMS_POSITION                               0x00000003
#define _UFCR_DMAMS_MASK                                   0x00000008
#define _UFCR_DMAMS_LENGTH                                 0x00000001

#define _UFCR_TXFIFOR_POSITION                             0x00000002
#define _UFCR_TXFIFOR_MASK                                 0x00000004
#define _UFCR_TXFIFOR_LENGTH                               0x00000001

#define _UFCR_RXFIFOR_POSITION                             0x00000001
#define _UFCR_RXFIFOR_MASK                                 0x00000002
#define _UFCR_RXFIFOR_LENGTH                               0x00000001

#define _UFCR_FIFOEN_POSITION                              0x00000000
#define _UFCR_FIFOEN_MASK                                  0x00000001
#define _UFCR_FIFOEN_LENGTH                                0x00000001

#define _ULCR_DLAB_POSITION                                0x00000007
#define _ULCR_DLAB_MASK                                    0x00000080
#define _ULCR_DLAB_LENGTH                                  0x00000001

#define _ULCR_BRK_POSITION                                 0x00000006
#define _ULCR_BRK_MASK                                     0x00000040
#define _ULCR_BRK_LENGTH                                   0x00000001

#define _ULCR_STP_POSITION                                 0x00000005
#define _ULCR_STP_MASK                                     0x00000020
#define _ULCR_STP_LENGTH                                   0x00000001

#define _ULCR_EPS_POSITION                                 0x00000004
#define _ULCR_EPS_MASK                                     0x00000010
#define _ULCR_EPS_LENGTH                                   0x00000001

#define _ULCR_PEN_POSITION                                 0x00000003
#define _ULCR_PEN_MASK                                     0x00000008
#define _ULCR_PEN_LENGTH                                   0x00000001

#define _ULCR_STB_POSITION                                 0x00000002
#define _ULCR_STB_MASK                                     0x00000004
#define _ULCR_STB_LENGTH                                   0x00000001

#define _ULCR_WLS1_POSITION                                0x00000001
#define _ULCR_WLS1_MASK                                    0x00000002
#define _ULCR_WLS1_LENGTH                                  0x00000001

#define _ULCR_WLS0_POSITION                                0x00000000
#define _ULCR_WLS0_MASK                                    0x00000001
#define _ULCR_WLS0_LENGTH                                  0x00000001

#define _ULCR_WLS_POSITION                                 0x00000000
#define _ULCR_WLS_MASK                                     0x00000003
#define _ULCR_WLS_LENGTH                                   0x00000002

#define _UMCR_AFE_POSITION                                 0x00000005
#define _UMCR_AFE_MASK                                     0x00000020
#define _UMCR_AFE_LENGTH                                   0x00000001

#define _UMCR_LOOP_POSITION                                0x00000004
#define _UMCR_LOOP_MASK                                    0x00000010
#define _UMCR_LOOP_LENGTH                                  0x00000001

#define _UMCR_INTE_POSITION                                0x00000003
#define _UMCR_INTE_MASK                                    0x00000008
#define _UMCR_INTE_LENGTH                                  0x00000001

#define _UMCR_OUT2_POSITION                                0x00000003
#define _UMCR_OUT2_MASK                                    0x00000008
#define _UMCR_OUT2_LENGTH                                  0x00000001

#define _UMCR_OUT1_POSITION                                0x00000002
#define _UMCR_OUT1_MASK                                    0x00000004
#define _UMCR_OUT1_LENGTH                                  0x00000001

#define _UMCR_RTS_POSITION                                 0x00000001
#define _UMCR_RTS_MASK                                     0x00000002
#define _UMCR_RTS_LENGTH                                   0x00000001

#define _UMCR_DTR_POSITION                                 0x00000000
#define _UMCR_DTR_MASK                                     0x00000001
#define _UMCR_DTR_LENGTH                                   0x00000001

#define _ULSR_RXERR_POSITION                               0x00000007
#define _ULSR_RXERR_MASK                                   0x00000080
#define _ULSR_RXERR_LENGTH                                 0x00000001

#define _ULSR_TEMT_POSITION                                0x00000006
#define _ULSR_TEMT_MASK                                    0x00000040
#define _ULSR_TEMT_LENGTH                                  0x00000001

#define _ULSR_THRE_POSITION                                0x00000005
#define _ULSR_THRE_MASK                                    0x00000020
#define _ULSR_THRE_LENGTH                                  0x00000001

#define _ULSR_BI_POSITION                                  0x00000004
#define _ULSR_BI_MASK                                      0x00000010
#define _ULSR_BI_LENGTH                                    0x00000001

#define _ULSR_FE_POSITION                                  0x00000003
#define _ULSR_FE_MASK                                      0x00000008
#define _ULSR_FE_LENGTH                                    0x00000001

#define _ULSR_PE_POSITION                                  0x00000002
#define _ULSR_PE_MASK                                      0x00000004
#define _ULSR_PE_LENGTH                                    0x00000001

#define _ULSR_OE_POSITION                                  0x00000001
#define _ULSR_OE_MASK                                      0x00000002
#define _ULSR_OE_LENGTH                                    0x00000001

#define _ULSR_DR_POSITION                                  0x00000000
#define _ULSR_DR_MASK                                      0x00000001
#define _ULSR_DR_LENGTH                                    0x00000001

#define _UMSR_DCD_POSITION                                 0x00000007
#define _UMSR_DCD_MASK                                     0x00000080
#define _UMSR_DCD_LENGTH                                   0x00000001

#define _UMSR_RI_POSITION                                  0x00000006
#define _UMSR_RI_MASK                                      0x00000040
#define _UMSR_RI_LENGTH                                    0x00000001

#define _UMSR_DSR_POSITION                                 0x00000005
#define _UMSR_DSR_MASK                                     0x00000020
#define _UMSR_DSR_LENGTH                                   0x00000001

#define _UMSR_CTS_POSITION                                 0x00000004
#define _UMSR_CTS_MASK                                     0x00000010
#define _UMSR_CTS_LENGTH                                   0x00000001

#define _UMSR_DDCD_POSITION                                0x00000003
#define _UMSR_DDCD_MASK                                    0x00000008
#define _UMSR_DDCD_LENGTH                                  0x00000001

#define _UMSR_TERI_POSITION                                0x00000002
#define _UMSR_TERI_MASK                                    0x00000004
#define _UMSR_TERI_LENGTH                                  0x00000001

#define _UMSR_DDSR_POSITION                                0x00000001
#define _UMSR_DDSR_MASK                                    0x00000002
#define _UMSR_DDSR_LENGTH                                  0x00000001

#define _UMSR_DCTS_POSITION                                0x00000000
#define _UMSR_DCTS_MASK                                    0x00000001
#define _UMSR_DCTS_LENGTH                                  0x00000001

#define _UAFR_XRDY_POSITION                                0x00000002
#define _UAFR_XRDY_MASK                                    0x00000004
#define _UAFR_XRDY_LENGTH                                  0x00000001

#define _UAFR_BAUDOUT_POSITION                             0x00000001
#define _UAFR_BAUDOUT_MASK                                 0x00000002
#define _UAFR_BAUDOUT_LENGTH                               0x00000001

#define _UAFR_CONC_POSITION                                0x00000000
#define _UAFR_CONC_MASK                                    0x00000001
#define _UAFR_CONC_LENGTH                                  0x00000001

#endif /* TL16C2552_H */
