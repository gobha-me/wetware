# `wetware`

A real-time tactical cyberpunk syndicate-warfare game and spiritual successor to *Syndicate* (1993) and *Syndicate Wars* (1996), rendered in **Native 24/32-Bit Isometric Pixel Art + 2.5D Normal/Height Maps + GPU Shaders** at 2K (`2560x1440`) and 4K (`3840x2160`) integer scaling.

## Core Pillars
- **One Persistent Megacity, Zero Generic Missions**: Every district is a live physical sector with **3 seamless vertical strata** (*Spire*, *Street*, *Under-Grid*) in one continuous multi-elevation cutaway map. You choose which rival syndicate to target and whether to seize their infrastructure surgically or bomb their buildings into rubble to bankrupt them on reconstruction costs.
- **Persistent Destruction & Rebuilding**: Load-bearing building and sky-bridge collapse (*Syndicate Wars*-style). Destroyed towers and monorail viaducts remain smoking rubble across days until the owning syndicate pays to rebuild them—and construction sites themselves can be raided or defended.
- **District Infrastructure ("City Organs") & Symmetric 3-Path Progression**: Every syndicate (player, AI, or human MP rival) obeys identical economic rules. Unlock `V1`–`V4` cyberware and catastrophic ordinance via **(1) HQ R&D Lab funding**, **(2) City Organ control** (`-65%` R&D and fabrication cost/time via Bio-Foundries and Ordinance Foundries), or **(3) Physical Field Salvage** (equip looted rival chrome immediately as a single physical unit or sacrifice it for a `+50%` R&D reverse-engineering breakthrough).
- **4 Trenchcoat Operatives**: Live **I / P / A (Intelligence, Perception, Adrenaline)** biochem sliders with **Adrenaline Overclock** (`0.25x` tactical bullet-time in Single-Player; real-time hyper-reflex surge in Multiplayer), evolved **Persuadertron** neural-mesh hijacking, and catastrophic heavy ordinance.
- **Unified Deterministic Tick Architecture (Single-Player & Multiplayer)**: Authoritative C++23 command-log simulation supporting Single-Player campaigns, **1v1/2v2 Live Tactical Sector Clashes**, and **2–4 Syndicate Persistent Megacity Wars** (with live rival interception drops or deterministic tactical auto-resolve).

## Key Documents
- [`AGENTS.md`](AGENTS.md) — Architecture ownership boundary (C++23 simulation core + Godot 4.7.2 presentation), the proven 24/32-bit isometric pixel-art + 2.5D normal-map shader pipeline, and the `venice` CLI asset/audio pipeline.
- [`DESIGN_SEED.md`](DESIGN_SEED.md) — Complete strategic, tactical, progression, and multiplayer design specification.

## Repository Layout
- `include/wetware/` & `src/` — C++23 deterministic megacity economy, symmetric 3-path R&D/salvage, 3-stratum structural collapse, I/P/A biochem, Persuadertron graph, rival AI, and command-log simulation core
- `test/` — C++23 deterministic simulation & tactical unit tests
- `godot/` — Godot 4.7.2 2.5D isometric pixel-art presentation, 3-stratum elevation cutaway, normal-mapped lighting, and destruction shaders
- `tools/` — C++23 format/lint scripts, 24/32-bit isometric sprite/tile extraction, and 2.5D normal/height map bevel generators
