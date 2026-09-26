# Arquitetura

O projeto abre `game/GameRoot.tscn` no Godot 4.6. `GameRoot.gd` constrói a arena, menus, HUD, cartas 3D e entrada; mantém equipe, decks, melhorias, campanha e opções em `user://hotn3.cfg`. `Content.gd` contém regras, tipos, heróis, cartas, inimigos, missões, descrição da campanha e identidade dos personagens. Os dados de combate são dicionários que `BattleState.gd` copia e transforma durante uma missão; `GameRoot` não decide dano nem escolhe ações inimigas.

`BattleState.gd` mantém atores, mão, deck, descarte, estados, rodadas e RNG. Emite `changed` para redesenhar a interface, `event` para o histórico, `visual(kind, source_id, target_id, value)` para a apresentação e `finished(victory)` para a tela de resultado. `CombatPresentation.gd` recebe `visual`, associa IDs a sprites, anima recortes, câmera, números, partículas e pausa breve no quadro do impacto. `SoundBus.gd` gera os sons e a música por código e controla cinco volumes. A cena mantém atores entre redesenhos da mão e remove efeitos temporários após animação.

`tools/run_checks.py` faz verificações estruturais e de conteúdo. Quando encontra Godot 4.6, importa recursos e executa `StatusSmoke.gd`, `CampaignSmoke.gd` e `SceneSmoke.gd`. `tools/build_web.py` usa esse mesmo gate antes de exportar o preset Web; precisa das export templates 4.6. Essas rotinas ainda não foram executadas no motor neste ambiente.

A versão atual usa uma cena de combate gerada em tempo de execução. Não há exploração, Abadia, sistema de amizades nem movimento livre em mapa. O posicionamento tático é frente/retaguarda.
