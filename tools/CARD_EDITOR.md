# Editor de Cartas e Personagens HotN3

Abra `card_editor.html` no navegador (duplo clique ou arraste o arquivo).

## Por que JSON acoplável (não editar Content.gd)

- Cartas e heróis do elenco (`ent_*`) vivem em `addons/hotn3_entities/entities.json`.
- O `PackBridge` carrega esse JSON e injeta em `Content` em runtime.
- Assim você cria conteúdo sem tocar no script gigante do núcleo.

## Abas

| Aba | O que edita |
|-----|-------------|
| **Cartas** | Cartas do pack (`actions`, flags, custo/ganho, arte, owner) |
| **Personagens** | Heróis (`hp`, `attack`, `power`, `armor`, `speed`, portrait/sprite/ícone, pool) |

## Fluxo

1. **Importar** `addons/hotn3_entities/entities.json`
2. (Opcional) **Carregar pasta de assets** — escolha `assets/` ou `assets/cast/` no seletor de pastas. O editor indexa PNGs para prévia automática.
3. Criar/editar na aba **Cartas** ou **Personagens**
4. **Salvar nesta sessão**
5. **Exportar patch JSON** (só o que mudou) **ou** entities.json completo
6. Mesclar no projeto:

```bash
python tools/merge_card_patch.py hotn3_cards_patch.json --write
# Se baixou PNGs de arte das cartas:
python tools/merge_card_patch.py hotn3_cards_patch.json --write --art-dir ./pasta_dos_pngs
```

## Imagem da carta

- **Escolher imagem do PC**: prévia via blob URL; no export define `art` = `res://assets/cards/<card_id>.png` e permite **Baixar PNG**.
- **Sem arte custom**: a prévia usa o **portrait** do dono; se não houver, o **sprite** — desde que a pasta de assets tenha sido carregada (indexa por nome de arquivo).
- Coloque o PNG em `assets/cards/` (manual ou `--art-dir` no merge). O navegador **não** grava direto na pasta do Godot.

## Imagem do personagem

- Botões Portrait / Sprite / Ícone: escolhem arquivo do PC, definem o caminho `res://assets/cast/<id>_….png` e baixam o PNG para você colocar em `assets/cast/`.
- Com a pasta de assets indexada, a prévia resolve os caminhos `res://` existentes.

## Dano (hit)

Meta de design (igual ao Content / `_damage_value`):

> **Dano final ≈ Carta + Impacto/Poder − Escudo + Mods**

No editor, o efeito `hit` é rotulado como **dano base da carta** (aditivo).

**Estado atual do runtime do pack** (`EntityRuntime` / `CardRuntime`):

```text
last_hit = max(1, round(ofensa × (fator_hit + bônus) × multiplicadores_de_status))
```

Ou seja, o valor de `hit` no JSON do pack **ainda multiplica** o ataque/poder do herói. Já as cartas de `Content.gd` usam `amount + attack_stat` (aditivo) em `BattleState._damage_value`.

Nesta versão o editor **não** altera o GDScript (mudar a fórmula quebraria os fatores fracionários atuais: `0.5`, `0.8`, `1.5`…). Ajuste de runtime fica para um balanceamento dedicado.

## Flags

Botões de flag usam texto **branco** sobre fundo escuro (legível).

## Raridade

Removida da UI. Cartas novas **omitêm** o campo `rarity`. Entradas antigas no JSON podem manter `rarity` em silêncio; saves sujos não reintroduzem o campo.

## Formato

- Cartas: `actions` como `[["hit","1"],["push","2"]]`, flags `reach`/`quick`/`free`/`exhaust`, `owner` = id do herói, opcional `art`.
- Heróis: schema completo do pack (`hp`, `attack`, `power`, `armor`, `speed`, `type`, `row`, `passive`, `portrait`, `sprite`, `signature_icon`, `pool`, `cards`, …).

## Patch de exemplo

```json
{
  "format": 1,
  "cards": { "ent_adam_nova": { "id": "ent_adam_nova", "name": "Nova", "owner": "ent_adam", "…": "…" } },
  "heroes": { "ent_adam": { "id": "ent_adam", "name": "Adam", "hp": 26, "…": "…" } }
}
```
