extends RefCounted
class_name HotNContent

const RULES := {
	"team_size": 3, "deck_size": 8, "manobras_iniciais": 5, "copy_limit": 2, "hand_max": 10,
	"opening_hand": 5, "turn_draw": 2, "card_plays": 3,
	"redraws": 2, "moves": 1, "item_uses": 1,
	"impulse_max": 10, "items_max": 3,
	# Arquétipo intransitivo Armadura>Impacto>Escudo>Poder>Armadura (±25%). OFF por padrão.
	"archetype_matchup": false,
}

const TYPES := {
	"BRUTO": {"MENTAL": 1.25, "PROJETIVO": 0.75},
	"TECNICO": {"PSICOLOGICO": 1.25, "QUIMICO": 0.75},
	"PSICOLOGICO": {"QUIMICO": 1.25, "BRUTO": 0.75},
	"MENTAL": {"PROJETIVO": 1.25, "TECNICO": 0.75},
	"PROJETIVO": {"TECNICO": 1.25, "PSICOLOGICO": 0.75},
	"QUIMICO": {"BRUTO": 1.25, "MENTAL": 0.75},
}


# Ciclo intransitivo (só se RULES.archetype_matchup). Versátil/Nenhum = neutro.
const ARCHETYPE_BEATS := {
	"Armadura": "Impacto",
	"Impacto": "Escudo",
	"Escudo": "Poder",
	"Poder": "Armadura",
}

static var HEROES := {
	"guerreiro": {"name": "Guerreiro", "hp": 112, "attack": 32, "power": 20, "armor": 20, "escudo": 20, "type": "BRUTO", "sprite": "res://hero_fighter.png", "row": "front", "passive": "vanguarda", "playable": false, "pool": ["corte", "guarda", "investida", "contra", "furia", "golpe_largo", "preparo", "ruptura", "frenesi_aco", "martelo_pesado", "furia_totem", "corte_adj"], "cards": ["corte", "corte", "guarda", "guarda", "investida", "investida", "contra", "furia"]},
	"mago": {"name": "Mago", "hp": 73, "attack": 20, "power": 36, "armor": 20, "escudo": 20, "type": "PROJETIVO", "sprite": "res://hero_wizard.png", "row": "back", "passive": "canalizar", "playable": false, "pool": ["raio", "barreira", "explosao", "runas", "tempestade", "centelha", "prisma", "eco", "visao", "selo_ruina", "dominio", "portal_impulso", "controlar_mente", "distorcer", "fagulha_incerta"], "cards": ["raio", "raio", "barreira", "barreira", "explosao", "explosao", "runas", "tempestade"]},
	"ladino": {"name": "Ladino", "hp": 81, "attack": 28, "power": 20, "armor": 20, "escudo": 20, "type": "TECNICO", "sprite": "res://hero_rogue.png", "row": "front", "passive": "oportunista", "playable": false, "pool": ["punhal", "esquiva", "marca", "corrente", "sombra", "armadilha", "furto", "golpe_oculto", "corte_dreno", "queda", "jogo_sombras"], "cards": ["punhal", "punhal", "esquiva", "esquiva", "marca", "marca", "corrente", "sombra"]},
	"clerigo": {"name": "Clérigo", "hp": 90, "attack": 20, "power": 28, "armor": 20, "escudo": 20, "type": "MENTAL", "sprite": "res://hero_cleric.png", "row": "back", "passive": "devocao", "playable": false, "pool": ["luz", "cura", "benção", "purificar", "julgamento", "abrigo", "fervor", "resgate", "campo_sagrado", "elo_vital", "benzer", "prisma_sangue", "balanca"], "cards": ["luz", "luz", "cura", "cura", "benção", "benção", "purificar", "julgamento"]},
	"paladino": {"name": "Paladino", "hp": 120, "attack": 24, "power": 20, "armor": 20, "escudo": 20, "type": "PSICOLOGICO", "sprite": "res://hero_paladin.png", "row": "front", "passive": "baluarte", "playable": false, "pool": ["martelo", "egide", "provocar", "escudo_forte", "sentenca", "muralha_viva", "juramento", "brilho", "estandarte", "guarda_absoluta", "pele_rigida", "furia_total", "cerco_frente"], "cards": ["martelo", "martelo", "egide", "egide", "provocar", "provocar", "escudo_forte", "sentenca"]},
	"patrulheiro": {"name": "Patrulheiro", "hp": 87, "attack": 24, "power": 20, "armor": 20, "escudo": 20, "type": "QUIMICO", "sprite": "res://hero_rogue.png", "row": "back", "passive": "rastreador", "playable": false, "pool": ["flecha", "foco", "salva", "rede", "veneno", "flanquear", "falcon", "chuva", "teia", "foco_ambiental", "predador", "armadilha_tempo", "agitar", "tiro_retaguarda"], "cards": ["flecha", "flecha", "foco", "foco", "salva", "rede", "veneno", "chuva"]},
	"fera": {"name": "Fera noturna", "hp": 60, "attack": 28, "power": 20, "armor": 20, "escudo": 20, "type": "QUIMICO", "ai": "ASSASSINO", "sprite": "res://en_dog.png", "row": "front", "passive": "oportunista", "playable": false, "minion": true, "repeatable": true, "pool": ["punhal", "investida", "corte", "veneno", "marca", "furto", "sombra", "queda"], "cards": ["punhal", "punhal", "investida", "corte", "veneno", "marca", "furto", "sombra"]},
	"guardiao": {"name": "Guardião do Eclipse", "hp": 119, "attack": 32, "power": 32, "armor": 20, "escudo": 20, "type": "MENTAL", "ai": "AGRESSIVO", "sprite": "res://en_elite.png", "row": "back", "passive": "canalizar", "playable": false, "minion": false, "boss": true, "pool": ["raio", "explosao", "tempestade", "julgamento", "selo_ruina", "brilho", "controlar_mente", "distorcer"], "cards": ["raio", "raio", "explosao", "tempestade", "julgamento", "brilho", "controlar_mente", "distorcer"]},
}

