#include <stdint.h>

#include "../include/utils.h"

/*
 * Keep the producer and indirect jump adjacent in the emitted stream:
 * la expands to AUIPC/ADDI, and JALR consumes ADDI's result through rs1.
 * The target writes one, while fall-through writes zero.  This is an
 * end-to-end companion to tb/id_jalr_forwarding_tb.sv.
 */
static uint32_t run_ex_to_jalr_case(void)
{
    uint32_t reached_target;

    __asm__ volatile(
        "la t0, 1f\n"
        "jalr t1, t0, 0\n"
        "li %0, 0\n"
        "j 2f\n"
        "1: li %0, 1\n"
        "2:\n"
        : "=&r"(reached_target)
        :
        : "t0", "t1", "memory");

    return reached_target;
}

int main(void)
{
    if (run_ex_to_jalr_case() == 1u) {
        set_test_pass();
    } else {
        set_test_fail();
    }
    return 0;
}
