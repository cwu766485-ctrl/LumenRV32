#ifndef _PMU_H_
#define _PMU_H_

#include <stdint.h>

#define PMU_BASE_ADDR      (0x20004000UL)
#define PMU_CTRL           (0x00)
#define PMU_CYCLE_LO       (0x04)
#define PMU_CYCLE_HI       (0x08)
#define PMU_INST_LO        (0x0c)
#define PMU_INST_HI        (0x10)
#define PMU_JUMP_LO        (0x14)
#define PMU_JUMP_HI        (0x18)
#define PMU_LOAD_LO        (0x1c)
#define PMU_LOAD_HI        (0x20)
#define PMU_STORE_LO       (0x24)
#define PMU_STORE_HI       (0x28)
#define PMU_HOLD_LO        (0x2c)
#define PMU_HOLD_HI        (0x30)
#define PMU_INT_LO         (0x34)
#define PMU_INT_HI         (0x38)
#define PMU_DIV_WAIT_LO    (0x3c)
#define PMU_DIV_WAIT_HI    (0x40)
#define PMU_SIM_DONE       (0x44)
#define PMU_SIM_TICKS_LO   (0x48)
#define PMU_SIM_TICKS_HI   (0x4c)
#define PMU_ICACHE_HIT     (0x50)
#define PMU_ICACHE_MISS    (0x54)
#define PMU_DCACHE_LD_HIT  (0x58)
#define PMU_DCACHE_LD_MISS (0x5c)
#define PMU_DCACHE_ST_HIT  (0x60)
#define PMU_DCACHE_ST_MISS (0x64)
#define PMU_BRANCH_REDIR   (0x68)
#define PMU_BRANCH_FLUSH   (0x6c)
#define PMU_PREFETCH_OCC   (0x70)
#define PMU_PREFETCH_FULL  (0x74)
#define PMU_PREFETCH_STALL (0x78)
#define PMU_BP_HIT         (0x7c)
#define PMU_BP_MISS        (0x80)
#define PMU_DCACHE_LD_STALL (0x84)
#define PMU_DCACHE_ST_WAIT  (0x88)
#define PMU_ID_CONTENTION   (0x8c)
#define PMU_STBUF_ENQUEUE   (0x90)
#define PMU_STBUF_FULL_STALL (0x94)
#define PMU_STBUF_DRAIN     (0x98)
#define PMU_FETCH_BUS_WAIT  (0x9c)
#define PMU_DATA_BUS_WAIT   (0xa0)

#define PMU_REG(offset) (*(volatile uint32_t *)(PMU_BASE_ADDR + (offset)))

static inline uint64_t pmu_read_counter(uint32_t low_offset, uint32_t high_offset)
{
    uint32_t hi0;
    uint32_t hi1;
    uint32_t lo;

    do {
        hi0 = PMU_REG(high_offset);
        lo = PMU_REG(low_offset);
        hi1 = PMU_REG(high_offset);
    } while (hi0 != hi1);

    return ((uint64_t)hi1 << 32) | (uint64_t)lo;
}

static inline void pmu_clear(void)
{
    PMU_REG(PMU_CTRL) = 0x1;
}

static inline uint64_t pmu_get_inst_count(void)
{
    return pmu_read_counter(PMU_INST_LO, PMU_INST_HI);
}

static inline uint64_t pmu_get_cycle_count(void)
{
    return pmu_read_counter(PMU_CYCLE_LO, PMU_CYCLE_HI);
}

static inline uint64_t pmu_get_jump_count(void)
{
    return pmu_read_counter(PMU_JUMP_LO, PMU_JUMP_HI);
}

static inline uint64_t pmu_get_load_count(void)
{
    return pmu_read_counter(PMU_LOAD_LO, PMU_LOAD_HI);
}

static inline uint64_t pmu_get_store_count(void)
{
    return pmu_read_counter(PMU_STORE_LO, PMU_STORE_HI);
}

static inline uint64_t pmu_get_hold_count(void)
{
    return pmu_read_counter(PMU_HOLD_LO, PMU_HOLD_HI);
}

