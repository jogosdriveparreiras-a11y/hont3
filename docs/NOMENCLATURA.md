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
Substitui os termos antigos: **recurso**, **passive**, **assinatura/signature**.

- Campo preferido: `aprimoramento` (string id ou objeto `{id, name, text}`).
- Compatibilidade: `passive` ainda é lido como alias no runtime/editor.
- **Assinatura/signature foi removida** — não há mais efeito automático no início do turno (BLOCK/etc.).
- Um personagem tem um (ou lista de) efeitos sempre ativos.

Exemplo Alyssa: aprimoramento **Escuridão** (`escuridao`).

## Grupos e Combos

- Cada personagem tem `grupos: []` (geralmente 3 nomes).
- Se **os 3** membros do time compartilham **o mesmo** grupo, o **deck compartilhado do time** recebe **4 Manobras Combo** (não são cartas de kit por herói):
  - 3 pares nomeados (ex.: `Combo Alyssa e Dominika`) + 1 trio (ex.: `Combo Alyssa, Dominika e Nero`).
- Propriedades: **Grátis** (sem PA), **custo INI 0**, **Efêmeras** (`ephemeral` / `tier: combo` / `class: COMBO`) — descartadas se não usadas no turno.
- Só jogáveis se **todos** os personagens nomeados naquela Combo estão vivos.
- Ao jogar: concede **Impulso 1** a cada envolvido — a **próxima** Manobra daquele herói **neste round** custa **0 INI** (1 carga por herói; consome ao jogar a Manobra).
- **Não** usar o legado `dueto` / "Pacto de batalha" (injeção por Iniciativa ≥4) como sistema de combo de grupo.

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
| Desvantagem | Tormenta (Instantâneo; E≥1; 10×E em todos os outros) |

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


## Instantâneo

Enquanto houver um Instantâneo **jogável** na mão, o jogador **deve** jogar um Instantâneo antes de qualquer outra carta ou de Encerrar. Se houver vários, escolhe qual. Se o Instantâneo estiver injogável (requisitos, INI, incapacitado…), pode Encerrar ou jogar outras cartas; se depois ficar jogável, a restrição volta. Instantâneo **não** pode ser recomprado.

## Counter

Counter **não** é um estado genérico: os efeitos do revidе vêm da carta que o concedeu. Padrão de alcance: só frente vs frente; se não houver frente no time, usam-se as regras de corpo-a-corpo (sem Alcance).

## Alcance

`reach` / Alcance só faz sentido contra o time inimigo. Cartas `SELF` / `ALLY` / `ALL_ALLIES` não devem marcar Alcance.


## Postura

**Postura** = status exclusivo **e** classe de carta (`class: POSTURA`). Um personagem só pode ter **uma** postura por vez — aplicar outra **substitui** a anterior.

Ganho de Iniciativa da postura: **no máximo 1 ativação por postura por rodada** (não por hit de AoE / multi-alvo).

| Id | Nome | Gatilho | INI |
|----|------|---------|-----|
| `tanque` | Tanque | Sofre dano de Vida | +1 |
| `furioso` | Furioso | Causa dano de Vida | +1 |
| `curador` | Curador | Cura Vida | +2 |
| `empatico` | Empático | Causa dano de Vida em aliado | +2 |
| `atirador` | Atirador | Usa carta com Alcance | +2 |
| `drenador` | Drenador | Usa Dreno | +2 |
| `controlador` | Controlador | Aplica status negativo em inimigo | +2 |
| `garra` | Garra | Recebe status negativo de inimigo | +3 |
| `vingador` | Vingador | Aliado morre | +2 |
| `executor` | Executor | Mata inimigo | +2 |
| `indomavel` | Indomável | Fim do turno do time com Vida < 1/3 | +2 |
| `sobrevivente` | Sobrevivente | Fim do turno do time como único vivo do grupo | +3 |
| `intocavel` | Intocável | Evita ataque inimigo com Proteção | +2 |
| `preparo` | Preparo | Usa item | +3 |

UI: popup flutuante verde `+X Iniciativa` sobre o personagem + foco breve de câmera.

Legado: status `vitima` / Vítima normaliza para `tanque` / Tanque. Carta Dominika **Eu Sou a Vítima!** concede Postura Tanque por 3 rodadas (nome da carta mantido).
