# Mapeamento de animações de cartas (HotN3)

Regra: **exatamente 1** `anim_self` (cast) + **1** `anim_target` por carta.
Fontes: RM sheets + Effekseer basenames via `FxPlayer`/`RmAnimPlayer`.

Total: **553** cartas.

## Distribuição cast (self)

| anim_self | qtd |
|---|---:|
| `guard` | 47 |
| `cast` | 46 |
| `Neutral1` | 46 |
| `buff` | 46 |
| `Neutral2` | 46 |
| `Special1` | 46 |
| `Special2` | 44 |
| `Special3` | 44 |
| `fire` | 44 |
| `lightning` | 44 |
| `light` | 19 |
| `BreathLight` | 12 |
| `HeartMark1` | 11 |
| `summon` | 9 |
| `Song1` | 8 |
| `wind` | 8 |
| `BreathFire` | 6 |
| `darkness` | 6 |
| `BreathDarkness` | 5 |
| `Smokescreen` | 5 |
| `thunder` | 4 |
| `BreathThunder` | 4 |
| `ice` | 3 |

## Distribuição target

| anim_target | qtd |
|---|---:|
| `status` | 30 |
| `debuff` | 30 |
| `shield` | 29 |
| `stun` | 29 |
| `StarsHit` | 29 |
| `bind` | 29 |
| `hit` | 27 |
| `HitSP1` | 26 |
| `HitSP2` | 26 |
| `blow` | 26 |
| `CrossHit` | 26 |
| `slash` | 26 |
| `slow` | 24 |
| `push` | 20 |
| `Explosion1` | 17 |
| `Protection` | 15 |
| `Shield` | 15 |
| `Reflection` | 15 |
| `confusion` | 8 |
| `heal` | 7 |
| `Light1` | 7 |
| `absorb` | 7 |
| `bleed` | 6 |
| `Light2` | 6 |
| `Light3` | 6 |
| `Light4` | 6 |
| `pull` | 6 |
| `SlashSP1` | 4 |
| `claw` | 3 |
| `Darkness1` | 3 |
| `Darkness2` | 3 |
| `SlashSP2` | 3 |
| `ClawSP1` | 3 |
| `Thunder1` | 3 |
| `Fire1` | 3 |
| `CrossSlash` | 3 |
| `explosion` | 3 |
| `pierce` | 2 |
| `banish` | 2 |
| `PierceSP1` | 2 |
| `ClawSP2` | 2 |
| `SlashSP3` | 2 |
| `Thunder2` | 2 |
| `Fire2` | 2 |
| `Explosion2` | 2 |
| `Ice1` | 1 |
| `PierceSP2` | 1 |
| `arrow` | 1 |
| `Wind1` | 1 |
| `Thunder3` | 1 |
| `CrossClaw` | 1 |
| `Arrow` | 1 |
| `Shoot1` | 1 |

## Tabela completa

