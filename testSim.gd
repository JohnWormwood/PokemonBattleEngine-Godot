extends Node

const tr = preload("res://gdScripts/pokeSim/core/trainer.gd")

var misty
var battle

func _ready():
	PokeSim.start()
	run()

func run():
	# Crear Pikachu para Ash
	var pikachu = Pokemon.new().set_pokemon_data(
		"shedinja",
		50,
		["dig", "scratch", "harden", "grudge"],
		"male",
		"jolly",
		[1, 90, 45, 30, 30, 40]
	)

	# Crear Starmie para Misty
	var starmie = Pokemon.new().set_pokemon_data(
		"starmie",
		50,
		["surf", "ice-beam", "psychic", "tackle"],
		"genderless",
		"modest",
		[110, 75, 85, 100, 85, 115]
	)

	# Crear los entrenadores
	var ash = tr.Trainer.new("Ash", [pikachu])
	misty = tr.Trainer.new("Misty", [starmie])

	# Crear la batalla
	battle = Battle.new(ash, misty)
	battle.start()
	
	# Parámetros de ejemplo para el turno
	var t1_action = ['move', 'scratch']    # Acción de Ash
	var t2_action = ['move', 'tackle']      # Acción de Misty
	
	# Procesar el turno con los parámetros fijos
	var turn_result = battle.turn(t1_action, t2_action)
	
	#t1_action = ['move', 'harden']
	#t2_action = ['move', 'surf'] 
	#turn_result = battle.turn(t1_action, t2_action)
	##
	#t1_action = ['move', 'harden']
	#t2_action = ['move', 'surf'] 
	#turn_result = battle.turn(t1_action, t2_action)
	##
	#t1_action = ['move', 'thunderbolt']
	#t2_action = ['move', 'surf'] 
	#turn_result = battle.turn(t1_action, t2_action)
	
#TODO parece que hay un problema con el move del t2, no se calcula en el _calculate_damage

	# Imprimir el resultado final
	print(battle.get_all_text())
	print("Pikachu hp:",ash.poke_list.pop_front().cur_hp," vs "," Starmie hp:",misty.poke_list.pop_front().cur_hp)
	print("Battle finished!")
