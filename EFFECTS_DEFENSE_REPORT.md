# HotN3 — Instantâneo + Defesa (redesign)

## Instantâneo (corrigido)

**Antes (errado):** jogar Instantâneo encerrava a fase (`request_end_turn`) e tratava a carta quase como Final.

**Agora (intent do usuário):**
- Instantâneo é uma **restrição negativa** na carta (`instant` / ação `instant` / `Instantâneo`).
- Se houver qualquer Instantâneo **na mão**, **Encerrar** fica bloqueado (`can_end_turn` / `hand_has_instantaneo`).
- Jogar Instantâneo **não** encerra a fase e **não** impede recompra por "fim de fase" — só bloqueia **recompra** da própria Instantâneo (ainda deve ser jogada).
- Não torna a carta free por padrão (só se `free` estiver marcado).
- **Efêmero** permanece separado (descarta no fim da rodada).

## Modelo de defesa

### Atributos permanentes (fórmula)
- **Armadura** → reduz dano de Impacto
- **Escudo** (`escudo`) → reduz dano de Poder

### Status novos / redesenhados

| Status | Chave | Regra |
|---|---|---|
| **Proteção X** | `protecao` | Ignora os próximos X ataques; −1 por ataque (cada hit de Chain); −1 por rodada; some em 0 |
| **Barreira X Y** | `barrier` / `barreira` | Dura X rodadas; HP próprio Y; dano entra na barreira primeiro; overflow na Vida; **não** bloqueia mira (Row cuida disso) |
| **Resistente X** | `resistente` | +2 Armadura e +2 Escudo por stack (máx 5); −1/rodada; cancela com Frágil |
| **Frágil X** | `fragil` | −2 Armadura e −2 Escudo por stack (máx 5); cancela com Resistente (diferença líquida) |
| **Invulnerável X** | `invulnerable` | Imune a dano por X rodadas; **some ao jogar qualquer carta**; duração ainda tiqueia se não jogar |

### Removidos / migrados
- `protected` / `protecting` — removidos das regras de mira; conteúdo → `protecao`
- `dazed` — tratado como `stun` (migração de conteúdo)
- `resist` (cancelar 1 instância) — mapeado para `protecao`
- Barreira antiga (bloqueava alvo sem reach) — substituída pelo pool de HP

### Legado / Cap
- Conteúdo migrado: Cap gasta **Proteção**; geral gera **Barreira**.
- `block` / `shield` de ator ainda absorvem **depois** da Barreira se restarem valores residuais (passivas antigas / edge cases).

## Pipeline ao receber golpe

1. **Invulnerável** → 0 dano  
2. **Proteção** → consome 1, 0 dano (**Penetrante ignora Proteção**)  
3. **Barreira** (HP) → absorve; overflow segue (**Penetrante ignora Barreira por completo** — não reduz HP da barreira; dano segue ao personagem)  
4. Escudo/Bloqueio legado (se não pierce/penetrante)  
5. Vida; stun some com perda de Vida (salvo Letárgico)

Fórmula Armadura/Escudo (+ Resistente/Frágil) continua aplicada no cálculo do valor do golpe (`_damage_value` / runtimes) **antes** do pipeline de camadas.

## Penetrante (escolha documentada)

- **Ignora Proteção** (não consome, dano segue)
- **Ignora Barreira por completo** (não subtrai HP da barreira; dano vai ao personagem)
- Continua reduzindo Armadura/Escudo em **50%**
- Continua ignorando absorb legado block/shield (`pierce`)
- Ainda sujeito a Invulnerável e à fórmula Armadura/Escudo (já com ½) / Proteção (ignorada)

## Editor / PackBridge

- Chips: Instantâneo (tooltip corrigido), Proteção, Barreira (2 params), Resistente, Frágil, Invulnerável
- Removidos Dazed / resist da lista de status do editor
- `describe_actions` em pt-BR

## Arquivos principais

`game/BattleState.gd`, `game/GameRoot.gd`, `game/PackBridge.gd`, `addons/hotn3_entities/EntityRuntime.gd`, `addons/hotn3_external_cards/CardRuntime.gd`, `tools/card_editor.html`, conteúdo em `Content.gd` / JSONs.
