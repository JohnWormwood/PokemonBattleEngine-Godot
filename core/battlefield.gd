class_name Battlefield

# Importaciones simuladas para representar las clases y constantes necesarias
var gs = preload("res://gdScripts/pokeSim/conf/global_settings.gd") # Simula las constantes de gs
var bt = preload("res://gdScripts/pokeSim/core/battle.gd") # Simula la clase Battle
var pa = preload("res://gdScripts/pokeSim/util/process_ability.gd") # Simula el manejo de habilidades
var pk = preload("res://gdScripts/pokeSim/core/pokemon.gd") # Simula la clase Pokemon

var weather
var _terrain
var acc_modifier
var weather_count
var gravity_count
var trick_room_count
var gravity_stats
var cur_battle

# Constructor para inicializar la batalla
func _init(battle: Object, terrain: String = gs.OTHER_TERRAIN, weather: String = gs.CLEAR):  # Se usa Object en lugar de bt.Battle
	self.weather = weather
	self._terrain = terrain
	self.acc_modifier = 1
	self.weather_count = -1
	self.gravity_count = 0
	self.trick_room_count = 0
	self.gravity_stats = null
	self.cur_battle = battle


# Función para actualizar el estado del campo de batalla
func update():
	if self.weather_count != 0:
		self.weather_count -= 1
		if self.weather_count != 0:
			if self.weather == gs.SANDSTORM:
				self.cur_battle.add_text("The sandstorm is raging.")
			elif self.weather == gs.RAIN:
				self.cur_battle.add_text("Rain continues to fall.")
			elif self.weather == gs.HARSH_SUNLIGHT:
				self.cur_battle.add_text("The sunlight is strong.")
			elif self.weather == gs.HAIL:
				self.cur_battle.add_text("The hail is crashing down.")
		else:
			if self.weather == gs.SANDSTORM:
				self.cur_battle.add_text("The sandstorm subsided.")
			elif self.weather == gs.RAIN:
				self.cur_battle.add_text("The rain stopped.")
			elif self.weather == gs.HARSH_SUNLIGHT:
				self.cur_battle.add_text("The harsh sunlight faded.")
			elif self.weather == gs.HAIL:
				self.cur_battle.add_text("The hail stopped.")

	if self.gravity_count > 0:
		self.gravity_count -= 1
		if self.gravity_count == 0:
			self.acc_modifier = 1
			self.cur_battle.t1.current_poke.grounded = false
			self.cur_battle.t2.current_poke.grounded = false

	if self.trick_room_count > 0:
		self.trick_room_count -= 1
		if self.trick_room_count == 0:
			self.cur_battle.add_text("The twisted dimensions returned to normal!")

# Cambia el clima en el campo de batalla
func change_weather(weather: int):
	if self.weather != weather:
		self.weather = weather
		pa.weather_change_abilities(self.cur_battle, self)

# Procesa los efectos del clima sobre el Pokémon
func process_weather_effects(poke: Pokemon):
	if not poke.is_alive or self.weather_count >= 999:
		return

	if self.weather == gs.SANDSTORM and not self.poke.has_ability("sand-veil") and not self.poke.in_ground and not self.poke.in_water and not self.poke.types.has("ground") and not self.poke.types.has("steel") and not self.poke.types.has("rock"):
		self.cur_battle.add_text(self.poke.nickname + " is buffeted by the Sandstorm!")
		self.poke.take_damage(max(1, self.poke.max_hp / 16))#TODO div entero

	if self.weather == gs.HAIL and not self.poke.has_ability("ice-body") and not self.poke.in_ground and not self.poke.in_water and not self.poke.types.has("ice"):
		self.cur_battle.add_text(self.poke.nickname + " is buffeted by the Hail!")
		self.poke.take_damage(max(1, self.poke.max_hp / 16))#TODO div entero

	if self.weather == gs.HAIL and self.poke.has_ability("ice-body"):
		self.cur_battle.add_text(self.poke.nickname + " was healed by its Ice Body!")
		var text_skip=true
		self.poke.heal(max(1, self.poke.max_hp / 16), text_skip)#TODO div entero

	if self.weather == gs.RAIN and self.poke.has_ability("dry-skin"):
		self.cur_battle.add_text(self.poke.nickname + " was healed by its Dry Skin!")
		var text_skip=true
		self.poke.heal(max(1, self.poke.max_hp / 8), text_skip)#TODO div entero

	if self.weather == gs.HARSH_SUNLIGHT and self.poke.has_ability("dry-skin"):
		self.cur_battle.add_text(self.poke.nickname + " was hurt by its Dry Skin!")
		self.poke.take_damage(max(1, self.poke.max_hp / 8))#TODO div entero
