#!/usr/bin/env python3
"""Mescla um patch do card_editor no entities.json (cartas e/ou heróis).

Normaliza: remove speed, garante escudo, Tipo/Arquétipo/Espécie/Nível.

Uso:
  python tools/merge_card_patch.py hotn3_cards_patch.json
  python tools/merge_card_patch.py hotn3_cards_patch.json --write
  python tools/merge_card_patch.py hotn3_cards_patch.json --write --art-dir ./baixados
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "addons" / "hotn3_entities" / "entities.json"
CARDS_DIR = ROOT / "assets" / "cards"


def _copy_art(art_dir: Path, cards: dict) -> int:
    """Copia PNGs do art_dir para assets/cards/ conforme campo art das cartas."""
    if not art_dir.is_dir():
        print(f"Pasta de arte inexistente: {art_dir}", file=sys.stderr)
        return 0
    CARDS_DIR.mkdir(parents=True, exist_ok=True)
    copied = 0
    # Indexa arquivos locais por nome e por stem
    by_name: dict[str, Path] = {}
    for p in art_dir.rglob("*"):
        if p.is_file() and p.suffix.lower() in {".png", ".webp", ".jpg", ".jpeg"}:
            by_name[p.name] = p
            by_name[p.stem] = p
    for cid, card in cards.items():
        art = str(card.get("art") or "")
        if not art:
            continue
        # res://assets/cards/<id>.png → <id>.png
        dest_name = Path(art.replace("\\", "/").split("/")[-1]).name
        if not dest_name:
            dest_name = f"{cid}.png"
        src = by_name.get(dest_name) or by_name.get(Path(dest_name).stem) or by_name.get(cid) or by_name.get(f"{cid}.png")
        if not src:
            print(f"  (arte não encontrada para {cid}: {dest_name})")
            continue
        dest = CARDS_DIR / dest_name
        if dest.suffix.lower() != src.suffix.lower():
            dest = CARDS_DIR / f"{Path(dest_name).stem}{src.suffix.lower()}"
        shutil.copy2(src, dest)
        print(f"  arte: {src.name} -> {dest.relative_to(ROOT)}")
        copied += 1
    return copied


def main() -> int:
    ap = argparse.ArgumentParser(description="Mescla patch do editor no entities.json")
    ap.add_argument("patch")
    ap.add_argument("--write", action="store_true", help="Grava entities.json")
    ap.add_argument("--catalog", type=Path, default=CATALOG)
    ap.add_argument(
        "--art-dir",
        type=Path,
        default=None,
        help="Pasta com PNGs baixados do editor; copia para assets/cards/ quando a carta tem art",
    )
    args = ap.parse_args()
    patch = __import__("json").loads(Path(args.patch).read_text(encoding="utf-8"))
    cards = patch.get("cards") or {}
    heroes = patch.get("heroes") or {}
    if not cards and not heroes:
        print("Patch sem cards nem heroes", file=sys.stderr)
        return 1
    data = __import__("json").loads(args.catalog.read_text(encoding="utf-8"))
    before_c = len(data.get("cards", {}))
    before_h = len(data.get("heroes", {}))
    if cards:
        data.setdefault("cards", {}).update(cards)
        heroes_map = data.setdefault("heroes", {})
        for cid, card in cards.items():
            owner = card.get("owner")
            if owner and owner in heroes_map:
                h = heroes_map[owner]
                pool = list(h.get("pool", []))
                if cid not in pool:
                    pool.append(cid)
                    h["pool"] = pool
    if heroes:
        data.setdefault("heroes", {}).update(heroes)
    # Normaliza heróis: sem speed; garante escudo / campos de identidade
    for _hid, h in data.get("heroes", {}).items():
        if not isinstance(h, dict):
            continue
        h.pop("speed", None)
        if "escudo" not in h:
            h["escudo"] = int(h.get("armor", 0) or 0)
        h.setdefault("archetype", "Nenhum")
        h.setdefault("species", "Humano")
        h.setdefault("level_reference", 1)
        h.setdefault("type", "TECNICO")
    # Cartas: custo XOR ganho se ambos vierem > 0
    for _cid, c in data.get("cards", {}).items():
        if not isinstance(c, dict):
            continue
        cost = int(c.get("cost", 0) or 0)
        gain = int(c.get("gain", 0) or 0)
        if cost > 0 and gain > 0:
            c.pop("gain", None)
    text = __import__("json").dumps(data, ensure_ascii=False, indent=2) + "\n"
    print(f"Cartas no patch: {len(cards)}")
    print(f"Heróis no patch: {len(heroes)}")
    print(f"Catálogo cartas: {before_c} -> {len(data.get('cards', {}))}")
    print(f"Catálogo heróis: {before_h} -> {len(data.get('heroes', {}))}")
    art_copied = 0
    if args.art_dir is not None and cards:
        art_copied = _copy_art(args.art_dir, cards)
        print(f"Arquivos de arte copiados: {art_copied}")
    if args.write:
        args.catalog.write_text(text, encoding="utf-8")
        print(f"Gravado: {args.catalog}")
    else:
        print("(dry-run; passe --write para gravar)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
