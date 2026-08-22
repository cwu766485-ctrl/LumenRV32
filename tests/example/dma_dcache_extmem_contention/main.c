#include <stdint.h>

#include "../include/dma.h"
#include "../include/extmem.h"
#include "../include/pmu.h"
#include "../include/utils.h"

#ifndef WORD_COUNT
#define WORD_COUNT       128u
#endif

#ifndef DMA_ROUNDS
#define DMA_ROUNDS       4u
#endif
#define DDR_DMA_BASE     (EXTMEM_BASE_ADDR + 0x0800u)
#define DDR_COPY_BASE    (EXTMEM_BASE_ADDR + 0x1000u)
#define DDR_CPU_BASE     (EXTMEM_BASE_ADDR + 0x1800u)
#define DEBUG_STAGE_REG  EXTMEM_REG32(0x1ffcu)
#define DEBUG_AUX0_REG   EXTMEM_REG32(0x1ff4u)
#define DEBUG_AUX1_REG   EXTMEM_REG32(0x1ff8u)

static uint32_t src_buf[WORD_COUNT] __attribute__((aligned(64)));

static uint32_t pattern(uint32_t index, uint32_t round)
{
    return 0xa5000000u ^ (round << 20) ^ (index * 0x10203u) ^ (index << (round & 7u));
}

static void fail(uint32_t code, uint32_t actual, uint32_t expected)
{
    DEBUG_STAGE_REG = code;
    DEBUG_AUX0_REG = actual;
    DEBUG_AUX1_REG = expected;
    asm volatile("mv x26, %0" :: "r"(code));
    set_test_fail();
    while (1) {
    }
}

static void cpu_extmem_pressure(uint32_t round)
{
    volatile uint32_t *cpu_mem = (volatile uint32_t *)(uintptr_t)DDR_CPU_BASE;
    uint32_t i;

    for (i = 0u; i < 64u; i++) {
        cpu_mem[i] = 0x5a000000u ^ (round << 12) ^ i;
    }
    for (i = 0u; i < 64u; i++) {
        uint32_t expected = 0x5a000000u ^ (round << 12) ^ i;
        if (cpu_mem[i] != expected) {
            fail(0x3000u | i, cpu_mem[i], expected);
        }
    }
}

int main(void)
{
    volatile uint32_t *ddr_dma = (volatile uint32_t *)(uintptr_t)DDR_DMA_BASE;
    uint32_t round;
    uint32_t i;
    uint32_t checksum = 0u;

    pmu_clear();

    for (round = 0u; round < DMA_ROUNDS; round++) {
        for (i = 0u; i < WORD_COUNT; i++) {
            src_buf[i] = pattern(i, round);
        }

        dma_start_mem2mem((uint32_t)(uintptr_t)src_buf, DDR_DMA_BASE, WORD_COUNT);
        cpu_extmem_pressure(round);
        if (!dma_wait_done(WORD_COUNT)) {
            fail(0x1000u | round, dma_count(), WORD_COUNT);
        }

        for (i = 0u; i < WORD_COUNT; i++) {
            uint32_t expected = pattern(i, round);
            if (ddr_dma[i] != expected) {
                fail(0x2000u | round, ddr_dma[i], expected);
            }
        }

        dma_start_mem2mem(DDR_DMA_BASE, DDR_COPY_BASE, WORD_COUNT);
        cpu_extmem_pressure(round + 0x100u);
        if (!dma_wait_done(WORD_COUNT)) {
            fail(0x4000u | round, dma_count(), WORD_COUNT);
        }

        for (i = 0u; i < WORD_COUNT; i++) {
            volatile uint32_t *ddr_copy = (volatile uint32_t *)(uintptr_t)DDR_COPY_BASE;
            uint32_t expected = pattern(i, round);
            checksum ^= ddr_copy[i] + i + round;
            if (ddr_copy[i] != expected) {
                fail(0x5000u | round, ddr_copy[i], expected);
            }
        }
    }

    asm volatile("mv x28, %0" :: "r"((uint32_t)pmu_get_cycle_count()));
    asm volatile("mv x29, %0" :: "r"((uint32_t)pmu_get_hold_count()));
    asm volatile("mv x30, %0" :: "r"(checksum));
    asm volatile("li x26, 1");
    set_test_pass();
    while (1) {
    }
    return 0;
}
