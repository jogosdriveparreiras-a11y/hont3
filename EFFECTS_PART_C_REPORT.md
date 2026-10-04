# Relatório HotN3 — sistemas atuais + Part C

## PARTE A — Como funciona hoje (com trechos)

### 1) Camadas ao receber dano (`BattleState._take_damage`)

Ordem efetiva:

1. **Invulnerável** (`invulnerable`): cancela todo o dano; emite `immune`.  
   `game/BattleState.gd` ~457–460.
2. **Resist** (`resist`, se não `pierce`): consome 1 stack e cancela a instância. ~461–468.
3. Ajustes ambientais / minion.
4. **Proteção** absorve hits individualmente; **Barreira** absorve um pool de HP antes da Vida. `pierce` ignora ambos.
   (Passiva `baluarte` e efeitos `SHIELD` enchem `shield`; `BLOCK` / guarda enchem `block`.)
5. Resto vai para **Vida** (`hp`).
6. Se perdeu Vida (`hp_lost > 0`): remove **stun** (salvo Letárgico — ver Part C); pode aplicar lifesteal/bleed hooks.

**Protegido** (`protected`): não é imunidade a dano — impede **seleção** de alvo (e área) em `can_reach` / `_targets` (~312–354).  
**Barreira** (`barrier`): pool de HP temporário; não bloqueia seleção de alvo.
**Armor (status stacks)**: em `_defense_for_stat`, soma `2 * stacks` à Armadura permanente no caminho Impacto (~431–435).  
**Armadura (stat)** vs **Escudo (stat `escudo`)**: Impacto → Armadura (+ stacks); Poder → Escudo permanente. Distintos do `shield` temporário de carta.

### 2) Slow / Fast

Em `_cost` / play dos packs: se custo > 0, **fast** −1 Iniciativa, **slow** +1 (`BattleState._cost` ~640–641; Entity/CardRuntime no cálculo de cost).

### 3) Wounded vs Bleed; Stun vs Dazed

| | |
|---|---|
| **Bleed** | DoT no tick (`_tick_statuses`): `stacks * 2` com pierce. |
| **Wounded** | Ao **jogar** carta: auto-dano `3 * stacks` pierce (`play` ~709–710). |
| **Stun** | Impede jogar; removido ao perder Vida; ao aplicar, apaga `protecting`. |
| **Dazed** | Impede jogar; stacks caem **por carta jogada** em `_after_card_play` (~649–666); **não** some com dano. |

**Sim:** dano que reduz Vida remove stun hoje (`_take_damage` ~485). Letárgico passa a impedir isso.

### 4) Counter

Status `counter` (cartas `guarda`, `contra`, `provocar`, `frenesi_aco`…).  
Se o alvo não morreu, `counter_allowed` e ainda tem o status, rebate  
`max(1, 3 + floor(attack/2))` com `counter_allowed=false` (sem recontra) (~519–522).  
Não consome stack por golpe — dura pela `duration` do status. **Funcionando; sem fix.**

### 5) Jogadas > 3 no próximo turno?

Já existia `next_turn_plays` / `neurally_enhanced` forçando `max(..., 4)` (= +1).  
**Part C:** agora **soma stacks** (`card_plays += max(1, stacks)`), então `actions` 2 → 5 jogadas, etc. Também há efeito Content `CARD_PLAY` para +jogadas **no turno atual**.

---

## PARTE B — Já aceito (sem build)

Impacto/Poder 1–7, Combo=Chain, Alcance/Área/Invocar, Proteção/Invulnerável.

---

## PARTE C — Implementado

| Efeito | Chave | Onde |
|---|---|---|
| Penetrante | `penetrating` flag/action | Ignora Proteção/Barreira (`pierce`); defesa Armadura/Escudo × 0,5 |
| Letárgico | `lethargic` | `_take_damage(..., remove_stun=false)` |
| Counter | — | Documentado; OK |
| Ações | `actions` N / status `next_turn_plays` | +N jogadas no próximo turno |
| Comprar próprio | `draw_own` N | `BattleState.draw_own` (+ reshuffle descarte) |
| Recuperar própria | `recover_own` | Auto: mais recente do dono |
| Recuperar | `recover` | UI GameRoot no descarte; auto se encerrar turno |
| Instantâneo | `instant` | Sem recompra; free se omitido; `request_end_turn` → fase inimiga |
| Recuo | `recoil` | Autodano 1/3 do dano efetivo |
| Aquecimento | `warmup` X | `drawn_turn + X` |
| Efêmero | `ephemeral` | Purge no fim da fase (mão) |
| Dreno | `drain` | Cura 1/4 do dano efetivo |
| Descarte | `discard` X | Aleatório na mão |

Arquivos: `BattleState.gd`, `EntityRuntime.gd`, `CardRuntime.gd`, `PackBridge.gd`, `GameRoot.gd`, `tools/card_editor.html`, `tools/CARD_EDITOR.md`, `CHANGELOG.md`.

**Atualização 2026-10:** Voar passou a ser status configurável, com esquiva de ataques em área, derrubada por ataques diretos que alcancem o alvo e impacto dobrado em colisões. O editor agora descreve a regra.

---

## Perguntas em aberto (UX)

1. **Instantâneo:** interpretado como “jogar encerra a fase do jogador”. Alternativa (exigir Instantâneo na mão para poder Encerrar) **não** foi feita.  
2. **Recuperar:** há painel de escolha no descarte; se o jogador encerrar o turno sem escolher, auto-pega a mais recente.  
3. **Descarte N:** aleatório (UI de escolha na mão não adicionada).  
4. **Recuo/Dreno:** baseados no dano efetivo pós-armadura (`last_hit` / `hit_amount`), não só no HP perdido após bloqueio.
