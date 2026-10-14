#include "wetware/simulation.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace wetware {

namespace {

constexpr double kOrganAcceleratorMultiplier = 0.35; // -65% cost & time
constexpr double kClearinghouseBonusMultiplier = 1.25;
constexpr double kSinglePlayerBulletTimeScale = 0.25;
constexpr double kRedlineThreshold = 0.80;

std::uint64_t fnv1a_mix(std::uint64_t hash, std::uint64_t value) noexcept {
  for (int i = 0; i < 8; ++i) {
    const auto byte = static_cast<std::uint8_t>((value >> (i * 8)) & 0xFFU);
    hash ^= byte;
    hash *= 1099511628211ULL;
  }
  return hash;
}

double clamp01(double value) noexcept {
  return std::clamp(value, 0.0, 1.0);
}

} // namespace

CyberTier OperativeState::organ_tier(OrganSlot slot) const noexcept {
  return organs.at(static_cast<std::size_t>(slot));
}

void OperativeState::set_organ_tier(OrganSlot slot, CyberTier tier) noexcept {
  organs.at(static_cast<std::size_t>(slot)) = tier;
}

MegacitySimulation::MegacitySimulation(SessionMode mode, std::uint64_t seed)
    : mode_(mode), rng_state_(seed) {
}

void MegacitySimulation::add_blueprint(TechBlueprint blueprint) {
  blueprints_.push_back(std::move(blueprint));
}

void MegacitySimulation::add_syndicate(SyndicateLedger syndicate) {
  syndicates_.push_back(std::move(syndicate));
}

void MegacitySimulation::add_district(DistrictState district) {
  districts_.push_back(std::move(district));
}

void MegacitySimulation::add_building(BuildingStructure building) {
  const BuildingId building_id = building.id;
  const DistrictId district_id = building.district_id;
  buildings_.push_back(std::move(building));
  for (auto& district : districts_) {
    if (district.id == district_id) {
      if (std::ranges::find(district.buildings, building_id) ==
          district.buildings.end()) {
        district.buildings.push_back(building_id);
      }
      break;
    }
  }
}

const TechBlueprint* MegacitySimulation::find_blueprint(
    BlueprintId id) const noexcept {
  for (const auto& bp : blueprints_) {
    if (bp.id == id) return &bp;
  }
  return nullptr;
}

const SyndicateLedger* MegacitySimulation::find_syndicate(
    SyndicateId id) const noexcept {
  for (const auto& syn : syndicates_) {
    if (syn.id == id) return &syn;
  }
  return nullptr;
}

SyndicateLedger* MegacitySimulation::find_syndicate_mut(
    SyndicateId id) noexcept {
  for (auto& syn : syndicates_) {
    if (syn.id == id) return &syn;
  }
  return nullptr;
}

const DistrictState* MegacitySimulation::find_district(
    DistrictId id) const noexcept {
  for (const auto& dist : districts_) {
    if (dist.id == id) return &dist;
  }
  return nullptr;
}

const BuildingStructure* MegacitySimulation::find_building(
    BuildingId id) const noexcept {
  for (const auto& bld : buildings_) {
    if (bld.id == id) return &bld;
  }
  return nullptr;
}

bool MegacitySimulation::controls_intact_organ(SyndicateId syndicate_id,
                                               CityOrgan organ) const noexcept {
  for (const auto& district : districts_) {
    if (district.owner_syndicate != syndicate_id || district.organ != organ) {
      continue;
    }
    bool organ_building_intact = true;
    for (const BuildingId bid : district.buildings) {
      const auto* bld = find_building(bid);
      if (bld != nullptr && bld->houses_city_organ &&
          bld->state != BuildingState::Intact) {
        organ_building_intact = false;
        break;
      }
    }
    if (organ_building_intact) return true;
  }
  return false;
}

Credits MegacitySimulation::effective_research_cost(
    SyndicateId syndicate_id, BlueprintId blueprint_id) const noexcept {
  const auto* bp = find_blueprint(blueprint_id);
  if (bp == nullptr) return 0;

  const CityOrgan matching_organ =
      (bp->category == BlueprintCategory::CyberneticOrgan)
          ? CityOrgan::BioFoundry
          : CityOrgan::OrdinanceFoundry;
  if (controls_intact_organ(syndicate_id, matching_organ)) {
    return std::max<Credits>(
        1, static_cast<Credits>(
               std::llround(static_cast<double>(bp->base_research_cost) *
                            kOrganAcceleratorMultiplier)));
  }
  return bp->base_research_cost;
}

