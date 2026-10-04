#!/usr/bin/env python3
"""Sync HotN3 Cast/Edited portraits into assets/cast + entities.json.

Rules:
- Prefer the MOST RECENT file when a character has multiple variants
- Update existing heroes' sprite/portrait/icon
- NEW named characters get a generic deck (Pauline template)
- Unnamed/hash files are skipped (logged)
- Naomi art updates Nero transform_* paths
"""

from __future__ import annotations

import json
import re
import shutil
from collections import deque
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
CAST = ROOT / "assets" / "cast"
CATALOG = ROOT / "addons" / "hotn3_entities" / "entities.json"
EDITED_DEFAULT = ROOT / "playtest_out" / "edited_cast"

TYPE_COLOR = {
    "BRUTO": (110, 28, 36, 255),
    "TECNICO": (224, 122, 47, 255),
    "PSICOLOGICO": (122, 62, 161, 255),
    "MENTAL": (229, 106, 168, 255),
    "PROJETIVO": (61, 77, 184, 255),
    "QUIMICO": (46, 196, 182, 255),
}

# Explicit newest picks from Windows LastWriteTime inventory (zip mtimes are unreliable).
# Keys are display/base names; values are exact filenames in Edited.
NEWEST_BY_BASE = {
    "Caçadora": "Caçadora.png",
    "Chaos": "Chaos.png",
    "Delírio": "Delírio 2.png",
    "Dr. Espantalho": "Dr. Espantalho.png",
    "Kabuki": "Kabuki.png",
    "Naomi": "Naomi 3.png",
    "Nero": "Nero 2.png",
    "Pauline": "Pailine 2.png",  # typo variant; newer than Pauline.png
    "Patrulheiro Rosa": "Patrulheiro Rosa.png",
    "Pesadelo Vivo": "Pesadelo Vivo.png",
    "Pessoa Planta": "Pessoa Planta 2.png",
    "Siren": "Siren.png",
    "Techna": "Techna.png",
}

# Map Edited base name -> entity id / role
NAME_MAP = {
    "Caçadora": {"id": "ent_cacadora", "role": "new", "name": "Caçadora", "type": "TECNICO", "row": "back",
                 "hp": 76, "attack": 31, "power": 29, "armor": 18, "escudo": 16},
    "Chaos": {"id": "ent_pietro_caos", "role": "update", "name": "Pietro"},
    "Delírio": {"id": "ent_delirio", "role": "update", "name": "Delírio"},
    "Dr. Espantalho": {"id": "ent_dr_espantalho", "role": "update", "name": "Dr. Espantalho"},
    "Kabuki": {"id": "ent_kabuki", "role": "update", "name": "Kabuki"},
    "Naomi": {"id": "ent_naomi", "role": "transform", "name": "Naomi", "owner": "ent_nero"},
    "Nero": {"id": "ent_nero", "role": "update", "name": "Nero"},
    "Pauline": {"id": "ent_pauline", "role": "update", "name": "Pauline"},
    "Patrulheiro Rosa": {"id": "ent_patrulheiro_rosa", "role": "update", "name": "Patrulheiro Rosa"},
    "Pesadelo Vivo": {"id": "ent_pesadelo_vivo", "role": "update", "name": "Pesadelo Vivo"},
    "Pessoa Planta": {"id": "ent_pessoa_planta", "role": "new", "name": "Pessoa Planta", "type": "QUIMICO", "row": "front",
                      "hp": 88, "attack": 27, "power": 32, "armor": 22, "escudo": 18},
    "Siren": {"id": "ent_siren", "role": "update", "name": "Siren"},
    "Techna": {"id": "ent_techna", "role": "update", "name": "Techna"},
}

SKIP_PATTERNS = [
    re.compile(r"^8zFgG\.", re.I),
    re.compile(r"^[A-Za-z0-9_-]{20,}\.(png|jpg|jpeg|webp)$", re.I),
]

