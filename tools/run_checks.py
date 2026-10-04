"""Run static checks; optionally import and test the project in Godot."""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", help="Path to a compatible Godot 4.6 executable")
args = parser.parse_args()


def run(*command, timeout=240, capture_godot=False):
    print("+", *command, flush=True)
    if capture_godot:
        log_path = ROOT / "tools" / "_last_godot.log"
        with log_path.open("w", encoding="utf-8", errors="replace") as log:
            completed = subprocess.run(
                command, cwd=ROOT, check=False, timeout=timeout,
                stdout=log, stderr=subprocess.STDOUT,
            )
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        if completed.returncode != 0 or "CrashHandlerException" in log_text:
            print(log_text[-4000:], flush=True)
            raise subprocess.CalledProcessError(completed.returncode, command)
        # Surface OK lines for the suite summary.
        for line in log_text.splitlines():
            if line.startswith("OK:") or line.startswith("MERGE ") or line.startswith("PENDENTE"):
                print(line, flush=True)
    else:
        subprocess.run(command, cwd=ROOT, check=True, timeout=timeout)


run(sys.executable, "tools/lint_gd.py")
run(sys.executable, "tools/verify_effect_catalog.py")
run(sys.executable, "tools/verify_content.py")
run(sys.executable, "tools/verify_assets.py")
engine = args.godot or shutil.which("godot") or shutil.which("godot4")
if not engine:
    print("PENDENTE: Godot 4.6 indisponível; testes de parsing, cena e combate não executados.")
    sys.exit(0)

version = subprocess.run([engine, "--version"], cwd=ROOT, check=True, capture_output=True, text=True, timeout=15).stdout.strip()
if not re.match(r"^4\.6(?:\.|\D|$)", version):
    sys.exit(f"Godot 4.6 é necessário; executável encontrado: {version}")

godot_base = (engine, "--headless", "--accessibility", "disabled", "--path", str(ROOT))
run(*godot_base, "--editor", "--import", "--quit", capture_godot=True)
for script in ("EngineSmoke.gd", "StatusSmoke.gd", "CampaignSmoke.gd", "SceneSmoke.gd", "MergeSmoke.gd"):
    run(*godot_base, "-s", f"res://tools/{script}", capture_godot=True)
print("OK: verificações estáticas, importação e testes de combate/cena")
