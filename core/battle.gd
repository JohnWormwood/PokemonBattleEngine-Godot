class_name Battle
# Importa las clases necesarias desde los módulos
# Nota: Las importaciones deben ser relativas a la estructura del proyecto Godot
# Asegúrate de tener los scripts y las rutas correctamente configuradas.

# Importa las clases necesarias
const pk = preload("res://gdScripts/pokeSim/core/pokemon.gd")
const tr = preload("res://gdScripts/pokeSim/core/trainer.gd")

const pm = preload("res://gdScripts/pokeSim/util/process_move.gd")
const pa = preload("res://gdScripts/pokeSim/util/process_ability.gd")
const pi = preload("res://gdScripts/pokeSim/util/process_item.gd")

const gs = preload("res://gdScripts/pokeSim/conf/global_settings.gd")
const gd = preload("res://gdScripts/pokeSim/conf/global_data.gd")

#TODO optimizar var

var t1: tr.Trainer
var t2: tr.Trainer
var terrain
var weather
var battle_started
var all_text
var cur_text
var t1_faint
var t2_faint
var winner
var last_move
var last_move_next
var turn_count
var t1_fainted
var t2_fainted
var battlefield

# Constructor de la clase Battle
func _init(t1: tr.Trainer, t2: tr.Trainer, terrain: String = gs.OTHER_TERRAIN, weather: String = gs.CLEAR):
	#Crear un objeto Battle requiere exactamente dos entrenadores (Trainer) con un equipo válido
	#y sin Pokémon repetidos o que ya estén en batalla.
	#El orden de los entrenadores no afecta las mecánicas de batalla.
	#Two optional parameters can be added :
		#- terrain: the name of the terrain
		#- weather: the starting weather

	if not t1 is tr.Trainer or not t2 is tr.Trainer:
		push_error("Attempted to create Battle with invalid Trainer")
		return
	
	if t1.in_battle or t2.in_battle:
		push_error("Attempted to create Battle with Trainer already in battle")
		return
	
	for t1_poke in t1.poke_list:
		for t2_poke in t2.poke_list:
			if t1_poke == t2_poke:
				push_error("Attempted to create Battle with Pokemon that is in both Trainers' parties")
				return
	
	for t1_poke in t1.poke_list:
		if t1_poke.in_battle:
			push_error("Attempted to create Battle with Pokemon already in battle")
			return
	
	for t2_poke in t2.poke_list:
		if t2_poke.in_battle:
			push_error("Attempted to create Battle with Pokemon already in battle")
			return

	# Asignación de los entrenadores y estados iniciales
	self.t1 = t1
	self.t2 = t2
	self.battle_started = false
	self.all_text = []
	self.cur_text = []

# Método para iniciar la batalla
func start():
	self.t1.start_pokemon(self)
	self.t2.start_pokemon(self)
	self.t1_faint = false
	self.t2_faint = false
	self.battle_started = true
	self.winner = null
	self.last_move = null
	self.last_move_next = null
	self.turn_count = 0
	
	add_text(self.t1.name + " sent out " + self.t1.current_poke.nickname + "!")
	add_text(self.t2.name + " sent out " + self.t2.current_poke.nickname + "!")

