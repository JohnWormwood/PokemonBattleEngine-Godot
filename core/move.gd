extends Resource
class_name Move
# Importar configuraciones
const gs = preload("res://gdScripts/pokeSim/conf/global_settings.gd")

#region Var

var move_data: Array
var id
@export var name: String
var type
var original_power
var power
var max_pp
var acc
var prio
var target
var category
var ef_id
var ef_chance
var ef_amount
var ef_stat
var cur_pp
var pos
var disabled
var encore_blocked
#endregion

# Constructor
func _init():
	pass
func set_move_data(move_data: Array):
	self.move_data = move_data
	self.id = move_data[gs.MOVE_ID]
	self.name = move_data[gs.MOVE_NAME]
	self.type = move_data[gs.MOVE_TYPE]  # Asegúrate de que esto sea una cadena de texto
	self.original_power = move_data[gs.MOVE_POWER]
	self.power = move_data[gs.MOVE_POWER]
	self.max_pp = move_data[gs.MOVE_PP]
	self.acc = move_data[gs.MOVE_ACC]
	self.prio = move_data[gs.MOVE_PRIORITY]
	self.target = move_data[gs.MOVE_TARGET]
	self.category = move_data[gs.MOVE_CATEGORY]
	self.ef_id = move_data[gs.MOVE_EFFECT_ID]
	self.ef_chance = move_data[gs.MOVE_EFFECT_CHANCE]
	self.ef_amount = move_data[gs.MOVE_EFFECT_AMT]
	self.ef_stat = move_data[gs.MOVE_EFFECT_STAT]
	self.cur_pp = self.max_pp
	return self

# Método para resetear el movimiento
func reset():
	self.cur_pp = self.max_pp
	self.pos = null
	self.disabled = 0
	self.encore_blocked = false
	self.power = self.md[gs.MOVE_POWER]
	self.max_pp = self.md[gs.MOVE_PP]
	self.acc = self.md[gs.MOVE_ACC]
	self.prio = self.md[gs.MOVE_PRIORITY]
	self.category = self.md[gs.MOVE_CATEGORY]
	self.ef_id = self.md[gs.MOVE_EFFECT_ID]
	self.ef_chance = self.md[gs.MOVE_EFFECT_CHANCE]
	self.ef_amount = self.md[gs.MOVE_EFFECT_AMT]
	self.ef_stat = self.md[gs.MOVE_EFFECT_STAT]

# Método para obtener una copia del movimiento
func get_tcopy() -> Move:
	var copy = Move.new().set_move_data(self.move_data)
	copy.ef_id = self.ef_id
	copy.ef_amount = self.ef_amount
	copy.ef_stat = self.ef_stat
	copy.cur_pp = self.cur_pp
	copy.pos = self.pos
	copy.disabled = self.disabled
	return copy
