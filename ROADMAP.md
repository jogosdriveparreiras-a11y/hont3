# Plano de conclusão sem Git

## 1. Estabilidade e teste — validado no Godot 4.6.1

O comando único de verificação cobre estrutura, conteúdo, recursos, importação e testes headless de combate/cena. A suíte foi executada com Godot 4.6.1 em 2026-09-27. Permanecem como trabalho contínuo os testes manuais de usabilidade e balanceamento.

## 2. Regras e interface de combate

Implementados e cobertos pela suíte: alvo adjacente, aleatório, frente/trás e qualquer unidade; prévia de dano, defesa, resistência, status e mudança de linha; pontuação de IA por dano efetivo, estados e perfil; coleção automática com filtros e melhorias independentes. Os testes de cena confirmam que cartas adquiridas entram automaticamente no deck. Partidas extensas para ajuste fino de IA e dificuldade continuam como trabalho de balanceamento.

## 3. Apresentação e acesso — implementado no código, aguardando teste no Godot

Adicionados animações dos sprites com recortes específicos dos arquivos existentes, movimento da mão e descarte, textos e partículas de dano/cura/defesa, câmera por ação, efeitos sonoros sintetizados, música e ambiente com controles separados, teclado/controle para cartas, alvos, recompra, movimento e turno, além de redução de tremor/flashes/movimento e velocidade de animação. As opções são salvas. Os testes estruturais passaram; as entradas, o enquadramento, a audibilidade e a renderização precisam de validação visual e de execução no Godot 4.6, ausente neste ambiente.

## 4. Conteúdo e identidade — código e documentação realizados, validações pendentes

Os 27 personagens HotN têm ficha, atributos, aprimoramento e cartas. As cinco missões possuem briefing, objetivo e sequência de desbloqueio. Vitórias registram até três estrelas e concedem Essência sem recompensa repetida; melhorias e modificações gastam esse recurso. A proteção da sentinela foi ajustada para resistir à pressão passiva máxima. `ASSETS.md` registra as artes HotN e os pacotes MZ; os oito recursos antigos sem licença foram substituídos. Partidas para medir dificuldade e duração continuam pendentes.

## 5. Validação e entrega — suíte automatizada concluída

O HUD e a coleção são verificados nas duas resoluções solicitadas. A suíte cobre os cinco objetivos de missão, importação, parsing e testes headless no Godot 4.6.1. Os oito sprites antigos sem proveniência foram substituídos por recursos MZ documentados. O preset Web está pronto, mas a exportação exige templates 4.6; partidas extensas, desempenho e inspeção visual manual continuam sendo o próximo passo de produção.
