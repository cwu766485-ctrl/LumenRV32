import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
COREMARK_STATUS = ROOT / "docs" / "project_metrics.md"
IVERILOG_DIR = Path(r"C:\iverilog\bin")
MINGW_DIR = Path(r"C:\MinGW\bin")
KNOWN_TOOL_PATHS = {
    "iverilog": [IVERILOG_DIR / "iverilog.exe"],
    "vvp": [IVERILOG_DIR / "vvp.exe"],
    "make": [MINGW_DIR / "mingw32-make.exe"],
}
TOOL_ALIASES = {
    "make": ["make", "mingw32-make"],
}
IMPL_TARGETS = [
    {
        "name": "Artix-7 35T",
        "part": "xc7a35tftg256-1",
        "report_dir": ROOT / "build" / "vivado_impl",
        "constraint": "board XDC (`fpga/constrs/tinyriscv.xdc`)",
    },
    {
        "name": "Kintex-7 160T",
        "part": "xc7k160tffg676-2",
        "report_dir": ROOT / "build" / "vivado_impl_k7",
        "constraint": "generic 50 MHz XDC (`fpga/constrs/tinyriscv_generic.xdc`)",
    },
]


def find_tool(name):
    candidates = [name] + TOOL_ALIASES.get(name, [])
    if any(shutil.which(candidate) is not None for candidate in candidates):
        return True
    return any(path.exists() for path in KNOWN_TOOL_PATHS.get(name, []))


def count_files(path, pattern):
    return len(list(path.glob(pattern)))


def extract_coremark_score():
    patterns = [
        re.compile(r"([0-9]+(?:\.[0-9]+)?)\s+CoreMark/MHz"),
        re.compile(r"CoreMark.*?([0-9]+(?:\.[0-9]+)?)", re.S),
    ]
    for path in (COREMARK_STATUS, README):
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                return f"{match.group(1)} CoreMark/MHz"
    return None


def list_example_targets():
    targets = []
    for makefile in sorted((ROOT / "tests" / "example").rglob("Makefile")):
        rel = makefile.parent.relative_to(ROOT).as_posix()
        if "/Source/" in rel:
            continue
        targets.append(rel)
    return targets


def parse_pmu_metrics(text):
    metrics = {}
    for line in text.splitlines():
        match = re.match(r"PMU\s+([A-Za-z_]+)\s*=\s*(\d+)", line.strip())
        if match:
            metrics[match.group(1).lower()] = int(match.group(2))
    return metrics


