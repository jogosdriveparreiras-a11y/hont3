"""Detect undocumented changes in artwork and keep removed legacy files out."""

from hashlib import sha256
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = (root / "ASSETS.md").read_text(encoding="utf-8")
images = sorted(root.glob("*.png"))
assert len(images) == 8, "Sprite count changed; update the provenance record"
for image in images:
    digest = sha256(image.read_bytes()).hexdigest()
    assert f"`{image.name}` | `{digest}`" in manifest, image.name
for obsolete in ("AppleGaramond.ttf", "CinzelDecorative-Bold.otf", "battle_music.ogg", "Main.tscn", "Card.tscn"):
    assert not (root / obsolete).exists(), obsolete
print(f"OK: {len(images)} image hashes documented; unlicensed legacy files absent")