SimulationTick MegacitySimulation::effective_research_ticks(
    SyndicateId syndicate_id, BlueprintId blueprint_id) const noexcept {
  const auto* bp = find_blueprint(blueprint_id);
  if (bp == nullptr) return 0;

  const CityOrgan matching_organ =
      (bp->category == BlueprintCategory::CyberneticOrgan)
          ? CityOrgan::BioFoundry
          : CityOrgan::OrdinanceFoundry;
  if (controls_intact_organ(syndicate_id, matching_organ)) {
    return std::max<SimulationTick>(
        1U, static_cast<SimulationTick>(
                std::llround(static_cast<double>(bp->base_research_ticks) *
                             kOrganAcceleratorMultiplier)));
  }
  return bp->base_research_ticks;
}

Credits MegacitySimulation::effective_fabrication_cost(
    SyndicateId syndicate_id, BlueprintId blueprint_id) const noexcept {
  const auto* bp = find_blueprint(blueprint_id);
  if (bp == nullptr) return 0;

  const CityOrgan matching_organ =
      (bp->category == BlueprintCategory::CyberneticOrgan)
          ? CityOrgan::BioFoundry
          : CityOrgan::OrdinanceFoundry;
  if (controls_intact_organ(syndicate_id, matching_organ)) {
    return std::max<Credits>(
        1, static_cast<Credits>(
               std::llround(static_cast<double>(bp->base_fabrication_cost) *
                            kOrganAcceleratorMultiplier)));
  }
  return bp->base_fabrication_cost;
}

Credits MegacitySimulation::calculate_district_daily_revenue(
    DistrictId district_id) const noexcept {
  const auto* district = find_district(district_id);
  if (district == nullptr) return 0;

  Credits total = 0;
  for (const BuildingId bid : district->buildings) {
    const auto* bld = find_building(bid);
    if (bld == nullptr) continue;
    if (bld->state == BuildingState::Intact) {
      total += bld->base_daily_revenue;
    } else if (bld->state == BuildingState::Damaged) {
      total += bld->base_daily_revenue / 2;
    }
  }
  if (district->power_blackout) {
    total = (total * 70) / 100;
  }
  return total;
}

Credits MegacitySimulation::calculate_syndicate_daily_net(
    SyndicateId syndicate_id) const noexcept {
  const auto* syndicate = find_syndicate(syndicate_id);
  if (syndicate == nullptr) return 0;

  Credits gross = 0;
  for (const auto& district : districts_) {
    if (district.owner_syndicate == syndicate_id) {
      gross += calculate_district_daily_revenue(district.id);
    }
  }
  if (controls_intact_organ(syndicate_id, CityOrgan::Clearinghouse)) {
    gross = static_cast<Credits>(std::llround(static_cast<double>(gross) *
                                              kClearinghouseBonusMultiplier));
  }

  Credits research_drain = 0;
  for (const auto& proj : syndicate->research) {
    if (!proj.unlocked) {
      research_drain += proj.daily_budget;
    }
  }
  return gross - research_drain;
}

void MegacitySimulation::propagate_structural_collapse(
    BuildingStructure& building) {
  bool lower_support_failed = false;
  for (auto& story : building.stories) {
    if (lower_support_failed ||
        story.intact_columns * 2U < story.total_columns) {
      story.collapsed = true;
      story.intact_columns = 0;
      lower_support_failed = true;
    }
  }

  const bool any_collapsed = std::ranges::any_of(
      building.stories, [](const StorySegment& s) { return s.collapsed; });
  const bool any_damaged =
      std::ranges::any_of(building.stories, [](const StorySegment& s) {
        return s.intact_columns < s.total_columns;
      });

  if (any_collapsed) {
    building.state = BuildingState::Rubble;
    building.rebuild_ticks_remaining = building.rebuild_total_ticks;

    // Seamless 3-stratum vertical drop-through for operatives on collapsed
    // upper strata inside this building.
    for (auto& syndicate : syndicates_) {
      for (auto& op : syndicate.squad) {
        if (op.occupied_building == building.id &&
            op.current_stratum == Stratum::Spire) {
          op.current_stratum = Stratum::Street;
        }
      }
    }

    // If this building houses a City Organ, apply organ destruction
    // side-effects
    for (auto& district : districts_) {
      if (district.id != building.district_id || !building.houses_city_organ) {
        continue;
      }
      if (district.organ == CityOrgan::PowerSubGrid) {
        district.power_blackout = true;
        for (const DistrictId adj_id : district.adjacent_districts) {
          for (auto& adj : districts_) {
            if (adj.id == adj_id) {
              adj.power_blackout = true;
            }
          }
        }
      } else if (district.organ == CityOrgan::MonorailHub) {
        district.monorail_wreck_lootable = true;
        district.monorail_vault_loot = 2500;
      }
    }
  } else if (any_damaged) {
    building.state = BuildingState::Damaged;
  } else {
    building.state = BuildingState::Intact;
  }
}

