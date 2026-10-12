"""Reconstrói partes geradas de tools/card_editor.html (idempotente):
- EMBEDDED_ENTITIES  <- addons/hotn3_entities/entities.json (inclui bloco design)
- CODE_KEYS          <- tools/_code_keys.json (rode gen_code_keys.py antes)
- módulo de design   <- tools/editor_design_module.js
Uso: python tools/scripts/gen_code_keys.py && python tools/scripts/build_editor.py"""
import json, re
from pathlib import Path
R = Path(__file__).resolve().parents[2]
H = R / "tools/card_editor.html"
s = H.read_text(encoding="utf-8")
ent = json.loads((R / "addons/hotn3_entities/entities.json").read_text(encoding="utf-8"))
emb = "const EMBEDDED_ENTITIES = " + json.dumps(ent, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/") + ";"
s = re.sub(r"^const EMBEDDED_ENTITIES = .*;$", lambda m: emb, s, count=1, flags=re.M)
keys = json.loads((R / "tools/_code_keys.json").read_text(encoding="utf-8"))
ck = "window.CODE_KEYS = " + json.dumps(keys, separators=(",", ":")) + ";"
if "window.CODE_KEYS = " in s:
    s = re.sub(r"^window\.CODE_KEYS = .*;$", lambda m: ck, s, count=1, flags=re.M)
else:
    s = s.replace(emb, emb + "\n" + ck, 1)
mod = (R / "tools/editor_design_module.js").read_text(encoding="utf-8").strip()
if "/*DESIGN_MODULE_BEGIN*/" in s:
    s = re.sub(r"/\*DESIGN_MODULE_BEGIN\*/.*?/\*DESIGN_MODULE_END\*/", lambda m: mod, s, flags=re.S)
else:
    s = s.replace("\ntry {\n  wire();", "\n" + mod + "\n\ntry {\n  wire();", 1)
H.write_text(s, encoding="utf-8")
print("ok", len(s))
