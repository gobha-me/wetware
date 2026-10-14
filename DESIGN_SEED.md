# `wetware` — Design Seed (*Syndicate* / *Syndicate Wars* Spiritual Successor)

## 1. High-Concept Pitch
- **Genre**: Real-Time Tactical Cyberpunk Syndicate Warfare & Persistent Megacity Takeover (Single-Player & Multiplayer)
- **Spiritual Lineage**: *Syndicate* (Bullfrog, 1993) + *Syndicate Wars* (Bullfrog, 1996)
- **Visual Signature**: **Native 24/32-Bit Isometric Pixel Art + 2.5D Normal/Height Maps + GPU Shaders** at 2K (`2560x1440`) and 4K (`3840x2160`) integer scaling. Rain-slicked asphalt reflecting neon kanji holograms, 4 matte-black trenchcoat cyborgs emerging from an unmarked spinner car, minigun tracer light carving across wet concrete, and entire corporate sky-bridges and towers collapsing into persistent smoking rubble.

---

## 2. One Persistent Megacity — Zero Generic Missions
Instead of a static world map of disconnected, recycled missions, the entire game takes place across **one massive, continuous cyberpunk megacity** divided into **Owned Districts** and **3 Seamless Vertical Strata** within each tactical sector map:
1. **The Spire Layer (`Stratum::Spire` — Upper Canopy)**: Glass sky-bridges, executive penthouses, orbital shuttle pads, high-security research vaults, and satellite uplink arrays.
2. **The Street Layer (`Stratum::Street` — Neon Grid)**: Rain-slicked boulevards, elevated monorail viaducts, corporate bank branches, nightclubs, police precincts, and dense civilian and vehicle traffic.
3. **The Under-Grid (`Stratum::UnderGrid` — Sub-Street)**: Power sub-stations, black-market ripperdoc clinics, cooling tunnels, sewer waterways, and unpoliced syndicate smuggling routes.

### Seamless Multi-Level Isometric Elevation Slicing
- During live tactical deployment, all 3 strata exist in **one continuous multi-elevation sector map** connected by freight elevators, maintenance shafts, stairwells, monorail platforms, and breachable floor slabs.
- Dynamic roof and floor cutaway slicing peels back upper stories and sky-bridges around the camera elevation and operative sightlines.
- Shearing the supports of a Spire sky-bridge or upper floor drops whoever (or whatever) is on top straight down onto the Street or Under-Grid below.

### Player-Driven Strategy (No Scripted Mission Dispatches)
- There is **no mission briefing screen telling you what to do next**.
- You look at the live megacity map, inspect rival syndicates' cashflow, infrastructure, R&D trajectory, and patrol density, and **you decide which rival to target and how to hurt them**:
  - **Surgical Takeover (High Profit / Intact Infrastructure)**:
    - Deploy your 4 operatives with suppressed Gauss rifles, EMP charges, and the **Persuadertron** to brainwash the district's executive director or sever its security nodes without leveling the real estate.
    - You seize the district intact and immediately collect 100% of its daily revenue and infrastructure perks.
  - **Scorched-Earth Economic Warfare (Bankrupting Rivals)**:
    - Walk into a rival's crown-jewel financial or research district with Thermite Charges, Miniguns, and Satellite Strikes and **level their buildings to the ground**.
    - Even if you extract without claiming the territory, the buildings stay **persistent rubble**.
    - The rival syndicate immediately loses that district's income and City Organ perks, and is forced to hemorrhage their treasury into **expensive reconstruction scaffolding and security cordons**—letting you watch them go broke rebuilding while you seize their lightly defended outer districts.

---

## 3. District Infrastructure ("City Organs")
Every district isn't just a colored polygon of tax revenue—it houses a physical piece of megacity infrastructure that grants tangible strategic and tactical power to whoever owns it (or cripples them if bombed into rubble):

1. **Power Sub-Grid District**:
   - **Controlled**: Reroute megawatt surges to charge your orbital weapon capacitors or cut street lighting/turret power in adjacent rival districts right before your squad drops in.
   - **Bombed to Rubble**: Rolling blackouts across neighboring districts; rival automated laser turrets and security cameras go dark.
2. **Broadcast & Neural-Mesh Spire**:
   - **Controlled**: Doubles global **Persuadertron** neural-hijack bandwidth and suppresses civilian riot panic in your taxed districts.
   - **Bombed to Rubble**: Rival propaganda collapses; their brainwashed thralls and corporate security suffer morale and coordination failure.
