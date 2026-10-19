#include "wetware/scenarios.hpp"
#include "wetware/simulation.hpp"

#include <cstdlib>
#include <iostream>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}

void test_symmetric_three_path_progression() {
  auto sim = wetware::create_default_vertical_slice();

  require(sim.effective_research_cost(1, 1) == 700,
          "Bio-Foundry owner gets -65% R&D cost on V3 cyberware");
  require(sim.effective_research_ticks(1, 1) == 4,
          "Bio-Foundry owner gets -65% R&D duration on V3 cyberware");
  require(sim.effective_research_cost(2, 1) == 2000,
          "Non-owner pays base R&D cost");

  require(sim.apply_command(wetware::CommandSalvageFieldHardware{
              .syndicate_id = 2, .blueprint_id = 1, .quantity = 2}),
          "Salvage 2 units of V3 legs");
  require(
      sim.apply_command(wetware::CommandUseSalvage{.syndicate_id = 2,
                                                   .blueprint_id = 1,
                                                   .reverse_engineer = false,
                                                   .operative_index = 0}),
      "Equip 1 salvaged V3 legs directly onto rival operative 0");
  const auto* rival = sim.find_syndicate(2);
  require(rival != nullptr, "Rival exists");
  require(rival->squad.at(0).organ_tier(wetware::OrganSlot::Legs) ==
              wetware::CyberTier::V3,
          "Rival operative 0 now wears salvaged V3 legs");

  require(sim.apply_command(wetware::CommandUseSalvage{.syndicate_id = 2,
                                                       .blueprint_id = 1,
                                                       .reverse_engineer = true,
                                                       .operative_index = 0}),
          "Reverse-engineer 2nd salvaged V3 legs for +50% R&D breakthrough");
  require(rival->research.size() == 1 &&
              rival->research.front().invested_credits == 1000 &&
              rival->research.front().accrued_ticks == 5,
          "Reverse-engineering grants +50% credits and ticks toward blueprint");
}

void test_three_stratum_cascading_collapse_and_rebuild() {
  auto sim = wetware::create_default_vertical_slice();

  const auto* player = sim.find_syndicate(1);
  require(player->squad.at(0).current_stratum == wetware::Stratum::Spire,
          "Operative 0 starts on Spire stratum");

  require(sim.apply_command(
              wetware::CommandShearColumns{.building_id = 10,
                                           .stratum = wetware::Stratum::Street,
                                           .columns_destroyed = 3}),
          "Shear load-bearing street columns on Building 10");

  const auto* bld = sim.find_building(10);
  require(bld != nullptr && bld->state == wetware::BuildingState::Rubble,
          "Building 10 collapses into persistent rubble");
  require(bld->stories.at(2).collapsed,
          "Upper Spire story cascades into collapse when Street columns fail");
  require(player->squad.at(0).current_stratum == wetware::Stratum::Street,
          "Operative on collapsed Spire sky-bridge drops to Street stratum");

  require(!sim.controls_intact_organ(1, wetware::CityOrgan::BioFoundry),
          "Destroyed Bio-Foundry no longer grants intact organ perk");
  require(sim.effective_research_cost(1, 1) == 2000,
          "Player R&D cost reverts to base while Bio-Foundry is rubble");

  require(sim.apply_command(wetware::CommandFundRebuild{.syndicate_id = 1,
                                                        .building_id = 10}),
          "Fund reconstruction of Building 10");
  for (int i = 0; i < 5; ++i) {
    sim.step_tick();
  }
  require(bld->state == wetware::BuildingState::Intact,
          "Building 10 is restored to Intact after rebuild ticks complete");
  require(sim.controls_intact_organ(1, wetware::CityOrgan::BioFoundry),
          "Rebuilt Bio-Foundry restores organ accelerator");
}

