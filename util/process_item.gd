

# Importa módulos necesarios

const tr = preload("res://gdScripts/pokeSim/core/trainer.gd")
const bt = preload("res://gdScripts/pokeSim/core/battle.gd")
const bf = preload("res://gdScripts/pokeSim/core/battlefield.gd")

const pm = preload("res://gdScripts/pokeSim/util/process_move.gd")

const gs = preload("res://gdScripts/pokeSim/conf/global_settings.gd")
const gd = preload("res://gdScripts/pokeSim/conf/global_data.gd")


static func use_item(
	trainer: tr.Trainer,
	battle: Battle,
	item: String,
	item_target_pos: String,
	move_target_pos: String = "-1",
	text_skip: bool = false,
	can_skip: bool = false
) -> void:
	"""
	Item actions in turn must be formatted as: ['item', $item, $item_target_pos, $move_target_pos?]

	$item refers to the item name
	$item_target_pos refers to the target's position in the trainer's party (0-indexed)
	$move_target_pos is an optional parameter that refers to the target move's position
	in item target's move list (0-indexed)
	"""
	if not can_use_item(trainer, battle, item, item_target_pos, move_target_pos):
		if can_skip:
			return
		push_error("Trainer attempted to use invalid item on Pokemon")
		return

	var poke = trainer.current_poke
	var move: Move = null
	if move_target_pos != "-1":
		move = poke.moves[move_target_pos]

	if not text_skip:
		battle.add_text(
			trainer.name
			+ " used one "
			+ pm.cap_name(item)
			+ " on "
			+ poke.nickname
			+ "!"
		)

	if poke.embargo_count > 0:
		pm._failed(battle)
		return

	if item in gd.HEALING_ITEM_CHECK.keys():
		poke.heal(gd.HEALING_ITEM_CHECK[item])
	elif item == "antidote" or item == "pecha-berry":
		pm.cure_nv_status(gs.POISONED, poke, battle)
	elif item == "burn-heal" or item == "rawst-berry":
		pm.cure_nv_status(gs.BURNED, poke, battle)
	elif item == "ice-heal" or item == "aspear-berry":
		pm.cure_nv_status(gs.FROZEN, poke, battle)
	elif item == "awakening" or item == "chesto-berry":
		pm.cure_nv_status(gs.ASLEEP, poke, battle)
	elif item == "paralyz-heal" or item == "cheri-berry":
		pm.cure_nv_status(gs.PARALYZED, poke, battle)
	elif item == "full-restore":
		poke.heal(poke.max_hp)
		pm.cure_nv_status(poke.nv_status, poke, battle)
		pm.cure_confusion(poke, battle)
	elif item == "max-potion":
		poke.heal(poke.max_hp)
	elif item == "full-heal" or item == "heal-powder" or item == "lava-cookie" or item == "old-gateau" or item == "lum-berry":
		pm.cure_nv_status(poke.nv_status, poke, battle)
		pm.cure_confusion(poke, battle)
	elif item == "revive":
		if not poke.is_alive:
			poke.is_alive = true
			poke.heal(poke.max_hp / 2)
	elif item == "max-revive":
		if not poke.is_alive:
			poke.is_alive = true
			poke.heal(poke.max_hp)
	elif item == "revival-herb":
		if not poke.is_alive:
			poke.is_alive = true
			poke.heal(poke.max_hp)
	elif item == "ether" or item == "leppa-berry":
		poke.restore_pp(move, 10)
	elif item == "max-ether":
		poke.restore_pp(move, 999)
	elif item == "elixir":
		poke.restore_all_pp(10)
	elif item == "max-elixir":
		poke.restore_all_pp(999)
	elif item == "guard-spec.":
		if not trainer.mist:
			battle.add_text(trainer.name + "'s team became shrouded in mist!")
			trainer.mist = 5
	elif item == "dire-hit":
		poke.crit_stage += 2
		if poke.crit_stage > 4:
			poke.crit_stage = 4
		battle.add_text(poke.nickname + " is getting pumped!")
	elif item == "x-attack":
		pm.give_stat_change(poke, battle, gs.ATK, 1, true)
	elif item == "x-defense":
		pm.give_stat_change(poke, battle, gs.DEF, 1, true)
	elif item == "x-speed":
		pm.give_stat_change(poke, battle, gs.SPD, 1, true)
	elif item == "x-accuracy":
		pm.give_stat_change(poke, battle, gs.ACC, 1, true)
	elif item == "x-special":
		pm.give_stat_change(poke, battle, gs.SP_ATK, 1, true)
	elif item == "x-sp.-def":
		pm.give_stat_change(poke, battle, gs.SP_DEF, 1, true)
	elif item == "blue-flute":
		pm.cure_nv_status(gs.ASLEEP, poke, battle)
	elif item == "yellow-flute" or item == "persim-berry":
		pm.cure_confusion(poke, battle)
	elif item == "red-flute":
		pm.cure_infatuation(poke, battle)

