
const pk = preload("res://scripts/pokeSim/core/pokemon.gd")
const tr = preload("res://scripts/pokeSim/core/trainer.gd")
const bf = preload("res://scripts/pokeSim/core/battlefield.gd")

const pa = preload("res://scripts/pokeSim/util/process_ability.gd")
const pi = preload("res://scripts/pokeSim/util/process_item.gd")

const gs = preload("res://scripts/pokeSim/conf/global_settings.gd")
const gd = preload("res://scripts/pokeSim/conf/global_data.gd")

static func process_move(attacker, defender, battlefield, battle, move_data, is_first):
	if _pre_process_status(attacker, defender, battlefield, battle, move_data):
		return
	battle.add_text(attacker.nickname + " used " + cap_name(move_data.name) + "!")
	battle.last_move_next = move_data
	attacker.last_move_next = move_data
	if not _calculate_hit_or_miss(attacker, defender, battlefield, battle, move_data, is_first):
		return
	attacker.last_successful_move_next = move_data
	if _meta_effect_check(attacker, defender, battlefield, battle, move_data, is_first):
		return
	_process_effect(attacker, defender, battlefield, battle, move_data, is_first)
	_post_process_status(attacker, defender, battlefield, battle, move_data)
	battle._faint_check()

static func _calculate_type_ef(defender, move_data):
	if move_data.type == "typeless":
		return 1
	if move_data.type == "ground" and not defender.grounded and (defender.magnet_rise or defender.has_ability("levitate")):
		return 0

	var vulnerable_types = []
	if move_data.type == "ground" and "flying" in defender.types and defender.grounded:
		vulnerable_types.append("flying")
	if (defender.foresight_target or defender.enemy.current_poke.has_ability("scrappy")) and move_data.type in ["normal", "fighting"] and "ghost" in defender.types:
		vulnerable_types.append("ghost")
	if defender.me_target and move_data.type == "psychic" and "dark" in defender.types:
		vulnerable_types.append("dark")

	var t_mult = PokeSim.get_type_ef(move_data.type, defender.types[0])
	if defender.types[1] and defender.types[1] not in vulnerable_types:
		t_mult = t_mult * PokeSim.get_type_ef(move_data.type, defender.types[1])
	return t_mult


static func _calculate_random_multiplier_damage() -> float:
	return randf_range(85, 101) / 100

static func _calculate_damage(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	crit_chance: int = 0,
	inv_bypass: bool = false,
	skip_fc: bool = false,
	skip_dmg: bool = false,
	skip_txt: bool = false,
	fix_damage: Variant = null
) -> int:
	if battle.winner or move_data.category == gs.STATUS:
		return 0
	if not defender.is_alive:
		_missed(attacker, battle)
		return 0
	if _protect_check(defender, battle, move_data):
		return 0
	if fix_damage == null and not move_data.power:
		return 0

	if not inv_bypass and _invulnerability_check(
		attacker, defender, battlefield, battle, move_data
	):
		return 0
	if not move_data.power:
		return 0
	
	var type_multiplier = _calculate_type_ef(defender, move_data)

	if not skip_txt and (type_multiplier == 0 or (type_multiplier < 2 and defender.has_ability("wonder-guard"))):
		_not_affected(battle, defender)
		return 0
	if fix_damage == null:
		if pa.type_protection_abilities(defender, move_data, battle):
			return 0

	var critical_multiplier = _calculate_critical_multiplier(attacker, defender, battle, crit_chance)

	var damage
	if not skip_txt:
		if type_multiplier < 1:
			battle.add_text("It's not very effective...") 
		elif type_multiplier > 1:
			battle.add_text("It's super effective!")

		var ignore_stats=defender.has_ability("unaware")
		attacker.calculate_stats_effective(ignore_stats)
		defender.calculate_stats_effective(ignore_stats)

		var a_stat = gs.ATK if move_data.category == gs.PHYSICAL else gs.SP_ATK
		var d_stat = gs.DEF if move_data.category == gs.PHYSICAL else gs.SP_DEF
		var atk_ig
		var def_ig
		if critical_multiplier == 1:
			atk_ig = attacker.stats_effective[a_stat]
			def_ig = defender.stats_effective[d_stat]
		else:
			def_ig = min(defender.stats_actual[d_stat], defender.stats_effective[d_stat])
			atk_ig = max(attacker.stats_actual[a_stat], attacker.stats_effective[a_stat])

		var attack_defense_ratio = float(atk_ig) / def_ig
		var burn_multiplier = 0.5 if attacker.nv_status == gs.BURNED and move_data.category == gs.PHYSICAL and not attacker.has_ability("guts") else 1

		if attacker.charged and move_data.type == "electric":
			move_data.power *= 2

		if move_data.type == "electric" and (attacker.mud_sport or defender.mud_sport):
			move_data.power /= 2

		if move_data.type == "fire" and (attacker.water_sport or defender.water_sport):
			move_data.power /= 2

		if defender.has_ability("thick-fat") and (move_data.type == "fire" or move_data.type == "ice"):
			move_data.power /= 2

		pa.damage_calc_abilities(attacker, defender, battle, move_data, type_multiplier)
		#pi.damage_calc_items(attacker, defender, battle, move_data)TODO descomentar

		var screen_multiplier = 0.5 if (type_multiplier <= 1 and ((move_data.category == gs.PHYSICAL and defender.trainer.reflect) or (move_data.category == gs.SPECIAL and defender.trainer.light_screen))) else 1
		var weather_multiplier = 1

		if battlefield.weather == gs.HARSH_SUNLIGHT:
			if move_data.type == "fire":
				weather_multiplier = 1.5
			elif move_data.type == "water":
				weather_multiplier = 0.5
		elif battlefield.weather == gs.RAIN:
			if move_data.type == "fire":
				weather_multiplier = 0.5
			elif move_data.type == "water":
				weather_multiplier = 1.5

		var stab = 1.5 if move_data.type == attacker.types[0] or move_data.type == attacker.types[1] and not attacker.has_ability("adaptability") else 2 if move_data.type == attacker.types[0] or move_data.type == attacker.types[1] else 1

		var random_multiplier = _calculate_random_multiplier_damage()

		var berry_multiplier = pi.pre_hit_berries(attacker, defender, battle, move_data, type_multiplier)
		var item_multiplier = pi.damage_mult_items(attacker, defender, battle, move_data, type_multiplier)

		damage = ((0.4 * attacker.level + 2) * move_data.power * attack_defense_ratio) / 50 * burn_multiplier * screen_multiplier * weather_multiplier + 2
		damage *= critical_multiplier * item_multiplier * random_multiplier * stab * type_multiplier * berry_multiplier
		damage = int(damage)

	else:
		critical_multiplier = _calculate_critical_multiplier(attacker, defender, battle, crit_chance)
		damage = fix_damage

		if skip_dmg:
			return damage

	var damage_done = defender.take_damage(damage, move_data)
	if not skip_fc:
		battle._faint_check()
	if critical_multiplier > 1 and defender.is_alive and defender.has_ability("anger-point") and defender.stat_stages[gs.ATK] < 6:
		battle.add_text(defender.nickname + " maxed its Attack!")
		defender.stat_stages[gs.ATK] = 6
	
	pi.post_damage_items(attacker, battle, damage_done)
	return damage_done

static func _calculate_hit_or_miss(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield:Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
) -> bool:
	var defender_evasion_stage = defender.evasion_stage
	var attacker_accuracy_stage = attacker.accuracy_stage
	
	# Verifica si la defensa tiene algún efecto que altere la evasión
	if defender.foresight_target or defender.me_target:
		if defender.evasion_stage > 0:
			defender_evasion_stage = 0
	
	# Ajusta el escenario de evasión y precisión basado en habilidades
	if attacker.has_ability("unaware"):
		defender_evasion_stage = 0
	if defender.has_ability("unaware"):
		attacker_accuracy_stage = 0
	if move_data.name == "stomp" and defender.minimized:
		defender_evasion_stage = 0
	var stage = attacker_accuracy_stage - defender_evasion_stage
	var stage_mult = max(3, 3 + stage) / max(3, 3 - stage)
	var ability_mult = pa.calculate_precision_modifier_abilities(attacker, defender, battlefield, battle, move_data)
	var item_mult = pi.homc_items(attacker, defender, battlefield, battle, move_data, is_first)
	
	var move_accuracy = move_data.acc
	if _special_move_acc(attacker, defender, battlefield, battle, move_data):
		return true

	if not move_accuracy:
		return true

	if defender.mr_count and defender.mr_target and attacker == defender.mr_target:
		return true

	if attacker.has_ability("no-guard") or defender.has_ability("no-guard"):
		return true

	if attacker.next_will_hit:
		attacker.next_will_hit = false
		return true

	var precision_result = get_move_precision()
	var result_hit
	if move_accuracy == -1:
		result_hit = precision_result <= attacker.level - defender.level + 30
	else:
		var hit_threshold = (move_accuracy * stage_mult * battlefield.acc_modifier * item_mult * ability_mult)
		result_hit = precision_result <= hit_threshold

	if not result_hit:
		if defender.evasion_stage > 0:
			_avoided(battle, defender)
		else:
			_missed(attacker, battle)

	return result_hit

	
	
static func _meta_effect_check(attacker: Pokemon, defender: Pokemon, battlefield: Battlefield, battle: Battle, move_data: Move, is_first: bool) -> bool:
	if _magic_coat_check(attacker, defender, battlefield, battle, move_data, is_first):
		return true
	if _snatch_check(attacker, defender, battlefield, battle, move_data, is_first):
		return true
	if _protect_check(defender, battle, move_data):
		return true
	if _soundproof_check(defender, battle, move_data):
		return true
	if _grounded_check(attacker, battle, move_data):
		return true
	if _truant_check(attacker, battle, move_data):
		return true
	_normalize_check(attacker, move_data)
	_extra_flinch_check(attacker, defender, battle, move_data, is_first)
	return false

static func _process_effect(attacker: Pokemon, defender: Pokemon, battlefield: Battlefield, battle: Battle, move_data: Move, is_first: bool) -> void:
	pa.pre_move_abilities(attacker, defender, battle, move_data)
	var ef_id = move_data.ef_id
	var crit_chance = 0
	var inv_bypass = false
	var cc_ib = [crit_chance, inv_bypass]
	
	_MOVE_EFFECTS[ef_id].call(attacker, defender, battlefield, battle, move_data, is_first, cc_ib)


static func _calculate_critical_multiplier(
		attacker: Pokemon,
		defender: Pokemon,
		battle: Battle,
		crit_chance: int

) -> int:
	var cc = crit_chance + attacker.crit_stage if crit_chance else attacker.crit_stage
	var critical_multiplier
	if attacker.has_ability("super-luck"):
		cc += 1
	if attacker.item == "scope-lens" or attacker.item == "razor-claw":
		cc += 1
	elif attacker.item == "lucky-punch" and attacker.name == "chansey":
		cc += 2
	if (
			not defender.trainer.lucky_chant
			and not defender.has_ability("battle-armor")
			and not defender.has_ability("shell-armor")
			and _calculate_is_critical(cc)
	):
		critical_multiplier = 2 if not attacker.has_ability("sniper") else 3
		battle.add_text("A critical hit!")
	else:
		critical_multiplier = 1
	return critical_multiplier

static func _calculate_is_critical(crit_chance: int = 0) -> bool:
	if not crit_chance:
		return randi_range(0, 15) < 1
	elif crit_chance == 1:
		return randi_range(0, 8) < 1
	elif crit_chance == 2:
		return randi_range(0, 4) < 1
	elif crit_chance == 3:
		return randi_range(0, 3) < 1
	elif crit_chance == 4:
		return randi_range(0, 2) < 1
	else:
		return randi_range(0, 999) < crit_chance

static func _invulnerability_check(attacker: Pokemon, defender: Pokemon, battlefield: Battlefield, battle: Battle, move_data: Move) -> bool:
	if attacker.has_ability("no-guard") or defender.has_ability("no-guard"):
		return false
	if defender.invulnerable:
		if defender.in_air:
			if move_data.name == "gust":
				return false
		elif defender.in_ground:
			if move_data.name == "earthquake":
				return false
		elif defender.in_water:
			if move_data.name in ["surf", "whirlpool", "low-kick"]:
				return false
		_avoided(battle, defender)
		return true
	return false