void test_sp_and_mp_overclock_and_persuadertron() {
  auto sp_sim = wetware::create_default_vertical_slice(
      wetware::SessionMode::SinglePlayer);
  auto mp_sim = wetware::create_default_vertical_slice(
      wetware::SessionMode::MultiplayerMegacityWar);

  require(sp_sim.apply_command(wetware::CommandTriggerOverclock{
              .syndicate_id = 1, .active = true}),
          "Trigger SP Adrenaline Overclock");
  require(sp_sim.tactical_time_scale() == 0.25 &&
              sp_sim.macro_city_time_scale() == 1.0,
          "SP Overclock triggers 0.25x tactical bullet-time while city ticks "
          "at 1x");
  require(sp_sim.find_syndicate(1)->squad.at(0).overclock ==
              wetware::OverclockState::BulletTimeDilation,
          "SP operative enters BulletTimeDilation");

  require(mp_sim.apply_command(wetware::CommandTriggerOverclock{
              .syndicate_id = 1, .active = true}),
          "Trigger MP Adrenaline Overclock");
  require(mp_sim.tactical_time_scale() == 1.0,
          "MP Overclock keeps global time scale at 1.0x");
  require(mp_sim.find_syndicate(1)->squad.at(0).overclock ==
              wetware::OverclockState::HyperReflexSurge,
          "MP operative enters real-time HyperReflexSurge");

  require(sp_sim.attempt_persuade(
              2, 0, 9001, wetware::PersuadeTargetClass::Police, 2,
              wetware::Stratum::Street, wetware::ThrallDirective::SleeperNode),
          "Broadcast Spire owner has sufficient bandwidth to hijack Police as "
          "Sleeper Node");
}

void test_sector_grid_vertical_traversal_sightline_and_breach() {
  auto sim = wetware::create_default_vertical_slice();

  // Operative 1 (VEX-2) is at (2, 2, Street) inside a VerticalShaft cell
  require(sim.apply_command(wetware::CommandTraverseVerticalShaft{
              .syndicate_id = 1,
              .operative_index = 1,
              .district_id = 1,
              .target_stratum = wetware::Stratum::UnderGrid}),
          "Traverse freight shaft from Street down to UnderGrid");
  require(sim.find_syndicate(1)->squad.at(1).current_stratum ==
              wetware::Stratum::UnderGrid,
          "VEX-2 is now in UnderGrid stratum");

  // Sightline test across OpaqueWall at (5, 4, Street) between (3, 4, Street)
  // and (7, 4, Street)
  const auto* kowloon = sim.find_district(1);
  require(kowloon != nullptr, "Kowloon district exists");
  require(!kowloon->tactical_grid.has_sightline(
              wetware::GridCoord{3, 4, wetware::Stratum::Street},
              wetware::GridCoord{7, 4, wetware::Stratum::Street}, 0.40, 1U),
          "Opaque wall blocks baseline sightline when Perception is low");
  require(kowloon->tactical_grid.has_sightline(
              wetware::GridCoord{3, 4, wetware::Stratum::Street},
              wetware::GridCoord{7, 4, wetware::Stratum::Street}, 0.85, 3U),
          "High Perception (0.85) + V3 Eyes penetrates 1 opaque wall via "
          "thermal silhouette");

  // Breach sky-bridge slab under Operative 0 at (4, 4, Spire)
  require(sim.apply_command(wetware::CommandBreachFloorSlab{
              .district_id = 1,
              .coord = wetware::GridCoord{4, 4, wetware::Stratum::Spire}}),
          "Breach sky-bridge slab at (4, 4, Spire)");
  const auto& op0 = sim.find_syndicate(1)->squad.at(0);
  require(op0.current_stratum == wetware::Stratum::Street && op0.health < 100,
          "Breaching sky-bridge slab drops operative to Street with fall "
          "impact damage");
}

