#ifndef COMET68K_H
#define COMET68K_H

/**************************************************************************************************
 *                                                                                                *
 *                               PLATFORM HEADER FILE FOR COMET68k                                *
 *                                                                                                *
 **************************************************************************************************/

#define _COMET_PERIPH_BASE 0x00C00000           /* Base address for all on-board peripherals */
#define _COMET_IO_BASE (_COMET_PERIPH_BASE + 0x00010000)
#define _COMET_UART_BASE (_COMET_PERIPH_BASE + 0x00020000)
#define _COMET_TIMER_BASE (_COMET_PERIPH_BASE + 0x00030000)
#define _COMET_ETH_BASE (_COMET_PERIPH_BASE + 0x00040000)

#ifndef __ASSEMBLY__
#include <stdint.h>

/* Watchdog timer macros
 *
 * The board features a watchdog timer, implemented by the MAX705 supervisor.
 *
 * Due to the way the MAX705 operates, the watchdog timeout period if not definable, and is fixed at
 * a period of approximately 1.6 seconds.
 *
 * The watchdog function is disabled on reset, whether caused by software, hardware, or watchdog
 * timeout.
 *
 * To enable the watchdog function, the WDTEN() macro is called. This sets a flip flop which makes
 * the WDI input of the MAX705 low impedance, and enables its watchdog function. From this moment
 * 1.6 seconds are available before the watchdog timer must be cleared.
 *
 * To reset the watchdog timer and prevent a reset, the WDTCLR() macro is called. From this moment
 * 1.6 seconds are available before the watchdog timer must be cleared again.
 *
 * The watchdog function is disabled by calling the WDTDIS() macro. From this moment, no further
 * WDTCLR()'s are required.
 *
 * If a watchdog reset occurrs, the WDTO bit within the CSR2 is set, and software may use this bit
 * along with the POR bit of the CSR2 to determine the cause of a reset. */
#define WDTEN() { COMETCSR2 |= _COMETCSR2_WDT_EN_MASK; }
#define WDTDIS() { COMETCSR2 &= ~_COMETCSR2_WDT_EN_MASK; }
#define WDTCLR() { (void)(*(volatile uint8_t *)(_COMET_IO_BASE + 0x2)); }

/* Software reset macros
 *
 * To perform a software reset, the software reset function must first be armed with the SOFTRSTEN()
 * macro. This sets a flip flop to unmask the preset input to a second flip flop which is toggled
 * through the use of the SOFTRESET() macro.
 *
 * The state of these flip flops is restored to their negated states on reset, whether software or
 * hardware induced.
 *
 * No status bits are set as a result of a software reset, but through the use of the POR and WDTO
 * bits of the CSR2, software may determine the cause of a reset. */
#define SOFTRESETEN() { COMETCSR2 |= _COMETCSR2_SOFT_RST_EN_MASK; }
#define SOFTRESET() { (void)(*(volatile uint8_t *)(_COMET_IO_BASE + 0x3)); }

#define COMETCSR1 (*(volatile uint8_t *)(_COMET_IO_BASE))
typedef union {
    struct {
        uint8_t CPLD_FUNC1:1;
        uint8_t SPK_GATE:1;
        uint8_t ETH_LI:1;
        uint8_t ETH_LPBK:1;
        uint8_t LED_D:1;
        uint8_t LED_C:1;
        uint8_t LED_B:1;
        uint8_t LED_A:1;
    };
    struct {
        uint8_t u8;
    };
} __COMETCSR1bits_t;
#define COMETCSR1bits (*(volatile __COMETCSR1bits_t *)(_COMET_IO_BASE));

#define COMETCSR2 (*(volatile uint8_t *)(_COMET_IO_BASE + 0x1))
typedef union {
    struct {
        uint8_t POR:1;
        uint8_t WDTO:1;
        uint8_t SOFT_RST_EN:1;
        uint8_t WDT_EN:1;
        uint8_t CONFIG3:1;
        uint8_t CONFIG2:1;
        uint8_t CONFIG1:1;
        uint8_t CONFIG0:1;
    };
    struct {
        uint8_t :4;
        uint8_t CONFIG:4;
    };
    struct {
        uint8_t u8;
    };
} __COMETCSR2bits_t;
#define COMETCSR2bits (*(volatile __COMETCSR2bits_t *)(_COMET_IO_BASE + 0x1));

