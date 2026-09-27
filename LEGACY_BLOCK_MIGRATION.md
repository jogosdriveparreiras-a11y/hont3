# Inventário legado: block / shield / Proteção / Barreira

**Status: MIGRAÇÃO APLICADA** (conteúdo + runtimes). Pools `block`/`shield` de ator ainda existem no pipeline só como legado residual (após Barreira); cartas de conteúdo não devem mais gerar block plano.

## Modelo alvo

| Efeito | Uso |
|---|---|
| **Proteção X** | Ignora os próximos X ataques (cada hit de Chain conta). Máx 15 stacks. |
| **Barreira X Y** | Dura X rodadas; pool de HP Y; overflow na Vida |
| **Resistente X** | +2 Armadura e +2 Escudo por stack (máx 5) |
| block / shield (legado) | Só residual no pipeline; conteúdo migrado |

**Penetrante**: ignora Proteção e Barreira; ignora block/shield; ½ Armadura/Escudo.

## Exceção Cap America (Escudo = Proteção)

User override: **Escudo do Cap = Proteção** (não Barreira). Barreira fica para aura / armadura temp / parede (ex.: Marvel).

| Carta | Antes | Depois |
|---|---|---|
| Dig In | `block(12)` | `protecao(12)` |
| Tactician | `block(10)` | `protecao(10)` |
| The Best Defense | `block_on_hit` | mesmo status; runtime → **Proteção 1** ao perder Vida |
| Shield Bash | `spend_block(0.25)` | `spend_protecao(0.25)` |
| Shield Charge | `hit_from_block` + `spend_all_block` | `hit_from_protecao` + `spend_all_protecao` |
| Shield Bounce | (sem block) | sem mudança de economia |

Ops novas: `spend_protecao`, `spend_all_protecao`, `hit_from_protecao`.

## Captain Marvel (Barreira OK)

| Carta | Depois |
|---|---|
| Knee Strike | `barrier_from_hit` (Barreira HP = dano) |
| Rain of Blows | `spend_all_barrier` |
| Regroup | `barreira(1, 8)` |
| Go Binary | `barreira_hp(1, 0.5)` — Binary persiste enquanto houver Barreira |

## Regras gerais aplicadas

- flat `block N` / `shield N` / `block_hp` → **Barreira** (1 rodada se N<10, 2 se N≥10; `barreira_hp` para %)
- ids com *armadura* → **Resistente 1** + Barreira menor
- `ignore-hit` / `resist` / `hand_resist` / `hand_block` → **Proteção**
- `bonus_block` → bônus se alvo tem **Barreira OU Proteção** (ou block legado)
- `block_on_hit` → Proteção 1 na perda de Vida
- Content.gd `BLOCK`/`SHIELD` → status `barrier`
- Passivas vanguarda / baluarte → Barreira 1/2

## Arquivos

`CardRuntime.gd`, `EntityRuntime.gd`, `BattleState.gd`, `PackBridge.gd`, `Content.gd`, `cards.json`, `entities.json`, `tools/card_editor.html` (chips + aba Dicionário).