void test_rival_ai_controller() {
  auto sim = wetware::create_default_vertical_slice();

  // Collapse Rival's Broadcast Spire (Building 20) and verify Rival AI funds
  // reconstruction + R&D + launches a raid
  require(sim.apply_command(
              wetware::CommandShearColumns{.building_id = 20,
                                           .stratum = wetware::Stratum::Street,
                                           .columns_destroyed = 4}),
          "Destroy Rival Broadcast Spire");
  require(sim.find_building(20)->state == wetware::BuildingState::Rubble,
          "Broadcast Spire is rubble");

  const auto outcome = sim.step_rival_ai(2);
  require(sim.find_building(20)->state == wetware::BuildingState::Rebuilding,
          "Rival AI automatically prioritizes rebuilding its destroyed City "
          "Organ");
  require(!sim.find_syndicate(2)->research.empty(),
          "Rival AI allocates R&D budget");
  require(outcome.has_value() && outcome->district_id == 1,
          "Rival AI evaluates and dispatches raid against District 1");
}

void test_deterministic_command_replay() {
  auto sim_a = wetware::create_default_vertical_slice(
      wetware::SessionMode::MultiplayerMegacityWar);
  auto sim_b = wetware::create_default_vertical_slice(
      wetware::SessionMode::MultiplayerMegacityWar);

  const std::vector<wetware::SimulationCommand> script{
      wetware::CommandAllocateResearch{
          .syndicate_id = 1, .blueprint_id = 1, .daily_budget = 350},
      wetware::CommandTriggerOverclock{.syndicate_id = 2, .active = true},
      wetware::CommandTraverseVerticalShaft{.syndicate_id = 1,
                                            .operative_index = 1,
                                            .district_id = 1,
                                            .target_stratum =
                                                wetware::Stratum::Spire},
      wetware::CommandBreachFloorSlab{
          .district_id = 1,
          .coord = wetware::GridCoord{4, 4, wetware::Stratum::Spire}},
      wetware::CommandShearColumns{.building_id = 21,
                                   .stratum = wetware::Stratum::Street,
                                   .columns_destroyed = 4},
  };

  for (const auto& cmd : script) {
    require(sim_a.apply_command(cmd), "Apply command to sim_a");
    require(sim_b.apply_command(cmd), "Apply command to sim_b");
    sim_a.step_tick();
    sim_b.step_tick();
  }

  require(sim_a.state_digest() == sim_b.state_digest(),
          "Deterministic command replay yields identical state digest");
  const std::string json_a = sim_a.export_snapshot_json();
  const std::string json_b = sim_b.export_snapshot_json();
  require(json_a == json_b &&
              json_a.find("\"schema_version\": 2") != std::string::npos &&
              json_a.find("\"events\": [") != std::string::npos &&
              sim_a.events().size() == sim_b.events().size(),
          "Deterministic snapshot JSON export matches across replays");
}