static func can_use_item(
	trainer: tr.Trainer,
	battle: Battle,
	item: String,
	item_target_pos: String,
	move_target_pos: String = ""
) -> bool:
	if not gd.USABLE_ITEM_CHECK.has(item):
		return false

	var item_target_index = int(item_target_pos)
	if item_target_index < 0 or item_target_index >= trainer.poke_list.size():
		return false

	var poke = trainer.poke_list[item_target_index]
	if poke.embargo_count > 0:
		return false

	var move: Move = null
	if move_target_pos != "":
		var move_target_index = int(move_target_pos)
		if move_target_index < 0 or move_target_index >= poke.moves.size():
			return false
		move = poke.moves[move_target_index]

	match item:
		"antidote", "pecha-berry":
			return poke.nv_status == gs.POISONED
		"burn-heal", "rawst-berry":
			return poke.nv_status == gs.BURNED
		"ice-heal", "aspear-berry":
			return poke.nv_status == gs.FROZEN
		"awakening", "chesto-berry":
			return poke.nv_status == gs.ASLEEP
		"paralyz-heal", "cheri-berry":
			return poke.nv_status == gs.PARALYZED
		"revive", "max-revive", "revival-herb":
			return not poke.is_alive
		"full-restore":
			return poke.cur_hp < poke.max_hp or poke.nv_status or poke.v_status[gs.CONFUSED]
		"max-potion":
			return poke.cur_hp < poke.max_hp
		"full-heal", "heal-powder", "lava-cookie", "old-gateau", "lum-berry":
			return poke.nv_status or poke.v_status[gs.CONFUSED]
		"yellow-flute", "persim-berry":
			return poke.v_status[gs.CONFUSED]
		"red-flute":
			return poke.infatuation != null
		"guard-spec.":
			return not trainer.mist
		"ether", "max-ether", "leppa-berry":
			return move and move.cur_pp < move.max_pp
		"elixir", "max-elixir":
			return poke.moves.any(func(move):
				return move.cur_pp < move.max_pp
			)
		_:
			return true

func damage_calc_items(
	attacker: Pokemon, 
	defender: Pokemon, 
	battle: Battle, 
	move_data: Move
) -> void:
	if not attacker.item in gd.DMG_ITEM_CHECK:
		return
	if attacker.has_ability("klutz") or attacker.embargo_count > 0:
		return

	var item = attacker.item

	match item:
		"griseous-orb":
			if attacker.name == "giratina" and (move_data.type == "dragon" or move_data.type == "ghost"):
				move_data.power *= 1.2
		"adamant-orb":
			if attacker.name == "dialga" and (move_data.type == "dragon" or move_data.type == "steel"):
				move_data.power *= 1.2
		"lustrous-orb":
			if attacker.name == "palkia" and (move_data.type == "dragon" or move_data.type == "water"):
				move_data.power *= 1.2
		"silver-powder", "insect-plate":
			if move_data.type == "bug":
				move_data.power *= 1.2
		"soul-dew":
			if (attacker.name == "latios" or attacker.name == "latias") and (move_data.type == "dragon" or move_data.type == "psychic"):
				move_data.power *= 1.5
		"metal-coat", "iron-plate":
			if move_data.type == "steel":
				move_data.power *= 1.2
		"soft-sand", "earth-plate":
			if move_data.type == "ground":
				move_data.power *= 1.2
		"hard-stone", "stone-plate", "rock-incense":
			if move_data.type == "rock":
				move_data.power *= 1.2
		"miracle-seed", "meadow-plate", "rose-incense":
			if move_data.type == "grass":
				move_data.power *= 1.2
		"blackglasses", "dread-plate":
			if move_data.type == "dark":
				move_data.power *= 1.2
		"black-belt", "fist-plate":
			if move_data.type == "fighting":
				move_data.power *= 1.2
		"magnet", "zap-plate":
			if move_data.type == "electric":
				move_data.power *= 1.2
		"mystic-water", "sea-incense", "wave-incense", "splash-plate":
			if move_data.type == "water":
				move_data.power *= 1.2
		"sharp-beak", "sky-plate":
			if move_data.type == "flying":
				move_data.power *= 1.2
		"poison-barb", "toxic-plate":
			if move_data.type == "poison":
				move_data.power *= 1.2
		"nevermeltice", "icicle-plate":
			if move_data.type == "ice":
				move_data.power *= 1.2
		"spell-tag", "spooky-plate":
			if move_data.type == "ghost":
				move_data.power *= 1.2
		"twistedspoon", "mind-plate", "odd-incense":
			if move_data.type == "psychic":
				move_data.power *= 1.2
		"charcoal", "flame-plate":
			if move_data.type == "fire":
				move_data.power *= 1.2
		"dragon-fang", "draco-plate":
			if move_data.type == "dragon":
				move_data.power *= 1.2
		"silk-scarf":
			if move_data.type == "normal":
				move_data.power *= 1.2
		"muscle-band":
			if move_data.category == gs.PHYSICAL:
				move_data.power *= 1.1
		"wise-glasses":
			if move_data.category == gs.SPECIAL:
				move_data.power *= 1.1
		"metronome":
			if not attacker.last_successful_move_next:
				attacker.metronome_count = 1
				move_data.power *= 1.1
			elif move_data.name == attacker.last_successful_move_next.name:
				attacker.metronome_count = max(10, attacker.metronome_count + 1)
				move_data.power *= (1 + (attacker.metronome_count) / 10)
			else:
				attacker.metronome_count = 0

