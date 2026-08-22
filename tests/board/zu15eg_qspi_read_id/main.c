#include <stdint.h>

#include "xparameters.h"
#include "xqspipsu.h"
#include "xstatus.h"

#define QSPI_READ_ID_COMMAND 0x9FU
#define QSPI_MAILBOX_MAGIC   0x51535049U
#define QSPI_STATE_RUNNING   0x52554E21U
#define QSPI_STATE_PASS      0x50415353U
#define QSPI_STATE_FAIL      0x4641494CU

struct qspi_mailbox {
    volatile uint32_t magic;
    volatile uint32_t state;
    volatile uint32_t driver_status;
    volatile uint32_t flash_id;
};

__attribute__((section(".mailbox")))
volatile struct qspi_mailbox g_mailbox;

__attribute__((noinline, noreturn))
void qspi_read_id_done(void)
{
    __asm__ volatile("dsb sy\nisb" ::: "memory");
    for (;;) {
        __asm__ volatile("wfe");
    }
}

int main(void)
{
    XQspiPsu qspi;
    XQspiPsu_Config *config;
    XQspiPsu_Msg msg[2];
    uint8_t cmd = QSPI_READ_ID_COMMAND;
    uint8_t id[3] = {0, 0, 0};
    int status;

    g_mailbox.magic = QSPI_MAILBOX_MAGIC;
    g_mailbox.state = QSPI_STATE_RUNNING;
    g_mailbox.driver_status = 0xFFFFFFFFU;
    g_mailbox.flash_id = 0;

    config = XQspiPsu_LookupConfig(XPAR_XQSPIPSU_0_DEVICE_ID);
    if (config == 0) {
        g_mailbox.state = QSPI_STATE_FAIL;
        qspi_read_id_done();
    }
    status = XQspiPsu_CfgInitialize(&qspi, config, config->BaseAddress);
    if (status != XST_SUCCESS) {
        g_mailbox.driver_status = (uint32_t)status;
        g_mailbox.state = QSPI_STATE_FAIL;
        qspi_read_id_done();
    }

    XQspiPsu_SetOptions(&qspi, XQSPIPSU_MANUAL_START_OPTION);
    XQspiPsu_SetClkPrescaler(&qspi, XQSPIPSU_CLK_PRESCALE_8);
    XQspiPsu_SelectFlash(&qspi, XQSPIPSU_SELECT_FLASH_CS_LOWER,
                         XQSPIPSU_SELECT_FLASH_BUS_LOWER);

    msg[0].TxBfrPtr = &cmd;
    msg[0].RxBfrPtr = 0;
    msg[0].ByteCount = 1;
    msg[0].BusWidth = XQSPIPSU_SELECT_MODE_SPI;
    msg[0].Flags = XQSPIPSU_MSG_FLAG_TX;
    msg[1].TxBfrPtr = 0;
    msg[1].RxBfrPtr = id;
    msg[1].ByteCount = 3;
    msg[1].BusWidth = XQSPIPSU_SELECT_MODE_SPI;
    msg[1].Flags = XQSPIPSU_MSG_FLAG_RX;

    status = XQspiPsu_PolledTransfer(&qspi, msg, 2);
    g_mailbox.driver_status = (uint32_t)status;
    g_mailbox.flash_id = ((uint32_t)id[0] << 16) |
                          ((uint32_t)id[1] << 8) | id[2];
    g_mailbox.state = (status == XST_SUCCESS && g_mailbox.flash_id != 0 &&
                       g_mailbox.flash_id != 0xFFFFFFU) ? QSPI_STATE_PASS : QSPI_STATE_FAIL;
    qspi_read_id_done();
}
