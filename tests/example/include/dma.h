#ifndef _DMA_H_
#define _DMA_H_

#include <stdint.h>

#define DMA_BASE_ADDR      (0x20005000UL)
#define DMA_CTRL           (0x00)
#define DMA_STATUS         (0x04)
#define DMA_SRC            (0x08)
#define DMA_DST            (0x0c)
#define DMA_LEN            (0x10)
#define DMA_COUNT          (0x14)
#define DMA_AUX            (0x18)
#define DMA_FIFO_STATUS    (0x1c)
#define DMA_ERROR          (0x20)
#define DMA_DESC_STATUS    (0x24)

#define DMA_REG(offset) (*(volatile uint32_t *)(DMA_BASE_ADDR + (offset)))

#define DMA_CTRL_FIELDS_MAKE(irq_en, fixed_src, fixed_dst, byte_mode, spi_stream) \
    ((((irq_en) & 0x1u) << 1) | (((fixed_src) & 0x1u) << 2) | \
     (((fixed_dst) & 0x1u) << 3) | (((byte_mode) & 0x1u) << 4) | (((spi_stream) & 0x1u) << 5))

typedef struct dma_xfer_desc_t {
    uint32_t src;
    uint32_t dst;
    uint32_t len;
    uint32_t ctrl;
    uint32_t aux;
} dma_xfer_desc_t;

static inline void dma_set_src(uint32_t addr)
{
    DMA_REG(DMA_SRC) = addr;
}

static inline void dma_set_dst(uint32_t addr)
{
    DMA_REG(DMA_DST) = addr;
}

static inline void dma_set_len(uint32_t length_words_or_bytes)
{
    DMA_REG(DMA_LEN) = length_words_or_bytes;
}

static inline void dma_set_aux(uint32_t value)
{
    DMA_REG(DMA_AUX) = value;
}

static inline uint32_t dma_status(void)
{
    return DMA_REG(DMA_STATUS);
}

static inline void dma_clear_done_irq(void)
{
    DMA_REG(DMA_STATUS) = 0x6u;
}

static inline uint32_t dma_count(void)
{
    return DMA_REG(DMA_COUNT);
}

static inline uint32_t dma_fifo_status(void)
{
    return DMA_REG(DMA_FIFO_STATUS);
}

static inline uint32_t dma_error_status(void)
{
    return DMA_REG(DMA_ERROR);
}

static inline uint32_t dma_desc_status(void)
{
    return DMA_REG(DMA_DESC_STATUS);
}

static inline void dma_start(uint32_t irq_en, uint32_t fixed_src, uint32_t fixed_dst, uint32_t byte_mode, uint32_t spi_stream)
{
    DMA_REG(DMA_CTRL) = 0x1u | DMA_CTRL_FIELDS_MAKE(irq_en, fixed_src, fixed_dst, byte_mode, spi_stream);
}

static inline void dma_desc_init(
    dma_xfer_desc_t *desc,
    uint32_t src,
    uint32_t dst,
    uint32_t len,
    uint32_t ctrl,
    uint32_t aux)
{
    desc->src = src;
    desc->dst = dst;
    desc->len = len;
    desc->ctrl = ctrl & 0x3eu;
    desc->aux = aux;
}

static inline void dma_desc_init_mem2mem(
    dma_xfer_desc_t *desc,
    uint32_t src,
    uint32_t dst,
    uint32_t len_words)
{
    dma_desc_init(desc, src, dst, len_words, DMA_CTRL_FIELDS_MAKE(0u, 0u, 0u, 0u, 0u), 0u);
}

static inline void dma_desc_program(const dma_xfer_desc_t *desc)
{
    dma_set_src(desc->src);
    dma_set_dst(desc->dst);
    dma_set_len(desc->len);
    dma_set_aux(desc->aux);
}

static inline void dma_desc_launch(const dma_xfer_desc_t *desc)
{
    dma_desc_program(desc);
    dma_clear_done_irq();
    DMA_REG(DMA_CTRL) = 0x1u | (desc->ctrl & 0x3eu);
}

static inline int dma_desc_wait_done(const dma_xfer_desc_t *desc)
{
    while ((dma_status() & 0x2u) == 0u) {
    }
    return dma_count() == desc->len;
}

static inline int dma_desc_run_blocking(const dma_xfer_desc_t *desc)
{
    dma_desc_launch(desc);
    return dma_desc_wait_done(desc);
}

static inline void dma_start_mem2mem(uint32_t src, uint32_t dst, uint32_t len_words)
{
    dma_set_src(src);
    dma_set_dst(dst);
    dma_set_len(len_words);
    dma_clear_done_irq();
    dma_start(0, 0, 0, 0, 0);
}

static inline int dma_wait_done(uint32_t expected_count)
{
    while ((dma_status() & 0x2u) == 0u) {
    }
    return dma_count() == expected_count;
}

#endif
