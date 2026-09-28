## 2026-09-28 — Recompra, seleção bloqueada, mão e Teste de Animação

- **Recompra**: hold-to-redraw em **1,0s** (metade); medidor circular épico (halo, ticks, ponta brilhante, painel dourado) — não ProgressBar.
- **Seleção**: cartas injogáveis (Iniciativa, fileira/Alcance, requisitos, jogadas, incapacitado…) **não selecionam**; clique mostra toast só com o motivo (fade ~0,14s → 1s → fade-out, sem OK).
- **Mão**: com uma carta selecionada, as demais ficam **invisíveis** (e sem raycast).
- **Menu**: **Teste de Animação** — escolhe usuário + alvo (sprites), filtra cartas (personagem/tipo/nome) e reproduz só RM/FX (`anim_self`/`anim_target`), sem efeitos de combate.

## 2026-09-28 — anim cartas + zoom mão isolado

- **Zoom lateral**: câmera fixa; o mundo (`stage`/`units`) escala e desloca no hover de sprite. Mão 3D (filha da câmera) não muda de tamanho/posição na tela.
- **Anims da mão**: compra/recompra entram da **direita** (deck→arco); jogar/recompra saem para a **esquerda** (fade+scale), sem interferir no fluxo seleção→confirmação.

## 2026-09-28 — IA inimiga: alvos + mão de mortos

- Relatórios `hotn3_session_20260928_165025` / `_163241`: ataques `ENEMY` (Airsoft, Cobertura, Isolar, Lâmina…) miraram aliados do jogador corretamente após cace737; cartas `SELF`/`ALLY` (Passo despercebido, Moto de fuga, Guarda, Plano de assalto) não miram o jogador por design.
- **Bug real**: cartas de inimigo morto ficavam na `enemy_hand` e a IA recomprava índice 0 à toa — com dono em `bind` isso queimava Manobras de custo 0 e deixava `plays_left>0` sem jogada (`enemy_skip` turns 10–11 Fate / turn 6 Ashlee bound).
- **Correção**: purge de mortos também na `enemy_hand`; recompra inteligente (`_best_enemy_redraw_index`); `diagnose_enemy_hand` no `enemy_skip` do SessionReport; `enemy_choice` grava `target_kind`/`card_class`.
- Smoke: `tools/EnemyAiTargetSmoke.gd`.

## 2026-09-28 — Crash fim de combate (RmAnim visible/freed)

- **Causa**: vitória chama `_center_panel` → `clear_actors()` que `queue_free` nos filhos do presentation (incl. `RmAnim`), enquanto tweens criados em `host_3d` ainda rodavam `_apply_frame` → `s.visible = false` em nó já liberado.
- **Correção**: `is_instance_valid` antes de tocar `visible`/propriedades; tween da anim RM ligado ao `root` (morre com o free); `stop_active`/`stop_all` no teardown; callbacks de free também validam instância (FxPlayer + float/burst).
- Relatório `hotn3_session_20260928_163241.jsonl` confirma sequência: hit → Fate caiu → death → `finished won` imediatamente antes do crash.

## 2026-09-28 — IA inimiga ent_ + relatório de sessão

## 2026-09-28 (boot menu)

- Boot: menu principal antes do SessionReport (evita tela vazia se `user://reports` travar no Windows).
- SessionReport: `FileAccess.WRITE` em vez de `WRITE_READ`; falha de IO não bloqueia o jogo.
- Câmera: `drive_camera` desligado no título; `look_at` seguro (sem `det==0` no editor).


- **Bug real (Task A)**: missões usam inimigos `ent_*` cujas Manobras têm `actions` (não `effects`). A IA chamava `BattleState.play()`, que só resolve `effects` — cartas inimigas gastavam Iniciativa/jogadas sem causar dano. **Correção**: `EntityRuntime.play` / `PackBridge.play_card` side-aware (PLAYER+ENEMY); `enemy_step` e `_step_enemy` despacham cartas `ent_`/`ms_` pelo PackBridge.
- **Relatório de sessão (Task B)**: `game/SessionReport.gd` grava JSONL append-only em `user://reports/hotn3_session_YYYYMMDD_HHMMSS.jsonl` (fuso local / America/Sao_Paulo no relógio do box). Auto-inicia no launch; botão **Copiar caminho do report** no menu principal e no menu de combate. Categorias: `ui`, `card`, `battle`, `ai`, `error`, `session`.
- Smoke: `tools/EnemyHitSmoke.gd`.

