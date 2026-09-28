# Arquitetura

O projeto abre `game/GameRoot.tscn` no Godot 4.6. `GameRoot.gd` coordena menus, HUD, cartas 3D e entrada. `ArenaBuilder.gd` constrói e limpa os cenários; regras puras de coleção ficam em `CollectionRules.gd`; desbloqueio, recompensas e estrelas ficam em `CampaignRules.gd`. `Content.gd` contém regras, tipos, heróis-base, cartas-base, inimigos, missões e descrições da campanha. Os pacotes JSON acrescentam 27 personagens e 471 cartas. `BattleState.gd` copia e transforma esses dados durante uma missão; a camada de interface não decide dano nem escolhe ações inimigas.

`BattleState.gd` mantém atores, mão, deck, descarte, estados, rodadas e RNG. Emite `changed` para redesenhar a interface, `event` para o histórico, `visual(kind, source_id, target_id, value)` para a apresentação e `finished(victory)` para a tela de resultado. `CombatPresentation.gd` recebe `visual`, associa IDs a sprites, anima recortes, câmera, números, partículas e pausa breve no quadro do impacto. `SoundBus.gd` gera os sons e a música por código e controla cinco volumes. A cena mantém atores entre redesenhos da mão e remove efeitos temporários após animação.

`tools/run_checks.py` faz verificações estruturais, de conteúdo e de proveniência. Com Godot 4.6, importa recursos e executa `StatusSmoke.gd`, `CampaignSmoke.gd`, `SceneSmoke.gd` e `MergeSmoke.gd`. `tools/build_web.py` usa o mesmo gate antes de exportar o preset Web e exige os templates 4.6. A suíte foi executada com Godot 4.6.1 em 2026-09-27.

A versão atual usa uma cena de combate gerada em tempo de execução. Não há exploração, Abadia, sistema de amizades nem movimento livre em mapa. O posicionamento tático é frente/retaguarda.