func turn(t1_turn: Array, t2_turn: Array) -> bool:
	self.turn_count += 1
	if not self.battle_started:
		push_error("Cannot use turn on Battle that hasn't started")
		return false
	if self.is_finished():
		return false
	
	# Procesar movimientos de los entrenadores
	var t1_command = t1_turn.duplicate()
	var t2_command = t2_turn.duplicate()
	var t1_move_data = null
	var t2_move_data = null
	var t1_mv_check_bypass = false
	var t2_mv_check_bypass = false
	var t1_first = null
	var faster_did_selection = false
	
	# Primero se hace la llamada a la función y se obtiene el resultado como un Array
	var result_t1 = _pre_process_move(self.t1, [t1_command, t1_move_data, t1_mv_check_bypass])
	var result_t2 = _pre_process_move(self.t2, [t2_command, t2_move_data, t2_mv_check_bypass])
	
	# Luego se descompone el resultado en variables individuales
	t1_command = result_t1[0]
	t1_move_data = result_t1[1]
	t1_mv_check_bypass = result_t1[2]
	
	t2_command = result_t2[0]
	t2_move_data = result_t2[1]
	t2_mv_check_bypass = result_t2[2]
	
	if not t1_command is Array or not t1_command.size() >= 2 or not t1_command[gs.ACTION_TYPE].to_lower() in gs.ACTION_PRIORITY:
		push_error("Trainer 1 invalid turn action")
		return false
	if not t2_command is Array or not t2_command.size() >= 2 or not t2_command[gs.ACTION_TYPE].to_lower() in gs.ACTION_PRIORITY:
		push_error("Trainer 2 invalid turn action")
		return false
	
	self.t1.has_moved = false
	self.t2.has_moved = false
	t1_command = t1_command.map(func(e): return e.to_lower())
	t2_command = t2_command.map(func(e): return e.to_lower())
	self.t1_fainted = false
	self.t2_fainted = false
	self.t1.current_poke.turn_damage = false
	self.t2.current_poke.turn_damage = false
	
	if t1_command[gs.ACTION_TYPE] == gd.MOVE and not t1_mv_check_bypass and not self.t1.current_poke.is_move(t1_command[gs.ACTION_VALUE]):
		push_error("Trainer 1 attempted to use move not in Pokemon's moveset")
		return false
	if t2_command[gs.ACTION_TYPE] == gd.MOVE and not t2_mv_check_bypass and not self.t2.current_poke.is_move(t2_command[gs.ACTION_VALUE]):
		push_error("Trainer 2 attempted to use move not in Pokemon's moveset")
		return false
	
	if not t1_move_data and t1_command[gs.ACTION_TYPE] == gd.MOVE:
		t1_move_data = self.t1.current_poke.get_move_data(t1_command[gs.ACTION_VALUE])
		if not t1_move_data:
			t1_move_data = Move.new(PokeSim.get_single_move(t1_command[gs.ACTION_VALUE]))
	if not t2_move_data and t2_command[gs.ACTION_TYPE] == gd.MOVE:
		t2_move_data = self.t2.current_poke.get_move_data(t2_command[gs.ACTION_VALUE])
		if not t2_move_data:
			t2_move_data = Move.new(PokeSim.get_single_move(t2_command[gs.ACTION_VALUE]))
	
	var t1_prio = gs.ACTION_PRIORITY[t1_command[gs.ACTION_TYPE]]
	var t2_prio = gs.ACTION_PRIORITY[t2_command[gs.ACTION_TYPE]]
	t1_first = t1_prio >= t2_prio
	if t1_prio == 1 and t2_prio == 1:
		if t1_move_data.prio != t2_move_data.prio:
			t1_first = t1_move_data.prio > t2_move_data.prio
		else:
			var spd_dif = self.t1.current_poke.stats_effective[gs.SPD] - self.t2.current_poke.stats_effective[gs.SPD]
			if spd_dif == 0:
				t1_first = randf_range(0, 1) < 1
			else:
				t1_first = spd_dif > 0
				if self.battlefield.gravity_count:
					t1_first = not t1_first
				if self._stall_check():
					t1_first = self._calculate_stall()
				if self._ltail_check():
					t1_first = self._calculate_ltail()
			t1_first = self._prio_boost_check(t1_first)

	self.add_text("Turn " + str(self.turn_count) + ":")

	if self._pursuit_check(t1_command, t2_command, t1_move_data, t2_move_data, t1_first):
		t1_first = t1_command == gd.PURSUIT

	if self._me_first_check(t1_move_data, t2_move_data):
		t1_first = t1_command == gd.ME_FIRST

	self._focus_punch_check(t1_command, t2_command)

	if t1_first:
		if self.t1.current_poke.is_alive:
			self._half_turn(self.t1, self.t2, t1_command, t1_move_data)
		self._faint_check()
		if self.t2.current_poke.is_alive:
			self._half_turn(self.t2, self.t1, t2_command, t2_move_data)
		self._faint_check()
	else:
		if self.t2.current_poke.is_alive:
			self._half_turn(self.t2, self.t1, t2_command, t2_move_data)
		self._faint_check()
		if self.t1.current_poke.is_alive:
			self._half_turn(self.t1, self.t2, t1_command, t1_move_data)
		self._faint_check()

	if self.winner:
		return true
	self.battlefield.update()

	var dif = self.t1.current_poke.stats_effective[gs.SPD] - self.t2.current_poke.stats_effective[gs.SPD]
	var faster
	var slower

	if dif > 0:
		faster = self.t1
		slower = self.t2
	elif dif < 0:
		faster = self.t2
		slower = self.t1
	else:
		faster = self.t1 if randf_range(0, 1) < 1 else self.t2
		slower = self.t2 if faster == self.t1 else self.t1

	if faster.current_poke.is_alive:
		self._post_process_status(faster, slower)
	self._faint_check()
	if self.winner:
		return true
	if not faster.current_poke.is_alive:
		self._process_selection(faster)
	if slower.current_poke.is_alive:
		self._post_process_status(slower, faster)
	self._faint_check()
	if self.winner:
		return true
	if not slower.current_poke.is_alive:
		self._process_selection(slower)
	
	return false


