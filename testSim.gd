extends Node

const tr = preload("res://gdScripts/pokeSim/core/trainer.gd")

func _ready():
	PokeSim.start()
	main()

func main():
	# Crear Pikachu para Ash
	var pikachu = Pokemon.new(
		"pikachu",
		50,
		["thunderbolt", "quick-attack", "iron-tail", "tackle"],
		"male",
		"jolly",
		[120, 90, 55, 50, 50, 100]
	)

	# Crear Starmie para Misty
	var starmie = Pokemon.new(
		"starmie",
		50,
		["surf", "ice-beam", "psychic", "tackle"],
		"genderless",
		"modest",
		[110, 75, 85, 100, 85, 115]
	)

	# Crear los entrenadores
	var ash = tr.Trainer.new("Ash", [pikachu])
	var misty = tr.Trainer.new("Misty", [starmie])

	# Crear la batalla
	var battle = Battle.new(ash, misty)
	battle.start()
	
	# Parámetros de ejemplo para el turno
	var t1_action = ['move', 'thunderbolt']    # Acción de Ash
	var t2_action = ['move', 'tackle']      # Acción de Misty
	
	# Procesar el turno con los parámetros fijos
	var turn_result = battle.turn(t1_action, t2_action)
	
	#t1_action = ['move', 'thunderbolt']
	#t2_action = ['move', 'surf'] 
	#turn_result = battle.turn(t1_action, t2_action)
	#
	#t1_action = ['move', 'thunderbolt']
	#t2_action = ['move', 'surf'] 
	#turn_result = battle.turn(t1_action, t2_action)
	#
	#t1_action = ['move', 'thunderbolt']
	#t2_action = ['move', 'surf'] 
	#turn_result = battle.turn(t1_action, t2_action)
	
#TODO parece que hay un problema con el move del t2, no se calcula en el _calculate_damage

	# Imprimir el resultado final
	print(battle.get_all_text())
	print("Pikachu hp:",ash.poke_list.pop_front().cur_hp," vs "," Starmie hp:",misty.poke_list.pop_front().cur_hp)
	print("Battle finished!")
