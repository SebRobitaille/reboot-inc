# Rift Tap — M0/M1 starter (Godot 4.6)

A running heartbeat for milestones **M0 (skeleton)** and **M1 (core loop, hardcoded)**
from the design doc. The economy is the real deterministic ring-flow simulation — not a
placeholder — so you can feel the production → collection → decay loop before any content.

## Run it

1. Open Godot 4.6, **Import** → select this folder's `project.godot`.
2. Press **Play** (F5). The five autoloads are already registered and `Main.tscn` is set as
   the main scene, so it should just run.

## What you'll see

A small HUD top-left:

- **Essence** climbing on its own (the hardcoded Channeler emits, the Gather-Sprite collects).
- **Flux** ticking up slowly as a byproduct of captured essence.
- A rate line: `emit/s`, `captured/s`, **`lost to Rift/s`**, and current `in-flight`.
- **Tap Portal** injects essence into ring 0 (the start-of-run bootstrap).
- **Collect Essence** grabs in-flight essence by hand.

> **`lost to Rift/s` will be non-zero — that's intentional.** The starter Collector sits two
> rings outside the Extractor, so some essence drifts past it and is reclaimed. This is the
> placement lesson the whole game is built on. Move the Gather-Sprite to ring 0 or 1 in
> `game_state.gd::setup_m1_starter()` and watch the loss drop.

## File map

```
project.godot                 # autoloads + main scene, openable as-is
autoload/
  event_bus.gd                # global signals only (no state)
  balance.gd                  # all tunable constants + curve functions
  game_state.gd               # authoritative in-run state; M1 hardcoded loadout
  economy.gd                  # the fixed-timestep ring-flow simulation
  number_format.gd            # display formatting (K/M/B/T...)
scenes/main/
  Main.tscn                   # root node with main.gd attached
  main.gd                     # code-built HUD + button wiring (temporary, replace in M2)
```

## Design rules baked in (keep these)

- **Economy is deterministic and tick-based** (10 Hz fixed timestep with an accumulator),
  framerate-independent. Future particles/animations are cosmetic and must never feed back in.
- **All cross-system talk goes through `EventBus`.** Systems don't reference each other directly.
- **No magic numbers** outside `balance.gd`.
- **Clicking is bootstrap only** — it exists to afford the first buildings and gets automated
  away by prestige later.

## Next: hand to Claude Code for M2

Point Claude Code at the GDD and this folder, then ask it to implement **M2 — data-driven
buildings**: a `BuildingData` Resource class, the ring/slot board UI, buy + place flow with
exponential costs (`Balance.building_cost`), and the support buildings (Refinery, Stabilizer).
`game_state.gd` already exposes `emission_by_ring()` / `collection_by_ring()`, so M2 mainly
swaps the hardcoded `placements` dictionaries for real `BuildingData`-driven placements feeding
those same two methods — the economy doesn't change.