static inline uint64_t pmu_get_interrupt_count(void)
{
    return pmu_read_counter(PMU_INT_LO, PMU_INT_HI);
}

static inline uint64_t pmu_get_div_wait_count(void)
{
    return pmu_read_counter(PMU_DIV_WAIT_LO, PMU_DIV_WAIT_HI);
}

static inline uint32_t pmu_read_event32(uint32_t offset)
{
    return PMU_REG(offset);
}

static inline uint32_t pmu_get_icache_hit_count(void)
{
    return pmu_read_event32(PMU_ICACHE_HIT);
}

static inline uint32_t pmu_get_icache_miss_count(void)
{
    return pmu_read_event32(PMU_ICACHE_MISS);
}

static inline uint32_t pmu_get_dcache_load_hit_count(void)
{
    return pmu_read_event32(PMU_DCACHE_LD_HIT);
}

static inline uint32_t pmu_get_dcache_load_miss_count(void)
{
    return pmu_read_event32(PMU_DCACHE_LD_MISS);
}

static inline uint32_t pmu_get_dcache_store_hit_count(void)
{
    return pmu_read_event32(PMU_DCACHE_ST_HIT);
}

static inline uint32_t pmu_get_dcache_store_miss_count(void)
{
    return pmu_read_event32(PMU_DCACHE_ST_MISS);
}

static inline uint32_t pmu_get_branch_redirect_count(void)
{
    return pmu_read_event32(PMU_BRANCH_REDIR);
}

static inline uint32_t pmu_get_branch_flush_count(void)
{
    return pmu_read_event32(PMU_BRANCH_FLUSH);
}

static inline uint32_t pmu_get_prefetch_occupancy_sum(void)
{
    return pmu_read_event32(PMU_PREFETCH_OCC);
}

static inline uint32_t pmu_get_prefetch_full_count(void)
{
    return pmu_read_event32(PMU_PREFETCH_FULL);
}

static inline uint32_t pmu_get_prefetch_stall_count(void)
{
    return pmu_read_event32(PMU_PREFETCH_STALL);
}

static inline uint32_t pmu_get_branch_predict_hit_count(void)
{
    return pmu_read_event32(PMU_BP_HIT);
}

static inline uint32_t pmu_get_branch_predict_miss_count(void)
{
    return pmu_read_event32(PMU_BP_MISS);
}

static inline uint32_t pmu_get_dcache_load_miss_stall_count(void)
{
    return pmu_read_event32(PMU_DCACHE_LD_STALL);
}

static inline uint32_t pmu_get_dcache_store_wait_count(void)
{
    return pmu_read_event32(PMU_DCACHE_ST_WAIT);
}

static inline uint32_t pmu_get_id_contention_count(void)
{
    return pmu_read_event32(PMU_ID_CONTENTION);
}

static inline uint32_t pmu_get_store_buffer_enqueue_count(void)
{
    return pmu_read_event32(PMU_STBUF_ENQUEUE);
}

static inline uint32_t pmu_get_store_buffer_full_stall_count(void)
{
    return pmu_read_event32(PMU_STBUF_FULL_STALL);
}

static inline uint32_t pmu_get_store_buffer_drain_count(void)
{
    return pmu_read_event32(PMU_STBUF_DRAIN);
}

static inline uint32_t pmu_get_fetch_bus_wait_count(void)
{
    return pmu_read_event32(PMU_FETCH_BUS_WAIT);
}

static inline uint32_t pmu_get_data_bus_wait_count(void)
{
    return pmu_read_event32(PMU_DATA_BUS_WAIT);
}

static inline void pmu_sim_mark_done(uint64_t ticks)
{
    PMU_REG(PMU_SIM_TICKS_LO) = (uint32_t)ticks;
    PMU_REG(PMU_SIM_TICKS_HI) = (uint32_t)(ticks >> 32);
    PMU_REG(PMU_SIM_DONE) = 0x1;
}

#endif
