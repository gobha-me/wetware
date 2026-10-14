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

SectorGrid::SectorGrid(std::int32_t width, std::int32_t height)
    : width_(std::max(1, width)), height_(std::max(1, height)),
      cells_(static_cast<std::size_t>(width_) *
             static_cast<std::size_t>(height_) * 3U) {
  for (std::int32_t y = 0; y < height_; ++y) {
    for (std::int32_t x = 0; x < width_; ++x) {
      set_cell(GridCoord{x, y, Stratum::UnderGrid},
               SectorCell{.kind = TileKind::UnderGridCatwalk});
      set_cell(GridCoord{x, y, Stratum::Street},
               SectorCell{.kind = TileKind::StreetAsphalt});
      set_cell(GridCoord{x, y, Stratum::Spire},
               SectorCell{.kind = TileKind::Void});
    }
  }
}

bool SectorGrid::in_bounds(GridCoord coord) const noexcept {
  const auto s = static_cast<std::uint8_t>(coord.stratum);
  return coord.x >= 0 && coord.x < width_ && coord.y >= 0 &&
         coord.y < height_ && s < 3U;
}

std::size_t SectorGrid::index(GridCoord coord) const noexcept {
  const auto s = static_cast<std::size_t>(coord.stratum);
  const auto ux = static_cast<std::size_t>(coord.x);
  const auto uy = static_cast<std::size_t>(coord.y);
  const auto uw = static_cast<std::size_t>(width_);
  const auto uh = static_cast<std::size_t>(height_);
  return (s * uw * uh) + (uy * uw) + ux;
}

const SectorCell& SectorGrid::cell(GridCoord coord) const {
  return cells_.at(index(coord));
}

void SectorGrid::set_cell(GridCoord coord, SectorCell value) {
  if (!in_bounds(coord)) return;
  cells_.at(index(coord)) = value;
}

bool SectorGrid::is_walkable(GridCoord coord) const noexcept {
  if (!in_bounds(coord)) return false;
  const auto& c = cells_.at(index(coord));
  if (c.breached) return false;
  switch (c.kind) {
    case TileKind::UnderGridCatwalk:
    case TileKind::StreetAsphalt:
    case TileKind::SpireSkybridge:
    case TileKind::VerticalShaft:
    case TileKind::RubbleCrater: return true;
    case TileKind::Void:
    case TileKind::CoverPillar:
    case TileKind::OpaqueWall: return false;
  }
  return false;
}

bool SectorGrid::can_traverse_vertical(GridCoord from,
                                       Stratum target_stratum) const noexcept {
  if (!in_bounds(from) || from.stratum == target_stratum) return false;
  const GridCoord dest{from.x, from.y, target_stratum};
  if (!in_bounds(dest)) return false;
  return cell(from).kind == TileKind::VerticalShaft &&
         cell(dest).kind == TileKind::VerticalShaft && !cell(dest).breached;
}

