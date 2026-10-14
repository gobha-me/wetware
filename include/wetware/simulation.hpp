#ifndef WETWARE_SIMULATION_HPP
#define WETWARE_SIMULATION_HPP

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace wetware {

using SyndicateId = std::uint32_t;
using DistrictId = std::uint32_t;
using BuildingId = std::uint32_t;
using OperativeId = std::uint32_t;
using BlueprintId = std::uint32_t;
using SimulationTick = std::uint64_t;
using Credits = std::int64_t;

enum class SessionMode : std::uint8_t {
  SinglePlayer = 0,
  MultiplayerTacticalClash = 1,
  MultiplayerMegacityWar = 2,
};

enum class Stratum : std::uint8_t {
  UnderGrid = 0,
  Street = 1,
  Spire = 2,
};

enum class CityOrgan : std::uint8_t {
  None = 0,
  PowerSubGrid = 1,
  BroadcastSpire = 2,
  BioFoundry = 3,
  MonorailHub = 4,
  OrdinanceFoundry = 5,
  Clearinghouse = 6,
};

enum class OrganSlot : std::uint8_t {
  Legs = 0,
  Arms = 1,
  Chest = 2,
  Eyes = 3,
  Brain = 4,
  Heart = 5,
};

enum class CyberTier : std::uint8_t {
  V1 = 1,
  V2 = 2,
  V3 = 3,
  V4 = 4,
};

enum class WeaponId : std::uint8_t {
  Persuadertron = 0,
  SuppressedGauss = 1,
  Minigun = 2,
  ThermiteCharge = 3,
  PlasmaLance = 4,
  SatelliteRain = 5,
};

enum class BlueprintCategory : std::uint8_t {
  CyberneticOrgan = 0,
  HeavyOrdinance = 1,
};

struct TechBlueprint {
  BlueprintId id{0};
  std::string name;
  BlueprintCategory category{BlueprintCategory::CyberneticOrgan};
  OrganSlot organ_slot{OrganSlot::Legs};
  CyberTier cyber_tier{CyberTier::V1};
  WeaponId weapon_id{WeaponId::Persuadertron};
  Credits base_research_cost{1000};
  SimulationTick base_research_ticks{10};
  Credits base_fabrication_cost{500};
};

struct ResearchProgress {
  BlueprintId blueprint_id{0};
  Credits invested_credits{0};
  SimulationTick accrued_ticks{0};
  Credits daily_budget{0};
  bool unlocked{false};
};

struct SalvagedHardwareUnit {
  BlueprintId blueprint_id{0};
  std::uint32_t quantity{0};
};

enum class OverclockState : std::uint8_t {
  Inactive = 0,
  BulletTimeDilation = 1,
  HyperReflexSurge = 2,
};

enum class MedicalStatus : std::uint8_t {
  Nominal = 0,
  CyberPsychosis = 1,
  CardiacFlatline = 2,
};

struct BiochemSliders {
  double intelligence{0.5};
  double perception{0.5};
  double adrenaline{0.5};
};

struct OperativeState {
  OperativeId id{0};
  std::string callsign;
  Stratum current_stratum{Stratum::Street};
  BuildingId occupied_building{0};
  std::array<CyberTier, 6> organs{
      CyberTier::V1, CyberTier::V1, CyberTier::V1,
      CyberTier::V1, CyberTier::V1, CyberTier::V1,
  };
  WeaponId primary_weapon{WeaponId::SuppressedGauss};
  BiochemSliders sliders{};
  double neural_toxicity{0.0};
  double cardiac_strain{0.0};
  OverclockState overclock{OverclockState::Inactive};
  MedicalStatus medical_status{MedicalStatus::Nominal};
  bool alive{true};

  [[nodiscard]] CyberTier organ_tier(OrganSlot slot) const noexcept;
  void set_organ_tier(OrganSlot slot, CyberTier tier) noexcept;
};

enum class BuildingState : std::uint8_t {
  Intact = 0,
  Damaged = 1,
  Rubble = 2,
  Rebuilding = 3,
};

struct StorySegment {
  Stratum stratum{Stratum::Street};
  std::uint32_t story_index{0};
  std::uint32_t intact_columns{4};
  std::uint32_t total_columns{4};
  bool collapsed{false};
};

struct BuildingStructure {
  BuildingId id{0};
  std::string name;
  DistrictId district_id{0};
  bool houses_city_organ{false};
  bool is_skybridge_hub{false};
  Credits base_daily_revenue{500};
  Credits rebuild_total_cost{1200};
  SimulationTick rebuild_total_ticks{6};
  SimulationTick rebuild_ticks_remaining{0};
  BuildingState state{BuildingState::Intact};
  std::vector<StorySegment> stories;
};

enum class PersuadeTargetClass : std::uint8_t {
  Civilian = 0,
  Police = 1,
  CorporateGuard = 2,
  Executive = 3,
  RivalOperative = 4,
};

enum class ThrallDirective : std::uint8_t {
  Escort = 0,
  SleeperNode = 1,
  DeadManBroadcast = 2,
  CrowdSurge = 3,
};

struct PersuadedThrall {
  std::uint32_t actor_id{0};
  PersuadeTargetClass target_class{PersuadeTargetClass::Civilian};
  DistrictId district_id{0};
  Stratum stratum{Stratum::Street};
  ThrallDirective directive{ThrallDirective::Escort};
};

struct DistrictState {
  DistrictId id{0};
  std::string name;
  SyndicateId owner_syndicate{0};
  CityOrgan organ{CityOrgan::None};
  bool power_blackout{false};
  bool monorail_wreck_lootable{false};
  Credits monorail_vault_loot{0};
  std::uint32_t security_budget{100};
  std::vector<DistrictId> adjacent_districts;
  std::vector<BuildingId> buildings;
};

struct SyndicateLedger {
  SyndicateId id{0};
  std::string name;
  Credits treasury{5000};
  std::vector<ResearchProgress> research;
  std::vector<SalvagedHardwareUnit> cryo_vault_salvage;
  std::array<OperativeState, 4> squad{};
  std::vector<PersuadedThrall> thralls;
};

struct RaidOutcome {
  DistrictId district_id{0};
  SyndicateId attacker_id{0};
  SyndicateId defender_id{0};
  bool attacker_won{false};
  bool intercepted_live{false};
  std::uint32_t buildings_collapsed{0};
  Credits loot_credits{0};
};

struct CommandSetBiochem {
  SyndicateId syndicate_id{0};
  std::size_t operative_index{0};
  BiochemSliders sliders{};
};

struct CommandTriggerOverclock {
  SyndicateId syndicate_id{0};
  bool active{true};
};

struct CommandShearColumns {
  BuildingId building_id{0};
  Stratum stratum{Stratum::Street};
  std::uint32_t columns_destroyed{0};
};

struct CommandFundRebuild {
  SyndicateId syndicate_id{0};
  BuildingId building_id{0};
};

struct CommandAllocateResearch {
  SyndicateId syndicate_id{0};
  BlueprintId blueprint_id{0};
  Credits daily_budget{0};
};

struct CommandSalvageFieldHardware {
  SyndicateId syndicate_id{0};
  BlueprintId blueprint_id{0};
  std::uint32_t quantity{1};
};

struct CommandUseSalvage {
  SyndicateId syndicate_id{0};
  BlueprintId blueprint_id{0};
  bool reverse_engineer{false};
  std::size_t operative_index{0};
};

using SimulationCommand =
    std::variant<CommandSetBiochem, CommandTriggerOverclock,
                 CommandShearColumns, CommandFundRebuild,
                 CommandAllocateResearch, CommandSalvageFieldHardware,
                 CommandUseSalvage>;

class MegacitySimulation {
 public:
  explicit MegacitySimulation(SessionMode mode = SessionMode::SinglePlayer,
                              std::uint64_t seed = 0x57455457415245ULL);

  [[nodiscard]] SessionMode session_mode() const noexcept { return mode_; }
  [[nodiscard]] SimulationTick current_tick() const noexcept { return tick_; }
  [[nodiscard]] double tactical_time_scale() const noexcept {
    return tactical_time_scale_;
  }
  [[nodiscard]] double macro_city_time_scale() const noexcept {
    return macro_city_time_scale_;
  }

  void add_blueprint(TechBlueprint blueprint);
  void add_syndicate(SyndicateLedger syndicate);
  void add_district(DistrictState district);
  void add_building(BuildingStructure building);

  [[nodiscard]] const TechBlueprint* find_blueprint(
      BlueprintId id) const noexcept;
  [[nodiscard]] const SyndicateLedger* find_syndicate(
      SyndicateId id) const noexcept;
  [[nodiscard]] SyndicateLedger* find_syndicate_mut(SyndicateId id) noexcept;
  [[nodiscard]] const DistrictState* find_district(
      DistrictId id) const noexcept;
  [[nodiscard]] const BuildingStructure* find_building(
      BuildingId id) const noexcept;

  [[nodiscard]] bool controls_intact_organ(SyndicateId syndicate_id,
                                           CityOrgan organ) const noexcept;

  [[nodiscard]] Credits effective_research_cost(
      SyndicateId syndicate_id, BlueprintId blueprint_id) const noexcept;
  [[nodiscard]] SimulationTick effective_research_ticks(
      SyndicateId syndicate_id, BlueprintId blueprint_id) const noexcept;
  [[nodiscard]] Credits effective_fabrication_cost(
      SyndicateId syndicate_id, BlueprintId blueprint_id) const noexcept;

  [[nodiscard]] Credits calculate_district_daily_revenue(
      DistrictId district_id) const noexcept;
  [[nodiscard]] Credits calculate_syndicate_daily_net(
      SyndicateId syndicate_id) const noexcept;

  bool apply_command(const SimulationCommand& cmd);
  void step_tick();

  bool trigger_power_reroute_blackout(SyndicateId syndicate_id,
                                      DistrictId target_district_id);

  [[nodiscard]] double persuadertron_bandwidth(
      SyndicateId syndicate_id, std::size_t operative_index) const noexcept;
  [[nodiscard]] static double persuade_threshold(
      PersuadeTargetClass target_class) noexcept;

  bool attempt_persuade(SyndicateId syndicate_id, std::size_t operative_index,
                        std::uint32_t actor_id,
                        PersuadeTargetClass target_class,
                        DistrictId district_id, Stratum stratum,
                        ThrallDirective directive = ThrallDirective::Escort);

  RaidOutcome resolve_district_raid(
      SyndicateId attacker_id, DistrictId district_id, bool scorched_earth,
      std::optional<SyndicateId> live_interceptor = std::nullopt);

  [[nodiscard]] std::uint64_t state_digest() const noexcept;
  [[nodiscard]] const std::vector<SimulationCommand>& command_log()
      const noexcept {
    return command_log_;
  }

 private:
  void propagate_structural_collapse(BuildingStructure& building);
  void step_syndicate_biochem(SyndicateLedger& syndicate);
  void step_syndicate_research(SyndicateLedger& syndicate);
  void step_rebuilds();

  SessionMode mode_{SessionMode::SinglePlayer};
  std::uint64_t rng_state_{0x57455457415245ULL};
  SimulationTick tick_{0};
  double tactical_time_scale_{1.0};
  double macro_city_time_scale_{1.0};

  std::vector<TechBlueprint> blueprints_;
  std::vector<SyndicateLedger> syndicates_;
  std::vector<DistrictState> districts_;
  std::vector<BuildingStructure> buildings_;
  std::vector<SimulationCommand> command_log_;
};

MegacitySimulation create_default_vertical_slice(
    SessionMode mode = SessionMode::SinglePlayer);

} // namespace wetware

#endif // WETWARE_SIMULATION_HPP
