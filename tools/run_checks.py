"""Run static checks; optionally import and test the project in Godot."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", help="Path to a compatible Godot 4.6 executable")
args = parser.parse_args()


def run(*command):
    print("+", *command, flush=True)
    subprocess.run(command, cwd=ROOT, check=True, timeout=120)


run(sys.executable, "tools/lint_gd.py")
run(sys.executable, "tools/verify_content.py")
engine = args.godot or shutil.which("godot") or shutil.which("godot4")
if not engine:
    print("PENDENTE: Godot 4.6 indisponível; testes de parsing, cena e combate não executados.")
    sys.exit(0)

run(engine, "--headless", "--path", str(ROOT), "--editor", "--import", "--quit")
for script in ("StatusSmoke.gd", "SceneSmoke.gd"):
    run(engine, "--headless", "--path", str(ROOT), "-s", f"res://tools/{script}")
print("OK: verificações estáticas, importação e testes de combate/cena")