void test_ordinance_strike_and_corpse_wetware_extraction() {
  auto sim = wetware::create_default_vertical_slice();

  // Equip Rival operative 0 (ONI-1 at (8, 8, Street)) with V3 Legs and move
  // Player operative 2 (NULL-3) to (8, 8, Street) to extract the corpse after
  // SatelliteRain / PlasmaLance strike.
  auto* rival = sim.find_syndicate_mut(2);
  auto* player = sim.find_syndicate_mut(1);
  require(rival != nullptr && player != nullptr, "Syndicates exist");
  rival->squad.at(0).set_organ_tier(wetware::OrganSlot::Legs,
                                    wetware::CyberTier::V3);
  // Bring ONI-1 and ONI-2 into Kowloon (District 1); NULL-3 moves onto
  // ONI-1's cell to extract the corpse afterwards.
  require(sim.apply_command(wetware::CommandDeployOperative{
              .syndicate_id = 2,
              .operative_index = 0,
              .building_id = 11,
              .coord = wetware::GridCoord{8, 8, wetware::Stratum::Street}}),
          "Deploy ONI-1 into Kowloon");
  require(sim.apply_command(wetware::CommandDeployOperative{
              .syndicate_id = 2,
              .operative_index = 1,
              .building_id = 11,
              .coord = wetware::GridCoord{9, 8, wetware::Stratum::Street}}),
          "Deploy ONI-2 into Kowloon");
  require(sim.apply_command(wetware::CommandDeployOperative{
              .syndicate_id = 1,
              .operative_index = 2,
              .building_id = 11,
              .coord = wetware::GridCoord{8, 8, wetware::Stratum::Street}}),
          "Deploy NULL-3 onto ONI-1's cell");

  require(
      sim.apply_command(wetware::CommandFireOrdinance{
          .attacker_syndicate_id = 1,
          .operative_index = 0,
          .district_id = 1,
          .weapon = wetware::WeaponId::PlasmaLance,
          .target_coord = wetware::GridCoord{8, 8, wetware::Stratum::Street}}),
      "Fire PlasmaLance at (8, 8, Street)");
  require(!rival->squad.at(0).alive, "Rival operative ONI-1 is slain");
  require(sim.find_district(1)->corpse_drops.size() == 1,
          "Corpse hardware drop spawned at (8, 8, Street)");
  require(player->squad.at(2).alive && player->squad.at(2).health == 100,
          "Attacker's own squadmate on the target cell is not hit");

  require(sim.apply_command(wetware::CommandExtractCorpseSalvage{
              .syndicate_id = 1, .operative_index = 2, .district_id = 1}),
          "Player operative NULL-3 extracts fallen rival's V3 cyberware");
  require(!player->cryo_vault_salvage.empty() &&
              player->cryo_vault_salvage.front().blueprint_id == 1,
          "Extracted V3 Myomer Reflex Legs added to Player Cryo-Vault");

  // Test SatelliteRain 3-stratum vertical kinetic strike at (4, 4)
  require(
      sim.apply_command(wetware::CommandFireOrdinance{
          .attacker_syndicate_id = 2,
          .operative_index = 1,
          .district_id = 1,
          .weapon = wetware::WeaponId::SatelliteRain,
          .target_coord = wetware::GridCoord{4, 4, wetware::Stratum::Spire}}),
      "Fire SatelliteRain orbital strike at (4, 4)");
  require(sim.find_building(10)->state == wetware::BuildingState::Rubble,
          "SatelliteRain collapses Building 10 across all strata");
}

