#include "wetware/simulation.hpp"

#include <iostream>

int main() {
  auto sim = wetware::create_default_vertical_slice(
      wetware::SessionMode::SinglePlayer);
  sim.step_tick();

  const auto* player = sim.find_syndicate(1);
  const auto* rival = sim.find_syndicate(2);
  if (player == nullptr || rival == nullptr) {
    return 1;
  }

  std::cout << "{\n"
            << "  \"tick\": " << sim.current_tick() << ",\n"
            << "  \"digest\": " << sim.state_digest() << ",\n"
            << "  \"player_treasury\": " << player->treasury << ",\n"
            << "  \"rival_treasury\": " << rival->treasury << ",\n"
            << "  \"player_v3_legs_effective_cost\": "
            << sim.effective_research_cost(1, 1) << ",\n"
            << "  \"rival_v3_legs_effective_cost\": "
            << sim.effective_research_cost(2, 1) << "\n"
            << "}\n";
  return 0;
}
