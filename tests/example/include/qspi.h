#ifndef _QSPI_H_
#define _QSPI_H_

#include <stdint.h>

#define QSPI_BASE        (0x20007000u)
#define QSPI_CTRL        (QSPI_BASE + 0x00u)
#define QSPI_STATUS      (QSPI_BASE + 0x04u)
#define QSPI_CLKDIV      (QSPI_BASE + 0x08u)
#define QSPI_CMD         (QSPI_BASE + 0x0cu)
#define QSPI_ADDR        (QSPI_BASE + 0x10u)
#define QSPI_LEN         (QSPI_BASE + 0x14u)
#define QSPI_TXDATA      (QSPI_BASE + 0x18u)
#define QSPI_RXDATA      (QSPI_BASE + 0x1cu)
#define QSPI_RX_INDEX    (QSPI_BASE + 0x20u)
#define QSPI_FIFO_STATUS (QSPI_BASE + 0x24u)
#define QSPI_TX_INDEX    (QSPI_BASE + 0x28u)

#define QSPI_CTRL_START   (1u << 0)
#define QSPI_CTRL_ADDR_EN (1u << 1)
#define QSPI_CTRL_WRITE   (1u << 2)
#define QSPI_CTRL_QUAD    (1u << 3)

#define QSPI_STATUS_BUSY  (1u << 0)
#define QSPI_STATUS_DONE  (1u << 1)
#define QSPI_STATUS_ERROR (1u << 2)
#define QSPI_STATUS_RX_VALID (1u << 8)

#define QSPI_REG(addr) (*(volatile uint32_t *)(addr))

static inline void qspi_init(uint32_t clkdiv)
{
    QSPI_REG(QSPI_CLKDIV) = clkdiv;
    QSPI_REG(QSPI_STATUS) = QSPI_STATUS_DONE | QSPI_STATUS_ERROR;
}

static inline int qspi_wait_done(uint32_t timeout)
{
    while (timeout-- != 0u) {
        uint32_t status = QSPI_REG(QSPI_STATUS);
        if ((status & QSPI_STATUS_ERROR) != 0u) {
            return -1;
        }
        if ((status & QSPI_STATUS_DONE) != 0u) {
            return 0;
        }
    }
    return -2;
}

static inline int qspi_command(uint8_t cmd)
{
    QSPI_REG(QSPI_STATUS) = QSPI_STATUS_DONE | QSPI_STATUS_ERROR;
    QSPI_REG(QSPI_CMD) = cmd;
    QSPI_REG(QSPI_LEN) = 0u;
    QSPI_REG(QSPI_CTRL) = QSPI_CTRL_START;
    return qspi_wait_done(20000u);
}

static inline int qspi_read_id(uint8_t *data, uint32_t len)
{
    uint32_t i;

    QSPI_REG(QSPI_STATUS) = QSPI_STATUS_DONE | QSPI_STATUS_ERROR;
    QSPI_REG(QSPI_CMD) = 0x9fu;
    QSPI_REG(QSPI_LEN) = len;
    QSPI_REG(QSPI_CTRL) = QSPI_CTRL_START;
    if (qspi_wait_done(20000u) != 0) {
        return -1;
    }

    for (i = 0u; i < len; i++) {
        QSPI_REG(QSPI_RX_INDEX) = i;
        data[i] = (uint8_t)QSPI_REG(QSPI_RXDATA);
    }
    return 0;
}

static inline int qspi_read_data(uint8_t *data, uint32_t len, uint32_t addr)
{
    uint32_t i;

    QSPI_REG(QSPI_STATUS) = QSPI_STATUS_DONE | QSPI_STATUS_ERROR;
    QSPI_REG(QSPI_CMD) = 0x03u;
    QSPI_REG(QSPI_ADDR) = addr & 0x00ffffffu;
    QSPI_REG(QSPI_LEN) = len;
    QSPI_REG(QSPI_CTRL) = QSPI_CTRL_START | QSPI_CTRL_ADDR_EN;
    if (qspi_wait_done(40000u) != 0) {
        return -1;
    }

    for (i = 0u; i < len; i++) {
        QSPI_REG(QSPI_RX_INDEX) = i;
        data[i] = (uint8_t)QSPI_REG(QSPI_RXDATA);
    }
    return 0;
}

#endif