bool MegacitySimulation::apply_command(const SimulationCommand& cmd) {
  command_log_.push_back(cmd);

  if (const auto* set_bio = std::get_if<CommandSetBiochem>(&cmd)) {
    auto* syn = find_syndicate_mut(set_bio->syndicate_id);
    if (syn == nullptr || set_bio->operative_index >= syn->squad.size()) {
      return false;
    }
    auto& op = syn->squad.at(set_bio->operative_index);
    op.sliders.intelligence = clamp01(set_bio->sliders.intelligence);
    op.sliders.perception = clamp01(set_bio->sliders.perception);
    op.sliders.adrenaline = clamp01(set_bio->sliders.adrenaline);
    return true;
  }

  if (const auto* overclock = std::get_if<CommandTriggerOverclock>(&cmd)) {
    auto* syn = find_syndicate_mut(overclock->syndicate_id);
    if (syn == nullptr) return false;

    const OverclockState target_state =
        !overclock->active ? OverclockState::Inactive
                           : (mode_ == SessionMode::SinglePlayer
                                  ? OverclockState::BulletTimeDilation
                                  : OverclockState::HyperReflexSurge);

    for (auto& op : syn->squad) {
      if (!op.alive) continue;
      op.overclock = target_state;
      if (overclock->active) {
        op.sliders.adrenaline = std::max(op.sliders.adrenaline, 0.95);
      }
    }

    if (mode_ == SessionMode::SinglePlayer) {
      tactical_time_scale_ =
          overclock->active ? kSinglePlayerBulletTimeScale : 1.0;
      macro_city_time_scale_ = 1.0;
    } else {
      tactical_time_scale_ = 1.0;
      macro_city_time_scale_ = 1.0;
    }
    return true;
  }

  if (const auto* shear = std::get_if<CommandShearColumns>(&cmd)) {
    for (auto& bld : buildings_) {
      if (bld.id != shear->building_id) continue;
      for (auto& story : bld.stories) {
        if (story.stratum == shear->stratum) {
          if (shear->columns_destroyed >= story.intact_columns) {
            story.intact_columns = 0;
          } else {
            story.intact_columns -= shear->columns_destroyed;
          }
        }
      }
      propagate_structural_collapse(bld);
      return true;
    }
    return false;
  }

  if (const auto* rebuild = std::get_if<CommandFundRebuild>(&cmd)) {
    auto* syn = find_syndicate_mut(rebuild->syndicate_id);
    if (syn == nullptr) return false;
    for (auto& bld : buildings_) {
      if (bld.id != rebuild->building_id) continue;
      if (bld.state != BuildingState::Rubble &&
          bld.state != BuildingState::Damaged) {
        return false;
      }
      if (syn->treasury < bld.rebuild_total_cost) return false;
      syn->treasury -= bld.rebuild_total_cost;
      bld.state = BuildingState::Rebuilding;
      bld.rebuild_ticks_remaining = bld.rebuild_total_ticks;
      return true;
    }
    return false;
  }

  if (const auto* alloc = std::get_if<CommandAllocateResearch>(&cmd)) {
    auto* syn = find_syndicate_mut(alloc->syndicate_id);
    if (syn == nullptr || find_blueprint(alloc->blueprint_id) == nullptr) {
      return false;
    }
    for (auto& proj : syn->research) {
      if (proj.blueprint_id == alloc->blueprint_id) {
        proj.daily_budget = std::max<Credits>(0, alloc->daily_budget);
        return true;
      }
    }
    syn->research.push_back(ResearchProgress{
        .blueprint_id = alloc->blueprint_id,
        .invested_credits = 0,
        .accrued_ticks = 0,
        .daily_budget = std::max<Credits>(0, alloc->daily_budget),
        .unlocked = false,
    });
    return true;
  }

  if (const auto* salvage = std::get_if<CommandSalvageFieldHardware>(&cmd)) {
    auto* syn = find_syndicate_mut(salvage->syndicate_id);
    if (syn == nullptr || find_blueprint(salvage->blueprint_id) == nullptr ||
        salvage->quantity == 0) {
      return false;
    }
    for (auto& item : syn->cryo_vault_salvage) {
      if (item.blueprint_id == salvage->blueprint_id) {
        item.quantity += salvage->quantity;
        return true;
      }
    }
    syn->cryo_vault_salvage.push_back(SalvagedHardwareUnit{
        .blueprint_id = salvage->blueprint_id,
        .quantity = salvage->quantity,
    });
    return true;
  }

  if (const auto* use_salvage = std::get_if<CommandUseSalvage>(&cmd)) {
    auto* syn = find_syndicate_mut(use_salvage->syndicate_id);
    const auto* bp = find_blueprint(use_salvage->blueprint_id);
    if (syn == nullptr || bp == nullptr) return false;

    auto it = std::ranges::find_if(
        syn->cryo_vault_salvage, [&](const SalvagedHardwareUnit& unit) {
          return unit.blueprint_id == use_salvage->blueprint_id &&
                 unit.quantity > 0;
        });
    if (it == syn->cryo_vault_salvage.end()) return false;

    if (use_salvage->reverse_engineer) {
      // Path 3B: Sacrifice physical salvaged unit for +50% R&D breakthrough
      it->quantity -= 1;
      const Credits req_cost =
          effective_research_cost(syn->id, use_salvage->blueprint_id);
      const SimulationTick req_ticks =
          effective_research_ticks(syn->id, use_salvage->blueprint_id);

      ResearchProgress* target_proj = nullptr;
      for (auto& proj : syn->research) {
        if (proj.blueprint_id == use_salvage->blueprint_id) {
          target_proj = &proj;
          break;
        }
      }
      if (target_proj == nullptr) {
        syn->research.push_back(ResearchProgress{
            .blueprint_id = use_salvage->blueprint_id,
            .invested_credits = 0,
            .accrued_ticks = 0,
            .daily_budget = 0,
            .unlocked = false,
        });
        target_proj = &syn->research.back();
      }
      target_proj->invested_credits += (req_cost + 1) / 2;
      target_proj->accrued_ticks += (req_ticks + 1U) / 2U;
      if (target_proj->invested_credits >= req_cost &&
          target_proj->accrued_ticks >= req_ticks) {
        target_proj->unlocked = true;
      }
      return true;
    }

    // Path 3A: Direct physical bolt-on of a single salvaged unit without
    // requiring blueprint unlock.
    if (use_salvage->operative_index >= syn->squad.size()) return false;
    it->quantity -= 1;
    auto& op = syn->squad.at(use_salvage->operative_index);
    if (bp->category == BlueprintCategory::CyberneticOrgan) {
      op.set_organ_tier(bp->organ_slot, bp->cyber_tier);
    } else {
      op.primary_weapon = bp->weapon_id;
    }
    return true;
  }

  return false;
}