# Method to get current text and clear the list
func get_cur_text() -> Array:
	var cur_t = self.cur_text.duplicate()
	self.cur_text.clear()
	return cur_t

# Method to get all accumulated text
func get_all_text() -> Array:
	return self.all_text.duplicate()

# Method to process half of the turn
func _half_turn(
	attacker: tr.Trainer,
	defender: tr.Trainer,
	a_move: Array,
	a_move_data: Move = null
):
	if self.winner:
		return
	
	match a_move[gs.ACTION_TYPE]:
		"other":
			_process_other(attacker, defender, a_move)
		"item":
			if a_move.size() >= 4:
				print("descomentar 243")
				pi.use_item(
					attacker,
					a_move[gs.ACTION_VALUE],
					a_move[gs.ITEM_TARGET_POS],
					a_move[gs.MOVE_TARGET_POS]
				)
			elif a_move.size() == 3:
				pi.use_item(attacker,a_move[gs.ACTION_VALUE],a_move[gs.ITEM_TARGET_POS],a_move[gs.MOVE_TARGET_POS])
			else:
				push_error("Trainer attempted to use item with invalid data format")
		"move":
			_process_pp(attacker.current_poke, a_move_data)
			pm.process_move(
				attacker.current_poke,
				defender.current_poke,
				self.battlefield,
				self,
				a_move_data.get_tcopy(),
				not defender.has_moved
			)
			if self.last_move_next:
				self.last_move = self.last_move_next
				self.last_move_next = null
			attacker.current_poke.update_last_moves()
	attacker.has_moved = true

# Method to process move PP
func _process_pp(attacker: Pokemon, move_data: Move) -> bool:
	if move_data.name == "struggle" or attacker.rage or attacker.uproar:
		return true
	if move_data.cur_pp <= 0:
		push_error("Trainer attempted to use move that has no pp left")
		return false
	var is_disabled = move_data.disabled
	attacker.reduce_disabled_count()
	if is_disabled:
		add_text(move_data.name + " is disabled!")
		return false
	if not (move_data.name in gd.TWO_TURN_CHECK and not move_data.ef_stat):
		move_data.cur_pp -= 1
		_pressure_check(attacker, move_data)
	if move_data.cur_pp == 0 and attacker.item == "leppa-berry":
		pi._eat_item(attacker, self)
		attacker.restore_pp(move_data.name, 10)
	if move_data.cur_pp == 0 and attacker.copied and move_data.name == attacker.copied.name:
		attacker.copied = null
	return true

