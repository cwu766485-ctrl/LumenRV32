
ifndef RISCV_GCC_PREFIX
RISCV_PATH := $(TOOLCHAIN_DIR)/tools/gnu-mcu-eclipse-riscv-none-gcc-8.2.0-2.2-20190521-0004-win64/
RISCV_GCC_PREFIX := $(abspath $(RISCV_PATH)/bin/riscv-none-embed-)
endif

RISCV_GCC     := $(RISCV_GCC_PREFIX)gcc
RISCV_AS      := $(RISCV_GCC_PREFIX)as
RISCV_GXX     := $(RISCV_GCC_PREFIX)g++
RISCV_OBJDUMP := $(RISCV_GCC_PREFIX)objdump
RISCV_GDB     := $(RISCV_GCC_PREFIX)gdb
RISCV_AR      := $(RISCV_GCC_PREFIX)ar
RISCV_OBJCOPY := $(RISCV_GCC_PREFIX)objcopy
RISCV_READELF := $(RISCV_GCC_PREFIX)readelf
PYTHON ?= python

.PHONY: all
all: $(TARGET)

ASM_SRCS += $(COMMON_DIR)/start.S
ASM_SRCS += $(COMMON_DIR)/trap_entry.S
C_SRCS += $(COMMON_DIR)/init.c
C_SRCS += $(COMMON_DIR)/trap_handler.c
C_SRCS += $(COMMON_DIR)/lib/utils.c
C_SRCS += $(COMMON_DIR)/lib/xprintf.c
C_SRCS += $(COMMON_DIR)/lib/uart.c
C_SRCS += $(COMMON_DIR)/lib/flash_n25q.c
C_SRCS += $(COMMON_DIR)/lib/spi.c

ifndef LINKER_SCRIPT
LINKER_SCRIPT := $(COMMON_DIR)/link.lds
endif

INCLUDES += -I$(COMMON_DIR)

LDFLAGS += -T $(LINKER_SCRIPT) -nostartfiles -Wl,--gc-sections -Wl,--check-sections

ASM_OBJS := $(ASM_SRCS:.S=.o)
C_OBJS := $(C_SRCS:.c=.o)

LINK_OBJS += $(ASM_OBJS) $(C_OBJS)
LINK_DEPS += $(LINKER_SCRIPT)

CLEAN_OBJS += $(TARGET) $(LINK_OBJS) $(TARGET).dump $(TARGET).bin

CFLAGS += -march=$(RISCV_ARCH)
CFLAGS += -mabi=$(RISCV_ABI)
CFLAGS += -mcmodel=$(RISCV_MCMODEL) -ffunction-sections -fdata-sections -fno-builtin-printf -fno-builtin-malloc
CFLAGS += -MMD -MP

DEPFILES := $(ASM_OBJS:.o=.d) $(C_OBJS:.o=.d)

-include $(DEPFILES)

CLEAN_OBJS += $(DEPFILES)

$(TARGET): $(LINK_OBJS) $(LINK_DEPS) Makefile
	$(RISCV_GCC) $(CFLAGS) $(INCLUDES) $(LINK_OBJS) -o $@ $(LDFLAGS)
	$(RISCV_OBJCOPY) -O binary $@ $@.bin
	$(RISCV_OBJDUMP) --disassemble-all $@ > $@.dump

$(ASM_OBJS): %.o: %.S
	$(RISCV_GCC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

$(C_OBJS): %.o: %.c
	$(RISCV_GCC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

.PHONY: clean
clean:
	$(PYTHON) -c "from pathlib import Path; import sys; [Path(p).unlink(missing_ok=True) for p in sys.argv[1:]]" $(CLEAN_OBJS)
