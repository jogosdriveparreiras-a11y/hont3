extends RefCounted
class_name HotNCombatRules

## Valores ajustáveis do combate, agrupados pela função que têm nas cartas.
## Para balancear, altere os números aqui sem procurar a fórmula nos runtimes.

const STATES := {
	"sangrando": {"max_stacks": 15, "max_hp_fraction_per_stack": 0.05, "decay_per_round": 1},
	"ferido": {"max_hp_fraction_per_stack": 0.10, "damage_per_stack": 1, "decay_per_round": 1},
	"fraco": {"damage_divisor_per_stack": 1.0, "decay_per_round": 1},
	"fortalecido": {"bonus_per_stack": 0.5, "decay_per_round": 1},
	"fragil": {"defense_divisor_per_stack": 1.0, "max_stacks": 5, "decay_per_round": 1},
	"resistente": {"bonus_per_stack": 0.5, "max_stacks": 5, "decay_per_round": 1},
	"vulneravel": {"damage_received_multiplier": 1.5, "decay_per_round": 1},
	"critico": {"damage_multiplier": 1.5},
	"binary": {"damage_multiplier": 2.0},
	"penetrante": {"defense_multiplier": 0.5},
	"lento": {"ini_cost_per_stack": 1, "decay_per_round": 1},
	"rapido": {"ini_discount_per_stack": 1, "decay_per_round": 1},
	"protecao": {"max_stacks": 15, "hits_per_stack": 1, "decay_per_round": 1},
	"barreira": {"hp_per_stack": 10},
	"corrompido": {"damage_per_stack": 2, "spread_duration": 2, "spread_stacks": 1},
	"regeneracao": {"heal_per_stack": 3},
	"voraz": {"damage_bonus_per_stack": 0.2, "max_stacks": 5, "growth_per_round": 1},
	"teia": {"environmental_damage_multiplier": 1.5},
	"forca_total": {"environmental_damage_multiplier": 1.5},
	"voar": {"landing_damage_max_hp_fraction": 0.10, "movement_damage_multiplier": 2.0},
	"sede_de_sangue": {"bleed_duration": 2, "bleed_stacks": 1},
	"fazer_sangrar": {"bleed_duration": 2, "bleed_stacks": 2},
}

const EFFECTS := {
	"recuo": {"damage_divisor": 3.0},
	"dreno": {"heal_divisor": 4.0},
	"colisao": {"base_damage_flat": 10, "base_damage_max_hp_fraction": 0.10, "boundary_damage_max_hp_fraction": 0.10},
	"recompra": {"attack_bonus": 0.5},
}

const REQUIREMENTS := {
	"status": {"default_stacks": 1},
	"requires_self_status": {"default_stacks": 1},
	"when_stacks": {"default_stacks": 1},
	"chain": {"minimum_targets": 1},
}

const RESOURCES := {
	"iniciativa": {
		"fast_discount": 1,
		"slow_surcharge": 1,
		"redraw_summon_cost": 1,
		"repeated_summon_cost": 2,
	},
	"protecao": {"max_stacks": 15, "stacks_spent_per_hit": 1},
	"barreira": {"hp_per_stack": 10},
	"escuridao": {"max_stacks": 20},
}

const POSTURES := {
	"tanque": {"gain": 1, "label": "Tanque"}, "furioso": {"gain": 1, "label": "Furioso"},
	"curador": {"gain": 2, "label": "Curador"}, "empatico": {"gain": 2, "label": "Empático"},
	"atirador": {"gain": 2, "label": "Atirador"}, "drenador": {"gain": 2, "label": "Drenador"},
	"controlador": {"gain": 2, "label": "Controlador"}, "garra": {"gain": 3, "label": "Garra"},
	"vingador": {"gain": 2, "label": "Vingador"}, "executor": {"gain": 2, "label": "Executor"},
	"indomavel": {"gain": 2, "label": "Indomável"}, "sobrevivente": {"gain": 3, "label": "Sobrevivente"},
	"intocavel": {"gain": 2, "label": "Intocável"}, "preparo": {"gain": 3, "label": "Preparo"},
}

