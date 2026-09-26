# Heroes of the Nightmare 3 — versão de desenvolvimento

Projeto Godot 4.6 de combate tático por cartas. Abra `project.godot` no editor e execute a cena principal. Use mouse para escolher uma carta, depois um alvo; também é possível clicar nas cartas 3D. O menu permite selecionar três integrantes, editar oito cartas por herói, equipar itens e escolher uma missão.

## Conteúdo implementado no código

- Seis arquétipos jogáveis com passivas, pelo menos oito habilidades por herói e 74 definições de cartas incluindo a combinação, três classes de carta, melhorias e modificadores.
- Deck compartilhado, mão, compra, descarte, exaustão, três ações por turno, duas recompras, movimento, Ímpeto, prévia de dano, Quick, Marcado, Chain, ações gratuitas, efeitos ao recomprar e combo com dois integrantes.
- Front/back row, bloqueio, escudo, armadura, cura, tipos, estados e duração, empurrar/puxar, ataques em área, 14 tipos de inimigos incluindo três elites e um chefe, reforços, quatro objetivos de missão, itens e objetos de cenário.
- Arena 3D construída em tempo de execução, sprites 2D em placas 3D, cartas com rosto compartilhado aplicado em uma malha 3D, trilha musical herdada, menu, vitória/derrota, repetição e preferências locais salvas em `user://hotn3.cfg`.

## Situação da verificação

`python3 tools/run_checks.py` executa verificações estáticas e, quando encontra Godot 4.6, importa os recursos e executa os testes headless de combate e cena descritos em `TESTING.md`. As verificações estáticas passaram. **Este ambiente não tem o executável do Godot 4.6.** Não houve execução dos testes headless, importação de recursos pelo editor, teste visual ou exportação de um binário. O ZIP contém o projeto fonte para abrir no Godot. Mecânicas e apresentação ainda exigem testes e ajustes no editor; este pacote não é uma versão final certificada.

O projeto não inclui campanha narrativa, exploração da Abadia, amizades, diálogos, personalização de herói ou equivalentes de todos os sistemas de progressão de *Marvel's Midnight Suns*. O combate usa nomes e universo próprios e não inclui conteúdo daquele jogo.

## Recursos incluídos

Sprites, fontes e música foram reaproveitados dos arquivos disponíveis do projeto HotN2 fornecido para esta tarefa. Os metadados de licença de redistribuição desses arquivos não vieram com a cópia obtida; é necessário confirmar as licenças antes de redistribuição pública. Nenhum recurso de *Marvel's Midnight Suns* foi incluído e nenhuma arte gerada por IA foi criada nesta implementação.
