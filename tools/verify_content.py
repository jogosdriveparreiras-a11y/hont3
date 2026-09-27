"""Validate data references without relying on an installed Godot editor."""

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "game" / "Content.gd").read_text(encoding="utf-8")


def dictionary(name):
    marker = None
    for candidate in (f"const {name} := ", f"static var {name} := "):
        if candidate in SOURCE:
            marker = candidate
            break
    if marker is None:
        raise AssertionError(f"Dictionary not found: {name}")
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
campaign = dictionary("CAMPAIGN")
hero_lore = dictionary("HERO_LORE")
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
ravenous regen resist resistente fragil protecao protection barreira
slow soulbound spike_bomb strengthened strongest_there_is
stun summoning symbiote_skin taunt taunted unleashed vampiric_essence
vulnerable weak webbed_up wounded invulneravel
""".split())

for hero_id, hero in heroes.items():
    assert hero_id in hero_lore and all(hero_lore[hero_id].get(k) for k in ("role", "trait", "history")), hero_id
    assert len(hero["cards"]) == rules["deck_size"], hero_id
    assert len(set(hero["pool"])) >= 8, hero_id
    assert hero.get("passive") in {"vanguarda", "canalizar", "oportunista", "devocao", "baluarte", "rastreador"}, hero_id
    assert (ROOT / hero["sprite"].removeprefix("res://")).is_file(), hero_id
    assert "playable" in hero, hero_id
    if hero.get("minion"):
        assert hero.get("playable") is False, hero_id
    for card_id in hero["pool"]:
        assert card_id in cards, (hero_id, card_id)
    for card_id in hero["cards"]:
        assert card_id in cards, (hero_id, card_id)
        assert hero["cards"].count(card_id) <= cards[card_id].get("copy_limit", rules["copy_limit"]), (hero_id, card_id)

playable = {hero_id: hero for hero_id, hero in heroes.items() if hero.get("playable", True)}
legacy = ["guerreiro", "mago", "ladino", "clerigo", "paladino", "patrulheiro"]
for legacy_id in legacy:
    assert heroes[legacy_id].get("playable") is False, legacy_id
import json
entity_pack = json.loads((ROOT / "addons/hotn3_entities/entities.json").read_text(encoding="utf-8"))["heroes"]
assert len(entity_pack) == 27
for hero_id, hero in entity_pack.items():
    assert hero_id.startswith("ent_"), hero_id
    for key in ("sprite", "portrait", "signature_icon"):
        art = str(hero.get(key, ""))
        assert art.startswith("res://assets/cast/"), (hero_id, key)
        assert (ROOT / art.removeprefix("res://")).is_file(), (hero_id, art)
assert any(hero.get("boss") and not hero.get("playable", True) for hero in heroes.values())
assert any(hero.get("minion") and not hero.get("playable", True) for hero in heroes.values())

for enemy_id, enemy in enemies.items():
    assert (ROOT / enemy["sprite"].removeprefix("res://")).is_file(), enemy_id
    for ability in enemy.get("skills", []):
        assert ability in enemy_cards, (enemy_id, ability)

for name, definition in {**cards, **enemy_cards}.items():
    assert definition.get("target") in {
        "SELF", "ALLY", "ALL_ALLIES", "ENEMY", "SINGLE", "ROW", "ENEMY_ROW",
        "ALL_ENEMIES", "ADJACENT", "RANDOM", "CHAIN", "ANY_UNIT", "FRONT_ROW", "BACK_ROW"
    }, name
    if "copy_limit" in definition:
        assert 1 <= definition["copy_limit"] <= rules["deck_size"], name
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
    assert mission_id in campaign and campaign[mission_id].get("brief") and campaign[mission_id].get("goal"), mission_id
    assert campaign[mission_id].get("par", 0) >= 3, mission_id
    for requirement in campaign[mission_id]["requires"]:
        assert requirement in missions and requirement != mission_id, (mission_id, requirement)
    assert mission["objective"] in {"ELIMINATE", "SURVIVE", "PROTECT", "BOSS"}, mission_id
    seen = set()
    for enemy_id in mission["enemies"]:
        assert enemy_id in heroes or enemy_id in entity_pack, (mission_id, enemy_id)
        record = heroes.get(enemy_id, entity_pack.get(enemy_id, {}))
        if not record.get("minion"):
            assert enemy_id not in seen, (mission_id, enemy_id)
            seen.add(enemy_id)
    for wave in mission.get("reinforcements", {}).values():
        wave_seen = set()
        for enemy_id in wave:
            assert enemy_id in heroes or enemy_id in entity_pack, (mission_id, enemy_id)
            record = heroes.get(enemy_id, entity_pack.get(enemy_id, {}))
            if not record.get("minion"):
                assert enemy_id not in wave_seen, (mission_id, enemy_id)
                wave_seen.add(enemy_id)

assert set(campaign) == set(missions) and set(hero_lore) == set(heroes)
assert campaign["road"]["requires"] == []
assert set(campaign["eclipse"]["requires"]) == {"ritual", "watch"}
watch = missions["watch"]
worst_population = len(watch["enemies"]) + sum(map(len, watch.get("reinforcements", {}).values()))
assert watch["protect_hp"] > 2 * worst_population * watch["turns"], "Protection objective should survive passive pressure alone"

assert (ROOT / "game/GameRoot.tscn").is_file()
for document in ("README.md", "ARCHITECTURE.md", "GAME_DESIGN.md", "BALANCE.md", "ASSET_LICENSES.md", "CREDITS.md", "CHANGELOG.md", "TESTING.md", "FINAL_AUDIT.md"):
    assert (ROOT / document).is_file(), document
assert 'platform="Web"' in (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
for source_file in [ROOT / "project.godot", *sorted((ROOT / "game").glob("*.gd")), ROOT / "game/GameRoot.tscn"]:
    for resource in re.findall(r"res://[^\"']+", source_file.read_text(encoding="utf-8")):
        assert (ROOT / resource.removeprefix("res://")).exists(), (source_file, resource)
assert len(heroes) >= 6 and len(cards) >= 48
for target_kind in ("ADJACENT", "RANDOM", "FRONT_ROW", "BACK_ROW", "ANY_UNIT"):
    assert any(card["target"] == target_kind for card in cards.values()), target_kind
assert len([enemy for enemy in enemies.values() if enemy.get("elite")]) >= 3
assert len([enemy for enemy in enemies.values() if enemy.get("boss")]) >= 1
assert len(enemies) >= 14
audit_rows = [line for line in (ROOT / "EFFECTS_AUDIT.md").read_text().splitlines()
              if line.startswith("| ") and not line.startswith("| Efeito")]
assert len(audit_rows) == 77, len(audit_rows)
assert len({line.split("|")[1].strip() for line in audit_rows}) == 77
print(f"OK: {len(heroes)} heroes, {len(cards)} player cards, "
      f"{len(enemies)} enemy types, {len(missions)} missions, {len(audit_rows)} audited effects")
