import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TARGETS = [
    (
        "Artix-7 35T",
        "xc7a35tftg256-1",
        ROOT / "build" / "vivado_impl",
        "board XDC (`fpga/constrs/tinyriscv.xdc`)",
    ),
    (
        "Kintex-7 160T",
        "xc7k160tffg676-2",
        ROOT / "build" / "vivado_impl_k7",
        "generic 50 MHz XDC (`fpga/constrs/tinyriscv_generic.xdc`)",
    ),
]


def parse_report_value(text, pattern, cast=float):
    match = re.search(pattern, text, re.M)
    if not match:
        return None
    return cast(match.group(1))


def parse_target(name, part, report_dir, constraint):
    timing_path = report_dir / "post_route_timing.rpt"
    util_path = report_dir / "post_route_utilization.rpt"
    power_path = report_dir / "post_route_power.rpt"
    if not (timing_path.exists() and util_path.exists()):
        return None

    timing_text = timing_path.read_text(encoding="utf-8", errors="ignore")
    util_text = util_path.read_text(encoding="utf-8", errors="ignore")
    power_text = power_path.read_text(encoding="utf-8", errors="ignore") if power_path.exists() else ""

    slack_match = re.search(
        r"WNS\(ns\).*?\n\s*-+\s+-+.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+",
        timing_text,
        re.S,
    )
    period = parse_report_value(timing_text, r"sys_clk_pin\s+\{[^}]+\}\s+([0-9.]+)\s+[0-9.]+", float)
    wns = float(slack_match.group(1)) if slack_match else None
    tns = float(slack_match.group(2)) if slack_match else None
    fmax = None
    if period is not None and wns is not None and (period - wns) > 0:
        fmax = 1000.0 / (period - wns)

    return {
        "name": name,
        "part": part,
        "report_dir": report_dir.relative_to(ROOT).as_posix(),
        "constraint": constraint,
        "period": period,
        "wns": wns,
        "tns": tns,
        "fmax": fmax,
        "luts": parse_report_value(util_text, r"^\| Slice LUTs\s+\|\s+(\d+)", int),
        "ffs": parse_report_value(util_text, r"^\| Slice Registers\s+\|\s+(\d+)", int),
        "bram": parse_report_value(util_text, r"^\| Block RAM Tile\s+\|\s+(\d+)", int),
        "dsps": parse_report_value(util_text, r"^\| DSPs\s+\|\s+(\d+)", int),
        "power": parse_report_value(power_text, r"^\| Total On-Chip Power \(W\)\s+\|\s+([0-9.]+)", float),
    }


def render_markdown(targets):
    lines = []
    lines.append("# FPGA Target Matrix")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Target | Part | Constraint | WNS (ns) | TNS (ns) | Fmax (MHz, inferred) | LUT | FF | BRAM | DSP | Power (W) |")
    lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
    for target in targets:
        lines.append(
            f"| {target['name']} | {target['part']} | {target['constraint']} | "
            f"{target['wns']:.3f} | {target['tns']:.3f} | {target['fmax']:.3f} | "
            f"{target['luts']} | {target['ffs']} | {target['bram']} | {target['dsps']} | {target['power']:.3f} |"
        )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- `Fmax` is inferred from the `50 MHz` timing constraint and post-route `WNS`: `1000 / (period_ns - WNS_ns)`.")
    lines.append("- The K7 run proves RTL portability at implementation level, but real board validation still needs a K7 board-specific pinout XDC.")
    lines.append("- Reports come from Vivado `2024.1` non-project batch runs under `build/vivado_impl*`.")
    lines.append("")
    lines.append("## Report Roots")
    lines.append("")
    for target in targets:
        lines.append(f"- {target['name']}: `{target['report_dir']}`")
    lines.append("")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Generate a markdown comparison of FPGA post-route reports.")
    parser.add_argument("--output", type=Path, help="Write the markdown table to a file.")
    args = parser.parse_args()

    targets = [parsed for parsed in (parse_target(*entry) for entry in DEFAULT_TARGETS) if parsed]
    report = render_markdown(targets)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report, end="")


if __name__ == "__main__":
    main()
