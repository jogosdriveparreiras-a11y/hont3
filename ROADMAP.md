# Plano de conclusão sem Git

## 1. Estabilidade e teste — executado no ambiente disponível

Corrigir erros identificáveis pela leitura do motor, exigir todos os acertos de Chain e registrar eliminações por impacto para Quick/Marcado. Criar um único comando de verificação e testes headless de combate/cena. As verificações estáticas passaram; importação e execução no Godot 4.6 permanecem pendentes por ausência do executável neste ambiente. A primeira etapa só poderá ser aprovada integralmente após executar `python3 tools/run_checks.py --godot /caminho/para/godot` sem erros.

## 2. Regras e interface de combate

Implementados em código: alvo adjacente, aleatório, frente/trás e qualquer unidade; prévia de dano, defesa, resistência, status e mudança de linha; pontuação de IA por dano efetivo, estados e perfil; editor de decks com seleção de slot/carta, filtros por classe/tipo/raridade, melhorias independentes e limite de cópias. Cinco cartas equipáveis exercitam os novos alvos. As verificações estáticas passaram. Testar as cartas em partidas, regras de cenário, interface e IA no Godot permanece pendente; sem isso o passo não está validado integralmente.

## 3. Apresentação e acesso — implementado no código, aguardando teste no Godot

Adicionados animações dos sprites com recortes específicos dos arquivos existentes, movimento da mão e descarte, textos e partículas de dano/cura/defesa, câmera por ação, efeitos sonoros sintetizados, música e ambiente com controles separados, teclado/controle para cartas, alvos, recompra, movimento e turno, além de redução de tremor/flashes/movimento e velocidade de animação. As opções são salvas. Os testes estruturais passaram; as entradas, o enquadramento, a audibilidade e a renderização precisam de validação visual e de execução no Godot 4.6, ausente neste ambiente.

## 4. Conteúdo e identidade — código e documentação realizados, validações pendentes

Seis heróis receberam função, história e descrição de passiva; a cura passiva do Clérigo foi implementada. As quatro missões ganharam briefing, objetivo e sequência de desbloqueio. Vitórias registram recorde de até três estrelas e concedem Essência sem recompensa repetida; melhorias e modificações de cartas agora gastam esse recurso. A proteção da sentinela foi ajustada para resistir à pressão passiva máxima. `BALANCE.md` registra números e hipóteses; partidas para medir dificuldade e duração no Godot permanecem pendentes. `ASSETS.md` registra origem local e hashes dos sprites; sua licença não pôde ser confirmada. Fontes de cenas antigas e música sem proveniência foram removidas; o áudio atual é sintetizado no código. Assim, a validação integral do passo 4 ainda depende de testes e dos direitos das imagens.

## 5. Validação e entrega — executado até o limite do ambiente

Reorganizados HUD e editor de decks para as duas resoluções solicitadas, adicionadas verificações de limites das regiões da interface e dos quatro objetivos de missão, documentação de arquitetura/design/licenças/créditos e auditoria do checklist inicial. O projeto usa renderizador de compatibilidade e tem preset e comando para exportação Web após os testes. Verificações estáticas passaram. A tentativa de obter o editor oficial foi impedida pela rede; Godot 4.6 e templates não estão instalados. Importação, parsing, console, screenshots reais, partidas, desempenho e exportação permanecem pendentes. Licenças de oito sprites também não estão comprovadas. `FINAL_AUDIT.md` mantém os itens abertos; o ZIP é fonte de desenvolvimento, não executável final.
