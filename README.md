# `wetware`

A real-time tactical cyberpunk syndicate-warfare game and spiritual successor to *Syndicate* (1993) and *Syndicate Wars* (1996), rendered in **Native 24/32-Bit Isometric Pixel Art + 2.5D Normal/Height Maps + GPU Shaders** at 2K (`2560x1440`) and 4K (`3840x2160`) integer scaling.

## Core Pillars
- **One Persistent Megacity, Zero Generic Missions**: Every district is a live physical sector with 3 vertical strata (*Spire*, *Street*, *Under-Grid*). You choose which rival syndicate to target and whether to seize their infrastructure surgically or bomb their buildings into rubble to bankrupt them on reconstruction costs.
- **Persistent Destruction & Rebuilding**: Load-bearing building collapse (*Syndicate Wars*-style). Destroyed towers and monorail viaducts remain smoking rubble across days until the owning syndicate pays to rebuild them—and construction sites themselves can be raided or defended.
- **District Infrastructure ("City Organs")**: Control or destroy the city's physical systems—Power Sub-Grids (blackouts), Broadcast Spires (Persuadertron range), Bio-Foundries (V3/V4 cyberware & wetware harvesting), Monorail Hubs (armored train ambushes), and Ordinance Foundries.
- **Active Rivals & Base Defense**: Rival syndicates wage turf wars against each other and send 4-cyborg hit squads into your districts and against your physical HQ.
- **4 Trenchcoat Operatives**: Live **I / P / A (Intelligence, Perception, Adrenaline)** biochem sliders with **Adrenaline Overclock** (tactical time-dilation), evolved **Persuadertron** neural-mesh hijacking, and catastrophic heavy ordinance.

## Key Documents
- [`AGENTS.md`](AGENTS.md) — Architecture ownership boundary (C++23 simulation core + Godot 4.7.2 presentation) and the proven 24/32-bit isometric pixel-art + 2.5D normal-map shader pipeline.
- [`DESIGN_SEED.md`](DESIGN_SEED.md) — Complete strategic & tactical design seed.

## Repository Layout
- `include/wetware/` & `src/` — C++23 megacity economy, rival AI, structural collapse, and biochem simulation core
- `test/` — C++23 deterministic simulation & tactical unit tests
- `godot/` — Godot 4.7.2 2.5D isometric pixel-art presentation, normal-mapped lighting, and destruction shaders
- `tools/` — 24/32-bit isometric sprite/tile extraction, normal/height map bevel generators, and asset pipelines
