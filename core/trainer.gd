# Importa las clases necesarias
const pk = preload("res://scripts/pokeSim/core/pokemon.gd")

const pi = preload("res://scripts/pokeSim/util/process_item.gd")

const gs = preload("res://scripts/pokeSim/conf/global_settings.gd")
const gd = preload("res://scripts/pokeSim/conf/global_data.gd")

class Trainer:
		# Definir las propiedades de Trainer
	var name: String
	var poke_list: Array
	var selection: Variant
	var in_battle: bool  # Asegúrate de definir la propiedad
	var current_poke
	var next_poke
	var light_screen
	var safeguard
	var reflect
	var mist
	var stealth_rock
	var fs_dmg
	var fs_count
	var dd_dmg
	var dd_count
	var tailwind_count
	var wish
	var lucky_chant
	var spikes
	var toxic_spikes
	var num_fainted
	var wish_poke
	var imprisoned_poke
	var has_moved
	
	func _init(_name: String, _poke_list: Array, _selection: Callable = Callable()):
		#Crea un objeto Trainer que requiere un nombre, un equipo de Pokémon y una función opcional de selección.
		#- name: Nombre del entrenador
		#- poke_list: Lista de Pokémon del entrenador
		#- selection: Función opcional para seleccionar una acción, si no se provee, se selecciona el primer Pokémon disponible.

		if not _poke_list or _poke_list.size() < gs.POKE_NUM_MIN or _poke_list.size() > gs.POKE_NUM_MAX:
			push_error("Intento de crear un entrenador con un número inválido de Pokémon.")
			return
		
		for p in _poke_list:
			if typeof(p) != TYPE_OBJECT or not p is Pokemon:
				push_error("Intento de crear un entrenador con una lista de Pokémon inválida.")
				return
		
		for poke in poke_list:
			if poke.trainer:
				push_error("Intento de crear un entrenador con Pokémon que ya pertenecen a otro entrenador.")
				return
		
		if not _name or typeof(_name) != TYPE_STRING:
			push_error("Intento de crear un entrenador sin nombre.")
			return
		
		#if _selection and not call(selection):
			#push_error("Intento de crear un entrenador con una función de selección inválida.")
			#return
		
		poke_list = _poke_list
		for poke in self.poke_list:
			if poke.trainer == null:
				poke.trainer = self
			else:
				push_error("Attempted to create Trainer with duplicate Pokemon")

		self.selection = _selection
		self.next_poke = null
		self.name = _name
		self.in_battle = false

	func start(battle):
		for poke in self.poke_list:
			poke.start_battle(battle)
		self.current_poke = self.poke_list[0]
		self.light_screen = 0
		self.safeguard = 0
		self.reflect = 0
		self.mist = 0
		self.stealth_rock = 0
		self.fs_dmg = 0
		self.fs_count = 0
		self.dd_dmg = 0
		self.dd_count = 0
		self.tailwind_count = 0
		self.wish = 0
		self.lucky_chant = 0
		self.spikes = 0
		self.toxic_spikes = 0
		self.num_fainted = 0
		self.wish_poke = null
		self.imprisoned_poke = null
		self.in_battle = true
		self.has_moved = false

	func is_valid_action(action: Array) -> bool:
		if not action or action.size() < 2:
			return false
		
		if action[gs.ACTION_TYPE] == gd.MOVE:
			return can_use_move(action)
		
		if action == gd.SWITCH:
			return can_switch_out()
		
		if action[gs.ACTION_TYPE] == gd.ITEM:
			return can_use_item(action)
		
		return false

	func can_switch_out() -> bool:
		self._must_be_in_battle()
		return self.current_poke.can_switch_out()

	func can_use_item(item_action: Array) -> bool:
		self._must_be_in_battle()
		if not item_action or typeof(item_action[gs.ACTION_TYPE]) != TYPE_STRING or item_action[gs.ACTION_TYPE] != "item":
			return false
		print("TODO: can_use_item")
		#if item_action.size() == 3:TODO descomentar
			#return pi.can_use_item(self, self.cur_battle, item_action[gs.ACTION_VALUE], item_action[gs.ITEM_TARGET_POS])
		#elif item_action.size() == 4:
			#return pi.can_use_item(self, self.cur_battle, item_action[gs.ACTION_VALUE], item_action[gs.ITEM_TARGET_POS], item_action[gs.MOVE_TARGET_POS])
		return false

	func can_use_move(move_action: Array) -> bool:
		if not move_action or typeof(move_action[gs.ACTION_TYPE]) != TYPE_STRING or move_action[gs.ACTION_TYPE] != "move":
			return false
		
		if move_action.size() == 2:
			for move in self.current_poke.get_available_moves():
				if move_action[gs.ACTION_VALUE] == move.name:
					return true
		return false

	func _must_be_in_battle():
		if not self.in_battle:
			push_error("Trainer must be in battle")

	func switch_poke(n: int):
		self.current_poke = poke_list[n]
		poke_list[n] = poke_list[0]
		poke_list[0] = self.current_poke
