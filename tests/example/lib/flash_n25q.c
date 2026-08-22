#include <stdint.h>

#include "../include/flash_n25q.h"
#include "../include/spi.h"

#ifdef SIMULATION

void n25q_init()
{
    spi_init();
}

void n25q_read_id(uint8_t data[], uint8_t len)
{
    uint8_t i;

    for (i = 0; i < len; i++) {
        if (i == 0u) {
            data[i] = 0x20u;
        } else if (i == 1u) {
            data[i] = 0xbau;
        } else if (i == 2u) {
            data[i] = 0x18u;
        } else {
            data[i] = 0xffu;
        }
    }
}

void n25q_read_data(uint8_t data[], uint32_t len, uint32_t addr)
{
    uint32_t i;

    for (i = 0; i < len; i++) {
        uint32_t cur = addr + i;
        if (cur == 0u) {
            data[i] = 0x54u; // T
        } else if (cur == 1u) {
            data[i] = 0x52u; // R
        } else if (cur == 2u) {
            data[i] = 0x56u; // V
        } else if (cur == 3u) {
            data[i] = 0x31u; // 1
        } else {
            data[i] = (uint8_t)(0xa5u ^ (cur & 0xffu));
        }
    }
}

void n25q_subsector_erase(uint32_t subsector)
{
    (void)subsector;
}

void n25q_sector_erase(uint32_t sector)
{
    (void)sector;
}

void n25q_page_program(uint8_t data[], uint32_t len, uint32_t page)
{
    (void)data;
    (void)len;
    (void)page;
}

#else

static void n25q_write_enable(uint8_t en)
{
    spi_set_ss(0);
    spi_write_byte(en ? WRITE_ENABLE_CMD : WRITE_DISABLE_CMD);
    spi_set_ss(1);
}

static uint8_t n25q_read_status_reg()
{
    uint8_t data;

    spi_set_ss(0);
    spi_write_byte(READ_STATUS_REG_CMD);
    data = spi_read_byte();
    spi_set_ss(1);

    return data;
}

static uint8_t n25q_is_busy()
{
    return (uint8_t)(n25q_read_status_reg() & 0x1u);
}

void n25q_init()
{
    spi_init();
}

void n25q_read_id(uint8_t data[], uint8_t len)
{
    spi_set_ss(0);
    spi_write_byte(READ_ID_CMD);
    spi_read_bytes(data, len);
    spi_set_ss(1);
}

void n25q_read_data(uint8_t data[], uint32_t len, uint32_t addr)
{
    spi_set_ss(0);
    spi_write_byte(READ_CMD);
    spi_write_byte((addr >> 16) & 0xffu);
    spi_write_byte((addr >> 8) & 0xffu);
    spi_write_byte(addr & 0xffu);
    spi_read_bytes(data, len);
    spi_set_ss(1);
}

void n25q_subsector_erase(uint32_t subsector)
{
    uint32_t addr = N25Q_SUBSECTOR_TO_ADDR(subsector);

    n25q_write_enable(1);
    spi_set_ss(0);
    spi_write_byte(SUBSECTOR_ERASE_CMD);
    spi_write_byte((addr >> 16) & 0xffu);
    spi_write_byte((addr >> 8) & 0xffu);
    spi_write_byte(addr & 0xffu);
    spi_set_ss(1);
    while (n25q_is_busy()) {
    }
    n25q_write_enable(0);
}

void n25q_sector_erase(uint32_t sector)
{
    uint32_t addr = N25Q_SECTOR_TO_ADDR(sector);

    n25q_write_enable(1);
    spi_set_ss(0);
    spi_write_byte(SECTOR_ERASE_CMD);
    spi_write_byte((addr >> 16) & 0xffu);
    spi_write_byte((addr >> 8) & 0xffu);
    spi_write_byte(addr & 0xffu);
    spi_set_ss(1);
    while (n25q_is_busy()) {
    }
    n25q_write_enable(0);
}

void n25q_page_program(uint8_t data[], uint32_t len, uint32_t page)
{
    uint32_t addr = N25Q_PAGE_TO_ADDR(page);

    n25q_write_enable(1);
    spi_set_ss(0);
    spi_write_byte(PAGE_PROGRAM_CMD);
    spi_write_byte((addr >> 16) & 0xffu);
    spi_write_byte((addr >> 8) & 0xffu);
    spi_write_byte(addr & 0xffu);
    spi_write_bytes(data, len);
    spi_set_ss(1);
    while (n25q_is_busy()) {
    }
    n25q_write_enable(0);
}

#endif
