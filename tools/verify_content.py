"""Validate data references without relying on an installed Godot editor."""

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "game" / "Content.gd").read_text(encoding="utf-8")


def dictionary(name):
    marker = f"const {name} := "
    start = SOURCE.index(marker) + len(marker)
    level = 0
    quote = False
    escape = False
    for end in range(start, len(SOURCE)):
        char = SOURCE[end]
        if quote:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                quote = False
        elif char == '"':
            quote = True
        elif char == "{":
            level += 1
        elif char == "}":
            level -= 1
            if level == 0:
                text = SOURCE[start : end + 1]
                text = re.sub(r"\btrue\b", "True", text)
                text = re.sub(r"\bfalse\b", "False", text)
                return ast.literal_eval(text)
    raise AssertionError(f"Unclosed dictionary: {name}")


rules = dictionary("RULES")
heroes = dictionary("HEROES")
cards = dictionary("CARDS")
enemies = dictionary("ENEMIES")
enemy_cards = dictionary("ENEMY_CARDS")
missions = dictionary("MISSIONS")
allowed_effects = {
    "DAMAGE", "HEAL", "BLOCK", "SHIELD", "STATUS", "CLEANSE", "DISPEL",
    "PUSH", "PULL", "MOVE", "DRAW", "GENERATE", "CARD_PLAY", "SUMMON",
    "CURE", "NEXT_TURN", "INFECT",
}
supported_statuses = set("""
all_together_now armor banished barrier berserk_enemy berserk_lifesteal binary bind
bleed blessed blind blood_magic bloodlust bound chaos_field conceal confused
corrupted counter critical dazed drop en_fuego enhanced fast fatal_fury
feeding_frenzy frenzy full_force fury_totem invulnerable lifesteal make_em_bleed
marked momentum naturalist neurally_enhanced next_turn_plays offensive_rush
opportunist overload overpowered perfect_aim poison portal protected protecting
ravenous regen resist slow soulbound spike_bomb strengthened strongest_there_is
stun summoning symbiote_skin taunt taunted unleashed vampiric_essence
vulnerable weak webbed_up wounded
""".split())

for hero_id, hero in heroes.items():
    assert len(hero["cards"]) == rules["deck_size"], hero_id
    assert len(set(hero["pool"])) >= 8, hero_id
    assert hero.get("passive") in {"vanguarda", "canalizar", "oportunista", "devocao", "baluarte", "rastreador"}, hero_id
    assert (ROOT / hero["sprite"].removeprefix("res://")).is_file(), hero_id
    for card_id in hero["pool"]:
        assert card_id in cards, (hero_id, card_id)
    for card_id in hero["cards"]:
        assert card_id in cards, (hero_id, card_id)
        assert hero["cards"].count(card_id) <= rules["copy_limit"], (hero_id, card_id)

for enemy_id, enemy in enemies.items():
    assert (ROOT / enemy["sprite"].removeprefix("res://")).is_file(), enemy_id
    for ability in enemy["skills"]:
        assert ability in enemy_cards, (enemy_id, ability)

for name, definition in {**cards, **enemy_cards}.items():
    assert definition.get("target") in {
        "SELF", "ALLY", "ALL_ALLIES", "ENEMY", "ENEMY_ROW", "ALL_ENEMIES", "CHAIN"
    }, name
    all_effects = (definition.get("effects", []) + definition.get("on_redraw", [])
                   + definition.get("full_combo", []) + definition.get("roulette", []))
    for effect in list(all_effects):
        if effect.get("kind") == "NEXT_TURN":
            all_effects.extend(effect.get("effects", []))
    for effect in all_effects:
        assert effect["kind"] in allowed_effects, (name, effect["kind"])
        if effect["kind"] == "STATUS":
            assert effect["id"] in supported_statuses, (name, effect["id"])
        if effect["kind"] == "GENERATE":
            assert effect["id"] in cards, (name, effect["id"])

for mission_id, mission in missions.items():
    assert mission["objective"] in {"ELIMINATE", "SURVIVE", "PROTECT", "BOSS"}, mission_id
    for enemy_id in mission["enemies"]:
        assert enemy_id in enemies, (mission_id, enemy_id)
    for wave in mission.get("reinforcements", {}).values():
        for enemy_id in wave:
            assert enemy_id in enemies, (mission_id, enemy_id)

assert (ROOT / "game/GameRoot.tscn").is_file()
for source_file in [ROOT / "project.godot", *sorted((ROOT / "game").glob("*.gd")), ROOT / "game/GameRoot.tscn"]:
    for resource in re.findall(r"res://[^\"']+", source_file.read_text(encoding="utf-8")):
        assert (ROOT / resource.removeprefix("res://")).exists(), (source_file, resource)
assert len(heroes) >= 6 and len(cards) >= 48
assert len([enemy for enemy in enemies.values() if enemy.get("elite")]) >= 3
assert len([enemy for enemy in enemies.values() if enemy.get("boss")]) >= 1
assert len(enemies) >= 14
audit_rows = [line for line in (ROOT / "EFFECTS_AUDIT.md").read_text().splitlines()
              if line.startswith("| ") and not line.startswith("| Efeito")]
assert len(audit_rows) == 77, len(audit_rows)
assert len({line.split("|")[1].strip() for line in audit_rows}) == 77
print(f"OK: {len(heroes)} heroes, {len(cards)} player cards, "
      f"{len(enemies)} enemy types, {len(missions)} missions, {len(audit_rows)} audited effects")
