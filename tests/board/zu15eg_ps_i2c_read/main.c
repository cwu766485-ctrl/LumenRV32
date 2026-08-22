#include <stdint.h>

#define PS_I2C1_BASE       0xFF030000U
#define PCA9548A_ADDRESS    0x70U
#define M24C02_ADDRESS      0x50U
#define PCA9548A_CHANNEL0   0x01U

#define I2C_CR              0x00U
#define I2C_SR              0x04U
#define I2C_ADDR            0x08U
#define I2C_DATA            0x0CU
#define I2C_ISR             0x10U
#define I2C_TRANS_SIZE      0x14U
#define I2C_TIMEOUT         0x1CU
#define I2C_IDR             0x28U
#define I2C_CR_DIV_A0_DIV_B49 0x00003100U /* ~90.9 kHz from 100 MHz */
#define I2C_CR_CLEAR_FIFO   0x00000040U
#define I2C_CR_7BIT         0x00000004U
#define I2C_CR_MASTER       0x00000002U
#define I2C_CR_READ         0x00000001U
#define I2C_SR_RX_VALID     0x00000020U
#define I2C_ISR_ARB_LOST    0x00000200U
#define I2C_ISR_NACK        0x00000004U
#define I2C_ISR_COMPLETE    0x00000001U
#define I2C_ISR_ERROR       (I2C_ISR_ARB_LOST | I2C_ISR_NACK)
#define I2C_ISR_ALL         0x000002FFU
#define I2C_POLL_LIMIT      2000000U

#define I2C_MAILBOX_MAGIC   0x49324331U
#define I2C_STATE_RUNNING   0x52554E21U
#define I2C_STATE_PASS      0x50415353U
#define I2C_STATE_FAIL      0x4641494CU

struct i2c_mailbox {
    volatile uint32_t magic;
    volatile uint32_t state;
    volatile uint32_t stage;
    volatile uint32_t driver_status;
    volatile uint32_t eeprom_byte0;
};

__attribute__((section(".mailbox")))
volatile struct i2c_mailbox g_mailbox;

__attribute__((noinline, noreturn))
void ps_i2c_read_done(void)
{
    __asm__ volatile("dsb sy\nisb" ::: "memory");
    for (;;) { __asm__ volatile("wfe"); }
}

static void fail(uint32_t stage, int status)
{
    g_mailbox.stage = stage;
    g_mailbox.driver_status = (uint32_t)status;
    g_mailbox.state = I2C_STATE_FAIL;
    ps_i2c_read_done();
}

static inline void wr(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(PS_I2C1_BASE + offset) = value;
}

static inline uint32_t rd(uint32_t offset)
{
    return *(volatile uint32_t *)(uintptr_t)(PS_I2C1_BASE + offset);
}

static int wait_for_complete(void)
{
    uint32_t i;
    for (i = 0; i < I2C_POLL_LIMIT; ++i) {
        uint32_t isr = rd(I2C_ISR);
        if ((isr & I2C_ISR_ERROR) != 0U) {
            wr(I2C_ISR, isr);
            return -2;
        }
        if ((isr & I2C_ISR_COMPLETE) != 0U) {
            wr(I2C_ISR, isr);
            return 0;
        }
    }
    return -1;
}

static int write_byte(uint8_t slave, uint8_t value)
{
    wr(I2C_CR, 0U);
    wr(I2C_TIMEOUT, 0xFFU);
    wr(I2C_IDR, I2C_ISR_ALL);
    wr(I2C_ISR, I2C_ISR_ALL);
    wr(I2C_CR, I2C_CR_DIV_A0_DIV_B49 | I2C_CR_CLEAR_FIFO | I2C_CR_7BIT | I2C_CR_MASTER);
    wr(I2C_DATA, value);
    wr(I2C_ADDR, slave);
    return wait_for_complete();
}

static int read_byte(uint8_t slave, uint8_t *value)
{
    int status;
    wr(I2C_CR, 0U);
    wr(I2C_TIMEOUT, 0xFFU);
    wr(I2C_IDR, I2C_ISR_ALL);
    wr(I2C_ISR, I2C_ISR_ALL);
    wr(I2C_CR, I2C_CR_DIV_A0_DIV_B49 | I2C_CR_CLEAR_FIFO | I2C_CR_7BIT | I2C_CR_MASTER | I2C_CR_READ);
    wr(I2C_TRANS_SIZE, 1U);
    wr(I2C_ADDR, slave);
    status = wait_for_complete();
    if (status == 0 && (rd(I2C_SR) & I2C_SR_RX_VALID) != 0U) {
        *value = (uint8_t)rd(I2C_DATA);
    }
    return status;
}

int main(void)
{
    uint8_t mux_select = PCA9548A_CHANNEL0;
    uint8_t eeprom_offset = 0;
    uint8_t eeprom_value = 0;
    int status;

    g_mailbox.magic = I2C_MAILBOX_MAGIC;
    g_mailbox.state = I2C_STATE_RUNNING;
    g_mailbox.stage = 0;
    g_mailbox.driver_status = 0xFFFFFFFFU;
    g_mailbox.eeprom_byte0 = 0;

    /* FSBL/psu_init owns PS clock and MIO setup.  Do not write protected CRL
       registers from this acceptance payload. */
    g_mailbox.stage = 1;
    /* PCA9548A selection is volatile and is cleared by reset; EEPROM data is never written. */
    status = write_byte(PCA9548A_ADDRESS, mux_select);
    if (status != 0) { fail(3, status); }
    status = write_byte(M24C02_ADDRESS, eeprom_offset);
    if (status != 0) { fail(4, status); }
    status = read_byte(M24C02_ADDRESS, &eeprom_value);
    if (status != 0) { fail(5, status); }

    g_mailbox.stage = 6;
    g_mailbox.driver_status = 0;
    g_mailbox.eeprom_byte0 = eeprom_value;
    g_mailbox.state = I2C_STATE_PASS;
    ps_i2c_read_done();
}