3. **Bio-Foundry & Municipal Morgue**:
   - **Controlled**: Cuts **V3/V4 Cybernetic Organ** R&D and fabrication time/cost by **65%** and enables automated wetware harvesting from fallen elites in controlled sectors.
   - **Bombed to Rubble**: Owning syndicate loses its 65% Bio-Foundry accelerator and cannot mass-fabricate replacement V3/V4 cyberware until the facility is rebuilt.
4. **Monorail & Mag-Lev Transit Hub**:
   - **Controlled**: Instant armored train insertion across connected districts and physical cargo taxation.
   - **Bombed to Rubble**: Blowing a monorail viaduct while a rival's armored bullion/tech train is crossing drops the burning wreckage into the street below so your squad can loot the vault cars before rival reinforcements arrive.
5. **Heavy Ordinance Foundry**:
   - **Controlled**: Cuts heavy weapon and ordinance R&D and fabrication time/costs (Gauss Gun, Plasma Lance, Thermite Structural Charges, Satellite Rods) by **65%**.
   - **Bombed to Rubble**: Strips the rival's ordinance discount and halts automated heavy-ammo resupply.
6. **Corporate Clearinghouse & Bond Exchange**:
   - **Controlled**: High-yield credit laundering (+25% syndicate tax efficiency) and real-time espionage visibility into rival syndicate balance sheets, R&D queues, and reconstruction debt.

---

## 4. Symmetric 3-Path Hybrid Tech Progression (Balanced Economy)
To prevent artificial rubber-banding or unfair rival tech advantages, **every syndicate in the megacity (Player, AI Rivals, and Human Multiplayer Rivals) starts on symmetric rules and obeys the exact same ledger and progression constraints**:

1. **Path 1 — In-House HQ R&D Lab (Credits + Time)**:
   - Any syndicate can research any `V1`–`V4` cybernetic organ (`Legs`, `Arms`, `Chest`, `Eyes`, `Brain`, `Heart`) or weapon blueprint in their HQ lab by allocating daily R&D funding.
   - Researching `V3`–`V4` apex tech purely in-house without the corresponding City Organ is always possible, ensuring no faction is ever hard-locked, but demands high credit upkeep and time.
2. **Path 2 — City Organ Infrastructure Accelerator (`-65%` Cost & Time)**:
   - Controlling a **Bio-Foundry** (for cyberware) or **Heavy Ordinance Foundry** (for heavy weapons) slashes R&D and unit fabrication cost and time by **65%**.
   - This makes Bio-Foundry and Ordinance Foundry districts prime strategic flashpoints: if a rival controls one, you can either seize it intact to claim the accelerator for yourself, or bomb it into rubble so they lose their R&D edge.
