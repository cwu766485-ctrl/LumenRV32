#!/usr/bin/env python3
"""Create a deterministic CoreMark benchmark image from a known base image.

The checked-in source tree intentionally ignores generated ``*.bin`` files.
This utility changes only ``seed4_volatile`` (the CoreMark iteration count),
using the matching objdump file to locate it. It does not alter the memory map
or instruction stream.
"""

import argparse
import re
from pathlib import Path


def symbol_address(dump_text: str, symbol: str) -> int:
    match = re.search(rf"^([0-9a-fA-F]+)\s+<{re.escape(symbol)}>:", dump_text, re.MULTILINE)
    if not match:
        raise ValueError(f"symbol not found: {symbol}")
    return int(match.group(1), 16)


def data_lma(dump_text: str) -> int:
    match = re.search(r"#\s+([0-9a-fA-F]+)\s+<_data_lma>", dump_text)
    if not match:
        raise ValueError("_data_lma reference not found")
    return int(match.group(1), 16)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--dump", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--iterations", required=True, type=int)
    args = parser.parse_args()

    if args.iterations <= 0 or args.iterations > 0xFFFFFFFF:
        raise ValueError("iterations must fit in an unsigned 32-bit word")

    dump_text = args.dump.read_text(encoding="utf-8", errors="replace")
    seed4_vma = symbol_address(dump_text, "seed4_volatile")
    offset = data_lma(dump_text) + seed4_vma - 0x10000000
    image = bytearray(args.binary.read_bytes())
    if offset < 0 or offset + 4 > len(image):
        raise ValueError(f"seed4 offset 0x{offset:x} outside input image")

    old_value = int.from_bytes(image[offset:offset + 4], "little")
    image[offset:offset + 4] = args.iterations.to_bytes(4, "little")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    print(
        f"CoreMark iterations {old_value} -> {args.iterations}; "
        f"seed4 VMA=0x{seed4_vma:08x}, file offset=0x{offset:x}"
    )


if __name__ == "__main__":
    main()
