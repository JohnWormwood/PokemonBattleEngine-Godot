class_name Pokemon

# Importa las clases necesarias

const bt = preload("res://gdScripts/pokeSim/core/battle.gd")
const tr = preload("res://gdScripts/pokeSim/core/trainer.gd")

const pa = preload("res://gdScripts/pokeSim/util/process_ability.gd")
const pi = preload("res://gdScripts/pokeSim/util/process_item.gd")
const pm = preload("res://gdScripts/pokeSim/util/process_move.gd")



const gs = preload("res://gdScripts/pokeSim/conf/global_settings.gd")
const gd = preload("res://gdScripts/pokeSim/conf/global_data.gd")
"""
		Creating a Pokemon object involves five required and seven optional fields.

		Required:

		- name_or_id: this can either be a Pokemon's real name such as 'Pikachu' or its Pokedex id (25)
		- stats: either the Pokemon's actual stats (stats_actual) or its ivs, evs, and nature
		- level: this is the Pokemon's level as an interger between 1 and 100 inclusive by default
		- moves: this is a list of names of the Pokemon's moves, max of 4 by defeault
		- gender: this is the Pokemon's gender, either 'male', 'female', or 'typeless' by default

		Optional:
		- ability: Pokemon's ability; if not used, assumed that Pokemon has ability not relevant to battle
		- nature: Pokemon's nature, not required if stats_actual provided; if not used, any effect that
		takes nature into account will process the worst-case scenario for the Pokemon
		- item: Pokemon's held item
		- cur_hp: Pokemon's current hp, used if Pokemon's current hp is less than its max hp
		- status: Pokemon's non-volatile status such as poisoned or paralyzed
		- friendship: Pokemon's friendship value as an int between 0 and 255 by default
		- nickname: Pokemon's unique nickname
		"""
#TODO optimizar variables
#region Var
var in_battle
var cur_battle
var v_status
var stat_stages
var accuracy_stage
var evasion_stage
var crit_stage
var substitute
var mr_count
var db_count
var perish_count
var encore_count
var bide_count
var bide_dmg
var protect_count
var embargo_count
var hb_count
var uproar
var stockpile
var charged
var taunt
var inv_count
var ability_count
var metronome_count
var last_damage_taken

var last_move
var last_successful_move
var last_move_next
var last_successful_move_next
var last_move_hit_by
var last_consumed_item
var copied
var binding_type
var binding_poke
var encore_move
var mr_target
var infatuation
var r_types
var mf_move
var locked_move

var in_air
var in_ground
var in_water
var grounded
var ingrain
var invulnerable
var trapped
var perma_trapped
var minimized
var rage
var recharging
var biding
var df_curl
var protect
var endure
var transformed
var tormented
var magic_coat
var foresight_target
var me_target
var snatch
var mud_sport
var water_sport
var power_trick
var ability_suppressed
var ability_activated
var item_activated
var sp_check
var magnet_rise
var has_moved
var prio_boost
var next_will_hit
var unburden
var turn_damage
var moves
var ability
var o_moves
var o_ability
var o_item
var item
var h_item
var old_pp

# Declaración de variables de instancia
var name
var id
var level
var gender
var nature
var stats_actual
var cur_hp
var ivs
var evs
var status
var nickname
var friendship
var stats_base
var types: Variant
var base
var height
var weight
var base_exp
var gen
var nature_effect = []
var nv_status
var nv_counter
var is_alive
var max_hp
var stats_effective
var next_moves: Array
var original
var trainer
var r_amt
var enemy
#endregion

