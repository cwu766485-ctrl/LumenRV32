#include <stdint.h>

#include "../include/extmem.h"
#include "../include/utils.h"

static inline void sim_set_pass(void)
{
    asm volatile ("li x27, 0x01");
}

static inline void sim_set_fail(void)
{
    asm volatile ("li x27, 0x00");
}

int main()
{
    volatile uint32_t *base = (volatile uint32_t *)EXTMEM_BASE_ADDR;

    base[0] = 0x11223344u;
    base[1] = 0xa5a55a5au;

    if ((base[0] == 0x11223344u) && (base[1] == 0xa5a55a5au)) {
        sim_set_pass();
    } else {
        sim_set_fail();
    }

    return 0;
}
