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
