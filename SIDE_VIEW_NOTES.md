# Vista Lateral (Side View)

## Como alternar

1. **No combate (HUD):** botão **«Vista: Normal» / «Vista: Lateral»** no painel inferior direito (acima de Encerrar turno).
2. **Configurações (menu):** «Vista de batalha: Normal | Lateral».
3. Preferência salva em `user://hotn3.cfg` (`settings/battle_view_mode`).

Padrão: **Normal** (vista atual top-down/overhead). Lateral é opt-in.

## Comportamento Lateral

- Mapa conceptualmente “de lado”: **aliados à esquerda**, inimigos à direita.
- Ordem esquerda → direita: retaguarda aliada → frente aliada → frente inimiga → retaguarda inimiga.
- Sem rotação de órbita 180° na fase inimiga; em vez disso, a câmera **foca/dá zoom** no inimigo que está jogando a carta.
- Hover (aliado ou inimigo): centra a câmera no sprite e aumenta o zoom.
- A vista Normal permanece intacta e continua o comportamento antigo (órbita na fase inimiga, leve foco em aliados).

Arquivos: `game/CombatPresentation.gd`, `game/GameRoot.gd`.