void MegacitySimulation::step_syndicate_biochem(SyndicateLedger& syndicate) {
  for (auto& op : syndicate.squad) {
    if (!op.alive) continue;

    const double max_slider =
        std::max({op.sliders.intelligence, op.sliders.perception,
                  op.sliders.adrenaline});
    const double heart_resistance =
        static_cast<double>(static_cast<int>(op.organ_tier(OrganSlot::Heart))) *
        0.04;
    const double brain_resistance =
        static_cast<double>(static_cast<int>(op.organ_tier(OrganSlot::Brain))) *
        0.04;

    if (op.sliders.intelligence > kRedlineThreshold ||
        op.sliders.perception > kRedlineThreshold) {
      op.neural_toxicity =
          clamp01(op.neural_toxicity + 0.18 - brain_resistance);
    } else {
      op.neural_toxicity = clamp01(op.neural_toxicity - 0.08);
    }

    if (op.sliders.adrenaline > kRedlineThreshold ||
        op.overclock != OverclockState::Inactive) {
      op.cardiac_strain = clamp01(op.cardiac_strain + 0.22 - heart_resistance);
    } else if (max_slider <= kRedlineThreshold) {
      op.cardiac_strain = clamp01(op.cardiac_strain - 0.10);
    }

    if (op.cardiac_strain >= 1.0) {
      op.medical_status = MedicalStatus::CardiacFlatline;
      op.alive = false;
      op.overclock = OverclockState::Inactive;
    } else if (op.neural_toxicity >= 1.0) {
      op.medical_status = MedicalStatus::CyberPsychosis;
    } else {
      op.medical_status = MedicalStatus::Nominal;
    }
  }
}

