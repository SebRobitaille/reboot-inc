# Rift Tap — Game Design & Architecture Doc

> **Working title:** *Rift Tap* (rename freely — search/replace the title).
> **Engine:** Godot 4.6 (GDScript)
> **Genre:** Idle / incremental. Decision-driven, not click-driven.
> **Target length:** ~20–40 hours to clear the main prestige progression.

---

## 0. How to use this document (for the implementing agent)

This is the source of truth for design intent **and** architecture. When implementing:

- Build in the **milestone order** in §10. Don't jump ahead; each milestone is a playable checkpoint.
- The **economy is a deterministic tick-based simulation** (§4). The visual layer (particles, animations) is **cosmetic only** and must never drive game state. Never compute economy from particle positions.
- All tunable numbers live in `Balance` (autoload) or in `*Data` Resource files — **no magic numbers in logic scripts**.
- Building/prestige/surge definitions are **data-driven** via custom `Resource` classes so designers can add content without touching systems code.
- When in doubt about a design choice, preserve the **Design Pillars** (§1) over convenience.

---

## 1. Design pillars

1. **Tension over multipliers.** Power comes from the *geometry and throughput* of production vs. collection vs. decay — not from stacking raw "+1000%" bonuses. Multipliers are seasoning. If a feature can express its power as a behavior change ("portal emits a 3-burst") instead of a percentage, prefer the behavior change.
2. **The player's verb is allocation.** The actionable gameplay is *who you hire and where you place them*. Clicking the portal is a start-of-run bootstrap only, and prestige upgrades phase it out entirely.
3. **A real challenge every ~25 minutes.** Portal Surges are allocation/preparation tests at the player's current frontier. The player should never feel safe AFKing indefinitely.
4. **Every prestige hands you a new toy.** Each reset unlocks a new building type or portal mechanic, and where you invest prestige points visibly changes which buildings dominate (which guides placement).
5. **Legibility.** The player can always see why they're growing or stalling: per-building stats, essence lost to the Rift, and a clear "prestige now" signal.

### Anti-goals (do not do these)
- No frantic clicking as a sustained mechanic.
- No opaque scaling where every upgrade is just another flat percent.
- No "AFK for 45 minutes then beat a wall" pacing — the wall comes ~every 25 min.
- No per-particle pathfinding or physics driving the economy.

---

## 2. Core loop

1. **Fresh run start:** little automation. Player clicks the portal to emit the first essence and clicks essence to collect it, bootstrapping enough Essence to buy the first Extractor + Collector. (Resonance-tree prestige nodes progressively automate this away — see §7.)
2. **Automate:** buy/place Extractors (make essence) and Collectors (catch it before the Rift reclaims it). Spend the three in-run currencies (§3) on more workers, deeper buildings, and unlocks.
3. **Push depth:** clear **Portal Surges** (§6) to gain Rift Cores and advance depth tiers.
4. **Collapse (prestige):** when growth plateaus, collapse the portal for **Echoes** (§7), spend them across three trees, and restart faster and stronger.
5. Repeat. Runs shrink over the playthrough (early game gets faster); the ~25-min Surge wall reasserts at the new frontier.

---

## 3. Currencies

### In-run currencies (reset on prestige)
| Currency | Source | Spent on | Player question it answers |
|---|---|---|---|
| **Essence** | Collected by Collectors from the portal's emission | Hiring workers (exponential cost) | *How many workers, of which type?* |
| **Flux** | Byproduct of essence **throughput** (a fraction of essence collected/sec) | Leveling individual buildings + support structures | *Which buildings do I deepen?* |
| **Rift Cores** | Discrete reward for clearing a Surge | Unlocking new building **types** + biggest power spikes | *What do I unlock next?* |

Rift Cores gate new content, so progression is tied to beating Surges — you cannot AFK your way to new toys.

### Meta currency (persists across prestige)
| Currency | Source | Spent on |
|---|---|---|
| **Echoes** | Banked on collapse, scaled by depth reached + cores earned | The three prestige trees (§7) |

