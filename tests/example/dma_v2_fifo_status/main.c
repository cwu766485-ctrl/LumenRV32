#include <stdint.h>
#include "../include/dma.h"

static volatile uint32_t src_buf[8] __attribute__((aligned(4)));
static volatile uint32_t dst_buf[8] __attribute__((aligned(4)));

static void fail(int code)
{
    asm volatile("mv x26, %0" : : "r"(code));
    asm volatile("li x27, 0");
    while (1) {
    }
}

int main(void)
{
    for (uint32_t i = 0; i < 8; i++) {
        src_buf[i] = 0x55000000u + i;
        dst_buf[i] = 0;
    }

    dma_start_mem2mem((uint32_t)(uintptr_t)src_buf, (uint32_t)(uintptr_t)dst_buf, 8);
    if (!dma_wait_done(8)) {
        fail(1);
    }

    for (uint32_t i = 0; i < 8; i++) {
        if (dst_buf[i] != src_buf[i]) {
            fail(2);
        }
    }

    if ((dma_status() & 0x0bu) != 0x02u) {
        fail(3);
    }

    if ((dma_fifo_status() & ((1u << 10) | (1u << 9))) != 0u) {
        fail(4);
    }

    if ((dma_error_status() & 0x7u) != 0u) {
        fail(5);
    }

    if ((dma_desc_status() & 0x7u) != 0x2u) {
        fail(6);
    }

    asm volatile("li x26, 0");
    asm volatile("li x27, 1");
    return 0;
}
