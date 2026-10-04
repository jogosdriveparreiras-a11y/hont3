# Campanhas instaladas

Coloque arquivos `.json` exportados pelo `tools/vn_editor.html` nesta pasta para que o jogo os liste no botão **Campanha**. Também são detectados arquivos JSON colocados na raiz do projeto, em `user://campaigns/` e, no jogo exportado para desktop, ao lado do executável ou na subpasta `campaigns/`.

O editor abre o roteiro pelo botão **Abrir JSON**. Depois de editar, use **Baixar JSON** e substitua o arquivo instalado. Reinicie o jogo para atualizar a lista.

Cada arquivo é carregado como pacote separado. IDs de campanhas, aventuras e cenas são isolados pelo nome do arquivo; referências locais a cenas em saltos, escolhas e batalhas continuam funcionando sem colidir com outros roteiros.

O JSON da história deve conter `scenes`. Se não declarar `campaigns` e `adventures`, o runtime cria uma campanha e uma aventura usando o roteiro inteiro.
