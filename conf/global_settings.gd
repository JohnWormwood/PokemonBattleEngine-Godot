# CSV Paths
const DATA_DIR = 'poke_battle_sim.data'
const POKEMON_STATS_CSV = 'pokemon_stats.csv'
const NATURES_CSV = 'natures.csv'
const MOVES_CSV = 'move_list.csv'
const TYPE_EF_CSV = 'type_effectiveness.csv'
const ABILITIES_CSV = 'abilities.csv'
const ITEMS_CSV = 'items_gen4.csv'

# Stat Ranges
const LEVEL_MIN = 1
const LEVEL_MAX = 100
const STAT_ACTUAL_MIN = 1
const STAT_ACTUAL_MAX = 500
const IV_MIN = 0
const IV_MAX = 31
const EV_MIN = 0
const EV_MAX = 255
const EV_TOTAL_MAX = 510
const NATURE_DEC = 0.9
const NATURE_INC = 1.1

# Misc Settings
const POKE_NUM_MIN = 1
const POKE_NUM_MAX = 6
const POSSIBLE_GENDERS = ['male', 'female', 'genderless']
const COMPLETED_MOVES = 467

# Non-volatile Statuses
const BURNED = 1
const FROZEN = 2
const PARALYZED = 3
const POISONED = 4
const ASLEEP = 5
const BADLY_POISONED = 6

# Non-volatile Status Conversion
const NV_STATUSES = {
	'burned': 1,
	'frozen': 2,
	'paralyzed': 3,
	'poisoned': 4,
	'asleep': 5,
	'badly poisoned': 6
}

# Volatile Statuses
const V_STATUS_NUM = 9
const CONFUSED = 0
const FLINCHED = 1
const LEECH_SEED = 2
const BINDING_COUNT = 3
const NIGHTMARE = 4
const CURSE = 5
const DROWSY = 6
const INGRAIN = 7
const AQUA_RING = 8

# Binding Types
const BIND = 1
const WRAP = 2
const FIRE_SPIN = 3
const CLAMP = 4
const WHIRLPOOL = 5
const SAND_TOMB = 6
const MAGMA_STORM = 7

# Weather Types
const CLEAR = "clear"
const HARSH_SUNLIGHT = "sunny"
const RAIN = "rain"
const SANDSTORM = "sandstorm"
const HAIL = "hail"
const FOG = "fog"

const WEATHERS = [CLEAR, HARSH_SUNLIGHT, RAIN, SANDSTORM, HAIL, FOG]

# Terrain Types
const BUILDING = "building"
const DISTORSION_WORLD = "distorsion-world"
const SAND = "sand"
const CAVE = "cave"
const TALL_GRASS = "tall-grass"
const WATER = "water"
const SNOW = "snow"
const ICE = "ice"
const OTHER_TERRAIN = "other"

const TERRAINS = [BUILDING, DISTORSION_WORLD, SAND, CAVE, TALL_GRASS, WATER, SNOW, ICE, OTHER_TERRAIN]

# Stat Ordering Format
const HP = 0
const ATK = 1
const DEF = 2
const SP_ATK = 3
const SP_DEF = 4
const SPD = 5
const STAT_NUM = 6
const ACC = 6
const EVA = 7

const STAT_TO_NAME = ['Health', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed', 'accuracy', 'evasion']

# Move Categories
const STATUS = 1
const PHYSICAL = 2
const SPECIAL = 3


# Move Range
const MOVES_MAX = 4

# Base Pokemon Stats Formatting
const NDEX = 0
const NAME = 1
const TYPE1 = 2
const TYPE2 = 3
const STAT_START = 4
# HP = 4, ATK = 5, DEF = 6, SP_ATK = 7, SP_DEF = 8, SPD = 9
const HEIGHT = 10
const WEIGHT = 11
const BASE_EXP = 12
const GEN = 13

# Move Data Formatting
const MOVE_ID = 0
const MOVE_NAME = 1
const MOVE_TYPE = 3
const MOVE_POWER = 4
const MOVE_PP = 5
const MOVE_ACC = 6
const MOVE_PRIORITY = 7
const MOVE_TARGET = 8
const MOVE_CATEGORY = 9
const MOVE_EFFECT_ID = 10
const MOVE_EFFECT_CHANCE = 11
const MOVE_EFFECT_AMT = 12
const MOVE_EFFECT_STAT = 13

# CSV Numerical Columns
const POKEMON_STATS_NUMS = [0, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
const MOVES_NUM = [0, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

# Player Turn Actions
const ACTION_PRIORITY = {
	'other': 3,
	'item': 2,
	'move': 1
}

# Turn Data
const ACTION_TYPE = 0
const ACTION_VALUE = 1
const ITEM_TARGET_POS = 2
const MOVE_TARGET_POS = 3

# Pre-process Move Data
const PPM_MOVE = 0
const PPM_MOVE_DATA = 1
const PPM_BYPASS = 2

# Item Thresholds
const BERRY_THRESHOLD = 0.5
const DAMAGE_THRESHOLD = 0.25