## 2026-09-28 — RM anims (Alyssa/Dominika/Evelyn), recompra, zoom sprite

- **Crash SE RM**: `_fire_timings` não tipa mais `se` nulo como Dictionary (timings RM com `"se": null`); `_play_se` ignora nome vazio. "A Filha Dele" remapeada para `slow/debuff` (sem stun/Paralisia).
- **Animações RM** em todas as cartas de Alyssa Wine, Dominika Seur e Evelyn Graves (`anim_self` / `anim_target`); `RmAnimPlayer` com aliases amplos e preferência por sheets existentes.
- **Recompra**: após hold-to-redraw, `_render_battle()` reconstrói a mão na hora (carta nova aparece no arco sem precisar clicar outra).
- **Zoom lateral**: restaura zoom no hover de **sprite**; hover de carta sem zoom; mão 3D isolada (filha da câmera + compensação de FOV).

## 2026-09-28 — Retrato, status, Arena, invocações, RM anims

- Retrato some ao sair do hover (mantém se carta selecionada/inspeção/prévia).
- Ícones de status sob a barra de HP; lista expandida no hover; também nos retratos na prévia.
- **Arena** no menu: escolhe 3 aliados + 3 inimigos.
- Invocações: personagem normal, deck mesclado; ao morrer/expirar remove cartas do dono.
- Animações RM (`assets/fx/rm_animations/`) com playback frame+SE.

## 2026-09-28 — Combate UX: breath, alvo, Escuridão, FX

- **Breath** idle restaurado (pés fixos, stretch superior); independente de “Reduzir movimento da câmera”.
- **Vista lateral**: hover no sprite só desloca o foco — **sem FOV/zoom** da mão.
- **Prévia de alvo**: `BattleState.preview` estima `actions` (hit/status); barra `HpForecast` + **Confirmar** juntos perto do HP.
- **Escuridão**: cartas com `requires_self_status` ficam bloqueadas; clique → popup `Requer: Escuridão X`.
- **Face/Inspeção**: BBCode (`[b]Escuridão[/b]`, Sangrando/Ferido); valores amplificados por E em verde; glossário Expandido.
- **FX**: `FxPlayer` toca sequências frame-a-frame (particles2d) + SFX; Animations.json MZ não está no repo (MVP com sheets TRP).

## 2026-09-28 — BGM título/combate + menu principal

- **Tocar** no seletor de BGM: usa a faixa do seletor (`bgm_pick`), não o `__stop__` salvo — Parar + Tocar retoma a música.
- Menu/título toca **`title`** por padrão; combate toca **`Battle1`** (troca contextual entre os defaults).
- Inclui `assets/audio/bgm/title.mp3` no repositório.
- Menu de combate: **Voltar ao menu principal** (abandona a luta e volta ao título).
- SoundBus deixa de auto-iniciar BGM; GameRoot controla por contexto. MP3 com loop via `AudioStreamMP3`.

## 2026-09-28 — Pacote HUD/FX/editor/balanceamento

## 2026-09-28 — UX combate (pt-BR)

- Hover de carta: mantém foco da câmera no dono; compensação de FOV isola o zoom do sprite do tamanho da mão (só a carta sob hover escala).
- Alvo inimigo: clique mostra prévia de dano e pede **Confirmar alvo** antes de resolver (`pending_target_id`).
- Menu de combate (botão topo-direita + ESC): BGM, clima, câmera livre, vista.
- Removido `warp_mouse`; freeze ~0,5s de retarget no hover de sprite.
- IMPACTO/PODER + escudo/espada alinhados à borda esquerda da carta.
- Face da carta: resumos curtos (`Lento 1`); glossário completo só em Inspecionar.
- Modo carta selecionada: sem hover/zoom em outras; câmera normal; Cancelar ou clique fora.
- SFX distintos `confirm` / `cancel`.
- Breath: pés fixos, stretch só na parte superior.
- Barras de HP: ícone de tipo antes dos números (💥⚔️👁️🎭⚡🧪).


