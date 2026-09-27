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

Campos: **Vida**, Impacto, Poder, Armadura, **Escudo**, Tipo, **Arquétipo**, **Raça/Espécie**, **Nível**, fileira, passiva (com caixa de explicação), pool (com contagem).

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
