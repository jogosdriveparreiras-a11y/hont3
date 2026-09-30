# Changelog


## 2026-09-30 — Manobras Combo de grupo (duo/trio)

- Design travado: se os 3 heróis compartilham o mesmo `grupos`, o deck compartilhado recebe 4 Manobras Combo (3 pares + 1 trio), nomeadas (`Combo A e B` / `Combo A, B e C`).
- Grátis, INI 0, Efêmeras; jogáveis só com todos os nomes vivos; efeito = **Impulso 1** (próxima Manobra de cada envolvido no round custa 0 INI).
- Removida a injeção legada de `dueto` / Pacto de batalha por Iniciativa ≥4 como sistema de combo de grupo.
- Editor: seção Combos mostra stubs duo/trio (não Pacto / não kit falso por herói).

## 2026-09-30 — Cast Edited sync

- Atualizados a partir de HotN3 Cast/Edited (arquivo mais recente por nome): Nero (`Nero 2`), Naomi transform (`Naomi 3`), Kabuki, Techna, Pietro/Chaos, Delírio (`Delírio 2`), Dr. Espantalho, Patrulheiro Rosa, Pauline (`Pailine 2`), Pesadelo Vivo, Siren.
- Novos com kit genérico: **Caçadora** (`ent_cacadora`), **Pessoa Planta** (`ent_pessoa_planta`).
- Pipeline: `tools/scripts/PackBridge/cast/sync_edited_cast.py` (punch/trim/fit + ícone simbólico).
- Ignorados (sem nome): `8zFgG.jpg`, `2kj0_…` (duplicata de Pessoa Planta.png).
- **Marcell Wine**: sem arte em Edited — placeholders genéricos mantidos.

## 2026-09-30 — Marcell Wine (Escuridão)

- Novo herói jogável **Marcell Wine** (`ent_marcell_wine`): mesmo aprimoramento **Escuridão** de Alyssa (E sobe ao sofrer dano).
- Kit (~19 cartas): Pacto Escuro (Forte/Resistente/Rápido ×E), Regeneração Sombria (cura 10%×E), Garras do Abismo (dano+counter ×E), Relâmpago Negro (cadeia 1+E), Tempestade Latente, Desvantagem Instantânea **Legião das Sombras** (reforça o inimigo com E lacaios).
- Novos efeitos de carta: `forte`, `rapido`, `heal_pct`, `summon_foe`; `chain` aceita fórmula com E.
- Assets provisórios (placeholders genéricos) — sem arte dedicada em HotN3 Cast/Edited.


## 2026-09-29 — Herói morto no ciclo, Reanimar, cadáver, editor

### Regras (reverte o purge agressivo de cartas de herói morto)
- Cartas de **herói** morto permanecem na mão, no baralho e no descarte e **consomem a cota de compra**. Ficam injogáveis até o herói reviver.
- Só saem do ciclo cartas de **lacaio/invocação** (morte do lacaio ou do conjurador) — purge já existente.
- O corpo fica na arena: sem animação de respiração; sprite em escala de cinza (sprite de cadáver fica para depois).

### Reanimar
- Ao cair um herói, entra **uma** carta Reanimar no baralho daquele lado (custo 4 INI, alvo só aliado caído).
- Efeito: revive com **25% da Vida máxima** e **Ferido 1**.
- Se ninguém daquele lado segue caído, Reanimar sai da mão, do baralho e do descarte.
- Dono: primeiro aliado vivo do lado. Se esse dono cair, a carta passa para outro vivo.

### Editor
- `tools/card_editor.html` ficava em "Carregando…": `blankCard()` lia `HEROES_FALLBACK` (inexistente) antes do `try` de boot. Depois disso, `wire()` quebrava em `TARGETS`/`STATUSES`/`UNLOCKS`/`STATS`/`SPECIES_LIST`/`PASSIVES` também removidos. Constantes restauradas (alvo `DEAD_ALLY` incluso). Prévia de deck local + `file://` usa a cópia embutida sem `await fetch`.


## 2026-09-29 — Report rico, Vítima no kit, purge/draw mortos, Instantâneo Desvantagem, cast/minions

### Relatório de sessão
- `SessionReport`: `seq`, snapshots de mão/atores/pilhas, `emit_structured`.
- `BattleState.report_cb` → GameRoot: draw, draw_skip_dead_owner, draw_batch, reshuffle, purge, death, redraw, phase, posture_trigger, status_add.
- Snapshot de baralho/mão/atores no início da missão.