- **CardFace**: fonte épica/serif no título (`assets/fonts/CardTitle.ttf`), nome do personagem centralizado, emblema de Impacto à esquerda, caixa de regras semi-transparente, INICIATIVA no canto inferior esquerdo; `CardFace.tscn` editável.
- **FX de combate**: `FxPlayer.gd` + presets; toda Manobra toca animação no conjurador e no alvo (padrão `cast`/`hit` se a carta não definir); timing parallel/wait no editor.
- **Config (ESC)**: seletor de BGM listando `assets/audio/bgm` (+ fantasy/).
- **HUD economia**: Iniciativa em 10 segmentos; Ações / Recompras / Movimentos com ícones que esmaecem ao gastar.
- **Câmera/retratos**: hover de carta foca o dono (se vivo); retratos laterais permanecem com carta selecionada até resolver; sem hover/seleção → ocultos. Warp do mouse ao centro do sprite ao focar (quebra loop zoom↔hover).
- **Seleção**: botão **Cancelar** para desmarcar; inspeção com glossário em linguagem de jogo (ex.: Lento explica o +1 de Iniciativa).
- **Conteúdo sensível (invertido)**: OFF → `cast_sensitive/` com mapeamento **único** por personagem (sem placeholders genéricos); ON → arte original `cast/`.
- **Balanceamento**: Vida 60–120; Impacto/Poder/Armadura/Escudo 20–40 nos heróis do pack e Content; dano absoluto de cartas Content ~20–40. Hits do pack continuam como modificadores sobre Impacto/Poder.
- **Editor HTML**: aba **Tabela de atributos** comparativa de todos os personagens, ordenação por coluna, células editáveis + **Salvar atributos** (grava no catálogo; exportar `entities.json`).
- Inclui trabalho local Windows: `ArenaBuilder.gd`, `CampaignRules.gd`, `CollectionRules.gd`, refactor de `GameRoot.gd`, smoke tools.

## 2026-09-28 — mão, seleção e HUD de batalha

- Cartas da mão menores e mais altas; hover eleva, endireita, ilumina e traz a carta para a frente.
- O primeiro clique volta a exibir a carta completa e fixa no centro, com o segundo clique mantendo a confirmação.
- Nós visuais dos personagens agora são recriados quando a textura esperada muda, evitando que Alyssa e Dominika herdem sprites provisórios.
- Textos do cabeçalho, log, objetivo, economia e cartas foram reposicionados ou ajustados para permanecer dentro de seus painéis.
- A regressão visual agora verifica hover, seleção central, vista lateral e os arquivos exatos dos sprites de Alyssa e Dominika.

## 2026-09-27 — validação, coleção e proveniência

- Coleção e campanha extraídas para `CollectionRules.gd` e `CampaignRules.gd`.
- Removidos seleção de slots, limites de cópia, sanitização e persistência do editor de deck antigo.
- Os oito sprites herdados sem licença documentada foram substituídos por cópias verificadas do DLC RPG Maker MZ.
- `verify_assets.py` agora valida os índices Effekseer/TRP, 50 BGM e as oito substituições por hash.
- Documentação alinhada com 27 personagens jogáveis, 553 definições de carta, cinco missões e validação no Godot 4.6.1.
- Imagens de referência, logs locais e o inicializador específico da máquina foram adicionados ao `.gitignore` sem apagar os arquivos locais.

## 2026-09-27 — Battle UX, deck automático, conteúdo sensível, editor

