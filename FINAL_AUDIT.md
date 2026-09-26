# Auditoria do checkpoint do pedido inicial

Legenda: **C** = código ou arquivo presente e inspeção estática concluída, porém execução no motor não validada; **P** = pendente; **A** = adaptado por decisão posterior do usuário. A presença no código não equivale a aprovação do requisito em partida.

| Requisito do anexo | Estado | Evidência ou limite |
| --- | --- | --- |
| Repositório próprio, sem alteração no HotN2 | A | Usuário decidiu continuar sem Git; trabalho feito em cópia local do HotN3. |
| Abre em Godot 4.6 | P | Executável indisponível neste ambiente. |
| Referências de arquivo | C | `verify_content.py` valida as referências da cena ativa. |
| Menu, missão, equipe, decks, início de batalha | C | `GameRoot.gd`; `SceneSmoke.gd` preparado, não executado no motor. |
| Arena 3D, personagens 2D, sombras, cartas 3D com fundo comum | C | Criação dinâmica em `GameRoot.gd`; aspecto visual não inspecionado em execução. |
| Animação da mão, hover, seleção, prévia e alvo | C | `GameRoot.gd`; qualidade visual e interação ainda pendentes. |
| Ações, recompra, deck, descarte e Iniciativa | C | `BattleState.gd`; smoke tests ainda pendentes no Godot. |
| Ataque, técnica, poder, Rápida, Marcado, Chain, área | C | Dados em `Content.gd`, resolução em `BattleState.gd`. |
| Buff, debuff, duração, Counter, Block, Armor, Shield, cura | C | `BattleState.gd`; auditoria dos efeitos em `EFFECTS_AUDIT.md`. |
| Tipos, vantagens na prévia, frente/retaguarda, corpo a corpo e alcance | C | `BattleState.gd`, `GameRoot.gd`; testes de cena não executados. |
| Empurrar, puxar, movimento voluntário | C | `BattleState.gd`; apresentação de movimento aguarda inspeção visual. |
| IA com prioridades, minions, elites, chefe, reforços | C | `BattleState.gd`, `Content.gd`; dificuldade real não medida. |
| Quatro objetivos, cenário, itens, combo, cartas geradas e melhorias | C | Implementados no código; `CampaignSmoke.gd` preparado. |
| Passivas | C | Seis passivas configuradas; cura do Clérigo implementada no passo 4. |
| Ataque, impacto, morte, câmera, tremor, redução do tremor, partículas | C | `CombatPresentation.gd`; sequência e enquadramento sem inspeção visual. |
| Hit stop | C | Pausa visual de 65 ms no quadro do sprite atingido; não pausa a simulação. |
| Áudio e controles de volume | C | `SoundBus.gd` e configurações; audibilidade não avaliada. |
| Vitória, derrota, tentar novamente e salvamento | C | `BattleState.gd`, `GameRoot.gd`; fluxo completo ainda não jogado. |
| Licença de todos os recursos | P | Oito sprites do HotN2 sem autor/licença comprovados; `ASSET_LICENSES.md`. |
| Nenhum recurso Marvel ou arte gerada por IA | C | Inventário `ASSETS.md` e arquivos incluídos. |
| README, GAME_DESIGN, ARCHITECTURE, BALANCE, TESTING | C | Arquivos presentes e atualizados para o código disponível. |
| ASSET_LICENSES e CREDITS completos | P | Arquivos presentes, mas crédito/licença dos oito sprites não identificados. |
| Ausência de erros críticos no console | P | Godot não executado. |
| Ausência de TODOs bloqueadores e cenas essenciais vazias | C | Busca estática e inspeção da cena principal; parsing pendente. |
| Jogo com qualidade de produto final | P | Requer execução, partidas, avaliação visual, correções e licenças. |

Verificações realizadas: `python3 tools/run_checks.py` completa apenas a etapa estática neste ambiente. Godot 4.6, templates de exportação, renderização e teste de desempenho não estão disponíveis aqui. Não existe binário ou export web validado neste pacote; `tools/build_web.py` para antes de exportar se essas dependências faltarem.