bool SectorGrid::has_sightline(GridCoord origin, GridCoord target,
                               double perception_slider,
                               std::uint8_t eyes_tier) const noexcept {
  if (!in_bounds(origin) || !in_bounds(target)) return false;

  const double dx = static_cast<double>(target.x - origin.x);
  const double dy = static_cast<double>(target.y - origin.y);
  const double dz = static_cast<double>(static_cast<int>(target.stratum) -
                                        static_cast<int>(origin.stratum)) *
                    3.0;
  const double dist = std::sqrt(dx * dx + dy * dy + dz * dz);

  const double max_range = 6.0 + (clamp01(perception_slider) * 10.0) +
                           (static_cast<double>(eyes_tier) * 2.5);
  if (dist > max_range) return false;

  // High perception (>= 0.75) or V3+ Cyber-Eyes grants thermal/structural
  // silhouette detection through 1 opaque wall or 1 stratum slab.
  const int allowed_wall_penetrations =
      (perception_slider >= 0.75 || eyes_tier >= 3U) ? 1 : 0;

  if (origin.stratum != target.stratum && allowed_wall_penetrations == 0) {
    // Cross-stratum sightline without thermal penetration requires an open
    // Void/breached cell or VerticalShaft along the vertical transition.
    const auto& upper_cell =
        (origin.stratum > target.stratum) ? cell(origin) : cell(target);
    if (upper_cell.kind != TileKind::VerticalShaft &&
        upper_cell.kind != TileKind::SpireSkybridge && !upper_cell.breached) {
      return false;
    }
  }

  std::int32_t x0 = origin.x;
  std::int32_t y0 = origin.y;
  const std::int32_t x1 = target.x;
  const std::int32_t y1 = target.y;

  const std::int32_t sx = (x0 < x1) ? 1 : -1;
  const std::int32_t sy = (y0 < y1) ? 1 : -1;
  const std::int32_t adx = std::abs(x1 - x0);
  const std::int32_t ady = -std::abs(y1 - y0);
  std::int32_t err = adx + ady;

  int walls_hit = 0;
  while (true) {
    if (x0 == x1 && y0 == y1) break;
    const GridCoord step_coord{x0, y0, origin.stratum};
    if (!(x0 == origin.x && y0 == origin.y)) {
      const auto kind = cell(step_coord).kind;
      if (kind == TileKind::OpaqueWall) {
        walls_hit += 1;
        if (walls_hit > allowed_wall_penetrations) {
          return false;
        }
      }
    }
    const std::int32_t e2 = 2 * err;
    if (e2 >= ady) {
      err += ady;
      x0 += sx;
    }
    if (e2 <= adx) {
      err += adx;
      y0 += sy;
    }
  }

  return true;
}

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