---

## 4. The economy simulation (the heart of the game)

**Model the economy as a deterministic, tick-based ring-flow simulation.** It is cheap (O(rings × buildings)) and makes placement meaningful. The visual particle layer is cosmetic and reads from this state.

### Ring-flow model
- The board is **concentric rings** `0..N` (start with **N = 3**, i.e. 4 rings: ring 0 innermost). Each ring has a fixed number of **slots** for buildings.
- Each economy tick (fixed timestep, see below):
  1. **Emit:** the portal injects `emit_per_tick` essence into ring 0's *in-flight pool*. `emit_per_tick` = Σ(Extractor emission in all rings) × global extraction multipliers.
  2. **Flow inward→outward:** for each ring `r` from inner to outer:
     - Collectors in ring `r` capture `captured_r = min(inflight_r, collect_capacity_r)`. Add `captured_r` to the Essence balance.
     - A drift-loss fraction `drift_loss_r` of the *remaining* in-flight decays this ring (reduced by Stabilizers/Conveyors in/near ring `r`).
     - Remaining in-flight passes to ring `r+1`.
  3. **Reclaim:** essence still in-flight after the outer ring is **reclaimed by the Rift** (lost — or fed to a Void Siphon late game; see §8).
- `collect_capacity_r` = Σ(Collector pickup in ring `r`) × global collection multipliers, plus area effects (e.g. Magnet Pylon reaches adjacent slots).

**Why this matters:** Inner Extractors produce more total essence but it must survive more rings. Over-stack Extractors → essence floods past collection capacity → bleeds to the Rift. Over-stack Collectors → idle capacity. The balance point *is* the gameplay, and it produces the per-building stats players want (each building logs produced/captured/lost).

### Flux generation
`flux_per_tick` = `essence_captured_this_tick` × `flux_rate` × (Refinery multipliers). `flux_rate` is small (starter: 0.02) so Flux stays scarce relative to Essence.

### Tick & framerate independence
- Run the economy on a **fixed timestep accumulator** (e.g. 10 Hz: `ECON_TICK = 0.1s`), decoupled from `_process`. Accumulate `delta` and run whole ticks. This keeps the sim deterministic and identical regardless of FPS, and makes offline progress (§9) trivially "run N ticks."
- Visuals interpolate/animate in `_process`; they never feed back into the sim.

### Manual bootstrap (start-of-run clicking)
- Clicking the portal injects a flat `manual_emit` burst into ring 0. Clicking floating essence adds a flat `manual_collect`. Both exist to get the first ~2 buildings affordable.
- Resonance-tree nodes grant starting Essence / pre-placed starter buildings / an auto-clicker, shrinking required clicking toward zero over the playthrough.

---

## 5. Buildings (roster of 10, headroom to 12)

Buildings are **data-driven** via a `BuildingData` Resource (§9 data model). Each instance tracks lifetime stats. `preferred_ring` is a soft hint that grants a bonus when placed there; players can still place anywhere.

### Extractors (prefer inner rings)
| Building | Role | Buy currency | Notes |
|---|---|---|---|
| **Channeler** | Steady emission | Essence | Starter. Available turn 1. |
| **Rupture Drill** | Periodic large burst (every K ticks) | Essence | Spiky output; pairs with strong collection. |
| **Resonant Lance** | Emission scales with current depth / Surges cleared | Rift Core (unlock) | Late-bloomer. |

### Collectors (prefer mid/outer rings)
| Building | Role | Buy currency | Notes |
|---|---|---|---|
| **Gather-Sprite** | Baseline auto-collect | Essence | Starter. |
| **Magnet Pylon** | Captures from its slot **and adjacent slots** | Essence / Flux | Coverage tool. |
| **Conveyor Node** | Reduces drift-loss in its ring (extends collect window) + light collect | Flux | Support/collector hybrid. |

