# Editor de Cartas e Personagens HotN3

Abra `tools/card_editor.html` no navegador (servidor local ou `file://`).

## Carregamento automático

1. Tenta **fetch** de `../addons/hotn3_entities/entities.json` (relativo a `tools/`).
2. Se falhar (ex.: `file://`), usa a **cópia embutida** gerada no commit.
3. Botão **Recarregar dados do jogo** força novo fetch; **Importar** aceita JSON manual.

Liste/edite espécies, arquétipos e passivas a partir dos dados carregados.

## Recursos do turno

- **Único recurso compartilhado: Iniciativa** (`impulse`).
- **Não existe** pool de Poder gastável.
- **Impacto** (`attack`) e **Poder** (`power`) são atributos de escala.
- **Sem Velocidade** — só fases de **grupo** (jogador vs inimigo).

## Dano (aditivo)

```
Impacto: Carta + Impacto − Armadura + Mods
Poder:   Carta + Poder − Escudo + Mods
```

Escudo permanente do personagem ≠ escudo temporário de carta (`SHIELD` / camada `shield`).

## Exclusões no editor

- Escala: **Impacto | Poder | Estado** (radio).
- **Custo XOR Ganho** de Iniciativa.
- **Chain** fica em **Efeitos** (com nº de alvos), não na seção de custo.
- **Cura** = Vida absoluta (não × Impacto).

## Personagens

Campos: **Vida**, Impacto, Poder, Armadura, **Escudo**, Tipo, **Arquétipo**, **Raça/Espécie**, **Nível**, fileira, passiva (com caixa de explicação), **Fator de escala** (`sprite_scale`, padrão 1.00), pool (com contagem).

**Fator de escala:** multiplica **largura e altura** do sprite de combate em relação à transformação Godot já usada (CombatPresentation / exibição da entidade) — não a substitui. Normal = 1.00; maiores ~1.05–1.10; menores ~0.90. Persistido no JSON do herói; PackBridge / merge preservam o campo.

Arquétipo intransitivo (Armadura→Impacto→Escudo→Poder→Armadura, ±25%; Versátil neutro) está no código com `RULES.archetype_matchup = false` (**DESLIGADO**).

## Prévia

Arte em **full-bleed**; textos em caixas pretas com opacidade ~125/255 (~0,49).

## Fluxo

1. Abrir o editor (já carrega dados)
2. Editar / salvar na sessão
3. Exportar patch
4. `python tools/merge_card_patch.py hotn3_cards_patch.json --write [--art-dir ./pngs]`

## Por que JSON acoplável

Cartas/heróis `ent_*` em `addons/hotn3_entities/entities.json`; `PackBridge` injeta no `Content` em runtime.


## Novos flags / ações (pt-BR)

| Chave | Nome | Comportamento |
|---|---|---|
| `penetrating` | Penetrante | Ignora Proteção e Barreira por completo; ignora block/escudo de carta; só ½ Armadura (Impacto) ou Escudo permanente (Poder). |
| `lethargic` | Letárgico | Dano desta carta **não** remove Atordoamento (por padrão dano em Vida remove stun). |
| `recoil` | Recuo | Usuário sofre 1/3 do dano efetivo (arredondado). |
| `drain` | Dreno | Cura 1/4 do dano efetivo. |
| `actions` N | Ações | +N jogadas de carta no **próximo** turno (além do padrão 3). |
| `draw_own` N | Comprar próprio | Compra do baralho do herói; se não houver, embaralha descarte e tenta. |
| `recover_own` N | Recuperar própria | Carta mais recente do descarte daquele dono → mão. |
| `recover` N | Recuperar | UI escolhe no descarte; auto (mais recente) se encerrar turno sem escolher. |
| `discard` N | Descarte | Descarta N cartas aleatórias da mão. |
| `instant` | Instantâneo | Deve ser jogada nesta rodada; bloqueia Encerrar enquanto estiver na mão; não encerra a fase ao jogar; não pode ser recomprada. |
| `ephemeral` | Efêmero | Se ainda na mão no fim da rodada, descarta. |
| `warmup` X | Aquecimento | Indisponível por X rodadas após comprar (`drawn_turn + X`). |

**Não implementar no editor (ainda):** Voar; aba dicionário de status/flags/ops.

## Nomenclatura (2026-09)

- Lista filtrada por personagem mostra secoes **Iniciais | Evoluidas | Melhoradas | Desvantagem**.
- Toggle **Melhorada (+)**: tier=melhorada, nome com +, campo melhorada_de, chrome 3D na previa.
- Personagem: campo **Aprimoramento** (alias passiva), **Grupos**, **Biografia**.
- Ver `docs/NOMENCLATURA.md`.


## Animações (FX)

Campos por carta:

| Campo | Tipo | Descrição |
|---|---|---|
| `anim_self` | string[] | FX no conjurador (aliases em `assets/fx/presets.json` ou basename `.efkefc`) |
| `anim_target` | string[] | FX no alvo |
| `anim_timing` | `parallel` \| `wait_last` | Simultâneo ou espera a última |

Runtime: `FxPlayer.gd` + `CombatPresentation.play_card_fx` no resolve da carta. Stub usa GPUParticles2D/CPUParticles3D com texturas de `assets/fx/particles2d/`; `.efkefc` indexados para plugin Effekseer futuro.

## Tabela de atributos

Aba **Tabela de atributos**: lista todos os personagens com Vida/Impacto/Poder/Armadura/Escudo.
- Clique no cabeçalho para ordenar.
- Edite células e use **Salvar atributos** para aplicar no catálogo em memória.
- Em seguida **Exportar entities.json completo** para baixar o arquivo atualizado.