# Constructor de la clase
func _init(
	name_or_id: Variant,
	level: int,
	moves: Array,
	gender: String,
	nature: String = "",
	stats_actual: Array = [],
	ability: String = "",
	cur_hp: int = -1,
	ivs: Array = [],
	evs: Array = [],
	item: String = "",
	status: String = "",
	nickname: String = "",
	friendship: int = 0
):
	# Creación del objeto Pokémon
	self.stats_base = PokeSim.get_pokemon(name_or_id)
	if not stats_base:
		push_error("Attempted to create Pokemon with invalid name or id")
		return

	id = stats_base[gs.NDEX]
	name = stats_base[gs.NAME]
	types = [stats_base[gs.TYPE1], stats_base[gs.TYPE2]]
	# Genera la lista de stats_base usando map
	base = []
	for i in range(gs.STAT_START, gs.STAT_START + gs.STAT_NUM):
		base.append(int(stats_base[i]))
	height = int(stats_base[gs.HEIGHT])
	weight = int(stats_base[gs.WEIGHT])
	base_exp = int(stats_base[gs.BASE_EXP])
	gen = int(stats_base[gs.GEN])

	if not (level >= gs.LEVEL_MIN and level <= gs.LEVEL_MAX):
		push_error("Attempted to create Pokemon with invalid level")
		return
	self.level = level

	if not (gender and gender.to_lower() in gs.POSSIBLE_GENDERS):
		push_error("Attempted to create Pokemon with invalid gender")
		return
	self.gender = gender.to_lower()

	if not stats_actual and not ivs and not evs:
		push_error("Attempted to create Pokemon without providing stats information")
		return

	if stats_actual and (ivs or evs):
		push_error("Attempted to create Pokemon with conflicting stats information")
		return

	if stats_actual:
		if not (stats_actual is Array and stats_actual.size() == gs.STAT_NUM):
			push_error("Attempted to create Pokemon with invalid stats")
			return
		var valid_stats = true
		for s in stats_actual:
			if not (typeof(s) == TYPE_INT and s > gs.STAT_ACTUAL_MIN and s < gs.STAT_ACTUAL_MAX):
				valid_stats = false
				break
		if not valid_stats:
			push_error("Attempted to create Pokemon with invalid stats")
		self.stats_actual = stats_actual
		self.ivs = []
		self.evs = []
		self.nature = ""
		self.nature_effect = []
	else:
		if not (ivs is Array and evs is Array and ivs.size() == gs.STAT_NUM and evs.size() == gs.STAT_NUM):
			push_error("Attempted to create Pokemon with invalid evs or ivs")
			return
		var valid_ivs = true
		for iv in ivs:
			if not (typeof(iv) == TYPE_INT and iv >= gs.IV_MIN and iv <= gs.IV_MAX):
				valid_ivs = false
				break
		if not valid_ivs:
			push_error("Attempted to create Pokemon with invalid ivs")
			return
		self.ivs = ivs
		var valid_evs = true
		var total_ev = 0
		for ev in evs:
			if not (typeof(ev) == TYPE_INT and ev >= gs.EV_MIN and ev <= gs.EV_MAX):
				valid_evs = false
				break
			total_ev += ev
		if not valid_evs or total_ev > gs.EV_TOTAL_MAX:
			push_error("Attempted to create Pokemon with invalid evs")
			return
		self.evs = evs
		self.nature_effect = PokeSim.nature_conversion(nature.to_lower())
		if not self.nature_effect:
			push_error("Attempted to create Pokemon without providing its nature")
			return
		self.nature = nature.to_lower()
		calculate_stats_actual()

	self.max_hp = self.stats_actual[gs.HP]
	if cur_hp >= 0 and (cur_hp < 0 or cur_hp > self.max_hp):
		push_error("Attempted to create Pokemon with invalid hp value")
		return
	self.cur_hp = cur_hp if cur_hp >= 0 else self.stats_actual[gs.HP]

	var moves_data = PokeSim.get_move_data(moves)
	if not moves_data:
		push_error("Attempted to create Pokemon with invalid moveset")
		return
		
	self.moves = []
	for move_d in moves_data:
		self.moves.append(Move.new(move_d))

	for i in range(self.moves.size()):
		self.moves[i].pos = i
	self.o_moves = self.moves

	if ability and (not ability.is_empty() and not PokeSim.check_ability(ability.to_lower())):
		push_error("Attempted to create Pokemon with invalid ability")
		return
	self.o_ability = ability.to_lower() if not ability.is_empty() else ""
	self.ability = self.o_ability

	if item and (not item.is_empty() and not PokeSim.check_item(item.to_lower())):
		push_error("Attempted to create Pokemon with invalid held item")
		return
	self.o_item = item.to_lower() if not item.is_empty() else ""

	if nickname and not nickname.is_empty():
		self.nickname = nickname
	else:
		self.nickname = self.name
	self.nickname = self.nickname.to_upper()
	self.original = null
	self.trainer = self.trainer
	if status:
		if not status in gs.NV_STATUSES:
			push_error("Attempted to create Pokemon afflicted with invalid status")
			return
		self.nv_status = gs.NV_STATUSES[status]
	else:
		self.nv_status = 0
	if self.nv_status == gs.NV_STATUSES["asleep"]:
		self.nv_counter = randi_range(2, 6)
	elif self.nv_status == gs.NV_STATUSES["badly poisoned"]:
		self.nv_counter = 1
	else:
		self.nv_counter = 0

	if not (friendship is int and friendship >= 0 and friendship <= 255):
		push_error("Attempted to create Pokemon with invalid friendship value")
		return
	self.friendship = friendship

	self.is_alive = self.cur_hp != 0
	self.in_battle = false
	self.transformed = false
	self.invulnerable = false