### Support / Economy
| Building | Role | Buy currency | Notes |
|---|---|---|---|
| **Stabilizer** | Globally reduces drift-loss (slows Rift reclaim) | Flux | |
| **Refinery** | Raises Flux conversion rate + essence value | Flux | |
| **Echo Chamber** | Boosts Echoes gained on collapse | Rift Core (unlock) | Prestige-value play. |
| **Overclock Spire** | Activated ability: large emission + collection burst for one Surge window | Rift Core (unlock) | Your "survive the wall" tool. Cooldown-gated, not spam. |

### Late unlockables (fill 11–12)
- **Void Siphon** — captures a fraction of essence the Rift reclaims, flipping the sink into an upside late game.
- **Twin Portal** — a portal mechanic that opens a second emission source / mirrors a ring.

### Early vs. late identity
- **Early stars:** Channeler, Gather-Sprite.
- **Late stars:** Resonant Lance, Echo Chamber, Void Siphon.
This deliberately makes some workers more valuable early and others scale into the late game.

### Cost scaling
Per-building cost is exponential in the count *of that building type*:
`cost(n) = base_cost × growth^n` with starter `growth = 1.13`.
This forces the focus decision (deepen one type vs. diversify). Tune `growth` per building so spiky/late buildings ramp differently.

---

## 6. Portal Surges (the ~25-minute wall)

A Surge is an **allocation/preparation test**, not a click test.

### Flow
1. **Warning phase** (~30–60s): a pre-Surge banner; the player may re-hire/re-place freely. (Optionally pause cost ramps here.)
2. **Surge window** (fixed duration, e.g. 90s): the portal "resists." The player must accumulate **destabilization** ≥ `surge_threshold` within the window. `destabilization_per_tick` = net essence captured that tick (so it rewards *both* high production and high collection — the whole loop).
3. **Resolve:**
   - **Cleared** → award 1+ Rift Cores, advance one **depth tier**, raise base multipliers slightly.
   - **Failed** → no penalty beyond lost time; player keeps growing and retries. (Never punish harshly; the wall is a gate, not a trap.)

### Keeping cadence at ~25 minutes (rubber-band)
`surge_threshold = peak_net_capture_recent × surge_factor × depth_scalar`
- `peak_net_capture_recent` = rolling peak of net essence/sec over the last few minutes.
- `surge_factor` (starter ~3.0) sets how much *more* than current output is required — i.e. roughly one growth-cycle.
- Tune `surge_factor` and the buy-cost growth together so the frontier Surge consistently takes **~25 min of growth** to clear, while Surges behind the frontier become trivial. This is the core pacing knob — verify it empirically in playtests (§11).

### Within a prestige run
A run spans several Surges (target: ~2 hours early-game, shrinking to a few minutes late as prestige speeds the opening). The player collapses when Echoes/hour plateaus (§7).

---

## 7. Prestige

### Collapse
Collapsing resets all in-run state (currencies, buildings, depth) and banks **Echoes**:
`echoes_gained = floor(echo_k × depth^echo_exp × (1 + cores_earned × core_bonus))`
Starters: `echo_k = 1`, `echo_exp = 1.5`, `core_bonus = 0.25`. Echo Chamber buildings multiply this.

### Three trees, one currency (Echoes)
Investment **mirrors the in-run roles**, so spending guides which buildings become your strongest → guides placement.

- **Extraction tree** — emission boosts; portal mechanics (multi-burst, larger chunks); Extractor abilities; early manual-click power.
- **Collection tree** — collector strength; drift-loss reduction; Rift-timer/window extension; auto-collect; decay mitigation.
- **Resonance tree** — meta/economy: Flux & Rift Core gain; Surge survivability; **offline progress**; and the **auto-bootstrap** nodes (starting Essence, pre-placed starters, auto-clicker) that remove start-of-run clicking. This tree carries the "make early game faster" and "general powers" upgrades.

