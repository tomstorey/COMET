#include <stdint.h>
#include <stddef.h>
#include "COMET68k.h"
#include "TL16C2552.h"

static uint8_t a = 0;

int
main(void)
{
    WDTEN();
    WDTCLR();
    WDTDIS();

    UART_REG(UART_CHA, UART_MCR_REG) = 0x12;
    a = UART_REG(UART_CHB, UART_RBR_REG);

    UIIRAbits.IID = 1;

    return 0;
}
