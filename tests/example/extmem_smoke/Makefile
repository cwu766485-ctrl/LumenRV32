RISCV_ARCH := rv32im
RISCV_ABI := ilp32
RISCV_MCMODEL := medlow

TARGET := extmem_smoke

C_SRCS := \
	main.c \

CFLAGS += -DSIMULATION

COMMON_DIR = ..
TOOLCHAIN_DIR = ../../..
include ../common.mk
