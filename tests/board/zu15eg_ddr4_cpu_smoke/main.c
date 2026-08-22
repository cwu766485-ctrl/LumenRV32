#include <stdint.h>

/* Keep the controlled smoke inside the externally backed-up PL-DDR window. */
#define PL_DDR_BASE        0x0000000430000000ULL
#define TEST_WORDS         1024U

#define MAILBOX_MAGIC      0x44524434U
#define STATE_RUNNING      0x52554E21U
#define STATE_PASS         0x50415353U
#define STATE_DATA_FAIL    0x44464149U
#define STATE_RESTORE_FAIL 0x52464149U

struct smoke_mailbox {
    volatile uint32_t magic;
    volatile uint32_t state;
    volatile uint32_t words;
    volatile uint32_t pattern_passes;
    volatile uint32_t fail_index;
    volatile uint32_t expected;
    volatile uint32_t actual;
    volatile uint32_t restore_fail_index;
    volatile uint32_t restore_expected;
    volatile uint32_t restore_actual;
    volatile uint32_t checksum_before;
    volatile uint32_t checksum_after;
};

__attribute__((section(".mailbox")))
volatile struct smoke_mailbox g_mailbox;

static uint32_t g_backup[TEST_WORDS];

static inline void barrier(void)
{
    __asm__ volatile("dsb sy\nisb" ::: "memory");
}

static uint32_t pattern_value(uint32_t pass, uint32_t index)
{
    uint32_t address_word = (uint32_t)((PL_DDR_BASE >> 2) + index);

    switch (pass) {
    case 0:
        return 0xA5A5A5A5U;
    case 1:
        return 0x5A5A5A5AU;
    case 2:
        return address_word ^ 0x13579BDFU;
    default:
        return ~(address_word ^ 0x2468ACE0U);
    }
}

__attribute__((noinline, noreturn))
void smoke_done(void)
{
    barrier();
    for (;;) {
        __asm__ volatile("wfe");
    }
}

int main(void)
{
    volatile uint32_t *const ddr = (volatile uint32_t *)PL_DDR_BASE;
    uint32_t checksum_before = 0;
    uint32_t checksum_after = 0;
    uint32_t pass;
    uint32_t i;

    g_mailbox.magic = MAILBOX_MAGIC;
    g_mailbox.state = STATE_RUNNING;
    g_mailbox.words = TEST_WORDS;
    g_mailbox.pattern_passes = 0;
    g_mailbox.fail_index = 0xFFFFFFFFU;
    g_mailbox.expected = 0;
    g_mailbox.actual = 0;
    g_mailbox.restore_fail_index = 0xFFFFFFFFU;
    g_mailbox.restore_expected = 0;
    g_mailbox.restore_actual = 0;
    g_mailbox.checksum_before = 0;
    g_mailbox.checksum_after = 0;
    barrier();

    for (i = 0; i < TEST_WORDS; ++i) {
        uint32_t value = ddr[i];
        g_backup[i] = value;
        checksum_before = (checksum_before << 5) ^
                          (checksum_before >> 27) ^ value ^ i;
    }

    for (pass = 0; pass < 4U; ++pass) {
        for (i = 0; i < TEST_WORDS; ++i) {
            ddr[i] = pattern_value(pass, i);
        }
        barrier();

        for (i = 0; i < TEST_WORDS; ++i) {
            uint32_t expected = pattern_value(pass, i);
            uint32_t actual = ddr[i];
            if (actual != expected) {
                g_mailbox.state = STATE_DATA_FAIL;
                g_mailbox.fail_index = i;
                g_mailbox.expected = expected;
                g_mailbox.actual = actual;
                goto restore;
            }
        }
        g_mailbox.pattern_passes = pass + 1U;
    }

restore:
    for (i = 0; i < TEST_WORDS; ++i) {
        ddr[i] = g_backup[i];
    }
    barrier();

    for (i = 0; i < TEST_WORDS; ++i) {
        uint32_t actual = ddr[i];
        checksum_after = (checksum_after << 5) ^
                         (checksum_after >> 27) ^ actual ^ i;
        if ((actual != g_backup[i]) &&
            (g_mailbox.restore_fail_index == 0xFFFFFFFFU)) {
            g_mailbox.restore_fail_index = i;
            g_mailbox.restore_expected = g_backup[i];
            g_mailbox.restore_actual = actual;
        }
    }

    g_mailbox.checksum_before = checksum_before;
    g_mailbox.checksum_after = checksum_after;
    if (g_mailbox.restore_fail_index != 0xFFFFFFFFU) {
        g_mailbox.state = STATE_RESTORE_FAIL;
    } else if (g_mailbox.state == STATE_RUNNING) {
        g_mailbox.state = STATE_PASS;
    }
    smoke_done();
}