# Method to post-process Pokémon status
func _post_process_status(trainer: tr.Trainer, other: tr.Trainer):
	var poke = trainer.current_poke
	if trainer.wish:
		trainer.wish -= 1
		if trainer.wish == 0:
			add_text(trainer.wish_poke + "'s wish came true!")
			trainer.current_poke.heal(trainer.current_poke.max_hp / 2) #TODO div enteros
		trainer.wish_poke = null
	if poke.v_status[gs.INGRAIN] and poke.heal_block_count == 0:
		add_text(poke.nickname + " absorbed nutrients with its roots!")
		var heal_amt = max(1, poke.max_hp / 16) #TODO div enteros
		if poke.item == "big-root":
			heal_amt = int(heal_amt * 1.3)
		var text_skip=true
		poke.heal(heal_amt, text_skip)
	if poke.v_status[gs.AQUA_RING] and poke.heal_block_count == 0:
		add_text("A veil of water restored " + poke.nickname + "'s HP!")
		var heal_amt = max(1, poke.max_hp / 16)#TODO div enteros
		if poke.item == "big-root":
			heal_amt = int(heal_amt * 1.3)
		var text_skip=true
		poke.heal(heal_amt, text_skip)
	if self.battlefield.weather == gs.RAIN and poke.has_ability("rain-dish"):
		poke.heal(poke.max_hp / 16)#TODO div entero
	if trainer.fs_count and poke.is_alive:
		trainer.fs_count -= 1
		if trainer.fs_count == 0:
			poke.take_damage(trainer.fs_dmg)
			add_text(poke.nickname + " took the Future Sight attack!")
	if trainer.dd_count and poke.is_alive:
		trainer.dd_count -= 1
		if trainer.dd_count == 0:
			poke.take_damage(trainer.dd_dmg)
			add_text(poke.nickname + " took the Doom Desire attack!")
	if trainer.reflect:
		trainer.reflect -= 1
	if trainer.light_screen:
		trainer.light_screen -= 1
		add_text(trainer.name + "'s Light Screen wore off.")
	if trainer.safeguard:
		trainer.safeguard -= 1
		if trainer.safeguard == 0:
			add_text(trainer.name + " is no longer protected by Safeguard.")
	if trainer.mist:
		trainer.mist -= 1
		if trainer.mist == 0:
			add_text(trainer.name + " is no longer protected by mist!")
	if trainer.tailwind_count:
		trainer.tailwind_count -= 1
		if trainer.tailwind_count == 0:
			add_text(trainer.name + "'s tailwind petered out!")
			for temp_poke in trainer.poke_list:
				temp_poke.stats_actual[gs.SPD] /= 2
				poke = temp_poke  # Asigna el valor de temp_poke a poke
	if trainer.lucky_chant:
		trainer.lucky_chant -= 1
		if trainer.lucky_chant == 0:
			add_text(trainer.name + "'s Lucky Chant wore off!")
	if trainer.imprisoned_poke and trainer.imprisoned_poke != other.current_poke:
		trainer.imprisoned_poke = null
	if poke.perish_count and poke.is_alive:
		poke.perish_count -= 1
		if poke.perish_count == 0:
			poke.faint()
			return

	if not poke.is_alive:
		return

	if poke.nv_status and (
		(poke.has_ability("shed-skin") and randf_range(0, 10) < 3)
		or (poke.has_ability("hydration") and self.battlefield.weather == gs.RAIN)
	):
		pm.cure_nv_status(poke.nv_status, poke, self)
	if poke.nv_status == gs.BURNED and poke.is_alive:
		add_text(poke.nickname + " was hurt by its burn!")
		if not poke.has_ability("heatproof"):
			poke.take_damage(max(1, poke.max_hp / 8))#TODO div entero
		else:
			poke.take_damage(max(1, poke.max_hp / 16))#TODO div entero
	if poke.nv_status == gs.POISONED and poke.is_alive:
		if not poke.has_ability("poison-heal"):
			add_text(poke.nickname + " was hurt by poison!")
			poke.take_damage(max(1, poke.max_hp / 8))#TODO div entero
		else:
			add_text(poke.nickname + " was healed by its Poison Heal!")
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
	if poke.nv_status == gs.BADLY_POISONED and poke.is_alive:
		if not poke.has_ability("poison-heal"):
			add_text(poke.nickname + " was hurt by poison!")
			poke.take_damage(max(1, poke.max_hp * poke.nv_counter / 16))#TODO div entero
		else:
			add_text(poke.nickname + " was healed by its Poison Heal!")
			poke.heal(max(1, poke.max_hp / 8))#TODO div entero
		poke.nv_counter += 1
	if poke.v_status[gs.BINDING_COUNT] and poke.is_alive:
		if poke.binding_poke == other.current_poke and poke.binding_type:
			add_text(poke.nickname + " is hurt by " + poke.binding_type + "!")
			poke.take_damage(max(1, poke.max_hp / 16))#TODO div entero
			if not poke.is_alive:
				return
			poke.v_status[gs.BINDING_COUNT] -= 1
			if poke.v_status[gs.BINDING_COUNT] == 0:
				poke.binding_type = null
				poke.binding_poke = null
		else:
			poke.v_status[gs.BINDING_COUNT] = 0
			poke.binding_type = null
			poke.binding_poke = null
	if poke.v_status[gs.LEECH_SEED] and poke.is_alive:
		add_text(poke.nickname + "'s health is sapped by Leech Seed!")
		var heal_amt = poke.take_damage(max(1, poke.max_hp / 8))#TODO div entero
		if poke.item == "big-root":
			heal_amt = int(heal_amt * 1.3)
		var other_poke = (
			self.t2.current_poke if poke == self.t1.current_poke
			else self.t1.current_poke
		)
		if other_poke.is_alive:
			if not poke.has_ability("liquid-ooze"):
				if other.heal_block_count == 0:
					other.heal(heal_amt)
			else:
				other_poke.take_damage(heal_amt)
				add_text(other_poke.nickname + " sucked up the liquid ooze!")
	if poke.v_status[gs.NIGHTMARE] and poke.is_alive:
		add_text(poke.nickname + " is locked in a nightmare!")
		poke.take_damage(max(1, poke.max_hp / 4))#TODO div entero
	if poke.v_status[gs.CURSE] and poke.is_alive:
		add_text(poke.nickname + " is afflicted by the curse!")
		poke.take_damage(max(1, poke.max_hp / 4))#TODO div entero
	if poke.has_ability("solar-power"):
		add_text(poke.nickname + " was hurt by its Solar Power!")
		poke.take_damage(max(1, poke.max_hp / 8))#TODO div entero
	if not poke.is_alive:
		return

	self.battlefield.process_weather_effects(poke)

	if not poke.is_alive:
		return

	pa.end_turn_abilities(poke, self)
	pi.end_turn_items(poke, self)

	if poke.v_status[gs.FLINCHED]:
		poke.v_status[gs.FLINCHED] = 0
	if poke.foresight_target and poke.foresight_target != other:
		poke.foresight_target = null
	if poke.bide_count:
		poke.bide_count -= 1
	if poke.mr_count:
		poke.mr_count -= 1
	if poke.db_count:
		poke.db_count -= 1
		if poke.mr_count == 0:
			poke.mr_target = null
	if poke.charged:
		poke.charged -= 1
	if poke.taunt:
		poke.taunt -= 1
	if poke.r_types:
		poke.types = poke.r_types
		poke.r_types = null
	if poke.encore_count:
		poke.encore_count -= 1
		if poke.encore_count == 0:
			poke.encore_move = null
			for move in poke.moves:
				move.encore_blocked = false
			add_text(poke.nickname + "'s encore ended.")
	if poke.embargo_count:
		poke.embargo_count -= 1
		if poke.embargo_count == 0:
			add_text(poke.nickname + " can use items again!")
	if poke.heal_block_count:
		poke.heal_block_count -= 1
		if poke.heal_block_count == 0:
			add_text(poke.nickname + "'s Heal Block wore off!")
	if poke.uproar:
		poke.uproar -= 1
		if poke.uproar == 0:
			add_text(poke.nickname + " calmed down.")
	if poke.protect:
		poke.protect = false
		poke.invulnerable = false
		if poke.last_successful_move not in ["protect", "detect", "endure"]:
			poke.protect_count = 0
	if poke.endure:
		poke.endure = false
		if poke.last_successful_move not in ["protect", "detect", "endure"]:
			poke.protect_count = 0
	if poke.magic_coat:
		poke.magic_coat = false
	if poke.snatch:
		poke.snatch = false
	if poke.sucker_punch_check:
		poke.sucker_punch_check = false
	if not poke.has_moved:
		poke.has_moved = true
	if poke.v_status[gs.DROWSY]:
		poke.v_status[gs.DROWSY] -= 1
		if poke.v_status[gs.DROWSY] == 0 and not poke.nv_status:
			poke.nv_status = gs.ASLEEP
			add_text(poke.nickname + " fell asleep!")