void test_thrall_directives_and_monorail_wreck_loot() {
  auto sim = wetware::create_default_vertical_slice();

  // Upgrade Player operative 0 (KESTREL-1) Brain to V4 and persuade a Police
  // officer and an Executive in District 2
  auto* player = sim.find_syndicate_mut(1);
  require(player != nullptr, "Player exists");
  player->squad.at(0).set_organ_tier(wetware::OrganSlot::Brain,
                                     wetware::CyberTier::V4);
  player->squad.at(0).sliders.intelligence = 1.0;
  require(sim.apply_command(wetware::CommandDeployOperative{
              .syndicate_id = 1,
              .operative_index = 0,
              .building_id = 20,
              .coord = wetware::GridCoord{5, 5, wetware::Stratum::Spire}}),
          "Deploy KESTREL-1 into Shinjuku (District 2)");

  require(sim.attempt_persuade(1, 0, 7002, wetware::PersuadeTargetClass::Police,
                               2, wetware::Stratum::Street,
                               wetware::ThrallDirective::CrowdSurge),
          "Persuade Police for CrowdSurge in District 2");
  require(sim.attempt_persuade(1, 0, 7003,
                               wetware::PersuadeTargetClass::CorporateGuard, 2,
                               wetware::Stratum::Street,
                               wetware::ThrallDirective::DeadManBroadcast),
          "Persuade CorporateGuard for DeadManBroadcast in District 2");
  require(sim.attempt_persuade(
              1, 0, 7001, wetware::PersuadeTargetClass::Executive, 2,
              wetware::Stratum::Spire, wetware::ThrallDirective::SleeperNode),
          "Chain-persuade Executive as SleeperNode in District 2");

  // Trigger SleeperNode
  require(sim.apply_command(wetware::CommandTriggerThrallDirective{
              .syndicate_id = 1, .actor_id = 7001, .target_building_id = 0}),
          "Trigger SleeperNode in District 2");
  require(sim.find_district(2)->sleeper_vision_syndicate == 1,
          "District 2 sleeper vision granted to Syndicate 1");

  // Trigger CrowdSurge
  require(sim.apply_command(wetware::CommandTriggerThrallDirective{
              .syndicate_id = 1, .actor_id = 7002, .target_building_id = 0}),
          "Trigger CrowdSurge in District 2");
  require(sim.find_district(2)->crowd_surge_active,
          "CrowdSurge is active in District 2");

  // Trigger DeadManBroadcast (detonates thrall and damages Building 20)
  require(sim.apply_command(wetware::CommandTriggerThrallDirective{
              .syndicate_id = 1, .actor_id = 7003, .target_building_id = 20}),
          "Trigger DeadManBroadcast in District 2");
  require(sim.find_district(2)->security_budget == 60,
          "DeadManBroadcast reduces District 2 security budget by 40");
  require(player->thralls.size() == 2,
          "DeadManBroadcast consumes the detonated thrall");

  // Collapse Chiba Monorail Hub (Building 21 in District 3) and loot wreck
  require(sim.apply_command(
              wetware::CommandShearColumns{.building_id = 21,
                                           .stratum = wetware::Stratum::Street,
                                           .columns_destroyed = 4}),
          "Shear Chiba Monorail Hub columns");
  require(sim.find_district(3)->monorail_wreck_lootable,
          "Chiba Monorail wreck is lootable on Street stratum");

  const wetware::Credits before_loot = player->treasury;
  require(sim.apply_command(wetware::CommandLootMonorailWreck{
              .syndicate_id = 1, .operative_index = 1, .district_id = 3}),
          "Player operative VEX-2 loots derailed monorail vault on Street");
  require(player->treasury == before_loot + 2500,
          "Monorail vault credits transferred to Player treasury");
  require(!sim.find_district(3)->monorail_wreck_lootable,
          "Monorail wreck marked looted");
}

void test_subgrid_transformer_sabotage_and_executive_convoy_ambush() {
  auto sim = wetware::create_default_vertical_slice();

  // Operative 3 (CHROME-4) is on UnderGrid; sabotage transformer in District 2
  require(sim.apply_command(wetware::CommandSabotageTransformer{
              .syndicate_id = 1, .operative_index = 3, .district_id = 2}),
          "Operative CHROME-4 sabotages Under-Grid transformer in District 2");
  require(!sim.find_district(2)->transformer_intact &&
              sim.find_district(2)->power_blackout &&
              sim.find_district(2)->security_budget == 70,
          "Transformer sabotage triggers District 2 blackout and -30 security");

  // Operative 1 (VEX-2) is on Street; intercept Executive Convoy in District 2
  const wetware::Credits before_convoy = sim.find_syndicate(1)->treasury;
  require(sim.apply_command(wetware::CommandInterceptExecutiveConvoy{
              .syndicate_id = 1, .operative_index = 1, .district_id = 2}),
          "Operative VEX-2 intercepts Zaibatsu Executive Convoy on Street");
  require(!sim.find_district(2)->executive_convoy_active &&
              sim.find_syndicate(1)->treasury == before_convoy + 1500,
          "Executive Convoy ambush awards +1500 bearer bonds and salvage");
}