### Bugs
- **Eu Sou a Vítima!** (Dominika): estava só em `evoluidas` e `kit_manobras` cortava em 5 manobras (POSTURA ficava de fora). Agora na lista `iniciais`; `kit_manobras` inclui todas as POSTURA do kit; `ensure_owned` remescla iniciais faltantes.
- **Nero/Naomi pós-morte**: `_purge_dead_cards` agora também limpa a **mão aliada** (cartas de morto ocupavam slots); `_draw_side` **não gasta cota** ao puxar carta de dono morto (vai para exhausted e tenta de novo). Time vivo volta a comprar normalmente.

### Regras
- Toda carta `DESVANTAGEM` é **Instantâneo** (Tormenta, Derretimento, Solidão/Deixe-me Viver).

### Arte
- Cast Edited: atualizados Nero, Kabuki, Techna, Pietro/Chaos; Naomi → `transform_*` do Nero.
- Novos (kit genérico): Dr. Espantalho, Patrulheiro Rosa, Pauline, Siren, Delírio.
- Lacaios Nero/Naomi: sprites RPG Maker MZ (`enemies`) em `assets/cast/ent_minion_*`.
- Assunção: `8zFgG.jpg` sem nome — não criou personagem.


## 2026-09-29 — Posturas

- Sistema de **Postura** (status exclusivo + classe `POSTURA`): 14 posturas com ganho de Iniciativa (1 ativação/postura/rodada).
- UI: popup verde `+X Iniciativa` + foco breve de câmera.
- Dominika **Eu Sou a Vítima!** → concede Postura Tanque 3 rodadas (nome da carta mantido; alias `vitima`→`tanque`).
- Docs: `NOMENCLATURA.md` § Postura, `docs/STATUSES.txt`. Smoke: `tools/PosturaSmoke.gd`.

## 2026-09-29 — Nero→Naomi transform FX + summons die with summoner

- **Transform FX**: ao completar 5 cartas Nero, emite `visual transform` — foco/zoom cinematográfico (~1,4s), burst/summon/buff FX, flash, texto DESPERTAR; sprite/retrato trocam para `transform_*` (hoje **reutiliza arte de Nero** — sem assets Naomi dedicados).
- **Lacaios do conjurador**: ao morrer Nero/Naomi (ou qualquer summoner), `purge_summons_of` zera HP dos `is_summon`, remove cartas deles de mão/baralho/descarte e emite death.
- Smoke: `tools/NeroNaomiTransformSmoke.gd` (Derretimento passive_like, Solidão/Deixe-me Viver redraw+alone, transform, purge).

## 2026-09-29 — Status Dictionary safe get (dazed / signature crashes)

- **Cause (`dazed`)**: `_normalize_status_id("dazed")` → `stun`. `_has_status(..., "dazed")` succeeded, then `actor["statuses"]["dazed"]` threw *Invalid access* (GDScript 4). Hit on Puxão do Reino Quebrado / Peitada via `_after_card_play`.
- **Cause (`signature`)**: `EntityRuntime.on_turn_start` did `hero["signature"]` on minions (Zumbi…Lich) that have no signature — crash after Dominika/Nero summons.
- **Fix**: `_ensure_statuses` / `_status_state`; `_has_status` / `_status_stacks` use normalized safe get; `_after_card_play` no longer play-ticks alias `dazed`; leftover raw `resist` key checked without alias `[]`; EntityRuntime skips empty signature; safer `_counter`/`_stack`/`_consume` (Entity + CardRuntime).
- Smoke: `tools/StatusAliasSafeSmoke.gd`.

## 2026-09-29 — Arena deck merge + Tormenta Instantâneo jogável

- **Deck merge / owned stale**: após redesign Dominika/Nero, `owned_cards` no save ainda tinha IDs removidos (`engolfamento`, `foice_de_sangue`, …). `ensure_owned` descartava nada → `deploy` falhava `deck_valid` → fallback `begin` só enfileirava cartas presentes em `Content.CARDS` (só Alyssa). Correção: limpar IDs ausentes e resetar para Iniciais+Desvantagem; `deploy`/`build_combat_deck_ids` sanitizam kit inválido.
- **Carta desconhecida**: com `pack_mode=entities` e fallback `begin`, itens/`item_*` passavam por `EntityRuntime.play_block_reason` (catálogo vazio). Agora só `ent_*` desconocido; itens usam Content.
- **Tormenta Instantâneo**: custo/INI = 0. Gate Instantâneo só para *jogável*. `GameRoot` aplicava Slow mesmo com custo 0 (0→1 INI) enquanto `BattleState._cost` não — Tormenta bloqueava a mão e era injogável. Slow/Fast só com custo base > 0. Solidão também `cost: 0`.
- Smoke: `InstantDominikaNeroSmoke` cobre owned stale, deploy 3 donos, Tormenta jogável com Slow a 0 INI.

