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
assert story["protagonist"] == "ent_alyssa_wine"
assert story["protagonist"] in catalog["heroes"]
assert story["battles"] == ["road", "ritual", "eclipse"]


def project_has(path: str) -> bool:
    if (ROOT / path).is_file():
        return True
    return path in tracked_audio

scenes = story["scenes"]
assert list(scenes) == ["prologue", "after_road", "after_ritual", "ending"]
assert [step["index"] for scene in scenes.values() for step in scene["steps"] if step.get("type") == "battle"] == [0, 1, 2]
assert all(project_has(scene["bgm"].removeprefix("res://")) for scene in scenes.values())
assert len({scene["arena"] for scene in scenes.values() if scene["arena"] != "campaign_eclipse"}) == 2
assert sum(step.get("type", "line") == "line" for scene in scenes.values() for step in scene["steps"]) >= 55
assert sum(step.get("type") == "choice" for scene in scenes.values() for step in scene["steps"]) >= 3

for scene in scenes.values():
    for step in scene["steps"]:
        if step.get("type") == "choice":
            assert len(step["options"]) == 2
            assert len({(o["flag"], o["value"]) for o in step["options"]}) == 2
        hero_id = step.get("right", "")
        if hero_id:
            assert hero_id in catalog["heroes"] or hero_id == "guardiao", hero_id

initial = catalog["heroes"]["ent_alyssa_wine"]
assert len(initial["evoluidas"]) >= 3
assert not set(initial["evoluidas"]) & set(initial["iniciais"])
for hero_id in ["ent_madelyn", "ent_ashlee"]:
    hero = catalog["heroes"][hero_id]
    assert len(hero["evoluidas"]) >= 3
    assert not set(hero["evoluidas"]) & set(hero["iniciais"])

assert (ADDON / "CampaignRoot.tscn").is_file()
assert (ADDON / "CampaignRoot.gd").is_file()
assert (ADDON / "CampaignView.gd").is_file()
assert (ADDON / "ArenaBuilder.gd").is_file()
print("OK: 3 encontros, 4 cenas, 3 escolhas, retratos e recompensas verificados")