# Effects are applied in order. Each card is an action of its owner, never a summoned unit.
static var CARDS := {
	"corte": {"name": "Corte firme", "class": "ATTACK", "target": "ENEMY", "reach": false, "gain": 1, "quick": true, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["Special3"], "anim_target": ["SlashSP1"]},
	"guarda": {"name": "Postura de guarda", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 2, "stacks": 10}, {"kind": "STATUS", "id": "counter", "duration": 1, "stacks": 1}], "anim_self": ["buff"], "anim_target": ["Protection"]},
	"investida": {"name": "Investida de ferro", "class": "ATTACK", "target": "ENEMY", "reach": false, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 21, "stat": "attack"}, {"kind": "PUSH", "force": 2}], "anim_self": ["fire"], "anim_target": ["Explosion1"]},
	"contra": {"name": "Resposta de aço", "class": "SKILL", "target": "SELF", "gain": 2, "effects": [{"kind": "STATUS", "id": "counter", "duration": 2, "stacks": 2}, {"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 6}], "anim_self": ["Neutral1"], "anim_target": ["shield"]},
	"furia": {"name": "Fúria disciplinada", "class": "POWER", "target": "ENEMY_ROW", "cost": 4, "effects": [{"kind": "DAMAGE", "amount": 32, "stat": "attack"}, {"kind": "STATUS", "id": "weak", "duration": 2, "stacks": 1}], "anim_self": ["wind"], "anim_target": ["shield"]},
	"raio": {"name": "Raio concentrado", "class": "ATTACK", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "power"}], "anim_self": ["thunder"], "anim_target": ["Thunder2"]},
	"barreira": {"name": "Barreira arcana", "class": "SKILL", "target": "ALLY", "gain": 1, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 2, "stacks": 9}], "on_redraw": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 3}], "anim_self": ["buff"], "anim_target": ["Shield"]},
	"explosao": {"name": "Detonação rúnica", "class": "POWER", "target": "ENEMY_ROW", "reach": true, "cost": 3, "effects": [{"kind": "DAMAGE", "amount": 24, "stat": "power"}], "anim_self": ["lightning"], "anim_target": ["explosion"]},
	"runas": {"name": "Runas móveis", "class": "SKILL", "target": "ALLY", "gain": 2, "effects": [{"kind": "MOVE", "row": "other"}, {"kind": "DRAW", "amount": 1}, {"kind": "GENERATE", "id": "centelha"}], "anim_self": ["Special1"], "anim_target": ["shield"]},
	"tempestade": {"name": "Tempestade dos selos", "class": "POWER", "target": "ALL_ENEMIES", "reach": true, "cost": 5, "exhaust": true, "final": true, "effects": [{"kind": "DAMAGE", "amount": 21, "stat": "power"}, {"kind": "STATUS", "id": "stun", "duration": 1, "stacks": 1}], "anim_self": ["cast"], "anim_target": ["shield"]},
	"punhal": {"name": "Punhal veloz", "class": "ATTACK", "target": "ENEMY", "reach": false, "gain": 1, "quick": true, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["Neutral2"], "anim_target": ["Arrow"]},
	"esquiva": {"name": "Passo oculto", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "conceal", "duration": 1, "stacks": 1}, {"kind": "MOVE", "row": "other"}], "anim_self": ["Neutral1"], "anim_target": ["shield"]},
	"marca": {"name": "Alvo exposto", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 2, "free": true, "effects": [{"kind": "STATUS", "id": "marked", "duration": 2, "stacks": 1}, {"kind": "STATUS", "id": "vulnerable", "duration": 1, "stacks": 1}], "anim_self": ["Special1"], "anim_target": ["shield"]},
	"corrente": {"name": "Corte em sequência", "class": "ATTACK", "target": "CHAIN", "reach": true, "gain": 1, "chain": 3, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "full_combo": [{"kind": "STATUS", "id": "bleed", "duration": 2, "stacks": 2}], "anim_self": ["Special2"], "anim_target": ["SlashSP2"]},
	"sombra": {"name": "Dança sombria", "class": "POWER", "target": "ENEMY", "reach": true, "cost": 3, "effects": [{"kind": "DAMAGE", "amount": 38, "stat": "attack"}, {"kind": "STATUS", "id": "bleed", "duration": 2, "stacks": 2}], "anim_self": ["Special3"], "anim_target": ["shield"]},
	"luz": {"name": "Luz incisiva", "class": "ATTACK", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "power"}], "anim_self": ["BreathLight"], "anim_target": ["HitSP2"]},
	"cura": {"name": "Cura vital", "class": "SKILL", "target": "ALLY", "gain": 1, "effects": [{"kind": "HEAL", "amount": 12}, {"kind": "CLEANSE", "ids": ["poison", "bleed", "burn"]}], "anim_self": ["HeartMark1"], "anim_target": ["Light1"]},
	"benção": {"name": "Bênção persistente", "class": "SKILL", "target": "ALLY", "gain": 2, "effects": [{"kind": "STATUS", "id": "strengthened", "duration": 2, "stacks": 1}, {"kind": "STATUS", "id": "regen", "duration": 2, "stacks": 1}], "anim_self": ["BreathLight"], "anim_target": ["shield"]},
	"purificar": {"name": "Purificação", "class": "SKILL", "target": "ALLY", "gain": 1, "free": true, "effects": [{"kind": "CLEANSE", "ids": ["poison", "bleed", "burn", "weak", "bind", "silence", "blind"]}, {"kind": "DRAW", "amount": 1}], "anim_self": ["cast"], "anim_target": ["shield"]},
	"julgamento": {"name": "Julgamento", "class": "POWER", "target": "ENEMY", "reach": true, "cost": 4, "effects": [{"kind": "DAMAGE", "amount": 35, "stat": "power"}, {"kind": "STATUS", "id": "stun", "duration": 1, "stacks": 1}], "anim_self": ["fire"], "anim_target": ["shield"]},
	"martelo": {"name": "Golpe de martelo", "class": "ATTACK", "target": "ENEMY", "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}, {"kind": "PULL"}], "anim_self": ["lightning"], "anim_target": ["pull"]},
	"egide": {"name": "Égide", "class": "SKILL", "target": "ALLY", "gain": 1, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 8}, {"kind": "STATUS", "id": "resistente", "duration": 2, "stacks": 1}], "anim_self": ["buff"], "anim_target": ["Reflection"]},
	"provocar": {"name": "Desafio", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "taunt", "duration": 2, "stacks": 1}, {"kind": "STATUS", "id": "counter", "duration": 1, "stacks": 1}], "anim_self": ["Neutral1"], "anim_target": ["shield"]},
	"escudo_forte": {"name": "Muralha", "class": "SKILL", "target": "ALL_ALLIES", "gain": 2, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 6}, {"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 1}], "anim_self": ["buff"], "anim_target": ["Protection"]},
	"sentenca": {"name": "Sentença", "class": "POWER", "target": "ENEMY", "cost": 5, "effects": [{"kind": "DAMAGE", "amount": 40, "stat": "attack", "pierce": true}], "anim_self": ["Neutral2"], "anim_target": ["blow"]},
	# Legado: não injetar mais via _check_combo. Combos de grupo = duo/trio no deck (EntityRuntime).
	"dueto": {"name": "Pacto de batalha (legado)", "class": "COMBO", "tier": "combo", "target": "ENEMY", "reach": true, "cost": 4, "exhaust": true, "legacy_combo": true, "effects": [{"kind": "DAMAGE", "amount": 40, "stat": "power"}, {"kind": "DRAW", "amount": 1}], "anim_self": ["Special2"], "anim_target": ["CrossHit"], "text": "Legado desativado. Use Manobras Combo de grupo (duo/trio) no deck compartilhado."},
	"golpe_largo": {"name": "Arco de aço", "class": "ATTACK", "target": "ENEMY_ROW", "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["Special3"], "anim_target": ["slash"]},
	"preparo": {"name": "Reunir forças", "class": "SKILL", "target": "SELF", "free": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "strengthened", "duration": 2}, {"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 4}], "anim_self": ["Special1"], "anim_target": ["StarsHit"]},
	"ruptura": {"name": "Quebra de escudo", "class": "POWER", "target": "ENEMY", "cost": 3, "effects": [{"kind": "DAMAGE", "amount": 35, "stat": "attack", "pierce": true}, {"kind": "STATUS", "id": "vulnerable", "duration": 1}], "anim_self": ["buff"], "anim_target": ["Shield"]},
	"centelha": {"name": "Centelha", "class": "ATTACK", "target": "ENEMY", "reach": true, "quick": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "power"}], "anim_self": ["BreathThunder"], "anim_target": ["Thunder1"]},
	"prisma": {"name": "Prisma de defesa", "class": "SKILL", "target": "ALL_ALLIES", "cost": 2, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 5}], "anim_self": ["cast"], "anim_target": ["bind"]},
	"eco": {"name": "Eco arcano", "class": "SKILL", "target": "SELF", "gain": 2, "effects": [{"kind": "DRAW", "amount": 2}], "roulette": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 6}, {"kind": "STATUS", "id": "strengthened", "duration": 1}], "anim_self": ["summon"], "anim_target": ["shield"]},
	"armadilha": {"name": "Armadilha curta", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "bind", "duration": 2}, {"kind": "STATUS", "id": "weak", "duration": 1}], "anim_self": ["Neutral1"], "anim_target": ["status"]},
	"furto": {"name": "Furto veloz", "class": "ATTACK", "target": "ENEMY", "gain": 2, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}, {"kind": "DRAW", "amount": 1}], "anim_self": ["fire"], "anim_target": ["hit"]},
	"golpe_oculto": {"name": "Punhal nas sombras", "class": "POWER", "target": "ENEMY", "reach": true, "cost": 4, "effects": [{"kind": "DAMAGE", "amount": 40, "stat": "attack"}], "anim_self": ["Smokescreen"], "anim_target": ["Shoot1"]},
	"abrigo": {"name": "Abrigo sagrado", "class": "SKILL", "target": "ALL_ALLIES", "cost": 2, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 5}, {"kind": "STATUS", "id": "protecao", "duration": 1}], "anim_self": ["HeartMark1"], "anim_target": ["Reflection"]},
	"fervor": {"name": "Fervor", "class": "SKILL", "target": "ALLY", "free": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "strengthened", "duration": 1}], "anim_self": ["Neutral2"], "anim_target": ["debuff"]},
	"resgate": {"name": "Resgate", "class": "SKILL", "target": "ALLY", "gain": 1, "effects": [{"kind": "HEAL", "amount": 7}, {"kind": "MOVE"}], "anim_self": ["light"], "anim_target": ["Light3"]},
	"muralha_viva": {"name": "Muralha viva", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 2, "stacks": 12}, {"kind": "STATUS", "id": "taunt", "duration": 1}], "anim_self": ["guard"], "anim_target": ["Protection"]},
	"juramento": {"name": "Juramento de aço", "class": "SKILL", "target": "ALLY", "gain": 2, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 8}, {"kind": "CLEANSE", "ids": ["weak", "vulnerable"]}], "anim_self": ["Special1"], "anim_target": ["stun"]},
	"brilho": {"name": "Clarão", "class": "ATTACK", "target": "ENEMY_ROW", "reach": true, "cost": 2, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "power"}, {"kind": "STATUS", "id": "blind", "duration": 1}], "anim_self": ["lightning"], "anim_target": ["StarsHit"]},
	"flecha": {"name": "Flecha certeira", "class": "ATTACK", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["Special2"], "anim_target": ["pierce"]},
	"foco": {"name": "Foco do caçador", "class": "SKILL", "target": "SELF", "gain": 2, "effects": [{"kind": "STATUS", "id": "strengthened", "duration": 1}, {"kind": "DRAW", "amount": 1}], "anim_self": ["cast"], "anim_target": ["bind"]},
	"salva": {"name": "Salva rente", "class": "ATTACK", "target": "ENEMY_ROW", "reach": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["Special3"], "anim_target": ["HitSP1"]},
	"rede": {"name": "Rede de caça", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "bind", "duration": 2}, {"kind": "PULL"}], "anim_self": ["Neutral1"], "anim_target": ["pull"]},
	"veneno": {"name": "Flecha contaminada", "class": "ATTACK", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}, {"kind": "STATUS", "id": "poison", "duration": 2, "stacks": 2}], "anim_self": ["fire"], "anim_target": ["PierceSP1"]},
	"flanquear": {"name": "Flanquear", "class": "SKILL", "target": "SELF", "free": true, "gain": 1, "effects": [{"kind": "MOVE"}, {"kind": "STATUS", "id": "conceal", "duration": 1}], "anim_self": ["Neutral2"], "anim_target": ["shield"]},
	"falcon": {"name": "Olho da falcoaria", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 2, "effects": [{"kind": "STATUS", "id": "marked", "duration": 2}, {"kind": "DRAW", "amount": 1}], "anim_self": ["Special1"], "anim_target": ["status"]},
	"chuva": {"name": "Chuva de pontas", "class": "POWER", "target": "ALL_ENEMIES", "reach": true, "cost": 5, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["lightning"], "anim_target": ["HitSP2"]},
	"frenesi_aco": {"name": "Frenesi de aço", "class": "SKILL", "target": "SELF", "gain": 2, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 9}, {"kind": "STATUS", "id": "bloodlust", "duration": 2}, {"kind": "STATUS", "id": "counter", "duration": 2}], "anim_self": ["cast"], "anim_target": ["debuff"]},
	"martelo_pesado": {"name": "Martelo impulsor", "class": "ATTACK", "target": "ENEMY", "cost": 2, "effects": [{"kind": "DAMAGE", "amount": 21, "stat": "attack"}, {"kind": "PUSH", "force": 2, "forceful": true}], "anim_self": ["Special2"], "anim_target": ["push"]},
	"visao": {"name": "Visão do porvir", "class": "SKILL", "target": "SELF", "free": true, "effects": [{"kind": "STATUS", "id": "next_turn_plays", "duration": 2}, {"kind": "NEXT_TURN", "effects": [{"kind": "DRAW", "amount": 1}]}], "anim_self": ["Neutral1"], "anim_target": ["stun"]},
	"selo_ruina": {"name": "Selo de ruína", "class": "POWER", "target": "ENEMY", "reach": true, "cost": 3, "effects": [{"kind": "STATUS", "id": "corrupted", "duration": 2}, {"kind": "STATUS", "id": "overload", "duration": 2}], "anim_self": ["Special3"], "anim_target": ["blow"]},
	"corte_dreno": {"name": "Corte drenante", "class": "ATTACK", "target": "ENEMY", "gain": 1, "effects": [{"kind": "STATUS", "id": "lifesteal", "duration": 1, "self": true}, {"kind": "DAMAGE", "amount": 20, "stat": "attack"}, {"kind": "STATUS", "id": "wounded", "duration": 2}], "anim_self": ["fire"], "anim_target": ["CrossSlash"]},
	"queda": {"name": "Passagem perigosa", "class": "SKILL", "target": "ENEMY", "reach": true, "cost": 2, "effects": [{"kind": "STATUS", "id": "drop", "duration": 2}, {"kind": "PUSH", "force": 1}], "anim_self": ["Neutral2"], "anim_target": ["Explosion1"]},
	"campo_sagrado": {"name": "Campo sagrado", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "chaos_field", "duration": 2}, {"kind": "CURE"}], "anim_self": ["BreathLight"], "anim_target": ["StarsHit"]},
	"elo_vital": {"name": "Elo vital", "class": "SKILL", "target": "ALL_ALLIES", "cost": 2, "effects": [{"kind": "STATUS", "id": "soulbound", "duration": 2}, {"kind": "HEAL", "amount": 3}], "anim_self": ["HeartMark1"], "anim_target": ["Light4"]},
	"estandarte": {"name": "Estandarte de defesa", "class": "SKILL", "target": "SELF", "cost": 2, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 2, "stacks": 15}, {"kind": "STATUS", "id": "binary", "duration": 2}, {"kind": "STATUS", "id": "protecao", "duration": 2}], "anim_self": ["buff"], "anim_target": ["bind"]},
	"guarda_absoluta": {"name": "Guarda absoluta", "class": "SKILL", "target": "ALLY", "gain": 1, "effects": [{"kind": "STATUS", "id": "protecao", "duration": 1}, {"kind": "STATUS", "id": "invulnerable", "duration": 1}], "anim_self": ["guard"], "anim_target": ["Shield"]},
	"teia": {"name": "Teia de caça", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "webbed_up", "duration": 2}, {"kind": "STATUS", "id": "bound", "duration": 1}], "anim_self": ["Special1"], "anim_target": ["shield"]},
	"foco_ambiental": {"name": "Foco ambiental", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "opportunist", "duration": 2, "stacks": 2}, {"kind": "STATUS", "id": "perfect_aim", "duration": 2, "stacks": 2}], "anim_self": ["cast"], "anim_target": ["status"]},
	"furia_totem": {"name": "Fúria do totem", "class": "SKILL", "target": "SELF", "cost": 2, "effects": [{"kind": "STATUS", "id": "en_fuego", "duration": 99}, {"kind": "STATUS", "id": "fury_totem", "duration": 2}, {"kind": "STATUS", "id": "fatal_fury", "duration": 1}], "anim_self": ["wind"], "anim_target": ["debuff"]},
	"dominio": {"name": "Domínio do selo", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "enhanced", "duration": 2}, {"kind": "STATUS", "id": "fast", "duration": 2}, {"kind": "STATUS", "id": "unleashed", "duration": 2}, {"kind": "STATUS", "id": "portal", "duration": 2}, {"kind": "STATUS", "id": "neurally_enhanced", "duration": 2}], "anim_self": ["Neutral1"], "anim_target": ["stun"]},
	"portal_impulso": {"name": "Impulso do selo", "class": "ATTACK", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "power"}, {"kind": "PUSH", "force": 1}], "anim_self": ["lightning"], "anim_target": ["push"]},
	"controlar_mente": {"name": "Ruído mental", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "stun", "duration": 2, "stacks": 2}, {"kind": "STATUS", "id": "slow", "duration": 2}], "anim_self": ["Neutral2"], "anim_target": ["StarsHit"]},
	"distorcer": {"name": "Distorcer vontade", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "confused", "duration": 2, "stacks": 2}], "anim_self": ["buff"], "anim_target": ["bind"]},
	"jogo_sombras": {"name": "Jogo de sombras", "class": "SKILL", "target": "SELF", "cost": 2, "effects": [{"kind": "STATUS", "id": "momentum", "duration": 1}, {"kind": "STATUS", "id": "critical", "duration": 1}, {"kind": "STATUS", "id": "berserk_lifesteal", "duration": 1}, {"kind": "STATUS", "id": "make_em_bleed", "duration": 2, "stacks": 2}], "anim_self": ["darkness"], "anim_target": ["shield"]},
	"benzer": {"name": "Bênção do grupo", "class": "SKILL", "target": "ALL_ALLIES", "cost": 2, "effects": [{"kind": "STATUS", "id": "blessed", "duration": 2}, {"kind": "STATUS", "id": "all_together_now", "duration": 2, "stacks": 2}, {"kind": "STATUS", "id": "offensive_rush", "duration": 2}], "anim_self": ["BreathLight"], "anim_target": ["status"]},
	"prisma_sangue": {"name": "Prisma sanguíneo", "class": "SKILL", "target": "ALLY", "gain": 1, "effects": [{"kind": "STATUS", "id": "blood_magic", "duration": 2}, {"kind": "STATUS", "id": "vampiric_essence", "duration": 2}], "anim_self": ["Special1"], "anim_target": ["debuff"]},
	"pele_rigida": {"name": "Pele selada", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "barrier", "duration": 2, "stacks": 10}, {"kind": "STATUS", "id": "symbiote_skin", "duration": 1}, {"kind": "STATUS", "id": "protecao", "duration": 1}], "anim_self": ["cast"], "anim_target": ["stun"]},
	"furia_total": {"name": "Força total", "class": "SKILL", "target": "SELF", "cost": 2, "effects": [{"kind": "STATUS", "id": "overpowered", "duration": 2}, {"kind": "STATUS", "id": "strongest_there_is", "duration": 2}], "anim_self": ["Neutral1"], "anim_target": ["StarsHit"]},
	"predador": {"name": "Instinto do predador", "class": "SKILL", "target": "SELF", "gain": 1, "effects": [{"kind": "STATUS", "id": "ravenous", "duration": 3, "stacks": 5}, {"kind": "STATUS", "id": "naturalist", "duration": 2}, {"kind": "STATUS", "id": "full_force", "duration": 2}], "anim_self": ["Neutral2"], "anim_target": ["bind"]},
	"armadilha_tempo": {"name": "Laço instável", "class": "SKILL", "target": "ENEMY", "reach": true, "cost": 2, "effects": [{"kind": "STATUS", "id": "banished", "duration": 1}, {"kind": "STATUS", "id": "spike_bomb", "duration": 2}], "anim_self": ["buff"], "anim_target": ["shield"]},
	"agitar": {"name": "Agitação dirigida", "class": "SKILL", "target": "ENEMY", "reach": true, "gain": 1, "effects": [{"kind": "STATUS", "id": "berserk_enemy", "duration": 1}, {"kind": "STATUS", "id": "taunted", "duration": 1}], "anim_self": ["guard"], "anim_target": ["status"]},
	"corte_adj": {"name": "Corte de flanco", "class": "ATTACK", "target": "ADJACENT", "rarity": "Incomum", "gain": 1, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}], "anim_self": ["Special2"], "anim_target": ["SlashSP1"]},
	"fagulha_incerta": {"name": "Fagulha incerta", "class": "ATTACK", "target": "RANDOM", "rarity": "Incomum", "reach": true, "gain": 2, "effects": [{"kind": "DAMAGE", "amount": 28, "stat": "power"}], "anim_self": ["Special3"], "anim_target": ["CrossHit"]},
	"cerco_frente": {"name": "Cerco frontal", "class": "POWER", "target": "FRONT_ROW", "rarity": "Rara", "copy_limit": 1, "cost": 3, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}, {"kind": "STATUS", "id": "weak", "duration": 1}], "anim_self": ["fire"], "anim_target": ["slash"]},
	"tiro_retaguarda": {"name": "Disparo de retaguarda", "class": "POWER", "target": "BACK_ROW", "rarity": "Rara", "copy_limit": 1, "reach": true, "cost": 3, "effects": [{"kind": "DAMAGE", "amount": 28, "stat": "attack"}], "anim_self": ["guard"], "anim_target": ["Reflection"]},
	"balanca": {"name": "Balança de cinzas", "class": "SKILL", "target": "ANY_UNIT", "rarity": "Incomum", "reach": true, "gain": 1, "effects": [{"kind": "HEAL", "amount": 8}, {"kind": "STATUS", "id": "weak", "duration": 1}], "anim_self": ["light"], "anim_target": ["heal"]},
	"item_potion": {"name": "Poção", "class": "SKILL", "target": "ALLY", "free": true, "exhaust": true, "item": true, "art": "res://assets/items/potion.png", "effects": [{"kind": "HEAL", "amount": 15}], "anim_self": ["light"], "anim_target": ["Light1"]},
	"item_antidote": {"name": "Antídoto", "class": "SKILL", "target": "ALLY", "free": true, "exhaust": true, "item": true, "art": "res://assets/items/antidote.png", "effects": [{"kind": "CURE"}], "anim_self": ["Special1"], "anim_target": ["debuff"]},
	"item_bomb": {"name": "Bomba", "class": "ATTACK", "target": "ENEMY", "reach": true, "free": true, "exhaust": true, "item": true, "art": "res://assets/items/bomb.png", "effects": [{"kind": "DAMAGE", "amount": 40, "stat": "none"}], "anim_self": ["lightning"], "anim_target": ["hit"]},
	"reanimar": {"name": "Reanimar", "class": "SKILL", "target": "DEAD_ALLY", "cost": 4, "text": "Revive um aliado caído com 25% da Vida máxima e aplica Ferido 1.", "effects": [{"kind": "REVIVE", "fraction": 0.25}, {"kind": "STATUS", "id": "ferido", "duration": 1, "stacks": 1}], "anim_self": ["HeartMark1"], "anim_target": ["Light1"]},
}