# Procesa el movimiento antes de que se ejecute
func _pre_process_move(trainer: tr.Trainer, t_move: Array) -> Array:
	if t_move[gs.PPM_MOVE] == gd.RECHARGING or t_move[gs.PPM_MOVE] == gd.BIDING:
		push_error("Trainer attempted to use invalid move")
		return t_move

	if trainer.current_poke.recharging:
		t_move[gs.PPM_MOVE] = gd.RECHARGING
	elif not trainer.current_poke.next_moves.is_empty():
		t_move[gs.PPM_MOVE_DATA] = trainer.current_poke.next_moves.pop_front()
		t_move[gs.PPM_MOVE] = [gd.MOVE, t_move[gs.PPM_MOVE_DATA].name]
		t_move[gs.PPM_BYPASS] = true
	elif trainer.current_poke.encore_count:
		t_move[gs.PPM_MOVE_DATA] = trainer.current_poke.encore_move
		t_move[gs.PPM_MOVE] = [gd.MOVE, t_move[gs.PPM_MOVE_DATA].name]
		if t_move[gs.PPM_MOVE_DATA].disabled:
			t_move[gs.PPM_MOVE] = gd.STRUGGLE
			t_move[gs.PPM_MOVE_DATA] = null
			t_move[gs.PPM_BYPASS] = true
	elif (
		t_move[gs.PPM_MOVE][gs.ACTION_TYPE] == gd.MOVE
		and trainer.current_poke.no_pp()
	):
		t_move[gs.PPM_MOVE] = gd.STRUGGLE
		t_move[gs.PPM_MOVE_DATA] = null
		t_move[gs.PPM_BYPASS] = true
	elif trainer.current_poke.bide_count:
		t_move[gs.PPM_MOVE] = gd.BIDING
	elif trainer.current_poke.rage:
		t_move[gs.PPM_MOVE] = gd.RAGE
		t_move[gs.PPM_BYPASS] = true
	elif trainer.current_poke.uproar:
		t_move[gs.PPM_MOVE] = gd.UPROAR
		t_move[gs.PPM_BYPASS] = true

	return t_move

