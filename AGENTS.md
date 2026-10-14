# `wetware` — Repository & Art/Simulation Guidelines

## 1. Project Identity
`wetware` is a real-time tactical cyberpunk syndicate-warfare game and spiritual successor to *Syndicate* (1993) and *Syndicate Wars* (1996), set across a single persistent, destructible megacity rendered in **Native 24/32-Bit Isometric Pixel Art + 2.5D Normal/Height Maps + GPU Shaders**.

## 2. Architecture & Ownership Boundary
- **C++23 Deterministic Simulation Core (`include/wetware/`, `src/`, `test/`)**:
  - Designed from Day 1 around a **Unified Deterministic Fixed-Tick Command Architecture** (`SimulationTick`, `SyndicateId`, serializable `Command` envelopes, explicit RNG state, zero global singletons) supporting both **Single-Player** and **Multiplayer** (*1v1/2v2 Live Tactical Sector Clashes* and *2–4 Syndicate Persistent Megacity Wars*).
  - Owns all authoritative state:
    - Persistent Megacity district ledger, symmetric syndicate treasuries, tax/tariff cashflow, R&D funding queues, cryo-vault physical salvage inventory, and structural rebuild queues.
    - District Infrastructure ("City Organs"): Power Sub-Grid, Neural Broadcast Spire, Bio-Foundry / Morgue, Monorail Transit Hub, Heavy Ordinance Foundry, Corporate Clearinghouse.
    - **Symmetric 3-Path Hybrid Tech Progression**: All syndicates (player, AI, or human MP rivals) obey identical economic rules: (1) In-house HQ R&D via credits/time, (2) City Organ control cutting matching R&D and fabrication cost/time by **65%**, and (3) physical field-salvaged chrome/weapons from fallen operatives that can be equipped immediately as a single physical unit or sacrificed for a **+50% R&D reverse-engineering breakthrough**.
    - **3-Stratum Seamless Isometric Sector & Structural Physics**: Continuous multi-elevation sectors (`UnderGrid`, `Street`, `Spire`) with load-bearing pillars, cascading multi-story and sky-bridge collapse propagation, vertical drop-through when upper slabs shear, persistent rubble states, and reconstruction cost/progress.
    - **4-Operative Cyborg Squad State**: Cybernetic organ tiers (`V1`–`V4` `Legs`, `Arms`, `Chest`, `Eyes`, `Brain`, `Heart`), weapon loadouts, and live **I / P / A (Intelligence, Perception, Adrenaline)** biochem levels, tolerance, cardiac/neural strain thresholds, and **Adrenaline Overclock** (`0.25x` tactical time-dilation in Single-Player; real-time speed/fire-rate/reflex surge in Multiplayer).
    - **Persuadertron Neural-Mesh Propagation Graph**: Chain-Persuade bandwidth thresholds across `Civilian -> Police -> CorporateGuard -> Executive -> RivalOperative`, plus Sleeper Nodes, Dead-Man Broadcasts, and Crowd Surges.
    - **Rival Syndicate AI & Deterministic Tactical Auto-Resolve**: Inter-rival district raids, treasury allocation (R&D vs. rebuild vs. hit squads), retaliatory strikes against player-owned districts/HQ, and deterministic auto-resolve when raids are not fought manually.
  - Format with `clang-format-20` (`tools/format.sh`) and lint with `clang-tidy-20` (`tools/lint.sh`). Any `NOLINT` suppression must name exact checks and include an inline justification accepted by `tools/check_nolint.sh`. Validate with both GCC (`g++`) and Clang (`clang++`). Cap build parallelism at `-j4`.
- **Godot 4.7.2 Presentation Layer (`godot/`)**:
  - Consumes C++23 simulation snapshots/state and renders the 2.5D isometric megacity, 3-stratum elevation cutaway (`Under-Grid`, `Street`, `Spire`), trenchcoat operatives, crowd panic, structural collapse VFX, and GPU lighting/weather shaders.
  - Headless editor import rule (Godot #111048): always pass `--frame-delay 1000`:
    `godot --headless --path godot --editor --import --quit --frame-delay 1000`

## 3. Proven Art Direction Pipeline (Path 1 Standard — `5/5`)
1. **No Raw Low-Poly 3D Mannequins**:
   - Do **not** use raw Meshy 3D human exports or procedural 3D human meshes for characters or street actors.
   - All operatives, civilians, corporate sec-forces, vehicles, and isometric architectural tiles use **purpose-authored 24/32-bit pixel art sprites/tiles paired with 2.5D normal and height maps**.
2. **Isometric Projection, 3-Stratum Cutaway & Integer Scaling**:
   - Standardize on a locked `2:1` isometric pixel grid (`64x32` or `128x64` base ground tiles) with integer scaling (`640x360` virtual canvas -> `4x` on 2K `2560x1440`, `6x` on 4K `3840x2160`).
   - Support dynamic elevation cutaway slicing across `Under-Grid`, `Street`, and `Spire` strata so upper roofs/sky-bridges peel back cleanly around the camera focus and squad sightlines.
   - All pixel-art textures use `FILTER_NEAREST` so pixel edges remain razor-sharp under dynamic 2.5D lighting.
3. **2.5D Normal/Height Maps & Dynamic GPU Shaders**:
   - Every building facade, street tile, vehicle, and operative sprite carries:
     - **Albedo RGBA** (`FILTER_NEAREST`)
     - **2.5D Normal Map** (derived from luminance + directional Sobel bevels so minigun muzzle flashes, plasma arcs, burning cars, and neon signs cast real-time directional rim light across trenchcoats and wet asphalt)
     - **Height / Emissive Mask** (isolating neon signage, visor optics, plasma vents, and street puddles for localized bloom and specular reflections)
   - Foreground silhouettes must occlude background bloom (`bloom *= (1.0 - fg.a)`) so dark trenchcoats read cleanly against neon rain.
4. **Structural Destruction & Persistent Rubble**:
   - Buildings are composed of modular isometric stories and load-bearing corner/facade segments with intact, damaged, collapsing, rubble, and scaffolding/rebuilding visual states.
   - Heavy ordinance (Gauss Gun, High Explosives, Satellite Rain, Plasma Lance) shears load-bearing segments in the C++ simulation, triggering cascading multi-story collapse with GPU dust/debris shockwaves and leaving persistent physical craters/rubble across days.
5. **Venice Uncensored Creative & Audio Pipeline (`/config/.local/bin/venice`)**:
   - Because `wetware` features dark dystopian cyberpunk themes (ripperdoc cyber-surgery, wetware organ harvesting, cyber-psychosis, heavy ordinance destruction, and gritty syndicate warfare) that can trip builtin image-generator safety filters, use `/config/.local/bin/venice` when generating reference plates, UI portraits, sprite/tile source plates, SFX, or music:
     - **Visuals**: `venice image --no-safe-mode --hide-watermark --save-json --max-spend <USD> ...` and `venice bg-remove` for sprite/prop isolation before quantizing/pixelating and generating 2.5D Sobel normal/height maps via `tools/`.
     - **Audio**: `venice sfx --master` (minigun spin-up, Gauss rail crack, Persuadertron neural hum, structural tower collapse) and `venice music --instrumental --master --loop` (dark industrial synth ambient loops).
     - **Guardrails**: Always check cost first with `--dry-run`, cap spend with `--max-spend`, respect the shared daily Venice API budget ceiling, and retain `.json` sidecar metadata for asset provenance.