# Cálculo de estadísticas actuales
func calculate_stats_actual():
	var stats_actual = []
	var nature_stat_changes = []
	for _i in range(6):
		nature_stat_changes.append(1.0)
	nature_stat_changes[self.nature_effect[0]] = gs.NATURE_INC
	nature_stat_changes[self.nature_effect[1]] = gs.NATURE_DEC
	stats_actual.append(
		(((2 * self.base[0] + self.ivs[0] + self.evs[0] / 4) * self.level) / 100) + 10 #TODO div de enteros //
	)
	for s in range(1, gs.STAT_NUM):
		stats_actual.append(
			(
				(((2 * self.base[s] + self.ivs[s] + self.evs[s] / 4) * self.level) / 100) + 5#TODO div de enteros //
			) * nature_stat_changes[s]
		)
	self.stats_actual = []
	for stat in stats_actual:
		self.stats_actual.append(int(stat))

func calculate_stats_effective(ignore_stats: bool = false):
	if not ignore_stats:
		for s in range(1, 6):
			self.stats_effective[s] = max(
				1,
				int(
					self.stats_actual[s]
					* max(2, 2 + self.stat_stages[s])
					/ max(2, 2 - self.stat_stages[s])
				)
			)
	else:
		self.stats_effective = self.stats_actual.duplicate()

	pa.stat_calc_abilities(self)
	pi.stat_calc_items(self)

	if self.nv_status == gs.PARALYZED and not has_ability("quick-feet"):
		self.stats_effective[gs.SPD] = floor(self.stats_effective[gs.SPD] / 4)  #TODO División a entero

func reset_stats():
	# Resets various battle-related stats and states of the Pokemon.
	self.v_status = []
	for i in range(gs.V_STATUS_NUM):
		self.v_status.append(0)
	self.stat_stages = []
	for i in range(gs.STAT_NUM):
		self.stat_stages.append(0)
	self.accuracy_stage = 0
	self.evasion_stage = 0
	self.crit_stage = 0
	self.substitute = 0
	self.mr_count = 0
	self.db_count = 0
	self.perish_count = 0
	self.encore_count = 0
	self.bide_count = 0
	self.bide_dmg = 0
	self.protect_count = 0
	self.embargo_count = 0
	self.hb_count = 0
	self.uproar = 0
	self.stockpile = 0
	self.charged = 0
	self.taunt = 0
	self.inv_count = 0
	self.ability_count = 0
	self.metronome_count = 0
	self.last_damage_taken = 0
	self.last_move = null
	self.last_successful_move = null
	self.last_move_next = null
	self.last_successful_move_next = null
	self.last_move_hit_by = null
	self.last_consumed_item = null
	self.copied = null
	self.binding_type = null
	self.binding_poke = null
	self.encore_move = null
	self.mr_target = null
	self.infatuation = null
	self.r_types = null
	self.mf_move = null
	self.locked_move = null
	self.in_air = false
	self.in_ground = false
	self.in_water = false
	self.grounded = false
	self.ingrain = false
	self.invulnerable = false
	self.trapped = false
	self.perma_trapped = false
	self.minimized = false
	self.rage = false
	self.recharging = false
	self.biding = false
	self.df_curl = false
	self.protect = false
	self.endure = false
	self.transformed = false
	self.tormented = false
	self.magic_coat = false
	self.foresight_target = false
	self.me_target = false
	self.snatch = false
	self.mud_sport = false
	self.water_sport = false
	self.power_trick = false
	self.ability_suppressed = false
	self.ability_activated = false
	self.item_activated = false
	self.sp_check = false
	self.magnet_rise = false
	self.has_moved = false
	self.prio_boost = false
	self.next_will_hit = false
	self.unburden = false
	self.turn_damage = false
	self.moves = self.o_moves
	self.ability = self.o_ability
	
	if self.transformed:
		self.reset_transform()
	
	self.item = self.o_item
	self.h_item = self.item
	self.old_pp = []
	
	for move in self.moves:
		self.old_pp.append(move.cur_pp)
	
	self.next_moves.clear()
	self.types = [self.stats_base[gs.TYPE1], self.stats_base[gs.TYPE2]]
	self.stats_effective = self.stats_actual

