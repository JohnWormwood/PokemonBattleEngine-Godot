# PokeBattleSim-Godot

**PokeBattleSim-Godot** is a real-time Pokémon battle simulator developed in Godot Engine, inspired by open-source Pokémon battle simulation projects. The original project is based on [poke-battle-sim](https://github.com/hiimvincent/poke-battle-sim), and I am currently working on upgrading it using the enhanced version from [pykemon](https://github.com/thomas18F/pykemon). Thanks for checking it out!

## Overview

**PokeBattleSim-Godot** replicates the battle mechanics found in Generation IV Pokémon games (Diamond, Pearl, Platinum) and is designed to be easily expandable and customizable.

The project supports all content from the first four Pokémon generations, including:

- 493 Pokémon
- 467 Moves
- 122 Abilities
- 535 Items

## Installation

To get started with **PokeBattleSim-Godot**, clone this repository to your local machine and copy all files to your **Godot 4.3**(stable).
Remember to fix any directory errors.

### Getting Started
Setting up a battle in Godot is simple.
Add **testSim.gd** to the start of the scene and the emulator will run with the data entered in **turn()**

```gdscript
# Setting up trainers and Pokémon
var pikachu = Pokemon.new("Pikachu", 50, ["thunderbolt", "quick-attack", "iron-tail", "thunder"])
var ash = Trainer.new("Ash", [pikachu])

var starmie = Pokemon.new("Starmie", 50, ["surf", "tackle", "psychic", "thunderbolt"])
var misty = Trainer.new("Misty", [starmie])

# Starting the battle
var battle = Battle.new(ash, misty)
battle.start()
battle.turn(["move", "thunderbolt"], ["move", "surf"])

#turn 2
t1_action = ['move', 'thunder']
t2_action = ['move', 'psychic'] 
battle.turn(t1_action, t2_action)

# Get battle text output
print(battle.get_all_text())

```

### Features
Single Pokémon battle simulation from Generation IV. Full support for trainers, moves, abilities, and items.

Easy customization and expansion to add new mechanics or generations.

Good integration with Godot Engine to take advantage of its graphical and gameplay features.
### Limitations
Currently, PokeBattleSim-Godot does not support double battles or mechanics introduced in later generations. We are working on expanding support in future updates.

Mechanics not implemented in poke-battle-sim include:

- Using Nintendo DS audio volume data in damage calculation
- Using terrain-based type and power modifications
- Any glitches in the original games that were patched in subsequent generations

#### Credits
This project was inspired by:

[poke-battle-sim](https://github.com/hiimvincent/poke-battle-sim "poke-battle-sim") - the original project by Vincent Johnson.

[pykemon](https://github.com/thomas18F/pykemon "pykemon") - an enhanced version of the Pokémon battle simulation in Python.

##### References used during development:

[Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Main_Page "Bulbapedia")

[PokemonDB](https://pokemondb.net/ "PokemonDB")

[Serebii.net](https://serebii.net/ "Serebii.net")
