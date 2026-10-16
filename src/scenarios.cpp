#include "wetware/scenarios.hpp"

#include <charconv>
#include <cstdint>
#include <string>
#include <vector>

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

std::string_view trim_sv(std::string_view sv) noexcept {
  while (!sv.empty() &&
         (sv.front() == ' ' || sv.front() == '\t' || sv.front() == '\r')) {
    sv.remove_prefix(1);
  }
  while (!sv.empty() &&
         (sv.back() == ' ' || sv.back() == '\t' || sv.back() == '\r')) {
    sv.remove_suffix(1);
  }
  return sv;
}

std::vector<std::string_view> split_sv(std::string_view sv, char delim) {
  std::vector<std::string_view> out;
  std::size_t start = 0;
  while (start <= sv.size()) {
    const std::size_t pos = sv.find(delim, start);
    if (pos == std::string_view::npos) {
      out.push_back(trim_sv(sv.substr(start)));
      break;
    }
    out.push_back(trim_sv(sv.substr(start, pos - start)));
    start = pos + 1;
  }
  return out;
}

bool parse_i64(std::string_view sv, std::int64_t& out) noexcept {
  sv = trim_sv(sv);
  if (sv.empty()) return false;
  const auto [ptr, ec] = std::from_chars(sv.data(), sv.data() + sv.size(), out);
  return ec == std::errc{} && ptr == sv.data() + sv.size();
}

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

