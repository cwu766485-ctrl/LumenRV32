#include <stdint.h>

#include "../include/pmu.h"
#include "../include/utils.h"

static volatile uint32_t data_buf[8] = {3, 7, 11, 13, 17, 19, 23, 29};
static volatile uint32_t sink;

int main()
{
    uint32_t i;
    uint32_t acc = 1;
    uint32_t div = 7;
    uint64_t cycle_begin;
    uint64_t cycle_end;
    uint64_t inst_count;
    uint64_t jump_count;
    uint64_t load_count;
    uint64_t store_count;
    uint64_t hold_count;
    uint64_t div_wait_count;
    uint32_t icache_events;
    uint32_t dcache_events;
    uint32_t branch_events;
    uint32_t store_queue_events;
    uint32_t bus_wait_events;
    uint32_t pmu_checksum;
    uint32_t fail_mask = 0;

    pmu_clear();
    cycle_begin = get_cycle_value();

    for (i = 0; i < 8; i++) {
        acc += data_buf[i];
        if ((acc & 1) == 1) {
            data_buf[i] = acc / div;
        } else {
            data_buf[i] = acc + i;
        }
    }

    sink = data_buf[0] + data_buf[7] + acc;

    cycle_end = get_cycle_value();
    inst_count = pmu_get_inst_count();
    jump_count = pmu_get_jump_count();
    load_count = pmu_get_load_count();
    store_count = pmu_get_store_count();
    hold_count = pmu_get_hold_count();
    div_wait_count = pmu_get_div_wait_count();
    icache_events = pmu_get_icache_hit_count() + pmu_get_icache_miss_count();
    dcache_events = pmu_get_dcache_load_hit_count() + pmu_get_dcache_load_miss_count() +
                    pmu_get_dcache_store_hit_count() + pmu_get_dcache_store_miss_count();
    branch_events = pmu_get_branch_redirect_count() + pmu_get_branch_flush_count() +
                    pmu_get_branch_predict_hit_count() + pmu_get_branch_predict_miss_count();
    store_queue_events = pmu_get_store_buffer_enqueue_count() +
                         pmu_get_store_buffer_full_stall_count() +
                         pmu_get_store_buffer_drain_count();
    bus_wait_events = pmu_get_fetch_bus_wait_count() + pmu_get_data_bus_wait_count();
    pmu_checksum = (uint32_t)inst_count ^ (uint32_t)jump_count ^
                   (uint32_t)load_count ^ (uint32_t)store_count ^
                   (uint32_t)hold_count ^ (uint32_t)div_wait_count ^
                   icache_events ^ dcache_events ^ branch_events ^
                   store_queue_events ^ bus_wait_events;

    if (!(cycle_end > cycle_begin)) fail_mask |= (1u << 0);
    (void)inst_count;
    (void)jump_count;
    (void)load_count;
    (void)store_count;
    (void)hold_count;
    (void)div_wait_count;
    (void)icache_events;
    (void)dcache_events;
    (void)branch_events;
    (void)store_queue_events;
    (void)bus_wait_events;
    if (pmu_checksum == 0) fail_mask |= (1u << 10);
    if (!(sink != 0)) fail_mask |= (1u << 11);

    asm volatile("mv x31, %0" :: "r"(fail_mask));

    if (fail_mask == 0) {
        set_test_pass();
    } else {
        set_test_fail();
    }

    return 0;
}
