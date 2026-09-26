#!/usr/bin/env python3
"""Mescla um patch do card_editor no entities.json.

Uso:
  python tools/merge_card_patch.py hotn3_cards_patch.json
  python tools/merge_card_patch.py hotn3_cards_patch.json --write
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "addons" / "hotn3_entities" / "entities.json"

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("patch")
    ap.add_argument("--write", action="store_true", help="Grava entities.json")
    ap.add_argument("--catalog", type=Path, default=CATALOG)
    args = ap.parse_args()
    patch = json.loads(Path(args.patch).read_text(encoding="utf-8"))
    cards = patch.get("cards") or {}
    if not cards:
        print("Patch sem cards", file=sys.stderr)
        return 1
    data = json.loads(args.catalog.read_text(encoding="utf-8"))
    before = len(data.get("cards", {}))
    data.setdefault("cards", {}).update(cards)
    # opcional: adicionar ids novos ao pool/cards do herói se faltarem
    heroes = data.get("heroes", {})
    for cid, card in cards.items():
        owner = card.get("owner")
        if owner and owner in heroes:
            h = heroes[owner]
            pool = list(h.get("pool", []))
            if cid not in pool:
                pool.append(cid)
                h["pool"] = pool
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    print(f"Cartas no patch: {len(cards)}")
    print(f"Catálogo: {before} -> {len(data['cards'])}")
    if args.write:
        args.catalog.write_text(text, encoding="utf-8")
        print(f"Gravado: {args.catalog}")
    else:
        print("(dry-run; passe --write para gravar)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