func start_battle(battle: bt):
	#Initializes the Pokemon for battle, resets stats and sets up the enemy.
	#Parameters:
	#- battle (Battle): The battle instance to start.
	
	self.cur_battle = battle
	self.in_battle = true
	self.reset_stats()
	self.enemy = self.cur_battle.t2 if self.cur_battle.t1 == self.trainer else self.cur_battle.t1

func take_damage(damage: int, enemy_move: Move = null) -> int:
	#Applies damage to the Pokemon and handles related effects.
	#
	#Parameters:
	#- damage (int): The amount of damage to apply.
	#- enemy_move (Move): The move causing the damage.
	#
	#Returns:
	#- int: The actual amount of damage taken.
	if not damage or damage < 0 or not self.cur_battle:
		return 0
	
	if self.substitute:
		self.cur_battle.add_text("The substitute took damage for " + self.nickname + "!")
		if self.substitute - damage <= 0:
			self.substitute = 0
			self.cur_battle.add_text(self.nickname + "'s substitute faded!")
		else:
			self.substitute -= damage
		return 0

	if enemy_move:
		self.last_move_hit_by = enemy_move
		if pa.on_hit_abilities(self.enemy.current_poke, self, self.cur_battle, enemy_move) or not self.cur_battle:
			return 0
		pi.on_hit_items(self.enemy.current_poke, self, self.cur_battle, enemy_move)
		if not self.cur_battle:
			return 1 #NULL

	if self.bide_count:
		self.bide_dmg += damage

	if self.cur_hp - damage <= 0:
		self.last_damage_taken = self.cur_hp
		if _endure_check() or _fband_check() or _fsash_check():
			self.cur_hp = 1
			return self.last_damage_taken - 1
		_db_check()
		if self.last_move and self.last_move.name == "grudge" and self.enemy_move and self.enemy.current_poke.is_alive:
			self.cur_battle.add_text(self.enemy.current_poke.name + "'s " + enemy_move.name + " lost all its PP due to the grudge!")
			enemy_move.cur_pp = 0
		if not self.cur_battle:
			return 1# posible error null
		self.cur_hp = 0
		self.is_alive = false
		reset_stats()
		self.cur_battle._faint_check()
		_aftermath_check(enemy_move)
		return self.last_damage_taken

	if self.rage and self.stat_stages[gs.ATK] < 6:
		self.stat_stages[gs.ATK] += 1
		self.cur_battle.add_text(self.nickname + "'s rage is building!")

	self.turn_damage = true
	self.cur_hp -= damage
	self.last_damage_taken = damage
	pi.on_damage_items(self, self.cur_battle, enemy_move)
	return self.last_damage_taken

func faint():
	#Handles the Pokemon fainting.
	if not self.is_alive:
		return

	self.cur_hp = 0
	self.is_alive = false
	reset_stats()
	self.cur_battle._faint_check()

func heal(heal_amount: int, text_skip: bool = false) -> int:
	#Heals the Pokemon by a certain amount of HP.
	#Parameters:
	#- heal_amount (int): The amount of HP to heal.
	#- text_skip (bool): If true, skips adding text to the battle log.
	#Returns:
	#- int: The actual amount of HP healed.

	if not self.cur_battle or heal_amount <= 0:
		return 0

	var amt: int
	if self.cur_hp + heal_amount >= self.max_hp:
		amt = self.max_hp - self.cur_hp
		self.cur_hp = self.max_hp
		var r_amt = amt
	else:
		self.cur_hp += heal_amount
		self.r_amt = heal_amount

	if not text_skip:
		self.cur_battle.add_text(self.nickname + " regained health!")
	
	return self.r_amt

