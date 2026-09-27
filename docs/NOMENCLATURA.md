# HotN3 — Nomenclatura oficial

Documento de regras aprovado pelo design. Fonte de verdade para editor, dados e runtime.

## Manobras

**Manobras** = cartas dos tipos **Impacto**, **Poder** ou **Estado** (classes `ATTACK` / `ESTADO` / legado `SKILL`/`POWER` mapeados).

Cada personagem possui:

| Tier | Campo / `tier` | Regra |
|------|----------------|-------|
| **Iniciais** | `inicial` | Exatamente **5** cartas únicas que vêm com o personagem (kit inicial). Sem duplicatas no kit. |
| **Evoluídas** | `evoluida` | Cartas adicionais conquistadas com o progresso. |
| **Melhoradas** | `melhorada` | Versões aprimoradas de Iniciais **e** Evoluídas. Cartas separadas; o nome termina com `+` (ex.: `Bons Sonhos+`). Chrome 3D no visual. Campo `melhorada_de` aponta para a carta base. Editor tem toggle **Melhorada**. |

Não há editor de deck in-game. Após missões, o jogo sorteia **3** cartas entre as Manobras dos personagens que participaram (incluindo Evoluídas). Se o time já possui a carta, mostra a versão **Melhorada**.

## Deck de combate

- **Não há editor de deck.** Todas as cartas **possuídas** entram sempre no baralho de combate.
- **Deck só cresce** (Iniciais → + Evoluídas conquistadas → + Combos de grupo). Baralho maior = menos reshuffles.
- **Melhoradas substituem** a versão mais fraca: ao possuir `Nome+` (`melhorada_de` = base), a carta base **sai** do deck.
- **Deck inicial típico = 15 Manobras** (3 heróis × 5 Iniciais).
- Além disso, cada herói inclui **1 Desvantagem** no kit de combate → **+3** cartas.
- Se os 3 membros compartilham **um mesmo grupo**, entram **4 Combo Manobras** (um por par + um do trio).
- **Total típico inicial:** 15 manobras + 3 desvantagens (+ até 4 combos); cresce com Evoluídas/Melhoradas.

Quando o descarte é embaralhado de volta no baralho (reshuffle), **toda a equipe aliada recebe Lento 1** (fadiga).

## Desvantagens

Cartas negativas (`class: DESVANTAGEM`, `tier: desvantagem`). **Uma por personagem.** Entram no deck de combate junto com as Iniciais.

## Aprimoramentos

**Aprimoramentos** = passivas sempre ativas (estilo Ability de Pokémon).  
Substitui os termos antigos: **recurso**, **passive**, **assinatura** (como conceito de design).

- Campo preferido: `aprimoramento` (string id ou objeto `{id, name, text}`).
- Compatibilidade: `passive` e `signature` continuam lidos como aliases no runtime/editor.
- Um personagem tem um (ou lista de) efeitos sempre ativos.

Exemplo Alyssa: aprimoramento **Escuridão** (`escuridao`).

## Grupos e Combos

- Cada personagem tem `grupos: []` (geralmente 3 nomes).
- Se **os 3** membros do time compartilham **o mesmo** grupo, o deck recebe **4 Combo Manobras**:
  - 3 pares (AB, AC, BC) + 1 trio (ABC).
- Combos são **Efêmeros** (`ephemeral` / `tier: combo`).
- Só jogáveis se **todos** os personagens daquele Combo estão vivos.
- Ao jogar um Combo: as Manobras daqueles personagens custam **0 Iniciativa** naquele round.

## Ficha do personagem (UI)

Janela com: retrato, atributos, tipo, texto de **Biografia**, e lista de cartas.  
Clicar numa carta a amplia; cada efeito é explicado ao lado (glossário).

## Fluxo de batalha

1. Clique numa Manobra para **selecionar**. Clique de novo na mesma carta para **confirmar** (não há botão Confirmar).
2. O botão **Inspecionar** aparece ao lado da carta selecionada e só então abre o overlay/glossário.
3. Se a Manobra não puder ser usada, um popup explica o motivo (ex.: "Você não pode atacar sem Alcance da linha de trás", "Você precisa de Escuridão 3 para usar esta Manobra").
4. Após confirmar + escolher alvo: **prévia de dano** no alvo — barra de HP com a porção a perder em vermelho, mais outros efeitos que serão aplicados.
5. O texto de **fase** fica numa caixa central no topo da janela de batalha; o **log** fica só na janela esquerda.

## Editor de cartas

Lista por personagem, seções:

`Inicial | Evoluídas | Melhoradas | Desvantagem`

Toggle **Melhorada** (nome com `+`, `tier=melhorada`, `melhorada_de`).

## Alyssa Wine (referência)

| Papel | Cartas |
|-------|--------|
| Aprimoramento | Escuridão |
| Iniciais (5) | Bastão Retrátil, Garras e Presas, Premonição, A Filha Dele, Regeneração |
| Evoluídas | Relâmpago, Intelecto, Super Sentidos |
| Melhoradas | stubs `…+` para cada Inicial/Evoluída |
| Desvantagem | Tormenta |

## Esquema de dados (resumo)

```json
{
  "heroes": {
    "ent_exemplo": {
      "aprimoramento": "escuridao",
      "passive": "escuridao",
      "grupos": ["GrupoA", "GrupoB", "GrupoC"],
      "biografia": "Texto…",
      "iniciais": ["card_a", "card_b", "card_c", "card_d", "card_e"],
      "evoluidas": ["card_f"],
      "cards": ["card_a", "card_b", "card_c", "card_d", "card_e"],
      "pool": ["…todas as manobras + desvantagem…"],
      "desvantagem": "card_desv"
    }
  },
  "cards": {
    "card_a": { "tier": "inicial", "class": "ATTACK" },
    "card_a_plus": { "tier": "melhorada", "melhorada_de": "card_a", "name": "Nome+" },
    "card_desv": { "tier": "desvantagem", "class": "DESVANTAGEM" },
    "combo_ab_grupo": { "tier": "combo", "ephemeral": true, "combo_members": ["ent_a","ent_b"] }
  }
}
```