| id | nome | classe | origem | anim_self | anim_target |
|---|---|---|---|---|---|
| `abrigo` | Abrigo sagrado | SKILL | content | `HeartMark1` | `Reflection` |
| `agitar` | Agitação dirigida | SKILL | content | `guard` | `status` |
| `armadilha` | Armadilha curta | SKILL | content | `Neutral1` | `status` |
| `armadilha_tempo` | Laço instável | SKILL | content | `buff` | `shield` |
| `balanca` | Balança de cinzas | SKILL | content | `light` | `heal` |
| `barreira` | Barreira arcana | SKILL | content | `buff` | `Shield` |
| `benzer` | Bênção do grupo | SKILL | content | `BreathLight` | `status` |
| `benção` | Bênção persistente | SKILL | content | `BreathLight` | `shield` |
| `brilho` | Clarão | ATTACK | content | `lightning` | `StarsHit` |
| `campo_sagrado` | Campo sagrado | SKILL | content | `BreathLight` | `StarsHit` |
| `centelha` | Centelha | ATTACK | content | `BreathThunder` | `Thunder1` |
| `cerco_frente` | Cerco frontal | POWER | content | `fire` | `slash` |
| `chuva` | Chuva de pontas | POWER | content | `lightning` | `HitSP2` |
| `contra` | Resposta de aço | SKILL | content | `Neutral1` | `shield` |
| `controlar_mente` | Ruído mental | SKILL | content | `Neutral2` | `StarsHit` |
| `corrente` | Corte em sequência | ATTACK | content | `Special2` | `SlashSP2` |
| `corte` | Corte firme | ATTACK | content | `Special3` | `SlashSP1` |
| `corte_adj` | Corte de flanco | ATTACK | content | `Special2` | `SlashSP1` |
| `corte_dreno` | Corte drenante | ATTACK | content | `fire` | `CrossSlash` |
| `cura` | Cura vital | SKILL | content | `HeartMark1` | `Light1` |
| `distorcer` | Distorcer vontade | SKILL | content | `buff` | `bind` |
| `dominio` | Domínio do selo | SKILL | content | `Neutral1` | `stun` |
| `dueto` | Pacto de batalha | COMBO | content | `Special2` | `CrossHit` |
| `eco` | Eco arcano | SKILL | content | `summon` | `shield` |
| `egide` | Égide | SKILL | content | `buff` | `Reflection` |
| `elo_vital` | Elo vital | SKILL | content | `HeartMark1` | `Light4` |
| `escudo_forte` | Muralha | SKILL | content | `buff` | `Protection` |
| `esquiva` | Passo oculto | SKILL | content | `Neutral1` | `shield` |
| `estandarte` | Estandarte de defesa | SKILL | content | `buff` | `bind` |
| `explosao` | Detonação rúnica | POWER | content | `lightning` | `explosion` |
| `fagulha_incerta` | Fagulha incerta | ATTACK | content | `Special3` | `CrossHit` |
| `falcon` | Olho da falcoaria | SKILL | content | `Special1` | `status` |
| `fervor` | Fervor | SKILL | content | `Neutral2` | `debuff` |
| `flanquear` | Flanquear | SKILL | content | `Neutral2` | `shield` |
| `flecha` | Flecha certeira | ATTACK | content | `Special2` | `pierce` |
| `foco` | Foco do caçador | SKILL | content | `cast` | `bind` |
| `foco_ambiental` | Foco ambiental | SKILL | content | `cast` | `status` |
| `frenesi_aco` | Frenesi de aço | SKILL | content | `cast` | `debuff` |
| `furia` | Fúria disciplinada | POWER | content | `wind` | `shield` |
| `furia_total` | Força total | SKILL | content | `Neutral1` | `StarsHit` |
| `furia_totem` | Fúria do totem | SKILL | content | `wind` | `debuff` |
| `furto` | Furto veloz | ATTACK | content | `fire` | `hit` |
| `golpe_largo` | Arco de aço | ATTACK | content | `Special3` | `slash` |
| `golpe_oculto` | Punhal nas sombras | POWER | content | `Smokescreen` | `Shoot1` |
| `guarda` | Postura de guarda | SKILL | content | `buff` | `Protection` |
| `guarda_absoluta` | Guarda absoluta | SKILL | content | `guard` | `Shield` |
| `investida` | Investida de ferro | ATTACK | content | `fire` | `Explosion1` |
| `item_antidote` | Antídoto | SKILL | content | `Special1` | `debuff` |
| `item_bomb` | Bomba | ATTACK | content | `lightning` | `hit` |
| `item_potion` | Poção | SKILL | content | `light` | `Light1` |
| `jogo_sombras` | Jogo de sombras | SKILL | content | `darkness` | `shield` |
| `julgamento` | Julgamento | POWER | content | `fire` | `shield` |
| `juramento` | Juramento de aço | SKILL | content | `Special1` | `stun` |
| `luz` | Luz incisiva | ATTACK | content | `BreathLight` | `HitSP2` |
| `marca` | Alvo exposto | SKILL | content | `Special1` | `shield` |
| `martelo` | Golpe de martelo | ATTACK | content | `lightning` | `pull` |
| `martelo_pesado` | Martelo impulsor | ATTACK | content | `Special2` | `push` |
| `muralha_viva` | Muralha viva | SKILL | content | `guard` | `Protection` |
| `pele_rigida` | Pele selada | SKILL | content | `cast` | `stun` |
| `portal_impulso` | Impulso do selo | ATTACK | content | `lightning` | `push` |
| `predador` | Instinto do predador | SKILL | content | `Neutral2` | `bind` |
| `preparo` | Reunir forças | SKILL | content | `Special1` | `StarsHit` |
| `prisma` | Prisma de defesa | SKILL | content | `cast` | `bind` |
| `prisma_sangue` | Prisma sanguíneo | SKILL | content | `Special1` | `debuff` |
| `provocar` | Desafio | SKILL | content | `Neutral1` | `shield` |
| `punhal` | Punhal veloz | ATTACK | content | `Neutral2` | `Arrow` |
| `purificar` | Purificação | SKILL | content | `cast` | `shield` |
| `queda` | Passagem perigosa | SKILL | content | `Neutral2` | `Explosion1` |
| `raio` | Raio concentrado | ATTACK | content | `thunder` | `Thunder2` |
| `rede` | Rede de caça | SKILL | content | `Neutral1` | `pull` |
| `resgate` | Resgate | SKILL | content | `light` | `Light3` |
| `runas` | Runas móveis | SKILL | content | `Special1` | `shield` |
| `ruptura` | Quebra de escudo | POWER | content | `buff` | `Shield` |
| `salva` | Salva rente | ATTACK | content | `Special3` | `HitSP1` |
| `selo_ruina` | Selo de ruína | POWER | content | `Special3` | `blow` |
| `sentenca` | Sentença | POWER | content | `Neutral2` | `blow` |
| `sombra` | Dança sombria | POWER | content | `Special3` | `shield` |
| `teia` | Teia de caça | SKILL | content | `Special1` | `shield` |
| `tempestade` | Tempestade dos selos | POWER | content | `cast` | `shield` |
| `tiro_retaguarda` | Disparo de retaguarda | POWER | content | `guard` | `Reflection` |
| `veneno` | Flecha contaminada | ATTACK | content | `fire` | `PierceSP1` |
| `visao` | Visão do porvir | SKILL | content | `Neutral1` | `stun` |
| `ent_adam_abrigo_rapido` | Abrigo rápido | ESTADO | entities | `guard` | `shield` |
| `ent_adam_armadilha_de_campo` | Armadilha de campo | ATTACK | entities | `cast` | `hit` |
| `ent_adam_avaliar_o_risco` | Avaliar o risco | ESTADO | entities | `Neutral1` | `status` |
| `ent_adam_cobertura_improvisada` | Cobertura improvisada | ESTADO | entities | `buff` | `Protection` |
| `ent_adam_cuidar_dos_feridos` | Cuidar dos feridos | ESTADO | entities | `light` | `heal` |
| `ent_adam_faca_de_sobrevivencia` | Faca de sobrevivência | ATTACK | entities | `Neutral2` | `HitSP1` |
| `ent_adam_nao_vou_deixar` | Não vou deixar | ESTADO | entities | `guard` | `Shield` |
| `ent_adam_puxar_para_tras` | Puxar para trás | ATTACK | entities | `Special2` | `push` |
| `ent_adam_rota_de_fuga` | Rota de fuga | ESTADO | entities | `Special1` | `debuff` |
| `ent_adam_ultima_linha` | Última linha | ATTACK | entities | `Special3` | `stun` |
| `ent_akuji_asas_de_energia_negra` | Asas de energia negra | ESTADO | entities | `cast` | `StarsHit` |
| `ent_akuji_brasa_negra` | Brasa negra | ATTACK | entities | `fire` | `bind` |
| `ent_akuji_chama_sem_luz` | Chama sem luz | ATTACK | entities | `BreathLight` | `slow` |
| `ent_akuji_cinzas_retornam` | Cinzas retornam | ATTACK | entities | `lightning` | `HitSP2` |
| `ent_akuji_escamas_da_fornalha` | Escamas da fornalha | ESTADO | entities | `BreathFire` | `Reflection` |
| `ent_akuji_forma_de_cinzas` | Forma de cinzas | ESTADO | entities | `Neutral1` | `status` |
| `ent_akuji_incendio_dirigido` | Incêndio dirigido | ATTACK | entities | `Neutral2` | `blow` |
| `ent_akuji_leitura_de_pactos` | Leitura de pactos | ESTADO | entities | `buff` | `debuff` |
| `ent_akuji_noite_em_combustao` | Noite em combustão | ATTACK | entities | `Special2` | `CrossHit` |
| `ent_akuji_sopro_abrasador` | Sopro abrasador | ATTACK | entities | `Special3` | `slash` |
| `ent_alexis_alerta_aos_gritos` | Alerta aos gritos | ESTADO | entities | `Song1` | `stun` |
| `ent_alexis_colecao_improvavel` | Coleção improvável | ESTADO | entities | `guard` | `shield` |
| `ent_alexis_coragem_tardia` | Coragem tardia | ATTACK | entities | `fire` | `hit` |
| `ent_alexis_distracao_teatral` | Distração teatral | ESTADO | entities | `Special1` | `StarsHit` |
| `ent_alexis_escapar_para_cobertura` | Escapar para cobertura | ESTADO | entities | `cast` | `Protection` |
| `ent_alexis_objeto_arremessado` | Objeto arremessado | ATTACK | entities | `lightning` | `HitSP1` |
| `ent_alexis_primeiros_socorros` | Primeiros socorros | ESTADO | entities | `light` | `Light1` |
| `ent_alexis_proteger_um_amigo` | Proteger um amigo | ESTADO | entities | `guard` | `Shield` |
| `ent_alexis_reunir_o_grupo` | Reunir o grupo | ESTADO | entities | `Neutral1` | `bind` |
| `ent_alexis_tapete_sob_os_pes` | Tapete sob os pés | ATTACK | entities | `Neutral2` | `slow` |
| `ent_alistair_arco_de_luz` | Arco de luz | ATTACK | entities | `HeartMark1` | `HitSP2` |
| `ent_alistair_armadura_instantanea` | Armadura instantânea | ESTADO | entities | `buff` | `Reflection` |
| `ent_alistair_corrida_desesperada` | Corrida desesperada | ATTACK | entities | `Special2` | `Explosion1` |
| `ent_alistair_desafio_da_vanguarda` | Desafio da vanguarda | ESTADO | entities | `buff` | `shield` |
| `ent_alistair_esconjuro` | Esconjuro | ATTACK | entities | `Special3` | `blow` |
| `ent_alistair_espada_sagrada` | Espada sagrada | ATTACK | entities | `fire` | `CrossHit` |
| `ent_alistair_liga_ouro_aco` | Liga ouro-aço | ESTADO | entities | `guard` | `Protection` |
| `ent_alistair_muralha_luminosa` | Muralha luminosa | ESTADO | entities | `buff` | `Shield` |
| `ent_alistair_punho_de_armadura` | Punho de armadura | ATTACK | entities | `cast` | `slash` |
| `ent_alistair_tempo_de_reacao` | Tempo de reação | ESTADO | entities | `Special1` | `status` |
| `ent_alyssa_wine_a_filha_dele` | A Filha Dele | ESTADO | entities | `darkness` | `slow` |
| `ent_alyssa_wine_a_filha_dele_plus` | A Filha Dele+ | ESTADO | entities | `darkness` | `debuff` |
| `ent_alyssa_wine_bastao_retratil` | Bastão Retrátil | ATTACK | entities | `lightning` | `slash` |
| `ent_alyssa_wine_bastao_retratil_plus` | Bastão Retrátil+ | ATTACK | entities | `Neutral2` | `hit` |
| `ent_alyssa_wine_desvantagem_tormenta` | Tormenta | DESVANTAGEM | entities | `ice` | `blow` |
| `ent_alyssa_wine_garras_e_presas` | Garras e Presas | ATTACK | entities | `Special2` | `claw` |
| `ent_alyssa_wine_garras_e_presas_plus` | Garras e Presas+ | ATTACK | entities | `Special3` | `bleed` |
| `ent_alyssa_wine_intelecto` | Intelecto | ESTADO | entities | `Neutral1` | `stun` |
| `ent_alyssa_wine_intelecto_plus` | Intelecto+ | ESTADO | entities | `Special1` | `StarsHit` |
| `ent_alyssa_wine_premonicao` | Premonição | ESTADO | entities | `cast` | `Reflection` |
| `ent_alyssa_wine_premonicao_plus` | Premonição+ | ESTADO | entities | `Neutral1` | `bind` |
| `ent_alyssa_wine_regeneracao` | Regeneração | ESTADO | entities | `BreathLight` | `Light2` |
| `ent_alyssa_wine_regeneracao_plus` | Regeneração+ | ESTADO | entities | `HeartMark1` | `Light3` |
| `ent_alyssa_wine_relampago` | Relâmpago | ATTACK | entities | `thunder` | `HitSP1` |
| `ent_alyssa_wine_relampago_plus` | Relâmpago+ | ATTACK | entities | `BreathThunder` | `HitSP2` |
| `ent_alyssa_wine_super_sentidos` | Super Sentidos | ESTADO | entities | `Neutral2` | `status` |
| `ent_alyssa_wine_super_sentidos_plus` | Super Sentidos+ | ESTADO | entities | `Special1` | `debuff` |
| `ent_ashlee_analise_completa` | Análise completa | ESTADO | entities | `cast` | `stun` |
| `ent_ashlee_armadilha_de_isolamento` | Armadilha de isolamento | ESTADO | entities | `Neutral1` | `StarsHit` |
| `ent_ashlee_compartilhar_equipamento` | Compartilhar equipamento | ESTADO | entities | `guard` | `shield` |
| `ent_ashlee_dados_de_campo` | Dados de campo | ESTADO | entities | `Neutral2` | `hit` |
| `ent_ashlee_disparo_de_contencao` | Disparo de contenção | ATTACK | entities | `fire` | `CrossHit` |
| `ent_ashlee_isolar_alvo` | Isolar alvo | ATTACK | entities | `lightning` | `push` |
| `ent_ashlee_kit_medico` | Kit médico | ESTADO | entities | `light` | `Light4` |
| `ent_ashlee_protocolo_de_quarentena` | Protocolo de quarentena | ESTADO | entities | `buff` | `bind` |
| `ent_ashlee_quarentena_total` | Quarentena total | ATTACK | entities | `Special2` | `slow` |
| `ent_ashlee_scanner_de_soma` | Scanner de Soma | ESTADO | entities | `Special1` | `status` |
| `ent_daeva_aviso_por_radio` | Aviso por rádio | ESTADO | entities | `cast` | `debuff` |
| `ent_daeva_cobertura_de_corredor` | Cobertura de corredor | ATTACK | entities | `guard` | `push` |
| `ent_daeva_distracao_arriscada` | Distração arriscada | ESTADO | entities | `Neutral1` | `stun` |
| `ent_daeva_lealdade_teimosa` | Lealdade teimosa | ESTADO | entities | `light` | `absorb` |
| `ent_daeva_moto_de_fuga` | Moto de fuga | ESTADO | entities | `Neutral2` | `StarsHit` |
| `ent_daeva_passo_despercebido` | Passo despercebido | ESTADO | entities | `buff` | `bind` |
| `ent_daeva_plano_de_assalto` | Plano de assalto | ESTADO | entities | `Special1` | `hit` |
| `ent_daeva_saida_calculada` | Saída calculada | ESTADO | entities | `cast` | `slow` |
| `ent_daeva_tiro_de_airsoft` | Tiro de airsoft | ATTACK | entities | `Special3` | `pierce` |
| `ent_daeva_todos_para_fora` | Todos para fora | ESTADO | entities | `guard` | `Protection` |
| `ent_damian_alrosa_clausula_oculta` | Cláusula oculta | ATTACK | entities | `fire` | `HitSP1` |
| `ent_damian_alrosa_executar_contrato` | Executar contrato | ATTACK | entities | `lightning` | `HitSP2` |
| `ent_damian_alrosa_oferta_irrecusavel` | Oferta irrecusável | ESTADO | entities | `Neutral1` | `status` |
| `ent_damian_alrosa_pacto_irrevogavel` | Pacto irrevogável | ATTACK | entities | `Special2` | `blow` |
| `ent_damian_alrosa_pocao_negociada` | Poção negociada | ESTADO | entities | `light` | `heal` |
| `ent_damian_alrosa_preco_da_promessa` | Preço da promessa | ATTACK | entities | `Special3` | `CrossHit` |
| `ent_damian_alrosa_recurso_reservado` | Recurso reservado | ESTADO | entities | `guard` | `Shield` |
| `ent_damian_alrosa_rede_de_contatos` | Rede de contatos | ESTADO | entities | `Neutral2` | `hit` |
| `ent_damian_alrosa_renegociar_termos` | Renegociar termos | ESTADO | entities | `buff` | `debuff` |
| `ent_damian_alrosa_ritual_condicionado` | Ritual condicionado | ESTADO | entities | `Special1` | `stun` |
| `ent_dominika_seur_absorver_impacto` | Absorver impacto | ESTADO | entities | `light` | `Light1` |
| `ent_dominika_seur_avanco_colossal` | Avanço colossal | ATTACK | entities | `fire` | `push` |
| `ent_dominika_seur_campo_de_massa` | Campo de massa | ESTADO | entities | `guard` | `Reflection` |
| `ent_dominika_seur_corpo_acolchoado` | Corpo acolchoado | ESTADO | entities | `guard` | `shield` |
| `ent_dominika_seur_engolfamento` | Engolfamento | ATTACK | entities | `lightning` | `slash` |
| `ent_dominika_seur_esmagamento_lento` | Esmagamento lento | ATTACK | entities | `Special2` | `blow` |
| `ent_dominika_seur_massa_em_avanco` | Massa em avanço | ATTACK | entities | `Special3` | `Explosion1` |
| `ent_dominika_seur_onda_de_engolfamento` | Onda de engolfamento | ATTACK | entities | `wind` | `HitSP1` |
| `ent_dominika_seur_pressao_inabalavel` | Pressão inabalável | ESTADO | entities | `cast` | `shield` |
| `ent_dominika_seur_regeneracao_volumosa` | Regeneração volumosa | ESTADO | entities | `BreathLight` | `Light2` |
| `ent_dylan_atrair_atencao` | Atrair atenção | ATTACK | entities | `fire` | `HitSP2` |
| `ent_dylan_avisar_o_perigo` | Avisar o perigo | ESTADO | entities | `Neutral1` | `StarsHit` |
| `ent_dylan_buscar_ajuda` | Buscar ajuda | ESTADO | entities | `Neutral2` | `bind` |
| `ent_dylan_ficar_junto` | Ficar junto | ESTADO | entities | `guard` | `Protection` |
| `ent_dylan_guardar_a_porta` | Guardar a porta | ESTADO | entities | `buff` | `Shield` |
| `ent_dylan_nao_abandonar_ninguem` | Não abandonar ninguém | ESTADO | entities | `light` | `Light3` |
| `ent_dylan_nao_entre_em_panico` | Não entre em pânico | ESTADO | entities | `light` | `Light4` |
| `ent_dylan_saida_da_cafeteria` | Saída da cafeteria | ESTADO | entities | `Special1` | `slow` |
| `ent_dylan_versos_de_coragem` | Versos de coragem | ESTADO | entities | `cast` | `status` |
| `ent_dylan_xicara_improvisada` | Xícara improvisada | ATTACK | entities | `lightning` | `CrossHit` |
| `ent_evelyn_graves_arrastar_consciencia` | Arrastar consciência | ATTACK | entities | `darkness` | `slash` |
| `ent_evelyn_graves_eco_invocado` | Eco invocado | ESTADO | entities | `summon` | `Light2` |
| `ent_evelyn_graves_encanto_predatorio` | Encanto predatório | ATTACK | entities | `Special2` | `HitSP1` |
| `ent_evelyn_graves_fio_de_marionete` | Fio de marionete | ESTADO | entities | `Song1` | `confusion` |
| `ent_evelyn_graves_porta_no_vazio` | Porta no vazio | ESTADO | entities | `BreathDarkness` | `banish` |
| `ent_evelyn_graves_puxao_do_reino_quebrado` | Puxão do Reino Quebrado | ATTACK | entities | `Smokescreen` | `pull` |
| `ent_evelyn_graves_reino_escancarado` | Reino escancarado | ATTACK | entities | `BreathDarkness` | `banish` |
| `ent_evelyn_graves_ruptura_psiquica` | Ruptura psíquica | ATTACK | entities | `Special3` | `blow` |
| `ent_evelyn_graves_sombra_ilusoria` | Sombra ilusória | ESTADO | entities | `Smokescreen` | `Darkness1` |
| `ent_evelyn_graves_teatro_da_mente` | Teatro da mente | ESTADO | entities | `Song1` | `confusion` |
| `ent_fate_dever_da_alfandega` | Dever da alfândega | ESTADO | entities | `cast` | `hit` |
| `ent_fate_espada_da_fronteira` | Espada da fronteira | ATTACK | entities | `fire` | `push` |
| `ent_fate_fenda_de_aco` | Fenda de aço | ATTACK | entities | `lightning` | `Explosion1` |
| `ent_fate_golpe_de_custodia` | Golpe de custódia | ATTACK | entities | `Special2` | `HitSP2` |
| `ent_fate_guarda_interdimensional` | Guarda interdimensional | ESTADO | entities | `buff` | `Reflection` |
| `ent_fate_julgamento_da_fronteira` | Julgamento da fronteira | ATTACK | entities | `Special3` | `CrossHit` |
| `ent_fate_lamina_perfurante` | Lâmina perfurante | ATTACK | entities | `fire` | `SlashSP1` |
| `ent_fate_passo_de_fronteira` | Passo de fronteira | ATTACK | entities | `lightning` | `slash` |
| `ent_fate_retaliacao_imediata` | Retaliação imediata | ESTADO | entities | `Neutral1` | `debuff` |
| `ent_fate_sentir_anomalia` | Sentir anomalia | ESTADO | entities | `Neutral2` | `stun` |
| `ent_hynda_valdtagen_chuva_de_glifos` | Chuva de glifos | ATTACK | entities | `Special2` | `HitSP1` |
| `ent_hynda_valdtagen_circulo_planar` | Círculo planar | ATTACK | entities | `Special3` | `StarsHit` |
| `ent_hynda_valdtagen_glifo_ofensivo` | Glifo ofensivo | ATTACK | entities | `fire` | `HitSP2` |
| `ent_hynda_valdtagen_meteoro_continental` | Meteoro continental | ATTACK | entities | `lightning` | `blow` |
| `ent_hynda_valdtagen_meteoro_menor` | Meteoro menor | ATTACK | entities | `Neutral2` | `push` |
| `ent_hynda_valdtagen_pocao_adaptativa` | Poção adaptativa | ESTADO | entities | `Special1` | `bind` |
| `ent_hynda_valdtagen_pocao_restauradora` | Poção restauradora | ESTADO | entities | `light` | `absorb` |
| `ent_hynda_valdtagen_portal_da_bruxa` | Portal da bruxa | ESTADO | entities | `summon` | `slow` |
| `ent_hynda_valdtagen_reescrever_terreno` | Reescrever terreno | ESTADO | entities | `Neutral1` | `status` |
| `ent_hynda_valdtagen_transmutacao_de_emergencia` | Transmutação de emergência | ESTADO | entities | `light` | `heal` |
| `ent_kabuki_armadura_furtiva` | Armadura furtiva | ESTADO | entities | `buff` | `Protection` |
| `ent_kabuki_danca_cibernetica` | Dança cibernética | ATTACK | entities | `Special2` | `CrossHit` |
| `ent_kabuki_evasao_calculada` | Evasão calculada | ESTADO | entities | `Special1` | `debuff` |
| `ent_kabuki_golpe_acrobatico` | Golpe acrobático | ATTACK | entities | `Special3` | `slash` |
| `ent_kabuki_nocaute_rapido` | Nocaute rápido | ATTACK | entities | `fire` | `hit` |
| `ent_kabuki_operacao_fantasma` | Operação fantasma | ATTACK | entities | `lightning` | `stun` |
| `ent_kabuki_palco_de_sombras` | Palco de sombras | ESTADO | entities | `BreathDarkness` | `Darkness2` |
| `ent_kabuki_sabotar_interface` | Sabotar interface | ATTACK | entities | `cast` | `StarsHit` |
| `ent_kabuki_salto_de_contencao` | Salto de contenção | ATTACK | entities | `Neutral2` | `bind` |
| `ent_kabuki_sensor_desligado` | Sensor desligado | ESTADO | entities | `Neutral1` | `slow` |
| `ent_konrad_corte_de_armagedom` | Corte de Armagedom | ATTACK | entities | `Special2` | `SlashSP2` |
| `ent_konrad_desmontagem` | Desmontagem | ATTACK | entities | `Special3` | `bleed` |
| `ent_konrad_desviar_a_atencao` | Desviar a atenção | ESTADO | entities | `buff` | `status` |
| `ent_konrad_ferida_aberta` | Ferida aberta | ATTACK | entities | `fire` | `HitSP1` |
| `ent_konrad_ilusao_de_cobertura` | Ilusão de cobertura | ESTADO | entities | `guard` | `Shield` |
| `ent_konrad_incisao_precisa` | Incisão precisa | ATTACK | entities | `lightning` | `HitSP2` |
| `ent_konrad_isca_cruel` | Isca cruel | ESTADO | entities | `Special1` | `debuff` |
| `ent_konrad_passo_carniceiro` | Passo carniceiro | ATTACK | entities | `ice` | `Ice1` |
| `ent_konrad_pele_de_escudo` | Pele de escudo | ESTADO | entities | `buff` | `Reflection` |
| `ent_konrad_predador_da_penumbra` | Predador da penumbra | ESTADO | entities | `cast` | `stun` |
| `ent_leona_banquete_de_marbas` | Banquete de Marbas | ATTACK | entities | `Neutral2` | `absorb` |
| `ent_leona_cabelos_famintos` | Cabelos famintos | ATTACK | entities | `Special2` | `bleed` |
| `ent_leona_devoracao` | Devoração | ATTACK | entities | `Special3` | `absorb` |
| `ent_leona_doenca_lembrada` | Doença lembrada | ESTADO | entities | `Neutral1` | `StarsHit` |
| `ent_leona_fios_de_cabelo` | Fios de cabelo | ATTACK | entities | `fire` | `blow` |
| `ent_leona_fome_contagiosa` | Fome contagiosa | ESTADO | entities | `Special1` | `bind` |
| `ent_leona_fome_sem_fim` | Fome sem fim | ESTADO | entities | `cast` | `slow` |
| `ent_leona_forma_parcial` | Forma parcial | ESTADO | entities | `guard` | `shield` |
| `ent_leona_mordida_de_marbas` | Mordida de Marbas | ATTACK | entities | `lightning` | `bleed` |
| `ent_leona_regenerar_pelo_consumo` | Regenerar pelo consumo | ESTADO | entities | `HeartMark1` | `Light1` |
| `ent_lust_corpo_de_projecao` | Corpo de projeção | ESTADO | entities | `Neutral1` | `status` |
| `ent_lust_distracao_sensorial` | Distração sensorial | ATTACK | entities | `Neutral2` | `CrossHit` |
| `ent_lust_emprestar_soma` | Emprestar Soma | ESTADO | entities | `guard` | `Protection` |
| `ent_lust_encanto_de_area` | Encanto de área | ATTACK | entities | `Special2` | `slash` |
| `ent_lust_fluxo_de_energia` | Fluxo de energia | ATTACK | entities | `Special3` | `hit` |
| `ent_lust_ilusao_do_desejo` | Ilusão do desejo | ESTADO | entities | `buff` | `debuff` |
| `ent_lust_projecao_eterea` | Projeção etérea | ESTADO | entities | `Special1` | `stun` |
| `ent_lust_runa_compartilhada` | Runa compartilhada | ESTADO | entities | `cast` | `StarsHit` |
| `ent_lust_runa_de_soma` | Runa de Soma | ESTADO | entities | `light` | `Light3` |
| `ent_lust_transferencia_runica` | Transferência rúnica | ESTADO | entities | `Neutral1` | `bind` |
| `ent_madelyn_ataque_teatral` | Ataque teatral | ATTACK | entities | `fire` | `HitSP1` |
| `ent_madelyn_cortina_de_fumaca` | Cortina de fumaça | ESTADO | entities | `Neutral2` | `slow` |
| `ent_madelyn_disparo_inesperado` | Disparo inesperado | ATTACK | entities | `lightning` | `HitSP2` |
| `ent_madelyn_frenesi_de_palco` | Frenesi de palco | ESTADO | entities | `buff` | `status` |
| `ent_madelyn_improviso_perigoso` | Improviso perigoso | ATTACK | entities | `Special2` | `blow` |
| `ent_madelyn_recuperacao_caotica` | Recuperação caótica | ESTADO | entities | `light` | `Light4` |
| `ent_madelyn_risada_confusa` | Risada confusa | ESTADO | entities | `Special1` | `confusion` |
| `ent_madelyn_riso_cortante` | Riso cortante | ATTACK | entities | `Song1` | `CrossHit` |
| `ent_madelyn_sombra_mentirosa` | Sombra mentirosa | ESTADO | entities | `Smokescreen` | `PierceSP1` |
| `ent_madelyn_ultimo_ato` | Último ato | ATTACK | entities | `Special3` | `slash` |
| `ent_mingau_o_feiticeiro_arranhao_transformador` | Arranhão transformador | ATTACK | entities | `fire` | `hit` |
| `ent_mingau_o_feiticeiro_encantar_subordinado` | Encantar subordinado | ESTADO | entities | `cast` | `debuff` |
| `ent_mingau_o_feiticeiro_fios_de_marionete` | Fios de marionete | ESTADO | entities | `Song1` | `confusion` |
| `ent_mingau_o_feiticeiro_gato_intangivel` | Gato intangível | ESTADO | entities | `Neutral1` | `stun` |
| `ent_mingau_o_feiticeiro_reinado_da_varinha` | Reinado da varinha | ATTACK | entities | `lightning` | `HitSP1` |
| `ent_mingau_o_feiticeiro_sabotagem_felina` | Sabotagem felina | ESTADO | entities | `Neutral2` | `StarsHit` |
| `ent_mingau_o_feiticeiro_salto_impossivel` | Salto impossível | ATTACK | entities | `Special2` | `HitSP2` |
| `ent_mingau_o_feiticeiro_tinta_anomala` | Tinta anômala | ATTACK | entities | `Special3` | `blow` |
| `ent_mingau_o_feiticeiro_transformacao_em_cadeia` | Transformação em cadeia | ATTACK | entities | `fire` | `CrossHit` |
| `ent_mingau_o_feiticeiro_varinha_roubada` | Varinha roubada | ESTADO | entities | `buff` | `bind` |
| `ent_mutante_generico_barreira_condensada` | Barreira condensada | ESTADO | entities | `guard` | `Shield` |
| `ent_mutante_generico_canalizar_ordem` | Canalizar ordem | ESTADO | entities | `Special1` | `hit` |
| `ent_mutante_generico_carga_instavel` | Carga instável | ATTACK | entities | `lightning` | `slash` |
| `ent_mutante_generico_descarga_total` | Descarga total | ATTACK | entities | `cast` | `HitSP1` |
| `ent_mutante_generico_feixe_concentrado` | Feixe concentrado | ATTACK | entities | `Neutral2` | `slow` |
| `ent_mutante_generico_massa_elemental` | Massa elemental | ESTADO | entities | `guard` | `Reflection` |
| `ent_mutante_generico_onda_de_impacto` | Onda de impacto | ATTACK | entities | `wind` | `Explosion1` |
| `ent_mutante_generico_parede_do_elemento` | Parede do elemento | ESTADO | entities | `guard` | `shield` |
| `ent_mutante_generico_rajada_elemental` | Rajada elemental | ATTACK | entities | `Special2` | `HitSP2` |
| `ent_mutante_generico_ruptura_de_terreno` | Ruptura de terreno | ATTACK | entities | `Special3` | `blow` |
| `ent_nero_chamar_o_caido` | Chamar o caído | ESTADO | entities | `Neutral1` | `hit` |
| `ent_nero_circulo_funerario` | Círculo funerário | ESTADO | entities | `guard` | `Protection` |
| `ent_nero_escudo_de_ossos` | Escudo de ossos | ESTADO | entities | `buff` | `Shield` |
| `ent_nero_foice_de_sangue` | Foice de sangue | ATTACK | entities | `ice` | `ClawSP1` |
| `ent_nero_golpe_ritual` | Golpe ritual | ATTACK | entities | `fire` | `CrossHit` |
| `ent_nero_inferi_temporario` | Inferi temporário | ESTADO | entities | `summon` | `Light2` |
| `ent_nero_marcha_dos_inferi` | Marcha dos inferi | ATTACK | entities | `lightning` | `slash` |
| `ent_nero_portao_do_necroterio` | Portão do necrotério | ATTACK | entities | `cast` | `status` |
| `ent_nero_toque_no_equilibrio` | Toque no equilíbrio | ESTADO | entities | `Special1` | `debuff` |
| `ent_nero_vinculo_de_sangue` | Vínculo de sangue | ESTADO | entities | `light` | `claw` |
| `ent_niu_valdtagen_alerta_silencioso` | Alerta silencioso | ESTADO | entities | `Neutral1` | `stun` |
| `ent_niu_valdtagen_coincidencia_impossivel` | Coincidência impossível | ATTACK | entities | `Neutral2` | `StarsHit` |
| `ent_niu_valdtagen_encontrar_saida` | Encontrar saída | ESTADO | entities | `buff` | `bind` |
| `ent_niu_valdtagen_esquiva_involuntaria` | Esquiva involuntária | ESTADO | entities | `Special1` | `slow` |
| `ent_niu_valdtagen_passo_de_fuga` | Passo de fuga | ATTACK | entities | `Special2` | `push` |
| `ent_niu_valdtagen_pedra_atirada` | Pedra atirada | ATTACK | entities | `Special3` | `HitSP1` |
| `ent_niu_valdtagen_plano_improvisado` | Plano improvisado | ESTADO | entities | `guard` | `Reflection` |
| `ent_niu_valdtagen_residuo_planar` | Resíduo planar | ATTACK | entities | `fire` | `HitSP2` |
| `ent_niu_valdtagen_sorte_absurda` | Sorte absurda | ESTADO | entities | `cast` | `hit` |
| `ent_niu_valdtagen_sumir_no_corredor` | Sumir no corredor | ESTADO | entities | `Neutral1` | `status` |
| `ent_pesadelo_vivo_desaparecer` | Desaparecer | ESTADO | entities | `Neutral2` | `debuff` |
| `ent_pesadelo_vivo_eco_mental` | Eco mental | ATTACK | entities | `summon` | `blow` |
| `ent_pesadelo_vivo_estilhacar_realidade` | Estilhaçar realidade | ATTACK | entities | `lightning` | `CrossHit` |
| `ent_pesadelo_vivo_frenesi_subito` | Frenesi súbito | ATTACK | entities | `Special2` | `slash` |
| `ent_pesadelo_vivo_imagem_do_trauma` | Imagem do trauma | ESTADO | entities | `buff` | `stun` |
| `ent_pesadelo_vivo_medo_personalizado` | Medo personalizado | ESTADO | entities | `Special1` | `StarsHit` |
| `ent_pesadelo_vivo_pesadelo_sem_fim` | Pesadelo sem fim | ATTACK | entities | `Special3` | `bind` |
| `ent_pesadelo_vivo_reino_quebrado` | Reino quebrado | ATTACK | entities | `darkness` | `slow` |
| `ent_pesadelo_vivo_sombra_desperta` | Sombra desperta | ESTADO | entities | `BreathDarkness` | `Darkness1` |
| `ent_pesadelo_vivo_sombra_encarnada` | Sombra encarnada | ATTACK | entities | `Smokescreen` | `HitSP1` |
| `ent_pietro_caos_arrebentar_a_linha` | Arrebentar a linha | ATTACK | entities | `fire` | `Explosion1` |
| `ent_pietro_caos_aura_apocaliptica` | Aura apocalíptica | ESTADO | entities | `cast` | `status` |
| `ent_pietro_caos_caos_completo` | Caos completo | ATTACK | entities | `lightning` | `HitSP2` |
| `ent_pietro_caos_corrente_de_buer` | Corrente de Buer | ATTACK | entities | `Neutral2` | `pull` |
| `ent_pietro_caos_fome_de_medo` | Fome de medo | ATTACK | entities | `Special2` | `absorb` |
| `ent_pietro_caos_garras_de_ceifador` | Garras de ceifador | ATTACK | entities | `Special3` | `ClawSP2` |
| `ent_pietro_caos_recompor_carne` | Recompor carne | ESTADO | entities | `summon` | `heal` |
| `ent_pietro_caos_regeneracao_selvagem` | Regeneração selvagem | ESTADO | entities | `BreathLight` | `Light1` |
| `ent_pietro_caos_riso_do_caos` | Riso do caos | ESTADO | entities | `Song1` | `debuff` |
| `ent_pietro_caos_sabotar_sistema` | Sabotar sistema | ESTADO | entities | `Neutral1` | `stun` |
| `ent_quasar_assalto_de_vanguarda` | Assalto de vanguarda | ATTACK | entities | `buff` | `shield` |
| `ent_quasar_contra_de_combate` | Contra de combate | ESTADO | entities | `Special1` | `StarsHit` |
| `ent_quasar_golpe_de_abertura` | Golpe de abertura | ATTACK | entities | `fire` | `blow` |
| `ent_quasar_impacto_de_quasar` | Impacto de Quasar | ATTACK | entities | `lightning` | `push` |
| `ent_quasar_jab_divino` | Jab divino | ATTACK | entities | `cast` | `CrossHit` |
| `ent_quasar_percepcao_relampago` | Percepção relâmpago | ESTADO | entities | `thunder` | `Thunder1` |
| `ent_quasar_recuperacao_acelerada` | Recuperação acelerada | ESTADO | entities | `light` | `Light3` |
| `ent_quasar_riso_provocador` | Riso provocador | ESTADO | entities | `Song1` | `bind` |
| `ent_quasar_sequencia_desarmada` | Sequência desarmada | ATTACK | entities | `Neutral2` | `slash` |
| `ent_quasar_uppercut` | Uppercut | ATTACK | entities | `Special2` | `Explosion1` |
| `ent_taylor_asas_projetadas` | Asas projetadas | ESTADO | entities | `Neutral1` | `slow` |
| `ent_taylor_comando_remoto` | Comando remoto | ATTACK | entities | `Special3` | `hit` |
| `ent_taylor_desvio_de_mente` | Desvio de mente | ESTADO | entities | `guard` | `confusion` |
| `ent_taylor_fio_de_marionete` | Fio de marionete | ESTADO | entities | `Song1` | `confusion` |
| `ent_taylor_fortaleza_de_zaphter` | Fortaleza de Zaphter | ESTADO | entities | `guard` | `Protection` |
| `ent_taylor_lamina_psiquica` | Lâmina psíquica | ATTACK | entities | `fire` | `SlashSP3` |
| `ent_taylor_lanca_mental` | Lança mental | ATTACK | entities | `lightning` | `HitSP1` |
| `ent_taylor_mapa_tatico` | Mapa tático | ESTADO | entities | `buff` | `status` |
| `ent_taylor_nave_mae` | Nave-Mãe | ESTADO | entities | `guard` | `Shield` |
| `ent_taylor_voo_de_cobertura` | Voo de cobertura | ATTACK | entities | `cast` | `shield` |
| `ent_techna_armadilha_de_campo` | Armadilha de campo | ATTACK | entities | `Neutral2` | `HitSP2` |
| `ent_techna_armadura_de_bloqueio` | Armadura de bloqueio | ESTADO | entities | `buff` | `Reflection` |
| `ent_techna_cacada_inteligente` | Caçada inteligente | ATTACK | entities | `Special2` | `blow` |
| `ent_techna_choque_incapacitante` | Choque incapacitante | ATTACK | entities | `Special3` | `CrossHit` |
| `ent_techna_kit_de_captura` | Kit de captura | ESTADO | entities | `guard` | `Protection` |
| `ent_techna_laco_de_contencao` | Laço de contenção | ESTADO | entities | `Special1` | `bind` |
| `ent_techna_placas_modulares` | Placas modulares | ESTADO | entities | `guard` | `Shield` |
| `ent_techna_protocolo_nocaute` | Protocolo Nocaute | ATTACK | entities | `fire` | `slash` |
| `ent_techna_sabotar_arma` | Sabotar arma | ATTACK | entities | `lightning` | `hit` |
| `ent_techna_varredura_de_alvos` | Varredura de alvos | ESTADO | entities | `Neutral1` | `debuff` |
| `ms_blade_daywalker` | Daywalker | ATTACK | external | `cast` | `HitSP1` |
| `ms_blade_glaive` | Glaive | ATTACK | external | `Neutral2` | `stun` |
| `ms_blade_make_em_bleed` | Make 'em Bleed | ESTADO | external | `Special1` | `ClawSP1` |
| `ms_blade_quick_strike` | Quick Strike | ATTACK | external | `Special2` | `HitSP2` |
| `ms_blade_reaper` | Reaper | ATTACK | external | `Special3` | `blow` |
| `ms_blade_relentless` | Relentless | ATTACK | external | `fire` | `CrossHit` |
| `ms_blade_savage` | Savage | ATTACK | external | `lightning` | `slash` |
| `ms_blade_stake` | Stake | ATTACK | external | `cast` | `bleed` |
| `ms_blade_strike` | Strike | ATTACK | external | `Neutral2` | `hit` |
| `ms_blade_the_hunger` | The Hunger | ESTADO | external | `Neutral1` | `StarsHit` |
| `ms_captain_america_brooklyn_handshake` | Brooklyn Handshake | ATTACK | external | `Special2` | `push` |
| `ms_captain_america_dig_in` | Dig In | ESTADO | external | `buff` | `Reflection` |
| `ms_captain_america_punch` | Punch | ATTACK | external | `guard` | `Explosion1` |
| `ms_captain_america_quick_punch` | Quick Punch | ATTACK | external | `guard` | `HitSP1` |
| `ms_captain_america_shield_bash` | Shield Bash | ATTACK | external | `buff` | `shield` |
| `ms_captain_america_shield_bounce` | Shield Bounce | ATTACK | external | `buff` | `Protection` |
| `ms_captain_america_shield_charge` | Shield Charge | ATTACK | external | `buff` | `Shield` |
| `ms_captain_america_sprang` | SPRANG! | ATTACK | external | `Special3` | `HitSP2` |
| `ms_captain_america_tactician` | Tactician | ESTADO | external | `Special1` | `Reflection` |
| `ms_captain_america_the_best_defense` | The Best Defense | ESTADO | external | `Neutral1` | `slow` |
| `ms_captain_marvel_bring_it_on` | Bring it On | ESTADO | external | `guard` | `status` |
| `ms_captain_marvel_cosmic_ray` | Cosmic Ray | ATTACK | external | `fire` | `blow` |
| `ms_captain_marvel_fists_of_radiance` | Fists of Radiance | ATTACK | external | `lightning` | `push` |
| `ms_captain_marvel_go_binary` | Go Binary | ESTADO | external | `guard` | `shield` |
| `ms_captain_marvel_jab` | Jab | ATTACK | external | `cast` | `CrossHit` |
| `ms_captain_marvel_knee_strike` | Knee Strike | ATTACK | external | `guard` | `slash` |
| `ms_captain_marvel_one_step_ahead` | One Step Ahead | ESTADO | external | `Special1` | `debuff` |
| `ms_captain_marvel_photon_beam` | Photon Beam | ATTACK | external | `guard` | `hit` |
| `ms_captain_marvel_quick_jab` | Quick Jab | ATTACK | external | `guard` | `HitSP1` |
| `ms_captain_marvel_rain_of_blows` | Rain of Blows | ATTACK | external | `Neutral2` | `HitSP2` |
| `ms_captain_marvel_regroup` | Regroup | ESTADO | external | `light` | `Light4` |
| `ms_captain_marvel_supernova` | Supernova | ATTACK | external | `Special2` | `blow` |
| `ms_deadpool_all_together_now` | All Together Now | ESTADO | external | `Neutral1` | `stun` |
| `ms_deadpool_boom_headshot` | Boom, Headshot | ATTACK | external | `Special3` | `PierceSP2` |
| `ms_deadpool_burning_sensation` | Burning Sensation | ATTACK | external | `BreathFire` | `Fire1` |
| `ms_deadpool_death_from_above` | Death From Above | ATTACK | external | `fire` | `CrossHit` |
| `ms_deadpool_hey_face` | Hey #^*face! | ESTADO | external | `guard` | `StarsHit` |
| `ms_deadpool_mag_dump` | Mag Dump | ATTACK | external | `lightning` | `slash` |
| `ms_deadpool_overpowered` | Overpowered | ATTACK | external | `cast` | `Explosion1` |
| `ms_deadpool_pain_pinata` | Pain Piñata | ATTACK | external | `Neutral2` | `hit` |
| `ms_deadpool_quick_shot` | Quick Shot | ATTACK | external | `Special2` | `arrow` |
| `ms_deadpool_spread_the_love` | Spread the Love | ATTACK | external | `Special3` | `HitSP1` |
| `ms_doctor_strange_agamotto_s_gaze` | Agamotto's Gaze | ESTADO | external | `Special1` | `bind` |
| `ms_doctor_strange_astral_meditation` | Astral Meditation | ESTADO | external | `Neutral1` | `slow` |
| `ms_doctor_strange_axe_of_angarruumus` | Axe of Angarruumus | ATTACK | external | `fire` | `status` |
| `ms_doctor_strange_blessing_of_vishanti` | Blessing of Vishanti | ESTADO | external | `HeartMark1` | `debuff` |
| `ms_doctor_strange_bolt_of_balthakk` | Bolt of Balthakk | ATTACK | external | `lightning` | `HitSP2` |
| `ms_doctor_strange_crimson_bands_of_cyttorak` | Crimson Bands of Cyttorak | ESTADO | external | `Special1` | `stun` |
| `ms_doctor_strange_seven_suns_of_cinnibus` | Seven Suns of Cinnibus | ATTACK | external | `cast` | `blow` |
| `ms_doctor_strange_shield_of_seraphim` | Shield of Seraphim | ESTADO | external | `buff` | `Protection` |
| `ms_doctor_strange_vapors_of_valtorr` | Vapors of Valtorr | ESTADO | external | `Neutral1` | `StarsHit` |
| `ms_doctor_strange_winds_of_watoomb` | Winds of Watoomb | ATTACK | external | `wind` | `Wind1` |
| `ms_ghost_rider_drain_soul` | Drain Soul | ATTACK | external | `Neutral2` | `absorb` |
| `ms_ghost_rider_hell_s_fury` | Hell's Fury | ATTACK | external | `wind` | `CrossHit` |
| `ms_ghost_rider_hellmouth` | Hellmouth | ESTADO | external | `Special1` | `bind` |
| `ms_ghost_rider_hellride` | Hellride | ATTACK | external | `Special2` | `slash` |
| `ms_ghost_rider_immolate` | Immolate | ESTADO | external | `cast` | `slow` |
| `ms_ghost_rider_judgment` | Judgment | ATTACK | external | `Special3` | `hit` |
| `ms_ghost_rider_lash` | Lash | ATTACK | external | `fire` | `push` |
| `ms_ghost_rider_penance_stare` | Penance Stare | ATTACK | external | `lightning` | `HitSP1` |
| `ms_ghost_rider_retribution` | Retribution | ATTACK | external | `Neutral2` | `HitSP2` |
| `ms_ghost_rider_straight_to_hell` | Straight to Hell | ESTADO | external | `Neutral1` | `status` |
| `ms_hulk_always_angry` | Always Angry | ESTADO | external | `buff` | `debuff` |
| `ms_hulk_challenging_roar` | Challenging Roar | ESTADO | external | `Special1` | `stun` |
| `ms_hulk_crush` | Crush | ATTACK | external | `Special2` | `StarsHit` |
| `ms_hulk_gamma_kick` | Gamma Kick | ATTACK | external | `guard` | `Explosion1` |
| `ms_hulk_mighty_blow` | Mighty Blow | ATTACK | external | `Special3` | `push` |
| `ms_hulk_rampage` | Rampage | ATTACK | external | `guard` | `blow` |
| `ms_hulk_seismic_slam` | Seismic Slam | ATTACK | external | `guard` | `CrossHit` |
| `ms_hulk_smash` | Smash | ATTACK | external | `fire` | `bind` |
| `ms_hulk_thunderclap` | Thunderclap | ATTACK | external | `BreathThunder` | `Thunder2` |
| `ms_hulk_worldbreaker` | Worldbreaker | ATTACK | external | `lightning` | `Explosion1` |
| `ms_hunter_all_out` | All Out | ATTACK | external | `cast` | `slash` |
| `ms_hunter_annihilation` | Annihilation | ATTACK | external | `Neutral2` | `hit` |
| `ms_hunter_bands_of_fire` | Bands of Fire | ATTACK | external | `BreathFire` | `Fire2` |
| `ms_hunter_bladestorm` | Bladestorm | ATTACK | external | `Special2` | `push` |
| `ms_hunter_call_to_arms` | Call To Arms | ESTADO | external | `Neutral1` | `slow` |
| `ms_hunter_charge` | Charge | ATTACK | external | `Special3` | `Explosion1` |
| `ms_hunter_dark_blessing` | Dark Blessing | ESTADO | external | `BreathLight` | `Darkness2` |
| `ms_hunter_dark_heal` | Dark Heal | ESTADO | external | `HeartMark1` | `Darkness1` |
| `ms_hunter_deadly_ground` | Deadly Ground | ESTADO | external | `buff` | `status` |
| `ms_hunter_fortify` | Fortify | ESTADO | external | `guard` | `Shield` |
| `ms_hunter_fury` | Fury | ATTACK | external | `wind` | `debuff` |
| `ms_hunter_guarding_strike` | Guarding Strike | ATTACK | external | `buff` | `HitSP1` |
| `ms_hunter_heal` | Heal | ESTADO | external | `BreathLight` | `heal` |
| `ms_hunter_holy_burst` | Holy Burst | ATTACK | external | `HeartMark1` | `Light1` |
| `ms_hunter_holy_flame` | Holy Flame | ATTACK | external | `BreathFire` | `Fire1` |
| `ms_hunter_holy_gift` | Holy Gift | ESTADO | external | `BreathLight` | `stun` |
| `ms_hunter_holy_spark` | Holy Spark | ATTACK | external | `thunder` | `Thunder3` |
| `ms_hunter_inspire` | Inspire | ESTADO | external | `Special1` | `StarsHit` |
| `ms_hunter_last_sight` | Last Sight | ATTACK | external | `fire` | `HitSP2` |
| `ms_hunter_merciless` | Merciless | ATTACK | external | `lightning` | `bind` |
| `ms_hunter_mindbender` | Mindbender | ESTADO | external | `cast` | `slow` |
| `ms_hunter_mindbreaker` | Mindbreaker | ESTADO | external | `Neutral1` | `status` |
| `ms_hunter_morning_star` | Morning Star | ATTACK | external | `Neutral2` | `blow` |
| `ms_hunter_patience` | Patience | ATTACK | external | `Special2` | `CrossHit` |
| `ms_hunter_quick_slash` | Quick Slash | ATTACK | external | `Special3` | `CrossSlash` |
| `ms_hunter_slash` | Slash | ATTACK | external | `fire` | `SlashSP1` |
| `ms_hunter_summon_charlie` | Summon Charlie | ESTADO | external | `summon` | `Light2` |
| `ms_hunter_whip` | Whip | ATTACK | external | `lightning` | `push` |
| `ms_hunter_wild_strike` | Wild Strike | ATTACK | external | `cast` | `debuff` |
| `ms_hunter_wrath` | Wrath | ESTADO | external | `Special1` | `stun` |
| `ms_iron_man_air_superiority` | Air Superiority | ATTACK | external | `Neutral2` | `slash` |
| `ms_iron_man_blast` | Blast | ATTACK | external | `Special2` | `explosion` |
| `ms_iron_man_heads_up` | Heads Up | ESTADO | external | `guard` | `Reflection` |
| `ms_iron_man_hellfire_beam` | Hellfire Beam | ATTACK | external | `BreathFire` | `Fire2` |
| `ms_iron_man_leave_it_to_me` | Leave it To Me | ESTADO | external | `Neutral1` | `StarsHit` |
| `ms_iron_man_mark_target` | Mark Target | ESTADO | external | `buff` | `bind` |
| `ms_iron_man_new_plan` | New Plan | ESTADO | external | `Special1` | `slow` |
| `ms_iron_man_precision` | Precision | ESTADO | external | `cast` | `status` |
| `ms_iron_man_quick_blast` | Quick Blast | ATTACK | external | `Special3` | `Explosion2` |
| `ms_iron_man_surgical_strike` | Surgical Strike | ATTACK | external | `fire` | `hit` |
| `ms_magik_banish` | Banish | ESTADO | external | `Neutral1` | `debuff` |
| `ms_magik_darkchylde` | Darkchylde | ESTADO | external | `darkness` | `Darkness2` |
| `ms_magik_gather` | Gather | ATTACK | external | `lightning` | `pull` |
| `ms_magik_kick` | Kick | ATTACK | external | `Neutral2` | `Explosion1` |
| `ms_magik_limbo_portal` | Limbo Portal | ESTADO | external | `summon` | `stun` |
| `ms_magik_limbo_s_grasp` | Limbo's Grasp | ESTADO | external | `buff` | `StarsHit` |
| `ms_magik_quick_soulslash` | Quick Soulslash | ATTACK | external | `Special2` | `SlashSP2` |
| `ms_magik_reinforcement` | Reinforcement | ESTADO | external | `summon` | `Light2` |
| `ms_magik_soul_blast` | Soul Blast | ATTACK | external | `Special3` | `explosion` |
| `ms_magik_trap_door` | Trap Door | ESTADO | external | `Special1` | `bind` |
| `ms_morbius_bloodlust` | Bloodlust | ESTADO | external | `guard` | `claw` |
| `ms_morbius_charm` | Charm | ESTADO | external | `cast` | `slow` |
| `ms_morbius_claw` | Claw | ATTACK | external | `fire` | `CrossClaw` |
| `ms_morbius_cornered` | Cornered | ESTADO | external | `Neutral1` | `status` |
| `ms_morbius_echolocate` | Echolocate | ATTACK | external | `lightning` | `HitSP1` |
| `ms_morbius_feeding_frenzy` | Feeding Frenzy | ATTACK | external | `Neutral2` | `bleed` |
| `ms_morbius_mist_form` | Mist Form | ESTADO | external | `buff` | `debuff` |
| `ms_morbius_quick_claw` | Quick Claw | ATTACK | external | `Special2` | `ClawSP2` |
| `ms_morbius_savage_swipe` | Savage Swipe | ATTACK | external | `Special3` | `push` |
| `ms_morbius_shadow_strike` | Shadow Strike | ATTACK | external | `BreathDarkness` | `HitSP2` |
| `ms_morbius_undying_fury` | Undying Fury | ATTACK | external | `wind` | `blow` |
| `ms_nico_blood_for_blood` | Blood for Blood | ATTACK | external | `fire` | `CrossHit` |
| `ms_nico_blood_magic` | Blood Magic | ESTADO | external | `Special1` | `ClawSP1` |
| `ms_nico_crack_the_sky` | Crack the Sky | ATTACK | external | `lightning` | `slash` |
| `ms_nico_curse` | Curse | ATTACK | external | `cast` | `hit` |
| `ms_nico_double_up` | Double Up | ESTADO | external | `Neutral1` | `stun` |
| `ms_nico_empower` | Empower | ESTADO | external | `Neutral2` | `StarsHit` |
| `ms_nico_restore` | Restore | ESTADO | external | `light` | `Light3` |
| `ms_nico_swarm` | Swarm | ATTACK | external | `Special2` | `HitSP1` |
| `ms_nico_witchfire` | Witchfire | ATTACK | external | `BreathFire` | `Fire1` |
| `ms_nico_witchstorm` | Witchstorm | ATTACK | external | `Special3` | `HitSP2` |
| `ms_scarlet_witch_chaos_field` | Chaos Field | ESTADO | external | `buff` | `confusion` |
| `ms_scarlet_witch_chaos_reigns` | Chaos Reigns | ESTADO | external | `Special1` | `confusion` |
| `ms_scarlet_witch_detonate` | Detonate | ESTADO | external | `cast` | `Explosion2` |
| `ms_scarlet_witch_hex_bolt` | Hex Bolt | ATTACK | external | `fire` | `blow` |
| `ms_scarlet_witch_hex_charge` | Hex Charge | ESTADO | external | `Neutral1` | `bind` |
| `ms_scarlet_witch_hex_field` | Hex Field | ATTACK | external | `lightning` | `CrossHit` |
| `ms_scarlet_witch_hex_mark` | Hex Mark | ESTADO | external | `Neutral2` | `slow` |
| `ms_scarlet_witch_no_more` | No More | ATTACK | external | `Special2` | `slash` |
| `ms_scarlet_witch_quick_toss` | Quick Toss | ATTACK | external | `Special3` | `Explosion1` |
| `ms_scarlet_witch_unleashed` | Unleashed | ESTADO | external | `buff` | `status` |
| `ms_spider_man_chain_strike` | Chain Strike | ATTACK | external | `fire` | `hit` |
| `ms_spider_man_infernal_spider` | Infernal Spider | ESTADO | external | `Special1` | `debuff` |
| `ms_spider_man_opportunist` | Opportunist | ESTADO | external | `cast` | `stun` |
| `ms_spider_man_quick_kick` | Quick Kick | ATTACK | external | `lightning` | `push` |
| `ms_spider_man_special_delivery` | Special Delivery | ATTACK | external | `Neutral2` | `pull` |
| `ms_spider_man_spider_sense` | Spider-Sense | ESTADO | external | `Neutral1` | `StarsHit` |
| `ms_spider_man_thwip` | THWIP! | ESTADO | external | `buff` | `bind` |
| `ms_spider_man_up_here` | Up Here! | ATTACK | external | `Special2` | `slow` |
| `ms_spider_man_web_throw` | Web Throw | ATTACK | external | `Special3` | `Explosion1` |
| `ms_spider_man_webslinger` | Webslinger | ESTADO | external | `Special1` | `status` |
| `ms_storm_arc` | Arc | ATTACK | external | `fire` | `HitSP1` |
| `ms_storm_call_the_lightning` | Call the Lightning | ATTACK | external | `BreathThunder` | `Thunder1` |
| `ms_storm_crushing_blow` | Crushing Blow | ATTACK | external | `lightning` | `HitSP2` |
| `ms_storm_gale_force` | Gale Force | ATTACK | external | `cast` | `push` |
| `ms_storm_goddess_blessing` | Goddess' Blessing | ESTADO | external | `HeartMark1` | `debuff` |
| `ms_storm_hellstorm` | Hellstorm | ATTACK | external | `Neutral2` | `blow` |
| `ms_storm_live_wire` | Live Wire | ATTACK | external | `Special2` | `CrossHit` |
| `ms_storm_overload` | Overload | ESTADO | external | `Neutral1` | `stun` |
| `ms_storm_stormshield` | Stormshield | ESTADO | external | `buff` | `shield` |
| `ms_storm_vortex` | Vortex | ATTACK | external | `Special3` | `Explosion1` |
| `ms_venom_assimilation` | Assimilation | ESTADO | external | `Special1` | `StarsHit` |
| `ms_venom_devouring_strike` | Devouring Strike | ATTACK | external | `fire` | `slash` |
| `ms_venom_insatiable_hunger` | Insatiable Hunger | ESTADO | external | `cast` | `bind` |
| `ms_venom_lethal_embrace` | Lethal Embrace | ATTACK | external | `lightning` | `hit` |
| `ms_venom_spike_burst` | Spike Burst | ATTACK | external | `Neutral2` | `HitSP1` |
| `ms_venom_symbiote_bind` | Symbiote Bind | ESTADO | external | `Neutral1` | `slow` |
| `ms_venom_symbiotic_senses` | Symbiotic Senses | ESTADO | external | `buff` | `status` |
| `ms_venom_tasty_brains` | Tasty Brains | ATTACK | external | `Special2` | `absorb` |
| `ms_venom_tendril_strike` | Tendril Strike | ATTACK | external | `Special3` | `HitSP2` |
| `ms_venom_web_toss` | Web Toss | ATTACK | external | `fire` | `push` |
| `ms_wolverine_berserk` | Berserk | ESTADO | external | `Special1` | `debuff` |
| `ms_wolverine_chain_swipes` | Chain Swipes | ATTACK | external | `guard` | `blow` |
| `ms_wolverine_eviscerate` | Eviscerate | ATTACK | external | `guard` | `CrossHit` |
| `ms_wolverine_lethal_pounce` | Lethal Pounce | ATTACK | external | `lightning` | `slash` |
| `ms_wolverine_midnight_special` | Midnight Special | ATTACK | external | `cast` | `hit` |
| `ms_wolverine_piercing_slash` | Piercing Slash | ATTACK | external | `Neutral2` | `SlashSP3` |
| `ms_wolverine_power_slash` | Power Slash | ATTACK | external | `Special2` | `CrossSlash` |
| `ms_wolverine_quick_swipe` | Quick Swipe | ATTACK | external | `guard` | `HitSP1` |
| `ms_wolverine_rapid_healing` | Rapid Healing | ESTADO | external | `BreathLight` | `Light4` |
| `ms_wolverine_rapid_regeneration` | Rapid Regeneration | ESTADO | external | `HeartMark1` | `heal` |
| `ms_wolverine_stink_of_fear` | Stink of Fear | ESTADO | external | `guard` | `stun` |