void MegacitySimulation::step_syndicate_research(SyndicateLedger& syndicate) {
  for (auto& proj : syndicate.research) {
    if (proj.unlocked || proj.daily_budget <= 0) continue;
    const Credits spend = std::min(syndicate.treasury, proj.daily_budget);
    if (spend <= 0) continue;

    syndicate.treasury -= spend;
    proj.invested_credits += spend;
    proj.accrued_ticks += 1;

    const Credits req_cost =
        effective_research_cost(syndicate.id, proj.blueprint_id);
    const SimulationTick req_ticks =
        effective_research_ticks(syndicate.id, proj.blueprint_id);

    if (proj.invested_credits >= req_cost && proj.accrued_ticks >= req_ticks) {
      proj.unlocked = true;
    }
  }
}

void MegacitySimulation::step_rebuilds() {
  for (auto& bld : buildings_) {
    if (bld.state != BuildingState::Rebuilding) continue;
    if (bld.rebuild_ticks_remaining > 1) {
      bld.rebuild_ticks_remaining -= 1;
      continue;
    }
    bld.rebuild_ticks_remaining = 0;
    bld.state = BuildingState::Intact;
    for (auto& story : bld.stories) {
      story.intact_columns = story.total_columns;
      story.collapsed = false;
    }
  }
}

void MegacitySimulation::step_tick() {
  tick_ += 1;

  for (auto& syndicate : syndicates_) {
    Credits gross = 0;
    for (const auto& district : districts_) {
      if (district.owner_syndicate == syndicate.id) {
        gross += calculate_district_daily_revenue(district.id);
      }
    }
    if (controls_intact_organ(syndicate.id, CityOrgan::Clearinghouse)) {
      gross = static_cast<Credits>(std::llround(static_cast<double>(gross) *
                                                kClearinghouseBonusMultiplier));
    }
    syndicate.treasury += gross;
    step_syndicate_research(syndicate);
    step_syndicate_biochem(syndicate);
  }

  step_rebuilds();
}

bool MegacitySimulation::trigger_power_reroute_blackout(
    SyndicateId syndicate_id, DistrictId target_district_id) {
  if (!controls_intact_organ(syndicate_id, CityOrgan::PowerSubGrid)) {
    return false;
  }
  for (auto& district : districts_) {
    if (district.id == target_district_id) {
      district.power_blackout = true;
      return true;
    }
  }
  return false;
}

double MegacitySimulation::persuadertron_bandwidth(
    SyndicateId syndicate_id, std::size_t operative_index) const noexcept {
  const auto* syn = find_syndicate(syndicate_id);
  if (syn == nullptr || operative_index >= syn->squad.size()) return 0.0;

  const auto& op = syn->squad.at(operative_index);
  if (!op.alive) return 0.0;

  const double brain_tier =
      static_cast<double>(static_cast<int>(op.organ_tier(OrganSlot::Brain)));
  double bandwidth = 10.0 * brain_tier + (op.sliders.intelligence * 10.0);

  for (const auto& thrall : syn->thralls) {
    switch (thrall.target_class) {
      case PersuadeTargetClass::Civilian: bandwidth += 4.0; break;
      case PersuadeTargetClass::Police: bandwidth += 8.0; break;
      case PersuadeTargetClass::CorporateGuard: bandwidth += 12.0; break;
      case PersuadeTargetClass::Executive: bandwidth += 18.0; break;
      case PersuadeTargetClass::RivalOperative: bandwidth += 25.0; break;
    }
  }

  if (controls_intact_organ(syndicate_id, CityOrgan::BroadcastSpire)) {
    bandwidth *= 2.0;
  }
  return bandwidth;
}