static func damage_mult_items(
	attacker: Pokemon,
	defender: Pokemon,
	battle: Battle,
	move_data: Move,
	t_mult: float
) -> float:
	var i_mult = 1.0

	if not attacker.item in gd.DMG_MULT_ITEM_CHECK or attacker.has_ability("klutz") or attacker.embargo_count > 0:
		return i_mult

	var item = attacker.item

	match item:
		"expert-belt":
			if t_mult > 1:
				i_mult *= 1.2
		"life-orb":
			i_mult *= 1.3

	return i_mult

static func pre_hit_berries(
	attacker: Pokemon,
	defender: Pokemon,
	battle: Battle,
	move_data: Move,
	t_mult: float
) -> float:
	var p_mult = 1.0

	if not defender.is_alive or not defender.item in gd.PRE_HIT_BERRIES or defender.has_ability("klutz") or defender.embargo_count > 0:
		return p_mult

	if t_mult > 1 and gd.PRE_HIT_BERRIES[defender.item] == move_data.type:
		_eat_item(defender, battle)
		p_mult = 0.5

	return p_mult

static func on_damage_items(poke: Pokemon, battle: Battle, move_data: Move) -> void:
	if not poke.is_alive or poke.item not in gd.ON_DAMAGE_ITEM_CHECK or poke.has_ability("klutz") or poke.embargo_count:
		return
	var thr = gs.DAMAGE_THRESHOLD
	if poke.has_ability("gluttony"):
		thr *= 2
	if poke.cur_hp >= thr:
		return
	
	var item = poke.item
	_eat_item(poke, battle)
	
	match item:
		"liechi-berry":
			pm.give_stat_change(poke, battle, gs.ATK, 1)
		"ganlon-berry":
			pm.give_stat_change(poke, battle, gs.DEF, 1)
		"salac-berry":
			pm.give_stat_change(poke, battle, gs.SPD, 1)
		"petaya-berry":
			pm.give_stat_change(poke, battle, gs.SP_ATK, 1)
		"apricot-berry":
			pm.give_stat_change(poke, battle, gs.SP_DEF, 1)
		"lansat-berry":
			poke.crit_stage = min(4, poke.crit_stage + 1)
			battle.add_text(poke.nickname + " is getting pumped!")
		"starf-berry":
			pm.give_stat_change(poke, battle, randi_range(1, 6), 2)
		"micle-berry":
			poke.next_will_hit = true
		"custap-berry":
			poke.prio_boost = true
		"enigma-berry":
			var t_mult = pm._calculate_type_ef(poke, move_data)
			if t_mult and t_mult > 1:
				_eat_item(poke, battle)
				poke.heal(max(1, poke.max_hp / 4))#TODO div entero

func pre_move_items(poke: Pokemon) -> void:
	if poke.item not in gd.PRE_MOVE_ITEM_CHECK or poke.has_ability("klutz") or poke.embargo_count:
		return
	
	var item = poke.item
	
	if item == "quick-claw":
		if randi_range(0, 4) < 1:
			poke.prio_boost = true

