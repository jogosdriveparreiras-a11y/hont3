# Editor de Cartas HotN3

Abra `card_editor.html` no navegador (duplo clique ou arraste o arquivo).

## Por que JSON acoplável (não editar Content.gd)

- Cartas do elenco (`ent_*`) já vivem em `addons/hotn3_entities/entities.json`.
- O `PackBridge` carrega esse JSON e injeta em `Content.CARDS` em runtime.
- Assim você cria cartas sem tocar no script gigante do núcleo.

## Fluxo

1. **Importar** `addons/hotn3_entities/entities.json`
2. Criar/editar cartas (digite só o nome; o resto é clique)
3. **Salvar nesta sessão**
4. **Exportar patch JSON** (só o que mudou) **ou** entities.json completo
5. Substituir/mesclar no projeto e abrir o Godot

## Formato

Mesmo schema do pack: `actions` como `[["hit","1"],["push","2"]]`, flags `reach`/`quick`/`free`/`exhaust`, `owner` = id do herói (`ent_alyssa_wine`, …).