## 2026-09-29 — Tormenta Instantânea, Dominika/Nero redesign, Counter, Alcance, score

- **Tormenta (Alyssa)**: agora Instantâneo; requer Escuridão ≥1; dano absoluto 10×E em ALL_OTHERS; não recomprável; removido tick passivo E≥4.
- **Instantâneo**: só Instantâneo *jogável* obriga jogar antes de outras cartas / Encerrar; injogável libera o resto.
- **Alcance**: removido `reach` de 111 cartas SELF/ALLY/ALL_ALLIES (Alcance sem sentido em alvo próprio/aliado).
- **Counter**: efeitos/modo vêm da carta; alcance padrão frente×frente (fallback melee).
- **Dominika Seur**: kit Peitada…Presença + Derretimento; aprimoramento **100% Gordura** (imune Ferido/Sangrando/Preso).
- **Nero→Naomi**: após 5 cartas Nero na luta transforma; cartas dual Nero/Naomi; lacaios Zumbi…Lich; Explodir Cadáver / Curar os Mortos; Solidão Instantânea.
- **Editor**: pontuação automática por carta e totais inicial / deck final / final+ por personagem.

## 2026-09-29 — Push ≠ pull (Daeva Cobertura)

- **Anim 1+1 audit**: 553/553 cartas com exatamente 1 `anim_self` + 1 `anim_target` (0 missing, 0 2+, 0 comma-lists).
- **Bug**: `push` em `EntityRuntime`/`CardRuntime` alternava retaguarda→frente (puxava). Agora push só frente→retaguarda; pull só retaguarda→frente; `move_target` continua alternando.
- **Daeva** `ent_daeva_cobertura_de_corredor` (texto UI “Empurra”): `anim_target` `Explosion1` → `push`; actions já eram `push`.
- Prévia de pacote: estima `pull` (além de `push`). Smoke: `tools/PushPullSmoke.gd`, `tools/PushFxResolveSmoke.gd`.


## 2026-09-28 — Title orientation + Jogar fit

- **Title video/UI orientation**: Label3D on the camera-local menu no longer uses Y=180 (that mirrored glyphs). Video cover plane keeps identity UV/scale/rotation so the backdrop matches `assets/video/Title.*` (verified L/R brightness vs source frame).
- **Jogar submenu fit**: dense stack uses compact plates, frustum-based pack/scale, and a slightly smaller submenu header so Campanha / Missões / Arena / Escolher equipe / Escolher itens / Voltar all stay on-screen.

## 2026-09-28 — Título: vídeo full-cover + menu 3D flutuante

- **Backdrop**: `Title.ogv`/`Title.mp4` em loop, plano travado na câmera em modo **cover** (preenche o viewport; não é um quad pequeno no mundo).
- **Sem arena no título**: `Arena3D` / `Personagens2D` ficam ocultos — só o vídeo + botões 3D.
- **Menu**: botões Mesh+Label3D com bob/hover e árvore trancada (Jogar / Testes / Configurações); sem lista flat só-Control.

## 2026-09-28 — Título 3D, menu trancado, anims, hit feedback, clima

- **Menu título 3D**: vídeo `assets/video/Title.mp4` (+ `.ogv`) em loop de fundo; painel flutuante com fonte CardTitle.
- **Árvore trancada**: Jogar (Campanha / Missões / Arena / Escolher equipe / Escolher itens) · Testes (Copiar caminho do report / Coleção de cartas / Testar Animações) · Configurações.
- **Anims**: toda carta com exatamente 1 `anim_self` + 1 `anim_target` (RM + Effekseer); tabela em `docs/CARD_ANIM_MAPPING.md`.
- **Hit**: flash branco no sprite pela duração da anim de alvo; dano vermelho / cura verde flutuantes.
- **Clima**: chuva/neve/folhas/névoa/calor/noite com texturas RPG Maker (`particles2d`).

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
