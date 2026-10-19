#include "wetware/scenarios.hpp"
#include "wetware/simulation.hpp"

#include <algorithm>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>

namespace {

std::string compact_single_line(std::string s) {
  std::replace(s.begin(), s.end(), '\n', ' ');
  std::replace(s.begin(), s.end(), '\r', ' ');
  return s;
}

} // namespace

int main(int argc, char** argv) {
  std::string_view scenario = "default";
  std::string_view inline_commands{};
  std::string_view command_file{};
  std::string_view out_path{};
  bool interactive = false;

  for (int i = 1; i < argc; ++i) {
    const std::string_view arg(argv[i]);
    if (arg == "--scenario" && i + 1 < argc) {
      scenario = argv[++i];
    } else if (arg == "--commands" && i + 1 < argc) {
      inline_commands = argv[++i];
    } else if (arg == "--command-file" && i + 1 < argc) {
      command_file = argv[++i];
    } else if (arg == "--interactive") {
      interactive = true;
    } else if (out_path.empty()) {
      out_path = arg;
    }
  }

  const auto mode = (scenario == "overclock_mp")
                        ? wetware::SessionMode::MultiplayerMegacityWar
                        : wetware::SessionMode::SinglePlayer;
  auto sim = wetware::create_default_vertical_slice(mode);

  if (interactive) {
    wetware::DistrictId active_focus = 1;
    std::string line;
    while (std::getline(std::cin, line)) {
      if (line == "quit" || line == "exit") {
        break;
      }
      const auto next_focus = wetware::run_command_script(line, sim);
      if (next_focus.has_value()) {
        active_focus = *next_focus;
      }
      std::cout << compact_single_line(sim.export_snapshot_json(active_focus))
                << '\n'
                << std::flush;
    }
    return 0;
  }

  std::optional<wetware::DistrictId> focus;
  if (!command_file.empty()) {
    std::ifstream cmd_stream{std::string(command_file)};
    if (!cmd_stream) {
      std::cerr << "cannot open command file: " << command_file << "\n";
      return 2;
    }
    std::ostringstream buf;
    buf << cmd_stream.rdbuf();
    focus = wetware::run_command_script(buf.str(), sim);
  } else if (!inline_commands.empty()) {
    focus = wetware::run_command_script(inline_commands, sim);
  } else {
    focus = wetware::run_scenario(scenario, sim);
  }

  if (!focus.has_value()) {
    std::cerr << "invalid scenario or command script\n";
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