- Log de combate só na janela esquerda; prompt de fase centralizado no topo.
- Seleção de carta: 2º clique confirma; botão **Inspecionar** abre overlay (sem Confirmar).
- Popup pt-BR quando a Manobra não pode ser usada (Alcance / Escuridão / etc.).
- Sem editor de deck: coleção = todas as possuídas; Melhoradas substituem a base; deck só cresce.
- Vista lateral: quatro fileiras aparecem da esquerda para a direita, com divisórias amarelas no chão e inimigos espelhados.
- Config: **Conteúdo sensível = Não** usa as alternativas de `assets/cast_sensitive/`; **Sim** usa a arte original de `assets/cast/`.
- `tools/card_editor.html`: corrigido SyntaxError (aspas em Desvantagem) que deixava "Carregando…" eterno.

## 2026-09-27 — Nomenclatura oficial (Manobras / Aprimoramento / Melhoradas / Combos)

- Docs: `docs/NOMENCLATURA.md`; adaptação Masmorra 2 atualizada (Aprimoramento, Melhoradas+, Combos, deck 15).
- Dados: `aprimoramento`, `grupos`, `biografia`, `iniciais`/`evoluidas`/`melhoradas`/`desvantagem`; cards com `tier` + Melhoradas `Nome+` (`melhorada_de`).
- Alyssa Wine: 5 Iniciais, Evoluídas, Melhoradas stubs, Desvantagem Tormenta, aprimoramento Escuridão.
- Runtime: deck combate = 5×3 Manobras + Desvantagens + Combos (grupo compartilhado); reshuffle → Lento 1 na equipe; Combo zera INI das Manobras dos membros no round.
- UI: ficha do personagem (retrato/attrs/bio/cartas); overlay **Inspecionar** + glossário; prévia de dano (HP vermelho).
- Editor: seções Inicial|Evoluídas|Melhoradas|Desvantagem; toggle Melhorada; campos Aprimoramento/Grupos/Biografia.
- Smoke: `tools/NomenclatureSmoke.gd`.

## Não publicado

## 2026-09-27 — Alyssa Wine / Escuridão

- Alyssa redesenhada: passiva **Escuridão** (+1 ao perder Vida), Desvantagem **Tormenta** (E≥4 → 1 dmg em todos os outros no tick).
- Cartas novas: Bastão Retrátil, Garras e Presas, Premonição, A Filha Dele, Regeneração, Relâmpago, Intelecto, Super Sentidos, Tormenta (DESVANTAGEM).
- Fórmulas em efeitos (`1+E`, `2*E`, tokens de status); alvo `ALL_OTHERS`; status **Atento** e **wounded** no play path das runtimes.
- Bleed: causa X e stacks −1 por tick. Editor: dicionário/STATUSES/TARGETS atualizados.


## 2026-09-27 — Migração block/shield → Proteção/Barreira + Instantâneo UX + Dicionário

- Migração completa do inventário legado (`LEGACY_BLOCK_MIGRATION.md`): Cap America usa **Proteção** como Escudo (`spend_protecao` / `hit_from_protecao`); Marvel Knee/Rain em **Barreira**; resto do catálogo → Barreira / Resistente / Proteção conforme regra.
- Instantâneo: tooltip no Encerrar + toast curto ao clicar (botão não fica só disabled).
- Editor: aba **Dicionário** com statuses, flags, ops e atributos (pt-BR).


## 2026-09-27

- Penetrante ignora **Barreira** por completo (não gasta HP da barreira; dano segue ao personagem).
- Editor: campo **Fator de escala** (`sprite_scale`) por personagem; multiplica sprite W/H sobre a transform Godot existente.
- Vista de batalha **Lateral** (opt-in, HUD «Vista: Normal | Lateral») sem remover a vista Normal.
- Inventário `LEGACY_BLOCK_MIGRATION.md` (sugestões Proteção/Barreira/Resistente). Notas em `SIDE_VIEW_NOTES.md`.


## 2026-09-27 — Instantâneo corrigido + defesa redesenhada

