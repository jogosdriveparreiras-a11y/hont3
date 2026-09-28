# Vista Lateral (Side View)

## Como alternar

1. **No combate (HUD):** botão **«Vista: Normal» / «Vista: Lateral»** no painel inferior direito (acima de Encerrar turno).
2. **Configurações (menu):** «Vista de batalha: Normal | Lateral».
3. Preferência salva em `user://hotn3.cfg` (`settings/battle_view_mode`).

Padrão: **Normal** (vista atual top-down/overhead). Lateral é opt-in.

## Comportamento Lateral

- Mapa conceptualmente “de lado”: **aliados à esquerda**, inimigos à direita.
- Ordem esquerda → direita: retaguarda aliada → frente aliada → frente inimiga → retaguarda inimiga.
- Câmera na vista lateral fica no eixo **+Z** (olhando o campo), **não** em −X — as quatro fileiras no eixo X aparecem como colunas; três divisórias amarelas (ArenaBuilder) separam as colunas.
- Sem rotação de órbita 180° na fase inimiga; em vez disso, a câmera **foca/dá zoom** no inimigo que está jogando a carta.
- **Hover de sprite (unidade):** aplica zoom (~1.55) **no mundo** (`Arena3D` + `Personagens2D` escalam/deslocam em torno do foco). A câmera lateral fica **fixa** (posição/FOV).
- **Hover de carta:** foca o dono **sem** zoom (a mão não cresce).
- A mão 3D (`Cartas3D`) é **filha da câmera** (HUD 3D). Como o zoom move o mundo e não a câmera/FOV, o arco mantém o mesmo tamanho e posição na tela.
- A vista Normal permanece intacta e continua o comportamento antigo (órbita na fase inimiga, leve foco em aliados).

Arquivos: `game/CombatPresentation.gd`, `game/GameRoot.gd`.
