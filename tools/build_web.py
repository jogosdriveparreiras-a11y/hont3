"""Validate and export a web build when Godot 4.6 and templates are available."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", help="Godot 4.6 editor executable")
args = parser.parse_args()
engine = args.godot or shutil.which("godot") or shutil.which("godot4")
if not engine:
    sys.exit("Godot 4.6 indisponível: exportação não executada.")

subprocess.run([sys.executable, str(ROOT / "tools/run_checks.py"), "--godot", engine], cwd=ROOT, check=True)
target = ROOT / "dist/HotN3-web.zip"
target.parent.mkdir(exist_ok=True)
subprocess.run([engine, "--headless", "--path", str(ROOT), "--export-release", "Web", str(target)], cwd=ROOT, check=True, timeout=240)
if not target.is_file() or target.stat().st_size == 0:
    sys.exit("Godot não produziu o pacote web.")
print(f"OK: exportação web criada em {target}")