SHARED_MANEUVER_POOL = [
    # Pool compartilhado — NÃO inventar manobras temáticas por nome de personagem.
    {"id": "manobra_golpe", "name": "Golpe", "class": "ATTACK", "target": "ENEMY",
     "actions": [["hit", "0"]], "reach": True, "stat": "attack", "unlock": "starting",
     "gain": 1, "tier": "inicial", "anim_self": ["Slash1"], "anim_target": ["Hit1"]},
    {"id": "manobra_guarda", "name": "Guarda", "class": "ESTADO", "target": "SELF",
     "actions": [["barrier", "2", "6"]], "reach": False,
     "stat": "armor", "unlock": "starting", "gain": 1, "tier": "inicial",
     "anim_self": ["buff"], "anim_target": ["Shield"]},
    {"id": "manobra_foco", "name": "Foco", "class": "ESTADO", "target": "SELF",
     "actions": [["self_status", "strengthened", "1"]], "reach": False, "stat": "power",
     "unlock": "starting", "gain": 1, "tier": "inicial", "anim_self": ["buff"], "anim_target": ["status"]},
    {"id": "manobra_rajada", "name": "Rajada", "class": "ATTACK", "target": "ENEMY",
     "actions": [["hit", "0"]], "reach": True, "stat": "power", "unlock": "starting",
     "gain": 1, "tier": "inicial", "anim_self": ["Special2"], "anim_target": ["HitSP2"]},
    {"id": "manobra_cura_rapida", "name": "Cura Rápida", "class": "ESTADO", "target": "ALLY",
     "actions": [["heal", "8"]], "reach": False, "stat": "power", "unlock": "starting",
     "gain": 1, "tier": "inicial", "anim_self": ["buff"], "anim_target": ["Recovery1"]},
    {"id": "manobra_impacto", "name": "Impacto", "class": "ATTACK", "target": "ENEMY",
     "actions": [["hit", "1"]], "reach": False, "stat": "attack", "unlock": "evolved",
     "gain": 2, "tier": "evoluida", "anim_self": ["Slash2"], "anim_target": ["Hit2"]},
    {"id": "manobra_barreira", "name": "Barreira", "class": "ESTADO", "target": "SELF",
     "actions": [["barrier", "2", "10"]], "reach": False,
     "stat": "armor", "unlock": "evolved", "gain": 1, "tier": "evoluida",
     "anim_self": ["buff"], "anim_target": ["Shield"]},
    {"id": "manobra_onda", "name": "Onda", "class": "ATTACK", "target": "ALL_ENEMIES",
     "actions": [["hit", "0"]], "reach": True, "stat": "power", "unlock": "evolved",
     "gain": 1, "tier": "evoluida", "anim_self": ["Special1"], "anim_target": ["Explosion1"]},
    {"id": "manobra_inspirar", "name": "Inspirar", "class": "ESTADO", "target": "ALL_ALLIES",
     "actions": [["heal", "6"]], "reach": False, "stat": "power", "unlock": "evolved",
     "gain": 1, "tier": "evoluida", "anim_self": ["buff"], "anim_target": ["Recovery2"]},
    {"id": "manobra_finisher", "name": "Finisher", "class": "ATTACK", "target": "ENEMY",
     "actions": [["hit", "2"], ["self_status", "strengthened", "1"]], "reach": False,
     "stat": "attack", "unlock": "evolved", "gain": 2, "tier": "evoluida",
     "anim_self": ["Slash3"], "anim_target": ["Blow1"]},
]
GENERIC_CARD_SPECS = SHARED_MANEUVER_POOL  # alias legado
def is_background(color, bg):
    r, g, b = color[:3]
    return abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) < 28


