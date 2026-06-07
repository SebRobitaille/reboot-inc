extends Node
## Global signal hub. Holds NO state — only signals.
## All cross-system communication goes through here so systems never hold
## direct references to each other.

# --- Currency / economy (M1) ---
signal essence_changed(value: float)
signal flux_changed(value: float)
## Fired on a manual portal tap (for audio/feedback).
signal portal_tapped()
## Emitted ~once per second with smoothed rates.
## Keys: emit_per_sec, captured_per_sec, lost_per_sec, inflight_total
signal stats_updated(stats: Dictionary)

# --- Buildings (M2+) ---
signal building_purchased(data)
signal building_placed(data, ring: int, slot: int)
## UI coordination: emitted when the player arms a building in the shop for placement.
## Keeps the shop and the board decoupled (neither references the other).
signal build_selection_changed(data)

# --- Surges (M3) ---
## Counts down each frame during the warning phase (seconds until the window opens).
signal surge_warning(seconds: float)
## Window opened. `threshold` = destabilization needed to clear.
signal surge_started(threshold: float)
## Window progress, ~once per second: accumulated destabilization vs threshold and
## seconds left in the window.
signal surge_progress(destabilization: float, threshold: float, seconds_left: float)
signal surge_resolved(success: bool)

# --- Depth / cores (M3) ---
signal depth_changed(depth: int)
signal rift_cores_changed(cores: int)

# --- Overclock ability (M3) ---
## State dict: { unlocked: bool, active: bool, on_cooldown: bool, time_left: float }
signal overclock_changed(state: Dictionary)

# --- Run lifecycle ---
## Emitted after GameState resets to a fresh run (launch or collapse) so UI rebuilds.
signal run_reset()
## Emitted after a save file is loaded and applied (M5).
signal game_loaded()

# --- Prestige (M4) ---
signal echoes_changed(echoes: float)
signal prestige_node_purchased(node)
## Live collapse value + whether to glow the Collapse button (plateau reached).
signal prestige_ready(echoes_on_collapse: float, glow: bool)
signal prestige_completed(echoes: float)