void test_full_ops_tactical_sweep() {
  auto sim = wetware::create_default_vertical_slice();
  const wetware::Credits initial_credits = sim.find_syndicate(1)->treasury;

  require(sim.apply_command(wetware::CommandSabotageTransformer{
              .syndicate_id = 1, .operative_index = 3, .district_id = 1}),
          "Sabotage District 1 UnderGrid transformer");
  require(sim.apply_command(wetware::CommandInterceptExecutiveConvoy{
              .syndicate_id = 1, .operative_index = 1, .district_id = 1}),
          "Intercept District 1 Street executive convoy");
  require(sim.apply_command(
              wetware::CommandShearColumns{.building_id = 21,
                                           .stratum = wetware::Stratum::Street,
                                           .columns_destroyed = 4}),
          "Shear Monorail Hub columns");
  require(sim.apply_command(wetware::CommandLootMonorailWreck{
              .syndicate_id = 1, .operative_index = 2, .district_id = 3}),
          "Loot Monorail wreck on Street");
  sim.step_tick();

  const auto* d1 = sim.find_district(1);
  const auto* p1 = sim.find_syndicate(1);
  require(d1 != nullptr && p1 != nullptr, "District 1 and Player exist");
  require(d1->power_blackout && !d1->transformer_intact &&
              !d1->executive_convoy_active,
          "District 1 reflects blackout and intercepted convoy");
  require(p1->treasury > initial_credits + 3500 &&
              p1->cryo_vault_salvage.size() >= 2,
          "Combined Convoy + Monorail sweep credits and salvage recorded");
}

std::size_t count_events(const wetware::MegacitySimulation& sim,
                         wetware::SimEventKind kind) {
  std::size_t n = 0;
  for (const auto& ev : sim.events()) {
    if (ev.kind == kind) ++n;
  }
  return n;
}

const wetware::OperativeState& op_by_id(const wetware::MegacitySimulation& sim,
                                        wetware::SyndicateId syn,
                                        std::size_t index) {
  return sim.find_syndicate(syn)->squad.at(index);
}

void test_strategy_a_shepherd_human_shield_persuasion() {
  auto sim = wetware::create_default_vertical_slice();
  const auto focus = wetware::run_scenario("shepherd", sim);
  require(focus == wetware::DistrictId{2}, "Shepherd focuses Shinjuku");

  const auto& null_op = op_by_id(sim, 1, 2);
  require(sim.operative_district(null_op) == 2,
          "NULL-3 is physically deployed in Shinjuku");
  require(null_op.alive && null_op.health == 100,
          "Escort ring absorbs all 3 bursts; NULL-3 stays at 100 HP");
  require(count_events(sim, wetware::SimEventKind::ShotFired) == 3 &&
              count_events(sim, wetware::SimEventKind::ShieldIntercept) == 3 &&
              count_events(sim, wetware::SimEventKind::OperativeHit) == 0,
          "3 shots fired, 3 shield intercepts, 0 hits");
  // 14 civilians + 2 guards + hijacked ONI-1 = 17, minus 3 consumed shields.
  require(sim.find_syndicate(1)->thralls.size() == 14,
          "Thrall mesh: 17 recruited - 3 consumed = 14");
  require(!op_by_id(sim, 2, 0).alive &&
              count_events(sim, wetware::SimEventKind::RivalHijacked) == 1,
          "ONI-1 hijacked out of the Zaibatsu squad");
  require(sim.find_district(2)->owner_syndicate == 1 &&
              sim.find_building(20)->state == wetware::BuildingState::Intact &&
              sim.controls_intact_organ(1, wetware::CityOrgan::BroadcastSpire),
          "Shinjuku captured with the Broadcast Spire 100% intact");
  require(count_events(sim, wetware::SimEventKind::BuildingCollapsed) == 0,
          "No structure collapsed under the shepherd doctrine");
}

