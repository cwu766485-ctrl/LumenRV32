#include <stdint.h>

#include "../include/pmu.h"
#include "../include/qspi.h"
#include "../include/utils.h"

#define DEBUG_STAGE_REG (*(volatile uint32_t *)0x30001ffcu)
#define DEBUG_AUX0_REG  (*(volatile uint32_t *)0x30001ff4u)
#define DEBUG_AUX1_REG  (*(volatile uint32_t *)0x30001ff8u)

static void fail_with(uint32_t code, uint32_t actual, uint32_t expected)
{
    DEBUG_STAGE_REG = code;
    DEBUG_AUX0_REG = actual;
    DEBUG_AUX1_REG = expected;
    asm volatile("mv x26, %0\n\tmv a0, %0" :: "r"(code));
    set_test_fail();
    while (1) {
    }
}

static void pass_and_halt(void)
{
    set_test_pass();
    asm volatile("li x26, 1");
    while (1) {
    }
}

int main(void)
{
    uint8_t id[3];
    uint8_t data[8];
    uint32_t i;

    pmu_clear();
    qspi_init(1u);

    if (qspi_read_id(id, 3u) != 0) {
        fail_with(100u, QSPI_REG(QSPI_STATUS), QSPI_STATUS_DONE);
    }
    if (id[0] != 0x20u) {
        fail_with(101u, id[0], 0x20u);
    }
    if (id[1] != 0xbau) {
        fail_with(102u, id[1], 0xbau);
    }
    if (id[2] != 0x18u) {
        fail_with(103u, id[2], 0x18u);
    }

    if (qspi_read_data(data, 8u, 0u) != 0) {
        fail_with(200u, QSPI_REG(QSPI_STATUS), QSPI_STATUS_DONE);
    }
    if (data[0] != 0x54u || data[1] != 0x52u ||
        data[2] != 0x56u || data[3] != 0x31u) {
        fail_with(201u,
                  ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
                      ((uint32_t)data[2] << 8) | data[3],
                  0x54525631u);
    }

    for (i = 4u; i < 8u; i++) {
        uint8_t expected = (uint8_t)(0xa5u ^ i);
        if (data[i] != expected) {
            fail_with(202u + i, data[i], expected);
        }
    }

    pass_and_halt();
    return 0;
}
