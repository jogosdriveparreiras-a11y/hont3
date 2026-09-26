## Não publicado
- Smokes de Status/Campanha passam a carregar `PackBridge` antes de `begin`, pois as missões agora usam inimigos `ent_`.
- Fallback de sprite `assets/cast` em `_sprite_region` usa o quadro inteiro; regras da carta destacam Quick/Chain/Exhaust e efeitos negativos em vermelho.
- `run_checks` redireciona a saída do Godot para log (evita deadlock de pipe no SceneSmoke com retratos grandes) e inclui MergeSmoke.

- Pacotes `ent_`/`ms_` mesclados ao conteúdo principal: heróis do anexo entram na seleção de equipe e cartas externas expandem os pools dos arquétipos via `owner_mapping.json`.
- Removidas as demos separadas do menu (`Demo: elenco` / `Demo: cartas externas`).
- Corrigida tipagem `Array[String]` em `HotNBattle.begin` / `EntityRuntime.deploy`.
- Sprites do elenco `ent_` redesenhados a partir das descrições do HoeDex quando existiam (Kabuki ninja cibernética, Evelyn meio-monstro, Fate de cabelo azul e espada colossal, Mingau humanoide felino, Dominika parasita de vitrine, Hynda bruxa, Madelyn de pele marmórea, Techna com gadgets não letais, Taylor com a alienígena Zaphter). Sem descrição, o desenho segue espécie, papel e tags.

# Histórico da cópia de desenvolvimento

## Pacotes opcionais de cartas e entidades

- Incluídos `addons/hotn3_external_cards/` (cartas `ms_`) e `addons/hotn3_entities/` (elenco `ent_`) sem sobrescrever `Content.gd` nem `BattleState.gd`.
- `PackBridge.gd` injeta heróis `ent_` e cartas `ms_`/`ent_` em `Content` na inicialização e roteia jogada/redesenho por prefixo de ID.
- O caminho principal (Play / campanha / decks) usa o elenco e as cartas expandidos; pastas `addons/` permanecem como fonte.

## Iniciativa, pool único e cartas

- O recurso jogável continua sendo `impulse` (máximo 10), agora exibido como Iniciativa. O antigo modificador de iniciativa saiu das regras.
- Heróis, chefes e minions saem do mesmo pool. `playable: false` impede a escolha do jogador; `minion: true` é a única duplicata permitida no mesmo lado.
- Adversários usam as mesmas cartas. A linha `AÇÕES · INICIATIVA · RECOMPRA · MOVER · DECK · DESCARTE` fica visível nos dois lados e só a fase ativa fica em destaque.
- A mão 2D cresce no hover. Clicar amplia a carta a cerca de metade da tela; outro clique confirma e um clique fora cancela, antes do alvo no sprite. O retrato fica à esquerda para aliados e à direita para inimigos até a ação terminar.

## Passo 5 — auditoria e preparação de entrega

- HUD reorganizado para a mão e os painéis caberem em 1366×768 e 1920×1080; os testes de cena agora verificam os limites dos painéis nas duas resoluções.
- Inclusos o objetivo de campanha nos testes, pausa visual curta no quadro de impacto, documentação de arquitetura, regras, recursos e créditos e preset para exportação Web no renderizador de compatibilidade.
- Exportação e inspeção visual no motor continuam pendentes na ausência de Godot 4.6.

## Passo 4 — conteúdo

Campanha, estrelas, Essência, identidade dos heróis, ajuste de proteção, passiva de cura do Clérigo e inventário dos recursos com hashes.

## Passo 3 — apresentação

Sprites, mão, dano flutuante, partículas, câmera, sons sintetizados, teclado/controle e opções de acessibilidade.

## Passos 1 e 2 — estabilidade e regras

Verificadores, casos de teste Godot, ampliação de alvos, prévia, IA, filtros e editor de deck.