3. **Path 3 — Physical Field Salvage & Reverse-Engineering (`Cryo-Vault Hardware`)**:
   - Fallen operatives (yours or rivals') drop their physical cyberware and weapons on the pavement. If hauled back to an extraction spinner or monorail before retreating, that hardware enters your **Cryo-Vault Inventory** as a discrete physical item.
   - For any salvaged item whose blueprint you haven't unlocked yet, you have a tactical choice:
     - **Direct Field Bolt-On (Single Physical Unit)**: Equip that exact looted `V3`/`V4` organ or heavy weapon onto one of your operatives immediately without needing the blueprint (high reward, high risk: you cannot fabricate replacements if that operative dies and their body isn't recovered).
     - **Lab Reverse-Engineering (`+50%` R&D Breakthrough)**: Sacrifice the physical salvaged unit in your HQ lab to grant an instant **+50% research progress breakthrough** toward unlocking permanent mass fabrication of that blueprint.

---

## 5. Active Rivals, Rebuilding & Base Defense
The megacity is a living multi-faction warzone:
- **Inter-Rival Warfare**: Rival syndicates actively raid *each other* on the live map. You can monitor a turf war between two rivals, wait until they exhaust each other's squads and blow up half a block, and drop your 4 operatives in during the aftermath to clean up both sides and strip their chrome.
- **Persistent Rebuilding**:
  - Destroyed buildings remain smoking craters and rubble piles across days until the owning syndicate funds a **Rebuild Crew** (visible in-world as yellow holographic cranes, weld-sparks, and scaffolding).
  - You can ambush rival construction sites to reset their rebuild progress and drain their treasury further—or defend your own reconstruction crews when rebuilding a devastated district you just conquered.
- **Tactical Defense (Protecting Your Turf & HQ)**:
  - Rivals don't wait passively to die. When you hurt them, they send **4-cyborg hit squads**, sabotage teams, and armored vehicles into *your* districts and against your **Physical Syndicate HQ**.
  - You configure district security budgets (precinct patrols, street checkpoints, automated sentry turrets, grid locks) and scramble your own 4-operative squad via spinner or monorail to intercept incoming rival strike teams before they level *your* revenue buildings or breach your HQ cryo-vaults.

---

## 6. Tactical Core: The 4 Trenchcoat Operatives
When on the ground in the city, you command **4 cybernetic operatives** in real time:

### 1. The **I / P / A** Biochem Sliders & Adrenaline Overclock
Each operative has live-adjustable bloodstream sliders for **Intelligence**, **Perception**, and **Adrenaline**:
- **Intelligence (I)**: Autonomous target prioritization, hacking speed, door/grid bypass, and automatic self-defense reflexes when you're micro-managing another agent.
- **Perception (P)**: Cone-of-vision penetration through rain/fog, thermal/structural silhouette detection across elevation strata, and tighter weapon spread at long range.
- **Adrenaline (A) & Overclock**: Movement speed, recoil absorption, and **Adrenaline Overclock**:
  - **Single-Player Overclock (Bullet-Time)**: Spiking your squad into redline triggers **`0.25x` Tactical Time-Dilation** where rain droplets hang in the air, muzzle flashes bloom in slow motion, and you can queue split-second synchronized breaches.
  - **Multiplayer Overclock (Real-Time Reflex Surge)**: In live multiplayer clashes where global time cannot pause another human player, Overclock triggers a real-time **Hyper-Reflex Surge** (`+40%` movement/action speed, instant target snap, and recoil lock).
- **The Cost**: Pushing I/P/A into the red builds **Neural Toxicity** and **Cardiac Strain**—requiring cooldown stabilizers or risking mid-firefight cyber-psychosis (uncontrolled weapon discharge) or cardiac flatline.

### 2. The Evolved **Persuadertron** (Neural-Mesh Hijacking)
- *Syndicate*'s signature weapon returns: hijack civilians as human shields or cannon fodder, build a crowd mass to reach the neural bandwidth threshold for hijacking `Civilian -> Police -> Corporate Guard -> Executive VIP -> Rival Cyborg`.
- **Modern Tactical Twists**:
  - **Undercover Sleeper Nodes**: Leave a persuaded police captain or corporate technician in place inside a rival district as a permanent live vision/camera tap before you even start an assault.
  - **Dead-Man Broadcast**: Rig a persuaded VIP with a neural pulse or satchel charge and walk them straight through a rival security checkpoint.
  - **Crowd Surge**: Trigger a mass neural panic in a crowded neon market to flood a rival convoy's path with hundreds of rioting civilians.

### 3. Catastrophic Ordinance & Multi-Story Structural Physics
- Every building is composed of load-bearing columns and multi-story structural segments across the sector's vertical strata.
- Instead of fighting room-by-room up a 12-story rival tower, your squad can plant **Thermite Structural Charges** on the ground-floor support pillars or fire a **Gauss Gun** through the lobby columns and bring the entire building crashing down onto the rival VIPs inside—trading away the intact building's immediate tax value for an instant, zero-casualty kill and a massive reconstruction bill for your rival.

---

## 7. Unified Deterministic Clock & Multiplayer Modes
Because the C++23 simulation core is built as a **deterministic fixed-tick command simulation** (`SimulationTick`, `SyndicateId`, serializable `Command` queue), the exact same simulation engine powers both Single-Player and Multiplayer:

1. **Single-Player Campaign**:
   - The Megacity Overworld runs in continuous real-time with player-controlled time-compression (`Pause / 1x / 2x / 4x`).
   - Dropping into a live Tactical Sector locks camera focus to your squad while the macro Megacity clock advances at `1x` real-time (surfacing live HQ alerts if a rival launches an attack elsewhere), and supports `0.25x` Adrenaline Overclock bullet-time.
2. **Multiplayer Mode A — 1v1 / 2v2 Live Tactical Sector Clash**:
   - Two to four rival player squads drop simultaneously into the same 3-stratum district to contest high-value objectives (e.g., hijack or assassinate an Executive convoy, derail and loot an armored bullion monorail, or demolish/defend a Bio-Foundry).
3. **Multiplayer Mode B — 2–4 Syndicate Persistent Megacity War**:
   - Simultaneous real-time strategic clock across the Megacity.
   - When a syndicate launches a district raid, it can be resolved via **Deterministic Tactical Auto-Resolve** (fast macro pacing) *or* **Live Tactical Command**—where the defending syndicate player can scramble their own 4-operative hit squad via spinner or monorail and drop into that very same sector mid-battle to intercept the attacker live.