static func stat_calc_items(poke: Pokemon) -> void:
	if not poke.is_alive or poke.item not in gd.STAT_CALC_ITEM_CHECK or poke.has_ability("klutz") or poke.embargo_count:
		return
	
	var item = poke.item
	
	match item:
		"metal-powder":
			if poke.name == "ditto" and not poke.transformed:
				poke.stats_effective[gs.DEF] *= 2
		"quick-powder":
			if poke.name == "ditto" and not poke.transformed:
				poke.stats_effective[gs.SPD] *= 2
		"thick-club":
			if poke.name == "cubone" or poke.name == "marowak":
				poke.stats_effective[gs.ATK] *= 2
		"choice-band":
			poke.stats_effective[gs.ATK] = int(poke.stats_effective[gs.ATK] * 1.5)
			if not poke.locked_move and poke.last_successful_move_next:
				poke.locked_move = poke.last_successful_move_next.name
		"choice-specs":
			poke.stats_effective[gs.SP_ATK] = int(poke.stats_effective[gs.SP_ATK] * 1.5)
			if not poke.locked_move and poke.last_successful_move_next:
				poke.locked_move = poke.last_successful_move_next.name
		"choice-scarf":
			poke.stats_effective[gs.SPD] = int(poke.stats_effective[gs.SPD] * 1.5)
			if not poke.locked_move and poke.last_successful_move_next:
				poke.locked_move = poke.last_successful_move_next.name
		"deepseatooth":
			if poke.name == "clamperl":
				poke.stats_effective[gs.SP_ATK] *= 2
		"deepseascale":
			if poke.name == "clamperl":
				poke.stats_effective[gs.SP_DEF] *= 2
		"light-ball":
			if poke.name == "pikachu":
				poke.stats_effective[gs.ATK] *= 2
				poke.stats_effective[gs.SP_ATK] *= 2
		"iron-ball":
			poke.stats_effective[gs.SPD] /= 2#TODO div entero
			poke.grounded = true

static func status_items(poke: Pokemon, battle: Battle) -> void:
	if not poke.is_alive or poke.item not in gd.STATUS_ITEM_CHECK or poke.has_ability("klutz") or poke.embargo_count:
		return
	
	var item = poke.item
	
	match item:
		"cheri-berry":
			if poke.nv_status == gs.PARALYZED:
				_eat_item(poke, battle)
				pm.cure_nv_status(gs.PARALYZED, poke, battle)
		"chesto-berry":
			if poke.nv_status == gs.ASLEEP:
				_eat_item(poke, battle)
				pm.cure_nv_status(gs.ASLEEP, poke, battle)
		"pecha-berry":
			if poke.nv_status == gs.POISONED:
				_eat_item(poke, battle)
				pm.cure_nv_status(gs.POISONED, poke, battle)
		"rawst-berry":
			if poke.nv_status == gs.BURNED:
				_eat_item(poke, battle)
				pm.cure_nv_status(gs.BURNED, poke, battle)
		"aspear-berry":
			if poke.nv_status == gs.FROZEN:
				_eat_item(poke, battle)
				pm.cure_nv_status(gs.FROZEN, poke, battle)
		"persim-berry":
			if poke.v_status[gs.CONFUSED]:
				_eat_item(poke, battle)
				pm.cure_confusion(poke, battle)
		"lum-berry":
			if poke.nv_status or poke.v_status[gs.CONFUSED]:
				_eat_item(poke, battle)
				pm.cure_nv_status(poke.nv_status, poke, battle)
				pm.cure_confusion(poke, battle)
		"mental-herb":
			if poke.infatuation:
				_consume_item(poke, battle)
				pm.cure_infatuation(poke, battle)
		"destiny-knot":
			if poke.infatuation and poke.enemy.current_poke.is_alive and not poke.enemy.current_poke.infatuation:
				pm.infatuate(poke, poke.enemy.current_poke, battle)

static func on_hit_items(attacker: Pokemon, defender: Pokemon, battle: Battle, move_data: Move) -> void:
	if not move_data or not defender.item in gd.ON_HIT_ITEM_CHECK or defender.has_ability("klutz") or defender.embargo_count:
		return

	var t_mult = pm._calculate_type_ef(defender, move_data)
	var item = defender.item

	if item == "jaboca-berry":
		if move_data.category == gs.PHYSICAL and attacker.is_alive:
			_eat_item(defender, battle)
			attacker.take_damage(max(1, attacker.max_hp / 8))#TODO div entero
	elif item == "rowap-berry":
		if move_data.category == gs.SPECIAL and attacker.is_alive:
			_eat_item(defender, battle)
			attacker.take_damage(max(1, attacker.max_hp / 8))#TODO div entero
	elif item == "sticky-barb":
		if move_data.name in gd.CONTACT_CHECK and attacker.is_alive and not attacker.item:
			battle.add_text(attacker.nickname + " received " + defender.nickname + "'s Sticky Barb!")
			attacker.give_item("sticky-barb")


