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

  // Player (Syndicate 1) controls intact Bio-Foundry (District 1) -> -65% R&D
  // cost and time (35% of 2000 = 700 credits, 35% of 10 = 4 ticks).
  // Rival (Syndicate 2) does not control Bio-Foundry -> full 2000 credits, 10
  // ticks.
  require(sim.effective_research_cost(1, 1) == 700,
          "Bio-Foundry owner gets -65% R&D cost on V3 cyberware");
  require(sim.effective_research_ticks(1, 1) == 4,
          "Bio-Foundry owner gets -65% R&D duration on V3 cyberware");
  require(sim.effective_research_cost(2, 1) == 2000,
          "Non-owner pays base R&D cost");

  // Path 3A: Rival salvages physical V3 Legs from the field and bolts it
  // directly onto operative 0 without unlocking the blueprint.
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

  // Path 3B: Rival sacrifices 2nd salvaged unit for +50% R&D breakthrough
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

  // Operative 0 starts on Spire stratum of Building 10 (Kowloon Bio-Foundry)
  const auto* player = sim.find_syndicate(1);
  require(player->squad.at(0).current_stratum == wetware::Stratum::Spire,
          "Operative 0 starts on Spire stratum");

  // Shear 3 of 4 load-bearing columns on the Street stratum of Building 10
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

  // Because Bio-Foundry is now rubble, Player loses the -65% Bio-Foundry
  // accelerator until rebuilt!
  require(!sim.controls_intact_organ(1, wetware::CityOrgan::BioFoundry),
          "Destroyed Bio-Foundry no longer grants intact organ perk");
  require(sim.effective_research_cost(1, 1) == 2000,
          "Player R&D cost reverts to base while Bio-Foundry is rubble");

  // Fund reconstruction and step 5 ticks
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

  // Persuadertron chain-hijack test:
  // Syndicate 2 controls intact Broadcast Spire (2x bandwidth -> 30.0 base).
  require(sp_sim.attempt_persuade(
              2, 0, 9001, wetware::PersuadeTargetClass::Police, 2,
              wetware::Stratum::Street, wetware::ThrallDirective::SleeperNode),
          "Broadcast Spire owner has sufficient bandwidth to hijack Police as "
          "Sleeper Node");
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
}

} // namespace

int main() {
  test_symmetric_three_path_progression();
  test_three_stratum_cascading_collapse_and_rebuild();
  test_sp_and_mp_overclock_and_persuadertron();
  test_deterministic_command_replay();
  std::cout << "All wetware C++23 simulation tests passed.\n";
  return 0;
}
