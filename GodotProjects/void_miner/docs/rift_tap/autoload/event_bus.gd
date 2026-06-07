extends Node
## Global signal hub. Holds NO state — only signals.
## All cross-system communication goes through here so systems never hold
## direct references to each other.

# --- Currency / economy (M1) ---
signal essence_changed(value: float)
signal flux_changed(value: float)
## Emitted ~once per second with smoothed rates.
## Keys: emit_per_sec, captured_per_sec, lost_per_sec, inflight_total
signal stats_updated(stats: Dictionary)

# --- Buildings (M2+) ---
signal building_purchased(data)
signal building_placed(data, ring: int, slot: int)
## UI coordination: emitted when the player arms a building in the shop for placement.
## Keeps the shop and the board decoupled (neither references the other).
signal build_selection_changed(data)

# --- Surges (M3+) ---
signal surge_warning(seconds: float)
signal surge_started(data)
signal surge_resolved(success: bool)

# --- Prestige (M4+) ---
signal prestige_completed(echoes: float)
