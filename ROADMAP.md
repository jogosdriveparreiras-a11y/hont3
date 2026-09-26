# Plano de conclusão sem Git

## 1. Estabilidade e teste — executado no ambiente disponível

Corrigir erros identificáveis pela leitura do motor, exigir todos os acertos de Chain e registrar eliminações por impacto para Quick/Marcado. Criar um único comando de verificação e testes headless de combate/cena. As verificações estáticas passaram; importação e execução no Godot 4.6 permanecem pendentes por ausência do executável neste ambiente. A primeira etapa só poderá ser aprovada integralmente após executar `python3 tools/run_checks.py --godot /caminho/para/godot` sem erros.

## 2. Regras e interface de combate

Completar os tipos de alvo e a prévia de consequências, testar todas as cartas em partidas, ajustar IA, movimentação de linhas, cenário e editor de decks. Critério: regras coerentes com as cartas e cenários de teste cobrindo turnos e condições de vitória.

## 3. Apresentação e acesso

Implementar animações dos personagens e da mão, feedback de dano/defesa, câmera por ação, efeitos, sons de interface/combate, entradas por teclado/controle e opções de acessibilidade. Critério: feedback reconhecível para cada ação e interface utilizável sem depender apenas do mouse.

## 4. Conteúdo e identidade

Refinar personagens, inimigos, missões, progressão e balanceamento; confirmar proveniência e licenças dos recursos e registrar atribuições. Critério: conteúdo e recursos documentados e partidas com duração e dificuldade avaliadas no Godot.

## 5. Validação e entrega

Executar importação e testes no Godot 4.6, inspeção visual em 1366×768 e 1920×1080, corrigir console e fluxo completo, concluir documentação e exportar pacote final. Critério: jogo executável e todos os itens do checklist final do pedido verificados, com eventuais adaptações declaradas.