static func _pre_process_status(attacker: Pokemon, defender: Pokemon, battlefield: Battlefield, battle: Battle, move_data: Move) -> bool:
	_mold_breaker_check(attacker, defender, false)
	
	if attacker.invulnerability_count > 0:
		attacker.invulnerability_count -= 1
		if attacker.invulnerability_count == 0:
			attacker.invulnerable = false
			attacker.in_ground = false
			attacker.in_air = false
			attacker.in_water = false

	if attacker.prio_boost:
		attacker.prio_boost = false

	if attacker.nv_status == gs.FROZEN:
		if move_data.name in gd.FREEZE_CHECK or randi_range(0, 4) < 1:
			cure_nv_status(gs.FROZEN, attacker, battle)
		else:
			battle.add_text(attacker.nickname + " is frozen solid!")
			return true

	if attacker.nv_status == gs.ASLEEP:
		if attacker.nv_counter == 0:
			attacker.nv_status = 0
		else:
			attacker.nv_counter -= 1
			if attacker.has_ability("early-bird"):
				attacker.nv_counter -= 1
			if attacker.nv_counter > 0:
				battle.add_text(attacker.nickname + " is fast asleep!")
				if move_data.name != "snore" and move_data.name != "sleep-talk":
					return true
		battle.add_text(attacker.nickname + " woke up!")

	if attacker.v_status[gs.FLINCHED] > 0:
		attacker.v_status[gs.FLINCHED] = 0
		battle.add_text(attacker.nickname + " flinched and couldn't move")
		if attacker.has_ability("steadfast"):
			give_stat_change(attacker, battle, gs.ATK, 1)
		return true

	if attacker.nv_status == gs.PARALYZED:
		if randi_range(0, 3) < 1:
			battle.add_text(attacker.nickname + " is paralyzed! It can't move!")
			return true

	if attacker.infatuation:
		if attacker.infatuation != defender:
			attacker.infatuation = null
			battle.add_text(attacker.nickname + " got over its infatuation!")
		elif randi_range(0, 1) < 1:
			battle.add_text(attacker.nickname + " is immobilized by love!")
			return true

	if attacker.v_status[gs.CONFUSED] > 0:
		attacker.v_status[gs.CONFUSED] -= 1
		if attacker.v_status[gs.CONFUSED] > 0:
			battle.add_text(attacker.nickname + " is confused!")
			if randi_range(0, 1) < 1:
				battle.add_text("It hurt itself in its confusion!")
				var self_attack = Move.new().set_move_data([0, "self-attack", 1, "typeless", 40, 1, 999, 0, 10, 2, 1, "", "", ""])
				var crit_chance = 0
				_calculate_damage(attacker, attacker, battlefield, battle, self_attack, crit_chance)
				return true
		else:
			battle.add_text(attacker.nickname + " snapped out of its confusion!")
	return false

static func _post_process_status(attacker: Pokemon, defender: Pokemon, battlefield: Battlefield, battle: Battle, move_data: Move) -> void:
	_mold_breaker_check(attacker, defender)

static func _generate_2_to_5() -> int:
	var n = randi_range(0, 7)
	if n < 3:
		return 2
	elif n < 6:
		return 3
	elif n < 7:
		return 4
	else:
		return 5

static func get_move_precision() -> int:
	return randi_range(1, 101)

static func confuse(recipient: Pokemon, battle: Battle, forced: bool = false, bypass: bool = false) -> void:
	if not recipient.is_alive or recipient.substitute or recipient.has_ability("own-tempo"):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if not forced and not bypass and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.v_status[gs.CONFUSED] > 0:
		battle.add_text(recipient.nickname + " is already confused!")
		return
	recipient.v_status[gs.CONFUSED] = _generate_2_to_5()
	battle.add_text(recipient.nickname + " became confused!")
	pi.status_items(recipient, battle)

static func _flinch(recipient: Pokemon, battle: Battle, is_first: bool, forced: bool = false) -> void:
	if not recipient.is_alive or recipient.substitute or recipient.has_ability("shield-dust"):
		return
	if is_first and recipient.is_alive and recipient.v_status[gs.FLINCHED] == 0:
		if not recipient.has_ability("inner-focus"):
			recipient.v_status[gs.FLINCHED] = 1
		elif forced:
			battle.add_text(recipient.nickname + " won't flinch because of its Inner Focus!")

static func infatuate(attacker: Pokemon, defender: Pokemon, battle: Battle, forced: bool = false) -> void:
	if not defender.is_alive or defender.infatuation or defender.has_ability("oblivious"):
		if forced:
			_failed(battle)
		return
	if (attacker.gender == "male" and defender.gender == "female") or (attacker.gender == "female" and defender.gender == "male"):
		defender.infatuation = attacker
		battle.add_text(defender.nickname + " fell in love with " + attacker.nickname + "!")
		pi.status_items(defender, battle)

static func give_stat_change(
	recipient: Pokemon,
	battle: Battle,
	stat: int,
	amount: int,
	forced: bool = false,
	bypass: bool = false
):
	if not recipient.is_alive:
		if forced:
			_failed(battle)
		return
	if (
		amount < 0
		and not bypass
		and (
			recipient.substitute
			or recipient.has_ability("clear-body")
			or recipient.has_ability("white-smoke")
		)
	):
		if forced:
			_failed(battle)
		return
	if (
		amount < 0
		and not forced
		and not bypass
		and recipient.has_ability("shield-dust")
	):
		return
	if recipient.has_ability("simple"):
		amount *= 2
	var r_stat = 0
	if stat == 6:
		r_stat = recipient.accuracy_stage
		if amount < 0 and recipient.has_ability("keen-eye"):
			if forced:
				_failed(battle)
			return
		recipient.accuracy_stage = _fit_stat_bounds(recipient.accuracy_stage + amount)
	elif stat == 7:
		r_stat = recipient.evasion_stage
		recipient.evasion_stage = _fit_stat_bounds(recipient.evasion_stage + amount)
	else:
		r_stat = recipient.stat_stages[stat]
		if stat == gs.ATK and amount < 0 and recipient.has_ability("hyper-cutter"):
			if forced:
				_failed(battle)
			return
		recipient.stat_stages[stat] = _fit_stat_bounds(
			recipient.stat_stages[stat] + amount
		)
	if r_stat <= 6 and r_stat >= -6 or forced:
		battle.add_text(_stat_text(recipient, stat, amount))
	return

static func _fit_stat_bounds(stage: int) -> int:
	if stage >= 0:
		return min(6, stage)
	else:
		return max(-6, stage)

static func _stat_text(recipient: Pokemon, stat: int, amount: int) -> String:
	var cur_stage = 0
	if stat == gs.ACC:
		cur_stage = recipient.accuracy_stage
	elif stat == gs.EVA:
		cur_stage = recipient.evasion_stage
	else:
		cur_stage = recipient.stat_stages[stat]
	var base = recipient.nickname + "'s " + gs.STAT_TO_NAME[stat]
	if amount == 0:
		return ""
	if amount > 0:
		var dif = min(6 - cur_stage, amount)
		if dif <= 0:
			base += " won't go any higher!"
		elif dif == 1:
			base += " rose!"
		elif dif == 2:
			base += " rose sharply!"
		else:
			base += " rose drastically!"
	else:
		var dif = max(-6 - cur_stage, amount)
		if dif >= 0:
			base += " won't go any lower!"
		elif dif == -1:
			base += " fell!"
		elif dif == -2:
			base += " fell harshly!"
		else:
			base += " fell severely!"
	return base

static func give_nv_status(
	status: int, recipient: Pokemon, battle: Battle, forced: bool = false
):
	if status == gs.BURNED:
		burn(recipient, battle, forced)
	elif status == gs.FROZEN:
		freeze(recipient, battle, forced)
	elif status == gs.PARALYZED:
		paralyze(recipient, battle, forced)
	elif status == gs.POISONED:
		poison(recipient, battle, forced)
	elif status == gs.ASLEEP:
		sleep(recipient, battle, forced)
	elif status == gs.BADLY_POISONED:
		badly_poison(recipient, battle, forced)

static func burn(recipient: Pokemon, battle: Battle, forced: bool = false):
	if (
		not recipient.is_alive
		or recipient.substitute
		or recipient.has_ability("water-veil")
		or (
			recipient.has_ability("leaf-guard")
			and battle.battlefield.weather == gs.HARSH_SUNLIGHT
		)
	):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if "fire" in recipient.types:
		if forced:
			_failed(battle)
		return
	if not forced and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.nv_status == gs.BURNED:
		battle.add_text(recipient.nickname + " is already burned!")
	elif not recipient.nv_status:
		recipient.nv_status = gs.BURNED
		recipient.nv_counter = 0
		battle.add_text(recipient.nickname + " was burned!")
		if recipient.has_ability("synchronize"):
			burn(recipient.enemy.current_poke, battle)
		pi.status_items(recipient, battle)

static func freeze(recipient: Pokemon, battle: Battle, forced: bool = false):
	if (
		not recipient.is_alive
		or recipient.substitute
		or recipient.has_ability("magma-armor")
		or (
			recipient.has_ability("leaf-guard")
			and battle.battlefield.weather == gs.HARSH_SUNLIGHT
		)
	):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if "ice" in recipient.types:
		if forced:
			_failed(battle)
		return
	if not forced and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.nv_status == gs.FROZEN:
		battle.add_text(recipient.nickname + " is already frozen!")
	elif not recipient.nv_status:
		recipient.nv_status = gs.FROZEN
		recipient.nv_counter = 0
		battle.add_text(recipient.nickname + " was frozen solid!")
		if recipient.has_ability("synchronize"):
			freeze(recipient.enemy.current_poke, battle)
		pi.status_items(recipient, battle)

static func paralyze(recipient: Pokemon, battle: Battle, forced: bool = false):
	if (
		not recipient.is_alive
		or recipient.substitute
		or recipient.has_ability("limber")
		or (
			recipient.has_ability("leaf-guard")
			and battle.battlefield.weather == gs.HARSH_SUNLIGHT
		)
	):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if not forced and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.nv_status == gs.PARALYZED:
		battle.add_text(recipient.nickname + " is already paralyzed!")
	elif not recipient.nv_status:
		recipient.nv_status = gs.PARALYZED
		recipient.nv_counter = 0
		battle.add_text(recipient.nickname + " is paralyzed! It may be unable to move!")
		if recipient.has_ability("synchronize"):
			paralyze(recipient.enemy.current_poke, battle)
		pi.status_items(recipient, battle)

static func poison(recipient: Pokemon, battle: Battle, forced: bool = false):
	if (
		not recipient.is_alive
		or recipient.substitute
		or recipient.has_ability("immunity")
		or (
			recipient.has_ability("leaf-guard")
			and battle.battlefield.weather == gs.HARSH_SUNLIGHT
		)
	):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if not forced and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.nv_status == gs.POISONED:
		battle.add_text(recipient.nickname + " is already poisoned!")
	elif not recipient.nv_status:
		recipient.nv_status = gs.POISONED
		recipient.nv_counter = 0
		battle.add_text(recipient.nickname + " was poisoned!")
		if recipient.has_ability("synchronize"):
			poison(recipient.enemy.current_poke, battle)
		pi.status_items(recipient, battle)

static func sleep(recipient: Pokemon, battle: Battle, forced: bool = false):
	if (
		not recipient.is_alive
		or recipient.substitute
		or recipient.has_ability("insomnia")
		or recipient.has_ability("vital-spirit")
		or (
			recipient.has_ability("leaf-guard")
			and battle.battlefield.weather == gs.HARSH_SUNLIGHT
		)
	):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if not forced and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.nv_status == gs.ASLEEP:
		battle.add_text(recipient.nickname + " is already asleep!")
	elif not recipient.nv_status:
		recipient.nv_status = gs.ASLEEP
		recipient.nv_counter = randi() % 4 + 2
		battle.add_text(recipient.nickname + " fell asleep!")
		if recipient.has_ability("synchronize"):
			sleep(recipient.enemy.current_poke, battle)
		pi.status_items(recipient, battle)

static func badly_poison(recipient: Pokemon, battle: Battle, forced: bool = false):
	if (
		not recipient.is_alive
		or recipient.substitute
		or recipient.has_ability("immunity")
		or (
			recipient.has_ability("leaf-guard")
			and battle.battlefield.weather == gs.HARSH_SUNLIGHT
		)
	):
		if forced:
			_failed(battle)
		return
	if _safeguard_check(recipient, battle):
		return
	if not forced and recipient.has_ability("shield-dust"):
		return
	if forced and recipient.nv_status == gs.BADLY_POISONED:
		battle.add_text(recipient.nickname + " is already badly poisoned!")
	elif not recipient.nv_status:
		recipient.nv_status = gs.BADLY_POISONED
		recipient.nv_counter = 1
		battle.add_text(recipient.nickname + " was badly poisoned!")
		if recipient.has_ability("synchronize"):
			poison(recipient.enemy.current_poke, battle)
		pi.status_items(recipient, battle)

