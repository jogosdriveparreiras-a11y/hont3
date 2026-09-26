#!/usr/bin/env python3
"""Recorta os desenhos do elenco, gera ícones, HUD e liga os paths no pacote."""

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = {
    "ent_fate": "58c79c25-d27b-4070-953b-3c4edb34130e.jpg",
    "ent_evelyn_graves": "79cf1f04-7da9-425e-bc9c-5bdc22e4a1d5.jpg",
    "ent_madelyn": "1d96fcd3-af86-49ed-a812-daaeabf9b9c6.jpg",
    "ent_mingau_o_feiticeiro": "ac47d166-1026-475b-b61a-cf365369a7ab.jpg",
    "ent_kabuki": "62824325-d807-49fb-8822-25780f328346.jpg",
    "ent_hynda_valdtagen": "9a20f310-fdad-4814-90f2-6e20899cf72b.jpg",
    "ent_dominika_seur": "35e03814-dcef-4d46-b690-fcc0c77ba08b.jpg",
    "ent_techna": "552cb77e-62cb-496b-adc1-59802a21ce28.jpg",
    "ent_adam": "23eba798-e19a-4f77-b1cf-972005e3a276.jpg",
    "ent_akuji": "a959722d-a3c6-4bfc-a5f1-d9a0abcc8809.jpg",
    "ent_alistair": "d507c797-c34e-4219-90dc-69d6912598e5.jpg",
    "ent_alyssa_wine": "2e574aed-0a01-461d-8cf6-cb7fd3dddbeb.jpg",
    "ent_ashlee": "83425d15-b56a-43f5-b047-9cb21ffd59f0.jpg",
    "ent_daeva": "5dd80dfc-fd1c-4a0c-a86c-0c03b3d3677c.jpg",
    "ent_damian_alrosa": "347cfd43-502d-4e5a-b8b6-3e5f9e35bff4.jpg",
    "ent_konrad": "a65fd6ac-b487-4db0-93cf-7114b69ce178.jpg",
    "ent_alexis": "a009a346-bd8a-4d2d-81f3-9dbaf375a417.jpg",
    "ent_dylan": "72601dc6-be21-4bf6-985b-c34c759c5c75.jpg",
    "ent_leona": "b63c05c7-e0f0-40c7-a6f7-fb2bcb5f9556.jpg",
    "ent_lust": "321b9d43-830f-4401-8f32-f7b10fe96f5a.jpg",
    "ent_mutante_generico": "be9c0a2f-fc04-4d71-b059-116c5dddf6d2.jpg",
    "ent_nero": "cfc7cf8d-e8fc-481f-b442-77442056d902.jpg",
    "ent_niu_valdtagen": "a38c552d-24e2-411d-a02d-b143a9650ed7.jpg",
    "ent_pesadelo_vivo": "4235c47c-7100-4f87-97d7-1744b88dc7d2.jpg",
    "ent_pietro_caos": "f89eda6e-83c2-4cb3-91b8-0b27b358df01.jpg",
    "ent_quasar": "3a0d10de-84ee-47b1-ae8c-9133718e78d0.jpg",
    "ent_taylor": "52ca0233-d27d-4698-befc-96efe0a3ea4a.jpg",
}
TYPE_COLOR = {
    "BRUTO": (110, 28, 36, 255),
    "TECNICO": (224, 122, 47, 255),
    "PSICOLOGICO": (122, 62, 161, 255),
    "MENTAL": (229, 106, 168, 255),
    "PROJETIVO": (61, 77, 184, 255),
    "QUIMICO": (46, 196, 182, 255),
}
ART = Path("/workspace/artifacts/imagine_images")
CAST = ROOT / "assets" / "cast"
UI = ROOT / "assets" / "ui"
ITEMS = ROOT / "assets" / "items"
DEEP_DESPILL = {"ent_madelyn", "ent_niu_valdtagen", "ent_evelyn_graves"}
CLEAR_BG = {"ent_niu_valdtagen", "ent_evelyn_graves"}


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


