# Auditoria dos 77 efeitos de status

Comparação com a lista fornecida pelo usuário e a [página de efeitos de status](https://marvels-midnight-suns.fandom.com/wiki/Status_Effect) da wiki de *Marvel's Midnight Suns*. Estado: **Carta** = presente em carta equipável ou gerada; **Motor** = aplicado por habilidade inimiga, sem carta equipável; **Adaptado** = versão de linhas ou com valores definidos para dados desconhecidos, sem equivalência exata. O código não foi executado no Godot 4.6, portanto estas categorias são inspeção de código, não comprovação de funcionamento.

| Efeito da referência | Estado | Implementação ou lacuna |
|---|---|---|
| Agamotto’s Gaze | Carta | Visão do porvir: 4 jogadas no próximo turno. |
| All Together Now | Carta | Bênção do grupo atribui ao Clérigo os próximos KOs dos aliados. |
| Banished | Carta | Laço instável retira temporariamente o inimigo da lista de alvos sem contar como KO. |
| Berserk (Enemy) | Carta | Agitação dirigida força a próxima ação a atacar uma unidade da mesma linha. |
| Berserk (Wolverine) | Carta | Jogo de sombras concede Roubo de Vida temporário a cartas de dano. |
| Binary | Carta | Estandarte: +100% de Ataque até perder Bloqueio. |
| Bind | Carta | Armadilha/rede: impede ação e remove Proteção. |
| Bleed | Carta | Dano periódico ignora Bloqueio e Resistência. |
| Blessed | Adaptado | Bênção do grupo dobra dano contra a facção abissal original do jogo. |
| Block | Carta | Absorve dano e permanece até ser consumido. |
| Blood Magic | Carta | Prisma sanguíneo concede Roubo de Vida a cartas de Ataque. |
| Bloodlust | Carta | Frenesi de aço: dano/contra-ataque aplica Sangramento até perder Bloqueio. |
| Bound | Carta | Teia: impede ação e movimento forçado. |
| Chain | Carta | Corrente: permite repetir o alvo ou dividir os acertos. |
| Chaos Field | Adaptado | Campo sagrado concede Resistência a aliados da mesma linha no fim do turno. |
| Concealed | Carta | Não pode ser alvo direto; termina após ação direcionada ou dano de área. |
| Confused | Carta | Distorcer vontade provoca ataque aleatório após cada carta por duas cartas. |
| Corrupted | Adaptado | Dano periódico e propagação a unidades da mesma linha, sem distinção de lado. |
| Counter | Carta | Contra-ataca quem atacou. |
| Critical | Carta | Jogo de sombras concede bônus de dano; não há chance aleatória. |
| Cure | Carta | Campo sagrado remove a lista de estados negativos. |
| Dazed | Carta | Ruído mental bloqueia ação até duas cartas serem jogadas. |
| Drop | Adaptado | Marcador no alvo, chance de KO se empurrado; não há terreno com queda. |
| En Fuego | Carta | Fúria do totem inicia medidor que cresce por KO e amplia Ataque. |
| Enhanced | Carta | Domínio do selo reduz custo e amplia Poderes acima do limiar de Iniciativa. |
| Exhaust | Carta | Cartas exauridas saem da pilha durante o combate. |
| Fast | Carta | Domínio do selo reduz custo de Poderes/Combos. |
| Fatal Fury | Carta | Fúria do totem aumenta o próximo dano e aplica Ferido. |
| Feeding Frenzy | Adaptado | Caça ao objetivo atinge o objetivo de proteção após três cartas; sem civis. |
| Final | Carta | Tempestade impede outras ações daquele herói na rodada. |
| Forceful | Adaptado | Impulso dobrado causa dano de colisão na linha traseira. |
| Forceful Knockback | Adaptado | Martelo impulsor dobra força; sem atravessar objetos posicionados livremente. |
| Free | Carta | Não consome jogada de carta. |
| Frenzy | Motor | Transe de guerra é habilidade inimiga; inimigo age após duas cartas. |
| Full Combo | Carta | Corrente aplica efeito extra se os três acertos forem no mesmo alvo. |
| Full Force | Carta | Instinto do predador aumenta dano ambiental e reduz custo. |
| Fury Totem | Carta | Fúria do totem compra uma carta após KO. |
| Generate | Carta | Runas gera Centelha temporária; exaure ao jogar ou recomprar. |
| Invulnerable | Carta | Guarda absoluta evita dano. |
| Knockback | Adaptado | Empurra da frente para trás; colisão depende de força e linha. |
| Lifesteal | Carta | Corte drenante cura o dano de Vida causado. |
| Limbo’s Grasp | Adaptado | Domínio do selo com Impulso do selo causa 150% do Ataque no portal; não há trajetória. |
| Make ’em Bleed | Carta | Jogo de sombras adiciona dois Sangramentos aos próximos dois danos. |
| Marked | Carta | KO por habilidade devolve uma jogada, no máximo uma por carta. |
| Momentum | Carta | Jogo de sombras permite mover sem custo até usar habilidade não móvel. |
| Naturalist | Carta | Instinto do predador reduz custo de ataques ambientais. |
| Neurally Enhanced | Carta | Domínio do selo começa o próximo turno com quatro jogadas. |
| Next Turn | Carta | Visão do porvir compra carta no turno seguinte. |
| Offensive Rush | Carta | Bênção do grupo: bônus próprio de 25% de Ataque, valor ausente na fonte. |
| Opportunist | Carta | Foco ambiental concede duas ativações ambientais sem custo. |
| Overload | Carta | Selo de ruína explode no início do turno seguinte. |
| Overpowered | Carta | Força total aumenta Ataque em 100%. |
| Perfect Aim | Carta | Foco ambiental concede bônus a dois ataques ambientais; valor próprio de 50%. |
| Portal | Adaptado | Domínio do selo configura o próximo empurrão, sem posição de portal. |
| Protected | Carta | Guarda absoluta evita seleção direta e dano de área. |
| Protecting | Carta | Estandarte evita empurrão até ficar sem Bloqueio. |
| Quick | Carta | KO do alvo devolve uma jogada. |
| Ravenous | Carta | Instinto do predador inicia com cinco níveis, cresce e consome níveis. |
| Resist | Carta | Cancela uma instância de dano e consome uma carga. |
| Roulette | Carta | Eco escolhe um efeito quando comprado. |
| Slow | Carta | Ruído mental aumenta custo de Poderes e Combos. |
| Soulbound | Carta | Elo vital redistribui Vida e reanima unidades ligadas se alguma sobreviver. |
| Spike Bomb | Adaptado | Explode na mesma linha no turno seguinte; sem raio espacial. |
| Strengthened | Carta | +50% de Ataque. |
| Strongest There Is | Adaptado | Força total aumenta Ataque, compra extra e melhora dano, cura, Bloqueio e Escudo das cartas. |
| Stun | Carta | Impede ação, é removido ao sofrer dano e anula Proteção. |
| Summoning | Motor | Círculo instável é habilidade inimiga com preparação e interrupção por dano. |
| Symbiote Skin | Carta | Pele selada prende o próximo atacante corpo a corpo. |
| Taunt | Carta | Desafio força inimigos alcançáveis a escolher o Paladino. |
| Taunted | Carta | Agitação dirigida restringe alvo do inimigo ao aplicador. |
| Unleashed | Carta | Domínio do selo amplia ataques de linha para ambas as linhas. |
| Vampiric Essence | Carta | Prisma sanguíneo concede Roubo de Vida temporário. |
| Vampyre Bite | Adaptado | Dardo tóxico inimigo infecta uma carta na mão, que concede Sangramento ao jogar. |
| Vulnerable | Carta | Aumenta o dano recebido em 50%. |
| Weak | Carta | Reduz o Ataque em 50%. |
| Webbed Up | Carta | Aumenta o dano ambiental recebido em 50%. |
| Wounded | Carta | Sofre dano direto ao jogar carta. |

Várias regras descritas por nomes de personagens e facções da referência não têm equivalente narrativo no projeto. A implementação usa nomes próprios do jogo; adaptar uma regra a linhas ou ao objetivo de proteção não equivale à mecânica espacial integral da referência.
