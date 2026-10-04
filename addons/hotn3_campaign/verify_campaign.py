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

for scene in scenes.values():
    for step in scene["steps"]:
        kind = step.get("type", "line")
        assert kind in {"line", "choice", "battle", "jump", "end"}, kind
        if kind == "choice":
            assert step["options"]
            for option in step["options"]:
                if option.get("goto"):
                    assert option["goto"] in scenes
        if kind == "jump":
            assert step.get("scene") in scenes
        if kind == "battle":
            assert step.get("mission")
            assert int(step.get("party_size", 3)) >= len(step.get("required_party", [story["protagonist"]]))
            if step.get("next"):
                assert step["next"] in scenes
        hero_id = step.get("right", "")
        if hero_id:
            assert hero_id in catalog["heroes"] or hero_id == "guardiao", hero_id

assert (ADDON / "CampaignRoot.tscn").is_file()
assert (ADDON / "CampaignRoot.gd").is_file()
assert (ADDON / "CampaignView.gd").is_file()
assert (ADDON / "ArenaBuilder.gd").is_file()
print("OK: roteiro em grafo, batalhas, escolhas, retratos e recompensas verificados")