const ENEMIES := {
	"soldado": {"name": "Sentinela", "hp": 87, "attack": 20, "power": 20, "armor": 20, "escudo": 20, "type": "BRUTO", "ai": "DEFENSIVO", "sprite": "res://en_elite.png", "row": "front", "skills": ["strike", "guard"]},
	"arqueiro": {"name": "Batedor", "hp": 74, "attack": 20, "power": 20, "armor": 20, "escudo": 20, "type": "PROJETIVO", "sprite": "res://en_sniper.png", "row": "back", "skills": ["shot", "poison_shot"]},
	"fera": {"name": "Fera noturna", "hp": 60, "attack": 28, "power": 20, "armor": 20, "escudo": 20, "type": "QUIMICO", "ai": "ASSASSINO", "sprite": "res://en_dog.png", "row": "front", "minion": true, "skills": ["strike"]},
	"elite": {"name": "Capitão da Vigília", "hp": 98, "attack": 28, "power": 20, "armor": 20, "escudo": 20, "type": "TECNICO", "ai": "DEFENSIVO", "sprite": "res://en_elite.png", "row": "front", "elite": true, "skills": ["strike", "guard", "sweep"]},
	"boss": {"name": "Guardião do Eclipse", "hp": 119, "attack": 32, "power": 32, "armor": 20, "escudo": 20, "type": "MENTAL", "faction": "abissal", "sprite": "res://en_elite.png", "row": "back", "boss": true, "skills": ["shot", "sweep", "ritual"]},
	"batedor": {"name": "Escaramuçador", "hp": 83, "attack": 24, "power": 20, "armor": 20, "escudo": 20, "type": "TECNICO", "ai": "ASSASSINO", "sprite": "res://en_sniper.png", "row": "front", "skills": ["strike", "poison_shot"]},
	"ocultista": {"name": "Ocultista", "hp": 62, "attack": 20, "power": 28, "armor": 20, "escudo": 20, "type": "MENTAL", "sprite": "res://en_sniper.png", "row": "back", "skills": ["ritual", "shot", "invocacao"]},
	"brutamontes": {"name": "Brutamontes", "hp": 78, "attack": 32, "power": 20, "armor": 20, "escudo": 20, "type": "BRUTO", "ai": "AGRESSIVO", "sprite": "res://en_elite.png", "row": "front", "skills": ["strike", "sweep"]},
	"carrasco": {"name": "Carrasco", "hp": 67, "attack": 28, "power": 20, "armor": 20, "escudo": 20, "type": "PSICOLOGICO", "sprite": "res://en_elite.png", "row": "front", "skills": ["strike", "ritual", "transe", "fome"]},
	"alquimista": {"name": "Alquimista", "hp": 87, "attack": 20, "power": 24, "armor": 20, "escudo": 20, "type": "QUIMICO", "sprite": "res://en_sniper.png", "row": "back", "skills": ["poison_shot", "guard"]},
	"vigia": {"name": "Vigia", "hp": 83, "attack": 20, "power": 20, "armor": 20, "escudo": 20, "type": "PROJETIVO", "sprite": "res://en_sniper.png", "row": "back", "skills": ["shot", "guard"]},
	"sombrio": {"name": "Acólito sombrio", "hp": 74, "attack": 20, "power": 20, "armor": 20, "escudo": 20, "type": "MENTAL", "faction": "abissal", "sprite": "res://en_dog.png", "row": "front", "skills": ["ritual", "strike"]},
	"elite_alquimista": {"name": "Mestre dos Venenos", "hp": 112, "attack": 20, "power": 32, "armor": 20, "escudo": 20, "type": "QUIMICO", "sprite": "res://en_elite.png", "row": "back", "elite": true, "skills": ["poison_shot", "ritual", "guard"]},
	"elite_bruto": {"name": "General de Ferro", "hp": 120, "attack": 40, "power": 20, "armor": 20, "escudo": 20, "type": "BRUTO", "ai": "DEFENSIVO", "sprite": "res://en_elite.png", "row": "front", "elite": true, "skills": ["strike", "sweep", "guard", "espinhos"]},
}