func get_move_data(move_name: String) -> Move:
	#Retrieves the data of a specific move.
	#Parameters:
	#- move_name (String): The name of the move.
	#Returns:
	#- Move: The move object if found, otherwise null.
	if self.copied and move_name == self.copied.name:
		return self.copied

	for move in self.moves:
		if move.name == move_name:
			return move

	return null

func is_move(move_name: String) -> bool:
	#Checks if the Pokemon has a specific move.
	#Parameters:
	#- move_name (String): The name of the move.
	#Returns:
	#- bool: True if the move is available, otherwise false.
	if self.copied and self.copied.cur_pp:
		if move_name == self.copied.name:
			return true
		if move_name == "mimic":
			return false

	var av_moves = get_available_moves()
	for move in av_moves:
		if move.name == move_name:
			return true

	return false

func get_available_moves() -> Array:
	#Gets the list of moves the Pokemon can currently use.
	#Returns:
	#- Array: A list of available moves.

	if not self.next_moves.is_empty() or self.recharging:
		return []

	var av_moves = []
	for move in self.moves:
		if not move.disabled and move.cur_pp:
			av_moves.append(move)

	if self.copied and self.copied.cur_pp:
		for i in range(av_moves.size()):
			if av_moves[i].name == "mimic":
				av_moves[i] = self.copied

	if self.tormented and av_moves.size() and self.last_move:
		var filtered_moves = []
		for move in av_moves:
			if move.name != self.last_move.name:
				filtered_moves.append(move)
		av_moves = filtered_moves

	if self.taunt and av_moves.size():
		var filtered_moves = []
		for move in av_moves:
			if move.category != gs.STATUS:
				filtered_moves.append(move)
		av_moves = filtered_moves

	if self.grounded and av_moves.size():
		var filtered_moves = []
		for move in av_moves:
			if move not in gd.GROUNDED_CHECK:
				filtered_moves.append(move)
		av_moves = filtered_moves

	if self.hb_count and av_moves.size():
		var filtered_moves = []
		for move in av_moves:
			if move not in gd.HEAL_BLOCK_CHECK:
				filtered_moves.append(move)
		av_moves = filtered_moves

	if self.trainer.imprisoned_poke and self.trainer.imprisoned_poke == self.enemy.current_poke and av_moves.size():
		var i_moves = []
		for move in self.trainer.imprisoned_poke.moves:
			i_moves.append(move.name)
		
		var filtered_moves = []
		for move in av_moves:
			if move.name not in i_moves:
				filtered_moves.append(move)
		av_moves = filtered_moves

	if has_ability("truant") and self.last_move and av_moves.size():
		var filtered_moves = []
		for move in av_moves:
			if move.name != self.last_move.name:
				filtered_moves.append(move)
		av_moves = filtered_moves

	if self.locked_move:
		var filtered_moves = []
		for move in av_moves:
			if move.name == self.locked_move:
				filtered_moves.append(move)
		av_moves = filtered_moves
	
	return av_moves


func transform(target: Pokemon) -> void:
	#Transforms the Pokemon into another Pokemon, copying its attributes and moves.
	#Parameters:
	#- target (Pokemon): The Pokemon to transform into.

	if self.transformed or target.transformed:
		return
	
	# Guardar el estado original del Pokémon antes de transformarse
	var original = [
		self.name,
		self.types,
		self.height,
		self.weight,
		self.base_exp,
		self.gen,
		self.ability,
		self.stats_base.duplicate(),
		self.ivs.duplicate() if self.ivs else null,
		self.evs.duplicate() if self.evs else null,
		self.nature,
		self.nature_effect,
		[]  # Lista vacía para los movimientos, se rellenará luego
	]
	
	# Crear una copia de los movimientos originales
	for move in self.moves:
		original[12].append(move.get_tcopy())

	# Asignar las características del target al Pokémon actual
	self.name = target.name
	self.types = target.types
	self.height = target.height
	self.weight = target.weight
	self.base_exp = target.base_exp
	self.gen = target.gen
	self.ability = target.ability
	
	# Obtener una copia de los movimientos del target
	self.moves = []
	for move in target.moves:
		var new_move = move.get_tcopy()
		new_move.max_pp = min(5, new_move.max_pp)
		new_move.cur_pp = new_move.max_pp
		self.moves.append(new_move)

	# Asignar estadísticas y etapas del target
	self.stats_actual = target.stats_actual.duplicate()
	self.stat_stages = target.stat_stages.duplicate()
	self.accuracy_stage = target.accuracy_stage
	self.evasion_stage = target.evasion_stage
	self.crit_stage = target.crit_stage
	
	# Recalcular las estadísticas del Pokémon después de la transformación
	calculate_stats_effective()

	# Marcar al Pokémon como transformado
	self.transformed = true


