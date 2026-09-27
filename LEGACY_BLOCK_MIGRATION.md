# Inventário legado: block / shield / Proteção / Barreira

Lista gerada para revisão humana. **Nenhuma migração automática** foi aplicada ao conteúdo.

## Modelo alvo (resumo)

| Efeito | Uso sugerido |
|---|---|
| **Proteção X** | Ignora os próximos X ataques (cada hit de Chain conta) |
| **Barreira X Y** | Dura X rodadas; pool de HP Y; overflow na Vida |
| **Resistente X** | +2 Armadura e +2 Escudo por stack (máx 5) |
| block / shield (legado) | Ainda absorvem após Barreira; manter só onde há sinergia (`hit_from_block`, Cap, etc.) |

**Penetrante** (código): ignora Proteção e Barreira por completo; ignora block/shield; ½ Armadura/Escudo.

Total de cartas listadas: **94**.

## Cartas

| id | nome | efeito atual | sugestão de migração | fonte |
|---|---|---|---|---|
| `abrigo` | Abrigo sagrado | `block(5); status(protecao, 1, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `game/Content.gd` |
| `barreira` | Barreira arcana | `status(barrier, 2, 9); status(barrier, 1, 3)` | Já em Barreira (modelo novo) — ok. | `game/Content.gd` |
| `contra` | Resposta de aço | `block(6)` | BLOCK 6 → **Barreira** 1–2 rodadas, HP 6. | `game/Content.gd` |
| `eco` | Eco arcano | `shield(6)` | SHIELD 6 → **Barreira** 1–2 rodadas, HP 6 (ou Resistente 1–2 se for buff de defesa passiva). | `game/Content.gd` |
| `egide` | Égide | `block(8)` | BLOCK 8 → **Barreira** 1–2 rodadas, HP 8. | `game/Content.gd` |
| `ent_adam_abrigo_rapido` | Abrigo rápido | `block(3)` | BLOCK 3 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/3. | `addons/hotn3_entities/entities.json` |
| `ent_adam_cobertura_improvisada` | Cobertura improvisada | `block(5)` | BLOCK 5 → **Barreira** 1–2 rodadas, HP 5. | `addons/hotn3_entities/entities.json` |
| `ent_adam_nao_vou_deixar` | Não vou deixar | `block(8)` | BLOCK 8 → **Barreira** 1–2 rodadas, HP 8. | `addons/hotn3_entities/entities.json` |
| `ent_adam_rota_de_fuga` | Rota de fuga | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_akuji_escamas_da_fornalha` | Escamas da fornalha | `block(9)` | BLOCK 9 → **Barreira** 1–2 rodadas, HP 9. | `addons/hotn3_entities/entities.json` |
| `ent_alexis_alerta_aos_gritos` | Alerta aos gritos | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_alexis_colecao_improvavel` | Coleção improvável | `block(4)` | BLOCK 4 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/4. | `addons/hotn3_entities/entities.json` |
| `ent_alexis_proteger_um_amigo` | Proteger um amigo | `block(7); status(protecao, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `addons/hotn3_entities/entities.json` |
| `ent_alistair_armadura_instantanea` | Armadura instantânea | `block(12)` | BLOCK 12 → **Barreira** 2 rodadas, HP 12 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `addons/hotn3_entities/entities.json` |
| `ent_alistair_liga_ouro_aco` | Liga ouro-aço | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_alistair_muralha_luminosa` | Muralha luminosa | `block(13); status(protecao, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `addons/hotn3_entities/entities.json` |
| `ent_alistair_tempo_de_reacao` | Tempo de reação | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_alyssa_wine_despertar_anomalo` | Despertar anômalo | `block(6)` | BLOCK 6 → **Barreira** 1–2 rodadas, HP 6. | `addons/hotn3_entities/entities.json` |
| `ent_alyssa_wine_liga_viva` | Liga viva | `block_hp(0.3)` | Migrar `block_hp` → **Barreira** com HP = % da Vida máx. (mesma duração curta, 1–2 rodadas). | `addons/hotn3_entities/entities.json` |
| `ent_alyssa_wine_serpente_em_guarda` | Serpente em guarda | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_ashlee_compartilhar_equipamento` | Compartilhar equipamento | `block(5)` | BLOCK 5 → **Barreira** 1–2 rodadas, HP 5. | `addons/hotn3_entities/entities.json` |
| `ent_daeva_aviso_por_radio` | Aviso por rádio | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_daeva_lealdade_teimosa` | Lealdade teimosa | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_daeva_saida_calculada` | Saída calculada | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_daeva_todos_para_fora` | Todos para fora | `block(8); status(protecao, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `addons/hotn3_entities/entities.json` |
| `ent_damian_alrosa_pocao_negociada` | Poção negociada | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_damian_alrosa_recurso_reservado` | Recurso reservado | `block(4)` | BLOCK 4 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/4. | `addons/hotn3_entities/entities.json` |
| `ent_dominika_seur_absorver_impacto` | Absorver impacto | `block_hp(0.5)` | Migrar `block_hp` → **Barreira** com HP = % da Vida máx. (mesma duração curta, 1–2 rodadas). | `addons/hotn3_entities/entities.json` |
| `ent_dominika_seur_campo_de_massa` | Campo de massa | `block(5)` | BLOCK 5 → **Barreira** 1–2 rodadas, HP 5. | `addons/hotn3_entities/entities.json` |
| `ent_dominika_seur_corpo_acolchoado` | Corpo acolchoado | `block_hp(0.35)` | Migrar `block_hp` → **Barreira** com HP = % da Vida máx. (mesma duração curta, 1–2 rodadas). | `addons/hotn3_entities/entities.json` |
| `ent_dominika_seur_pressao_inabalavel` | Pressão inabalável | `self_status(protecao, 2)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_dylan_avisar_o_perigo` | Avisar o perigo | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_dylan_ficar_junto` | Ficar junto | `block(6)` | BLOCK 6 → **Barreira** 1–2 rodadas, HP 6. | `addons/hotn3_entities/entities.json` |
| `ent_dylan_guardar_a_porta` | Guardar a porta | `block(5)` | BLOCK 5 → **Barreira** 1–2 rodadas, HP 5. | `addons/hotn3_entities/entities.json` |
| `ent_dylan_nao_abandonar_ninguem` | Não abandonar ninguém | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_fate_guarda_interdimensional` | Guarda interdimensional | `block(10)` | BLOCK 10 → **Barreira** 2 rodadas, HP 10 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `addons/hotn3_entities/entities.json` |
| `ent_fate_lamina_perfurante` | Lâmina perfurante | `bonus_block(1)` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_entities/entities.json` |
| `ent_hynda_valdtagen_pocao_adaptativa` | Poção adaptativa | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_kabuki_armadura_furtiva` | Armadura furtiva | `block(4)` | BLOCK 4 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/4. | `addons/hotn3_entities/entities.json` |
| `ent_kabuki_evasao_calculada` | Evasão calculada | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_konrad_ilusao_de_cobertura` | Ilusão de cobertura | `block(5)` | BLOCK 5 → **Barreira** 1–2 rodadas, HP 5. | `addons/hotn3_entities/entities.json` |
| `ent_konrad_pele_de_escudo` | Pele de escudo | `block(9)` | BLOCK 9 → **Barreira** 1–2 rodadas, HP 9. | `addons/hotn3_entities/entities.json` |
| `ent_leona_forma_parcial` | Forma parcial | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_lust_emprestar_soma` | Emprestar Soma | `block(4)` | BLOCK 4 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/4. | `addons/hotn3_entities/entities.json` |
| `ent_lust_runa_compartilhada` | Runa compartilhada | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_lust_transferencia_runica` | Transferência rúnica | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_mingau_o_feiticeiro_gato_intangivel` | Gato intangível | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_mutante_generico_barreira_condensada` | Barreira condensada | `block(4)` | BLOCK 4 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/4. | `addons/hotn3_entities/entities.json` |
| `ent_mutante_generico_massa_elemental` | Massa elemental | `block(10)` | BLOCK 10 → **Barreira** 2 rodadas, HP 10 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `addons/hotn3_entities/entities.json` |
| `ent_mutante_generico_parede_do_elemento` | Parede do elemento | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_nero_circulo_funerario` | Círculo funerário | `block(6)` | BLOCK 6 → **Barreira** 1–2 rodadas, HP 6. | `addons/hotn3_entities/entities.json` |
| `ent_nero_escudo_de_ossos` | Escudo de ossos | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_nero_vinculo_de_sangue` | Vínculo de sangue | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_niu_valdtagen_alerta_silencioso` | Alerta silencioso | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_niu_valdtagen_esquiva_involuntaria` | Esquiva involuntária | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_niu_valdtagen_plano_improvisado` | Plano improvisado | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_quasar_percepcao_relampago` | Percepção relâmpago | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_entities/entities.json` |
| `ent_taylor_desvio_de_mente` | Desvio de mente | `block(5)` | BLOCK 5 → **Barreira** 1–2 rodadas, HP 5. | `addons/hotn3_entities/entities.json` |
| `ent_taylor_fortaleza_de_zaphter` | Fortaleza de Zaphter | `block(9); self_status(protecao, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `addons/hotn3_entities/entities.json` |
| `ent_taylor_lamina_psiquica` | Lâmina psíquica | `bonus_block(1)` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_entities/entities.json` |
| `ent_taylor_nave_mae` | Nave-Mãe | `block(13); status(protecao, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `addons/hotn3_entities/entities.json` |
| `ent_techna_armadura_de_bloqueio` | Armadura de bloqueio | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `addons/hotn3_entities/entities.json` |
| `ent_techna_kit_de_captura` | Kit de captura | `block(6); status(protecao, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `addons/hotn3_entities/entities.json` |
| `ent_techna_placas_modulares` | Placas modulares | `block(10)` | BLOCK 10 → **Barreira** 2 rodadas, HP 10 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `addons/hotn3_entities/entities.json` |
| `escudo_forte` | Muralha | `shield(6); status(barrier, 1, 1)` | Já aplica Barreira — remover block/shield duplicado ou fundir HP na Barreira existente. | `game/Content.gd` |
| `espinhos` | Pele espinhosa | `block(6)` | BLOCK 6 → **Barreira** 1–2 rodadas, HP 6. | `game/Content.gd` |
| `estandarte` | Estandarte de defesa | `block(15); status(protecao, 2, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `game/Content.gd` |
| `frenesi_aco` | Frenesi de aço | `block(9)` | BLOCK 9 → **Barreira** 1–2 rodadas, HP 9. | `game/Content.gd` |
| `guard` | Guarda | `block(7)` | BLOCK 7 → **Barreira** 1–2 rodadas, HP 7. | `game/Content.gd` |
| `guarda` | Postura de guarda | `block(10)` | BLOCK 10 → **Barreira** 2 rodadas, HP 10 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `game/Content.gd` |
| `guarda_absoluta` | Guarda absoluta | `status(protecao, 1, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `game/Content.gd` |
| `juramento` | Juramento de aço | `shield(8)` | SHIELD 8 → **Barreira** 1–2 rodadas, HP 8 (ou Resistente 1–2 se for buff de defesa passiva). | `game/Content.gd` |
| `ms_blade_savage` | Savage | `bonus_block(1)` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_america_dig_in` | Dig In | `block(12)` | BLOCK 12 → **Barreira** 2 rodadas, HP 12 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_america_shield_bash` | Shield Bash | `spend_block(0.25)` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_america_shield_charge` | Shield Charge | `hit_from_block(0); spend_all_block()` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_america_tactician` | Tactician | `block(10)` | BLOCK 10 → **Barreira** 2 rodadas, HP 10 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_marvel_go_binary` | Go Binary | `block_hp(0.5)` | Migrar `block_hp` → **Barreira** com HP = % da Vida máx. (mesma duração curta, 1–2 rodadas). | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_marvel_knee_strike` | Knee Strike | `block_from_hit()` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_marvel_rain_of_blows` | Rain of Blows | `spend_all_block()` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `ms_captain_marvel_regroup` | Regroup | `block(8)` | BLOCK 8 → **Barreira** 1–2 rodadas, HP 8. | `addons/hotn3_external_cards/cards.json` |
| `ms_doctor_strange_shield_of_seraphim` | Shield of Seraphim | `status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_external_cards/cards.json` |
| `ms_hunter_fortify` | Fortify | `block_hp(0.3)` | Migrar `block_hp` → **Barreira** com HP = % da Vida máx. (mesma duração curta, 1–2 rodadas). | `addons/hotn3_external_cards/cards.json` |
| `ms_hunter_guarding_strike` | Guarding Strike | `hand_block(0.1)` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `ms_iron_man_heads_up` | Heads Up | `block(9)` | BLOCK 9 → **Barreira** 1–2 rodadas, HP 9. | `addons/hotn3_external_cards/cards.json` |
| `ms_morbius_bloodlust` | Bloodlust | `block_hp(0.25)` | Migrar `block_hp` → **Barreira** com HP = % da Vida máx. (mesma duração curta, 1–2 rodadas). | `addons/hotn3_external_cards/cards.json` |
| `ms_morbius_cornered` | Cornered | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_external_cards/cards.json` |
| `ms_spider_man_spider_sense` | Spider-Sense | `self_status(protecao, 1)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_external_cards/cards.json` |
| `ms_storm_stormshield` | Stormshield | `status(protecao, 2)` | Já em Proteção — sem migração de block. Revisar só se stacks/duração estiverem desalinhados. | `addons/hotn3_external_cards/cards.json` |
| `ms_wolverine_piercing_slash` | Piercing Slash | `bonus_block(1)` | MANTER block legado por enquanto (sinergia hit_from_block / spend_block / Cap). Depois: redesenhar kit em torno de Barreira (pool) + Resistente, ou 'gasta Barreira' equivalente. | `addons/hotn3_external_cards/cards.json` |
| `muralha_viva` | Muralha viva | `block(12)` | BLOCK 12 → **Barreira** 2 rodadas, HP 12 (tanque). Alternativa: Barreira menor + **Resistente 1**. | `game/Content.gd` |
| `pele_rigida` | Pele selada | `block(10); status(protecao, 1, 1)` | Já tem Proteção — converter block/shield numérico em **Barreira** (ex.: 1–2 rodadas, HP ≈ valor do block) e manter Proteção X. | `game/Content.gd` |
| `preparo` | Reunir forças | `block(4)` | BLOCK 4 → **Proteção 1** (sabor 'esquiva/abrigo breve') *ou* Barreira 1/4. | `game/Content.gd` |
| `prisma` | Prisma de defesa | `shield(5)` | SHIELD 5 → preferir **Proteção 1** (ignora 1 golpe) *ou* Barreira 1 rodada / HP 5. | `game/Content.gd` |

## Notas

- Kits Cap (`hit_from_block` / `spend_block` / `spend_all_block`) devem ser decididos em conjunto — migrar block puro sem redesign quebra o combo.
- `block_hp` (% Vida) mapeia bem para Barreira com HP calculado na aplicação.
- Cartas que já usam `protecao` / `barrier` podem só limpar o block residual.
- Após a decisão do usuário, migrar conteúdo em lote (editor + merge) e ajustar smokes.

