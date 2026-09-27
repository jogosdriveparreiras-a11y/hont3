# Editor de Cartas e Personagens HotN3

Abra `card_editor.html` no navegador (duplo clique ou arraste o arquivo).

## Recursos do turno

- **Único recurso compartilhado: Iniciativa** (`impulse` no código).
- **Não existe** “Ponto de Poder” / pool de Poder gastável paralelo à Iniciativa.
- **Impacto** (`attack`) e **Poder** (`power`) são **atributos de escala** do herói: entram na soma do dano. Ícones na face da carta — **nunca** custo.
- Recursos de personagem (ex.: Raiva) podem existir depois via passivas; não no editor genérico.

## Por que JSON acoplável (não editar Content.gd)

- Cartas e heróis `ent_*` vivem em `addons/hotn3_entities/entities.json`.
- O `PackBridge` injeta no `Content` em runtime.

## Abas

| Aba | Conteúdo |
|-----|----------|
| **Cartas** | Nome, escala Impacto/Poder, Iniciativa (custo/ganho), flags, efeitos, arte |
| **Personagens** | HP, ataque/poder/armadura/velocidade, portrait/sprite/ícone, pool |

## Tipagem na face (sem ATTACK/SKILL/POWER)

- Carta com dano → mostra **IMPACTO** ou **PODER** (pelo campo `stat`).
- Carta sem dano → **nenhum** nome de classe na face (interno: `class: "ESTADO"`).
- O editor **não** oferece seletor ATTACK/SKILL/POWER.

## Dano (aditivo no jogo)

```
Dano ≈ Carta + Impacto/Poder − Armadura + Mods
```

Runtime do pack (`EntityRuntime` / `CardRuntime`): soma o valor de `hit` ao atributo do herói, aplica mods de status, subtrai armadura. Alinhado ao `BattleState._damage_value` do Content.

## Imagem

1. **Carregar pasta de assets** → indexa PNGs para prévia do portrait/sprite do dono.
2. **Escolher imagem do PC** → define `art = res://assets/cards/<id>.png` + download do PNG.
3. `python tools/merge_card_patch.py patch.json --write --art-dir ./pngs`

## Fluxo

1. Importar `entities.json`
2. Editar / salvar na sessão
3. Exportar patch
4. `python tools/merge_card_patch.py hotn3_cards_patch.json --write`

## Flags / raridade

- Flags com texto branco.
- Raridade removida da UI; cartas novas omitem `rarity`.
