# Tesla Incremental — Chain-Lightning Defense (Godot 4.x)

## Stack
- Godot 4.x, GDScript, fully typed.

## Conventions
- Autoloads for global state (EnergyPool, GoldWallet); signals to decouple nodes.
- All tunable combat numbers live in PlayerStats — never hard-code stats in scripts.
- Resources (.tres) for data-driven content (cards, enemies); small single-responsibility scenes.
- No web-dev analogies in comments or explanations.

## Layout
- scenes/      entities & main scene
- scripts/     gameplay scripts
- resources/   .tres data (cards, enemy/stat defs)
- docs/design/ specs (read shop-economy.md before gameplay work)

## Current focus
- Milestone 1: playable core combat.

## Always
- Propose a file/scene plan before large changes.
- Use Godot 4.x APIs only; flag uncertainty instead of inventing APIs.