static func cure_nv_status(status: int, recipient: Pokemon, battle: Battle,):
	if not recipient.is_alive or not status:
		return
	if recipient.nv_status != status and not (
		status == gs.POISONED and recipient.nv_status == gs.BADLY_POISONED
	):
		return
	var text = ""
	if recipient == recipient.trainer.current_poke:
		if status == gs.BURNED:
			text = "'s burn was healed!"
		elif status == gs.FROZEN:
			text = " thawed out!"
		elif status == gs.PARALYZED:
			text = " was cured of paralysis!"
		elif status == gs.ASLEEP:
			text = " woke up!"
		else:
			text = " was cured of poison!"
		battle.add_text(recipient.nickname + text)

	recipient.nv_status = 0
	recipient.nv_counter = 0

static func cure_confusion(recipient: Pokemon, battle: Battle,):
	if recipient.is_alive and recipient.v_status[gs.CONFUSED]:
		recipient.v_status[gs.CONFUSED] = 0
		battle.add_text(recipient.nickname + " snapped out of its confusion!")

static func cure_infatuation(recipient: Pokemon, battle: Battle,):
	if recipient.is_alive and recipient.infatuation:
		recipient.infatuation = null
		battle.add_text(recipient.nickname + " got over its infatuation!")

static func _magic_coat_check(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool
) -> bool:
	if (
		defender.is_alive
		and defender.magic_coat
		and move_data.name in gd.MAGIC_COAT_CHECK
	):
		battle.add_text(
			attacker.nickname
			+ "'s "
			+ move_data.name
			+ " was bounced back by Magic Coat!"
		)
		_process_effect(defender, attacker, battlefield, battle, move_data, is_first)
		return true
	return false

static func _snatch_check(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool
) -> bool:
	if defender.is_alive and defender.snatch and move_data.name in gd.SNATCH_CHECK:
		battle.add_text(
			defender.nickname + " snatched " + attacker.nickname + "'s move!"
		)
		_process_effect(defender, attacker, battlefield, battle, move_data, is_first)
		return true
	return false

static func _protect_check(defender: Pokemon, battle: Battle, move_data: Move) -> bool:
	if (
		defender.is_alive
		and defender.protect
		and move_data.name not in ["feint", "shadow-force"]
		and move_data.target in gd.PROTECT_TARGETS
	):
		battle.add_text(defender.nickname + " protected itself!")
		return true
	return false

static func _soundproof_check(defender: Pokemon, battle: Battle, move_data: Move) -> bool:
	if (
		defender.is_alive
		and defender.has_ability("soundproof")
		and move_data in gd.SOUNDPROOF_CHECK
	):
		_not_affected(battle, defender)
		return true
	return false

static func _grounded_check(attacker: Pokemon, battle: Battle, move_data: Move) -> bool:
	if attacker.grounded and move_data.name in gd.GROUNDED_CHECK:
		_failed(battle)
		return true
	return false

static func _truant_check(attacker: Pokemon, battle: Battle, move_data: Move) -> bool:
	if (
		attacker.has_ability("truant")
		and attacker.last_move
		and move_data.name == attacker.last_move.name
	):
		battle.add_text(attacker.nickname + " loafed around!")
		return true
	return false

static func _normalize_check(attacker: Pokemon, move_data: Move):
	if attacker.has_ability("normalize"):
		move_data.type = "normal"

static func _extra_flinch_check(
	attacker: Pokemon, defender: Pokemon, battle: Battle, move_data: Move, is_first: bool
):
	if attacker.item == "king's-rock" or attacker.item == "razor-fang":
		if (
			move_data in gd.EXTRA_FLINCH_CHECK
			and not defender.v_status[gs.FLINCHED]
			and is_first
			and randi() % 10 < 1
		):
			_flinch(defender, battle, is_first)

static func _mold_breaker_check(
	attacker: Pokemon, defender: Pokemon, end_turn: bool = true
):
	if not attacker.has_ability("mold-breaker"):
		return
	if not end_turn and not defender.ability_suppressed:
		defender.ability_suppressed = true
		attacker.ability_count = 1
	elif end_turn and attacker.ability_count:
		defender.ability_suppressed = false
		attacker.ability_count = 0

static func _power_herb_check(attacker: Pokemon, battle: Battle,) -> bool:
	if attacker.item == "power-herb":
		battle.add_text(
			attacker.nickname + " became fully charged due to its Power Herb!"
		)
		attacker.give_item("")#TODO posible error item vacio
		return true
	return false

static func _special_move_acc(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move
) -> bool:
	if move_data.name == "thunder":
		if battlefield.weather == gs.RAIN and not defender.in_ground:
			return true
		if battlefield.weather == gs.HARSH_SUNLIGHT:
			move_data.acc = 50
	return false

static func _recoil(attacker: Pokemon, battle: Battle, damage: int, move_data: Move):
	if not attacker.is_alive or not damage:
		return
	if attacker.has_ability("rock-head") and move_data.name in gd.RECOIL_CHECK:
		return
	attacker.take_damage(damage)
	battle.add_text(attacker.nickname + " is hit with recoil!")

static func cap_name(move_name: String) -> String:
	move_name = move_name.replace("-", " ")
	var words = move_name.split(" ")
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)

static func _failed(battle: Battle):
	battle.add_text("But, it failed!")

static func _missed(attacker: Pokemon, battle: Battle,):
	battle.add_text(attacker.nickname + "'s attack missed!")


static func _avoided(battle: Battle, defender: Pokemon):
	battle.add_text(defender.nickname + " avoided the attack!")

static func _not_affected(battle: Battle, defender: Pokemon):
	battle.add_text("It doesn't affect " + defender.nickname)

static func _safeguard_check(poke: Pokemon, battle: Battle,) -> bool:
	if poke.trainer.safeguard:
		battle.add_text(poke.nickname + " is protected by Safeguard!")
		return true
	return false

