# Animações RPG Maker (MV/MZ)

Importadas do projeto `CGC 2` (sheets + `Animations.json`) e SE padrão MZ (`newdata/audio/se`).

- `Animations.json` — definições frame/timing/SE
- `sheets/` — PNGs clássicos (Hit, Slash, Blow, Fire, Thunder…)
- `se/` — efeitos sonoros `.ogg`

Playback: `game/RmAnimPlayer.gd` via `FxPlayer` (frame-a-frame + SE nos timings).
