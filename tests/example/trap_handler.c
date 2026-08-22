#include <stdint.h>


extern void timer0_irq_handler() __attribute__((weak));
extern int external_irq_handler(uint32_t mcause, uint32_t mepc) __attribute__((weak));


void trap_handler(uint32_t mcause, uint32_t mepc)
{
    /*
     * Default examples historically only used timer0. Keep that path, but
     * allow SoC-level examples to claim a shared external interrupt source
     * such as DMA/NPU completion without changing trap_entry.S.
     */
    if (external_irq_handler != 0) {
        if (external_irq_handler(mcause, mepc) != 0) {
            return;
        }
    }

    timer0_irq_handler();
}
