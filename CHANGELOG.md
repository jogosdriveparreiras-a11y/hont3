# Histórico da cópia de desenvolvimento

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