double MegacitySimulation::persuade_threshold(
    PersuadeTargetClass target_class) noexcept {
  switch (target_class) {
    case PersuadeTargetClass::Civilian: return 12.0;
    case PersuadeTargetClass::Police: return 28.0;
    case PersuadeTargetClass::CorporateGuard: return 48.0;
    case PersuadeTargetClass::Executive: return 70.0;
    case PersuadeTargetClass::RivalOperative: return 110.0;
  }
  return 100.0;
}

bool MegacitySimulation::attempt_persuade(
    SyndicateId syndicate_id, std::size_t operative_index,
    std::uint32_t actor_id, PersuadeTargetClass target_class,
    DistrictId district_id, Stratum stratum, ThrallDirective directive) {
  auto* syn = find_syndicate_mut(syndicate_id);
  if (syn == nullptr) return false;

  const double bw = persuadertron_bandwidth(syndicate_id, operative_index);
  if (bw < persuade_threshold(target_class)) {
    return false;
  }

  syn->thralls.push_back(PersuadedThrall{
      .actor_id = actor_id,
      .target_class = target_class,
      .district_id = district_id,
      .stratum = stratum,
      .directive = directive,
  });
  return true;
}

RaidOutcome MegacitySimulation::resolve_district_raid(
    SyndicateId attacker_id, DistrictId district_id, bool scorched_earth,
    std::optional<SyndicateId> live_interceptor) {
  RaidOutcome outcome{
      .district_id = district_id,
      .attacker_id = attacker_id,
      .defender_id = 0,
      .attacker_won = false,
      .intercepted_live = live_interceptor.has_value(),
      .buildings_collapsed = 0,
      .loot_credits = 0,
  };

  DistrictState* target_district = nullptr;
  for (auto& d : districts_) {
    if (d.id == district_id) {
      target_district = &d;
      break;
    }
  }
  auto* attacker = find_syndicate_mut(attacker_id);
  if (target_district == nullptr || attacker == nullptr) return outcome;

  outcome.defender_id =
      live_interceptor.value_or(target_district->owner_syndicate);
  const auto* defender = find_syndicate(outcome.defender_id);

  auto squad_score = [](const SyndicateLedger* syn) {
    if (syn == nullptr) return 0.0;
    double score = 0.0;
    for (const auto& op : syn->squad) {
      if (!op.alive) continue;
      for (const CyberTier tier : op.organs) {
        score += static_cast<double>(static_cast<int>(tier)) * 5.0;
      }
      score += (op.sliders.intelligence + op.sliders.perception +
                op.sliders.adrenaline) *
               10.0;
      if (op.overclock == OverclockState::HyperReflexSurge) {
        score *= 1.25;
      }
    }
    return score;
  };

  const double attack_power = squad_score(attacker);
  double defense_power =
      static_cast<double>(target_district->security_budget) * 0.5;
  if (live_interceptor.has_value()) {
    defense_power += squad_score(defender);
  } else if (defender != nullptr) {
    defense_power += squad_score(defender) * 0.65;
  }
  if (target_district->power_blackout) {
    defense_power *= 0.70;
  }

  outcome.attacker_won = (attack_power >= defense_power);
  if (!outcome.attacker_won) {
    return outcome;
  }

  if (scorched_earth) {
    for (const BuildingId bid : target_district->buildings) {
      for (auto& bld : buildings_) {
        if (bld.id == bid && !bld.stories.empty()) {
          bld.stories.front().intact_columns = 0;
          propagate_structural_collapse(bld);
          outcome.buildings_collapsed += 1;
        }
      }
    }
    if (target_district->monorail_wreck_lootable) {
      outcome.loot_credits = target_district->monorail_vault_loot;
      attacker->treasury += outcome.loot_credits;
      target_district->monorail_wreck_lootable = false;
      target_district->monorail_vault_loot = 0;
    }
  } else {
    target_district->owner_syndicate = attacker_id;
  }

  return outcome;
}