bool execute_script_statement(std::string_view stmt, MegacitySimulation& sim,
                              DistrictId& focus) {
  const auto args = split_sv(stmt, ':');
  if (args.empty() || args[0].empty()) return true;
  const std::string_view op = args[0];

  auto arg_i64 = [&](std::size_t idx, std::int64_t fallback = 0) {
    std::int64_t val = fallback;
    if (idx < args.size()) {
      (void)parse_i64(args[idx], val);
    }
    return val;
  };

  if (op == "focus" && args.size() >= 2) {
    const auto did = arg_i64(1, 1);
    if (did >= 1 && did <= 6) {
      focus = static_cast<DistrictId>(did);
      return true;
    }
    return false;
  }
  if (op == "overclock" && args.size() >= 2) {
    return sim.apply_command(CommandTriggerOverclock{
        .syndicate_id = kEuroCorp, .active = (arg_i64(1, 0) != 0)});
  }
  if (op == "deploy" && args.size() >= 6) {
    const auto op_idx = static_cast<std::size_t>(arg_i64(1, 0));
    const auto bld_id = static_cast<BuildingId>(arg_i64(2, 10));
    const auto gx = static_cast<std::int32_t>(arg_i64(3, 4));
    const auto gy = static_cast<std::int32_t>(arg_i64(4, 4));
    const auto st = static_cast<Stratum>(arg_i64(5, 1));
    return sim.apply_command(CommandDeployOperative{
        .syndicate_id = kEuroCorp,
        .operative_index = op_idx,
        .building_id = bld_id,
        .coord = GridCoord{gx, gy, st},
    });
  }
  if (op == "fire" && args.size() >= 7) {
    const auto op_idx = static_cast<std::size_t>(arg_i64(1, 0));
    const auto did = static_cast<DistrictId>(arg_i64(2, focus));
    const auto wpn = static_cast<WeaponId>(arg_i64(3, 1));
    const auto gx = static_cast<std::int32_t>(arg_i64(4, 8));
    const auto gy = static_cast<std::int32_t>(arg_i64(5, 8));
    const auto st = static_cast<Stratum>(arg_i64(6, 1));
    return sim.apply_command(CommandFireOrdinance{
        .attacker_syndicate_id = kEuroCorp,
        .operative_index = op_idx,
        .district_id = did,
        .weapon = wpn,
        .target_coord = GridCoord{gx, gy, st},
    });
  }
  if (op == "shear" && args.size() >= 3) {
    const auto bld_id = static_cast<BuildingId>(arg_i64(1, 10));
    const auto cols = static_cast<std::uint32_t>(arg_i64(2, 4));
    return sim.apply_command(CommandShearColumns{
        .building_id = bld_id,
        .stratum = Stratum::Street,
        .columns_destroyed = cols,
    });
  }
  if (op == "rebuild" && args.size() >= 2) {
    const auto bld_id = static_cast<BuildingId>(arg_i64(1, 10));
    return sim.apply_command(
        CommandFundRebuild{.syndicate_id = kEuroCorp, .building_id = bld_id});
  }
  if (op == "sabotage" && args.size() >= 2) {
    const auto did = static_cast<DistrictId>(arg_i64(1, focus));
    return sim.apply_command(CommandSabotageTransformer{
        .syndicate_id = kEuroCorp, .operative_index = 3, .district_id = did});
  }
  if (op == "convoy" && args.size() >= 2) {
    const auto did = static_cast<DistrictId>(arg_i64(1, focus));
    return sim.apply_command(CommandInterceptExecutiveConvoy{
        .syndicate_id = kEuroCorp, .operative_index = 1, .district_id = did});
  }
  if (op == "monorail" && args.size() >= 2) {
    const auto did = static_cast<DistrictId>(arg_i64(1, focus));
    return sim.apply_command(CommandLootMonorailWreck{
        .syndicate_id = kEuroCorp, .operative_index = 2, .district_id = did});
  }
  if (op == "persuade" && args.size() >= 3) {
    const auto op_idx = static_cast<std::size_t>(arg_i64(1, 2));
    const auto did = static_cast<DistrictId>(arg_i64(2, focus));
    for (std::uint32_t cid = 8201; cid <= 8206; ++cid) {
      sim.attempt_persuade(kEuroCorp, op_idx, cid,
                           PersuadeTargetClass::Civilian, did, Stratum::Street,
                           ThrallDirective::CrowdSurge);
    }
    return true;
  }
  if (op == "organ" && args.size() >= 4) {
    auto* euro = sim.find_syndicate_mut(kEuroCorp);
    const auto op_idx = static_cast<std::size_t>(arg_i64(1, 0));
    const auto slot = static_cast<OrganSlot>(arg_i64(2, 0));
    const auto tier = static_cast<CyberTier>(arg_i64(3, 2));
    if (euro == nullptr || op_idx >= euro->squad.size()) return false;
    euro->squad.at(op_idx).set_organ_tier(slot, tier);
    return true;
  }
  if (op == "research" && args.size() >= 3) {
    const auto bp_id = static_cast<BlueprintId>(arg_i64(1, 1));
    const auto budget = static_cast<Credits>(arg_i64(2, 350));
    return sim.apply_command(CommandAllocateResearch{
        .syndicate_id = kEuroCorp,
        .blueprint_id = bp_id,
        .daily_budget = budget,
    });
  }
  if (op == "salvage_add" && args.size() >= 3) {
    const auto bp_id = static_cast<BlueprintId>(arg_i64(1, 1));
    const auto qty = static_cast<std::uint32_t>(arg_i64(2, 1));
    return sim.apply_command(CommandSalvageFieldHardware{
        .syndicate_id = kEuroCorp, .blueprint_id = bp_id, .quantity = qty});
  }
  if (op == "salvage_use" && args.size() >= 4) {
    const auto bp_id = static_cast<BlueprintId>(arg_i64(1, 1));
    const bool rev = (arg_i64(2, 0) != 0);
    const auto op_idx = static_cast<std::size_t>(arg_i64(3, 0));
    return sim.apply_command(CommandUseSalvage{
        .syndicate_id = kEuroCorp,
        .blueprint_id = bp_id,
        .reverse_engineer = rev,
        .operative_index = op_idx,
    });
  }
  if (op == "thaw" && args.size() >= 3) {
    const auto op_idx = static_cast<std::size_t>(arg_i64(1, 0));
    return sim.apply_command(CommandThawCryoReplacement{
        .syndicate_id = kEuroCorp,
        .operative_index = op_idx,
        .new_callsign = std::string(args[2]),
    });
  }
  if (op == "raid" && args.size() >= 3) {
    const auto did = static_cast<DistrictId>(arg_i64(1, focus));
    const bool scorched = (arg_i64(2, 0) != 0);
    (void)sim.resolve_district_raid(kEuroCorp, did, scorched);
    focus = did;
    return true;
  }
  if (op == "step_day") {
    const auto ticks = arg_i64(1, 1);
    for (std::int64_t t = 0; t < ticks; ++t) {
      sim.step_tick();
      (void)sim.step_rival_ai(kZaibatsu);
      (void)sim.step_rival_ai(kTriad);
      (void)sim.step_rival_ai(kOmni);
    }
    return true;
  }
  return false;
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

std::optional<DistrictId> run_command_script(std::string_view script,
                                             MegacitySimulation& sim) {
  DistrictId focus = 1;
  for (const auto line : split_sv(script, '\n')) {
    for (const auto stmt : split_sv(line, ';')) {
      if (stmt.empty() || stmt.front() == '#') continue;
      if (!execute_script_statement(stmt, sim, focus)) {
        return std::nullopt;
      }
    }
  }
  return focus;
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
