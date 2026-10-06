# Campanhas instaladas

Coloque arquivos `.json` exportados pelo `tools/vn_editor.html` nesta pasta para que o jogo os liste no botão **Campanha**. Também são detectados arquivos JSON colocados na raiz do projeto, em `user://campaigns/` e, no jogo exportado para desktop, ao lado do executável ou na subpasta `campaigns/`.

O editor abre o roteiro pelo botão **Abrir campanha JSON**. Depois de editar, use **Baixar JSON** e substitua o arquivo instalado. Reinicie o jogo para atualizar a lista.

## Gerar cenas separadas e reuni-las

Cada cena pode ser gerada em um arquivo JSON separado. O formato mínimo é:

```json
{
  "id": "cena_01",
  "title": "A chegada",
  "steps": [
    { "type": "line", "speaker": "NARRADOR", "text": "A história começa." }
  ]
}
```

No `tools/vn_editor.html`, abra uma campanha ou crie uma nova, selecione a aventura de destino e clique **Importar cenas JSON**. Selecione vários arquivos de cena de uma vez. O editor também aceita `{ "scene": { ... } }`, arquivos com `{ "scenes": { "id": { ... } } }` e `parts` no lugar de `steps`. As cenas entram na aventura selecionada na ordem dos arquivos; use as setas para reorganizá-las. IDs duplicados recebem um sufixo para evitar sobrescrita.

Depois, use **Baixar JSON** e coloque o arquivo da campanha resultante em `campaigns/`. O jogo lista campanhas completas dessa pasta ao iniciar. Arquivos de cena isolados não aparecem como campanhas: precisam ser reunidos a uma aventura para definir a ordem e os dados da campanha.

Cada arquivo é carregado como pacote separado. IDs de campanhas, aventuras e cenas são isolados pelo nome do arquivo; referências locais a cenas em saltos, escolhas e batalhas continuam funcionando sem colidir com outros roteiros.

O JSON da história deve conter `scenes`. Se não declarar `campaigns` e `adventures`, o runtime cria uma campanha e uma aventura usando o roteiro inteiro.