static func homc_items(attacker: Pokemon, defender: Pokemon, battlefield: Battlefield, battle: Battle, move_data: Move, is_first: bool) -> float:
	var i_mult = 1.0

	if (not defender.item in gd.HOMC_ITEM_CHECK or defender.has_ability("klutz") or defender.embargo_count) and (not attacker.item in gd.HOMC_ITEM_CHECK or attacker.has_ability("klutz") or attacker.embargo_count):
		return i_mult

	if defender.item == "brightpowder" or defender.item == "lax-incense":
		i_mult *= 0.9

	if attacker.item == "wide-lens":
		i_mult *= 1.1
	elif attacker.item == "zoom-lens" and not is_first:
		i_mult *= 1.2

	return i_mult

static func end_turn_items(poke: Pokemon, battle: Battle) -> void:
	if not poke.is_alive or not poke.item in gd.END_TURN_ITEM_CHECK or poke.has_ability("klutz") or poke.embargo_count:
		return

	var item = poke.item

	if item == "oran-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(10)
	elif item == "sitrus-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(max(1, poke.max_hp / 4))#TODO div entero
	elif item == "figy-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
			if not poke.nature or poke.nature in ["modest", "timid", "calm", "bold"]:
				pm.confuse(poke, battle)
	elif item == "wiki-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
			if not poke.nature or poke.nature in ["adamant", "jolly", "careful", "impish"]:
				pm.confuse(poke, battle)
	elif item == "mago-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
			if not poke.nature or poke.nature in ["brave", "quiet", "sassy", "relaxed"]:
				pm.confuse(poke, battle)
	elif item == "aguav-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
			if not poke.nature or poke.nature in ["naughty", "rash", "naive", "lax"]:
				pm.confuse(poke, battle)
	elif item == "iapapa-berry":
		if poke.cur_hp < poke.max_hp * gs.BERRY_THRESHOLD:
			_eat_item(poke, battle)
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
			if not poke.nature or poke.nature in ["lonely", "mild", "gentle", "hasty"]:
				pm.confuse(poke, battle)
	elif item == "leftovers":
		if not poke.cur_hp == poke.max_hp:
			battle.add_text(poke.nickname + " restored a little HP using its Leftovers!")
			var text_skip=true
			poke.heal(max(1, poke.max_hp / 16), text_skip)#TODO div entero
	elif item == "black-sludge":
		if "poison" in poke.types:
			battle.add_text(poke.nickname + " restored a little HP using its Black Sludge!")
			var text_skip=true
			poke.heal(max(1, poke.max_hp / 16), text_skip)#TODO div entero
		elif not poke.has_ability("magic-guard"):
			battle.add_text(poke.nickname + " was hurt by its Black Sludge!")
			poke.take_damage(max(1, poke.max_hp / 8))#TODO div entero
	elif item == "toxic-orb":
		if not poke.nv_status:
			pm.give_nv_status(gs.BADLY_POISONED, poke, battle)
	elif item == "flame-orb":
		if not poke.nv_status:
			pm.give_nv_status(gs.BURNED, poke, battle)
	elif item == "sticky-barb":
		battle.add_text(poke.nickname + " was hurt by its Sticky Barb!")
		poke.take_damage(max(1, poke.max_hp / 8))#TODO div entero


static func post_damage_items(attacker: Pokemon, battle: Battle, dmg: int) -> void:
	if attacker.item not in gd.POST_DAMAGE_ITEM_CHECK or attacker.has_ability("klutz") or attacker.embargo_count:
		return

	if attacker.item == "shell-bell":
		if attacker.is_alive and dmg:
			battle.add_text(attacker.nickname + " restored a little HP using its Shell Bell!")
			var text_skip=true
			attacker.heal(max(1, dmg / 8), text_skip)#TODO div entero
	if attacker.item == "life-orb":
		if attacker.is_alive and dmg:
			battle.add_text(attacker.nickname + " lost some of its HP!")
			attacker.take_damage(max(1, attacker.max_hp / 10))#TODO div entero


static func _consume_item(poke: Pokemon, battle: Battle) -> void:
	battle.add_text(poke.nickname + " used its " + pm.cap_name(poke.item) + "!")


static func _eat_item(poke: Pokemon, battle: Battle) -> void:
	battle.add_text(poke.nickname + " ate its " + pm.cap_name(poke.item) + "!")
	poke.give_item("")#TODO posible error item vacio
