#include "wetware/scenarios.hpp"

#include <cstdint>

namespace wetware {

namespace {

constexpr SyndicateId kEuroCorp = 1;
constexpr SyndicateId kZaibatsu = 2;
constexpr SyndicateId kTriad = 3;
constexpr SyndicateId kOmni = 4;

constexpr BuildingId kKowloonVatTower = 10;
constexpr BuildingId kKowloonArcade = 11;
constexpr BuildingId kShinjukuSpire = 20;
constexpr BuildingId kNeoRuhrSmelter = 40;

void set_full_loadout(OperativeState& op, CyberTier tier) {
  for (const auto slot :
       {OrganSlot::Legs, OrganSlot::Arms, OrganSlot::Chest, OrganSlot::Eyes,
        OrganSlot::Brain, OrganSlot::Heart}) {
    op.set_organ_tier(slot, tier);
  }
}

void deploy(MegacitySimulation& sim, SyndicateId syndicate,
            std::size_t operative_index, BuildingId building, std::int32_t x,
            std::int32_t y, Stratum stratum) {
  sim.apply_command(CommandDeployOperative{
      .syndicate_id = syndicate,
      .operative_index = operative_index,
      .building_id = building,
      .coord = GridCoord{x, y, stratum},
  });
}

void fire(MegacitySimulation& sim, SyndicateId syndicate,
          std::size_t operative_index, DistrictId district, WeaponId weapon,
          std::int32_t x, std::int32_t y, Stratum stratum) {
  sim.apply_command(CommandFireOrdinance{
      .attacker_syndicate_id = syndicate,
      .operative_index = operative_index,
      .district_id = district,
      .weapon = weapon,
      .target_coord = GridCoord{x, y, stratum},
  });
}

} // namespace

DistrictId run_shepherd_scenario(MegacitySimulation& sim) {
  constexpr DistrictId kShinjuku = 2;
  auto* euro = sim.find_syndicate_mut(kEuroCorp);
  if (euro == nullptr) return kShinjuku;

  // Loadout (pre-mission ripperdoc work): NULL-3 runs a V4 Brain.
  euro->squad.at(2).set_organ_tier(OrganSlot::Brain, CyberTier::V4);
  sim.apply_command(CommandSetBiochem{
      .syndicate_id = kEuroCorp,
      .operative_index = 2,
      .sliders = BiochemSliders{.intelligence = 0.90,
                                .perception = 0.50,
                                .adrenaline = 0.50},
  });
  deploy(sim, kEuroCorp, 2, kShinjukuSpire, 7, 7, Stratum::Street);

  // 14 civilians + 2 corporate guards join NULL-3's Escort mesh.
  for (std::uint32_t cid = 8001; cid <= 8014; ++cid) {
    sim.attempt_persuade(kEuroCorp, 2, cid, PersuadeTargetClass::Civilian,
                         kShinjuku, Stratum::Street, ThrallDirective::Escort);
  }
  for (const std::uint32_t gid : {8101U, 8102U}) {
    sim.attempt_persuade(kEuroCorp, 2, gid, PersuadeTargetClass::CorporateGuard,
                         kShinjuku, Stratum::Street, ThrallDirective::Escort);
  }

  // Zaibatsu ONI-2 opens fire on NULL-3 with three weapons; Escort thralls
  // physically absorb each burst.
  for (const auto weapon :
       {WeaponId::Minigun, WeaponId::SuppressedGauss, WeaponId::PlasmaLance}) {
    fire(sim, kZaibatsu, 1, kShinjuku, weapon, 7, 7, Stratum::Street);
  }

  // The snowballed mesh hijacks ONI-1, then EuroCorp takes the district
  // without firing a shot or damaging the Broadcast Spire.
  sim.attempt_persuade(kEuroCorp, 2, 201, PersuadeTargetClass::RivalOperative,
                       kShinjuku, Stratum::Street, ThrallDirective::Escort);
  sim.resolve_district_raid(kEuroCorp, kShinjuku, false);
  sim.step_tick();
  return kShinjuku;
}

DistrictId run_scorched_earth_scenario(MegacitySimulation& sim) {
  constexpr DistrictId kNeoRuhr = 4;
  auto* euro = sim.find_syndicate_mut(kEuroCorp);
  if (euro == nullptr) return kNeoRuhr;

  for (auto& op : euro->squad) {
    set_full_loadout(op, CyberTier::V3);
  }
  deploy(sim, kEuroCorp, 0, kNeoRuhrSmelter, 5, 6, Stratum::Street);
  deploy(sim, kEuroCorp, 1, kNeoRuhrSmelter, 6, 7, Stratum::Street);
  deploy(sim, kEuroCorp, 2, kNeoRuhrSmelter, 4, 7, Stratum::Street);
  deploy(sim, kEuroCorp, 3, kNeoRuhrSmelter, 5, 8, Stratum::Street);

  // Orbital strike on the smelter core, then the auto-resolved
  // scorched-earth raid levels what is left.
  fire(sim, kEuroCorp, 1, kNeoRuhr, WeaponId::SatelliteRain, 8, 8,
       Stratum::Street);
  sim.resolve_district_raid(kEuroCorp, kNeoRuhr, true);
  sim.step_tick();
  return kNeoRuhr;
}

DistrictId run_three_way_clash_scenario(MegacitySimulation& sim) {
  constexpr DistrictId kKowloon = 1;
  auto* euro = sim.find_syndicate_mut(kEuroCorp);
  if (euro == nullptr) return kKowloon;

  // Four syndicates converge on Kowloon across all three strata.
  deploy(sim, kEuroCorp, 2, kKowloonArcade, 4, 6, Stratum::Street);
  deploy(sim, kZaibatsu, 0, kKowloonArcade, 10, 6, Stratum::Street);
  deploy(sim, kZaibatsu, 1, kKowloonArcade, 11, 7, Stratum::Street);
  deploy(sim, kZaibatsu, 2, kKowloonVatTower, 6, 4, Stratum::Spire);
  deploy(sim, kZaibatsu, 3, kKowloonArcade, 9, 9, Stratum::UnderGrid);
  deploy(sim, kTriad, 0, kKowloonVatTower, 6, 4, Stratum::Spire);
  deploy(sim, kTriad, 1, kKowloonArcade, 3, 9, Stratum::Street);
  deploy(sim, kTriad, 2, kKowloonArcade, 4, 10, Stratum::Street);
  deploy(sim, kTriad, 3, kKowloonArcade, 3, 3, Stratum::UnderGrid);
  deploy(sim, kOmni, 1, kKowloonArcade, 12, 10, Stratum::Street);
  deploy(sim, kOmni, 2, kKowloonArcade, 13, 11, Stratum::Street);

  // KESTREL-1 breaches the skybridge slab under the dueling ONI-3 / VIPER-1.
  sim.apply_command(CommandBreachFloorSlab{
      .district_id = kKowloon,
      .coord = GridCoord{6, 4, Stratum::Spire},
  });

  // Crossfire on the street where they landed.
  fire(sim, kTriad, 1, kKowloon, WeaponId::SuppressedGauss, 6, 4,
       Stratum::Street); // VIPER-2 -> ONI-3 (and VIPER-1 is spared: own side)
  fire(sim, kOmni, 1, kKowloon, WeaponId::PlasmaLance, 10, 6,
       Stratum::Street); // AEGIS-2 -> ONI-1
  fire(sim, kZaibatsu, 1, kKowloon, WeaponId::Minigun, 4, 10,
       Stratum::Street); // ONI-2 -> VIPER-3
  fire(sim, kEuroCorp, 2, kKowloon, WeaponId::SuppressedGauss, 6, 4,
       Stratum::Street); // NULL-3 -> VIPER-1

  // VEX-2 (V3 Legs, stock Heart) and NULL-3 (V3 Heart) overclock; KESTREL-1
  // and CHROME-4 stay nominal.
  euro->squad.at(1).set_organ_tier(OrganSlot::Legs, CyberTier::V3);
  euro->squad.at(2).set_organ_tier(OrganSlot::Heart, CyberTier::V3);
  sim.apply_command(CommandTriggerOverclock{
      .syndicate_id = kEuroCorp, .active = true, .operative_mask = 0b0110});
  for (int t = 0; t < 8 && euro->squad.at(1).alive; ++t) {
    sim.step_tick();
  }
  sim.apply_command(
      CommandTriggerOverclock{.syndicate_id = kEuroCorp, .active = false});
  sim.apply_command(CommandSetBiochem{.syndicate_id = kEuroCorp,
                                      .operative_index = 2,
                                      .sliders = BiochemSliders{}});

  // NULL-3 harvests VEX-2's chrome; a fresh meat-puppet is thawed into the
  // empty slot and fitted with the recovered V3 Legs.
  deploy(sim, kEuroCorp, 2, kKowloonVatTower, 2, 2, Stratum::Street);
  sim.apply_command(CommandExtractCorpseSalvage{.syndicate_id = kEuroCorp,
                                                .operative_index = 2,
                                                .district_id = kKowloon});
  sim.apply_command(CommandThawCryoReplacement{.syndicate_id = kEuroCorp,
                                               .operative_index = 1,
                                               .new_callsign = "VORTEX-2"});
  sim.apply_command(CommandUseSalvage{.syndicate_id = kEuroCorp,
                                      .blueprint_id = 1,
                                      .reverse_engineer = false,
                                      .operative_index = 1});
  return kKowloon;
}

std::optional<DistrictId> run_scenario(std::string_view name,
                                       MegacitySimulation& sim) {
  if (name == "default" || name == "overclock_mp") {
    if (name == "overclock_mp") {
      sim.apply_command(
          CommandTriggerOverclock{.syndicate_id = kEuroCorp, .active = true});
    }
    sim.step_tick();
    return DistrictId{1};
  }
  if (name == "collapse") {
    sim.apply_command(
        CommandTriggerOverclock{.syndicate_id = kEuroCorp, .active = true});
    sim.apply_command(CommandShearColumns{
        .building_id = kKowloonVatTower,
        .stratum = Stratum::Street,
        .columns_destroyed = 4,
    });
    sim.step_tick();
    return DistrictId{1};
  }
  if (name == "full_ops") {
    sim.apply_command(
        CommandTriggerOverclock{.syndicate_id = kEuroCorp, .active = true});
    sim.apply_command(CommandSabotageTransformer{
        .syndicate_id = kEuroCorp, .operative_index = 3, .district_id = 1});
    sim.apply_command(CommandInterceptExecutiveConvoy{
        .syndicate_id = kEuroCorp, .operative_index = 1, .district_id = 1});
    sim.apply_command(CommandShearColumns{.building_id = kKowloonVatTower,
                                          .stratum = Stratum::Street,
                                          .columns_destroyed = 4});
    sim.apply_command(CommandShearColumns{
        .building_id = 21, .stratum = Stratum::Street, .columns_destroyed = 4});
    sim.apply_command(CommandLootMonorailWreck{
        .syndicate_id = kEuroCorp, .operative_index = 2, .district_id = 3});
    sim.step_tick();
    return DistrictId{1};
  }
  if (name == "shepherd") return run_shepherd_scenario(sim);
  if (name == "scorched_earth") return run_scorched_earth_scenario(sim);
  if (name == "three_way_clash") return run_three_way_clash_scenario(sim);
  return std::nullopt;
}

} // namespace wetware
