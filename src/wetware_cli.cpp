#include "wetware/scenarios.hpp"
#include "wetware/simulation.hpp"

#include <fstream>
#include <iostream>
#include <string>
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

  const auto focus = wetware::run_scenario(scenario, sim);
  if (!focus.has_value()) {
    std::cerr << "unknown scenario: " << scenario << "\n";
    return 2;
  }
  const std::string payload = sim.export_snapshot_json(*focus);

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