#else /* __ASSEMBLY__ */

#define COMETCSR1 (_COMET_IO_BASE)
#define COMETCSR2 (_COMET_IO_BASE + 0x1)

#endif /* __ASSEMBLY__ */

#define _COMETCSR1_CPLD_FUNC1_POSITION                     0x00000007
#define _COMETCSR1_CPLD_FUNC1_MASK                         0x00000080
#define _COMETCSR1_CPLD_FUNC1_LENGTH                       0x00000001

#define _COMETCSR1_SPK_GATE_POSITION                       0x00000006
#define _COMETCSR1_SPK_GATE_MASK                           0x00000040
#define _COMETCSR1_SPK_GATE_LENGTH                         0x00000001

#define _COMETCSR1_ETH_LI_POSITION                         0x00000005
#define _COMETCSR1_ETH_LI_MASK                             0x00000020
#define _COMETCSR1_ETH_LI_LENGTH                           0x00000001

#define _COMETCSR1_ETH_LPBK_POSITION                       0x00000004
#define _COMETCSR1_ETH_LPBK_MASK                           0x00000010
#define _COMETCSR1_ETH_LPBK_LENGTH                         0x00000001

#define _COMETCSR1_LED_D_POSITION                          0x00000003
#define _COMETCSR1_LED_D_MASK                              0x00000008
#define _COMETCSR1_LED_D_LENGTH                            0x00000001

#define _COMETCSR1_LED_C_POSITION                          0x00000002
#define _COMETCSR1_LED_C_MASK                              0x00000004
#define _COMETCSR1_LED_C_LENGTH                            0x00000001

#define _COMETCSR1_LED_B_POSITION                          0x00000001
#define _COMETCSR1_LED_B_MASK                              0x00000002
#define _COMETCSR1_LED_B_LENGTH                            0x00000001

#define _COMETCSR1_LED_A_POSITION                          0x00000000
#define _COMETCSR1_LED_A_MASK                              0x00000001
#define _COMETCSR1_LED_A_LENGTH                            0x00000001

#define _COMETCSR2_POR_POSITION                            0x00000007
#define _COMETCSR2_POR_MASK                                0x00000080
#define _COMETCSR2_POR_LENGTH                              0x00000001

#define _COMETCSR2_WDTO_POSITION                           0x00000006
#define _COMETCSR2_WDTO_MASK                               0x00000040
#define _COMETCSR2_WDTO_LENGTH                             0x00000001

#define _COMETCSR2_SOFT_RST_EN_POSITION                    0x00000005
#define _COMETCSR2_SOFT_RST_EN_MASK                        0x00000020
#define _COMETCSR2_SOFT_RST_EN_LENGTH                      0x00000001

#define _COMETCSR2_WDT_EN_POSITION                         0x00000004
#define _COMETCSR2_WDT_EN_MASK                             0x00000010
#define _COMETCSR2_WDT_EN_LENGTH                           0x00000001

#define _COMETCSR2_CONFIG3_POSITION                        0x00000003
#define _COMETCSR2_CONFIG3_MASK                            0x00000008
#define _COMETCSR2_CONFIG3_LENGTH                          0x00000001

#define _COMETCSR2_CONFIG2_POSITION                        0x00000002
#define _COMETCSR2_CONFIG2_MASK                            0x00000004
#define _COMETCSR2_CONFIG2_LENGTH                          0x00000001

#define _COMETCSR2_CONFIG1_POSITION                        0x00000001
#define _COMETCSR2_CONFIG1_MASK                            0x00000002
#define _COMETCSR2_CONFIG1_LENGTH                          0x00000001

#define _COMETCSR2_CONFIG0_POSITION                        0x00000000
#define _COMETCSR2_CONFIG0_MASK                            0x00000001
#define _COMETCSR2_CONFIG0_LENGTH                          0x00000001

#define _COMETCSR2_CONFIG_POSITION                         0x00000000
#define _COMETCSR2_CONFIG_MASK                             0x0000000F
#define _COMETCSR2_CONFIG_LENGTH                           0x00000004

#endif /* COMET68K_H */
