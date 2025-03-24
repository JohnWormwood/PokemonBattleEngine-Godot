class_name PokeSim

const gs = preload("res://scripts/pokeSim/conf/global_settings.gd")

static var _pokemon_stats = []
static var _name_to_id = {}
static var _natures = {}
static var _nature_list = []
static var _move_list = []
static var _move_name_to_id = {}
static var _type_effectives = []
static var _type_to_id = {}
static var _ability_list = []
static var _abilities = {}
static var _item_list = []
static var _items = {}

static func start() -> void:
	if _pokemon_stats.size() > 0:
		return

	var file = FileAccess.open("res://scripts/pokeSim/data/pokemon_stats.csv", FileAccess.READ)
	if file:
		file.get_line()  # Salta la cabecera
		while not file.eof_reached():
			var row= file.get_csv_line()  # Lee una línea del archivo CSV como PackedStringArray
			row = Array(row) #'PackedStringArray' pasamos a Array
			# Convierte ciertos valores en la fila a enteros según sea necesario
			var temp
			var temp_int
			for num in gs.POKEMON_STATS_NUMS:
				temp = row[num]
				temp_int = temp.to_int()
				row[num] = temp_int
			_pokemon_stats.append(row)
			_name_to_id[row[1]] = row[0]  # Asigna el nombre como clave y el ID como valor
		file.close()

	file = FileAccess.open("res://scripts/pokeSim/data/natures.csv", FileAccess.READ)
	if file:
		file.get_line()
		while not file.eof_reached():
			var row = file.get_csv_line()
			_natures[row[0]] = [int(row[1]), int(row[2])]
			_nature_list.append(row[0])
		file.close()

	file = FileAccess.open("res://scripts/pokeSim/data/move_list.csv", FileAccess.READ)
	if file:
		file.get_line()
		while not file.eof_reached():
			var row = file.get_csv_line()
			row = Array(row)
			var temp
			var temp_int
			for num in gs.MOVES_NUM:
				if row[num]:
					temp = row[num]
					temp_int = temp.to_int()
					row[num] = temp_int
			_move_list.append(row)
			_move_name_to_id[row[1]] = row[0]
		file.close()
	else:
		print("error move file")

	file = FileAccess.open("res://scripts/pokeSim/data/type_effectiveness.csv", FileAccess.READ)
	if file:
		file.get_line()
		var line_count = 0
		while not file.eof_reached():
			var row = file.get_csv_line()
			_type_to_id[row[0]] = line_count
			var temp_row = []
			for i in range(1, row.size()):
				temp_row.append(float(row[i]))
			row = temp_row
			_type_effectives.append(row)
			line_count += 1
		file.close()

	file = FileAccess.open("res://scripts/pokeSim/data/abilities.csv", FileAccess.READ)
	if file:
		file.get_line()
		var temp
		while not file.eof_reached():
			var row = file.get_csv_line()
			_abilities[row[1]] = [row[0], row[2]]
			_ability_list.append(row[1])
		file.close()

	file = FileAccess.open("res://scripts/pokeSim/data/items.csv", FileAccess.READ)
	if file:
		file.get_line()
		while not file.eof_reached():
			var row = file.get_csv_line()
			_items[row[1]] = [row[0], row[2]]
			_item_list.append(row[1])
		file.close()

static func _convert_name_to_id(name: String) -> int:
	if not _name_to_id.has(name):
		return -1
	return _name_to_id[name]

static func get_valid_name_or_id(name_or_id: Variant) -> int:
	if typeof(name_or_id) != TYPE_STRING and typeof(name_or_id) != TYPE_INT:
		return -1
	var p_id = name_or_id
	if typeof(name_or_id) == TYPE_STRING:
		p_id = _convert_name_to_id(name_or_id)
	if p_id > 0 and p_id < _pokemon_stats.size():
		return p_id
	return -1

static  func get_rand_poke() -> Pokemon:
	var poke = Pokemon.new()
	poke.set_pokemon_data(randi_range(1,150),randi_range(5,50),get_rand_moves_name(),
		get_rand_gender(),get_rand_nature(),[],get_rand_ability(),-1,get_rand_ivs(),[0,0,0,0,0,0])
	if poke.moves.size() > 4:
		print("out of moves ",poke.name)
	return poke
static func get_pokemon(name_or_id: Variant) -> Array:
	var p_id = get_valid_name_or_id(name_or_id)
	if p_id == -1:
		return []
	return _pokemon_stats[p_id - 1]

static func nature_conversion(nature: String) -> Array:
	if not _natures.has(nature):
		return []
	return _natures[nature]

static func get_move_data(moves: Array) -> Array:
	var move_data = []
	var move_ids = []
	for move in moves:
		if not _move_name_to_id.has(move):
			return []
		var move_info = _move_list[_move_name_to_id[move] - 1]
		if move_info[0] in move_ids:
			return []
		move_data.append(move_info)
		move_ids.append(move_info[0])
	return move_data

static func get_single_move(move: String):
	return _move_list[_move_name_to_id[move] - 1]

static func get_type_ef(move_type: String, def_type: String) -> float:
	if not _type_to_id.has(move_type) or not _type_to_id.has(def_type):
		return 1.0
	#print(move_type," vs ",def_type,_type_effectives[_type_to_id[move_type]][_type_to_id[def_type]])
	return _type_effectives[_type_to_id[move_type]][_type_to_id[def_type]]

static func get_all_types() -> Array:
	return _type_to_id.keys()

static func is_valid_type(type: String) -> bool:
	return _type_to_id.has(type)

static func filter_valid_types(types: Array) -> Array:
	var valid_types = []  # Lista para almacenar los tipos válidos
	for t in types:
		if is_valid_type(t):
			valid_types.append(t)  # Añade el tipo válido a la lista
	return valid_types  # Retorna la lista con los tipos filtrados

static func get_rand_move() -> Array:
	return _move_list[randi_range(0, _move_list.size() - 1)]

static func get_rand_moves_name() -> Array:
	var moves_names = []
	while moves_names.size() < 4:
		var move = get_rand_move()
		var move_name = move[1]
		if move_name not in moves_names:
			moves_names.append(move_name)
	return moves_names

static func get_rand_ability() -> String:
	return _ability_list[randi_range(0, _ability_list.size() - 1)]

static func get_rand_item() -> String:
	return _item_list[randi_range(0, _item_list.size() - 1)]

static func get_rand_poke_id() -> int:
	return randi_range(1, _pokemon_stats.size())

static func get_rand_stats() -> Array:
	var stats = []
	for i in range(6):
		stats.append(randi_range(gs.STAT_ACTUAL_MIN, gs.STAT_ACTUAL_MAX + 1))
	return stats

static func get_rand_ivs() -> Array:
	var stats = []
	for i in range(6):
		stats.append(randi_range(1, 31))
	return stats

static func get_rand_gender() -> String:
	return gs.POSSIBLE_GENDERS[randi_range(0, len(gs.POSSIBLE_GENDERS) - 1)]

static func get_rand_level() -> int:
	return randi_range(gs.LEVEL_MIN, gs.LEVEL_MAX)

static func get_rand_nature() -> String:
	return _nature_list[randi_range(0, _nature_list.size() - 1)]

static func check_ability(ability: String) -> bool:
	return _abilities.has(ability)

static func check_item(item: String) -> bool:
	return _items.has(item)