std::uint64_t MegacitySimulation::state_digest() const noexcept {
  std::uint64_t hash = 14695981039346656037ULL;
  hash = fnv1a_mix(hash, tick_);
  hash = fnv1a_mix(hash, static_cast<std::uint64_t>(mode_));
  hash = fnv1a_mix(hash, rng_state_);

  for (const auto& syn : syndicates_) {
    hash = fnv1a_mix(hash, syn.id);
    hash = fnv1a_mix(hash, static_cast<std::uint64_t>(syn.treasury));
    for (const auto& proj : syn.research) {
      hash = fnv1a_mix(hash, proj.blueprint_id);
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(proj.invested_credits));
      hash = fnv1a_mix(hash, proj.accrued_ticks);
      hash = fnv1a_mix(hash, proj.unlocked ? 1ULL : 0ULL);
    }
    for (const auto& salvage : syn.cryo_vault_salvage) {
      hash = fnv1a_mix(hash, salvage.blueprint_id);
      hash = fnv1a_mix(hash, salvage.quantity);
    }
    for (const auto& op : syn.squad) {
      hash = fnv1a_mix(hash, op.id);
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(op.current_stratum));
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(op.overclock));
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(op.medical_status));
      for (const CyberTier tier : op.organs) {
        hash = fnv1a_mix(hash, static_cast<std::uint64_t>(tier));
      }
    }
  }

  for (const auto& dist : districts_) {
    hash = fnv1a_mix(hash, dist.id);
    hash = fnv1a_mix(hash, dist.owner_syndicate);
    hash = fnv1a_mix(hash, dist.power_blackout ? 1ULL : 0ULL);
  }

  for (const auto& bld : buildings_) {
    hash = fnv1a_mix(hash, bld.id);
    hash = fnv1a_mix(hash, static_cast<std::uint64_t>(bld.state));
    hash = fnv1a_mix(hash, bld.rebuild_ticks_remaining);
  }

  return hash;
}