- Instantâneo: bloqueia Encerrar com carta na mão; **não** encerra fase ao jogar.
- Novos status: Proteção, Barreira (HP), Resistente, Frágil, Invulnerável (some ao jogar carta).
- Removidos protected/protecting/dazed; resist → Proteção.
- Ver `EFFECTS_DEFENSE_REPORT.md`.


### 2026-09-27 — Novos efeitos de carta (Penetrante, Letárgico, Ações, etc.)

- Penetrante, Letárgico, Recuo, Dreno, Instantâneo, Efêmero, Aquecimento.
- Comprar próprio, Recuperar / Recuperar própria, Descarte N, Ações (+jogadas no próximo turno).
- `next_turn_plays` agora soma stacks (permite >4 jogadas).
- Editor HTML: flags/ações em pt-BR; PackBridge descreve os novos ops.

## 2026-09-27 — Vida/Escudo, fases de grupo, editor auto-load

- Removida Velocidade; combate só em fases de grupo (jogador vs inimigo).
- Atributo **Escudo** nos personagens; dano Impacto − Armadura, Poder − Escudo.
- UI: HP → Vida. Cura de pack = Vida absoluta.
- Arquétipo intransitivo implementado, **desligado** (`RULES.archetype_matchup = false`).
- Editor carrega `entities.json` (fetch + cópia embutida), passivas com explicação, pool com contagem, exclusões Impacto|Poder|Estado e Custo⊕Ganho, prévia full-bleed.
- IA inimiga: até 3 melhores cartas por economia/dona vivos (sem Speed).

- Pacote de polimento HotN3 Godot 4.6: arte da carta sem squash (cover por altura), nome da carta ao lado do ícone de assinatura no topo, caixas pretas em opacidade média (~125/255), espada+IMPACTO/PODER+número ocupando ~90% do vão entre chip e efeitos.
- Turno inimigo apresenta cada carta centrada (~2s) como inspeção do jogador, depois aplica no alvo e espera ~2s antes da próxima (inclui sequência de PA/Quick/Free).
- Barra de recompra por segurar virou anel circular (`CircularMeter`).
- Arco da mão mais fechado horizontalmente; hover traz a carta à frente (z/depth) e aumenta escala.
- Nova missão/arena `street` — Rua noturna procedural (asfalto, calçadas, fachadas, postes, neon).
- Tremor de tela no dano mais forte.
- VisualPlaytest gera `playtest_hotn3_pass3_*.png`.

- Corrige fluxo de cartas: hover → selecionar → confirmar → alvo. O overlay de inspeção voltava `mouse_filter` para IGNORE dentro de `CardFace.setup`, então o 2º clique cancelava em vez de confirmar; agora STOP fica depois do setup. Alvos automáticos (SELF, ALL_ALLIES/ENEMIES, RANDOM, FRONT/BACK_ROW) resolvem na confirmação sem clique extra. VisualPlaytest cobre dano com mira e auto-play.
- Polimento battle UI pass2: arco circular da mão (~5° entre cartas), ícone escudo+espada do anexo com dano no centro do escudo, 2º clique na carta entra em mira (não desmarca), HUD esquerdo atualiza no hover, bloom/glow em barras e anéis, assinatura top-left, Iniciativa na economia à direita, arte full-bleed, cantos arredondados, idle breath nos sprites.
- Pacote visual UI/HUD/cartas estilo Midnight Suns: fundo opaco por tipo, caixas pretas semi-transparentes, ícone escudo+espada PNG, dano só em cartas ofensivas, nome do herói centrado sob o ícone de assinatura.
- Mão 3D em 50% do tamanho, hover com glow elétrico, inspeção +20%. HUD inferior: retrato+PV à esquerda, economia (jogadas/recompras/movimentos) + Encerrar turno à direita. Anéis de chão por tipo no lugar das sombras.
- Recompra por segurar ~2s (sem botão "Redesenhar"). Cartas de heróis mortos ficam na mão cinzas (inspecionáveis, não jogáveis). Equipe bloqueia heróis únicos que já são inimigos da missão.
- `cards_3d.reparent(camera)` passa `keep_global_transform=false` para a mão 3D ficar no espaço da câmera (antes ficava sob o chão da arena).
- Incluído `tools/VisualPlaytest.gd` para capturas de viewport sem gambiarra de Identity.
- Smokes de Status/Campanha passam a carregar `PackBridge` antes de `begin`, pois as missões agora usam inimigos `ent_`.
- Fallback de sprite `assets/cast` em `_sprite_region` usa o quadro inteiro; regras da carta destacam Quick/Chain/Exhaust e efeitos negativos em vermelho.
- `run_checks` redireciona a saída do Godot para log e inclui MergeSmoke.
- SceneSmoke força `reduce_motion=false` antes do toggle (config salva não pode fazer o assert falhar e travar o headless).

