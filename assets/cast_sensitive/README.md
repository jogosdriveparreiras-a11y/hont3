# Conteúdo sensível

Quando **Conteúdo sensível** estiver **desligado (Não)** nas Configurações, o jogo
usa `assets/cast_sensitive/` no lugar de `assets/cast/`
(ex.: `ent_alyssa_wine_sprite.png`).

Se não houver arquivo `ent_*` correspondente, usa os placeholders genéricos:
- `generic_sprite.png`
- `generic_portrait.png`
- `generic_icon.png`

Quando **Conteúdo sensível** estiver **ligado (Sim)**, o jogo usa a arte original
em `assets/cast/`.

## Pacote BasicResources (MZ DLC)

Fotos/retratos `Actor*`, `Evil_*`, `Monster*` etc. foram copiados de
`RPG Maker MZ\dlc\BasicResources\pictures` (licença DLC confirmada pelo usuário).
Use-os como base ou renomeie para `ent_*_sprite/portrait/icon.png` conforme necessário.

Pacote completo permanece no DLC; re-copie com `tools/copy_mz_dlc_assets.ps1`.
