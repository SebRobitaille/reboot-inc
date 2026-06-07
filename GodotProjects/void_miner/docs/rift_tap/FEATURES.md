# Rift Tap — Features & Formulas

A decision-driven idle/incremental game in Godot 4.6. Power comes from the
**geometry and throughput** of production vs. collection vs. decay — not from raw
percentage stacking. Your verb is **allocation**: who you hire and *where* you place
them. This document describes every implemented feature and the exact formulas behind
it. All tunable constants live in `autoload/balance.gd` (referenced below as
`Balance.X`); no magic numbers live in logic scripts.

---

## 1. The core loop

1. **Bootstrap.** A fresh run starts with little automation. You tap the portal to
   emit the first Essence and collect it by hand, enough to buy your first buildings.
   (Prestige's Resonance tree automates this away over time.)
2. **Automate.** Buy **Extractors** (make Essence) and **Collectors** (catch it before
   the Rift reclaims it), placing them across the ring board. Balance production
   against collection — over-produce and Essence floods past your collectors and bleeds
   to the Rift; over-collect and capacity sits idle.
3. **Push depth.** Clear **Portal Surges** (§5) to earn **Rift Cores** and advance a
   **depth tier**, which permanently strengthens you and unlocks new building types.
4. **Collapse (prestige).** When growth plateaus, collapse the portal for **Echoes**
   (§6), spend them across three trees, and restart faster and stronger.
5. Repeat. Each run reaches deeper than the last.

---

## 2. The ring economy (the heart of the game)

A deterministic, fixed-timestep simulation. The board is **4 concentric rings**
`0..3` (ring 0 = innermost, nearest the portal), each with **4 slots**
(`Balance.RING_COUNT = 4`, `Balance.SLOTS_PER_RING = 4` → 16 slots). The sim runs at
**10 Hz** (`Balance.ECON_TICK = 0.1s`) on an accumulator, so it's framerate-independent
and identical regardless of FPS. Any visual layer is cosmetic and never feeds back in.

Each tick, for `tick = Balance.ECON_TICK`:

**1. Emit** — extractors inject Essence into their ring's in-flight pool:

```
emission[r]  = Σ_extractors_in_r ( base_emission · (1 + emission_depth_scale · depth) · burst(t) · placement_bonus )
             + Σ_twin_portals_in_r ( mirror_fraction · emission_base[0] )
emission[r] *= extraction_mult · surge_emission_mult · prestige_extraction_mult
inflight[r] += emission[r] · tick

placement_bonus = 1 + Balance.PREFERRED_RING_BONUS (0.25)   if placed on the building's preferred_ring, else 1
burst(t)        = burst_period                              if burst_period>0 and tick_count % burst_period == 0
                = 0                                          if burst_period>0 otherwise
                = 1                                          if burst_period == 0  (steady)
```

**2. Flow inner → outer** — for each ring `r` from 0 to 3:

```
capacity[r] = Σ_collectors_covering_r ( base_collect · placement_bonus )      # a Magnet Pylon covers r ± collect_radius
capacity[r] *= collection_mult · surge_collection_mult · prestige_collection_mult

captured = min(inflight[r], capacity[r] · tick)            # collected this tick -> banked Essence
inflight[r] -= captured

outflow  = inflight[r] · Balance.FLOW_FRACTION (0.4)       # the rest drifts outward
inflight[r] -= outflow
drift    = outflow · Balance.DRIFT_LOSS (0.10) · global_drift_mult · ring_drift_mult[r]   # lost to the Rift
kept     = outflow - drift
inflight[r+1] += kept                                      # or, past ring 3, kept is reclaimed by the Rift
```

**3. Reclaim & siphon** — Essence still in-flight past ring 3 is reclaimed by the Rift
(lost). **Void Siphons** claw a fraction back:

```
recovered      = total_lost_this_tick · siphon_fraction          # capped at Balance.MAX_SIPHON_FRACTION (0.75)
captured_total += recovered ;  lost_total -= recovered
```

**Support multipliers:**

```
global_drift_mult = ( Π_stabilizers (1 - drift_reduction) ) · prestige_drift_mult ,  floored at Balance.MIN_DRIFT_MULT (0.1)
ring_drift_mult[r]= Π_conveyors_in_r (1 - ring_drift_reduction)
flux_mult         = ( 1 + Σ_refineries flux_bonus ) · prestige_flux_mult
```

**Why it matters:** inner extractors produce more total Essence but it must survive more
rings of drift; collectors want to sit where the Essence actually is. The balance point
*is* the gameplay.

---

## 3. Currencies (how resources are acquired)

| Currency | Acquired by | Spent on | Formula |
|---|---|---|---|
| **Essence** | Collected by Collectors each tick (`captured`) | Most buildings | `essence += captured_this_tick` |
| **Flux** | Byproduct of collection throughput | Support buildings | `flux += captured_this_tick · Balance.FLUX_RATE (0.02) · flux_mult` |
| **Rift Cores** | +1 (+prestige bonus) per cleared Surge | Gating building unlocks | `cores += Balance.CORES_PER_CLEAR (1) + prestige_core_bonus` |
| **Echoes** | Banked on collapse (persists across runs) | Prestige tree nodes | see §6 |

**Manual bootstrap** (phased out by prestige): tapping the portal injects
`Balance.MANUAL_EMIT (1.0)` into ring 0; collecting by hand grabs
`Balance.MANUAL_COLLECT (1.0)` from the rings. The **Auto-Tap** prestige node automates
this: it fires both every `Balance.AUTOCLICK_INTERVAL (2.0s) / autoclick_strength`.

**Building cost** is exponential in the count of that type you own:

```
cost(n) = base_cost · cost_growth ^ owned_count
```

A building is **buyable** once unlocked: `cores ≥ unlock_requirement` **OR** it has been
permanently unlocked by a prestige node.

---

## 4. Buildings

Buildings are data-driven `BuildingData` resources (`data/buildings/*.tres`). Each has a
category (Extractor / Collector / Support), a buy currency, exponential cost, and one or
more effects. `preferred_ring` grants `+25%` to that building's output when matched.

### Extractors (prefer inner rings)
| Building | Buy | Unlock | Effect / formula |
|---|---|---|---|
| **Channeler** | Essence | start | Steady emission `5.0/s`. |
| **Rupture Drill** | Essence | 1 core / *Drill Schematics* | Bursts: emits `base · burst_period` every `burst_period (20)` ticks, 0 otherwise → same average (`6.0/s`) delivered as 2-second floods. Pairs with strong collection. |
| **Resonant Lance** | Essence | 2 cores / *Lance Schematics* | Emission `8.0 · (1 + 0.5 · depth)` — a late-bloomer that scales with depth tiers. |
| **Twin Portal** | Flux | 6 cores / *Twin Portal Schematics* | Re-emits `0.6 ×` ring-0's base emission into its own ring — a second source closer to outer collectors. |

### Collectors (prefer mid/outer rings)
| Building | Buy | Unlock | Effect / formula |
|---|---|---|---|
| **Gather-Sprite** | Essence | start | Baseline capture `4.0/s`. |
| **Magnet Pylon** | Essence | 2 cores / *Magnet Schematics* | Captures `2.5/s` from its ring **and each ring within `collect_radius (1)`** (i.e. r-1, r, r+1). |
| **Conveyor Node** | Flux | 2 cores / *Conveyor Schematics* | Hybrid: `-50%` drift in its ring (`ring_drift_reduction`) + light capture `2.0/s`. |

### Support / Economy
| Building | Buy | Unlock | Effect / formula |
|---|---|---|---|
| **Refinery** | Flux | start | `flux_mult += 0.5` each (+50% Flux). |
| **Stabilizer** | Flux | start | `global_drift_mult ×= (1 - 0.3)` each (−30% Rift loss), floored at 0.1. |
| **Echo Chamber** | Flux | 3 cores / *Echo Chamber Schematics* | `building_echo_mult += 0.25` each (+25% Echoes on collapse). |
| **Void Siphon** | Flux | 5 cores | Reclaims `0.25 ×` Essence the Rift takes (capped 0.75 total). Turns the sink into upside. |

The **Overclock** ability (the "survive the wall" tool, §5) is a global activated
ability rather than a placed building: unlocked at `Balance.OVERCLOCK_UNLOCK_CORES (1)`
core, it grants `×3` emission **and** collection for `15s` on a `60s` cooldown.

---

## 5. Portal Surges (the ~25-minute wall)

A Surge is an **allocation / preparation test**, not a click test. Managed by
`SurgeManager` on a real-time clock; it reads the economy only through the 1 Hz stats
signal and never touches the sim.

**Cadence:** first Surge `Balance.SURGE_FIRST_DELAY (300s)` after a run starts, then
`Balance.SURGE_INTERVAL (1500s ≈ 25 min)` between Surges.

**Phases:**
1. **Warning** — `Balance.SURGE_WARNING (45s)`: re-hire / re-place freely; bank Essence.
2. **Window** — `Balance.SURGE_WINDOW (90s)`: the portal resists. Accumulate
   **destabilization** = Σ captured Essence during the window.
3. **Resolve** — cleared if `destabilization ≥ threshold`.

**Rubber-band threshold** (so the wall always sits at your current frontier):

```
threshold = peak_capture · Balance.SURGE_FACTOR (1.1) · (1 + Balance.DEPTH_THRESHOLD_SCALAR (0.1) · depth) · Balance.SURGE_WINDOW (90)
peak_capture = max captured/sec over the last Balance.PEAK_WINDOW (120s)
```

Because clearing needs you to *sustain ~1.1× your recent peak across the whole window*,
you can't clear by coasting — you bank Essence during the warning, dump it into new
buildings when the window opens (spiking output above your peak), and fire **Overclock**.
`SURGE_FACTOR` was set by the balance harness (`tools/balance_sim.gd`); at 3.0 surges
were unclearable, the clearable band is ~1.0–1.3, and single-run difficulty is limited
by board headroom (16 slots) — which is what makes you prestige.

**On clear:** `+1 Rift Core (+prestige_core_bonus)`, `depth += 1`, and the base
multipliers tick up: `extraction_mult, collection_mult ×= (1 + Balance.DEPTH_MULT_BONUS (0.1))`.
**On fail:** no penalty beyond lost time — grow more and the Surge returns.

---

## 6. Prestige (Collapse → Echoes → three trees)

Collapsing resets the run (currencies, buildings, depth) and banks **Echoes** (which
persist). Managed by `PrestigeManager`.

```
echoes_on_collapse = floor( echoes_gained(depth, cores) · echo_mult_nodes · building_echo_mult )
echoes_gained      = floor( Balance.ECHO_K (1) · depth ^ Balance.ECHO_EXP (1.5) · (1 + cores · Balance.CORE_BONUS (0.25)) )
echo_mult_nodes    = 1 + Σ (ECHO_MULT node magnitudes)
building_echo_mult = 1 + Σ_echo_chambers echo_bonus
```

At depth 0 the formula yields 0 — there's no point collapsing until you've cleared at
least one Surge. The HUD shows the live collapse value and **glows the Collapse button
at a plateau** (when the value stops growing meaningfully,
`Balance.PRESTIGE_PLATEAU_GROWTH`).

**Three trees, one currency (Echoes).** Each node is a `PrestigeNode` resource
(`data/prestige/*.tres`) with a single typed effect, a cost, and a prerequisite. Owned
nodes are aggregated and applied live. Effects:

| Effect | Applies as |
|---|---|
| `EXTRACTION_MULT` / `COLLECTION_MULT` / `FLUX_MULT` | `prestige_*_mult = 1 + Σ magnitudes` |
| `DRIFT_REDUCTION` | `prestige_drift_mult = max(1 − Σ, 0)` |
| `START_ESSENCE` | Essence granted at each run start |
| `AUTOCLICK` | auto-tap strength (auto bootstrap) |
| `CORE_GAIN` | `prestige_core_bonus` extra Cores per Surge |
| `ECHO_MULT` | multiplies Echoes on collapse |
| `PREPLACE_STARTER` | extra Channelers pre-placed at run start |
| `UNLOCK_BUILDING` | permanently unlocks a building (the "new toy each reset") |

- **Extraction** — emission boosts (Resonant Pulse → … → Singularity Core, +Focused Beam)
  and the Drill / Lance / Twin Portal unlock schematics.
- **Collection** — capacity (Wider Nets → Long Reach → Essence Weave → Free Flow), drift
  reduction (Rift Dampener, Rift Seal), and the Magnet / Conveyor unlocks.
- **Resonance** — the meta/auto-bootstrap tree: Head Start / Deep Reserves (start
  Essence), Pre-Attuned (pre-placed starter), Auto-Tap (auto-clicker), Flux Attunement,
  Echo Resonance (more Echoes), Core Affinity (more Cores), and the Echo Chamber unlock.

---

## 7. Legibility & persistence

- **Stats panel** (toggle overlay): global rates (Essence in / captured / **lost to
  Rift** / Flux per sec, depth, cores, echoes) plus a per-ring **emission vs capacity vs
  captured vs lost** table with red bleed highlighting and an actionable
  "add collectors at ring N" hint.
- **Save / load** (`SaveManager`): run + meta state serialized to `user://save.json`,
  autosaved every `Balance.AUTOSAVE_INTERVAL (15s)` plus on key events and on quit.
  Prestige factors are *recomputed* from owned nodes on load. **No offline rewards** —
  state restores exactly as left; time away grants nothing.
- **Number formatting** centralized in `NumberFormat` (K/M/B/T/aa…).

---

## 8. Balance constants (starting values)

| Constant | Value | Role |
|---|---|---|
| `ECON_TICK` | 0.1 s | Fixed timestep (10 Hz) |
| `RING_COUNT` / `SLOTS_PER_RING` | 4 / 4 | Board geometry (16 slots) |
| `FLOW_FRACTION` | 0.4 | Fraction of in-flight that drifts outward each tick |
| `DRIFT_LOSS` | 0.10 | Base fraction of outflow lost to the Rift |
| `PREFERRED_RING_BONUS` | 0.25 | Output bonus on a building's preferred ring |
| `MIN_DRIFT_MULT` / `MAX_SIPHON_FRACTION` | 0.1 / 0.75 | Drift floor / siphon cap |
| `FLUX_RATE` | 0.02 | Flux per Essence captured |
| `DEFAULT_COST_GROWTH` | 1.13 | Per-building cost exponent (overridden per type) |
| `SURGE_WARNING` / `SURGE_WINDOW` | 45 / 90 s | Surge phase durations |
| `SURGE_FIRST_DELAY` / `SURGE_INTERVAL` | 300 / 1500 s | Surge cadence (~25 min) |
| `PEAK_WINDOW` | 120 s | Rolling peak-capture window |
| `SURGE_FACTOR` | 1.1 | Surge difficulty (tuned via balance harness) |
| `DEPTH_THRESHOLD_SCALAR` / `DEPTH_MULT_BONUS` | 0.1 / 0.1 | Per-depth threshold growth / base-mult bump |
| `CORES_PER_CLEAR` | 1 | Rift Cores per cleared Surge |
| `OVERCLOCK_MULT` / `_DURATION` / `_COOLDOWN` / `_UNLOCK_CORES` | 3 / 15s / 60s / 1 | Overclock ability |
| `ECHO_K` / `ECHO_EXP` / `CORE_BONUS` | 1 / 1.5 / 0.25 | Echoes formula |
| `AUTOCLICK_INTERVAL` | 2.0 s | Auto-tap base period |
| `AUTOSAVE_INTERVAL` | 15 s | Background autosave cadence |

---

## 9. Architecture (autoloads)

`EventBus` (signals only) · `Balance` (all constants + curves) · `NumberFormat` ·
`GameState` (authoritative run state) · `Economy` (the tick sim) · `SurgeManager` ·
`PrestigeManager` · `SaveManager`. All cross-system communication goes through
`EventBus`; systems never reference each other directly. Content (buildings, prestige
nodes) is data-driven via `Resource` classes so designers add content without touching
systems code. `tools/balance_sim.gd` is a headless tuning harness (run with `--balance`).

---

## 10. Not yet implemented (roadmap)

- **Visual juice**: a concentric-ring board rendering with cosmetic Essence particles
  flowing through the rings (reading from `Economy.inflight`), and **audio**. These need
  a board visual rework + sound assets.
- Further prestige tree depth and additional balance passes against human playtests.
