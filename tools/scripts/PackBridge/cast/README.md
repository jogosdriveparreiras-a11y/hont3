# Cast Edited sync

Importa arte de `HotN3 Cast/Edited` para `assets/cast/` e atualiza `addons/hotn3_entities/entities.json`.

```bash
# Staging: copie Edited para playtest_out/edited_cast/ (ou rode com pasta já lá)
python3 tools/scripts/PackBridge/cast/sync_edited_cast.py
```

- Usa o arquivo **mais recente** por personagem (lista `NEWEST_BY_BASE` no script; mtimes de zip são ruins).
- Personagens novos recebem kit genérico (template Pauline).
- Naomi atualiza `ent_nero.transform_*`.
- Arquivos sem nome (`8zFgG`, hashes longos) são ignorados.