# Procesa la victoria del entrenador
func _victory(winner: tr.Trainer, loser: tr.Trainer):
	_process_end_battle()
	add_text(winner.name + " has defeated " + loser.name + "!")
	self.winner = winner

# Procesa la selección de un Pokémon
func _process_selection(selector: tr.Trainer, can_skip: bool = true) -> bool:
	
	if self.winner:
		return true

	var old_poke = selector.current_poke
	if selector.selection:
		selector.selection.call(selector)

	if not selector.current_poke.is_alive or selector.current_poke == old_poke:
		for p in selector.poke_list:
			if p.is_alive and p != old_poke:
				selector.current_poke = p
				break

	if not selector.current_poke.is_alive or selector.current_poke == old_poke:
		if can_skip:
			return true
		else:
			printerr("Trainer attempted make an invalid switch out")

	if old_poke.is_alive:
		old_poke.switch_out()
	add_text(selector.name + " sent out " + selector.current_poke.nickname + "!")

	if self.battlefield.gravity_count:
		selector.current_poke.grounded = true

	if selector.spikes and (
		selector.current_poke.grounded
		or (
			"flying" not in selector.current_poke.types
			and not selector.current_poke.magnet_rise
			and not selector.current_poke.has_ability("levitate")
			and not selector.current_poke.has_ability("magic-guard")
		)
	):
		var mult = 8 if selector.spikes == 1 else 6 if selector.spikes == 2 else 4
		selector.current_poke.take_damage(selector.current_poke.max_hp / mult)#TODO div entero
		add_text(selector.current_poke.nickname + " was hurt by the spikes!")

	if selector.toxic_spikes and "poison" in selector.current_poke.types:
		selector.toxic_spikes = 0
		add_text("The poison spikes disappeared from the ground around " + selector.name + ".")

	if (
		selector.toxic_spikes
		and not selector.current_poke.nv_status
		and (
			selector.current_poke.grounded
			or (
				not "flying" in selector.current_poke.types
				and not "steel" in selector.current_poke.types
				and not selector.current_poke.magnet_rise
				and not selector.current_poke.has_ability("immunity")
				and not selector.current_poke.has_ability("levitate")
				and not selector.current_poke.has_ability("magic-guard")
				and not (
					selector.current_poke.has_ability("leaf-guard")
					and self.battlefield.weather == gs.HARSH_SUNLIGHT
				)
			)
		)
	):
		if selector.toxic_spikes == 1:
			selector.current_poke.nv_status = gs.POISONED
			add_text(selector.current_poke.nickname + " was poisoned!")
		else:
			selector.current_poke.nv_status = gs.BADLY_POISONED
			selector.current_poke.nv_counter = 1
			add_text(selector.current_poke.nickname + " was badly poisoned!")

	if selector.stealth_rock and not selector.current_poke.has_ability("magic-guard"):
		var t_mult = PokeSim.get_type_ef("rock", selector.current_poke.types[0])
		if selector.current_poke.types[1]:
			t_mult *= PokeSim.get_type_ef("rock", selector.current_poke.types[1])
		if t_mult:
			selector.current_poke.take_damage(int(selector.current_poke.max_hp * 0.125 * t_mult))
			add_text("Pointed stones dug into " + selector.current_poke.nickname + "!")

	pa.enemy_selection_abilities(selector.current_poke, self.battlefield, self)
	pa.selection_abilities(selector.current_poke, self.battlefield, self)
	return false