static func _ef_000(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return true#posible error

static func _ef_001(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return true

static func _ef_002(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if attacker.is_alive and dmg and randi() % 100 < move_data.ef_chance:
		var bypass=true
		give_stat_change(
			attacker, battle, move_data.ef_stat, move_data.ef_amount, bypass
		)
	return true

static func _ef_003(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and randi() % 100 < move_data.ef_chance:
		give_stat_change(defender, battle, move_data.ef_stat, move_data.ef_amount)
	return true

static func _ef_004(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if attacker.is_alive and dmg and randi() % 100 < move_data.ef_chance:
		give_nv_status(move_data.ef_stat, attacker, battle)
	return true

static func _ef_005(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and randi() % 100 < move_data.ef_chance:
		give_nv_status(move_data.ef_stat, defender, battle)
	return true

static func _ef_006(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and randi() % 100 < move_data.ef_chance:
		confuse(defender, battle)
	return true

static func _ef_007(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and randi() % 100 < move_data.ef_chance:
		_flinch(defender, battle, is_first)
	return true

static func _ef_008(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	cc_ib[0] = 1
	return false  # Añadir un valor de retorno para cumplir con el tipo de retorno bool


static func _ef_009(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.has_moved:
		_failed(battle)
		return true
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg:
		var forced=true
		_flinch(defender, battle, is_first, forced)
	return true

static func _ef_010(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_missed(attacker, battle)
	var num_hits = 5 if attacker.has_ability("skill-link") else _generate_2_to_5()
	var nh = num_hits
	var skip_fc=true
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data, skip_fc)
	nh -= 1 if dmg else 0
	while nh and defender.is_alive:
		skip_fc=true
		var skip_txt=true
		_calculate_damage(
			attacker, defender, battlefield, battle, move_data, skip_fc, skip_txt
		)
		nh -= 1
	battle.add_text("Hit %d time(s)!" % num_hits)
	return true

static func _ef_011(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var skip_fc=true
	var dmg = _calculate_damage(
		attacker, defender, battlefield, battle, move_data, skip_fc
	)
	if not dmg:
		return true
	elif defender.is_alive:
		skip_fc=true
		var skip_txt=true
		_calculate_damage(
			attacker, defender, battlefield, battle, move_data, skip_fc, skip_txt
		)
	else:
		battle.add_text("Hit 1 time(s)!")
		return true
	battle.add_text("Hit 2 time(s)!")
	return true

static func _ef_013(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	give_nv_status(move_data.ef_stat, defender, battle, true)
	return true

static func _ef_014(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	confuse(defender, battle, true)
	return true

static func _ef_016(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	give_stat_change(attacker, battle, move_data.ef_stat, move_data.ef_amount)
	return false

static func _ef_017(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and defender.trainer.mist:
		battle.add_text(defender.nickname + "'s protected by mist.")
		return true
	give_stat_change(defender, battle, move_data.ef_stat, move_data.ef_amount)
	return false

static func _ef_018(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.in_water:
		move_data.power *= 2
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return false

static func _ef_019(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.minimized:
		move_data.power *= 2
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randi() % 10 < 3:
		_flinch(defender, battle, is_first)
	return false

static func _ef_020(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_missed(attacker, battle)
	if defender.has_ability("sturdy"):
		battle.add_text(defender.nickname + " endured the hit!")
		return true
	if _calculate_type_ef(defender, move_data) != 0:
		defender.take_damage(65535, move_data)
		if not defender.is_alive:
			battle.add_text("It's a one-hit KO!")
	else:
		_not_affected(battle, defender)
	return true

static func _ef_021(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> Variant:#posible error
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		attacker.next_moves.push_back(move_data)
		battle.add_text(attacker.nickname + " whipped up a whirlwind!")
	else:
		cc_ib[0] = 1
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return null


static func _ef_022(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.in_air:
		move_data.power *= 2
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return false


static func _ef_023_fly(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		attacker.next_moves.push_back(move_data)
		attacker.in_air = true
		attacker.invulnerable = true
		attacker.invulnerability_count = 1
		battle._pop_text()
		battle.add_text(attacker.nickname + " flew up high!")
		return true
	else:
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		return false


static func _ef_024(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if move_data.name == "whirlpool" and defender.in_water:
		move_data.power *= 2
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and not defender.substitute and not defender.v_status[gs.BINDING_COUNT]:
		defender.v_status[gs.BINDING_COUNT] = 5 if attacker.item == "grip-claw" else _generate_2_to_5()
		defender.binding_poke = attacker
		match move_data.ef_stat:
			gs.BIND:
				defender.binding_type = "Bind"
				battle.add_text(defender.nickname + " was squeezed by " + attacker.nickname + "!")
			gs.WRAP:
				defender.binding_type = "Wrap"
				battle.add_text(defender.nickname + " was wrapped by " + attacker.nickname + "!")
			gs.FIRE_SPIN:
				defender.binding_type = "Fire Spin"
				battle.add_text(defender.nickname + " was trapped in the vortex!")
			gs.CLAMP:
				defender.binding_type = "Clamp"
				battle.add_text(attacker.nickname + " clamped " + defender.nickname + "!")
			gs.WHIRLPOOL:
				defender.binding_type = "Whirlpool"
				battle.add_text(defender.nickname + " was trapped in the vortex!")
			gs.SAND_TOMB:
				defender.binding_type = "Sand Tomb"
				battle.add_text(defender.nickname + " was trapped by Sand Tomb!")
			gs.MAGMA_STORM:
				defender.binding_type = "Magma Storm"
				battle.add_text(defender.nickname + " became trapped by swirling magma!")
	return true


static func _ef_025(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		return true
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		dmg /= 2
	elif dmg == 0 and attacker.enemy and _calculate_type_ef(defender, move_data) == 0:
		dmg = defender.max_hp / 2
	if not dmg:
		return true
	battle.add_text(attacker.nickname + " kept going and crashed!")
	attacker.take_damage(dmg)
	return true


static func _ef_026(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.in_ground:
		move_data.power *= 2
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return false


static func _ef_027(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		_recoil(attacker, battle, max(1, dmg / 4), move_data)
	return true


static func _ef_028(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not move_data.ef_stat:
		var num_turns = randi_range(1, 2)
		move_data.ef_stat = num_turns
		attacker.next_moves.push_back(move_data)
	else:
		move_data.ef_stat -= 1
		if move_data.ef_stat == 0:
			var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
			if dmg:
				confuse(attacker, battle, true)
			return true
		else:
			attacker.next_moves.push_back(move_data)
	return false


static func _ef_029(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		_recoil(attacker, battle, max(1, dmg / 3), move_data)
	return true


static func _ef_030(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if not defender.is_alive or not dmg:
		return true
	if randi_range(1, 5) < 2:
		poison(defender, battle)
	dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randi_range(1, 5) < 2:
		poison(defender, battle)
	return true


static func _ef_031(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and _calculate_type_ef(defender, move_data) != 0:
		defender.take_damage(move_data.ef_amount, move_data)
	else:
		_missed(attacker, battle)
	return true


static func _ef_032(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var has_disabled = true
	for move in defender.moves:
		if not move.disabled:
			has_disabled = false
			break
	
	if not defender.last_move or not defender.last_move.cur_pp or has_disabled:
		_failed(battle)
	else:
		var disabled_move = defender.last_move
		disabled_move.disabled = randi_range(4, 7)
		battle.add_text(
			defender.trainer.name
			+ "'s "
			+ defender.nickname
			+ "'s "
			+ disabled_move.name
			+ " was disabled!"
		)
	return false


static func _ef_033(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not attacker.trainer.mist:
		battle.add_text(attacker.trainer.name + "'s team became shrouded in mist!")
		attacker.trainer.mist = 5
	else:
		_failed(battle)
	return false


static func _ef_034(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	attacker.recharging = true
	return false


static func _ef_035(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.weight < 100:
		move_data.power = 20
	elif defender.weight < 250:
		move_data.power = 40
	elif defender.weight < 500:
		move_data.power = 60
	elif defender.weight < 1000:
		move_data.power = 80
	elif defender.weight < 2000:
		move_data.power = 100
	else:
		move_data.power = 120
	return false

static func _ef_036(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and attacker.last_move_hit_by
		and defender.last_move
		and attacker.last_move_hit_by.name == defender.last_move.name
		and attacker.last_move_hit_by.category == gs.PHYSICAL
		and _calculate_type_ef(defender, move_data)
	):
		defender.take_damage(attacker.last_damage_taken * 2, move_data)
	else:
		_failed(battle)
	return true


static func _ef_037(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return true


static func _ef_038(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		var heal_amt = max(1, dmg / 2)
		if attacker.item == "big-root":
			heal_amt = int(heal_amt * 1.3)
		if not defender.has_ability("liquid-ooze"):
			if attacker.heal_block_count == 0:
				var text_skip=true
				attacker.heal(heal_amt, text_skip)
				battle.add_text(defender.nickname + " had its energy drained!")
		else:
			attacker.take_damage(heal_amt)
			battle.add_text(attacker.nickname + " sucked up the liquid ooze!")
	return true


static func _ef_039(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and not defender.substitute
		and not defender.v_status[gs.LEECH_SEED]
	):
		defender.v_status[gs.LEECH_SEED] = 1
		battle.add_text(defender.nickname + " was seeded!")
	return false


static func _ef_040(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		not move_data.ef_stat
		and battlefield.weather != gs.HARSH_SUNLIGHT
		and not _power_herb_check(attacker, battle)
	):
		battle._pop_text()
		battle.add_text(attacker.nickname + " absorbed light!")
		move_data.ef_stat = 1
		attacker.next_moves.push_back(move_data)
		return true
	if battlefield.weather != gs.HARSH_SUNLIGHT and battlefield.weather != gs.CLEAR:
		move_data.power /= 2
	return false


static func _ef_041_thunder(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randi_range(1,10) < 3:
		paralyze(defender, battle)
	return false


static func _ef_042_dig(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		attacker.next_moves.push_back(move_data)
		attacker.in_ground = true
		attacker.invulnerable = true
		attacker.invulnerability_count = 1
		battle._pop_text()
		battle.add_text(attacker.nickname + " burrowed its way under the ground!")
		return true
	else:
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		return false


static func _ef_043(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not attacker.rage:
		attacker.rage = true
		for move in attacker.moves:
			if move.name != "rage":
				move.disabled = true
	return false


static func _ef_044(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and defender.last_move
		and not attacker.copied
		and not attacker.is_move(defender.last_move.md)
	):
		attacker.copied = Move.new().set_move_data(defender.last_move.md)
		attacker.copied.max_pp = min(5, attacker.copied.max_pp)
		attacker.copied.cur_pp = attacker.copied.max_pp
		battle.add_text(
			attacker.nickname + " learned " + cap_name(attacker.copied.name)
		)
	else:
		_failed(battle)
	return false


static func _ef_046(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	attacker.heal(attacker.max_hp / 2)
	return false


static func _ef_047(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	attacker.minimized = true
	give_stat_change(attacker, battle, gs.EVA, 1)
	return false


static func _ef_048(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	attacker.df_curl = true
	give_stat_change(attacker, battle, gs.DEF, 1)
	return false


static func _ef_049(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var t = attacker.trainer
	var num_turns = 5 if attacker.item != "light-clay" else 8
	if move_data.ef_stat == 1:
		if t.light_screen:
			_failed(battle)
			return true
		t.light_screen = num_turns
		battle.add_text("Light Screen raised " + t.name + "'s team's Special Defense!")
	elif move_data.ef_stat == 2:
		if t.reflect:
			_failed(battle)
			return true
		t.reflect = num_turns
		battle.add_text("Reflect raised " + t.name + "'s team's Defense!")
	return false

static func _ef_050(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	attacker.reset_stages()
	defender.reset_stages()
	battle.add_text("All stat changes were eliminated!")
	return false


static func _ef_051(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	attacker.crit_stage += 2
	if attacker.crit_stage > 4:
		attacker.crit_stage = 4
	battle.add_text(attacker.nickname + " is getting pumped!")
	return false


static func _ef_052(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not move_data.ef_stat:
		attacker.trapped = true
		move_data.ef_stat = 1
		attacker.bide_count = 2 if is_first else 3
		attacker.next_moves.push_back(move_data)
		attacker.bide_dmg = 0
		battle.add_text(attacker.nickname + " is storing energy!")
	else:
		battle._pop_text()
		battle.add_text(attacker.nickname + " unleashed energy!")
		if defender.is_alive:
			defender.take_damage(2 * attacker.bide_dmg, move_data)
		else:
			_missed(attacker, battle)
		attacker.bide_dmg = 0
	return true


static func _ef_053(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var move_names = []
	for move in attacker.moves:
		move_names.append(move.name)
	var rand_move = PokeSim.get_rand_move()
	var attempts = 0
	while (
		attempts < 50
		and (rand_move[gs.MOVE_NAME] in move_names
		or rand_move[gs.MOVE_NAME] in gd.METRONOME_CHECK)
	):
		rand_move = PokeSim.get_rand_move()
		attempts += 1
	rand_move = Move.new().set_move_data(rand_move)
	battle.add_text(attacker.nickname + " used " + cap_name(rand_move.name) + "!")
	_process_effect(attacker, defender, battlefield, battle, rand_move, is_first)
	return true


static func _ef_054(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and defender.last_move:
		battle.add_text(
			attacker.nickname + " used " + cap_name(defender.last_move.name) + "!"
		)
		_process_effect(
			attacker, defender, battlefield, battle, defender.last_move, is_first
		)
	else:
		_failed(battle)
	return true


static func _ef_055(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_failed(battle)
		return true
	if attacker.has_ability("damp") or defender.has_ability("damp"):
		battle.add_text(attacker.nickname + " cannot use Self Destruct!")
		return true
	attacker.faint()
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return true


static func _ef_056(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		battle._pop_text()
		battle.add_text(attacker.nickname + " tucked in its head!")
		give_stat_change(attacker, battle, gs.DEF, 1)
		move_data.ef_stat = 1
		attacker.next_moves.push_back(move_data)
		return true
	return false

static func _ef_057(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_missed(attacker, battle)
	elif defender.nv_status == gs.ASLEEP:
		var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
		if dmg:
			var heal_amt = max(1, dmg / 2)
			if attacker.item == "big-root":
				heal_amt = int(heal_amt * 1.3)
			attacker.heal(heal_amt)
		battle.add_text(defender.nickname + "'s dream was eaten!")
	else:
		_failed(battle)
	return true


static func _ef_058(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		defender.next_moves.push_back(move_data)
		battle._pop_text()
		battle.add_text(attacker.nickname + " became cloaked in harsh light!")
	else:
		var crit_chance=1
		var dmg = _calculate_damage(
			attacker, defender, battlefield, battle, move_data, crit_chance
		)
		if dmg and randi_range(0, 9) < 3:
			_flinch(defender, battle, is_first)
	return true


static func _ef_059(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and not defender.transformed and not attacker.transformed:
		attacker.transform(defender)
		battle.add_text(attacker.nickname + " transformed into " + defender.name + "!")
	else:
		_failed(battle)
	return true


static func _ef_060(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = attacker.level * (randi_range(0, 10) * 10 + 50) / 100
	if defender.is_alive:
		defender.take_damage(dmg if dmg != 0 else 1, move_data)
	else:
		_missed(attacker, battle)
	return true


static func _ef_061(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	battle.add_text("But nothing happened!")
	return true


static func _ef_062(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_failed(battle)
		return true
	if attacker.has_ability("damp") or defender.has_ability("damp"):
		battle.add_text(attacker.nickname + " cannot use Explosion!")
		return true
	attacker.faint()
	var old_def = defender.stats_actual[gs.DEF]
	defender.stats_actual[gs.DEF] /= 2
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	defender.stats_actual[gs.DEF] = old_def
	return true


static func _ef_063(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not attacker.has_ability("insomnia") and not attacker.has_ability(
		"vital-spirit"
	):
		attacker.nv_status = gs.ASLEEP
		attacker.nv_counter = 3
		battle.add_text(attacker.nickname + " went to sleep!")
		attacker.heal(attacker.max_hp)
	else:
		_failed(battle)
	return false


static func _ef_064(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var move_types = []
	for move in attacker.moves:
		if move.type not in attacker.types:
			move_types.append(move.type)
	move_types = PokeSim.filter_valid_types(move_types)
	if move_types.size() == 0:
		_failed(battle)
		return true
	attacker.types = [move_types[randi_range(0, move_types.size() - 1)], null]
	return false


static func _ef_065(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and defender.is_alive and randi_range(1, 100) < move_data.ef_chance:
		give_nv_status(randi_range(1, 3), defender, battle)
	return true

static func _ef_066(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive or _calculate_type_ef(defender, move_data) == 0:
		_failed(battle)
		return true
	else:
		var dmg = defender.max_hp / 2#TODO div entero
		defender.take_damage(dmg if dmg > 0 else 1, move_data)
	return true


static func _ef_067(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.substitute:
		_failed(battle)
		return true
	if attacker.cur_hp - attacker.max_hp / 4 < 0:#TODO div entero
		battle.add_text("But it does not have enough HP left to make a substitute!")
		return true
	attacker.substitute = attacker.take_damage(attacker.max_hp / 4) + 1#TODO div entero
	battle.add_text(attacker.nickname + " made a substitute!")
	return true


static func _ef_068(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	battle._pop_text()
	battle.add_text(attacker.nickname + " has no moves left!")
	battle.add_text(attacker.nickname + " used Struggle!")
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	var struggle_dmg = max(1, attacker.max_hp / 4)#TODO div entero
	_recoil(attacker, battle, struggle_dmg, move_data)
	return true


static func _ef_069(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		attacker.transformed
		or move_data not in attacker.o_moves
		or not defender.is_alive
		or not defender.last_move
		or attacker.is_move(defender.last_move.name)
	):
		_failed(battle)
		return true
	attacker.moves[move_data.pos] = Move.new().set_move_data(defender.last_move.md)
	return true


static func _ef_070(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_missed(attacker, battle)
	var num_hits = 0
	while num_hits < 3 and defender.is_alive:
		var skip_fc=true
		_calculate_damage(
			attacker, defender, battlefield, battle, move_data, skip_fc
		)
		move_data.power += 10
		num_hits += 1
	battle.add_text("Hit" + str(num_hits) + " time(s)!")
	return true


static func _ef_071(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if (
		defender.item
		and dmg
		and not attacker.item
		and not defender.substitute
		and not defender.has_ability("sticky-hold")
		and not defender.has_ability("multitype")
	):
		battle.add_text(
			attacker.nickname
			+ " stole "
			+ defender.nickname
			+ "'s "
			+ cap_name(defender.item)
			+ "!"
		)
		attacker.give_item(defender.item)
		defender.give_item("")#TODO posible error item vacio
	return true


static func _ef_072(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and not defender.invulnerable:
		defender.perma_trapped = true
		battle.add_text(defender.nickname + " can no longer escape!")
	else:
		_failed(battle)
	return true


static func _ef_073(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive:
		attacker.mr_count = 2
		attacker.mr_target = defender
		battle.add_text(attacker.nickname + " took aim at " + defender.nickname + "!")
	else:
		_failed(battle)
	return true


static func _ef_074(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and defender.nv_status == gs.ASLEEP
		and not defender.substitute
	):
		defender.v_status[gs.NIGHTMARE] = 1
		battle.add_text(defender.nickname + " began having a nightmare!")
	else:
		_failed(battle)
	return true


static func _ef_075(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randi_range(1, 100) < move_data.ef_amount:
		burn(defender, battle)
	return true


static func _ef_076(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and attacker.nv_status == gs.ASLEEP:
		var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
		if dmg and randi_range(0, 9) < 3:
			_flinch(defender, battle, is_first)
	else:
		_failed(battle)
	return true


static func _ef_077(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if "ghost" not in attacker.types:
		if (
			attacker.stat_stages[gs.ATK] == 6
			and attacker.stat_stages[gs.DEF] == 6
			and attacker.stat_stages[gs.SPD] == -6
		):
			_failed(battle)
			return true
		if attacker.stat_stages[gs.ATK] < 6:
			give_stat_change(attacker, battle, gs.ATK, 1)
		if attacker.stat_stages[gs.DEF] < 6:
			give_stat_change(attacker, battle, gs.DEF, 1)
		if attacker.stat_stages[gs.SPD] > -6:
			var bypass=true
			give_stat_change(attacker, battle, gs.SPD, -1, bypass)
	else:
		if not defender.is_alive or defender.v_status[gs.CURSE] or defender.substitute:
			_failed(battle)
			return true
		attacker.take_damage(attacker.max_hp / 2)#TODO div entero
		defender.v_status[gs.CURSE] = 1
		battle.add_text(
			attacker.nickname
			+ " cut its own HP and laid a curse on "
			+ defender.nickname
			+ "!"
		)
	return true


static func _ef_078(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var hp_ratio = int((float(attacker.cur_hp) / attacker.max_hp) * 10000)
	if hp_ratio >= 6719:
		move_data.power = 20
	elif hp_ratio >= 3438:
		move_data.power = 40
	elif hp_ratio >= 2031:
		move_data.power = 80
	elif hp_ratio >= 938:
		move_data.power = 100
	elif hp_ratio >= 313:
		move_data.power = 150
	else:
		move_data.power = 200
	return true


static func _ef_079(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not attacker.last_move_hit_by or not PokeSim.is_valid_type(
		attacker.last_move_hit_by.type
	):
		_failed(battle)
		return true

	var last_move_type = attacker.last_move_hit_by.type
	var types = PokeSim.get_all_types()
	var poss_types = []
	for type in types:
		if type and PokeSim.get_type_ef(last_move_type, type) < 1:
			poss_types.append(type)

	# Filtrar tipos válidos que no estén en attacker.types
	var filtered_types = []
	for type in poss_types:
		if type not in attacker.types:
			filtered_types.append(type)
	poss_types = PokeSim.filter_valid_types(filtered_types)

	if poss_types.size() > 0:
		var new_type = poss_types[randi_range(0, poss_types.size() - 1)]
		attacker.types = [new_type, null]
		battle.add_text(
			attacker.nickname + " transformed into the " + new_type.upper() + " type!"
		)
	else:
		_failed(battle)
	return true


static func _ef_080(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and defender.last_move and defender.last_move.cur_pp:
		var amt_reduced = min(4, defender.last_move.cur_pp)
		defender.last_move.cur_pp -= amt_reduced
		battle.add_text(
			"It reduced the pp of " + defender.nickname + "'s " +
			cap_name(defender.last_move.name) + " by " +
			str(amt_reduced) + "!"
		)
	else:
		_failed(battle)
	return true


static func _ef_081(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.substitute:
		_failed(battle)
		return true
	
	var p_chance = min(8, 2 ** attacker.protect_count)
	if randi_range(0, p_chance - 1) < 1:
		attacker.invulnerable = true
		attacker.protect = true
		attacker.protect_count += 1
	else:
		_failed(battle)
	return true


static func _ef_082(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.max_hp / 2 > attacker.cur_hp or attacker.stat_stages[gs.ATK] == 6:#TODO div entero
		_failed(battle)
		return true
	battle.add_text(attacker.nickname + " cut its own HP and maximized its Attack!")
	attacker.stat_stages[gs.ATK] = 6
	return true


static func _ef_083(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var enemy = defender.trainer
	if enemy.spikes < 3:
		enemy.spikes += 1
		battle.add_text("Spikes were scattered all around the feet of " + enemy.name + "'s team!")
	else:
		_failed(battle)
	return true


static func _ef_084(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and not defender.foresight_target:
		defender.foresight_target = true
		battle.add_text(attacker.nickname + " identified " + defender.nickname + "!")
	else:
		_failed(battle)
	return true


static func _ef_085(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	battle.add_text(attacker.nickname + " is trying to take its foe with it!")
	attacker.db_count = 1 if is_first else 2
	return true


static func _ef_086(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not attacker.perish_count:
		attacker.perish_count = 4
	if defender.is_alive and not defender.perish_count:
		defender.perish_count = 4
	battle.add_text("All pokemon hearing the song will faint in three turns!")
	return true


static func _ef_087(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if battlefield.weather != gs.SANDSTORM:
		battlefield.change_weather(gs.SANDSTORM)
		battlefield.weather_count = 5 if attacker.item != "smooth-rock" else 8
		battle.add_text("A sandstorm brewed")
	else:
		_failed(battle)
	return true


static func _ef_088(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.substitute:
		_failed(battle)
		return true
	
	var p_chance = min(8, 2 ** attacker.protect_count)
	if randi_range(0, p_chance - 1) < 1:
		attacker.endure = true
		attacker.protect_count += 1
	else:
		_failed(battle)
	return true


static func _ef_089(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var power_multiplier = 1
	if (attacker.last_move
		and attacker.last_move == attacker.last_successful_move
		and attacker.last_move.name == move_data.name
	):
		power_multiplier *= 2 ** attacker.move_in_a_row
	else:
		attacker.move_in_a_row = 0
	if defender.has_defense_curl:
		power_multiplier *= 2
	move_data.power *= power_multiplier
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	move_data.power = move_data.original_power

	if dmg != 0 and attacker.move_in_a_row < 4:
		attacker.next_moves.append(move_data)
		attacker.move_in_a_row += 1
	else:
		attacker.move_in_a_row = 0
	return true


static func _ef_090(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var skip_dmg=true
	var dmg = _calculate_damage(
		attacker, defender, battlefield, battle, move_data, skip_dmg
	)
	if not dmg:
		return true
	if not defender.substitute and dmg >= defender.cur_hp:
		dmg = defender.cur_hp - 1
	defender.take_damage(dmg, move_data)
	return true


static func _ef_091(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive:
		give_stat_change(defender, battle, gs.ATK, 2)
		var forced=true
		confuse(defender, battle, forced)
	else:
		_failed(battle)
	return true


static func _ef_092_fury_cutter(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (attacker.last_move
		and attacker.last_move == attacker.last_successful_move
		and attacker.last_move.name == move_data.name
	):
		attacker.move_in_a_row += 1
		move_data.power = min(160, move_data.original_power * 2 ** (attacker.move_in_a_row - 1))
	else:
		attacker.move_in_a_row = 1
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return true


static func _ef_093(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var forced=true
	infatuate(attacker, defender, battle, forced)
	return true


static func _ef_094(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.nv_status == gs.ASLEEP:
		var pos_moves = []
		for move in attacker.moves:
			if move.name != "sleep-talk":
				pos_moves.append(move)
		if pos_moves.size() > 0:
			var sel_move = Move.new().set_move_data(pos_moves[randi_range(0, pos_moves.size() - 1)].md)
			battle.add_text(attacker.nickname + " used " + cap_name(sel_move.name) + "!")
			_process_effect(attacker, defender, battlefield, battle, sel_move, is_first)
	else:
		_failed(battle)
	return true


static func _ef_095(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if move_data.ef_stat == 1:
		battle.add_text("A bell chimed!")
	elif move_data.ef_stat == 2:
		battle.add_text("A soothing aroma wafted through the area!")
	var t = attacker.trainer
	for poke in t.poke_list:
		poke.nv_status = 0
	return true


static func _ef_096(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	move_data.power = max(1, int(attacker.friendship / 2.5))
	return true

static func _ef_097(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var res = randi() % 10
	if res < 2:
		if not defender.is_alive:
			_missed(attacker, battle)
			return true
		if defender.cur_hp == defender.max_hp:
			battle.add_text(defender.nickname + " can't receive the gift!")
			return true
		defender.heal(defender.max_hp / 4)#TODO div entero
		return true
	elif res < 6:
		move_data.power = 40
	elif res < 9:
		move_data.power = 80
	elif res < 10:
		move_data.power = 120
	return false

static func _ef_098(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	move_data.power = max(1, int((255 - attacker.friendship) / 2.5))
	return true

static func _ef_099(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var t = attacker.trainer
	if not t.safeguard:
		t.safeguard = 5
		battle.add_text(t.name + "'s team became cloaked in a mystical veil!")
	else:
		_failed(battle)
	return true

static func _ef_100(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive:
		var new_hp = (attacker.cur_hp + defender.cur_hp) / 2#TODO div entero
		battle.add_text("The battlers shared their pain!")
		attacker.cur_hp = min(new_hp, attacker.max_hp)
		defender.cur_hp = min(new_hp, defender.max_hp)
	else:
		_failed(battle)
	return true

static func _ef_101(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var res = randi() % 20
	var mag = 4
	if res < 1:
		move_data.power = 10
	elif res < 3:
		mag = 5
		move_data.power = 30
	elif res < 7:
		mag = 6
		move_data.power = 50
	elif res < 13:
		mag = 7
		move_data.power = 70
	elif res < 17:
		mag = 8
		move_data.power = 90
	elif res < 19:
		mag = 9
		move_data.power = 110
	else:
		mag = 10
		move_data.power = 150
	if defender.in_ground:
		cc_ib[1] = true
		move_data.power *= 2
	battle.add_text("Magnitude " + str(mag) + "!")
	return true

static func _ef_102(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var t = attacker.trainer
	var old_poke = attacker
	if t.num_fainted >= len(t.poke_list) - 1 or await battle._process_selection(t):
		_failed(battle)
	t.current_poke.v_status = attacker.v_status.duplicate()
	t.current_poke.stat_stages = attacker.stat_stages.duplicate()
	t.current_poke.perish_count = attacker.perish_count
	t.current_poke.trapped = attacker.trapped
	t.current_poke.perma_trapped = attacker.perma_trapped
	t.current_poke.embargo_count = attacker.embargo_count
	t.current_poke.magnetic_rise = attacker.magnetic_rise
	t.current_poke.substitute = attacker.substitute
	t.current_poke.heal_block_count = attacker.heal_block_count
	t.current_poke.power_trick = attacker.power_trick
	if not attacker.has_ability("multitype"):
		t.current_poke.ability_suppressed = attacker.ability_suppressed
	return true

static func _ef_103(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and not defender.encore_count
		and defender.last_move
		and defender.last_move.cur_pp
		and not (defender.last_move in gd.ENCORE_CHECK)
	):
		var has_matching_move = false
		for move in defender.moves:
			if move.name == defender.last_move.name:
				has_matching_move = true
				break

		if has_matching_move:
			defender.next_moves.clear()
			defender.encore_count = min(randi() % 5 + 2, defender.last_move.pp)
			for move in defender.moves:
				if move.name != defender.last_move.name:
					move.encore_blocked = true
				else:
					defender.encore_move = move
			battle.add_text(defender.nickname + " received an encore!")
		else:
			_failed(battle)
	else:
		_failed(battle)
	return true


static func _ef_104(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	if attacker.is_alive:
		attacker.v_status[gs.BINDING_COUNT] = 0
		attacker.binding_type = null
		attacker.binding_poke = null
		attacker.v_status[gs.LEECH_SEED] = 0
		var t = attacker.trainer
		t.spikes = 0
		t.toxic_spikes = 0
		t.steel_rock = 0
	return true

static func _ef_105(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var heal_amount = 4
	if battlefield.weather == gs.CLEAR:
		heal_amount = 2
	elif battlefield.weather == gs.HARSH_SUNLIGHT:
		heal_amount = 1.5
	attacker.heal(int(attacker.max_hp / heal_amount))
	return true

static func _ef_106(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var hp_stats = attacker.hidden_power_stats()#TODO posible error hidden_power, cambio de tupla a array
	if hp_stats:
		move_data.type = hp_stats[0]  # El primer valor del array es el tipo 
		move_data.power = hp_stats[1]  # El segundo valor es la potencia

	else:
		move_data.power = randi() % 41 + 30
		move_data.type = attacker.types[0]
	return true

static func _ef_107(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.in_air:
		cc_ib[1] = true
		move_data.power *= 2
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data, cc_ib[0], cc_ib[1])
	if dmg and randi() % 5 < 1:
		_flinch(defender, battle, is_first)
	return true

static func _ef_108(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if battlefield.weather != gs.RAIN:
		battlefield.change_weather(gs.RAIN)
		battlefield.weather_count = 5 if attacker.item != "damp-rock" else 8
		battle.add_text("It started to rain!")
	else:
		_failed(battle)
	return true

static func _ef_109(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if battlefield.weather != gs.HARSH_SUNLIGHT:
		battlefield.change_weather(gs.HARSH_SUNLIGHT)
		battlefield.weather_count = 5 if attacker.item != "heat-rock" else 8
		battle.add_text("The sunlight turned harsh!")
	else:
		_failed(battle)
	return true

static func _ef_110(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and attacker.last_move_hit_by
		and defender.last_move
		and attacker.last_move_hit_by.name == defender.last_move.name
		and attacker.last_move_hit_by.category == gs.SPECIAL
		and _calculate_type_ef(defender, move_data)
	):
		defender.take_damage(attacker.last_damage_taken * 2, move_data)
	else:
		_failed(battle)
	return true

static func _ef_111(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive:
		attacker.stat_stages = defender.stat_stages.duplicate()
		attacker.accuracy_stage = defender.accuracy_stage
		attacker.evasion_stage = defender.evasion_stage
		attacker.crit_stage = defender.crit_stage
		battle.add_text(
			attacker.nickname + " copied " + defender.nickname + "'s stat changes!"
		)
	else:
		_failed(battle)
	return true

static func _ef_112(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randi() % 100 < move_data.ef_chance:
		give_stat_change(attacker, battle, gs.ATK, 1)
		give_stat_change(attacker, battle, gs.DEF, 1)
		give_stat_change(attacker, battle, gs.SP_ATK, 1)
		give_stat_change(attacker, battle, gs.SP_DEF, 1)
		give_stat_change(attacker, battle, gs.SPD, 1)
	return true

static func _ef_113(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var t = defender.trainer
	if defender.is_alive and not t.fs_count:
		move_data.type = "typeless"
		var skip_dmg=true
		var crit_chance=-4
		t.fs_dmg = _calculate_damage(
			attacker,
			defender,
			battlefield,
			battle,
			move_data,
			crit_chance,
			skip_dmg
		)
		t.fs_count = 3
		battle.add_text(attacker.nickname + " foresaw an attack!")
	else:
		_failed(battle)
	return true

static func _ef_114(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if not defender.is_alive:
		_failed(battle)
		return true
	var poke_hits = []
	for poke in attacker.trainer.poke_list:
		if not poke.nv_status:
			poke_hits.append(poke)
	var num_hits = 0
	move_data.power = 10
	while defender.is_alive and num_hits < len(poke_hits):
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		battle.add_text(poke_hits[num_hits].nickname + "'s attack!")
		num_hits += 1
	return true

static func _ef_115(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and not attacker.uproar:
		attacker.uproar = randi() % 4 + 1
		battle.add_text(attacker.nickname + " caused an uproar!")
	return true

static func _ef_116(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.stockpile < 3:
		attacker.stockpile += 1
		battle.add_text(
			attacker.nickname + " stockpiled " + str(attacker.stockpile) + "!"
		)
		give_stat_change(attacker, battle, gs.DEF, 1)
		give_stat_change(attacker, battle, gs.SP_DEF, 1)
	else:
		_failed(battle)
	return true

static func _ef_117(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.stockpile:
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		move_data.power = 100 * attacker.stockpile
		attacker.stockpile = 0
		attacker.stat_stages[gs.DEF] -= attacker.stockpile
		attacker.stat_stages[gs.SP_DEF] -= attacker.stockpile
		battle.add_text(attacker.nickname + "'s stockpile effect wore off!")
	else:
		_failed(battle)
	return true

static func _ef_118(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if attacker.stockpile:
		attacker.heal(attacker.max_hp * (2 ** (attacker.stockpile - 1)) / 4)#TODO div entero
		attacker.stockpile = 0
		attacker.stat_stages[gs.DEF] -= attacker.stockpile
		attacker.stat_stages[gs.SP_DEF] -= attacker.stockpile
		battle.add_text(attacker.nickname + "'s stockpile effect wore off!")
	else:
		_failed(battle)
	return true

static func _ef_119(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if battlefield.weather != gs.HAIL:
		battlefield.change_weather(gs.HAIL)
		battlefield.weather_count = 5 if attacker.item != "icy-rock" else 8
		battle.add_text("It started to hail!")
	else:
		_failed(battle)
	return true

static func _ef_120(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if defender.is_alive and not defender.tormented:
		defender.tormented = true
		battle.add_text(defender.nickname + " was subjected to Torment!")
	else:
		_failed(battle)
	return true

static func _ef_121(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array
) -> bool:
	if (
		defender.is_alive
		and not defender.substitute
		and (not defender.v_status[gs.CONFUSED] or defender.stat_stages[gs.SP_ATK] < 6)
	):
		give_stat_change(defender, battle, gs.SP_ATK, 1)
		confuse(defender, battle)
	else:
		_failed(battle)
	return true

# Adaptar las funciones para GDScript

static func _ef_122(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.substitute:
		attacker.faint()
		give_stat_change(defender, battle, gs.ATK, -2)
		give_stat_change(defender, battle, gs.SP_ATK, -2)
	return true

static func _ef_123(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.nv_status == gs.BURNED or attacker.nv_status == gs.PARALYZED or attacker.nv_status == gs.POISONED:
		move_data.power *= 2
	return false

static func _ef_124(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not defender.is_alive:
		_failed(battle)
		return true
	if attacker.turn_damage:
		battle._pop_text()
		battle.add_text(attacker.nickname + " lost its focus and couldn't move!")
		return true
	return false

static func _ef_125_smelling_salts(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.nv_status == gs.PARALYZED:
		move_data.power *= 2
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and defender.nv_status == gs.PARALYZED:
		cure_nv_status(gs.PARALYZED, defender, battle)
	return true

static func _ef_126(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var selected_move
	if battlefield.get_terrain() in [gs.BUILDING, gs.DISTORSION_WORLD]:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("tri-attack"))
	elif battlefield.get_terrain() == gs.SAND:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("earthquake"))
	elif battlefield.get_terrain() == gs.CAVE:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("rock-slide"))
	elif battlefield.get_terrain() == gs.TALL_GRASS:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("seed-bomb"))
	elif battlefield.get_terrain() == gs.WATER:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("hydro-pump"))
	elif battlefield.get_terrain() == gs.SNOW:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("blizzard"))
	elif battlefield.get_terrain() == gs.ICE:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("ice-beam"))
	else:
		selected_move = Move.new().set_move_data(PokeSim.get_single_move("tri-attack"))
	print("ef126")
	var effect_move = _MOVE_EFFECTS[selected_move.ef_id]
	battle.add_text(cap_name(move_data.name) + " turned into " + cap_name(selected_move.name) + "!")
	return effect_move

static func _ef_127(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	attacker.charged = 2
	battle.add_text(attacker.nickname + " began charging power!")
	give_stat_change(attacker, battle, gs.SP_DEF, 1)
	return false

static func _ef_128(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.taunt and not defender.has_ability("oblivious"):
		defender.taunt = randi_range(3, 6)
		battle.add_text(defender.nickname + " fell for the taunt!")
	else:
		_failed(battle)
	return false

static func _ef_129(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	_failed(battle)
	return false

static func _ef_130(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.substitute and (attacker.item or defender.item) and attacker.item != "griseous-orb" and defender.item != "griseous-orb" and not defender.has_ability("sticky-hold") and not defender.has_ability("multitype") and not attacker.has_ability("multitype"):
		var a_item = attacker.item
		attacker.give_item(defender.item)
		defender.give_item(a_item)
		battle.add_text(attacker.nickname + " switched items with its target!")
		if attacker.item:
			battle.add_text(attacker.nickname + " obtained one " + cap_name(attacker.item) + ".")
		if defender.item:
			battle.add_text(defender.nickname + " obtained one " + cap_name(defender.item) + ".")
	else:
		_failed(battle)
	return false

static func _ef_131(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and defender.ability and not defender.has_ability("wonder-guard") and not defender.has_ability("multitype"):
		attacker.give_ability(defender.ability)
		battle.add_text(attacker.nickname + " copied " + defender.nickname + "'s " + defender.ability + "!")
	else:
		_failed(battle)
	return false

static func _ef_132(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var t = attacker.trainer
	if not t.wish:
		t.wish = 2
		t.wish_poke = attacker.nickname
	else:
		_failed(battle)
	return false

static func _ef_133(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var possible_moves = []
	for poke in attacker.trainer.poke_list:
		for move in poke.moves:
			if move.name not in gd.ASSIST_CHECK:
				possible_moves.append(move)
	if possible_moves.size() > 0:
		_process_effect(
			attacker,
			defender,
			battlefield,
			battle,
			Move.new().set_move_data(possible_moves[randi_range(0, possible_moves.size() - 1)].md),
			is_first,
		)
	else:
		_failed(battle)
	return true

static func _ef_134(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.v_status[gs.INGRAIN]:
		battle.add_text(attacker.nickname + " planted its roots!")
		attacker.v_status[gs.INGRAIN] = 1
		attacker.trapped = true
		attacker.grounded = true
	else:
		_failed(battle)
	return false

static func _ef_135(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		give_stat_change(attacker, battle, gs.ATK, -1, true)
		give_stat_change(attacker, battle, gs.DEF, -1, true)
	return true

static func _ef_136(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if is_first:
		attacker.magic_coat = true
		battle.add_text(attacker.nickname + " shrouded itself with Magic Coat!")
	else:
		_failed(battle)
	return false

static func _ef_137(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.item and not attacker.h_item and attacker.last_consumed_item:
		attacker.give_item(attacker.last_consumed_item)
		attacker.last_consumed_item = null
		battle.add_text(attacker.nickname + " found one " + cap_name(attacker.item) + "!")
	else:
		_failed(battle)
	return false

static func _ef_138(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.turn_damage:
		move_data.power *= 2
	return false

static func _ef_139(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.invulnerable and not defender.protect:
		var t = defender.trainer
		if t.light_screen or t.reflect:
			t.light_screen = 0
			t.reflect = 0
			battle.add_text("It shattered the barrier!")
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
	else:
		_failed(battle)
	return true

static func _ef_140(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		defender.is_alive
		and not defender.v_status[gs.DROWSY]
		and not defender.substitute
		and defender.nv_status != gs.FROZEN
		and defender.nv_status != gs.ASLEEP
		and not defender.has_ability("insomnia")
		and not defender.has_ability("vital-spirit")
		and not defender.trainer.safeguard
		and not (
			defender.has_ability("leaf-guard")
			and battlefield.weather == gs.HARSH_SUNLIGHT
		)
		and not (defender.uproar and not defender.has_ability("soundproof"))
	):
		defender.v_status[gs.DROWSY] = 2
		battle.add_text(attacker.nickname + " made " + defender.nickname + " drowsy!")
	else:
		_failed(battle)
	return false

static func _ef_141(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and defender.item and defender.h_item:
		battle.add_text(
			attacker.nickname
			+ " knocked off "
			+ defender.nickname
			+ "'s "
			+ cap_name(defender.item)
			+ "!"
		)
		defender.item = ""
	return true

static func _ef_142(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		defender.is_alive
		and attacker.cur_hp < defender.cur_hp
		and _calculate_type_ef(defender, move_data)
	):
		defender.take_damage(defender.cur_hp - attacker.cur_hp)
	else:
		_failed(battle)
	return true

static func _ef_143(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	move_data.power = max(1, int(150 * attacker.cur_hp) / attacker.max_hp)#TODO div entero
	return false

static func _ef_144(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		defender.is_alive
		and not defender.has_ability("wonder-guard")
		and not defender.has_ability("multitype")
		and not attacker.has_ability("wonder-guard")
		and not attacker.has_ability("multitype")
	):
		var a_ability = attacker.ability
		attacker.give_ability(defender.ability)
		defender.give_ability(a_ability)
		battle.add_text(attacker.nickname + " swapped abilities with its target!")
	else:
		_failed(battle)
	return false

static func _ef_145(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var a_moves = []
	for move in attacker.moves:
		a_moves.append(move.name)
	var t = defender.trainer
	if not t.imprisoned_poke:
		var move_sealed = false
		for poke in t.poke_list:
			for move in poke.moves:
				if move.name in a_moves:
					move_sealed = true
					break
			if move_sealed:
				break
		
		if move_sealed:
			battle.add_text(attacker.nickname + " sealed the opponent's move(s)!")
			t.imprisoned_poke = attacker
		else:
			_failed(battle)
	return false


static func _ef_146(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		attacker.nv_status == gs.BURNED
		or attacker.nv_status == gs.PARALYZED
		or attacker.nv_status == gs.POISONED
	):
		attacker.nv_status = 0
		battle.add_text(attacker.nickname + "'s status returned to normal!")
	else:
		_failed(battle)
	return false

static func _ef_147(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	battle.add_text(attacker.nickname + " wants " + attacker.enemy.name + " to bear a grudge!")
	return false

static func _ef_148(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if is_first:
		attacker.snatch = true
		battle.add_text(attacker.nickname + " waits for a target to make a move!")
	else:
		_failed(battle)
	return false

static func _ef_149(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randi_range(1, 100) < move_data.ef_chance:
		paralyze(defender, battle)
	return true

static func _ef_150_dive(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		attacker.next_moves.append(move_data)
		attacker.in_water = true
		attacker.invulnerable = true
		attacker.invulnerability_count = 1
		battle._pop_text()
		battle.add_text(attacker.nickname + " hid underwater!")
		return true
	else:
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		return false

static func _ef_151(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	attacker.type = ["normal", null]
	battle.add_text(attacker.nickname + " transformed into the " + attacker.types[0].upper() + " type!")
	return false

static func _ef_152(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var crit_chance=1
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data, crit_chance)
	if dmg and randi_range(0, 9) < 1:
		burn(defender, battle)
	return true

static func _ef_153(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.mud_sport and not (defender.is_alive and defender.mud_sport):
		attacker.mud_sport = true
		battle.add_text("Electricity's power was weakened")
	else:
		_failed(battle)
	return false

static func _ef_154(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	match battlefield.weather:
		gs.HARSH_SUNLIGHT:
			move_data.type = "fire"
		gs.RAIN:
			move_data.type = "water"
		gs.HAIL:
			move_data.type = "ice"
		gs.SANDSTORM:
			move_data.type = "rock"
		_:
			move_data.type = "normal"
	if battlefield.weather != gs.CLEAR:
		move_data.power *= 2
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	return false

static func _ef_156(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	sleep(defender, battle, true)
	return false

static func _ef_157(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and (
		defender.stat_stages[gs.ATK] > -6 or defender.stat_stages[gs.DEF] > -6
	):
		give_stat_change(defender, battle, gs.ATK, -1)
		give_stat_change(defender, battle, gs.DEF, -1)
	else:
		_failed(battle)
	return false

static func _ef_158(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.stat_stages[gs.DEF] < 6 or attacker.stat_stages[gs.SP_DEF] < 6:
		give_stat_change(attacker, battle, gs.DEF, 1)
		give_stat_change(attacker, battle, gs.SP_DEF, 1)
	else:
		_failed(battle)
	return false

static func _ef_159(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and defender.in_air:
		cc_ib[1] = true
	return false

static func _ef_160(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.stat_stages[gs.ATK] < 6 or attacker.stat_stages[gs.DEF] < 6:
		give_stat_change(attacker, battle, gs.ATK, 1)
		give_stat_change(attacker, battle, gs.DEF, 1)
	else:
		_failed(battle)
	return false

static func _ef_161_bounce(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		attacker.next_moves.append(move_data)
		attacker.in_air = true
		attacker.invulnerable = true
		attacker.invulnerability_count = 1
		battle._pop_text()
		battle.add_text(attacker.nickname + " sprang up!")
		return true
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randf_range(0, 9) < 3:
		paralyze(defender, battle)
	return true


static func _ef_162(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var crit_chance=1
	var dmg = _calculate_damage(
		attacker, defender, battlefield, battle, move_data, crit_chance
	)
	if dmg and randf_range(0, 9) < 1:
		poison(defender, battle)
	return true

static func _ef_163(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg and randf_range(0, 9) < 1:
		paralyze(defender, battle)
	if dmg:
		_recoil(attacker, battle, max(1, dmg / 3), move_data)#TODO div entero
	return true

static func _ef_164(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.water_sport and not (defender.is_alive and defender.water_sport):
		attacker.water_sport = true
		battle.add_text("Fire's power was weakened")
	else:
		_failed(battle)
	return false

static func _ef_165(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.stat_stages[gs.SP_ATK] < 6 or attacker.stat_stages[gs.SP_DEF] < 6:
		give_stat_change(attacker, battle, gs.SP_ATK, 1)
		give_stat_change(attacker, battle, gs.SP_DEF, 1)
	else:
		_failed(battle)
	return false

static func _ef_166(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.stat_stages[gs.ATK] < 6 or attacker.stat_stages[gs.SPD] < 6:
		give_stat_change(attacker, battle, gs.ATK, 1)
		give_stat_change(attacker, battle, gs.SPD, 1)
	else:
		_failed(battle)
	return false

static func _ef_167(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var t = defender.trainer
	if defender.is_alive and not t.dd_count:
		move_data.type = "typeless"
		var crit_chance=0
		var skip_dmg=true
		t.dd_dmg = _calculate_damage(
			attacker,
			defender,
			battlefield,
			battle,
			move_data,
			crit_chance,
			skip_dmg,
		)
		t.dd_count = 3
		battle.add_text(attacker.nickname + " chose Doom Desire as its destiny!")
	else:
		_failed(battle)
	return true

static func _ef_168(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	attacker.heal(max(1, attacker.max_hp / 2))#TODO div entero
	if not is_first or "flying" not in attacker.types:
		return true
	attacker.r_types = attacker.types
	var other_type = []
	for type in attacker.types:
		if type != "flying":
			other_type.append(type)
	if other_type.size() > 0:
		attacker.types = [other_type[0], null]
	else:
		attacker.types = ["normal", null]
	return false

static func _ef_169(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not battlefield.gravity_count:
		battlefield.gravity_count = 5
		battlefield.acc_modifier = 5.0 / 3.0
		attacker.grounded = true
		defender.grounded = true
		battle.add_text("Gravity intensified!")
	else:
		_failed(battle)
	return false

static func _ef_170(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.me_target:
		defender.me_target = true
		battle.add_text(attacker.nickname + " identified " + defender.nickname + "!")
	else:
		_failed(battle)
	return false

static func _ef_171(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.nv_status == gs.ASLEEP:
		move_data.power *= 2
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg:
		cure_nv_status(gs.ASLEEP, defender, battle)
	return true

static func _ef_172(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	attacker.calculate_stats_effective()
	defender.calculate_stats_effective()
	move_data.power = min(
		150,
		attacker.stats_effective[gs.SPD] * 25 / max(1, defender.stats_effective[gs.SPD]) + 1
	)
	return false

static func _ef_173(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var t = attacker.trainer
	if t.num_fainted >= t.poke_list.size() - 1 or await battle._process_selection(t):
		_failed(battle)
	battle.add_text("The healing wish came true!")
	t.current_poke.heal(t.current_poke.max_hp)
	t.current_poke.nv_status = 0
	return false

static func _ef_174(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.cur_hp < attacker.max_hp / 2:#TODO div entero
		move_data.power *= 2
	return false


static func _ef_175(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		attacker.item
		and attacker.item in gd.BERRY_DATA
		and battlefield.weather not in [gs.HARSH_SUNLIGHT, gs.RAIN]
		and not attacker.has_ability("klutz")
		and not attacker.embargo_count
	):
		move_data.type = gd.BERRY_DATA[attacker.item][0]#TODO posible error cambio de tupla a array
		move_data.power = gd.BERRY_DATA[attacker.item][1]
		attacker.give_item("")#TODO posible error item vacio
	else:
		_failed(battle)
		return true
	return false

static func _ef_176(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not is_first and defender.is_alive and defender.protect:
		battle.add_text(defender.nickname + " fell for the feint!")
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
	else:
		_failed(battle)
	return true

static func _ef_177(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if (
		defender.is_alive
		and dmg
		and defender.item
		and defender.item in gd.BERRY_DATA
		and not defender.has_ability("sticky-hold")
		and not defender.substitute
	):
		battle.add_text(
			attacker.nickname
			+ " stole and ate "
			+ defender.nickname
			+ "'s "
			+ defender.item
			+ "!"
		)
		if not attacker.has_ability("klutz") and not attacker.embargo_count:
			var text_skip=true
			var can_skip=true
			#pi.use_item(TODO descomentar
				#attacker.trainer,
				#battle,
				#defender.item,
				#attacker,
				#randf_range(0, attacker.moves.size() - 1),
				#text_skip,
				#can_skip
			#)
		defender.give_item("")#TODO posible error item vacio
	return true

static func _ef_178(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.trainer.tailwind_count:
		battle.add_text(
			"The tailwind blew from being " + attacker.trainer.name + "'s team!"
		)
		attacker.trainer.tailwind_count = 3
		for poke in attacker.trainer.poke_list:
			poke.stats_actual[gs.SPD] *= 2
	else:
		_failed(battle)
	return false

static func _ef_179(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var ef_stats = attacker.stat_stages + [attacker.accuracy_stage, attacker.evasion_stage]
	var filtered_stats = []
	for stat_i in range(ef_stats.size()):
		if ef_stats[stat_i] < 6:
			filtered_stats.append(stat_i)
	ef_stats = filtered_stats
	if ef_stats.size() > 0:
		give_stat_change(attacker, battle, randf_range(0, ef_stats.size() - 1), 2)
	else:
		_failed(battle)
	return false

static func _ef_180(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not is_first and attacker.turn_damage and defender.is_alive:
		defender.take_damage(int(attacker.last_damage_taken * 1.5))
	else:
		_failed(battle)
	return true

static func _ef_181(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	_calculate_damage(attacker, defender, battlefield, battle, move_data)
	var t = attacker.trainer
	if t.num_fainted < t.poke_list.size() - 1:
		battle._process_selection(t)
	return true

static func _ef_182(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if attacker.is_alive and dmg:
		var bypass=true
		give_stat_change(attacker, battle, gs.DEF, -1, bypass)
		give_stat_change(attacker, battle, gs.SP_DEF, -1, bypass)
	return true

static func _ef_183(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not is_first:
		move_data.power *= 2
	return false

static func _ef_184(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not is_first and defender.turn_damage:
		move_data.power *= 2
	return false

static func _ef_185(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.embargo_count:
		defender.embargo_count = 5
		battle.add_text(defender.nickname + " can't use items anymore!")
	else:
		_failed(battle)
	return false

static func _ef_186(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.item:
		battle.add_text(attacker.nickname + " flung its " + attacker.item + "!")
		move_data.power = 20
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		if attacker.is_alive:
			attacker.give_item("")#TODO posible error item vacio
	else:
		_failed(battle)
	return false

static func _ef_187(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.nv_status:
		give_nv_status(attacker.nv_status, defender, battle)
		attacker.nv_status = 0
	else:
		_failed(battle)
	return false

static func _ef_188(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	match move_data.cur_pp:
		4:
			move_data.power = 40
		3:
			move_data.power = 50
		2:
			move_data.power = 60
		1:
			move_data.power = 80
		_:
			move_data.power = 200
	return false

static func _ef_189(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.heal_block_count:
		defender.heal_block_count = 5
		battle.add_text(defender.nickname + " was prevented from healing!")
	else:
		_failed(battle)
	return false

static func _ef_190(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	move_data.power = int(1 + 120 * attacker.cur_hp / attacker.max_hp)
	return false

static func _ef_191(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	# Intercambia los valores de ATK y DEF
	var temp_atk = attacker.stats_actual[gs.ATK]
	attacker.stats_actual[gs.ATK] = attacker.stats_actual[gs.DEF]
	attacker.stats_actual[gs.DEF] = temp_atk

	# Añade el texto y cambia el estado de power_trick
	battle.add_text(attacker.nickname + " switched its Attack and Defense!")
	attacker.power_trick = true
	return false


static func _ef_192(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		defender.is_alive
		and not defender.has_ability("multitype")
		and not defender.ability_suppressed
	):
		defender.ability_suppressed = true
		battle.add_text(defender.nickname + "'s ability was suppressed!")
	else:
		_failed(battle)
	return false

static func _ef_193(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.trainer.lucky_chant:
		attacker.trainer.lucky_chant = 5
		battle.add_text(
			"The Lucky Chant shielded "
			+ attacker.trainer.name
			+ "'s team from critical hits!"
		)
	else:
		_failed(battle)
	return false

static func _ef_194(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.mf_move:
		if attacker.mf_move.power:
			attacker.mf_move.power = int(1.5 * attacker.mf_move.power)
		battle.add_text(
			attacker.nickname + " used " + cap_name(attacker.mf_move.name) + "!"
		)
		_process_effect(
			attacker, defender, battlefield, battle, attacker.mf_move, is_first
		)
		attacker.mf_move = null
	else:
		_failed(battle)
	return true

static func _ef_195(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if battle.last_move and battle.last_move.name != move_data.name:
		_process_effect(
			attacker, defender, battlefield, battle, Move.new().set_move_data(battle.last_move.md), is_first
		)
		return true
	else:
		_failed(battle)
	return false

static func _ef_196(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive:
		# Intercambia los valores de ATK
		var temp_atk = attacker.stat_stages[gs.ATK]
		attacker.stat_stages[gs.ATK] = defender.stat_stages[gs.ATK]
		defender.stat_stages[gs.ATK] = temp_atk

		# Intercambia los valores de SP_ATK
		var temp_sp_atk = attacker.stat_stages[gs.SP_ATK]
		attacker.stat_stages[gs.SP_ATK] = defender.stat_stages[gs.SP_ATK]
		defender.stat_stages[gs.SP_ATK] = temp_sp_atk

		# Añade el texto correspondiente
		battle.add_text(
			attacker.nickname
			+ " switched all changes to its Attack and Sp. Atk with "
			+ defender.nickname
			+ "!"
		)

	else:
		_failed(battle)
	return false

static func _ef_197(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive:
		# Intercambia los valores de DEF
		var temp_def = attacker.stat_stages[gs.DEF]
		attacker.stat_stages[gs.DEF] = defender.stat_stages[gs.DEF]
		defender.stat_stages[gs.DEF] = temp_def

		# Intercambia los valores de SP_DEF
		var temp_sp_def = attacker.stat_stages[gs.SP_DEF]
		attacker.stat_stages[gs.SP_DEF] = defender.stat_stages[gs.SP_DEF]
		defender.stat_stages[gs.SP_DEF] = temp_sp_def

		# Añade el texto correspondiente
		battle.add_text(
			attacker.nickname
			+ " switched all changes to its Defense and Sp. Def with "
			+ defender.nickname
			+ "!"
		)

	else:
		_failed(battle)
	return false

static func _ef_198(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var positive_stats = 0
	for stat in attacker.stat_stages:
		if stat > 0:
			positive_stats += stat
	move_data.power = max(200, 60 + 20 * positive_stats)
	return false

static func _ef_199(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.moves.size() < 2:
		_failed(battle)
		return true
	return false

	var all_moves_valid = true
	for i in range(attacker.moves.size()):
		if not (attacker.moves[i].cur_pp < attacker.old_pp[i] or attacker.moves[i].name == "last-resort"):
			all_moves_valid = false
			break

	if not all_moves_valid:
		_failed(battle)
		return true


static func _ef_200(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive and not defender.has_ability("multitype") and not defender.has_ability("truant"):
		battle.add_text(defender.nickname + " acquired insomnia!")
		defender.give_ability("insomnia")
	else:
		_failed(battle)
	return false

static func _ef_201(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not is_first or not attacker.sucker_punch_check:
		_failed(battle)
		return true
	return false

static func _ef_202(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	defender.trainer.toxic_spikes += 1
	battle.add_text(
		"Poison spikes were scattered all around the feet of "
		+ defender.trainer.name
		+ "'s team!"
	)
	return false

static func _ef_203(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive:
		# Intercambiar los cambios de estadísticas entre el atacante y el defensor
		var temp_stat_stages = attacker.stat_stages
		attacker.stat_stages = defender.stat_stages
		defender.stat_stages = temp_stat_stages

		battle.add_text(
			attacker.nickname + " switched stat changes with " + defender.nickname + "!"
		)
	else:
		_failed(battle)
	return false


static func _ef_204(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.v_status[gs.AQUA_RING]:
		battle.add_text(attacker.nickname + " surrounded itself with a veil of water!")
		attacker.v_status[gs.AQUA_RING] = 1
	else:
		_failed(battle)
	return false

static func _ef_205(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not attacker.magnet_rise:
		attacker.magnet_rise = true
		battle.add_text(attacker.nickname + " levitated on electromagnetism!")
	else:
		_failed(battle)
	return false

static func _ef_206(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		_recoil(attacker, battle, max(1, dmg / 3), move_data)
	if defender.is_alive and dmg and randi() % 10 < 1:
		burn(defender, battle)
	return true

static func _ef_207(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		_recoil(attacker, battle, max(1, dmg / 3), move_data)
	return false

static func _ef_208(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg:
		if randi() % 100 < move_data.ef_chance:
			paralyze(defender, battle)
		if randi() % 100 < move_data.ef_chance:
			_flinch(defender, battle, is_first)
	return true

static func _ef_209(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg:
		if randi() % 100 < move_data.ef_chance:
			freeze(defender, battle)
		if randi() % 100 < move_data.ef_chance:
			_flinch(defender, battle, is_first)
	return true

static func _ef_210(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg:
		if randi() % 100 < move_data.ef_chance:
			burn(defender, battle)
		if randi() % 100 < move_data.ef_chance:
			_flinch(defender, battle, is_first)
	return true

static func _ef_211(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if defender.is_alive:
		battle.add_text(_stat_text(defender, gs.EVA, -1))
		if defender.evasion_stage > -6:
			defender.evasion_stage -= 1
	attacker.trainer.spikes = 0
	attacker.trainer.toxic_spikes = 0
	attacker.trainer.stealth_rock = 0
	attacker.trainer.safeguard = 0
	attacker.trainer.light_screen = 0
	attacker.trainer.reflect = 0
	attacker.trainer.mist = 0
	if battlefield.weather == gs.FOG:
		battlefield.weather = gs.CLEAR
	return false

static func _ef_212(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not battlefield.trick_room_count:
		battlefield.trick_room_count = 5
		battle.add_text(attacker.nickname + " twisted the dimensions!")
	else:
		battlefield.trick_room_count = 0
		battle.add_text("The twisted dimensions returned to normal!")
	return false

static func _ef_213(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if (
		defender.is_alive
		and (attacker.gender == "male" and defender.gender == "female")
		or (attacker.gender == "female" and defender.gender == "male")
	):
		give_stat_change(defender, battle, gs.SP_ATK, -2, true)
	else:
		_failed(battle)
	return false

static func _ef_214(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not defender.trainer.stealth_rock:
		defender.trainer.stealth_rock = 1
		battle.add_text(
			"Pointed stones float in the air around "
			+ defender.trainer.name
			+ "'s team!"
		)
	else:
		_failed(battle)
	return false

static func _ef_215(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if defender.is_alive and dmg and randi() % 100 < 1:
		confuse(defender, battle)
	return true

static func _ef_216(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if attacker.item and attacker.item in gd.PLATE_DATA:
		move_data.type = gd.PLATE_DATA[attacker.item]
	return false

static func _ef_217(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var dmg = _calculate_damage(attacker, defender, battlefield, battle, move_data)
	if dmg:
		_recoil(attacker, battle, max(1, dmg / 2), move_data)
	return false

static func _ef_218(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	var t = attacker.trainer
	if t.num_fainted >= len(t.poke_list) - 1:
		_failed(battle)
	attacker.faint()
	battle._process_selection(t)
	battle.add_text(t.current_poke.nickname + " became cloaked in mystical moonlight!")
	t.current_poke.heal(t.current_poke.max_hp)
	t.current_poke.nv_status = 0
	for move in t.current_poke.moves:
		move.cur_pp = move.max_pp
	return false

static func _ef_219_shadow_force(
	attacker: Pokemon,
	defender: Pokemon,
	battlefield: Battlefield,
	battle: Battle,
	move_data: Move,
	is_first: bool,
	cc_ib: Array,
) -> bool:
	if not move_data.ef_stat and not _power_herb_check(attacker, battle):
		move_data.ef_stat = 1
		attacker.next_moves.push_back(move_data)
		attacker.invulnerable = true
		attacker.invulnerability_count = 1
		battle.add_text(attacker.nickname + " vanished instantly!")
		return true
	else:
		_calculate_damage(attacker, defender, battlefield, battle, move_data)
		return false

static var _MOVE_EFFECTS = [
	_ef_000, _ef_001, _ef_002, _ef_003, _ef_004, _ef_005, _ef_006, _ef_007, _ef_008, _ef_009, 
	_ef_010, _ef_011, null, _ef_013, _ef_014, null, _ef_016, _ef_017, _ef_018, _ef_019, _ef_020, 
	_ef_021, _ef_022, _ef_023_fly, _ef_024, _ef_025, _ef_026, _ef_027, _ef_028, _ef_029, _ef_030, 
	_ef_031, _ef_032, _ef_033, _ef_034, _ef_035, _ef_036, _ef_037, _ef_038, _ef_039, _ef_040, 
	_ef_041_thunder, _ef_042_dig, _ef_043, _ef_044, null, _ef_046, _ef_047, _ef_048, _ef_049, _ef_050, 
	_ef_051, _ef_052, _ef_053, _ef_054, _ef_055, _ef_056, _ef_057, _ef_058, _ef_059, _ef_060, 
	_ef_061, _ef_062, _ef_063, _ef_064, _ef_065, _ef_066, _ef_067, _ef_068, _ef_069, _ef_070, 
	_ef_071, _ef_072, _ef_073, _ef_074, _ef_075, _ef_076, _ef_077, _ef_078, _ef_079, _ef_080, 
	_ef_081, _ef_082, _ef_083, _ef_084, _ef_085, _ef_086, _ef_087, _ef_088, _ef_089, _ef_090, 
	_ef_091, _ef_092_fury_cutter, _ef_093, _ef_094, _ef_095, _ef_096, _ef_097, _ef_098, _ef_099, _ef_100, 
	_ef_101, _ef_102, _ef_103, _ef_104, _ef_105, _ef_106, _ef_107, _ef_108, _ef_109, _ef_110, 
	_ef_111, _ef_112, _ef_113, _ef_114, _ef_115, _ef_116, _ef_117, _ef_118, _ef_119, _ef_120, 
	_ef_121, _ef_122, _ef_123, _ef_124, _ef_125_smelling_salts, _ef_126, _ef_127, _ef_128, _ef_129, _ef_130, 
	_ef_131, _ef_132, _ef_133, _ef_134, _ef_135, _ef_136, _ef_137, _ef_138, _ef_139, _ef_140, 
	_ef_141, _ef_142, _ef_143, _ef_144, _ef_145, _ef_146, _ef_147, _ef_148, _ef_149, _ef_150_dive, 
	_ef_151, _ef_152, _ef_153, _ef_154, null, _ef_156, _ef_157, _ef_158, _ef_159, _ef_160, 
	_ef_161_bounce, _ef_162, _ef_163, _ef_164, _ef_165, _ef_166, _ef_167, _ef_168, _ef_169, _ef_170, 
	_ef_171, _ef_172, _ef_173, _ef_174, _ef_175, _ef_176, _ef_177, _ef_178, _ef_179, _ef_180, 
	_ef_181, _ef_182, _ef_183, _ef_184, _ef_185, _ef_186, _ef_187, _ef_188, _ef_189, _ef_190, 
	_ef_191, _ef_192, _ef_193, _ef_194, _ef_195, _ef_196, _ef_197, _ef_198, _ef_199, _ef_200, 
	_ef_201, _ef_202, _ef_203, _ef_204, _ef_205, _ef_206, _ef_207, _ef_208, _ef_209, _ef_210, 
	_ef_211, _ef_212, _ef_213, _ef_214, _ef_215, _ef_216, _ef_217, _ef_218, _ef_219_shadow_force
]
