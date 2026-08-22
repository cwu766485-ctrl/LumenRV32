import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IVERILOG_DIR = Path(r"C:\iverilog\bin")
IVERILOG = IVERILOG_DIR / "iverilog.exe"
VVP = IVERILOG_DIR / "vvp.exe"


def require_tools():
    missing = [str(path) for path in (IVERILOG, VVP) if not path.exists()]
    if missing:
        raise SystemExit(f"missing required simulation tools: {', '.join(missing)}")


def copy_subset(dst: Path):
    for name in ("rtl", "tb", "sim", "tools"):
        shutil.copytree(ROOT / name, dst / name, dirs_exist_ok=True)


def patch_baseline_id(id_path: Path):
    lines = id_path.read_text(encoding="utf-8").splitlines()
    patched = []
    replacing = False
    for line in lines:
        if "wire ex_is_load =" in line:
            replacing = True
            patched.extend([
                "    wire ex_is_load = 1'b0;",
                "    wire reg1_forward_en = 1'b0;",
                "    wire reg2_forward_en = 1'b0;",
                "    wire[`RegBus] reg1_data = reg1_rdata_i;",
                "    wire[`RegBus] reg2_data = reg2_rdata_i;",
                "    wire load_use_hazard = `HoldDisable;",
            ])
            continue
        if replacing:
            if "wire load_use_hazard =" in line:
                replacing = False
            continue
        patched.append(line)
    id_path.write_text("\n".join(patched) + "\n", encoding="utf-8")


def build_workspace(dst: Path, baseline: bool):
    copy_subset(dst)
    if baseline:
        patch_baseline_id(dst / "rtl" / "core" / "id.v")


def compile_workspace(workspace: Path):
    env = os.environ.copy()
    env["PATH"] = str(IVERILOG_DIR) + os.pathsep + env.get("PATH", "")
    subprocess.run(
        [sys.executable, "compile_rtl.py", ".."],
        cwd=workspace / "sim",
        env=env,
        check=True,
    )


def bin_to_mem(bin_path: Path, workspace: Path):
    subprocess.run(
        [sys.executable, str(workspace / "tools" / "BinToMem_CLI.py"), str(bin_path), str(workspace / "sim" / "inst.data")],
        cwd=workspace,
        check=True,
    )


def run_case(workspace: Path):
    proc = subprocess.run(
        [str(VVP), "out.vvp"],
        cwd=workspace / "sim",
        check=True,
        capture_output=True,
        text=True,
    )
    return parse_metrics(proc.stdout)


def parse_metrics(text: str):
    metrics = {}
    for key in ("cycle", "inst", "jump", "load", "store", "hold", "interrupt", "div_wait"):
        match = re.search(rf"PMU {key}\s*=\s*(\d+)", text)
        metrics[key] = int(match.group(1)) if match else None
    metrics["pass"] = "TEST_PASS" in text
    metrics["cpi"] = round(metrics["cycle"] / metrics["inst"], 4) if metrics["cycle"] and metrics["inst"] else None
    return metrics


def compare_cases(case_bins):
    with tempfile.TemporaryDirectory(prefix="tinyriscv-pipeline-") as temp_dir:
        temp_root = Path(temp_dir)
        current_ws = temp_root / "current"
        baseline_ws = temp_root / "baseline"
        build_workspace(current_ws, baseline=False)
        build_workspace(baseline_ws, baseline=True)
        compile_workspace(current_ws)
        compile_workspace(baseline_ws)

        rows = []
        for bin_path in case_bins:
            abs_bin = (ROOT / bin_path).resolve()
            bin_to_mem(abs_bin, current_ws)
            current = run_case(current_ws)
            bin_to_mem(abs_bin, baseline_ws)
            baseline = run_case(baseline_ws)
            rows.append({
                "case": bin_path,
                "baseline": baseline,
                "current": current,
            })
        return rows


def render_markdown(rows):
    lines = [
        "# Pipeline Comparison",
        "",
        "| Case | Baseline CPI | Current CPI | Delta CPI | Baseline Hold | Current Hold | Delta Hold | Result |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in rows:
        base = row["baseline"]
        curr = row["current"]
        delta_cpi = None if base["cpi"] is None or curr["cpi"] is None else round(curr["cpi"] - base["cpi"], 4)
        delta_hold = None if base["hold"] is None or curr["hold"] is None else curr["hold"] - base["hold"]
        result = "PASS" if base["pass"] and curr["pass"] else "FAIL"
        lines.append(
            f"| `{row['case']}` | {fmt(base['cpi'])} | {fmt(curr['cpi'])} | {fmt(delta_cpi)} | "
            f"{fmt(base['hold'])} | {fmt(curr['hold'])} | {fmt(delta_hold)} | {result} |"
        )
    lines.extend([
        "",
        "| Case | Baseline Cycle | Current Cycle | Baseline Inst | Current Inst | Baseline Load | Current Load |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ])
    for row in rows:
        base = row["baseline"]
        curr = row["current"]
        lines.append(
            f"| `{row['case']}` | {fmt(base['cycle'])} | {fmt(curr['cycle'])} | {fmt(base['inst'])} | "
            f"{fmt(curr['inst'])} | {fmt(base['load'])} | {fmt(curr['load'])} |"
        )
    return "\n".join(lines) + "\n"


def fmt(value):
    return "-" if value is None else str(value)


def main():
    parser = argparse.ArgumentParser(description="Compare current pipeline against a baseline without decode forwarding/load-use stall.")
    parser.add_argument("cases", nargs="+", help="relative bin paths from repo root")
    parser.add_argument("--output", help="write markdown report to file")
    args = parser.parse_args()

    require_tools()
    rows = compare_cases(args.cases)
    report = render_markdown(rows)
    if args.output:
        output = (ROOT / args.output).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()