def deep_despill(image: Image.Image) -> Image.Image:
    arr = np.asarray(image.convert("RGBA")).copy()
    for _step in range(240):
        alpha = arr[:, :, 3]
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        chroma = (alpha > 0) & (green < 130) & (red > 140) & (blue > 120) & (((red + blue) // 2 - green) > 80)
        neighbor = np.zeros(alpha.shape, dtype=bool)
        neighbor[1:, :] |= alpha[:-1, :] == 0
        neighbor[:-1, :] |= alpha[1:, :] == 0
        neighbor[:, 1:] |= alpha[:, :-1] == 0
        neighbor[:, :-1] |= alpha[:, 1:] == 0
        kill = chroma & neighbor
        if not kill.any():
            break
        arr[kill] = 0
    arr[arr[:, :, 3] == 0, :3] = 0
    return Image.fromarray(arr, "RGBA")


def clear_near_bg(image: Image.Image, bg, limit: int = 55) -> Image.Image:
    arr = np.asarray(image.convert("RGBA")).copy()
    red = arr[:, :, 0].astype(np.int16)
    green = arr[:, :, 1].astype(np.int16)
    blue = arr[:, :, 2].astype(np.int16)
    near = (arr[:, :, 3] > 0) & (np.abs(red - bg[0]) + np.abs(green - bg[1]) + np.abs(blue - bg[2]) < limit)
    arr[near] = 0
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


def ui_textures() -> None:
    UI.mkdir(parents=True, exist_ok=True)
    panel = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(panel)
    draw.rounded_rectangle((4, 4, 251, 251), 28, fill=(16, 18, 28, 230), outline=(212, 168, 92, 255), width=8)
    draw.rounded_rectangle((18, 18, 237, 237), 18, outline=(90, 70, 48, 255), width=3)
    panel.save(UI / "panel.png")
    button = Image.new("RGBA", (256, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(button)
    draw.rounded_rectangle((2, 2, 253, 93), 16, fill=(36, 28, 22, 245), outline=(214, 170, 96, 255), width=4)
    button.save(UI / "button.png")
    header = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(header)
    draw.rounded_rectangle((0, 0, 511, 127), 18, fill=(12, 14, 24, 220), outline=(196, 154, 84, 255), width=6)
    header.save(UI / "header.png")
    bar = Image.new("RGBA", (256, 28), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bar)
    draw.rounded_rectangle((0, 0, 255, 27), 8, fill=(20, 16, 16, 255), outline=(120, 90, 60, 255), width=2)
    bar.save(UI / "bar_bg.png")
    fill = Image.new("RGBA", (256, 28), (0, 0, 0, 0))
    draw = ImageDraw.Draw(fill)
    draw.rounded_rectangle((2, 2, 253, 25), 7, fill=(176, 48, 42, 255))
    fill.save(UI / "bar_fill.png")


def item_textures() -> None:
    ITEMS.mkdir(parents=True, exist_ok=True)
    gray = (150, 154, 162, 255)

    def canvas():
        image = Image.new("RGBA", (512, 768), (28, 30, 36, 255))
        return image, ImageDraw.Draw(image)

    potion, draw = canvas()
    draw.rounded_rectangle((210, 180, 300, 250), 12, fill=gray)
    draw.ellipse((150, 240, 360, 560), fill=(120, 40, 48, 255), outline=gray, width=10)
    potion.save(ITEMS / "potion.png")
    bomb, draw = canvas()
    draw.ellipse((140, 220, 370, 520), fill=(70, 72, 78, 255), outline=gray, width=10)
    draw.line((255, 160, 255, 230), fill=gray, width=12)
    draw.ellipse((240, 130, 280, 170), fill=(200, 90, 40, 255))
    bomb.save(ITEMS / "bomb.png")
    antidote, draw = canvas()
    draw.rounded_rectangle((190, 200, 320, 520), 40, fill=(40, 110, 90, 255), outline=gray, width=10)
    draw.rectangle((230, 150, 280, 210), fill=gray)
    antidote.save(ITEMS / "antidote.png")
    generic, draw = canvas()
    draw.rounded_rectangle((150, 220, 360, 540), 30, outline=gray, width=16)
    draw.ellipse((210, 160, 300, 250), outline=gray, width=12)
    generic.save(ITEMS / "item_icon.png")


def main() -> None:
    CAST.mkdir(parents=True, exist_ok=True)
    ui_textures()
    item_textures()
    catalog_path = ROOT / "addons" / "hotn3_entities" / "entities.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    missing = []
    for hero_id, filename in SRC.items():
        source = ART / filename
        if not source.is_file():
            missing.append(hero_id)
            continue
        raw = Image.open(source).convert("RGBA")
        corner = np.asarray(raw)
        bg = tuple(int(corner[2, 2, i]) for i in range(3))
        cut = trim(punch_background(raw))
        if hero_id in DEEP_DESPILL:
            cut = deep_despill(cut)
        if hero_id in CLEAR_BG:
            cut = clear_near_bg(cut, bg)
        sprite = fit_height(cut, 400)
        portrait = fit_height(cut, 860)
        sprite.save(CAST / f"{hero_id}_sprite.png")
        portrait.save(CAST / f"{hero_id}_portrait.png")
        hero = catalog["heroes"][hero_id]
        icon = icon_for(hero_id, TYPE_COLOR.get(hero.get("type", "TECNICO"), (200, 200, 200, 255)))
        icon.save(CAST / f"{hero_id}_icon.png")
        hero["sprite"] = f"res://assets/cast/{hero_id}_sprite.png"
        hero["portrait"] = f"res://assets/cast/{hero_id}_portrait.png"
        hero["signature_icon"] = f"res://assets/cast/{hero_id}_icon.png"
        print(hero_id, sprite.size)
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if missing:
        raise SystemExit("missing " + ", ".join(missing))
    print("cast", len(SRC))


if __name__ == "__main__":
    main()