## Generic read path: formula_value("Estados", "voar", "movement_damage_multiplier", 2.0).
static func category_values(category: String) -> Dictionary:
	match category.to_lower():
		"estados", "states": return STATES
		"efeitos", "effects": return EFFECTS
		"requerimentos", "requirements": return REQUIREMENTS
		"recursos", "resources": return RESOURCES
		"posturas", "postures": return POSTURES
		_: return {}

static func formula_value(category: String, id: String, key: String, fallback: Variant = 0) -> Variant:
	var group := category_values(category)
	var formula: Variant = group.get(id, {})
	if typeof(formula) != TYPE_DICTIONARY:
		return fallback
	return formula.get(key, fallback)

static func posture_gain(id: String) -> int:
	return int(formula_value("Posturas", id, "gain", 0))

## Compatibility helper for the existing combat call sites.
static func status_value(id: String, key: String, fallback: Variant = 0) -> Variant:
	return formula_value("Estados", id, key, fallback)

static func initiative_cost(base: int, fast: int, slow: int) -> int:
	var discount := int(formula_value("Recursos", "iniciativa", "fast_discount", 1)) if fast > 0 else 0
	var surcharge := int(formula_value("Recursos", "iniciativa", "slow_surcharge", 1)) if slow > 0 else 0
	return maxi(0, base - discount + surcharge)

static func wounded_damage(max_hp: int, stacks: int) -> int:
	return maxi(1, roundi(float(max_hp) * float(status_value("ferido", "max_hp_fraction_per_stack", 0.10)) * stacks * float(status_value("ferido", "damage_per_stack", 1))))

static func bleed_damage(max_hp: int, stacks: int) -> int:
	return maxi(1, roundi(float(max_hp) * float(status_value("sangrando", "max_hp_fraction_per_stack", 0.05)) * stacks))

static func corrupted_damage(stacks: int) -> int:
	return maxi(1, stacks * int(status_value("corrompido", "damage_per_stack", 2)))

static func drain_heal(hit: int) -> int:
	return maxi(0, roundi(float(hit) / float(formula_value("Efeitos", "dreno", "heal_divisor", 4.0))))

static func recoil_damage(hit: int) -> int:
	return maxi(0, roundi(float(hit) / float(formula_value("Efeitos", "recuo", "damage_divisor", 3.0))))

static func damage_multiplier(weak_stacks: int, strengthened_stacks: int, binary: bool, critical: bool, ravenous: int) -> float:
	var result := 1.0
	if weak_stacks > 0:
		result /= 1.0 + weak_stacks * float(status_value("fraco", "damage_divisor_per_stack", 1.0))
	if strengthened_stacks > 0:
		result *= 1.0 + float(status_value("fortalecido", "bonus_per_stack", 0.5)) * strengthened_stacks
	if binary:
		result *= float(status_value("binary", "damage_multiplier", 2.0))
	if critical:
		result *= float(status_value("critico", "damage_multiplier", 1.5))
	return result * (1.0 + float(status_value("voraz", "damage_bonus_per_stack", 0.2)) * ravenous)

static func defense(base: int, armor_stacks: int, resistant: int, fragile: int, penetrating: bool) -> int:
	var result := base + armor_stacks * 2
	if resistant > 0:
		result = roundi(float(result) * (1.0 + float(status_value("resistente", "bonus_per_stack", 0.5)) * resistant))
	if fragile > 0:
		result = roundi(float(result) / (1.0 + float(status_value("fragil", "defense_divisor_per_stack", 1.0)) * fragile))
	# Penetrante ignora apenas Resistente; Armadura/Escudo base continuam integrais.
	if penetrating:
		result = base + armor_stacks * 2
		if fragile > 0:
			result = roundi(float(result) / (1.0 + float(status_value("fragil", "defense_divisor_per_stack", 1.0)) * fragile))
	return maxi(0, result)