### Mapping to the four upgrade intents
- *Make early game quicker* → Resonance head-start/auto-bootstrap nodes.
- *Enhance units* → Extraction & Collection nodes.
- *Unlock unit abilities* → mid/late nodes in each tree.
- *Unlock general abilities / empower economy* → Resonance tree.

### New toy every reset
Gate at least one **new building type or portal mechanic** behind an early node in each tree (or behind Rift Core thresholds), so every prestige opens something fresh.

### "Prestige now" signal
Show live `echoes_on_collapse` and its rate of change. When Echoes/hour drops below a threshold (plateau), pulse/glow the Collapse button.

---

## 8. Stats & legibility (don't skip — it's a pillar)

A first-class **Stats panel**:
- Per building: essence **produced**, **captured**, **lost to Rift**, % of total, current/sec, lifetime totals.
- Global counters: total essence/sec in, captured/sec, **lost-to-Rift/sec** (the key "am I overproducing?" readout), Flux/sec, depth, cores.
- A simple recommendation hint is optional ("collection capacity < emission in ring 2").

The **Void Siphon** building (§5) reads the lost-to-Rift number as its input — wiring legibility into a mechanic.

---

## 9. Godot 4.6 architecture

### Folder structure
```
res://
  autoload/        # singletons (see below)
  data/
    buildings/     # *.tres BuildingData resources
    prestige/      # *.tres PrestigeNode resources
    surges/        # *.tres SurgeData resources
  scenes/
    main/          # Main.tscn (root), Board, Ring, Slot
    portal/        # Portal.tscn
    buildings/     # Building.tscn (one scene, configured by BuildingData)
    ui/            # HUD, shop, prestige screen, stats panel
  scripts/
    systems/       # pure logic, no nodes where possible
    ui/
  resources/       # custom Resource class definitions (BuildingData, etc.)
```

### Autoload singletons
- **EventBus** — global signals only (no state). e.g. `essence_changed(amount)`, `building_purchased(data)`, `surge_started(data)`, `surge_resolved(success)`, `prestige_completed(echoes)`. **All cross-system communication goes through here**; systems do not hold direct references to each other.
- **Balance** — every tunable constant + curve function (`building_cost(data, n)`, `surge_threshold(...)`, `echoes_gained(...)`). Single place to tune.
- **GameState** — authoritative run state: currency balances, owned buildings + placements, depth, cores. Emits via EventBus on change.
- **Economy** — runs the fixed-timestep ring-flow sim (§4). Owns `_economy_accumulator`; calls `_tick()` in whole steps.
- **SurgeManager** — schedules/runs Surges, computes thresholds, resolves outcomes.
- **PrestigeManager** — collapse logic, Echoes, tree node state + applied modifiers.
- **SaveManager** — serialize/deserialize GameState + Prestige to disk; offline progress.
- **NumberFormat** — helper for display (K/M/B/T/aa…) and number-to-string.

> Keep autoloads thin and single-purpose. UI subscribes to EventBus signals; it never polls the economy every frame for state it can receive on change (currency labels can refresh on `*_changed` signals or on a low-frequency timer).

### Data-driven Resources
Define custom `Resource` classes with `@export` fields so content is editable in the Inspector and addable without code:

```gdscript
# resources/building_data.gd
class_name BuildingData
extends Resource

@export var id: StringName
@export var display_name: String
@export var category: int        # enum Extractor / Collector / Support
@export var buy_currency: int    # enum Essence / Flux / RiftCore
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.13
@export var base_emission: float = 0.0       # extractors
@export var base_collect: float = 0.0        # collectors
@export var preferred_ring: int = -1         # -1 = none; grants a bonus if matched
@export var unlock_requirement: int = 0      # rift cores needed to unlock
@export var icon: Texture2D
@export var description: String
```

One `Building.tscn` is configured at runtime from its `BuildingData`. Same pattern for `PrestigeNode` (cost in Echoes, prereqs, modifier payload) and `SurgeData`.

