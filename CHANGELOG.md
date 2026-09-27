## Não publicado

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
