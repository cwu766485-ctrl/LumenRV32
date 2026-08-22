#include <stdint.h>

#include "../include/extmem.h"
#include "../include/pmu.h"
#include "../include/utils.h"

#ifndef WORD_COUNT
#define WORD_COUNT       128u
#endif

#ifndef ROUND_COUNT
#define ROUND_COUNT      8u
#endif
#define TEST_BASE        (EXTMEM_BASE_ADDR + 0x0000u)
#define DEBUG_STAGE_REG  EXTMEM_REG32(0x1ffcu)
#define DEBUG_AUX0_REG   EXTMEM_REG32(0x1ff4u)
#define DEBUG_AUX1_REG   EXTMEM_REG32(0x1ff8u)

static uint32_t pattern(uint32_t index, uint32_t round)
{
    uint32_t x = 0x9e3779b9u ^ (round * 0x45d9f3bu) ^ (index * 0x27d4eb2du);
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
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

static void byte_lane_check(void)
{
    volatile uint8_t *bytes = (volatile uint8_t *)(uintptr_t)(TEST_BASE + 0x1800u);
    uint32_t i;

    for (i = 0; i < 64u; i++) {
        bytes[i] = (uint8_t)(0x80u + (i * 3u));
    }
    for (i = 0; i < 64u; i++) {
        uint32_t expected = (uint8_t)(0x80u + (i * 3u));
        if (bytes[i] != expected) {
            fail(0x2000u | i, bytes[i], expected);
        }
    }
}

int main(void)
{
    volatile uint32_t *mem = (volatile uint32_t *)(uintptr_t)TEST_BASE;
    uint32_t round;
    uint32_t i;
    uint32_t checksum = 0u;

    pmu_clear();

    for (round = 0u; round < ROUND_COUNT; round++) {
        for (i = 0u; i < WORD_COUNT; i++) {
            mem[i] = pattern(i, round);
        }
        for (i = 0u; i < WORD_COUNT; i++) {
            uint32_t expected = pattern(i, round);
            uint32_t actual = mem[i];
            checksum ^= actual + (i << 16) + round;
            if (actual != expected) {
                fail(0x1000u | (round & 0xffu), actual, expected);
            }
        }
    }

    byte_lane_check();

    asm volatile("mv x28, %0" :: "r"((uint32_t)pmu_get_cycle_count()));
    asm volatile("mv x29, %0" :: "r"((uint32_t)pmu_get_hold_count()));
    asm volatile("mv x30, %0" :: "r"(checksum));
    asm volatile("li x26, 1");
    set_test_pass();
    while (1) {
    }
    return 0;
}
