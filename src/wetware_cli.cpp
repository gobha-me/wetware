#include "wetware/simulation.hpp"

#include <fstream>
#include <iostream>
#include <string_view>

int main(int argc, char** argv) {
  std::string_view scenario = "default";
  std::string_view out_path{};

  for (int i = 1; i < argc; ++i) {
    const std::string_view arg(argv[i]);
    if (arg == "--scenario" && i + 1 < argc) {
      scenario = argv[++i];
    } else if (out_path.empty()) {
      out_path = arg;
    }
  }

  const auto mode = (scenario == "overclock_mp")
                        ? wetware::SessionMode::MultiplayerMegacityWar
                        : wetware::SessionMode::SinglePlayer;
  auto sim = wetware::create_default_vertical_slice(mode);

  if (scenario == "collapse") {
    sim.apply_command(wetware::CommandTriggerOverclock{
        .syndicate_id = 1,
        .active = true,
    });
    sim.apply_command(wetware::CommandShearColumns{
        .building_id = 10,
        .stratum = wetware::Stratum::Street,
        .columns_destroyed = 4,
    });
  } else if (scenario == "overclock_mp") {
    sim.apply_command(wetware::CommandTriggerOverclock{
        .syndicate_id = 1,
        .active = true,
    });
  } else if (scenario == "full_ops") {
    sim.apply_command(wetware::CommandTriggerOverclock{
        .syndicate_id = 1,
        .active = true,
    });
    sim.apply_command(wetware::CommandSabotageTransformer{
        .syndicate_id = 1,
        .operative_index = 3,
        .district_id = 1,
    });
    sim.apply_command(wetware::CommandInterceptExecutiveConvoy{
        .syndicate_id = 1,
        .operative_index = 1,
        .district_id = 1,
    });
    sim.apply_command(wetware::CommandShearColumns{
        .building_id = 10,
        .stratum = wetware::Stratum::Street,
        .columns_destroyed = 4,
    });
    sim.apply_command(wetware::CommandShearColumns{
        .building_id = 21,
        .stratum = wetware::Stratum::Street,
        .columns_destroyed = 4,
    });
    sim.apply_command(wetware::CommandLootMonorailWreck{
        .syndicate_id = 1,
        .operative_index = 2,
        .district_id = 3,
    });
  } else if (scenario == "shepherd") {
    auto* player = sim.find_syndicate_mut(1);
    if (player != nullptr) {
      player->squad.at(2).set_organ_tier(wetware::OrganSlot::Brain,
                                         wetware::CyberTier::V4);
      player->squad.at(2).sliders.intelligence = 0.90;
      player->squad.at(2).grid_pos =
          wetware::GridCoord{8, 8, wetware::Stratum::Street};
    }
    for (std::uint32_t cid = 8001; cid <= 8014; ++cid) {
      sim.attempt_persuade(1, 2, cid, wetware::PersuadeTargetClass::Civilian, 2,
                           wetware::Stratum::Street,
                           wetware::ThrallDirective::Escort);
    }
    sim.attempt_persuade(
        1, 2, 8101, wetware::PersuadeTargetClass::CorporateGuard, 2,
        wetware::Stratum::Street, wetware::ThrallDirective::CrowdSurge);
    sim.apply_command(wetware::CommandTriggerThrallDirective{
        .syndicate_id = 1,
        .actor_id = 8101,
        .target_building_id = 0,
    });
    sim.apply_command(wetware::CommandFireOrdinance{
        .attacker_syndicate_id = 2,
        .operative_index = 1,
        .district_id = 2,
        .weapon = wetware::WeaponId::Minigun,
        .target_coord = wetware::GridCoord{8, 8, wetware::Stratum::Street},
    });
    sim.attempt_persuade(
        1, 2, 201, wetware::PersuadeTargetClass::RivalOperative, 2,
        wetware::Stratum::Street, wetware::ThrallDirective::Escort);
    sim.resolve_district_raid(1, 2, false);
  } else if (scenario == "scorched_earth") {
    for (auto& op : sim.find_syndicate_mut(1)->squad) {
      for (const auto slot :
           {wetware::OrganSlot::Legs, wetware::OrganSlot::Arms,
            wetware::OrganSlot::Chest, wetware::OrganSlot::Eyes,
            wetware::OrganSlot::Brain, wetware::OrganSlot::Heart}) {
        op.set_organ_tier(slot, wetware::CyberTier::V3);
      }
    }
    sim.resolve_district_raid(1, 4, true);
  } else if (scenario == "three_way_clash") {
    auto* zaibatsu = sim.find_syndicate_mut(2);
    auto* triad = sim.find_syndicate_mut(3);
    if (zaibatsu != nullptr && triad != nullptr) {
      zaibatsu->squad.at(2).grid_pos =
          wetware::GridCoord{6, 4, wetware::Stratum::Spire};
      zaibatsu->squad.at(2).current_stratum = wetware::Stratum::Spire;
      triad->squad.at(0).grid_pos =
          wetware::GridCoord{6, 4, wetware::Stratum::Spire};
      triad->squad.at(0).current_stratum = wetware::Stratum::Spire;
    }
    sim.apply_command(wetware::CommandBreachFloorSlab{
        .district_id = 1,
        .coord = wetware::GridCoord{6, 4, wetware::Stratum::Spire},
    });
    sim.apply_command(wetware::CommandSabotageTransformer{
        .syndicate_id = 1,
        .operative_index = 3,
        .district_id = 1,
    });
    sim.apply_command(wetware::CommandTriggerOverclock{
        .syndicate_id = 1,
        .active = true,
    });
  }

  sim.step_tick();
  const std::string payload = sim.export_snapshot_json();

  if (!out_path.empty()) {
    std::ofstream file{std::string(out_path), std::ios::binary};
    if (!file) {
      return 1;
    }
    file << payload;
    return file.good() ? 0 : 1;
  }

  std::cout << payload;
  return 0;
}
