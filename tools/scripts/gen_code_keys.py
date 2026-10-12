"""Gera tools/_code_keys.json: chaves de ação e status que o runtime reconhece (grep heurístico)."""
import json, re
from pathlib import Path
R = Path(__file__).resolve().parents[2]
acts, sts = set(), set()
for f in ["game/PackBridge.gd", "game/BattleState.gd", "addons/hotn3_entities/EntityCatalog.gd"]:
    p = R / f
    if not p.exists(): continue
    t = p.read_text(encoding="utf-8")
    for m in re.finditer(r'^\t+((?:"[a-z_0-9]+"(?:,\s*)?)+):\s*$', t, re.M):
        acts.update(re.findall(r'"([a-z_0-9]+)"', m.group(1)))
    for m in re.finditer(r'(?:status|stacks|_stack|add_stat|has_stat)\w*\(\s*(?:[\w.]+\s*,\s*)?"([a-z_]+)"', t):
        sts.add(m.group(1))
    for m in re.finditer(r'statuses(?:\.get)?\(\s*"([a-z_]+)"|statuses\["([a-z_]+)"\]', t):
        sts.add(m.group(1) or m.group(2))
lits = set()
for p in list((R / "game").rglob("*.gd")) + list((R / "addons").rglob("*.gd")):
    lits.update(re.findall(r'"([a-z_][a-z_0-9]*)"', p.read_text(encoding="utf-8", errors="replace")))
bs = (R / "game/BattleState.gd").read_text(encoding="utf-8")
removed = re.findall(r'"([a-z_]+)"', re.search(r"REMOVED_STATUSES := \[(.*?)\]", bs).group(1))
out = {"actions": sorted(acts), "literals": sorted(lits), "statuses": sorted(sts - set(removed)), "removed_statuses": removed}
(R / "tools/_code_keys.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
print(len(out["actions"]), "ações;", len(out["statuses"]), "status")