void test_strategy_b_scorched_earth_ordinance_fallout() {
  auto baseline = wetware::create_default_vertical_slice();
  require(baseline.calculate_district_daily_revenue(4) == 1050,
          "Intact Neo-Ruhr Ordinance Foundry yields 1050 CR/day");
  require(baseline.effective_research_cost(2, 2) == 840,
          "Owner gets -65% heavy weapon R&D cost (2400 -> 840)");

  auto sim = wetware::create_default_vertical_slice();
  const auto focus = wetware::run_scenario("scorched_earth", sim);
  require(focus == wetware::DistrictId{4}, "Scorched earth focuses Neo-Ruhr");
  require(sim.find_building(40)->state == wetware::BuildingState::Rubble &&
              count_events(sim, wetware::SimEventKind::BuildingCollapsed) == 1,
          "Ordinance Foundry collapses exactly once into rubble");
  require(count_events(sim, wetware::SimEventKind::OrbitalStrike) == 1,
          "Satellite Rain strike recorded");
  require(sim.find_district(4)->owner_syndicate == 2,
          "Scorched earth destroys rather than captures");
  require(sim.calculate_district_daily_revenue(4) == 0,
          "Rubble pays 0 CR/day (1050 -> 0) until rebuilt");
  require(sim.effective_research_cost(2, 2) == 2400 &&
              sim.effective_research_cost(1, 2) == 2400,
          "Nobody keeps the -65% Ordinance discount while it is rubble");
  for (const auto& syn_id : {2U, 3U}) {
    for (const auto& op : sim.find_syndicate(syn_id)->squad) {
      require(op.alive && op.health == 100,
              "Orbital strike in District 4 does not touch other districts");
    }
  }
}

void test_strategy_c_three_syndicate_three_stratum_convergence() {
  auto sim = wetware::create_default_vertical_slice();
  const auto focus = wetware::run_scenario("three_way_clash", sim);
  require(focus == wetware::DistrictId{1}, "Clash focuses Kowloon");

  // Every syndicate has operatives in the sector, on all three strata.
  bool strata_seen[3] = {false, false, false};
  for (wetware::SyndicateId syn = 1; syn <= 4; ++syn) {
    bool present = false;
    for (const auto& op : sim.find_syndicate(syn)->squad) {
      if (sim.operative_district(op) == 1) {
        present = true;
        strata_seen[static_cast<int>(op.current_stratum)] = true;
      }
    }
    require(present, "All 4 syndicates deployed in Kowloon");
  }
  require(strata_seen[0] && strata_seen[1] && strata_seen[2],
          "Operatives present on Under-Grid, Street, and Spire");
  require(count_events(sim, wetware::SimEventKind::OperativeDeployed) == 12,
          "11 convergence deployments + NULL-3 moving onto the corpse");

  // Skybridge breach: exactly 2 falls of 30 - 5*legs(V1) = 25 HP.
  std::size_t falls = 0;
  for (const auto& ev : sim.events()) {
    if (ev.kind == wetware::SimEventKind::FallDamage) {
      ++falls;
      require(ev.value == 25 && ev.to.stratum == wetware::Stratum::Street,
              "Each V1-legged operative falls to Street for exactly 25 HP");
    }
  }
  require(falls == 2, "ONI-3 and VIPER-1 both drop through the breach");

  // Crossfire outcomes (exact): ONI-3, ONI-1, VIPER-1 killed; VIPER-3 at 55.
  require(!op_by_id(sim, 2, 2).alive && !op_by_id(sim, 2, 0).alive &&
              !op_by_id(sim, 3, 0).alive,
          "ONI-3, ONI-1, VIPER-1 killed in the crossfire");
  require(op_by_id(sim, 3, 2).alive && op_by_id(sim, 3, 2).health == 55,
          "VIPER-3 survives the minigun burst at exactly 55 HP");
  require(count_events(sim, wetware::SimEventKind::OperativeKilled) == 3,
          "Exactly 3 combat kills");

  // Overclock flatline is targeted: only VEX-2 dies; nominal squadmates live.
  require(count_events(sim, wetware::SimEventKind::CardiacFlatline) == 1,
          "Exactly one cardiac flatline (VEX-2)");
  require(op_by_id(sim, 1, 0).alive && op_by_id(sim, 1, 3).alive,
          "KESTREL-1 and CHROME-4 were not overclocked and survive");
  require(op_by_id(sim, 1, 2).alive && op_by_id(sim, 1, 2).medical_status ==
                                           wetware::MedicalStatus::Nominal,
          "NULL-3 survives the overclock on its V3 Cyber-Heart");

  // Harvest -> thaw -> refit.
  require(count_events(sim, wetware::SimEventKind::SalvageExtracted) == 1 &&
              count_events(sim, wetware::SimEventKind::CryoThaw) == 1,
          "VEX-2's chrome harvested and a replacement thawed");
  const auto& vortex = op_by_id(sim, 1, 1);
  require(vortex.alive && vortex.callsign == "VORTEX-2" &&
              vortex.organ_tier(wetware::OrganSlot::Legs) ==
                  wetware::CyberTier::V3,
          "VORTEX-2 is active wearing the harvested V3 Legs");
}