MegacitySimulation create_default_vertical_slice(SessionMode mode) {
  MegacitySimulation sim(mode, 0x57455457415245ULL);

  sim.add_blueprint(TechBlueprint{
      .id = 1,
      .name = "V3 Myomer Reflex Legs",
      .category = BlueprintCategory::CyberneticOrgan,
      .organ_slot = OrganSlot::Legs,
      .cyber_tier = CyberTier::V3,
      .weapon_id = WeaponId::Persuadertron,
      .base_research_cost = 2000,
      .base_research_ticks = 10,
      .base_fabrication_cost = 800,
  });
  sim.add_blueprint(TechBlueprint{
      .id = 2,
      .name = "Heavy Gauss Cannon",
      .category = BlueprintCategory::HeavyOrdinance,
      .organ_slot = OrganSlot::Arms,
      .cyber_tier = CyberTier::V3,
      .weapon_id = WeaponId::SuppressedGauss,
      .base_research_cost = 2400,
      .base_research_ticks = 12,
      .base_fabrication_cost = 900,
  });

  SyndicateLedger player{
      .id = 1,
      .name = "EUROCORP SYNDICATE",
      .treasury = 6000,
      .research = {},
      .cryo_vault_salvage = {},
      .squad =
          {
              OperativeState{.id = 101,
                             .callsign = "KESTREL-1",
                             .current_stratum = Stratum::Spire,
                             .occupied_building = 10},
              OperativeState{.id = 102,
                             .callsign = "VEX-2",
                             .current_stratum = Stratum::Street,
                             .occupied_building = 10},
              OperativeState{.id = 103,
                             .callsign = "NULL-3",
                             .current_stratum = Stratum::Street,
                             .occupied_building = 11},
              OperativeState{.id = 104,
                             .callsign = "CHROME-4",
                             .current_stratum = Stratum::UnderGrid,
                             .occupied_building = 11},
          },
      .thralls = {},
  };

  SyndicateLedger rival{
      .id = 2,
      .name = "ZAIBATSU KAO",
      .treasury = 6000,
      .research = {},
      .cryo_vault_salvage = {},
      .squad =
          {
              OperativeState{.id = 201,
                             .callsign = "ONI-1",
                             .current_stratum = Stratum::Street,
                             .occupied_building = 20},
              OperativeState{.id = 202,
                             .callsign = "ONI-2",
                             .current_stratum = Stratum::Street,
                             .occupied_building = 20},
              OperativeState{.id = 203,
                             .callsign = "ONI-3",
                             .current_stratum = Stratum::Spire,
                             .occupied_building = 21},
              OperativeState{.id = 204,
                             .callsign = "ONI-4",
                             .current_stratum = Stratum::UnderGrid,
                             .occupied_building = 21},
          },
      .thralls = {},
  };

  sim.add_syndicate(std::move(player));
  sim.add_syndicate(std::move(rival));

  sim.add_district(DistrictState{
      .id = 1,
      .name = "KOWLOON BIO-FOUNDRY SECTOR",
      .owner_syndicate = 1,
      .organ = CityOrgan::BioFoundry,
      .power_blackout = false,
      .monorail_wreck_lootable = false,
      .monorail_vault_loot = 0,
      .security_budget = 120,
      .adjacent_districts = {2, 3},
      .buildings = {},
  });

  sim.add_district(DistrictState{
      .id = 2,
      .name = "SHINJUKU BROADCAST SPIRE",
      .owner_syndicate = 2,
      .organ = CityOrgan::BroadcastSpire,
      .power_blackout = false,
      .monorail_wreck_lootable = false,
      .monorail_vault_loot = 0,
      .security_budget = 100,
      .adjacent_districts = {1, 3},
      .buildings = {},
  });

  sim.add_district(DistrictState{
      .id = 3,
      .name = "CHIBA MONORAIL & SUB-GRID",
      .owner_syndicate = 2,
      .organ = CityOrgan::MonorailHub,
      .power_blackout = false,
      .monorail_wreck_lootable = false,
      .monorail_vault_loot = 0,
      .security_budget = 90,
      .adjacent_districts = {1, 2},
      .buildings = {},
  });

  sim.add_building(BuildingStructure{
      .id = 10,
      .name = "Kowloon Bio-Foundry Vat Tower",
      .district_id = 1,
      .houses_city_organ = true,
      .is_skybridge_hub = true,
      .base_daily_revenue = 900,
      .rebuild_total_cost = 1800,
      .rebuild_total_ticks = 5,
      .rebuild_ticks_remaining = 0,
      .state = BuildingState::Intact,
      .stories =
          {
              StorySegment{.stratum = Stratum::UnderGrid,
                           .story_index = 0,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
              StorySegment{.stratum = Stratum::Street,
                           .story_index = 1,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
              StorySegment{.stratum = Stratum::Spire,
                           .story_index = 2,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
          },
  });

  sim.add_building(BuildingStructure{
      .id = 11,
      .name = "Kowloon Ripperdoc Arcade",
      .district_id = 1,
      .houses_city_organ = false,
      .is_skybridge_hub = false,
      .base_daily_revenue = 450,
      .rebuild_total_cost = 900,
      .rebuild_total_ticks = 3,
      .rebuild_ticks_remaining = 0,
      .state = BuildingState::Intact,
      .stories =
          {
              StorySegment{.stratum = Stratum::Street,
                           .story_index = 0,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
          },
  });

  sim.add_building(BuildingStructure{
      .id = 20,
      .name = "Shinjuku Neural Broadcast Spire",
      .district_id = 2,
      .houses_city_organ = true,
      .is_skybridge_hub = true,
      .base_daily_revenue = 1100,
      .rebuild_total_cost = 2200,
      .rebuild_total_ticks = 6,
      .rebuild_ticks_remaining = 0,
      .state = BuildingState::Intact,
      .stories =
          {
              StorySegment{.stratum = Stratum::Street,
                           .story_index = 0,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
              StorySegment{.stratum = Stratum::Spire,
                           .story_index = 1,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
          },
  });

  sim.add_building(BuildingStructure{
      .id = 21,
      .name = "Chiba Mag-Lev Viaduct Pylon",
      .district_id = 3,
      .houses_city_organ = true,
      .is_skybridge_hub = true,
      .base_daily_revenue = 800,
      .rebuild_total_cost = 1600,
      .rebuild_total_ticks = 4,
      .rebuild_ticks_remaining = 0,
      .state = BuildingState::Intact,
      .stories =
          {
              StorySegment{.stratum = Stratum::Street,
                           .story_index = 0,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
              StorySegment{.stratum = Stratum::Spire,
                           .story_index = 1,
                           .intact_columns = 4,
                           .total_columns = 4,
                           .collapsed = false},
          },
  });

  return sim;
}

} // namespace wetware