const ENEMY_CARDS := {
	"strike": {"name": "Ataque", "target": "ENEMY", "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}]},
	"shot": {"name": "Disparo", "target": "ENEMY", "reach": true, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}]},
	"poison_shot": {"name": "Dardo tóxico", "target": "ENEMY", "reach": true, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}, {"kind": "STATUS", "id": "poison", "duration": 2, "stacks": 1}, {"kind": "INFECT"}]},
	"guard": {"name": "Guarda", "target": "SELF", "effects": [{"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 7}]},
	"sweep": {"name": "Varredura", "target": "ENEMY_ROW", "reach": true, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "attack"}]},
	"ritual": {"name": "Selo adverso", "target": "ENEMY", "reach": true, "effects": [{"kind": "DAMAGE", "amount": 20, "stat": "power"}, {"kind": "STATUS", "id": "weak", "duration": 2, "stacks": 1}]},
	"invocacao": {"name": "Círculo instável", "target": "SELF", "priority": 19, "effects": [{"kind": "STATUS", "id": "summoning", "duration": 2}]},
	"transe": {"name": "Transe de guerra", "target": "SELF", "priority": 17, "effects": [{"kind": "STATUS", "id": "frenzy", "duration": 2, "stacks": 2}]},
	"fome": {"name": "Caça ao objetivo", "target": "SELF", "priority": 15, "objective": "PROTECT", "effects": [{"kind": "STATUS", "id": "feeding_frenzy", "duration": 2, "stacks": 3}]},
	"espinhos": {"name": "Pele espinhosa", "target": "SELF", "priority": 16, "effects": [{"kind": "STATUS", "id": "symbiote_skin", "duration": 1}, {"kind": "STATUS", "id": "barrier", "duration": 1, "stacks": 6}]},
}