# Procesa otros tipos de acciones
func _process_other(attacker: tr.Trainer, defender: tr.Trainer, a_move: Array) -> void:
	if a_move == gd.SWITCH:
		if attacker.can_switch_out():
			var can_skip
			_process_selection(attacker, can_skip)
		else:
			push_error("Trainer attempted to switch out Pokemon that's trapped")

	if a_move[gs.ACTION_VALUE] == "recharging":
		add_text(attacker.current_poke.nickname + " must recharge!")
		attacker.current_poke.recharging = false

	if a_move[gs.ACTION_VALUE] == "biding":
		add_text(attacker.current_poke.nickname + " is storing energy!")

# Revisa si algún Pokémon ha caído
func _faint_check():
	if self.winner:
		return

	if not self.t1_fainted and not self.t1.current_poke.is_alive:
		add_text(self.t1.current_poke.nickname + " fainted!")
		self.t1_fainted = true
		self.t1.num_fainted += 1
		if self.t1.num_fainted == self.t1.poke_list.size():
			_victory(self.t2, self.t1)
			return

	if not self.t2_fainted and not self.t2.current_poke.is_alive:
		add_text(self.t2.current_poke.nickname + " fainted!")
		self.t2_fainted = true
		self.t2.num_fainted += 1
		if self.t2.num_fainted == self.t2.poke_list.size():
			_victory(self.t1, self.t2)
			return

# Procesa el final de la batalla
func _process_end_battle():
	for poke in self.t1.poke_list:
		poke.battle_end_reset()
	for poke in self.t2.poke_list:
		poke.battle_end_reset()
	self.t1.in_battle = false
	self.t2.in_battle = false

# Verifica el efecto de Pursuit
func _pursuit_check(t1_command: Array, t2_command: Array, t1_move_data: Move, t2_move_data: Move, t1_first: bool) -> bool:
	if t1_command == gd.PURSUIT and (
		t2_command == gd.SWITCH
		or (
			t2_command[gs.ACTION_TYPE] == gd.MOVE
			and t2_command[gs.ACTION_VALUE] in gd.PURSUIT_CHECK
			and not t1_first
		)
	):
		t1_move_data.cur_pp -= 1
		_pressure_check(self.t1.current_poke, t1_move_data)
		t1_move_data = t1_move_data.get_tcopy()
		t1_move_data.power *= 2
		return true
	elif t2_command == gd.PURSUIT and (
		t1_command == gd.SWITCH
		or (
			t1_command[gs.ACTION_TYPE] == gd.MOVE
			and t1_command[gs.ACTION_VALUE] in gd.PURSUIT_CHECK
			and t1_first
		)
	):
		t2_move_data.cur_pp -= 1
		_pressure_check(self.t2.current_poke, t2_move_data)
		t2_move_data = t2_move_data.get_tcopy()
		t2_move_data.power *= 2
		return true
	return false

