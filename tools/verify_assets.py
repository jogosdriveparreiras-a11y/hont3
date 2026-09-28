"""Validate documented asset provenance and references."""

import json
from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = (ROOT / "ASSETS.md").read_text(encoding="utf-8")

ROOT_ART = {
    "hero_fighter.png": "assets/cast_sensitive/Actor1_1.png",
    "hero_wizard.png": "assets/cast_sensitive/Actor2_2.png",
    "hero_rogue.png": "assets/cast_sensitive/Actor2_5.png",
    "hero_cleric.png": "assets/cast_sensitive/Actor3_1.png",
    "hero_paladin.png": "assets/cast_sensitive/Actor1_4.png",
    "en_dog.png": "assets/cast_sensitive/Monster_7.png",
    "en_elite.png": "assets/cast_sensitive/Monster_4.png",
    "en_sniper.png": "assets/cast_sensitive/Monster_2.png",
}

for destination, source in ROOT_ART.items():
    destination_path = ROOT / destination
    source_path = ROOT / source
    assert destination_path.is_file(), destination
    assert source_path.is_file(), source
    assert destination_path.read_bytes() == source_path.read_bytes(), (destination, source)
    digest = sha256(destination_path.read_bytes()).hexdigest()
    assert f"`{destination}` | `{source}` | `{digest}`" in MANIFEST, destination

effekseer = json.loads((ROOT / "assets/fx/effekseer/index.json").read_text(encoding="utf-8-sig"))
for effect in effekseer["curated"]:
    assert (ROOT / "assets/fx/effekseer" / f"{effect}.efkefc").is_file(), effect

particles = json.loads((ROOT / "assets/fx/particles2d/index.json").read_text(encoding="utf-8-sig"))
for filename in particles["files"]:
    assert (ROOT / "assets/fx/particles2d" / filename).is_file(), filename

bgm = sorted((ROOT / "assets/audio/bgm").rglob("*.ogg"))
assert len(bgm) == 50, "BGM inventory changed; update ASSETS.md"
assert "50 arquivos OGG" in MANIFEST

for obsolete in ("AppleGaramond.ttf", "CinzelDecorative-Bold.otf", "battle_music.ogg", "Main.tscn", "Card.tscn"):
    assert not (ROOT / obsolete).exists(), obsolete

print(
    f"OK: {len(ROOT_ART)} licensed replacements, "
    f"{len(effekseer['curated'])} Effekseer effects, "
    f"{len(particles['files'])} particle textures and {len(bgm)} BGM files"
)
