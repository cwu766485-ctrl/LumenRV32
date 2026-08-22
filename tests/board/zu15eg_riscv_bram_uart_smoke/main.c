#include <stdint.h>

#include "../../example/include/uart.h"

static void putc_poll(char c)
{
    while (UART0_REG(UART0_STATUS) & 0x1u) { }
    UART0_REG(UART0_TXDATA) = (uint32_t)(uint8_t)c;
}

static void puts_poll(const char *s)
{
    while (*s) {
        putc_poll(*s++);
    }
}

int main(void)
{
    UART0_REG(UART0_CTRL) = 0x3u;
    UART0_REG(UART0_BAUD) = 0x1B8u; /* 115200 at the verified 50 MHz clock. */
    for (;;) {
        puts_poll("TINYRISCV_BRAM_UART_SMOKE\\r\\n");
        for (volatile uint32_t i = 0; i < 12500000u; ++i) { }
    }
}
