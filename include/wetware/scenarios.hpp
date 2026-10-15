#ifndef WETWARE_SCENARIOS_HPP
#define WETWARE_SCENARIOS_HPP

#include "wetware/simulation.hpp"

#include <optional>
#include <string_view>

namespace wetware {

// Scripted, command-driven scenarios shared by the C++ tests, the
// `wetware_cli` snapshot exporter, and therefore the Godot presentation.
// Every scenario advances the simulation itself; callers must not mutate
// state between running a scenario and exporting/asserting on it.
//
// Returns the district the presentation layer should focus on, or
// std::nullopt for an unknown scenario name.
std::optional<DistrictId> run_scenario(std::string_view name,
                                       MegacitySimulation& sim);

// Strategy A: Persuadertron human-shield phalanx and intact capture of the
// Shinjuku Broadcast Spire (District 2).
DistrictId run_shepherd_scenario(MegacitySimulation& sim);

// Strategy B: scorched-earth heavy-ordinance raid on the Neo-Ruhr Ordinance
// Foundry (District 4).
DistrictId run_scorched_earth_scenario(MegacitySimulation& sim);

// Stress test C: four syndicates converge across all three strata of the
// Kowloon sector (District 1): skybridge breach, crossfire kills, redlined
// overclock flatline, squadmate organ harvest, and cryo-replacement thaw.
DistrictId run_three_way_clash_scenario(MegacitySimulation& sim);

} // namespace wetware

#endif // WETWARE_SCENARIOS_HPP