func reset_transform():
	"""
	Resets the Pokemon to its original state after transformation.
	"""
	if not self.transformed or not self.original:
		return

	self.name = self.original[0]
	self.types = self.original[1]
	self.height = self.original[2]
	self.weight = self.original[3]
	self.base_exp = self.original[4]
	self.gen = self.original[5]
	self.ability = self.original[6]
	self.stats_base = self.original[7]
	self.ivs = self.original[8]
	self.evs = self.original[9]
	self.nature = self.original[10]
	self.nature_effect = self.original[11]
	self.moves = self.original[12]
	self.stats_actual = self.original[13]
	self.original = null
	self.transformed = false
func give_ability(ability: String):
	#Sets the Pokemon's ability and initializes related states.
	#Parameters:
	#- ability (String): The name of the ability to give.
	self.ability = ability
	self.ability_activated = false
	self.ability_suppressed = false
	self.ability_count = 0
	pa.selection_abilities(self, self.cur_battle.battlefield, self.cur_battle)

func battle_end_reset():
	#Resets the Pokemon's state at the end of the battle.

	if self.transformed:
		reset_transform()
	reset_stats()
	self.in_battle = false
	self.cur_battle = null
	self.enemy = null

func switch_out():
	#Resets stats and cures status conditions when the Pokemon switches out.
	if self.transformed:
		reset_transform()
	reset_stats()
	if has_ability("natural-cure") and self.nv_status:
		pm.cure_nv_status(self.nv_status, self, self.cur_battle)

func update_last_moves():
	#Updates the last move and last successful move tracking.
	if self.last_move_next:
		self.last_move = self.last_move_next
		self.last_move_next = null
	if self.last_successful_move_next:
		self.last_successful_move = self.last_successful_move_next
		self.last_successful_move_next = null

func reduce_disabled_count():
	#Reduces the disabled count of moves by 1 if they are disabled.
	
	for move in self.moves:
		if move.disabled:
			move.disabled -= 1

func no_pp() -> bool:
	#Returns true if no available moves have PP or are blocked.

	for move in get_available_moves():
		if move.cur_pp and not move.disabled and not move.encore_blocked:
			return false
	return true


func can_switch_out() -> bool:
	#Determines if the Pokemon can switch out of battle.
	#
	#Returns:
	#- bool: True if the Pokemon can switch out, False otherwise.

	if self.item == "shed-shell":
		return true
	if (
		self.trapped or
		self.perma_trapped or
		self.recharging or
		not self.next_moves.is_empty()
	):
		return false
	
	var enemy_poke = self.enemy.current_poke
	if enemy_poke.is_alive and enemy_poke.has_ability("shadow-tag"):
		return false
	
	if (
		"steel" in self.types and
		enemy_poke.is_alive and
		enemy_poke.has_ability("magnet_pull")
	):
		return false
	
	if (
		(self.grounded or (not "flying" in self.types and not has_ability("levitate"))) and
		enemy_poke.is_alive and
		enemy_poke.has_ability("arena-trap")
	):
		return false
	
	return true

func can_use_item() -> bool:
	"""
	Checks if the Pokemon can use its item.
	
	Returns:
	- bool: True if the item can be used, False otherwise.
	"""
	return not self.embargo_count

func has_ability(ability_name: String) -> bool:
	"""
	Checks if the Pokemon has a specific ability.
	
	Parameters:
	- ability_name (String): The name of the ability to check.
	
	Returns:
	- bool: True if the Pokemon has the ability, False otherwise.
	"""
	return not self.ability_suppressed and self.ability == ability_name

func reset_stages():
	"""
	Resets the Pokemon's stat stages.
	"""
	self.accuracy_stage = 0
	self.evasion_stage = 0
	self.crit_stage = 0
	# Crear una lista de 0s con una longitud de gs.STAT_NUM
	self.stat_stages = []
	for i in range(gs.STAT_NUM):
		self.stat_stages.append(0)