static var MISSIONS := {
	"road": {"name": "Estrada abandonada", "objective": "ELIMINATE", "enemies": ["ent_akuji", "ent_fate", "ent_evelyn_graves"], "reinforcements": {3: ["fera", "fera"]}, "environment": [{"name": "Coluna rachada", "cost": 2, "damage": 6, "target": "front"}]},
	"ritual": {"name": "Círculo de cinzas", "objective": "SURVIVE", "turns": 5, "enemies": ["ent_techna", "ent_nero", "ent_taylor"], "reinforcements": {3: ["fera"]}, "environment": [{"name": "Runa instável", "cost": 2, "status": "vulnerable", "target": "back"}]},
	"watch": {"name": "Defesa da sentinela", "objective": "PROTECT", "turns": 4, "protect_hp": 40, "enemies": ["ent_quasar", "ent_alistair", "ent_kabuki"], "reinforcements": {2: ["fera"]}, "environment": [{"name": "Cristal de vigília", "cost": 2, "heal": 8, "target": "ally"}]},
	"eclipse": {"name": "Guardião do Eclipse", "objective": "BOSS", "enemies": ["guardiao", "ent_dominika_seur", "ent_leona"], "reinforcements": {3: ["fera", "fera"]}, "environment": [{"name": "Pilar selado", "cost": 3, "damage": 9, "target": "back"}]},
	"street": {"name": "Rua noturna", "objective": "ELIMINATE", "arena": "street_night", "enemies": ["ent_daeva", "ent_alexis", "ent_alyssa_wine"], "reinforcements": {2: ["fera"], 4: ["fera"]}, "environment": [{"name": "Poste quebrado", "cost": 2, "damage": 7, "target": "front"}, {"name": "Sinal de neon", "cost": 3, "status": "blind", "target": "back"}]},
}

