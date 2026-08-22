#include <stdint.h>

#include "../include/dma.h"
#include "../include/extmem.h"
#include "../include/utils.h"

static uint32_t src_buf[8] = {
    0x11112222u, 0x33334444u, 0x55556666u, 0x77778888u,
    0x9999aaaau, 0xbbbbccccu, 0xddddeeeeu, 0xffff0001u
};

static uint32_t dst_buf[8];

int main(void)
{
    uint32_t i;
    volatile uint32_t *ext = (volatile uint32_t *)(EXTMEM_BASE_ADDR + 0x100);

    dma_start_mem2mem((uint32_t)(uintptr_t)src_buf, EXTMEM_BASE_ADDR + 0x100, 8);
    if (!dma_wait_done(8)) {
        set_test_fail();
        return 0;
    }

    dma_start_mem2mem(EXTMEM_BASE_ADDR + 0x100, (uint32_t)(uintptr_t)dst_buf, 8);
    if (!dma_wait_done(8)) {
        set_test_fail();
        return 0;
    }

    for (i = 0; i < 8; i++) {
        if (ext[i] != src_buf[i] || dst_buf[i] != src_buf[i]) {
            set_test_fail();
            return 0;
        }
    }

    set_test_pass();
    return 0;
}