func _endure_check() -> bool:
	"""
	Checks if the Pokemon is using Endure.
	
	Returns:
	- bool: True if Endure is active, False otherwise.
	"""
	if self.endure:
		self.cur_battle.add_text(self.nickname + " endured the hit!")
		self.cur_hp = 1
		return true
	return false

func _fband_check() -> bool:
	"""
	Checks if the Pokemon is using Focus Band.
	
	Returns:
	- bool: True if Focus Band prevents fainting, False otherwise.
	"""
	if self.item == "focus-band" and randf_range(0, 10) < 1:
		self.cur_battle.add_text(self.nickname + " hung on using its Focus Band!")
		return true
	return false

func _fsash_check() -> bool:
	"""
	Checks if the Pokemon is using Focus Sash.
	
	Returns:
	- bool: True if Focus Sash prevents fainting, False otherwise.
	"""
	if (
		self.item == "focus-sash" and
		self.cur_hp == self.max_hp and
		not self.item_activated
	):
		self.cur_battle.add_text(self.nickname + " hung on using its Focus Sash!")
		self.item_activated = true
		return true
	return false

func _db_check() -> bool:
	"""
	Checks if the Pokemon's Dragon Breath move should cause the opponent to faint.
	
	Returns:
	- bool: True if the opponent faints due to Dragon Breath, False otherwise.
	"""
	if not self.db_count:
		return false
	
	var enemy_poke = self.enemy.current_poke
	self.cur_battle.add_text(self.nickname + " took down " + enemy_poke.nickname + " down with it!")
	enemy_poke.faint()
	return true

func _aftermath_check(enemy_move: Move):
	"""
	Checks if Aftermath ability should cause damage to the opponent.
	
	Parameters:
	- enemy_move (Move): The move used by the opponent.
	"""
	if (
		has_ability("aftermath") and
		enemy_move in gd.CONTACT_CHECK and
		self.enemy.current_poke.is_alive and
		not self.enemy.current_poke.has_ability("damp")
	):
		self.enemy.current_poke.take_damage(
			max(1, self.enemy.current_poke.max_hp / 4)#TODO div enteros
		)
		self.cur_battle.add_text(
			self.enemy.current_poke.nickname +" was hurt by " +
			self.nickname +"'s Aftermath!"
		)

func give_item(item: String):
	"""
	Sets the Pokemon's item and initializes related states.
	
	Parameters:
	- item (String): The name of the item to give.
	"""
	self.item = item
	self.h_item = item
	if not item:
		self.unburden = true
	pi.status_items(self, self.cur_battle)

func hidden_power_stats() -> Variant:
	#Calculates the type and power of Hidden Power based on IVs.
	#
	#Returns:
	#- Tuple: Contains the type and power of Hidden Power, or null if IVs are not set.

	if not self.ivs:
		return null
	
	var hp_type = 0
	for i in range(6):
		hp_type += pow(2, i) * (self.ivs[i] & 1)
	hp_type = floor((hp_type * 15) / 63)  # División y redondeo a entero
	
	var hp_power = 0
	for i in range(6):
		hp_power += pow(2, i) * ((self.ivs[i] >> 1) & 1)
	hp_power = floor((hp_power * 40) / 63 + 30)  # División y redondeo a entero
	
	# Se devuelve una tupla usando el operador `,`
	return [gd.HP_TYPES[hp_type], hp_power]

func restore_pp(move_name: String, amount: int):
	"""
	Restores PP for a specific move and updates the battle log.
	
	Parameters:
	- move_name (String): The name of the move to restore PP for.
	- amount (int): The amount of PP to restore.
	"""
	for move in self.moves:
		if move.name == move_name:
			move.cur_pp = min(move.cur_pp + amount, move.max_pp)
	self.cur_battle.add_text(
		self.nickname + "'s " + self.pm.cap_name(move_name) + "'s pp was restored!"
	)

func restore_all_pp(amount: int):
	"""
	Restores PP for all moves and updates the battle log.
	
	Parameters:
	- amount (int): The amount of PP to restore for each move.
	"""
	for move in self.moves:
		move.cur_pp = min(move.cur_pp + amount, move.max_pp)
	self.cur_battle.add_text(self.nickname + "'s move's pp were restored!")