# Campaign order does not change the combat data: mission identifiers remain stable in saves.
static var CAMPAIGN := {
	"road": {"requires": [], "par": 4, "brief": "Akuji, Fate e Evelyn Graves bloqueiam a estrada. Elimine a patrulha; feras chegam na terceira rodada.", "goal": "Elimine inimigos e reforços."},
	"ritual": {"requires": ["road"], "par": 5, "brief": "O círculo permanece ativo por cinco rodadas. Techna, Nero e Taylor mantêm o selo.", "goal": "Resista por cinco rodadas."},
	"watch": {"requires": ["road"], "par": 4, "brief": "Defenda a sentinela até a quarta rodada. Quasar, Alistair e Kabuki pressionam a vigília. Uma fera entra na segunda rodada.", "goal": "Proteja a sentinela por quatro rodadas."},
	"eclipse": {"requires": ["ritual", "watch"], "par": 6, "brief": "O Guardião do Eclipse ocupa a retaguarda, com Dominika e Leona. Reduza sua vida à metade para expor a segunda fase.", "goal": "Derrote o Guardião do Eclipse."},
	"street": {"requires": ["road"], "par": 4, "brief": "Daeva, Alexis e Alyssa Wine controlam a rua noturna. Elimine a gangue; feras surgem na segunda e quarta rodadas.", "goal": "Limpe a rua noturna."},
}

