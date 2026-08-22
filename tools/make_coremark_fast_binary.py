#!/usr/bin/env python3
"""Create a one-iteration CoreMark simulation binary for the current SoC map."""

import argparse
import re
from pathlib import Path


def symbol_address(dump_text: str, symbol: str) -> int:
    match = re.search(rf"^([0-9a-fA-F]+)\s+<{re.escape(symbol)}>:", dump_text, re.MULTILINE)
    if not match:
        raise ValueError(f"symbol not found in dump: {symbol}")
    return int(match.group(1), 16)


def data_lma(dump_text: str) -> int:
    match = re.search(r"#\s+([0-9a-fA-F]+)\s+<_data_lma>", dump_text)
    if not match:
        raise ValueError("_data_lma reference not found in dump")
    return int(match.group(1), 16)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--dump", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--old-pmu-base", type=lambda value: int(value, 0), default=0x60000000)
    parser.add_argument("--new-pmu-base", type=lambda value: int(value, 0), default=0x20004000)
    args = parser.parse_args()

    dump_text = args.dump.read_text(encoding="utf-8", errors="replace")
    seed4_vma = symbol_address(dump_text, "seed4_volatile")
    lma = data_lma(dump_text)
    file_offset = lma + seed4_vma - 0x10000000

    image = bytearray(args.binary.read_bytes())
    if file_offset < 0 or file_offset + 4 > len(image):
        raise ValueError(f"seed4 file offset 0x{file_offset:x} is outside binary")
    old_iterations = int.from_bytes(image[file_offset:file_offset + 4], "little")
    image[file_offset:file_offset + 4] = args.iterations.to_bytes(4, "little")

    # The checked-in fast image predates the AXI/APB address map migration.
    # Patch the single LUI that forms the PMU simulation-done base address.
    old_lui = ((args.old_pmu_base >> 12) << 12) | (29 << 7) | 0x37
    new_lui = ((args.new_pmu_base >> 12) << 12) | (29 << 7) | 0x37
    old_lui_bytes = old_lui.to_bytes(4, "little")
    matches = [
        offset
        for offset in range(0, len(image) - 3, 4)
        if image[offset:offset + 4] == old_lui_bytes
    ]
    if len(matches) != 1:
        raise ValueError(f"expected one old PMU LUI, found {len(matches)}")
    image[matches[0]:matches[0] + 4] = new_lui.to_bytes(4, "little")
    args.output.write_bytes(image)

    print(
        f"patched CoreMark iterations {old_iterations} -> {args.iterations}; "
        f"seed4 VMA=0x{seed4_vma:08x}, file offset=0x{file_offset:x}; "
        f"PMU LUI patched at 0x{matches[0]:x}"
    )


if __name__ == "__main__":
    main()