void test_combat_is_scoped_to_districts() {
  auto sim = wetware::create_default_vertical_slice();
  // ONI-1 (District 2) and ONI-4 (District 3) both stand on grid (8, 8).
  // A EuroCorp strike in Kowloon at (8, 8) must not touch either of them.
  require(sim.apply_command(wetware::CommandDeployOperative{
              .syndicate_id = 1,
              .operative_index = 1,
              .building_id = 10,
              .coord = {3, 3, wetware::Stratum::Street}}),
          "Deploy VEX-2 in Kowloon");
  require(sim.apply_command(wetware::CommandFireOrdinance{
              .attacker_syndicate_id = 1,
              .operative_index = 1,
              .district_id = 1,
              .weapon = wetware::WeaponId::SatelliteRain,
              .target_coord = {8, 8, wetware::Stratum::Street}}),
          "Satellite Rain on Kowloon (8, 8)");
  for (const auto& op : sim.find_syndicate(2)->squad) {
    require(op.alive, "Zaibatsu operatives in other districts are untouched");
  }
  // An operative cannot fire into a district it is not deployed in.
  require(!sim.apply_command(wetware::CommandFireOrdinance{
              .attacker_syndicate_id = 1,
              .operative_index = 1,
              .district_id = 2,
              .weapon = wetware::WeaponId::Minigun,
              .target_coord = {8, 8, wetware::Stratum::Street}}),
          "Cannot fire into a district the shooter is not in");
}

void test_live_command_script_execution() {
  auto sim_a = wetware::create_default_vertical_slice();
  auto sim_b = wetware::create_default_vertical_slice();

  constexpr std::string_view kScript =
      "focus:2;organ:0:0:3;research:1:350;convoy:1;sabotage:1;combat_tick:2;"
      "raid:2:0;step_day:1";
  const auto focus_a = wetware::run_command_script(kScript, sim_a);
  const auto focus_b = wetware::run_command_script(kScript, sim_b);
  require(focus_a.has_value() && focus_b == focus_a && *focus_a == 2,
          "Command script sets focus district to 2");
  require(sim_a.state_digest() == sim_b.state_digest(),
          "Identical command scripts produce identical state_digest");
  require(count_events(sim_a, wetware::SimEventKind::ShotFired) >= 2,
          "combat_tick command fires live exchange shots");
  require(sim_a.find_district(2)->owner_syndicate == 1,
          "Raid command captures District 2 for EuroCorp");
  require(!wetware::run_command_script("unknown_opcode:1", sim_a).has_value(),
          "Malformed command opcode returns std::nullopt");
}

} // namespace

int main() {
  test_symmetric_three_path_progression();
  test_three_stratum_cascading_collapse_and_rebuild();
  test_sp_and_mp_overclock_and_persuadertron();
  test_sector_grid_vertical_traversal_sightline_and_breach();
  test_rival_ai_controller();
  test_deterministic_command_replay();
  test_ordinance_strike_and_corpse_wetware_extraction();
  test_thrall_directives_and_monorail_wreck_loot();
  test_subgrid_transformer_sabotage_and_executive_convoy_ambush();
  test_full_ops_tactical_sweep();
  test_strategy_a_shepherd_human_shield_persuasion();
  test_strategy_b_scorched_earth_ordinance_fallout();
  test_strategy_c_three_syndicate_three_stratum_convergence();
  test_combat_is_scoped_to_districts();
  test_live_command_script_execution();
  std::cout << "All wetware C++23 simulation tests passed.\n";
  return 0;
}