static var HERO_LORE := {
	"guerreiro": {"role": "Vanguarda", "trait": "Na frente recebe 2 de Bloqueio no começo de cada rodada.", "history": "Ex-sentinela que abandonou a Vigília após a queda da estrada."},
	"mago": {"role": "Artilharia", "trait": "Canalizar gera 1 Iniciativa a cada rodada.", "history": "Estudou os selos que alimentam o ritual de cinzas."},
	"ladino": {"role": "Execução", "trait": "Causa dano extra a alvos marcados.", "history": "Contrabandista que conhece as rotas entre os postos da Vigília."},
	"clerigo": {"role": "Sustento", "trait": "Amplia a cura das habilidades.", "history": "Guardião das últimas sentinelas que resistem à corrupção."},
	"paladino": {"role": "Proteção", "trait": "Recebe 2 de Escudo a cada rodada.", "history": "Jurou manter o círculo de cinzas fechado."},
	"patrulheiro": {"role": "Controle", "trait": "Ataca melhor da retaguarda.", "history": "Rastreia os reforços que atravessam a estrada abandonada."},
	"fera": {"role": "Minion", "trait": "Pode haver mais de uma fera no mesmo lado. Não entra no grupo do jogador.", "history": "Caça em matilha. O código marca minion para permitir cópias."},
	"guardiao": {"role": "Chefe", "trait": "Na segunda fase o lado adversário ganha uma ação extra. Não pode ser escolhido pelo jogador.", "history": "O eclipse anda com as mesmas cartas dos heróis, só que do outro lado da arena."},
}
