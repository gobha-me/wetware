# `wetware` — Repository & Art/Simulation Guidelines

## 1. Project Identity
`wetware` is a real-time tactical cyberpunk syndicate-warfare game and spiritual successor to *Syndicate* (1993) and *Syndicate Wars* (1996), set across a single persistent, destructible megacity rendered in **Native 24/32-Bit Isometric Pixel Art + 2.5D Normal/Height Maps + GPU Shaders**.

## 2. Architecture & Ownership Boundary
- **C++23 Simulation Core (`include/wetware/`, `src/`, `test/`)**:
  - Owns all authoritative state:
    - Persistent Megacity district ledger, rival syndicate treasuries, tax/tariff cashflow, and structural rebuild queues.
    - District Infrastructure ("City Organs"): Power Sub-Grid, Neural Broadcast Spire, Bio-Foundry / Morgue, Monorail Transit Hub, Ordinance Foundry, Financial Clearinghouse.
    - Structural voxel/column integrity for buildings (load-bearing pillars, multi-story collapse propagation, persistent rubble states, and reconstruction cost/progress).
    - 4-Operative cyborg squad state: cybernetic organ tiers (V1–V4 Legs, Arms, Chest, Eyes, Brain, Heart), weapon loadouts, and live **I / P / A (Intelligence, Perception, Adrenaline)** biochem levels, tolerance, and overdose/flatline thresholds.
    - Persuadertron neural-mesh propagation graph (Chain-Persuade thresholds across civilians -> police -> corporate guards -> rival agents).
    - Rival Syndicate AI: inter-rival district raids, treasury allocation (rebuild vs. arm hit squads), and retaliatory strikes against player-owned districts and HQ.
  - Format with `clang-format-20` and lint with `clang-tidy-20`. Validate with both GCC (`g++`) and Clang (`clang++`). Cap build parallelism at `-j4`.
- **Godot 4.7.2 Presentation Layer (`godot/`)**:
  - Consumes C++23 simulation state and renders the 2.5D isometric megacity, trenchcoat operatives, crowd panic, structural collapse VFX, and GPU lighting/weather shaders.
  - Headless editor import rule (Godot #111048): always pass `--frame-delay 1000`:
    `godot --headless --path godot --editor --import --quit --frame-delay 1000`

## 3. Proven Art Direction Pipeline (Path 1 Standard — `5/5`)
1. **No Raw Low-Poly 3D Mannequins**:
   - Do **not** use raw Meshy 3D human exports or procedural 3D human meshes for characters or street actors.
   - All operatives, civilians, corporate sec-forces, vehicles, and isometric architectural tiles use **purpose-authored 24/32-bit pixel art sprites/tiles paired with 2.5D normal and height maps**.
2. **Isometric Projection & Integer Scaling**:
   - Standardize on a locked `2:1` isometric pixel grid (`64x32` or `128x64` base ground tiles) with integer scaling (`640x360` virtual canvas -> `4x` on 2K `2560x1440`, `6x` on 4K `3840x2160`).
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
