#include <stdint.h>

#include "../include/extmem.h"
#include "../include/pmu.h"
#include "../include/utils.h"

int main(void)
{
    volatile uint32_t *base = (volatile uint32_t *)(EXTMEM_BASE_ADDR + 0x200);
    uint32_t i;
    uint32_t sum = 0;

    base[0] = 0x01020304u;
    base[1] = 0x11121314u;
    base[2] = 0x21222324u;
    base[3] = 0x31323334u;

    pmu_clear();
    for (i = 0; i < 64; i++) {
        sum += base[0];
        sum += base[1];
        sum += base[2];
        sum += base[3];
    }

    asm volatile("mv x28, %0" :: "r"((uint32_t)pmu_get_inst_count()));
    asm volatile("mv x29, %0" :: "r"((uint32_t)pmu_get_hold_count()));
    asm volatile("mv x30, %0" :: "r"(sum));

    if (sum == 64u * (0x01020304u + 0x11121314u + 0x21222324u + 0x31323334u)) {
        set_test_pass();
    } else {
        set_test_fail();
    }
    return 0;
}