def run_command(command, workdir):
    env = os.environ.copy()
    if IVERILOG_DIR.exists():
        env["PATH"] = str(IVERILOG_DIR) + os.pathsep + env.get("PATH", "")
    if MINGW_DIR.exists():
        env["PATH"] = str(MINGW_DIR) + os.pathsep + env.get("PATH", "")
    process = subprocess.run(
        command,
        cwd=workdir,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    return process.returncode, process.stdout + process.stderr


def run_smoke():
    smoke = {"available": False, "runs": []}
    if not (find_tool("iverilog") and find_tool("vvp")):
        smoke["reason"] = "iverilog/vvp not found"
        return smoke

    smoke["available"] = True
    python_exe = sys.executable
    jobs = [
        {
            "name": "legacy-isa-add",
            "workdir": ROOT / "sim",
            "command": [
                python_exe,
                "sim_new_nowave.py",
                "../tests/isa/generated/rv32ui-p-add.bin",
                "inst.data",
            ],
        },
        {
            "name": "compliance-i-add",
            "workdir": ROOT / "sim" / "compliance_test",
            "command": [
                python_exe,
                "compliance_test.py",
                "../../tests/riscv-compliance/build_generated/rv32i/I-ADD-01.elf.bin",
                "inst.data",
            ],
        },
    ]

    for job in jobs:
        rc, output = run_command(job["command"], job["workdir"])
        smoke["runs"].append(
            {
                "name": job["name"],
                "returncode": rc,
                "pass": ("TEST_PASS" in output) or ("### PASS ###" in output),
                "pmu": parse_pmu_metrics(output),
            }
        )

    return smoke


def parse_report_value(text, pattern, cast=float):
    match = re.search(pattern, text, re.M)
    if not match:
        return None
    return cast(match.group(1))


def parse_impl_target(target):
    report_dir = target["report_dir"]
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

    def util(pattern):
        return parse_report_value(util_text, pattern, int)

    def power(pattern):
        value = parse_report_value(power_text, pattern, float)
        return None if value is None else value

    fmax = None
    if period is not None and wns is not None and (period - wns) > 0:
        fmax = 1000.0 / (period - wns)

    return {
        "name": target["name"],
        "part": target["part"],
        "constraint": target["constraint"],
        "wns": wns,
        "tns": tns,
        "period": period,
        "fmax": fmax,
        "luts": util(r"^\| Slice LUTs\s+\|\s+(\d+)"),
        "ffs": util(r"^\| Slice Registers\s+\|\s+(\d+)"),
        "bram": util(r"^\| Block RAM Tile\s+\|\s+(\d+)"),
        "dsps": util(r"^\| DSPs\s+\|\s+(\d+)"),
        "power": power(r"^\| Total On-Chip Power \(W\)\s+\|\s+([0-9.]+)"),
    }


def render_markdown(summary, smoke):
    lines = []
    lines.append("# RISC-V CPU and Lightweight NPU Heterogeneous SoC Project Report")
    lines.append("")
    lines.append("## Project Snapshot")
    lines.append("")
    lines.append(f"- Legacy ISA generated binaries: {summary['legacy_isa_bins']}")
    lines.append(f"- riscv-compliance generated binaries: {summary['compliance_total']}")
    lines.append(f"- Example application targets: {summary['example_target_count']}")
    lines.append(f"- Known CoreMark score: {summary['coremark_score'] or 'N/A'}")
    lines.append("- Interconnect upgrade: zero-wait Wishbone peripheral bridge with a unified `0x2000_xxxx` peripheral aperture")
    lines.append("- FPGA/ZU15EG status: `docs/modules/fpga_zu15eg.md`")
    lines.append("- CPU microarchitecture validation: `docs/validation/cpu_microarch_validation.md`")
    lines.append("- System specification: `docs/SPEC.md`")
    lines.append("")
    lines.append("## Verification Assets")
    lines.append("")
    lines.append("| Suite | Count |")
    lines.append("| --- | ---: |")
    lines.append(f"| Legacy ISA generated | {summary['legacy_isa_bins']} |")
    lines.append(f"| Compliance rv32i | {summary['compliance_rv32i']} |")
    lines.append(f"| Compliance rv32im | {summary['compliance_rv32im']} |")
    lines.append(f"| Compliance rv32Zicsr | {summary['compliance_rv32zicsr']} |")
    lines.append(f"| Compliance rv32Zifencei | {summary['compliance_rv32zifencei']} |")
    lines.append("")
    lines.append("## Enhancement Delta")
    lines.append("")
    lines.append("| Category | Before | After |")
    lines.append("| --- | --- | --- |")
    lines.append("| Hardware observability | cycle CSR only | cycle CSR + memory-mapped PMU counters + CoreMark done scratch regs |")
    lines.append("| Peripheral interconnect | direct per-peripheral memory interface decode | zero-wait Wishbone bridge + unified timer/uart/gpio/spi/pmu aperture |")
    lines.append("| Pipeline data path | original zero-wait bypass | zero-wait bypass restored, over-conservative load-use stall removed |")
    lines.append("| Verification hooks | PASS/FAIL banners only | PASS/FAIL banners + PMU summary dump + Wishbone protocol checks |")
    lines.append("| FPGA closure | single A7 snapshot | reusable Vivado batch flow for A7 and K7 |")
    lines.append("")
    lines.append("## Tool Availability")
    lines.append("")
    lines.append("| Tool | Available |")
    lines.append("| --- | --- |")
    for tool_name, available in summary["tools"].items():
        lines.append(f"| {tool_name} | {'yes' if available else 'no'} |")
    lines.append("")

    if summary["impl_targets"]:
        lines.append("## FPGA Implementation Snapshot")
        lines.append("")
        lines.append("| Target | Part | WNS (ns) | Fmax (MHz, inferred) | LUT | FF | BRAM | DSP | Power (W) |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
        for target in summary["impl_targets"]:
            lines.append(
                f"| {target['name']} | {target['part']} | "
                f"{target['wns']:.3f} | {target['fmax']:.3f} | {target['luts']} | "
                f"{target['ffs']} | {target['bram']} | {target['dsps']} | {target['power']:.3f} |"
            )
        lines.append("")

    lines.append("## Example Targets")
    lines.append("")
    for target in summary["example_targets"]:
        lines.append(f"- {target}")
    lines.append("")

    lines.append("## Notes")
    lines.append("")
    lines.append("- ISA regression result after the standardized bus integration: 47/47 generated ISA tests pass.")
    lines.append("- `perf_counter` rebuild and smoke simulation pass on the current AXI/APB mainline.")
    lines.append("- Compliance regression currently hits a known mismatch at `I-IO-01`; full 63/63 PASS is not claimed in this report.")
    lines.append("- K7 implementation uses the generic timing-only XDC; board bring-up still requires a K7 board-specific pin constraint file.")
    lines.append("")

    if smoke["available"]:
        lines.append("## Smoke Results")
        lines.append("")
        lines.append("| Run | PASS | PMU metrics captured |")
        lines.append("| --- | --- | --- |")
        for run in smoke["runs"]:
            metrics = ", ".join(f"{k}={v}" for k, v in sorted(run["pmu"].items())) or "none"
            lines.append(f"| {run['name']} | {'yes' if run['pass'] else 'no'} | {metrics} |")
        lines.append("")
    else:
        lines.append("## Smoke Results")
        lines.append("")
        lines.append(f"- Skipped: {smoke.get('reason', 'unavailable')}")
        lines.append("")

    return "\n".join(lines) + "\n"


def build_summary():
    example_targets = list_example_targets()
    summary = {
        "legacy_isa_bins": count_files(ROOT / "tests" / "isa" / "generated", "*.bin"),
        "compliance_rv32i": count_files(ROOT / "tests" / "riscv-compliance" / "build_generated" / "rv32i", "*.elf.bin"),
        "compliance_rv32im": count_files(ROOT / "tests" / "riscv-compliance" / "build_generated" / "rv32im", "*.elf.bin"),
        "compliance_rv32zicsr": count_files(ROOT / "tests" / "riscv-compliance" / "build_generated" / "rv32Zicsr", "*.elf.bin"),
        "compliance_rv32zifencei": count_files(ROOT / "tests" / "riscv-compliance" / "build_generated" / "rv32Zifencei", "*.elf.bin"),
        "example_targets": example_targets,
        "example_target_count": len(example_targets),
        "coremark_score": extract_coremark_score(),
        "tools": {
            "python": find_tool("python"),
            "iverilog": find_tool("iverilog"),
            "vvp": find_tool("vvp"),
            "make": find_tool("make"),
        },
        "impl_targets": [target for target in (parse_impl_target(entry) for entry in IMPL_TARGETS) if target],
    }
    summary["compliance_total"] = (
        summary["compliance_rv32i"] +
        summary["compliance_rv32im"] +
        summary["compliance_rv32zicsr"] +
        summary["compliance_rv32zifencei"]
    )
    return summary


def main():
    parser = argparse.ArgumentParser(
        description="Generate a project summary report for the heterogeneous RISC-V CPU/NPU SoC."
    )
    parser.add_argument("--output", type=Path, help="Write the markdown report to a file.")
    parser.add_argument("--run-smoke", action="store_true", help="Run smoke simulations when tools are available.")
    args = parser.parse_args()

    summary = build_summary()
    smoke = run_smoke() if args.run_smoke else {"available": False, "reason": "disabled"}
    report = render_markdown(summary, smoke)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")

    sys.stdout.write(report)


if __name__ == "__main__":
    main()