# Verifica el efecto de Me First
func _me_first_check(t1_move_data: Move, t2_move_data: Move) -> bool:
	if not t1_move_data or not t2_move_data:
		return false
	if t1_move_data.name == "me-first" and t2_move_data.category != gs.STATUS:
		self.t1.current_poke.mf_move = t2_move_data.get_tcopy()
		return true
	if t2_move_data.name == "me-first" and t1_move_data.category != gs.STATUS:
		self.t2.current_poke.mf_move = t1_move_data.get_tcopy()
		return true
	return false

# Verifica el efecto de Focus Punch
func _focus_punch_check(t1_command: Array, t2_command: Array):
	if t1_command == gd.FOCUS_PUNCH:
		add_text(self.t1.current_poke.nickname + " is tightening its focus!")
	if t2_command == gd.FOCUS_PUNCH:
		add_text(self.t2.current_poke.nickname + " is tightening its focus!")

# Verifica si algún Pokémon tiene la habilidad "Stall"
func _stall_check() -> bool:
	return self.t1.current_poke.has_ability("stall") or self.t2.current_poke.has_ability("stall")

# Calcula el efecto de la habilidad "Stall"
func _calculate_stall() -> bool:
	if self.t1.current_poke.has_ability("stall") and self.t2.current_poke.has_ability("stall"):
		if self.t1.current_poke.stats_effective[gs.SPD] != self.t2.current_poke.stats_effective[gs.SPD]:
			return self.t1.current_poke.stats_effective[gs.SPD] < self.t2.current_poke.stats_effective[gs.SPD]
		else:
			return randf_range(0, 1) < 1
	return self.t2.current_poke.has_ability("stall")

# Verifica si algún Pokémon tiene el item "Lagging Tail" o "Full Incense"
func _ltail_check() -> bool:
	return (
		self.t1.current_poke.item in ["lagging-tail", "full-incense"]
		or self.t2.current_poke.item in ["lagging-tail", "full-incense"]
	)

# Calcula el efecto del item "Lagging Tail" o "Full Incense"
func _calculate_ltail() -> bool:
	if (
		self.t1.current_poke.item in ["lagging-tail", "full-incense"]
		and self.t2.current_poke.item in ["lagging-tail", "full-incense"]
	):
		if self.t1.current_poke.stats_effective[gs.SPD] != self.t2.current_poke.stats_effective[gs.SPD]:
			return self.t1.current_poke.stats_effective[gs.SPD] < self.t2.current_poke.stats_effective[gs.SPD]
		else:
			return randf_range(0, 1) < 1
	return self.t2.current_poke.item in ["lagging-tail", "full-incense"]

# Verifica el efecto de Sucker Punch
func _sucker_punch_check(t1_move_data: Move, t2_move_data: Move):
	if not t1_move_data or not t2_move_data:
		return
	if t1_move_data.name == "sucker-punch" and t2_move_data.category != gs.STATUS:
		self.t1.current_poke.sucker_punch_check = true
	if t2_move_data.name == "sucker-punch" and t1_move_data.category != gs.STATUS:
		self.t2.current_poke.sucker_punch_check = true

# Verifica la habilidad "Pressure"
func _pressure_check(attacker: Pokemon, move_data: Move):
	if move_data.cur_pp and attacker.enemy.current_poke.is_alive and attacker.enemy.current_poke.has_ability("pressure"):
		move_data.cur_pp -= 1

# Verifica el efecto de prioridad
func _prio_boost_check(t1_first: bool) -> bool:
	if self.t1.current_poke.prio_boost and self.t2.current_poke.prio_boost:
		return randf_range(0, 1) < 1
	elif self.t1.current_poke.prio_boost or self.t2.current_poke.prio_boost:
		return self.t1.current_poke.prio_boost
	else:
		return t1_first

# Añade un texto a la lista de textos
func add_text(txt: String):
	if not self.winner:
		self.all_text.append(txt)
		self.cur_text.append(txt)

# Elimina el último texto de la lista de textos
func _pop_text():
	if self.all_text.size() > 0:
		self.all_text.pop_back()
	if self.cur_text.size() > 0:
		self.cur_text.pop_back()

# Verifica si la batalla ha terminado
func is_finished() -> bool:
	return self.winner != null 

# Obtiene el entrenador ganador
func get_winner() -> tr.Trainer:
	return self.winner