- Pacotes `ent_`/`ms_` mesclados ao conteúdo principal: heróis do anexo entram na seleção de equipe e cartas externas expandem os pools dos arquétipos via `owner_mapping.json`.
- Removidas as demos separadas do menu (`Demo: elenco` / `Demo: cartas externas`).
- Corrigida tipagem `Array[String]` em `HotNBattle.begin` / `EntityRuntime.deploy`.
- Sprites do elenco `ent_` redesenhados a partir das descrições do HoeDex quando existiam (Kabuki ninja cibernética, Evelyn meio-monstro, Fate de cabelo azul e espada colossal, Mingau humanoide felino, Dominika parasita de vitrine, Hynda bruxa, Madelyn de pele marmórea, Techna com gadgets não letais, Taylor com a alienígena Zaphter). Sem descrição, o desenho segue espécie, papel e tags.

# Histórico da cópia de desenvolvimento

## Pacotes opcionais de cartas e entidades

- Incluídos `addons/hotn3_external_cards/` (cartas `ms_`) e `addons/hotn3_entities/` (elenco `ent_`) sem sobrescrever `Content.gd` nem `BattleState.gd`.
- `PackBridge.gd` injeta heróis `ent_` e cartas `ms_`/`ent_` em `Content` na inicialização e roteia jogada/redesenho por prefixo de ID.
- O caminho principal (Play / campanha / decks) usa o elenco e as cartas expandidos; pastas `addons/` permanecem como fonte.

## Iniciativa, pool único e cartas

- O recurso jogável continua sendo `impulse` (máximo 10), agora exibido como Iniciativa. O antigo modificador de iniciativa saiu das regras.
- Heróis, chefes e minions saem do mesmo pool. `playable: false` impede a escolha do jogador; `minion: true` é a única duplicata permitida no mesmo lado.
- Adversários usam as mesmas cartas. A linha `AÇÕES · INICIATIVA · RECOMPRA · MOVER · DECK · DESCARTE` fica visível nos dois lados e só a fase ativa fica em destaque.
- A mão 2D cresce no hover. Clicar amplia a carta a cerca de metade da tela; outro clique confirma e um clique fora cancela, antes do alvo no sprite. O retrato fica à esquerda para aliados e à direita para inimigos até a ação terminar.

## Passo 5 — auditoria e preparação de entrega

- HUD reorganizado para a mão e os painéis caberem em 1366×768 e 1920×1080; os testes de cena agora verificam os limites dos painéis nas duas resoluções.
- Inclusos o objetivo de campanha nos testes, pausa visual curta no quadro de impacto, documentação de arquitetura, regras, recursos e créditos e preset para exportação Web no renderizador de compatibilidade.
- Exportação e inspeção visual no motor continuam pendentes na ausência de Godot 4.6.

## Passo 4 — conteúdo

Campanha, estrelas, Essência, identidade dos heróis, ajuste de proteção, passiva de cura do Clérigo e inventário dos recursos com hashes.

## Passo 3 — apresentação

Sprites, mão, dano flutuante, partículas, câmera, sons sintetizados, teclado/controle e opções de acessibilidade.

## Passos 1 e 2 — estabilidade e regras

Verificadores, casos de teste Godot, ampliação de alvos, prévia, IA, filtros e editor de deck.
