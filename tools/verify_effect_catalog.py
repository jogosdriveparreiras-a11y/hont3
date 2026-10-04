"""Check the visible effect catalog and the migrated defense/flight rules."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
legacy_actions = {
    "block", "block_hp", "hit_from_block", "spend_all_block", "spend_block",
    "block_from_hit", "bonus_block", "hand_block", "block_on_hit",
}


def check_legacy(value, where):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in {"actions", "naomi_actions"} and isinstance(child, list):
                for action in child:
                    if isinstance(action, list) and action:
                        assert str(action[0]).lower() not in legacy_actions, (where, action)
            if key == "action" and where.startswith("actors") and isinstance(child, list) and child:
                assert str(child[0]).lower() not in {"block", "shield"}, (where, child)
            if key in {"block", "shield"} and where.startswith("actors"):
                raise AssertionError(f"Temporary defense pool remains: {where}.{key}")
            check_legacy(child, f"{where}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            check_legacy(child, f"{where}[{index}]")


entities = json.loads((ROOT / "addons/hotn3_entities/entities.json").read_text(encoding="utf-8"))
external = json.loads((ROOT / "addons/hotn3_external_cards/cards.json").read_text(encoding="utf-8"))
check_legacy(entities.get("heroes", {}), "actors.entities")
check_legacy(entities.get("cards", {}), "cards.entities")
check_legacy(external.get("cards", {}), "cards.external")

editor = (ROOT / "tools/card_editor.html").read_text(encoding="utf-8")
rows = re.findall(r'\{cat:"([^"]+)", id:"([^"]+)", name:"([^"]+)", rule:"([^"]+)"\}', editor)
assert rows, "Effect dictionary is empty or changed format"
ids = [(category, entry_id) for category, entry_id, _, _ in rows]
assert len(ids) == len(set(ids)), "Duplicate catalog entries within a category"
assert all(name.strip() and rule.strip() for _, _, name, rule in rows), "Catalog item needs display text and a rule"
assert not any(category == "Legado" for category, _, _, _ in rows), "A legacy defense is still advertised"

voar = [rule for _, entry_id, _, rule in rows if entry_id == "voar"]
assert len(voar) == 1, "Voar needs one catalog rule"
assert all(part in voar[0] for part in ("área", "Alcance", "Colisão")), voar
collision = [rule for category, entry_id, _, rule in rows if category == "Op" and entry_id == "collision"]
assert len(collision) == 1 and all(part in collision[0] for part in ("empurrão", "Voar")), collision
assert '{op:"collision", label:"Colisão"' in editor
for source in (
    "addons/hotn3_entities/EntityCatalog.gd",
    "addons/hotn3_external_cards/CardPack.gd",
):
    assert '"collision"' in (ROOT / source).read_text(encoding="utf-8"), (source, "collision not recognized")
for source in (
    "addons/hotn3_entities/EntityRuntime.gd",
    "addons/hotn3_external_cards/CardRuntime.gd",
):
    runtime = (ROOT / source).read_text(encoding="utf-8")
    assert "battle.is_area_attack(resolved_def)" in runtime and 'not battle._has_status(victim, "flying")' in runtime, (source, "area flight filtering")
    assert 'battle.reposition(source, victim, "move" if op == "move_target" else op, _has_action(def, "collision"))' in runtime, (source, "collision dispatch")
combat = (ROOT / "game/CombatRules.gd").read_text(encoding="utf-8")
assert '"voar": {"landing_damage_max_hp_fraction": 0.10, "movement_damage_multiplier": 2.0}' in combat
smoke = (ROOT / "tools/StatusSmoke.gd").read_text(encoding="utf-8")
assert all(part in smoke for part in ("Voar evita dano", "Alcance permite ataque direto contra Voar", "Atacante voando alcança alvo voador", "não corpo a corpo derruba Voar", "Colisão duplica"))
assert all(f'"{kind}"' in smoke for kind in ("ENEMY_ROW", "ALLY_ROW", "ROW", "FRONT_ROW", "BACK_ROW", "ADJACENT", "ALL_ENEMIES", "ALL_ALLIES", "ALL_OTHERS"))

for source in (
    "game/BattleState.gd",
    "game/PackBridge.gd",
    "game/GameRoot.gd",
    "game/CombatPresentation.gd",
    "game/SoundBus.gd",
    "game/FxPlayer.gd",
    "addons/hotn3_entities/EntityRuntime.gd",
    "addons/hotn3_entities/EntityCatalog.gd",
    "addons/hotn3_external_cards/CardRuntime.gd",
    "addons/hotn3_external_cards/CardPack.gd",
    "tools/scripts/PackBridge/cast/sync_edited_cast.py",
):
    text = (ROOT / source).read_text(encoding="utf-8")
    for action in legacy_actions:
        assert f'"{action}"' not in text, (source, action)
    assert '"BLOCK"' not in text and '"SHIELD"' not in text, source

print(f"OK: {len(rows)} catalog entries have names and rules; legacy defense ops removed; Voar has rule/text/smoke coverage")
