# A Fenda das Três Vigílias — campanha VN do HotN3

Este diretório é um módulo separado. Usa os personagens, cartas, retratos, músicas e motor de combate que já estão no projeto. Não substitui arquivos de `game/`, os outros `addons/` nem `project.godot`.

## Jogar

Abra `CampaignRoot.tscn` no editor Godot 4.6 e use **Executar cena atual** (F6). Em Linux/macOS, rode `./addons/hotn3_campaign/run_campaign.sh`; no PowerShell, `./addons/hotn3_campaign/run_campaign.ps1 -Godot C:\caminho\godot.exe`. Esses comandos abrem uma versão da tela inicial com o botão **Campanha** e preservam a tela inicial original do projeto. Para fazer a campanha aparecer também quando se usa **Executar projeto** (F5), configure `res://addons/hotn3_campaign/CampaignRoot.tscn` como cena principal no editor. Essa troca requer uma alteração local em `project.godot`, que não está incluída no pacote.

O módulo estende `game/GameRoot.gd`. Usa `BattleState` e `PackBridge` para iniciar as missões `road`, `ritual` e `eclipse`, com arenas 3D exclusivas geradas por `ArenaBuilder.gd`. Se a API desses arquivos mudar, `CampaignRoot.gd` é o único ponto de integração a ajustar. Não existe duplicação do motor de cartas ou da IA.

## Fluxo

**Alyssa Wine** participa obrigatoriamente das três batalhas. Antes de cada uma, o jogador escolhe dois companheiros entre os personagens jogáveis; a lista exclui todos os adversários e reforços das três missões, inclusive os que só aparecem mais tarde. A primeira batalha elimina Akuji, Fate e Evelyn e seus reforços; a segunda exige resistir a cinco rodadas contra Techna, Nero e Taylor; a terceira derrota o Guardião do Eclipse protegido por Dominika e Leona. Cada luta recebe uma arena diferente: estrada alagada, círculo de cinzas e observatório do eclipse.

Após cada vitória, o módulo oferece três cartas ainda não possuídas, priorizando uma Evoluída de cada personagem que lutou. Uma escolha entra em `owned_cards` pelo mesmo método do jogo e no mesmo save `user://hotn3.cfg`. Quando um herói já possui todas as cartas elegíveis, outras cartas novas dos participantes preenchem as três opções. Caso a coleção inteira dos três esteja esgotada, a história prossegue sem uma concessão repetida. Derrotas retornam à seleção do time sem premiar cartas.

O roteiro editável em `story.json` contém as cenas de abertura, dois intervalos, o epílogo e três escolhas com consequências no diálogo final. A interface mostra retratos do elenco, escurece o personagem que não está falando, nome do orador, texto gradual, música distinta por capítulo, chuva/cinzas/partículas de eclipse e diálogos que mencionam Alyssa e os dois companheiros selecionados. O save independente `user://hotn3_campaign.cfg` guarda capítulo, escolhas, equipe e ofertas de carta para retomar entre batalhas. Uma luta interrompida é reiniciada desde a preparação.

## Verificar

`python3 addons/hotn3_campaign/verify_campaign.py` confere o roteiro, os encontros, os recursos referenciados e a disponibilidade de três cartas novas na primeira passagem. `python3 tools/lint_gd.py` faz inspeção estrutural de GDScript. A importação, a renderização das arenas, o áudio e uma partida completa precisam ser verificados no Godot 4.6; a inspeção estrutural não equivale a esses testes.
