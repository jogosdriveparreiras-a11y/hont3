# Heroes of the Nightmare 3 — versão de desenvolvimento

Projeto Godot 4.6 de combate tático por cartas. Abra `project.godot` no editor e execute a cena principal. Use mouse para escolher uma carta, depois um alvo; também é possível clicar nas cartas 3D. No combate, Q/E ou LB/RB percorrem cartas, setas ↑/↓ ou direcional do controle percorrem alvos, Enter/A confirma, R/X inicia a recompra, M seleciona o movimento, T/Y encerra o turno e Esc/B cancela a seleção. O menu permite selecionar três integrantes, editar oito cartas por herói, equipar itens e escolher uma missão.

## Conteúdo implementado no código

- Seis arquétipos jogáveis com passivas, pelo menos oito habilidades por herói e 79 definições de cartas incluindo a combinação, três classes de carta, melhorias e modificadores independentes.
- Deck compartilhado, mão, compra, descarte, exaustão, três ações por turno, duas recompras, movimento, Ímpeto, prévia de dano e mudança de linha, Quick, Marcado, Chain, ações gratuitas, efeitos ao recomprar e combo com dois integrantes. O editor de decks oferece filtros, seleção de slots e limites de cópia.
- Front/back row, bloqueio, escudo, armadura, cura, tipos, estados e duração, empurrar/puxar, ataques em área, 14 tipos de inimigos incluindo três elites e um chefe, reforços, quatro objetivos de missão, itens e objetos de cenário.
- Arena 3D construída em tempo de execução, sprites 2D animados em placas 3D, cartas com face aplicada em malhas 3D, animação da mão, texto e partículas de combate, foco e tremor da câmera, música, ambiente e sons sintetizados no código, menu, vitória/derrota, repetição e preferências de áudio/acessibilidade salvas em `user://hotn3.cfg`.
- Campanha de quatro missões com desbloqueios, recordes de três estrelas e Essência obtida ao melhorar resultados. Melhorias de cartas consomem Essência; saves anteriores mantêm suas melhorias. Descrições dos heróis, passivas e objetivos estão visíveis nos menus. Consulte `BALANCE.md` para critérios numéricos e limitações.

## Situação da verificação

`python3 tools/run_checks.py` executa verificações estáticas e, quando encontra Godot 4.6, importa os recursos e executa os testes headless de combate, campanha e cena descritos em `TESTING.md`. As verificações estáticas passaram. **Este ambiente não tem o executável do Godot 4.6.** Não houve parsing no editor, execução dos testes headless, inspeção visual, partidas de balanceamento ou exportação de um binário. O ZIP contém o projeto fonte para abrir no Godot. Mecânicas e apresentação ainda exigem testes e ajustes no editor; este pacote não é uma versão final validada.

Com Godot 4.6 e os templates de exportação instalados, `python3 tools/build_web.py --godot /caminho/para/godot` executa os testes e exporta `dist/HotN3-web.zip`. O projeto usa o renderizador de compatibilidade e inclui um preset Web. Para uma publicação pública, a questão das licenças dos sprites em `ASSET_LICENSES.md` ainda precisa ser resolvida.

O projeto não inclui campanha narrativa, exploração da Abadia, amizades, diálogos, personalização de herói ou equivalentes de todos os sistemas de progressão de *Marvel's Midnight Suns*. O combate usa nomes e universo próprios e não inclui conteúdo daquele jogo.

## Recursos incluídos

Os sprites foram reaproveitados da cópia local do HotN2 e conferidos por hash; as licenças dos criadores não constam nela e seguem pendentes antes de redistribuição pública. Fontes antigas e áudio sem proveniência foram retirados. Consulte `ASSET_LICENSES.md`, `ASSETS.md` e `FINAL_AUDIT.md` para o estado de cada recurso e requisito. `ARCHITECTURE.md`, `GAME_DESIGN.md`, `BALANCE.md`, `CREDITS.md` e `CHANGELOG.md` descrevem o projeto. Nenhum recurso de *Marvel's Midnight Suns* foi incluído e nenhuma arte gerada por IA foi criada nesta implementação.
