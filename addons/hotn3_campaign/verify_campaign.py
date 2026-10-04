"""Checks references and playability constraints of the standalone campaign."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ADDON = Path(__file__).resolve().parent
story = json.loads((ADDON / "story.json").read_text(encoding="utf-8"))
catalog = json.loads((ROOT / "addons/hotn3_entities/entities.json").read_text(encoding="utf-8-sig"))
tracked_audio = set()
if (ROOT / ".git").exists():
    tracked_audio = set(subprocess.check_output(
        ["git", "ls-tree", "-r", "--name-only", "HEAD", "assets/audio/bgm"],
        cwd=ROOT, text=True,
    ).splitlines())
assert story["protagonist"] in catalog["heroes"]


def project_has(path: str) -> bool:
    if (ROOT / path).is_file():
        return True
    return path in tracked_audio

scenes = story["scenes"]
assert scenes
assert story.get("start_scene", next(iter(scenes))) in scenes
assert all(not scene.get("bgm") or project_has(scene["bgm"].removeprefix("res://")) for scene in scenes.values())

# O runtime aceita o formato estruturado exportado pelo editor e também os
# roteiros legados, que são normalizados como uma campanha e uma aventura.
adventures = story.get("adventures") or {
    "aventura_principal": {"scene_ids": list(scenes)}
}
campaigns = story.get("campaigns") or [{
    "id": "campanha_principal",
    "required_party": [story["protagonist"]],
    "party_size": 3,
    "adventures": list(adventures),
}]
campaign_ids = {campaign["id"] for campaign in campaigns}
assert story.get("start_campaign", campaigns[0]["id"]) in campaign_ids
for adventure_id, adventure in adventures.items():
    for scene_id in adventure.get("scene_ids", scenes):
        assert scene_id in scenes, f"Adventure {adventure_id} references missing scene {scene_id}"
for campaign in campaigns:
    assert int(campaign.get("party_size", 3)) >= len(campaign.get("required_party", []))
    assert len(campaign.get("required_party", [])) <= int(campaign.get("party_size", 3))
    assert all(hero in catalog["heroes"] for hero in campaign.get("required_party", []))
    assert campaign.get("adventures", list(adventures))
    assert all(adventure in adventures for adventure in campaign.get("adventures", list(adventures)))

for scene in scenes.values():
    for step in scene["steps"]:
        kind = step.get("type", "line")
        assert kind in {"line", "choice", "battle", "jump", "reward", "end"}, kind
        if kind == "choice":
            assert step["options"]
            for option in step["options"]:
                if option.get("goto"):
                    assert option["goto"] in scenes
                for effect in option.get("effects", []):
                    assert effect.get("type") in {"set_flag", "add_hero", "remove_hero", "give_item", "give_card", "draw_card"}
                    if effect.get("type") in {"add_hero", "remove_hero"} and effect.get("id"):
                        assert effect["id"] in catalog["heroes"]
        if kind == "reward":
            for reward in step.get("rewards", []):
                assert reward.get("type") in {"character", "item", "card", "draw"}
                if reward.get("type") == "character":
                    assert reward.get("id") in catalog["heroes"]
                if reward.get("type") == "card":
                    assert reward.get("id") in catalog["cards"]
                    assert reward.get("owner", story["protagonist"]) in catalog["heroes"]
        if kind == "jump":
            assert step.get("scene") in scenes
        if kind == "battle":
            assert step.get("mission")
            assert int(step.get("party_size", 3)) >= len(step.get("required_party", [story["protagonist"]]))
            assert int(step.get("party_size", 3)) <= 3
            for criterion in step.get("criteria", []):
                assert criterion.get("type") in {"eliminate_all", "eliminate_target", "survive_rounds", "protect_ally", "protect_hp"}
                assert criterion.get("combine", "and") in {"and", "or"}
            for extra in step.get("extra_cards", []):
                assert extra.get("side", "enemy") in {"enemy", "ally"}
                assert extra.get("card_id", extra.get("card", "")) in catalog["cards"]
                if extra.get("owner_id"):
                    assert extra["owner_id"] in catalog["heroes"]
            if step.get("next"):
                assert step["next"] in scenes
        hero_id = step.get("right", "")
        if hero_id:
            assert hero_id in catalog["heroes"] or hero_id == "guardiao", hero_id

assert (ADDON / "CampaignRoot.tscn").is_file()
assert (ADDON / "CampaignRoot.gd").is_file()
assert (ADDON / "CampaignView.gd").is_file()
assert (ADDON / "ArenaBuilder.gd").is_file()
print("OK: campanhas ordenadas, cenas condicionais, batalhas, escolhas e recompensas verificadas")