### Numbers / scaling
- Godot floats are 64-bit doubles (~1.8e308 max) — sufficient for a 20–40h game with `growth ≈ 1.13`. **Centralize formatting in `NumberFormat`** from day one.
- If late-game values approach precision limits during balancing, introduce a `BigNumber` (mantissa+exponent) wrapper behind the currency API rather than retrofitting later. Keep the currency interface abstract enough to swap.

### Save / load + offline progress
- Serialize GameState + Prestige to a `Dictionary` → JSON via `FileAccess` (`user://save.json`). Store a `last_saved_unix` timestamp.
- **Offline progress** = "run the sim forward": on load, compute elapsed ticks since `last_saved_unix`, cap them (Resonance node raises the cap), and run `Economy._tick()` that many times (or use a closed-form approximation if N is huge). Because the sim is deterministic and tick-based, offline is just fast-forward.
- Autosave on a timer + on key events (purchase, surge resolve, prestige).

---

## 10. Implementation roadmap (build in this order)

Each milestone ends at a playable checkpoint. Don't proceed until the current one runs.

- **M0 — Skeleton.** Project, autoloads (EventBus, Balance, GameState, Economy stubs), `Main.tscn`, a HUD showing Essence. Fixed-timestep tick loop printing a heartbeat.
- **M1 — Core loop, hardcoded.** Portal + manual click bootstrap. One Extractor + one Collector hardcoded. Ring-flow sim (§4) with 4 rings. Essence flows, is captured, and excess is reclaimed by the Rift. You can earn Essence by hand then watch it automate.
- **M2 — Data-driven buildings.** `BuildingData` resources, ring/slot board, buy + place UI, exponential costs, Flux generation, Refinery/Stabilizer effects. Full starter roster minus core-locked buildings.
- **M3 — Surges & depth.** SurgeManager, warning + window + resolve, rubber-band threshold, Rift Cores, depth tiers, Overclock Spire ability. Verify the ~25-min cadence feel.
- **M4 — Prestige.** Collapse → Echoes, three trees as PrestigeNode resources, modifier application, auto-bootstrap nodes, "prestige now" signal. Full prestige loop closes.
- **M5 — Legibility & persistence.** Stats panel (§8), save/load, offline progress, number formatting.
- **M6 — Content & polish.** Core-locked buildings (Resonant Lance, Echo Chamber, Void Siphon, Twin Portal), full tree fill-out, balance pass, visual juice (cosmetic particles reading from sim state), audio.

---

## 11. Starter balance table (tune in playtesting)

| Constant | Starter value | Notes |
|---|---|---|
| `ECON_TICK` | 0.1 s (10 Hz) | Fixed timestep |
| Rings (N) | 3 (4 rings) | Slots per ring: 3–4 |
| `manual_emit` / click | 1.0 | Phased out by prestige |
| `flux_rate` | 0.02 | Flux scarcity |
| `cost_growth` (default) | 1.13 | Per-building, override per type |
| `drift_loss_r` (default) | 0.10 per ring | Lenient early; Stabilizers reduce |
| Surge window | 90 s | |
| Surge warning | 45 s | |
| `surge_factor` | 3.0 | Primary cadence knob |
| `echo_k` / `echo_exp` / `core_bonus` | 1 / 1.5 / 0.25 | Echoes formula |

**Pacing validation:** the single most important playtest check is that the *frontier* Surge takes ~25 min of growth to clear across the whole 20–40h arc. If it drifts, adjust `surge_factor` and `cost_growth` together — they are coupled.

---

## 12. Glossary
- **Essence** — primary in-run currency (collected from portal emission).
- **Flux** — throughput byproduct; deepens buildings/support.
- **Rift Core** — Surge reward; unlocks content.
- **Echoes** — meta prestige currency; three trees.
- **Rift reclaim / drift-loss** — the anti-overproduction sink; uncollected essence is lost as it crosses rings.
- **Surge** — the ~25-min allocation challenge.
- **Collapse** — the prestige action.
- **Depth tier** — progression layer advanced by clearing Surges.