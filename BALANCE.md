# Critérios de conteúdo e balanceamento

## Estrutura da campanha

Estrada → Círculo de cinzas, Defesa da sentinela e Rua noturna; Círculo + Defesa → Guardião do Eclipse. A primeira vitória em uma missão rende 3 de Essência mais 2 por estrela. Melhorar o mesmo recorde rende apenas 2 por estrela adicional; repetir a mesma pontuação não rende nada. Melhorar uma carta custa 3 de Essência para o nível 1 e 6 para o nível 2; alterar sua modificação custa 4. Todas as cartas possuídas entram no deck e Melhoradas substituem suas bases. Saves anteriores conservam as melhorias que já existiam.

Estrelas: 1 pela vitória, mais 1 por ao menos dois sobreviventes; a terceira exige conclusão até a rodada de referência em Estrada (4) ou Eclipse (6). Nas missões de resistência e proteção, exige os três heróis com ao menos metade da Vida; na proteção, também exige a sentinela com ao menos metade da Vida.

## Referência numérica antes dos estados e tipos

| Missão | Inimigos iniciais | PV iniciais somados | PV dos reforços | Rodada de referência |
| --- | ---: | ---: | ---: | ---: |
| Estrada | 4 | 66 | 31 | 4 |
| Círculo de cinzas | 3 | 85 | 35 | 5 |
| Defesa da sentinela | 3 | 55 | 48 | 4 |
| Eclipse | 3 | 129 | 26 | 6 |
| Rua noturna | 3 | variável pelo elenco | 26 | 4 |

A sentinela agora tem 40 PV. Mesmo com quatro inimigos ativos durante todas as quatro rodadas, a pressão passiva de `2 × 4 × 4 = 32` não a elimina sozinha. As habilidades inimigas ainda podem afetar a equipe e a missão precisa ser testada em partida.

Nos ataques iniciais comuns, o dano bruto por alvo antes de armadura, resistências e efeitos varia de 8 a 14; ataques em linha aplicam esse valor a cada alvo válido. Essa referência não prevê frequência de compra, gasto de Iniciativa, Quick, Marcado, inteligência dos inimigos nem eliminações por minion. Portanto não é uma estimativa de duração de partida ou taxa de vitória.

## Critério ainda pendente

Executar séries de partidas no Godot 4.6 com diferentes trios, decks e sementes; registrar duração, taxa de vitória e perdas por missão, distribuição de turnos e gastos de Essência. Ajustar PV, reforços e recompensas com esses dados antes de classificar o balanceamento como validado.

## Faixas-alvo (2026-09-28)

| Atributo | Faixa |
|----------|-------|
| Vida (hp) | 60–120 |
| Impacto / Poder / Armadura / Escudo | 20–40 |
| Dano absoluto (cartas Content `DAMAGE`) | ~20–40 |
| Hits do pack (`actions` `hit`) | modificadores sobre Impacto/Poder (não absolutos) |

Combate deve sentir escala média-alta: heróis sobrevivem alguns golpes, e Manobras ofensivas removem fatias relevantes da Vida.