def punch_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    corners = [pixels[2, 2], pixels[width - 3, 2], pixels[2, height - 3], pixels[width - 3, height - 3]]
    bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1
        color = pixels[x, y]
        if not is_background(color, bg):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))
    for _pass in range(2):
        halo = []
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                color = pixels[x, y]
                if color[3] == 0:
                    continue
                if abs(color[0] - bg[0]) + abs(color[1] - bg[1]) + abs(color[2] - bg[2]) > 46:
                    continue
                if pixels[x - 1, y][3] == 0 or pixels[x + 1, y][3] == 0 or pixels[x, y - 1][3] == 0 or pixels[x, y + 1][3] == 0:
                    halo.append((x, y))
        for x, y in halo:
            pixels[x, y] = (0, 0, 0, 0)
    arr = np.asarray(image).copy()
    for _fringe in range(28):
        alpha = arr[:, :, 3]
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        magenta = (green <= 96) & (red >= 150) & (blue >= 130) & (((red + blue) // 2 - green) >= 90) & (alpha > 0)
        neighbor = np.zeros(alpha.shape, dtype=bool)
        neighbor[1:, :] |= alpha[:-1, :] == 0
        neighbor[:-1, :] |= alpha[1:, :] == 0
        neighbor[:, 1:] |= alpha[:, :-1] == 0
        neighbor[:, :-1] |= alpha[:, 1:] == 0
        kill = magenta & neighbor
        if not kill.any():
            break
        arr[kill, 3] = 0
    for _chroma in range(160):
        alpha = arr[:, :, 3]
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        chroma = (alpha > 0) & (green < 50) & (red > 190) & (blue > 200)
        neighbor = np.zeros(alpha.shape, dtype=bool)
        neighbor[1:, :] |= alpha[:-1, :] == 0
        neighbor[:-1, :] |= alpha[1:, :] == 0
        neighbor[:, 1:] |= alpha[:, :-1] == 0
        neighbor[:, :-1] |= alpha[:, 1:] == 0
        kill = chroma & neighbor
        if not kill.any():
            break
        arr[kill, 3] = 0
    arr[arr[:, :, 3] == 0, :3] = 0
    return Image.fromarray(arr, "RGBA")


def trim(image: Image.Image, pad: int = 12) -> Image.Image:
    bbox = image.getbbox()
    if not bbox:
        return image
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(image.width, bbox[2] + pad)
    bottom = min(image.height, bbox[3] + pad)
    return image.crop((left, top, right, bottom))


def fit_height(image: Image.Image, height: int) -> Image.Image:
    ratio = height / float(image.height)
    width = max(1, int(round(image.width * ratio)))
    return image.resize((width, height), Image.Resampling.LANCZOS)


def icon_for(hero_id: str, color) -> Image.Image:
    image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((8, 8, 248, 248), fill=(18, 20, 28, 255), outline=color, width=14)
    seed = sum(ord(ch) * (index + 3) for index, ch in enumerate(hero_id))
    shape = seed % 6
    ink = color
    if shape == 0:
        draw.polygon([(128, 48), (196, 168), (60, 168)], outline=ink, width=10)
    elif shape == 1:
        draw.ellipse((78, 70, 178, 186), outline=ink, width=10)
        draw.line((128, 54, 128, 202), fill=ink, width=8)
    elif shape == 2:
        draw.arc((64, 64, 192, 192), 20, 320, fill=ink, width=12)
        draw.ellipse((110, 110, 146, 146), fill=ink)
    elif shape == 3:
        draw.rectangle((84, 72, 172, 184), outline=ink, width=10)
        draw.line((84, 128, 172, 128), fill=ink, width=8)
    elif shape == 4:
        draw.regular_polygon((128, 128, 70), 6, outline=ink, width=10)
    else:
        draw.line((70, 180, 128, 60), fill=ink, width=12)
        draw.line((128, 60, 186, 180), fill=ink, width=12)
        draw.line((88, 130, 168, 130), fill=ink, width=8)
    return image


def process_art(source: Path, hero_id: str, type_name: str) -> dict:
    raw = Image.open(source).convert("RGBA")
    # If already largely transparent / cropped, punch may still help for solid BGs.
    alpha_ratio = (np.asarray(raw)[:, :, 3] < 16).mean()
    if alpha_ratio < 0.08:
        cut = trim(punch_background(raw))
    else:
        cut = trim(raw)
    if cut.getbbox() is None:
        cut = trim(raw)
    sprite = fit_height(cut, 400)
    portrait = fit_height(cut, 860)
    icon = icon_for(hero_id, TYPE_COLOR.get(type_name, (200, 200, 200, 255)))
    CAST.mkdir(parents=True, exist_ok=True)
    sprite_path = CAST / f"{hero_id}_sprite.png"
    portrait_path = CAST / f"{hero_id}_portrait.png"
    icon_path = CAST / f"{hero_id}_icon.png"
    sprite.save(sprite_path)
    portrait.save(portrait_path)
    icon.save(icon_path)
    return {
        "sprite": f"res://assets/cast/{hero_id}_sprite.png",
        "portrait": f"res://assets/cast/{hero_id}_portrait.png",
        "signature_icon": f"res://assets/cast/{hero_id}_icon.png",
        "sprite_size": sprite.size,
        "portrait_size": portrait.size,
    }


def ensure_shared_maneuver_pool(cards: dict) -> None:
    """Valida/insere o pool compartilhado de manobras genéricas (sem tema por nome)."""
    for spec in SHARED_MANEUVER_POOL:
        cid = spec["id"]
        cards[cid] = {
            "id": cid,
            "name": spec["name"],
            "owner": "shared_pool",
            "class": spec["class"],
            "target": spec["target"],
            "actions": spec["actions"],
            "reach": spec["reach"],
            "stat": spec["stat"],
            "rarity": "COMMON",
            "unlock": spec["unlock"],
            "exhaust": False,
            "gain": spec["gain"],
            "tier": spec["tier"],
            "anim_self": spec["anim_self"],
            "anim_target": spec["anim_target"],
            "anim_timing": "parallel",
            "shared_pool": True,
        }


def make_generic_cards(hero_id: str) -> tuple[list[dict], list[str], list[str]]:
    # Personagens sem kit customizado usam só o pool compartilhado (ids manobra_*).
    # Não cria cartas temáticas com o nome do herói.
    cards = []
    iniciais = []
    evoluidas = []
    for spec in SHARED_MANEUVER_POOL:
        cid = spec["id"]
        # cards list returned for report only; real defs live in shared pool
        cards.append({"id": cid, "shared_pool": True, "owner_ref": hero_id})
        if spec["tier"] == "inicial":
            iniciais.append(cid)
        else:
            evoluidas.append(cid)
    return cards, iniciais, evoluidas



def make_generic_hero(meta: dict, paths: dict) -> dict:
    hero_id = meta["id"]
    cards, iniciais, evoluidas = make_generic_cards(hero_id)
    pool = iniciais + evoluidas
    hero = {
        "id": hero_id,
        "name": meta["name"],
        "archetype": "Poder",
        "species": "Humano",
        "level_reference": 3,
        "power_reference": 80,
        "hp": meta["hp"],
        "attack": meta["attack"],
        "power": meta["power"],
        "armor": meta["armor"],
        "type": meta["type"],
        "row": meta["row"],
        "sprite": paths["sprite"],
        "portrait": paths["portrait"],
        "signature_icon": paths["signature_icon"],
        "passive": "",
        "pool": pool,
        "cards": list(iniciais),
        "iniciais": iniciais,
        "evoluidas": evoluidas,
        "desvantagem": "",
        "signature": {"name": "Reserva", "target": "SELF", "action": ["barreira", "1", "2"]},
        "tags": [{"name": "Genérico", "level": 1}],
        "escudo": meta.get("escudo", 16),
        "aprimoramento": "",
        "grupos": ["Genérico"],
        "biografia": f"{meta['name']} — personagem novo importado do Cast Edited (kit genérico).",
        "playable": True,
        "source_sheet": "edited_cast",
    }
    return hero, cards


def should_skip(filename: str) -> bool:
    for pat in SKIP_PATTERNS:
        if pat.search(filename):
            # keep if exact named map exists
            return True
    return False


def main() -> None:
    edited = Path(EDITED_DEFAULT)
    if not edited.is_dir():
        raise SystemExit(f"missing edited folder: {edited}")

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    heroes = catalog.setdefault("heroes", {})
    cards = catalog.setdefault("cards", {})
    ensure_shared_maneuver_pool(cards)

    report = {
        "updated": [],
        "created": [],
        "transform": [],
        "skipped": [],
        "marcell": "no Edited art — placeholders unchanged",
        "sources": {},
    }

    files = {p.name: p for p in edited.iterdir() if p.is_file()}

    # Skip unnamed hashes / known orphans
    for name in sorted(files):
        base = Path(name).stem
        if name in ("8zFgG.jpg",) or re.match(r"^[A-Za-z0-9_-]{20,}$", base):
            # 2kj0 is duplicate of Pessoa Planta.png — skip as unnamed
            report["skipped"].append(name)
            continue

    for base, filename in NEWEST_BY_BASE.items():
        src = files.get(filename)
        if src is None:
            report["skipped"].append(f"MISSING:{filename}")
            continue
        meta = NAME_MAP[base]
        hero_id = meta["id"]
        report["sources"][hero_id] = filename

        if meta["role"] == "transform":
            # Naomi art for Nero transform_* + standalone naomi asset files
            type_name = heroes.get("ent_nero", {}).get("type", "PROJETIVO")
            paths = process_art(src, "ent_naomi", type_name)
            nero = heroes.get("ent_nero")
            if nero is not None:
                nero["transform_name"] = "Naomi"
                nero["transform_sprite"] = paths["sprite"]
                nero["transform_portrait"] = paths["portrait"]
            report["transform"].append({"id": "ent_naomi", "via": "ent_nero.transform_*", "source": filename})
            continue

        if meta["role"] == "update":
            hero = heroes.get(hero_id)
            if hero is None:
                report["skipped"].append(f"NO_HERO:{hero_id}:{filename}")
                continue
            paths = process_art(src, hero_id, hero.get("type", "TECNICO"))
            hero["sprite"] = paths["sprite"]
            hero["portrait"] = paths["portrait"]
            hero["signature_icon"] = paths["signature_icon"]
            report["updated"].append({"id": hero_id, "name": hero.get("name", meta["name"]), "source": filename,
                                      "sprite": paths["sprite_size"], "portrait": paths["portrait_size"]})
            continue

        if meta["role"] == "new":
            paths = process_art(src, hero_id, meta["type"])
            if hero_id in heroes:
                # already exists — just refresh art
                hero = heroes[hero_id]
                hero["sprite"] = paths["sprite"]
                hero["portrait"] = paths["portrait"]
                hero["signature_icon"] = paths["signature_icon"]
                report["updated"].append({"id": hero_id, "name": hero.get("name"), "source": filename,
                                          "sprite": paths["sprite_size"], "portrait": paths["portrait_size"]})
            else:
                hero, new_cards = make_generic_hero(meta, paths)
                heroes[hero_id] = hero
                for card in new_cards:
                    cards[card["id"]] = card
                report["created"].append({"id": hero_id, "name": meta["name"], "source": filename,
                                          "deck": "generic", "sprite": paths["sprite_size"],
                                          "portrait": paths["portrait_size"]})
            continue

    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    out = ROOT / "playtest_out" / "edited_cast_sync_report.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
