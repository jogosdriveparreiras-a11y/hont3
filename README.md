# Heroes of the Nightmare 3 — versão de desenvolvimento

Projeto Godot 4.6 de combate tático por cartas. Abra `project.godot` no editor e execute a cena principal. Passe o mouse numa carta para destacá-la e mostrar o retrato (esquerda para o seu lado, direita para o adversário). Clique para ampliá-la no centro, com cerca de metade da altura da tela; clique de novo para confirmar ou fora para cancelar. O alvo é o sprite, não uma lista. No combate, Q/E ou LB/RB percorrem cartas, setas ↑/↓ ou direcional do controle percorrem alvos, Enter/A confirma, R/X inicia a recompra, M seleciona o movimento, T/Y encerra o turno e Esc/B cancela a seleção. O menu permite selecionar três integrantes, consultar a coleção automática, melhorar cartas, equipar itens e escolher uma missão.

## Conteúdo implementado no código

- Vinte e sete personagens HotN jogáveis, oito personagens-base internos e 553 definições de cartas carregadas entre o núcleo e os dois pacotes JSON. O catálogo inclui Manobras Iniciais, Evoluídas, Melhoradas, Desvantagens e Combos.
- Deck de cada lado, mão, compra, descarte, exaustão, três ações por turno, duas recompras, movimento e Iniciativa (`impulse`, máximo 10). Todas as cartas possuídas entram no deck; Melhoradas substituem suas bases. Quick, Marcado, Chain, ações gratuitas, efeitos ao recomprar e combos de grupo estão implementados. Adversários usam as mesmas regras. `minion: true` (a Fera) é a exceção que permite cópias no mesmo lado.
- Front/back row, bloqueio, escudo, armadura, cura, tipos, estados e duração, empurrar/puxar, ataques em área, 14 tipos de inimigos incluindo três elites e um chefe, reforços, quatro objetivos de missão, itens e objetos de cenário.
- Arena 3D construída em tempo de execução, sprites 2D animados em placas 3D, cartas com face aplicada em malhas 3D, animação da mão, texto e partículas de combate, foco e tremor da câmera, música, ambiente e sons sintetizados no código, menu, vitória/derrota, repetição e preferências de áudio/acessibilidade salvas em `user://hotn3.cfg`.
- Campanha de cinco missões, incluindo Rua noturna, com desbloqueios, recordes de três estrelas e Essência obtida ao melhorar resultados. Melhorias de cartas consomem Essência; saves anteriores mantêm suas melhorias. Descrições dos heróis, passivas e objetivos estão visíveis nos menus. Consulte `BALANCE.md` para critérios numéricos e limitações.

## Situação da verificação

`python tools/run_checks.py --godot <executável>` executa verificações estáticas, importa os recursos e roda os testes headless de combate, campanha, cena e integração. O projeto foi validado com Godot 4.6.1 em 2026-09-27. A validação automatizada não substitui partidas de balanceamento nem revisão visual em diferentes máquinas.

Com Godot 4.6 e os templates de exportação instalados, `python3 tools/build_web.py --godot /caminho/para/godot` executa os testes e exporta `dist/HotN3-web.zip`. O projeto usa o renderizador de compatibilidade e inclui um preset Web. Para uma publicação pública, a questão das licenças dos sprites em `ASSET_LICENSES.md` ainda precisa ser resolvida.

O projeto não inclui campanha narrativa, exploração da Abadia, amizades, diálogos, personalização de herói ou equivalentes de todos os sistemas de progressão de *Marvel's Midnight Suns*. O combate usa nomes e universo próprios e não inclui conteúdo daquele jogo.

## Recursos incluídos

Os oito sprites herdados do HotN2 sem licença documentada foram substituídos por cópias verificadas de recursos do RPG Maker MZ licenciados pelo usuário. Efeitos, partículas, BGM e imagens MZ estão inventariados em `ASSETS.md`; os termos aplicáveis são resumidos em `ASSET_LICENSES.md`. `ARCHITECTURE.md`, `GAME_DESIGN.md`, `BALANCE.md`, `CREDITS.md` e `CHANGELOG.md` descrevem o projeto.

## Relatório de sessão (debug)

Cada execução grava um arquivo JSONL em `user://reports/hotn3_session_YYYYMMDD_HHMMSS.jsonl`
(caminho absoluto: use **Copiar caminho do report** no menu). Inclui cliques de UI, cartas,
alvos, log de combate, decisões da IA inimiga e efeitos visuais relevantes. Envie esse
arquivo ao reportar bugs.

