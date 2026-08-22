#ifndef _EXTMEM_H_
#define _EXTMEM_H_

#include <stdint.h>

#define EXTMEM_BASE_ADDR      (0x30000000UL)
#define EXTMEM_REG32(offset)  (*(volatile uint32_t *)(EXTMEM_BASE_ADDR + (offset)))

#endif
