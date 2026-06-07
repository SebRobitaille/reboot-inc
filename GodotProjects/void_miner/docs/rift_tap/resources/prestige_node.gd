class_name PrestigeNode
extends Resource
## A single prestige-tree upgrade, bought with Echoes. Data-driven: instances live
## as .tres in data/prestige/, so designers add nodes without touching systems code.
## Each node grants ONE typed modifier of a given magnitude; PrestigeManager sums
## the magnitudes of all owned nodes per effect and applies them.

# Named Branch (not Tree) — Tree is a native Godot Control class.
enum Branch { EXTRACTION, COLLECTION, RESONANCE }

## What the node does. PrestigeManager interprets `magnitude` per effect:
##  EXTRACTION_MULT / COLLECTION_MULT / FLUX_MULT / ECHO_MULT — additive to a x1.0 base
##  DRIFT_REDUCTION  — fraction subtracted from the drift multiplier
##  START_ESSENCE    — Essence granted at each run start
##  AUTOCLICK        — auto-tap strength (taps the portal + collects on a timer)
##  CORE_GAIN        — extra Rift Cores per cleared surge
##  PREPLACE_STARTER — extra Channelers pre-placed at run start
enum Effect {
	EXTRACTION_MULT, COLLECTION_MULT, FLUX_MULT, DRIFT_REDUCTION,
	START_ESSENCE, AUTOCLICK, CORE_GAIN, ECHO_MULT, PREPLACE_STARTER,
}

@export var id: StringName
@export var display_name: String = ""
@export var tree: Branch = Branch.EXTRACTION
@export var effect: Effect = Effect.EXTRACTION_MULT
@export var magnitude: float = 0.0
@export var cost: float = 1.0              # Echoes
## Single prerequisite node id (empty = a tree root). Kept to one for M4 simplicity.
@export var prereq: StringName = &""
@export var description: String = ""
