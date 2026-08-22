RISCV_ARCH := rv32im
RISCV_ABI := ilp32
RISCV_MCMODEL := medlow

TARGET = perf_counter

CFLAGS += -DSIMULATION
CFLAGS += -Os

C_SRCS := \
	main.c \

COMMON_DIR = ..
TOOLCHAIN_DIR = ../../..
include ../common.mk