DistrictState* MegacitySimulation::find_district_mut(DistrictId id) noexcept {
  for (auto& dist : districts_) {
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

    for (auto& syndicate : syndicates_) {
      for (auto& op : syndicate.squad) {
        if (op.occupied_building == building.id &&
            op.current_stratum == Stratum::Spire) {
          op.current_stratum = Stratum::Street;
          op.grid_pos.stratum = Stratum::Street;
        }
      }
    }

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

  if (const auto* traverse = std::get_if<CommandTraverseVerticalShaft>(&cmd)) {
    auto* syn = find_syndicate_mut(traverse->syndicate_id);
    const auto* dist = find_district(traverse->district_id);
    if (syn == nullptr || dist == nullptr ||
        traverse->operative_index >= syn->squad.size()) {
      return false;
    }
    auto& op = syn->squad.at(traverse->operative_index);
    if (!op.alive || !dist->tactical_grid.can_traverse_vertical(
                         op.grid_pos, traverse->target_stratum)) {
      return false;
    }
    op.current_stratum = traverse->target_stratum;
    op.grid_pos.stratum = traverse->target_stratum;
    return true;
  }

  if (const auto* breach = std::get_if<CommandBreachFloorSlab>(&cmd)) {
    auto* dist = find_district_mut(breach->district_id);
    if (dist == nullptr || !dist->tactical_grid.in_bounds(breach->coord) ||
        breach->coord.stratum == Stratum::UnderGrid) {
      return false;
    }
    SectorCell updated = dist->tactical_grid.cell(breach->coord);
    updated.breached = true;
    updated.kind = TileKind::Void;
    dist->tactical_grid.set_cell(breach->coord, updated);

    const Stratum lower_stratum = (breach->coord.stratum == Stratum::Spire)
                                      ? Stratum::Street
                                      : Stratum::UnderGrid;

    for (auto& syn : syndicates_) {
      for (auto& op : syn.squad) {
        if (op.alive && op.grid_pos == breach->coord) {
          op.current_stratum = lower_stratum;
          op.grid_pos.stratum = lower_stratum;
          const int legs_mitigation =
              static_cast<int>(op.organ_tier(OrganSlot::Legs)) * 5;
          op.health = std::max(0, op.health - (30 - legs_mitigation));
          if (op.health == 0) {
            op.alive = false;
          }
        }
      }
    }
    return true;
  }

  if (const auto* fire = std::get_if<CommandFireOrdinance>(&cmd)) {
    const auto* attacker = find_syndicate(fire->attacker_syndicate_id);
    auto* dist = find_district_mut(fire->district_id);
    if (attacker == nullptr || dist == nullptr ||
        fire->operative_index >= attacker->squad.size()) {
      return false;
    }
    const auto& shooter = attacker->squad.at(fire->operative_index);
    if (!shooter.alive || !dist->tactical_grid.in_bounds(fire->target_coord)) {
      return false;
    }

    auto spawn_corpse_drop = [&](SyndicateId owner_id,
                                 const OperativeState& dead_op) {
      std::vector<BlueprintId> drops;
      for (const auto& bp : blueprints_) {
        if (bp.category == BlueprintCategory::CyberneticOrgan &&
            dead_op.organ_tier(bp.organ_slot) == bp.cyber_tier &&
            bp.cyber_tier != CyberTier::V1) {
          drops.push_back(bp.id);
        } else if (bp.category == BlueprintCategory::HeavyOrdinance &&
                   dead_op.primary_weapon == bp.weapon_id) {
          drops.push_back(bp.id);
        }
      }
      if (drops.empty() && !blueprints_.empty()) {
        drops.push_back(blueprints_.front().id);
      }
      dist->corpse_drops.push_back(CorpseHardwareDrop{
          .fallen_operative_id = dead_op.id,
          .original_syndicate_id = owner_id,
          .coord = dead_op.grid_pos,
          .blueprint_ids = std::move(drops),
          .extracted = false,
      });
    };

    if (fire->weapon == WeaponId::SatelliteRain) {
      // Orbital kinetic strike punches vertically from Spire -> Street ->
      // UnderGrid at (target.x, target.y)
      for (const Stratum s :
           {Stratum::Spire, Stratum::Street, Stratum::UnderGrid}) {
        const GridCoord c{fire->target_coord.x, fire->target_coord.y, s};
        SectorCell cell = dist->tactical_grid.cell(c);
        if (cell.building_id != 0) {
          for (auto& bld : buildings_) {
            if (bld.id == cell.building_id) {
              for (auto& story : bld.stories) {
                story.intact_columns = 0;
              }
              propagate_structural_collapse(bld);
            }
          }
        }
        cell.kind =
            (s == Stratum::Spire) ? TileKind::Void : TileKind::RubbleCrater;
        cell.breached = (s != Stratum::UnderGrid);
        dist->tactical_grid.set_cell(c, cell);
      }
      for (auto& syn : syndicates_) {
        for (auto& op : syn.squad) {
          if (op.alive && op.grid_pos.x == fire->target_coord.x &&
              op.grid_pos.y == fire->target_coord.y) {
            op.health = 0;
            op.alive = false;
            spawn_corpse_drop(syn.id, op);
          }
        }
      }
      return true;
    }

    // Gauss / Plasma / Minigun ballistic shot at target_coord
    const SectorCell target_cell = dist->tactical_grid.cell(fire->target_coord);
    if (target_cell.kind == TileKind::OpaqueWall ||
        target_cell.kind == TileKind::CoverPillar) {
      SectorCell destroyed = target_cell;
      destroyed.kind = TileKind::StreetAsphalt;
      dist->tactical_grid.set_cell(fire->target_coord, destroyed);
    }
    if (target_cell.building_id != 0 &&
        (fire->weapon == WeaponId::SuppressedGauss ||
         fire->weapon == WeaponId::PlasmaLance ||
         fire->weapon == WeaponId::ThermiteCharge)) {
      for (auto& bld : buildings_) {
        if (bld.id == target_cell.building_id) {
          for (auto& story : bld.stories) {
            if (story.stratum == fire->target_coord.stratum &&
                story.intact_columns > 0) {
              story.intact_columns -= 1;
            }
          }
          propagate_structural_collapse(bld);
        }
      }
    }

    const int base_damage =
        (fire->weapon == WeaponId::PlasmaLance)
            ? 120
            : (fire->weapon == WeaponId::SuppressedGauss ? 85 : 55);
    for (auto& syn : syndicates_) {
      if (syn.id == fire->attacker_syndicate_id) continue;
      for (auto& op : syn.squad) {
        if (op.alive && op.grid_pos == fire->target_coord) {
          const int chest_armor =
              static_cast<int>(op.organ_tier(OrganSlot::Chest)) * 10;
          op.health =
              std::max(0, op.health - std::max(10, base_damage - chest_armor));
          if (op.health == 0) {
            op.alive = false;
            spawn_corpse_drop(syn.id, op);
          }
        }
      }
    }
    return true;
  }

  if (const auto* extract = std::get_if<CommandExtractCorpseSalvage>(&cmd)) {
    auto* syn = find_syndicate_mut(extract->syndicate_id);
    auto* dist = find_district_mut(extract->district_id);
    if (syn == nullptr || dist == nullptr ||
        extract->operative_index >= syn->squad.size()) {
      return false;
    }
    const auto& extractor = syn->squad.at(extract->operative_index);
    if (!extractor.alive) return false;

    bool any_extracted = false;
    for (auto& drop : dist->corpse_drops) {
      if (!drop.extracted && drop.coord == extractor.grid_pos) {
        drop.extracted = true;
        any_extracted = true;
        for (const BlueprintId bp_id : drop.blueprint_ids) {
          bool merged = false;
          for (auto& unit : syn->cryo_vault_salvage) {
            if (unit.blueprint_id == bp_id) {
              unit.quantity += 1;
              merged = true;
              break;
            }
          }
          if (!merged) {
            syn->cryo_vault_salvage.push_back(SalvagedHardwareUnit{
                .blueprint_id = bp_id,
                .quantity = 1,
            });
          }
        }
      }
    }
    return any_extracted;
  }

  if (const auto* thrall_cmd =
          std::get_if<CommandTriggerThrallDirective>(&cmd)) {
    auto* syn = find_syndicate_mut(thrall_cmd->syndicate_id);
    if (syn == nullptr) return false;

    auto it = std::ranges::find_if(syn->thralls, [&](const PersuadedThrall& t) {
      return t.actor_id == thrall_cmd->actor_id;
    });
    if (it == syn->thralls.end()) return false;

    auto* dist = find_district_mut(it->district_id);
    if (dist == nullptr) return false;

    switch (it->directive) {
      case ThrallDirective::SleeperNode:
        dist->sleeper_vision_syndicate = syn->id;
        return true;
      case ThrallDirective::DeadManBroadcast:
        dist->security_budget =
            (dist->security_budget > 40U) ? (dist->security_budget - 40U) : 0U;
        for (auto& bld : buildings_) {
          if (bld.id == thrall_cmd->target_building_id) {
            for (auto& story : bld.stories) {
              if (story.stratum == Stratum::Street) {
                story.intact_columns = (story.intact_columns > 2U)
                                           ? (story.intact_columns - 2U)
                                           : 0U;
              }
            }
            propagate_structural_collapse(bld);
            break;
          }
        }
        syn->thralls.erase(it);
        return true;
      case ThrallDirective::CrowdSurge:
        dist->crowd_surge_active = true;
        return true;
      case ThrallDirective::Escort: return true;
    }
    return false;
  }

  if (const auto* loot_wreck = std::get_if<CommandLootMonorailWreck>(&cmd)) {
    auto* syn = find_syndicate_mut(loot_wreck->syndicate_id);
    auto* dist = find_district_mut(loot_wreck->district_id);
    if (syn == nullptr || dist == nullptr ||
        loot_wreck->operative_index >= syn->squad.size()) {
      return false;
    }
    const auto& op = syn->squad.at(loot_wreck->operative_index);
    if (!op.alive || op.current_stratum != Stratum::Street ||
        !dist->monorail_wreck_lootable) {
      return false;
    }
    syn->treasury += dist->monorail_vault_loot;
    dist->monorail_vault_loot = 0;
    dist->monorail_wreck_lootable = false;
    if (!blueprints_.empty()) {
      apply_command(CommandSalvageFieldHardware{
          .syndicate_id = syn->id,
          .blueprint_id = blueprints_.back().id,
          .quantity = 1,
      });
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

std::optional<RaidOutcome> MegacitySimulation::step_rival_ai(
    SyndicateId rival_id) {
  auto* rival = find_syndicate_mut(rival_id);
  if (rival == nullptr) return std::nullopt;

  // Priority 1: Rebuild any destroyed City Organ building owned by this rival
  for (const auto& district : districts_) {
    if (district.owner_syndicate != rival_id) continue;
    for (const BuildingId bid : district.buildings) {
      const auto* bld = find_building(bid);
      if (bld != nullptr && bld->houses_city_organ &&
          bld->state == BuildingState::Rubble &&
          rival->treasury >= bld->rebuild_total_cost) {
        apply_command(CommandFundRebuild{
            .syndicate_id = rival_id,
            .building_id = bid,
        });
        break;
      }
    }
  }

  // Priority 2: Ensure an active R&D budget is running on the first locked
  // blueprint if treasury exceeds reserve
  if (!blueprints_.empty() && rival->treasury >= 1500) {
    for (const auto& bp : blueprints_) {
      const bool already_unlocked = std::ranges::any_of(
          rival->research, [&](const ResearchProgress& proj) {
            return proj.blueprint_id == bp.id && proj.unlocked;
          });
      if (!already_unlocked) {
        apply_command(CommandAllocateResearch{
            .syndicate_id = rival_id,
            .blueprint_id = bp.id,
            .daily_budget = 250,
        });
        break;
      }
    }
  }

  // Priority 3: Launch a raid against the weakest non-owned district if squad
  // is healthy
  const DistrictState* best_target = nullptr;
  for (const auto& district : districts_) {
    if (district.owner_syndicate == rival_id) continue;
    if (best_target == nullptr ||
        district.security_budget < best_target->security_budget) {
      best_target = &district;
    }
  }

  if (best_target != nullptr) {
    return resolve_district_raid(rival_id, best_target->id, false);
  }
  return std::nullopt;
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

  DistrictState* target_district = find_district_mut(district_id);
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
  if (target_district->crowd_surge_active) {
    defense_power *= 0.50;
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
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(op.grid_pos.x));
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(op.grid_pos.y));
      hash = fnv1a_mix(hash, static_cast<std::uint64_t>(op.health));
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
    hash = fnv1a_mix(hash, dist.crowd_surge_active ? 1ULL : 0ULL);
    hash = fnv1a_mix(hash, dist.sleeper_vision_syndicate);
    hash = fnv1a_mix(hash, dist.monorail_wreck_lootable ? 1ULL : 0ULL);
  }

  for (const auto& bld : buildings_) {
    hash = fnv1a_mix(hash, bld.id);
    hash = fnv1a_mix(hash, static_cast<std::uint64_t>(bld.state));
    hash = fnv1a_mix(hash, bld.rebuild_ticks_remaining);
  }

  return hash;
}

std::string MegacitySimulation::export_snapshot_json() const {
  std::string out;
  out.reserve(4096);
  out += "{\n";
  out += "  \"schema_version\": 1,\n";
  out += "  \"tick\": " + std::to_string(tick_) + ",\n";
  out += "  \"session_mode\": " + std::to_string(static_cast<unsigned>(mode_)) +
         ",\n";
  out += "  \"tactical_time_scale\": " + std::to_string(tactical_time_scale_) +
         ",\n";
  out +=
      "  \"macro_city_time_scale\": " + std::to_string(macro_city_time_scale_) +
      ",\n";
  out += "  \"state_digest\": \"" + std::to_string(state_digest()) + "\",\n";

  out += "  \"syndicates\": [\n";
  for (std::size_t si = 0; si < syndicates_.size(); ++si) {
    const auto& syn = syndicates_.at(si);
    out += "    {\n";
    out += "      \"id\": " + std::to_string(syn.id) + ",\n";
    out += "      \"name\": \"" + syn.name + "\",\n";
    out += "      \"treasury\": " + std::to_string(syn.treasury) + ",\n";
    out += "      \"thralls_count\": " + std::to_string(syn.thralls.size()) +
           ",\n";
    out += "      \"squad\": [\n";
    for (std::size_t oi = 0; oi < syn.squad.size(); ++oi) {
      const auto& op = syn.squad.at(oi);
      out += "        {\n";
      out += "          \"id\": " + std::to_string(op.id) + ",\n";
      out += "          \"callsign\": \"" + op.callsign + "\",\n";
      out += "          \"stratum\": " +
             std::to_string(static_cast<unsigned>(op.current_stratum)) + ",\n";
      out += "          \"grid_x\": " + std::to_string(op.grid_pos.x) + ",\n";
      out += "          \"grid_y\": " + std::to_string(op.grid_pos.y) + ",\n";
      out += "          \"occupied_building\": " +
             std::to_string(op.occupied_building) + ",\n";
      out += "          \"health\": " + std::to_string(op.health) + ",\n";
      out +=
          "          \"alive\": " + std::string(op.alive ? "true" : "false") +
          ",\n";
      out += "          \"overclock\": " +
             std::to_string(static_cast<unsigned>(op.overclock)) + ",\n";
      out += "          \"medical_status\": " +
             std::to_string(static_cast<unsigned>(op.medical_status)) + "\n";
      out += (oi + 1 < syn.squad.size()) ? "        },\n" : "        }\n";
    }
    out += "      ]\n";
    out += (si + 1 < syndicates_.size()) ? "    },\n" : "    }\n";
  }
  out += "  ],\n";

  out += "  \"districts\": [\n";
  for (std::size_t di = 0; di < districts_.size(); ++di) {
    const auto& dist = districts_.at(di);
    out += "    {\n";
    out += "      \"id\": " + std::to_string(dist.id) + ",\n";
    out += "      \"name\": \"" + dist.name + "\",\n";
    out +=
        "      \"owner_syndicate\": " + std::to_string(dist.owner_syndicate) +
        ",\n";
    out += "      \"organ\": " +
           std::to_string(static_cast<unsigned>(dist.organ)) + ",\n";
    out += "      \"power_blackout\": " +
           std::string(dist.power_blackout ? "true" : "false") + ",\n";
    out += "      \"crowd_surge_active\": " +
           std::string(dist.crowd_surge_active ? "true" : "false") + ",\n";
    out += "      \"sleeper_vision_syndicate\": " +
           std::to_string(dist.sleeper_vision_syndicate) + ",\n";
    out += "      \"monorail_wreck_lootable\": " +
           std::string(dist.monorail_wreck_lootable ? "true" : "false") + ",\n";
    out += "      \"corpse_drops_count\": " +
           std::to_string(dist.corpse_drops.size()) + "\n";
    out += (di + 1 < districts_.size()) ? "    },\n" : "    }\n";
  }
  out += "  ],\n";

  out += "  \"buildings\": [\n";
  for (std::size_t bi = 0; bi < buildings_.size(); ++bi) {
    const auto& bld = buildings_.at(bi);
    out += "    {\n";
    out += "      \"id\": " + std::to_string(bld.id) + ",\n";
    out += "      \"name\": \"" + bld.name + "\",\n";
    out += "      \"district_id\": " + std::to_string(bld.district_id) + ",\n";
    out +=
        "      \"state\": " + std::to_string(static_cast<unsigned>(bld.state)) +
        ",\n";
    out += "      \"rebuild_ticks_remaining\": " +
           std::to_string(bld.rebuild_ticks_remaining) + "\n";
    out += (bi + 1 < buildings_.size()) ? "    },\n" : "    }\n";
  }
  out += "  ]\n";
  out += "}\n";
  return out;
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
                             .grid_pos = {4, 4, Stratum::Spire},
                             .occupied_building = 10},
              OperativeState{.id = 102,
                             .callsign = "VEX-2",
                             .current_stratum = Stratum::Street,
                             .grid_pos = {2, 2, Stratum::Street},
                             .occupied_building = 10},
              OperativeState{.id = 103,
                             .callsign = "NULL-3",
                             .current_stratum = Stratum::Street,
                             .grid_pos = {6, 4, Stratum::Street},
                             .occupied_building = 11},
              OperativeState{.id = 104,
                             .callsign = "CHROME-4",
                             .current_stratum = Stratum::UnderGrid,
                             .grid_pos = {2, 2, Stratum::UnderGrid},
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
                             .grid_pos = {8, 8, Stratum::Street},
                             .occupied_building = 20},
              OperativeState{.id = 202,
                             .callsign = "ONI-2",
                             .current_stratum = Stratum::Street,
                             .grid_pos = {9, 8, Stratum::Street},
                             .occupied_building = 20},
              OperativeState{.id = 203,
                             .callsign = "ONI-3",
                             .current_stratum = Stratum::Spire,
                             .grid_pos = {8, 8, Stratum::Spire},
                             .occupied_building = 21},
              OperativeState{.id = 204,
                             .callsign = "ONI-4",
                             .current_stratum = Stratum::UnderGrid,
                             .grid_pos = {8, 8, Stratum::UnderGrid},
                             .occupied_building = 21},
          },
      .thralls = {},
  };

  sim.add_syndicate(std::move(player));
  sim.add_syndicate(std::move(rival));

  DistrictState kowloon{
      .id = 1,
      .name = "KOWLOON BIO-FOUNDRY SECTOR",
      .owner_syndicate = 1,
      .organ = CityOrgan::BioFoundry,
      .power_blackout = false,
      .monorail_wreck_lootable = false,
      .crowd_surge_active = false,
      .sleeper_vision_syndicate = 0,
      .monorail_vault_loot = 0,
      .security_budget = 120,
      .adjacent_districts = {2, 3},
      .buildings = {},
      .tactical_grid = SectorGrid(16, 16),
      .corpse_drops = {},
  };
  // Populate Kowloon Bio-Foundry 3-stratum vertical connectors and sky-bridge
  for (const Stratum s :
       {Stratum::UnderGrid, Stratum::Street, Stratum::Spire}) {
    kowloon.tactical_grid.set_cell(
        GridCoord{2, 2, s},
        SectorCell{.kind = TileKind::VerticalShaft, .building_id = 10});
  }
  for (std::int32_t x = 3; x <= 8; ++x) {
    kowloon.tactical_grid.set_cell(
        GridCoord{x, 4, Stratum::Spire},
        SectorCell{.kind = TileKind::SpireSkybridge, .building_id = 10});
  }
  kowloon.tactical_grid.set_cell(
      GridCoord{5, 4, Stratum::Street},
      SectorCell{.kind = TileKind::OpaqueWall, .building_id = 10});

  sim.add_district(std::move(kowloon));

  sim.add_district(DistrictState{
      .id = 2,
      .name = "SHINJUKU BROADCAST SPIRE",
      .owner_syndicate = 2,
      .organ = CityOrgan::BroadcastSpire,
      .power_blackout = false,
      .monorail_wreck_lootable = false,
      .crowd_surge_active = false,
      .sleeper_vision_syndicate = 0,
      .monorail_vault_loot = 0,
      .security_budget = 100,
      .adjacent_districts = {1, 3},
      .buildings = {},
      .tactical_grid = SectorGrid(16, 16),
      .corpse_drops = {},
  });

  sim.add_district(DistrictState{
      .id = 3,
      .name = "CHIBA MONORAIL & SUB-GRID",
      .owner_syndicate = 2,
      .organ = CityOrgan::MonorailHub,
      .power_blackout = false,
      .monorail_wreck_lootable = false,
      .crowd_surge_active = false,
      .sleeper_vision_syndicate = 0,
      .monorail_vault_loot = 0,
      .security_budget = 90,
      .adjacent_districts = {1, 2},
      .buildings = {},
      .tactical_grid = SectorGrid(16, 16),
      .corpse_drops = {},
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
