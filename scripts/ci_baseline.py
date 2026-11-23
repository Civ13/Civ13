"""Bounded offline CI registry and exact-source execution/aggregate receipts.

Only reviewed, explicitly named unittest files run here. This is neither a native
test launcher nor a claim that source projections establish gameplay acceptance.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
ZERO_BASE = '0' * 40

_skill_spec = importlib.util.spec_from_file_location('ci_skill_prose', Path(__file__).with_name('ci_skill_prose.py'))
_skill_module = importlib.util.module_from_spec(_skill_spec)
_skill_spec.loader.exec_module(_skill_module)
skill_prose = _skill_module.skill_prose


def comparison_module():
    # Ordinary standalone baseline consumers do not need checkout preparation.
    spec = importlib.util.spec_from_file_location('ci_source_comparison', Path(__file__).with_name('ci_checkout_refs.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_toolchain_spec = importlib.util.spec_from_file_location('ci_byond_toolchain', ROOT / 'scripts/byond_toolchain.py')
toolchain = importlib.util.module_from_spec(_toolchain_spec)
_toolchain_spec.loader.exec_module(toolchain)
POLICY_FILES = tuple('tests/' + name for name in (
    'test_ci_selection.py', 'test_ci_regression_policy.py',
    'test_ci_build_prefix.py', 'test_ci_baseline.py', 'test_ci_checkout_refs.py'))
# Review the complete imports/call graph before adding files. No wildcard test
# discovery: test_native.py and newly added runners must never enter implicitly.
SUITES = {
    'npc_friendly_fire_line': {'files': ('tests/getline2/test_friendly_fire.py',),
        'paths': ('tests/getline2/test_friendly_fire.py',), 'shared_paths': (
            'code/game/mob/living/simple_animal/hostile/tactical_ai.dm',
            'code/_helpers/unsorted.dm', 'tests/getline2/test_getline2.py',
            'tests/save_movement/source_adapter.py')},
    'npc_cover_direction': {'files': ('tests/npc_cover/test_direction_projection.py',),
        'paths': ('tests/npc_cover/',),
        'shared_paths': ('code/game/mob/living/simple_animal/hostile/tactical_ai.dm',)},
    'bottle_alcohol_power': {'files': ('tests/bottle_alcohol_power/test_alcohol_power.py',),
        'paths': ('tests/bottle_alcohol_power/', 'code/modules/reagents/reagent_containers/food/drinks/bottle.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'flour_dough': {'files': ('tests/flour_dough/test_dough.py',),
        'paths': ('tests/flour_dough/', 'code/modules/reagents/reagent_containers/food/condiment.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'airstrike_rearm': {'files': ('tests/airstrike_rearm/test_sources.py',),
        'paths': ('tests/airstrike_rearm/', 'code/modules/1713/weapons/zoom.dm', 'code/_helpers/global_lists.dm')},
    'getline2_contract': {'files': ('tests/getline2/test_getline2.py',),
        'paths': ('tests/getline2/',),
        'shared_paths': ('code/_helpers/unsorted.dm', 'tests/save_movement/source_adapter.py')},
    # Stdlib-only: civ13.dme compiles in its own order and Dream Maker's sorted one.
    'dme_order': {'files': ('tests/dme_order/test_define_order.py',), 'paths': ('tests/dme_order/',),
        'shared_paths': ('civ13.dme',)},
    'object_interval_dispatch': {'files': ('tests/process_time/test_dispatch_source.py',),
        'paths': ('tests/process_time/', 'code/processes/obj.dm', 'code/processes/_process.dm')},
    'abandonment_protection': {'files': (
        'tests/abandoned_items/test_protection.py', 'tests/abandoned_items/test_manure_ground_clock.py',
        'tests/food_progression/test_fertilizer_no_decay.py'),
        'paths': ('tests/abandoned_items/test_protection.py', 'tests/abandoned_items/test_manure_ground_clock.py',
                  'tests/food_progression/test_fertilizer_no_decay.py'),
        'shared_paths': ('code/processes/abandoned_items.dm', 'tests/save_movement/source_adapter.py',
                         'code/game/mob/living/carbon/human/shit_piss.dm',
                         'code/game/mob/living/simple_animal/simple_ai.dm', 'code/game/mob/living/simple_animal/simple_animal.dm',
                         'code/modules/reagents/reagent_containers/food.dm')},
    'astar_current_score': {'files': ('tests/astar_current_score/test_score.py',),
        'paths': ('tests/astar_current_score/', 'code/pathfinding.dm')},
    'bag_valve_mask': {'files': ('tests/bag_valve_mask/test_bag_valve_mask.py',), 'paths': (
        'tests/bag_valve_mask/',), 'shared_paths': (
        'code/game/objects/items/stacks/medical.dm',)},
    # Stdlib-only source projection: directional flooding order and callback traces.
    'flooding_directions': {'files': ('tests/flooding_directions/test_directions.py',),
        'paths': ('tests/flooding_directions/', 'code/modules/submarine/flooding_controller.dm')},
    'gas_skin_burns': {'files': ('tests/gas_skin_burns/test_gas_skin_burns.py',), 'paths': (
        'tests/gas_skin_burns/',), 'shared_paths': (
        'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Gases.dm',)},
    'pulled_punches': {'files': ('tests/pulled_punches/test_pulled_punches.py',), 'paths': (
        'tests/pulled_punches/',), 'shared_paths': (
        'code/game/mob/living/carbon/human/human_attackhand.dm',
        'code/game/mob/living/carbon/human/unarmed_attack.dm')},
    # Stdlib-only: compost bins keep their stock through a save of a running world (#5292).
    'compost_save': {'files': ('tests/compost_save/test_compost_save.py',), 'paths': (
        'tests/compost_save/',), 'shared_paths': ('code/modules/1713/production.dm',)},
    # Stdlib-only: poisonous frog meat coats crossbow bolts as well as arrows (#5258).
    'poison_frog_bolts': {'files': ('tests/poison_frog_bolts/test_bolts.py',), 'paths': (
        'tests/poison_frog_bolts/',), 'shared_paths': (
        'code/modules/reagents/reagent_containers/food/snacks/meat.dm',)},
    # Issue 5126: casings, specimens, organ spoiling, transplant guard, catgut.
    'intestine_casings': {'files': ('tests/organ_utilities/test_casings.py',
        'tests/organ_utilities/test_organ_uses.py'),
        'paths': ('tests/organ_utilities/', 'code/modules/organs/organ_uses.dm'),
        'shared_paths': ('code/modules/1713/animal_harvest.dm', 'scripts/atlas/catalog_metadata.py',
            'code/modules/organs/organ.dm', 'code/modules/surgery/organs_internal.dm',
            'code/modules/research_tree/naturalist_finds.dm')},
    'vehicle_level_shift': {'files': ('tests/vehicle_level_shift/test_shift.py',),
        'paths': ('tests/vehicle_level_shift/',
                  'code/modules/1713/machinery/modular_vehicles/axis.dm',
                  'code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm',
                  'code/modules/1713/machinery/modular_vehicles/ships/submarine.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'gaia_weather': {'files': ('tests/gaia_weather/test_frequency.py',),
        'paths': ('tests/gaia_weather/',), 'shared_paths': (
            'code/game/objects/map_metadata/nomads/nomads_gaia.dm',
            'code/modules/1713/weather_policy.dm', 'code/modules/1713/weather.dm',
            'code/__defines/weather.dm', 'tests/weather_policy/test_policy.py')},
    'biofuel_capacity': {'files': ('tests/biofuel_capacity/test_output.py',),
        'paths': ('tests/biofuel_capacity/',),
        'shared_paths': ('code/modules/1713/modern_items.dm', 'tests/save_movement/source_adapter.py')},
    'drying_rack_batches': {'files': ('tests/drying_rack_batches/test_rack.py',),
        'paths': ('tests/drying_rack_batches/', 'code/modules/1713/complex_production.dm')},
    'meat_grinder_crank': {'files': ('tests/meat_grinder_crank/test_crank.py',),
        'paths': ('tests/meat_grinder_crank/', 'code/modules/1713/complex_production.dm')},
    'reactor_coolant_seal': {'files': ('tests/reactor_coolant_seal/test_seal.py',),
        'paths': ('tests/reactor_coolant_seal/', 'code/modules/1713/machinery/nuclear_generation.dm')},
    'hand_mill_workers': {'files': ('tests/hand_mill_workers/test_workers.py',),
        'paths': ('tests/hand_mill_workers/',),
        'shared_paths': ('code/modules/1713/production.dm',)},
    # Offline source projection; the shared animal source retains conservative fallback.
    'frog_breeding_count': {'files': ('tests/frog_breeding_count/test_source.py',),
        'paths': ('tests/frog_breeding_count/',),
        'shared_paths': ('tests/save_movement/source_adapter.py', 'code/game/mob/living/simple_animal/friendly/lizard.dm')},
    'chemsmoke_initial_splash': {'files': ('tests/chemsmoke_initial_splash/test_initial_splash.py',),
        'paths': ('tests/chemsmoke_initial_splash/', 'tests/save_movement/source_adapter.py', 'code/game/objects/effects/chem/chemsmoke.dm', 'code/game/objects/effects/effect_system.dm')},
    'bayonet_mouth': {'files': ('tests/bayonet_mouth/test_sources.py',),
        'paths': ('tests/bayonet_mouth/', 'code/modules/projectiles/gun.dm')},
    'suit_patch_wait': {'files': ('tests/suit_patch_wait/test_sources.py',),
        'paths': ('tests/suit_patch_wait/', 'code/modules/space/pressure_suits.dm')},
    'boltaction_jam': {'files': ('tests/boltaction_jam/test_sources.py',),
        'paths': ('tests/boltaction_jam/', 'code/modules/1713/weapons/guns/bolt-action.dm')},
    'bone_setting_race': {'files': ('tests/bone_setting_race/test_sources.py',),
        'paths': ('tests/bone_setting_race/', 'code/modules/surgery/bones.dm', 'code/modules/organs/organ_external.dm')},
    'leech_wait': {'files': ('tests/leech_wait/test_sources.py',),
        'paths': ('tests/leech_wait/', 'code/game/mob/living/simple_animal/friendly/leech.dm')},
    'sheep_lambs': {'files': ('tests/sheep_lambs/test_sources.py',),
        'paths': ('tests/sheep_lambs/', 'code/game/mob/living/simple_animal/friendly/farm_animals.dm')},
    'vomit_cooldown': {'files': ('tests/vomit_cooldown/test_source.py',), 'paths': ('tests/vomit_cooldown/',),
        'shared_paths': ('code/game/mob/living/carbon/carbon_defines.dm',)},
    'meat_slicing': {'files': ('tests/meat_slicing/test_source.py',), 'paths': ('tests/meat_slicing/',),
        'shared_paths': ('code/modules/reagents/reagent_containers/food/snacks/meat.dm', 'code/modules/reagents/reagent_containers/food/snacks.dm')},
    'wolf_cubs': {'files': ('tests/wolf_cubs/test_sources.py',), 'paths': ('tests/wolf_cubs/',),
        'shared_paths': ('code/game/mob/living/simple_animal/hostile/wolf.dm',)},
    'animal_medical': {'files': ('tests/animal_medical/test_source.py',),
        'paths': ('tests/animal_medical/',),
        'shared_paths': ('code/game/mob/living/simple_animal/simple_animal.dm',
            'code/game/mob/living/simple_animal/hostile/commanded/kenobi.dm',
            'code/game/objects/structures/converters.dm')},
    'potted_cinchona': {'files': ('tests/potted_cinchona/test_source.py',),
        'paths': ('tests/potted_cinchona/',),
        'shared_paths': ('code/game/objects/structures/plant_pots.dm',)},
    'money_printer_payout': {'files': ('tests/money_printer_payout/test_source.py',),
        'paths': ('tests/money_printer_payout/',),
        'shared_paths': ('code/modules/1713/fiatcurrency.dm',
            'code/modules/1713/complex_production.dm')},
    'taser_dart': {'files': ('tests/taser_dart/test_source.py',),
        'paths': ('tests/taser_dart/',),
        'shared_paths': ('code/modules/projectiles/projectile.dm',
            'code/game/mob/living/living_defense.dm')},
    'incision_clamp': {'files': ('tests/incision_clamp/test_source.py',),
        'paths': ('tests/incision_clamp/',),
        'shared_paths': ('code/modules/organs/organ_external.dm',)},
    'chemsmoke_exclusion': {'files': ('tests/chemsmoke_exclusion/test_guard.py',),
        'paths': ('tests/chemsmoke_exclusion/', 'code/game/objects/effects/chem/chemsmoke.dm', 'code/game/objects/effects/chem/chemsmoke_types.dm')},
    'scheduled_task_guard': {'files': ('tests/scheduled_task_guard/test_guard.py',), 'paths': ('tests/scheduled_task_guard/', 'code/processes/scheduler.dm', 'code/__defines/qdel.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'cleanables_scheduler': {'files': ('tests/cleanables_scheduler/test_resume.py',),
        'paths': ('tests/cleanables_scheduler/', 'code/processes/cleanables.dm'),
        'shared_paths': ('code/processes/_process.dm', 'code/processes/___defines.dm', 'code/_macros.dm')},
    'time_tracking': {'files': ('tests/time_tracking/test_time_tracking.py',),
        'paths': ('tests/time_tracking/', 'code/processes/time_track.dm')},
    'life_tick_pacing': {'files': ('tests/life_tick_pacing/test_pacing.py',),
        'paths': ('tests/life_tick_pacing/',), 'shared_paths': (
            'code/processes/_process.dm', 'code/processes/__processScheduler.dm',
            'code/modules/organs/organ.dm', 'code/modules/organs/blood.dm',
            'code/game/mob/living/carbon/human/human_organs.dm',
            'code/game/mob/living/carbon/human/human.dm',
            'code/modules/1713/weapons/guns/mg/_stationary.dm', 'code/modules/1713/weather.dm',
            'code/modules/1713/rain_gear.dm', 'code/modules/organs/organ_external.dm',
            'code/game/mob/living/carbon/human/update_icons.dm',
            'code/game/mob/living/carbon/human/human_helpers.dm',
            'code/game/mob/living/carbon/human/human_needs.dm',
            'code/game/mob/living/carbon/human/human_damage.dm',
            'code/game/objects/structures/animalspawner/bearcave.dm', 'code/global.dm',
            'code/modules/ecology/ecology_spawning.dm', 'code/processes/mob.dm',
            'code/game/mob/living/simple_animal/simple_animal.dm')},
    'gladiator_stat_record': {'files': ('tests/gladiator_stat_record/test_record.py',),
        'paths': ('tests/gladiator_stat_record/', 'code/game/objects/structures/gladiator_control.dm')},
    'cooling_fan': {'files': ('tests/cooling_fan/test_fan_desc.py', 'tests/cooling_fan/test_appliance_dismantling.py'),
        'paths': ('tests/cooling_fan/', 'code/game/objects/structures/appliances.dm'),
        'shared_paths': ('code/game/objects/items/weapons/tools.dm',)},
    'landing_craft': {'files': ('tests/landing_craft/test_lever.py',),
        'paths': ('tests/landing_craft/', 'code/modules/1713/transporter/lever.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'dressmaking': {'files': ('tests/dressmaking/test_source.py',),
        'paths': ('tests/dressmaking/', 'tests/crafting/dressmaking.dm', 'code/modules/1713/dressmaking.dm',
                  'scripts/atlas/dressmaking.py'),
        'shared_paths': ('tests/save_movement/source_adapter.py',
                         'code/game/mob/living/carbon/human/update_icons.dm',
                         'config/crafting/material_recipes_global.txt',
                         'code/modules/research_tree/research_node.dm',
                         'scripts/check-recipes.py')},
    'atgm_retrieve': {'files': ('tests/atgm_retrieve/test_retrieve.py',),
        'paths': ('tests/atgm_retrieve/', 'code/modules/1713/weapons/guns/mg/stationary/mg.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'flare_snuff': {'files': ('tests/flare_snuff/test_snuff.py',),
        'paths': ('tests/flare_snuff/', 'code/game/objects/items/devices/flashlight.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'dumpster_rummage': {'files': ('tests/dumpster_rummage/test_rummage.py',),
        'paths': ('tests/dumpster_rummage/', 'code/game/objects/structures/crates_lockers/crates.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'game_clock': {'files': ('tests/game_clock/test_clock.py',),
        'paths': ('tests/game_clock/', 'code/__defines/time_of_day.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'fishing_cage_restore': {'files': ('tests/fishing_cage/test_restore.py',),
        'paths': ('tests/fishing_cage/', 'code/game/objects/structures/sea.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',
                         'code/modules/persistence/functions.dm',
                         'code/modules/persistence/loading.dm',
                         'code/modules/persistence/restore_contract.dm')},
    'toolbox_cables': {'files': ('tests/toolbox_cables/test_electrical.py',),
        'paths': ('tests/toolbox_cables/', 'code/game/objects/items/weapons/storage/toolbox.dm'),
        'shared_paths': ('code/modules/1713/machinery/cables_types.dm',
                         'code/game/objects/items/stacks/stack.dm')},
    'admin_send_mob': {'files': ('tests/admin_send_mob/test_send_mob.py',),
        'paths': ('tests/admin_send_mob/', 'code/modules/admin/verbs/adminjump.dm'),
        'shared_paths': ('code/_helpers/areas.dm', 'tests/save_movement/source_adapter.py')},
    'boiling_oil_splash': {'files': ('tests/boiling_oil/test_splash_icon.py',),
        'paths': ('tests/boiling_oil/', 'code/modules/1713/siege/boiling_oil.dm')},
    'pemmican_lid': {'files': ('tests/pemmican_lid/test_lid.py',),
        'paths': ('tests/pemmican_lid/', 'code/modules/1713/complex_production.dm')},
    'appearance_genders': {'files': ('tests/appearance_genders/test_genders.py',),
        'paths': ('tests/appearance_genders/', 'code/modules/nano/modules/appearance_changer.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/species/species.dm',
                         'tgui/src/interfaces/Standard.tsx')},
    'reaction_priority_empty': {'files': ('tests/reaction_priority/test_priority.py',),
        'paths': ('tests/reaction_priority/',), 'shared_paths': (
            'code/modules/reagents/Chemistry-Holder.dm', 'tests/save_movement/source_adapter.py')},
    'reagent_metabolism_empty': {'files': ('tests/reagent_metabolism/test_empty.py',),
        'paths': ('tests/reagent_metabolism/',), 'shared_paths': (
            'code/modules/reagents/Chemistry-Metabolism.dm',
            'code/modules/reagents/Chemistry-Holder.dm', 'tests/save_movement/source_adapter.py')},
    'chem_dispenser_refill': {'files': ('tests/chem_dispenser_refill/test_refill.py',),
        'paths': ('tests/chem_dispenser_refill/',),
        'shared_paths': ('code/modules/reagents/Chemistry-Machinery.dm',)},
    'warehouse_book': {'files': ('tests/warehouse_book/test_inventory.py',),
        'paths': ('tests/warehouse_book/',),
        'shared_paths': ('code/game/objects/map_metadata/pepelsibirsk.dm',)},
    'noticeboard_remove': {'files': ('tests/noticeboard_remove/test_remove.py',),
        'paths': ('tests/noticeboard_remove/',),
        'shared_paths': ('code/game/objects/structures/noticeboard.dm',)},
    'faction_banner_load': {'files': ('tests/faction_banner_load/test_source.py',),
        'paths': ('tests/faction_banner_load/',), 'shared_paths': (
            'code/game/mob/groups/factions.dm', 'code/game/mob/groups/religions.dm')},
    'moldy_sabotage': {'files': ('tests/moldy_sabotage/test_school_property.py',),
        'paths': ('tests/moldy_sabotage/', 'code/modules/1713/moldy_men/moldy_men_hooks.dm'),
        'shared_paths': ('code/game/objects/structures.dm',
                         'code/game/objects/map_metadata/wizard_boy.dm')},
    'cooking_pot_pour': {'files': ('tests/cooking_pot_pour/test_pour.py',),
        'paths': ('tests/cooking_pot_pour/',),
        'shared_paths': ('code/game/objects/structures/kitchen/pot.dm',)},
    'old_coffin_verb': {'files': ('tests/old_coffin_verb/test_verb.py',),
        'paths': ('tests/old_coffin_verb/',),
        'shared_paths': ('code/game/objects/structures/crates_lockers/closets.dm',)},
    'constrictor_death': {'files': ('tests/constrictor_death/test_constrictor_death.py',),
        'paths': ('tests/constrictor_death/', 'code/game/mob/living/simple_animal/hostile/snake.dm')},
    'wet_floor_slip': {'files': ('tests/wet_floor_slip/test_wet_floor_slip.py',),
        'paths': ('tests/wet_floor_slip/',),
        'shared_paths': ('code/game/mob/living/carbon/human/human.dm', 'code/game/mob/living/carbon/carbon.dm', 'code/game/turfs/turf.dm')},
    'snow_feet': {'files': ('tests/snow_feet/test_snow_feet.py',),
        'paths': ('tests/snow_feet/',),
        'shared_paths': ('code/game/mob/living/carbon/human/species/species.dm',)},
    'oil_spring': {'files': ('tests/oil_spring/test_oil_spring.py',),
        'paths': ('tests/oil_spring/', 'code/modules/1713/oil_fires.dm')},
    'boat_corpse_sink': {'files': ('tests/boat_corpse_sink/test_boat_corpse_sink.py',),
        'paths': ('tests/boat_corpse_sink/',),
        'shared_paths': ('code/game/turfs/floor_types.dm',)},
    'steam_engine_callbacks': {'files': ('tests/steam_engine_callbacks/test_engine_callbacks.py',),
        'paths': ('tests/steam_engine_callbacks/', 'code/modules/1713/machinery/engines/external_combustion.dm')},
    'conveyor_sync': {'files': ('tests/conveyor_sync/test_sync.py',),
        'paths': ('tests/conveyor_sync/', 'code/modules/1713/machinery/conveyor2.dm', 'code/modules/1713/hydroponics.dm')},
    'medical_side_effects': {'files': ('tests/medical_side_effects/test_registration.py',),
        'paths': ('tests/medical_side_effects/', 'code/game/mob/living/carbon/human/MedicalSideEffects.dm')},
    'biofuel_feed': {'files': ('tests/biofuel_feed/test_feed.py',),
        'paths': ('tests/biofuel_feed/',),
        'shared_paths': ('code/modules/1713/modern_items.dm',)},
    'starter_jar_load': {'files': ('tests/starter_jar_load/test_resume.py',),
        'paths': ('tests/starter_jar_load/',),
        'shared_paths': ('code/modules/1713/production.dm',)},
    'geiger_counter': {'files': ('tests/geiger_counter/test_geiger.py',),
        'paths': ('tests/geiger_counter/',),
        'shared_paths': ('code/modules/1713/radiation.dm',)},
    'press_anchoring': {'files': ('tests/press_anchoring/test_anchoring.py',),
        'paths': ('tests/press_anchoring/',),
        'shared_paths': ('code/modules/1713/factory_packaging.dm', 'tests/primitive_woodworking/source_adapter.py')},
    'splash_watering': {'files': ('tests/splash_watering/test_splash.py',),
        'paths': ('tests/splash_watering/',),
        'shared_paths': ('code/modules/reagents/Chemistry-Holder.dm', 'tests/primitive_woodworking/source_adapter.py')},
    # Leader orders: a weaker order never extends a stronger one (#5488).
    'leader_orders': {'files': ('tests/leader_orders/test_order_expiry.py',), 'paths': (
        'tests/leader_orders/', 'code/modules/1713/leader_orders.dm')},
    # Grenade launchers only finish loading within reach (#5526).
    'grenade_launcher_reach': {'files': ('tests/grenade_launcher_reach/test_reach.py',), 'paths': (
        'tests/grenade_launcher_reach/', 'code/modules/1713/weapons/guns/grenade_launcher.dm')},
    'matchbox_pickup': {'files': ('tests/matchbox/test_pickup.py',),
        'paths': ('tests/matchbox/',),
        'shared_paths': ('code/game/objects/items/weapons/storage/boxes.dm',
                         'tests/save_movement/source_adapter.py')},
    'cavity_surgery': {'files': ('tests/cavity_surgery/test_cavity.py',),
        'paths': ('tests/cavity_surgery/', 'code/modules/surgery/implant.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'double_holster_draw': {'files': ('tests/double_holster/test_draw.py',),
        'paths': ('tests/double_holster/', 'code/game/objects/items/clothing/under/accessories/holster.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'barricade_projectile': {'files': ('tests/barricade_projectile/test_canpass.py',),
        'paths': ('tests/barricade_projectile/', 'code/game/objects/structures/barricades.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'window_frames': {'files': ('tests/window_frames/test_window_frames.py',),
        'paths': ('tests/window_frames/', 'code/game/objects/structures/window.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'wood_ash_collection': {'files': ('tests/wood_ash_collection/test_collection.py',),
        'paths': ('tests/wood_ash_collection/', 'code/game/objects/items/misc.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'edge_climbing': {'files': ('tests/edge_climbing/test_sources.py',), 'paths': ('tests/edge_climbing/', 'code/modules/multiz/edge_climbing.dm'), 'shared_paths': ('code/modules/multiz/pit_climbing.dm', 'code/modules/multiz/open_space.dm', 'code/game/objects/building_levels.dm', 'code/game/turfs/turf.dm', 'code/_onclick/other_mobs.dm', 'code/game/objects/structures/tree_climbing.dm')},
    'open_air_view': {'files': ('tests/open_air_view/test_sources.py',), 'paths': ('tests/open_air_view/', 'code/modules/multiz/open_air_view.dm', 'code/modules/multiz/look_up.dm', 'code/processes/open_air_view.dm'), 'shared_paths': ('code/game/objects/building_levels.dm', 'code/modules/multiz/building_lighting.dm', 'code/game/mob/mob_movement.dm', 'code/_onclick/hud/updown_buttons.dm')},
    'burial': {'files': ('tests/burial/test_burial.py',), 'paths': ('tests/burial/', 'code/modules/1713/burial.dm', 'code/game/objects/structures/religious.dm'), 'shared_paths': ('code/game/mob/living/carbon/human/human_life.dm', 'code/game/mob/living/carbon/resist.dm')},
    'underground_excavation': {'files': ('tests/underground_excavation/test_underground_excavation.py',), 'paths': ('tests/underground_excavation/', 'code/modules/1713/underground_excavation.dm'), 'shared_paths': ('code/modules/multiz/structures.dm', 'code/modules/multiz/hole_ladder.dm', 'code/modules/1713/flood_cellars.dm')},
    'work_speed': {'files': ('tests/work_speed/test_work_speed.py',), 'paths': ('tests/work_speed/', 'code/modules/materials/work_speed.dm', 'code/__defines/tools.dm', 'code/modules/1713/earthworking_tools.dm'), 'shared_paths': ('code/game/turfs/floor_attackby.dm', 'code/modules/1713/trench.dm', 'code/modules/1713/tools.dm', 'code/modules/1713/sewers.dm', 'code/modules/1713/underground_excavation.dm', 'code/modules/1713/dug_wells.dm', 'code/modules/1713/road_tamping.dm', 'code/modules/1713/stone_age_storage.dm', 'code/modules/1713/placer.dm', 'code/modules/1713/open_cave_roof.dm', 'code/modules/1713/mountain_seams.dm', 'code/modules/provinces/province_rich.dm', 'code/game/objects/structures/wild.dm', 'code/game/objects/covers_types/cover_roads.dm', 'code/modules/multiz/dug_underground.dm')},
    'earthworking': {'files': ('tests/earthworking/test_sources.py',), 'paths': ('tests/earthworking/', 'code/modules/1713/earthworking_heavy.dm', 'tests/sprites/create_earthworking_tools.py', 'icons/obj/earthworking_tools.dmi', 'icons/mob/items/lefthand_earthworking.dmi', 'icons/mob/items/righthand_earthworking.dmi'), 'shared_paths': ('code/modules/1713/earthworks.dm', 'code/modules/1713/road_tamping.dm', 'config/crafting/material_recipes_global.txt')},
    'open_cave_roof': {'files': ('tests/open_cave_roof/test_open_cave_roof.py',), 'paths': ('tests/open_cave_roof/', 'code/modules/1713/open_cave_roof.dm', 'docs/open-cave-roof.md'), 'shared_paths': ('code/game/turfs/floor_attackby.dm',)},
    'mine_floor_registry': {'files': ('tests/mine_floor_registry/test_mine_floor_registry.py',), 'paths': ('tests/mine_floor_registry/', 'code/modules/multiz/mine_floor_registry.dm', 'code/__defines/mine_registry.dm')},
    'pit_climbing': {'files': ('tests/pit_climbing/test_pit_climbing.py',), 'paths': ('tests/pit_climbing/', 'code/modules/multiz/pit_climbing.dm', 'code/modules/multiz/hole_ladder.dm'), 'shared_paths': ('code/modules/multiz/dug_underground.dm', 'code/modules/1713/tools.dm', 'code/game/turfs/floor_attackby.dm')},
    'physical_interaction': {'files': ('tests/physical_interaction/test_touch.py',),
        'paths': ('tests/physical_interaction/',),
        'shared_paths': ('code/game/objects/objs.dm', 'code/game/objects/structures.dm',
                         'code/modules/1713/weapons/guns/mg/_stationary.dm',
                         'tests/save_movement/source_adapter.py')},
    'cable_neighbors': {'files': ('tests/power/test_neighbor_linking.py',),
        'paths': ('tests/power/test_neighbor_linking.py', 'tests/power/fixture.dm', 'scripts/test-power.ps1'),
        'shared_paths': ('code/modules/1713/smart_home.dm', 'code/modules/1713/machinery/cables.dm',
                         'code/modules/1713/machinery/cables_types.dm',
                         'code/game/objects/structures.dm')},
    'beekeeping_wait': {'files': ('tests/test_beekeeping_wait.py',),
        'paths': ('tests/test_beekeeping_wait.py', 'tests/beekeeping/',
                  'code/modules/1713/beekeeping.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py', 'code/_helpers/mobs.dm',
                         'code/_onclick/adjacent.dm', 'code/processes/garbage.dm')},
    'light_fuel': {'files': ('tests/test_light_fuel.py',),
        'paths': ('tests/test_light_fuel.py', 'code/modules/1713/lantern.dm',
                  'code/modules/1713/light_fuel.dm', 'code/game/objects/items/devices/flashlight.dm',
                  'code/game/objects/items/weapons/cigs_lighters.dm', 'code/modules/1713/telephone.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py', 'config/crafting/',
                         'code/modules/research_tree/research_node.dm',
            'code/modules/research_tree/book_pages.dm')},
    'cave_dismantling': {'files': ('tests/cave_dismantling/test_dismantling.py',),
        'paths': ('tests/cave_dismantling/', 'code/game/objects/structures/animalspawner/animal_spawner.dm',
                  'code/game/objects/structures/animalspawner/bearcave.dm',
                  'code/game/objects/structures/animalspawner/wolfcave.dm')},
    'shield_block': {'files': ('tests/shield_block/test_block.py',),
        'paths': ('tests/shield_block/', 'code/game/objects/items/weapons/shields.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'shove': {'files': ('tests/shove/test_shove.py',), 'paths': ('tests/shove/',),
        'shared_paths': ('code/game/mob/living/carbon/human/human_attackhand.dm',
                         'code/game/mob/living/carbon/human/subtile_movement.dm',
                         'code/game/mob/living/living.dm', 'tests/save_movement/source_adapter.py')},
    'stethoscope_examination': {'files': ('tests/stethoscope/test_examination.py',),
        'paths': ('tests/stethoscope/', 'code/game/objects/items/clothing/under/accessories/stethoscope.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'prosthesis_attachment': {'files': ('tests/prosthesis/test_attachment.py',),
        'paths': ('tests/prosthesis/', 'code/modules/surgery/prosthesis.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'sword_sheaths': {'files': ('tests/sword_sheaths/test_unlock.py',),
        # material_recipes_global.txt and research_node.dm already select every suite.
        'paths': ('tests/sword_sheaths/', 'code/modules/research_tree/book_research.dm',
                  'code/modules/research_tree/research_bench.dm',
                  'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm')},
    'katana_sheath': {'files': ('tests/katana_sheath/test_sheath.py',),
        'paths': ('tests/katana_sheath/', 'code/game/objects/items/clothing/under/accessories/sheaths.dm',
                  'code/game/objects/items/clothing/under/accessories/storage.dm',
                  'code/modules/1713/jobs/japanese.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'firearm_inventory': {'files': ('tests/firearm_inventory/test_inventory.py',),
        'paths': ('tests/firearm_inventory/', 'scripts/firearm_inventory.py',
                  'docs/firearm-migration-inventory.md')},
    # Gun coverage manifest (issue #4443); run.py regenerates it with BYOND.
    'firearm_coverage': {'files': ('tests/firearm_coverage/test_coverage.py',),
        'paths': ('tests/firearm_coverage/', 'docs/firearm-coverage.json', 'code/modules/projectiles/',
                  'code/modules/1713/weapons/', 'code/modules/1713/gunsmithing/')},
    # Handloading table covers every modern caliber; the native probe is tests/handloading/run.py.
    'handloading': {'files': ('tests/handloading/test_coverage.py',),
        'paths': ('tests/handloading/', 'docs/firearm-coverage.json', 'code/modules/projectiles/handloading.dm',
                  'code/modules/projectiles/_ammo_casing.dm')},
    # Self-loading guns and cased shells drop brass; the native probe is tests/casing_ejection/run.py.
    'casing_ejection': {'files': ('tests/casing_ejection/test_sources.py',),
        'paths': ('tests/casing_ejection/', 'code/modules/projectiles/guns/projectile.dm',
                  'code/modules/1713/siege/piece.dm', 'code/__defines/gun.dm',
                  'code/game/objects/items/item_heaps.dm', 'code/modules/projectiles/ammunition.dm',
                  'code/game/objects/items.dm')},
    'septim_appearance': {'files': ('tests/septim_appearance/test_appearance.py',),
        'paths': ('tests/septim_appearance/', 'code/game/objects/items/stacks/money.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    # Offline fixture composition only; this suite does not launch BYOND.
    'fixture_source_projection': {'files': ('tests/fixture_source_projection/test_projection.py',),
        'paths': ('tests/fixture_source_projection/', 'scripts/fixture_source_projection.py',
                  'tests/processing_list_removal/', 'scripts/processing_list_projection.py') +
            tuple(f'tests/{name}/run.py' for name in (
                'faction_membership', 'faction_recruitment', 'research_persistence')),
        'shared_paths': (
            'code/__defines/subsystem.dm',
            'tests/faction_membership/probe.dm', 'tests/faction_recruitment/probe.dm',
            'tests/research_persistence/probe.dm', 'code/game/mob/groups/faction_membership.dm',
            'code/game/mob/groups/faction_recruitment.dm', 'code/game/mob/groups/faction_rename.dm',
            'code/game/mob/groups/factions.dm', 'code/game/objects/structures/stool_bed_chair_nest/bed.dm', 'code/modules/research_tree/research_faction.dm',
            'code/modules/research_tree/_research_tree_defines.dm',
            'code/modules/research_tree/research_node.dm', 'code/game/objects/map_metadata/_map_metadata.dm')},
    'paper_bin_appearance': {'files': ('tests/paper_bin_appearance/test_appearance.py',),
        'paths': ('tests/paper_bin_appearance/', 'code/game/objects/items/bin.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'fridge_wrench': {'files': ('tests/fridge_wrench/test_fridge_wrench.py',),
        'paths': ('tests/fridge_wrench/', 'code/game/objects/structures/crates_lockers/closets/fridge.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'earmuff_muffling': {'files': ('tests/earmuff_muffling/test_earmuff_muffling.py',),
        'paths': ('tests/earmuff_muffling/',),
        'shared_paths': ('code/game/mob/living/life.dm',
                         'code/game/mob/living/carbon/human/human_life.dm',
                         'tests/save_movement/source_adapter.py')},
    'flashbang_audio': {'files': ('tests/flashbang_audio/test_audio.py',),
        'paths': ('tests/flashbang_audio/', 'code/game/objects/items/weapons/grenades/flashbang.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'egg_box_count': {'files': ('tests/egg_box_count/test_egg_box_count.py',),
        'paths': ('tests/egg_box_count/',),
        'shared_paths': ('code/game/objects/items/weapons/storage/fancy.dm',
                         'tests/save_movement/source_adapter.py')},
    'donut_box_empty': {'files': ('tests/donut_box_empty/test_donut_box_empty.py',),
        'paths': ('tests/donut_box_empty/',),
        'shared_paths': ('code/game/objects/items/weapons/storage/fancy.dm',
                         'tests/egg_box_count/original_fancy.dm',
                         'tests/save_movement/source_adapter.py')},
    'ashtray_spill': {'files': ('tests/ashtray_spill/test_spill.py',),
        'paths': ('tests/ashtray_spill/', 'code/game/objects/items/weapons/material/ashtray.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'outhouse_occupancy': {'files': ('tests/outhouse_occupancy/test_occupancy.py',),
        'paths': ('tests/outhouse_occupancy/', 'code/game/objects/structures/watercloset.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'large_bathtub_washing': {'files': ('tests/large_bathtub_washing/test_washing.py',),
        'paths': ('tests/large_bathtub_washing/', 'code/game/objects/structures/watercloset.dm',
                  'code/modules/1713/bathtubs.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'fixture_global_initialization': {'files': ('tests/fixture_global_initialization/test_global_initialization.py',),
        'paths': ('tests/fixture_global_initialization/', 'scripts/fixture_global_initialization.py'),
        'shared_paths': tuple(f'tests/{name}/run.py' for name in (
            'ammo_casing_load', 'berry_load', 'construction_weathering_load', 'custom_clothing_load',
            'animal_dead_states', 'gun_icon_states', 'load_construction', 'roof_support_load', 'trench_save',
            'vending_load'))},
    'fixture_compiler_output': {'files': ('tests/fixture_compiler_output/test_compiler_output.py',),
        'paths': ('tests/fixture_compiler_output/', 'scripts/fixture_compiler_output.py'),
        'shared_paths': ('scripts/fixture_global_initialization.py',) + tuple(f'tests/{name}/run.py' for name in (
            'ammo_casing_load', 'berry_load', 'construction_weathering_load', 'custom_clothing_load',
            'animal_dead_states', 'gun_icon_states', 'load_construction', 'roof_support_load', 'trench_save',
            'vending_load'))},
    # Offline mocked runner contracts; the native irrigation workflow remains opt-in.
    'irrigation_ci_runner': {'files': ('tests/irrigation_persistence/test_ci_runner.py',),
        'paths': ('tests/irrigation_persistence/', 'tests/trench_save/', 'code/world.dm',
                  '.github/workflows/test.yml', 'scripts/fixture_compiler_output.py',
                  'scripts/fixture_global_initialization.py')},
    'closet_key_assignment': {'files': ('tests/closet_key_assignment/test_assignment.py',), 'paths': (
        'tests/closet_key_assignment/', 'code/game/objects/structures/crates_lockers/closets.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'sign_icons': {'files': ('tests/sign_icons/test_sign_icons.py',), 'paths': (
        'tests/sign_icons/', 'code/game/objects/structures/signs.dm',
        'code/game/objects/structures/sign_flags.dm', 'icons/obj/decals.dmi',
        'icons/obj/decals_wide.dmi'), 'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'cremator_tray': {'files': ('tests/cremator_tray/test_retraction.py',), 'paths': (
        'tests/cremator_tray/', 'code/game/objects/structures/morgue.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'iv_drip_interaction': {'files': ('tests/iv_drip_interaction/test_drag.py',), 'paths': (
        'tests/iv_drip_interaction/', 'code/game/objects/structures/iv_drip.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'gong_fastening': {'files': ('tests/gong_fastening/test_fastening.py',), 'paths': (
        'tests/gong_fastening/', 'code/game/objects/structures/gong.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'lighting_overlay_idle': {'files': ('tests/lighting_idle/test_idle.py',),
        'paths': ('tests/lighting_idle/', 'code/processes/lighting/overlays.dm')},
    'curtain_lighting': {'files': ('tests/curtain_lighting/test_curtain_lighting.py',), 'paths': (
        'tests/curtain_lighting/', 'code/game/objects/structures/curtains.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'kitchen_spike': {'files': ('tests/kitchen_spike/test_kitchen_spike.py',), 'paths': (
        'tests/kitchen_spike/', 'code/game/objects/structures/kitchen_spike.dm')},
    'statue_appearance': {'files': ('tests/statue_appearance/test_statue_appearance.py',), 'paths': (
        'tests/statue_appearance/', 'code/game/objects/structures/religious.dm')},
    'weightlifter': {'files': ('tests/weightlifter/test_weightlifter.py',), 'paths': (
        'tests/weightlifter/', 'code/game/objects/structures/fitness.dm')},
    'building_storeys': {'files': ('tests/building_storeys/test_sources.py',), 'paths': (
        'tests/building_storeys/',), 'shared_paths': (
        'code/game/objects/building_levels.dm', 'code/modules/multiz/building_admission.dm',
        'code/modules/multiz/world_z_budget.dm', 'code/game/objects/map_metadata/nomads/nomads_gaia.dm',
        'code/modules/ecology/flora_regrowth.dm', 'code/modules/ecology/ecology_spawning.dm',
        'code/game/objects/roof_stuff.dm')},
    'building_sleeping_cells': {'files': ('tests/building_sleeping_cells/test_sources.py',), 'paths': (
        'tests/building_sleeping_cells/',), 'shared_paths': (
        'code/modules/multiz/building_lighting.dm', 'code/modules/persistence/zone_topology.dm',
        'code/modules/persistence/saving.dm', 'code/game/objects/map_metadata/_map_metadata.dm')},
    'practice_dummy_armor': {'files': ('tests/practice_dummy_armor/test_armor.py',), 'paths': (
        'tests/practice_dummy_armor/', 'code/game/objects/structures/target_stake.dm')},
    'mirror_fastening': {'files': ('tests/mirror_fastening/test_prompt.py',), 'paths': (
        'tests/mirror_fastening/', 'code/game/objects/structures/mirror.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'linen_bin': {'files': ('tests/linen_bin/test_appearance.py',), 'paths': (
        'tests/linen_bin/', 'code/game/objects/structures/bedsheet_bin.dm')},
    'bell_stand': {'files': ('tests/bell_stand/test_names.py',), 'paths': (
        'tests/bell_stand/', 'code/game/objects/structures/bells.dm')},
    'locket_storage': {'files': ('tests/locket_storage/test_locket.py',), 'paths': (
        'tests/locket_storage/', 'code/game/objects/items/clothing/under/accessories/lockets.dm', 'icons/obj/clothing/ties.dmi')},
    'clay_melee': {'files': ('tests/clay_melee/test_shatter.py',), 'paths': (
        'tests/clay_melee/', 'code/game/objects/items/clay_items.dm', 'tests/save_movement/source_adapter.py')},
    'magic_weapon_contact': {'files': ('tests/magic_weapon_contact/test_contact.py',), 'paths': (
        'tests/magic_weapon_contact/', 'code/_onclick/item_attack.dm',
        'code/modules/magic/magic_weapons.dm', 'code/game/objects/items/weapons/swords_axes_etc.dm', 'code/game/mob/living/living_defense.dm',
        'code/game/mob/living/carbon/carbon_defense.dm', 'code/game/mob/living/carbon/human/human_defense.dm',
        'code/game/mob/living/simple_animal/simple_animal.dm', 'code/game/mob/living/simple_animal/hostile/zombie.dm')},
    'glass_jar': {'files': ('tests/glass_jar/test_capture.py',), 'paths': (
        'tests/glass_jar/', 'code/game/objects/items/glassjar.dm', 'tests/save_movement/source_adapter.py')},
    'physical_data_lan': {'files': ('tests/physical_data_lan/test_lan.py',), 'paths': (
        'tests/physical_data_lan/', 'code/modules/1713/physical_data_lan.dm',
        'code/modules/1713/modern_terminal.dm', 'tests/save_movement/source_adapter.py')},
    'bodybag_label': {'files': ('tests/bodybag/test_label.py',), 'paths': (
        'tests/bodybag/', 'code/game/objects/items/bodybag.dm', 'tests/save_movement/source_adapter.py')},
    'card_dealing': {'files': ('tests/card_dealing/test_prompt.py',),
        'paths': ('tests/card_dealing/',), 'shared_paths': (
            'code/game/objects/items/cards.dm', 'tests/save_movement/source_adapter.py')},
    'stamp_icons': {'files': ('tests/stamp_icons/test_berlin.py',),
        'paths': ('tests/stamp_icons/',), 'shared_paths': (
            'code/game/objects/items/stamp.dm', 'icons/obj/bureaucracy.dmi')},
    'tape_markings': {'files': ('tests/tape_markings/test_overlays.py',),
        'paths': ('tests/tape_markings/',), 'shared_paths': (
            'code/game/objects/items/weapons/policetape.dm',
            'tests/save_movement/source_adapter.py')},
    'effect_lifetime_guards': {'files': ('tests/pool_effects/test_lifetime_guards.py',),
        'paths': ('tests/pool_effects/test_lifetime_guards.py',), 'shared_paths': (
            'code/game/objects/effects/effect_system.dm', 'code/__defines/qdel.dm',
            'tests/save_movement/source_adapter.py')},
    'smokables': {'files': ('tests/smokables/test_burn_state.py',),
        'paths': ('tests/smokables/',), 'shared_paths': (
            'code/game/objects/items/weapons/cigs_lighters.dm',
            'tests/save_movement/source_adapter.py')},
    'candle_lighting': {'files': ('tests/candle_lighting/test_flame_source.py',),
        'paths': ('tests/candle_lighting/',), 'shared_paths': (
            'code/game/objects/items/weapons/cigs_lighters.dm',
            'code/game/objects/items/weapons/candle.dm',
            'code/modules/1713/lantern.dm',
            'code/modules/1713/cmss13_gear.dm',
            'code/game/objects/structures/kitchen/oven.dm')},
    'mimic_treasure': {'files': ('tests/mimic_treasure/test_initialization.py',),
        'paths': ('tests/mimic_treasure/',), 'shared_paths': (
            'code/modules/1713/crates.dm',
            'code/game/mob/living/simple_animal/hostile/mimic.dm')},
    'lava_animal_remains': {'files': ('tests/lava_animal_remains/test_callback.py',),
        'paths': ('tests/lava_animal_remains/',), 'shared_paths': (
            'code/modules/1713/natural_disasters.dm',)},
    'fallout_area_lookup': {'files': ('tests/fallout_area_lookup/test_fallout_scan.py',),
        'paths': ('tests/fallout_area_lookup/',), 'shared_paths': (
            'code/modules/1713/radiation.dm', 'tests/save_movement/source_adapter.py')},
    # Weather system icons are the existing sheet tiled by tools/weather/make_chunks.py.
    'weather_systems': {'files': ('tests/weather_systems/test_icons.py', 'tests/weather_systems/test_strength_offsets.py'),
        'paths': ('tests/weather_systems/', 'tools/weather/'),
        'shared_paths': ('icons/effects/weather.dmi', 'icons/effects/weather_chunks.dmi',
                         'icons/effects/weather_roof.dmi', 'code/modules/1713/weather.dm',
                         'code/modules/1713/weather_systems.dm', 'tests/save_movement/source_adapter.py')},
    'river_flow': {'files': ('tests/river_flow/test_generation.py', 'tests/river_flow/test_flood.py', 'tests/river_flow/test_carryable_guard.py'),
        'paths': ('tests/river_flow/', 'scripts/river_flow.py', 'scripts/river_flood.py', 'scripts/map_coast.py', 'maps/nomads/', 'maps/heights/'),
        'shared_paths': ('tests/save_movement/source_adapter.py', 'code/__defines/qdel.dm', 'code/modules/1713/river_flow.dm', 'code/modules/1713/river_flood.dm', 'code/modules/1713/flood_effects.dm', 'code/modules/1713/flood_ground.dm', 'code/modules/1713/flood_hollows.dm',
                         'code/modules/1713/road_tamping.dm', 'code/modules/1713/barriers/sandbag.dm',
                         'code/game/objects/farming.dm', 'code/game/objects/structures/watercloset.dm',
                         'code/modules/1713/rain_gear.dm', 'code/game/mob/mob_movement.dm',
                         'code/processes/weather.dm', 'code/modules/persistence/durable_contract.dm',
                         'maps/nomads/nomads_desert.dmm',
                         'code/processes/river_current.dm',
                         'code/modules/1713/machinery/renewable_generation.dm',
                         'scripts/terrain_heights.py', 'maps/heights/',
                         'maps/nomads/nomads_gaia.dmm', 'maps/nomads/nomads_europe.dmm',
                         'maps/nomads/nomads_jungle.dmm', 'maps/nomads/nomads_asia.dmm')},
    'cleaning_rag': {'files': ('tests/cleaning_rag/test_targets.py', 'tests/cleaning_rag/test_ignition.py'),
        'paths': ('tests/cleaning_rag/', 'tests/rag_locked_barrel/'), 'shared_paths': (
            'code/game/objects/items/weapons/detective.dm', 'code/game/objects/items/weapons/cigs_lighters.dm',
            'code/game/objects/items/devices/flashlight.dm', 'code/modules/1713/lantern.dm', 'code/_helpers/mobs.dm',
            'code/_onclick/click.dm', 'code/_onclick/item_attack.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/save_movement/source_adapter.py')},
    'lipstick_application': {'files': ('tests/lipstick_application/test_completion.py',),
        'paths': ('tests/lipstick_application/',), 'shared_paths': (
            'code/game/objects/items/weapons/cosmetics.dm', 'code/_helpers/mobs.dm',
            'tests/save_movement/source_adapter.py')},
    'projectile_location': {'files': ('tests/projectile_location/test_location.py',),
        'paths': ('tests/projectile_location/',), 'shared_paths': (
            'code/modules/projectiles/projectile.dm', 'code/_helpers/vector.dm')},
    'projectile_repeat_body': {'files': ('tests/projectile_repeat_body/test_repeat_body.py',),
        'paths': ('tests/projectile_repeat_body/',), 'shared_paths': (
            'code/modules/projectiles/projectile.dm',)},
    'centre_tile': {'files': ('tests/centre_tile/test_sources.py',),
        'paths': ('tests/centre_tile/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/subtile_movement.dm',
            'code/game/mob/mob_movement.dm',
            'code/game/mob/living/simple_animal/riding.dm',
            'code/game/mob/living/living.dm',
            'code/game/turfs/floor_attackby.dm',
            'code/modules/1713/trench.dm')},
    'tree_trunk_collision': {'files': ('tests/tree_trunk_collision/test_sources.py',),
        'paths': ('tests/tree_trunk_collision/',), 'shared_paths': (
            'code/game/objects/structures/wild.dm',
            'code/game/turfs/turf.dm',
            'code/game/objects/farming.dm',
            'code/modules/ecology/willow_trees.dm')},
    'pointing': {'files': ('tests/pointing/test_sources.py',),
        'paths': ('tests/pointing/', 'code/game/mob/living/verbs.dm',
            'code/game/objects/effects/decals/misc.dm'), 'shared_paths': (
            'code/_onclick/click.dm',
            'code/game/mob/living/living.dm',
            'code/game/mob/observer/ghost/ghost.dm')},
    'tile_occupancy': {'files': ('tests/tile_occupancy/test_sources.py',),
        'paths': ('tests/tile_occupancy/', 'code/game/objects/tile_occupancy.dm'), 'shared_paths': (
            'civ13.dme',
            'code/game/objects/items/stacks/stack.dm',
            'code/game/objects/items/clay_items.dm',
            'code/modules/1713/barriers/sandbag.dm',
            'code/modules/1713/barriers/snow_walls.dm',
            'code/game/objects/covers.dm',
            'code/modules/multiz/open_space.dm')},
    'vehicle_offset': {'files': ('tests/vehicle_offset/test_sources.py',),
        'paths': ('tests/vehicle_offset/',), 'shared_paths': (
            'civ13.dme', 'code/modules/craft/vehicle_offset.dm',
            'code/modules/craft/vehicle_offset_ride.dm', 'code/modules/craft/vehicle_offset_frame.dm',
            'code/modules/craft/vehicle_offset_ship.dm', 'tests/save_movement/source_adapter.py')},
    'vehicle_decks': {'files': ('tests/vehicle_decks/test_sources.py',),
        'paths': ('tests/vehicle_decks/', 'code/modules/1713/machinery/modular_vehicles/vehicle_decks.dm'), 'shared_paths': (
            'code/modules/visibility/los_terrain.dm',
            'code/modules/visibility/los_context.dm',
            'code/_onclick/other_mobs.dm',
            'code/game/mob/mob_movement.dm',
            'code/game/objects/structures/tree_climbing.dm',
            'code/modules/projectiles/projectile.dm',
            'code/game/mob/living/carbon/human/human.dm')},
    # Hand conditioning and the unarmed skill: recipes, research, punch hooks, skill lists.
    'hand_conditioning': {'files': ('tests/hand_conditioning/test_sources.py',),
        'paths': ('tests/hand_conditioning/', 'code/modules/1713/martial_arts/hand_conditioning.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/human_attackhand.dm',
                         'code/game/mob/living/carbon/human/punch_injury.dm',
                         'code/game/mob/living/carbon/human/human_defines.dm')},
    # Martial schools: era coverage, research nodes, rank defines, travel hooks.
    'martial_schools': {'files': ('tests/martial_schools/test_sources.py',),
        'paths': ('tests/martial_schools/', 'code/modules/1713/martial_arts/martial_schools.dm',
                  'code/modules/1713/martial_arts/martial_training.dm', 'code/__defines/martial.dm'),
        'shared_paths': ('code/modules/research_tree/research_node.dm',
                         'code/modules/persistence/region_travel.dm')},
    # Whole-body motion: transform-only channel, posture handshake, hit recoil hooks, config.
    'body_motion': {'files': ('tests/body_motion/test_sources.py',),
        'paths': ('tests/body_motion/', 'code/game/mob/living/carbon/human/body_motion.dm', 'code/__defines/body_motion.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/update_icons.dm',
                         'code/game/mob/living/carbon/human/human_defense.dm',
                         'code/game/mob/living/carbon/human/human_attackhand.dm',
                         'code/datums/configuration.dm',
                         'civ13.dme',
                         'code/game/mob/living/carbon/human/emotes/emote.dm',
                         'code/game/objects/buckling.dm',
                         'code/game/mob/animations.dm',
                         'code/modules/projectiles/gun.dm',
                         'code/game/mob/living/carbon/carbon.dm',
                         'code/game/objects/items.dm',
                         'code/game/objects/items/stacks/medical.dm',
                         'code/game/atoms.dm',
                         'code/game/turfs/floor_attackby.dm',
                         'code/modules/1713/fishing_grounds.dm',
                         'code/game/mob/combat_reactions.dm',
                         'code/game/mob/combat_stance.dm',
                         'code/game/mob/mob_movement.dm',
                         'code/modules/1713/swimming.dm',
                         'code/game/mob/living/carbon/human/human_helpers.dm',
                         'code/game/objects/structures/tree_climbing.dm',
                         'code/modules/multiz/edge_climbing.dm',
                         'code/modules/multiz/pit_climbing.dm',
                         'code/modules/1713/machinery/modular_vehicles/vehicle_decks.dm',
                         'code/modules/naval/hull_masts.dm',
                         'code/modules/naval/hull_rigging.dm',
                         'code/game/objects/items/weapons/material/swords.dm',
                         'code/game/objects/items/weapons/material/material_weapons.dm',
                         'code/game/objects/items/weapons/material/twohanded.dm')},
    # Bare-knuckle hand injuries: punch and animal hooks, wrap materials.
    'punch_injury': {'files': ('tests/punch_injury/test_sources.py',),
        'paths': ('tests/punch_injury/', 'code/game/mob/living/carbon/human/punch_injury.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/human_attackhand.dm',
                         'code/game/mob/living/simple_animal/simple_animal.dm')},
    # Combat stances: melee paths ask the stance, doll/hotkey/HUD wiring, agent tools.
    'combat_stance': {'files': ('tests/combat_stance/test_sources.py',),
        'paths': ('tests/combat_stance/', 'code/game/mob/combat_stance.dm', 'code/game/mob/combat_reactions.dm',
                  'code/game/mob/combat_restrain.dm', 'code/__defines/combat_stance.dm'),
        'shared_paths': ('code/_onclick/item_attack.dm',
                         'code/game/mob/living/carbon/human/human_attackhand.dm',
                         'code/game/mob/living/carbon/human/human_defense.dm',
                         'code/game/mob/living/carbon/human/inventory.dm',
                         'code/_onclick/hud/base_screen_objects.dm',
                         'code/game/mob/living/carbon/human/examine.dm',
                         'code/modules/agent_control/agent_stance.dm',
                         'tools/agent-control/autopilot.py',
                         'tools/agent-control/catalog.py',
                         'code/game/mob/grab.dm',
                         'code/__defines/martial.dm',
                         'icons/mob/screen/1713Style.dmi',
                         'icons/mob/screen/ConsoleStyle.dmi',
                         'icons/mob/screen/FoFStyle.dmi',
                         'icons/mob/screen/litewebStyle.dmi')},
    # Training gear and the obstacle course: recipes, gates, hooks, saved fields and art.
    'active_training': {'files': ('tests/active_training/test_sources.py',),
        'paths': ('tests/active_training/', 'code/modules/1713/active_training.dm',
                  'code/modules/1713/training_gear.dm', 'code/modules/1713/training_course.dm',
                  'tests/sprites/create_training_gear.py', 'icons/obj/training.dmi',
                  'icons/mob/items/lefthand_training.dmi', 'icons/mob/items/righthand_training.dmi')},
    'tree_climbing': {'files': ('tests/tree_climbing/test_sources.py',),
        'paths': ('tests/tree_climbing/', 'code/game/objects/structures/tree_climbing.dm'), 'shared_paths': (
            'code/modules/visibility/los_terrain.dm',
            'code/modules/visibility/los_context.dm',
            'code/_onclick/other_mobs.dm',
            'code/game/mob/mob_movement.dm',
            'code/game/mob/living/simple_animal/hostile/tactical_ai.dm',
            'code/game/mob/living/carbon/human/human.dm')},
    # Event regions: home characters kept out of play while their players are at an event.
    'event_regions': {'files': ('tests/event_regions/test_sources.py',),
        'paths': ('tests/event_regions/', 'code/modules/persistence/region_event.dm',
                  'code/modules/admin/event_transfer.dm', 'docs/event-regions.md'), 'shared_paths': (
            'code/modules/persistence/shard_group.dm',
            'code/modules/persistence/region_home.dm',
            'code/modules/persistence/region_travel.dm',
            'code/processes/mob.dm',
            'code/modules/reagents/reagent_containers/food.dm',
            'code/modules/admin/admin_verbs.dm',
            'scripts/shard-group/shard_group.py')},
    # Send Player to Region: admins and the launcher send players or a ship to another region.
    'island_access': {'files': ('tests/island_access/test_source.py',),
        'paths': ('tests/island_access/', 'code/modules/naval/island_access.dm'),
        'shared_paths': ('civ13.dme', 'code/modules/naval/island_claim.dm', 'code/modules/naval/ship_crossing.dm',
            'code/modules/naval/ship_voyage.dm', 'code/modules/persistence/region_travel.dm',
            'code/modules/persistence/region_travel_gear.dm', 'code/modules/persistence/region_admin_send.dm',
            'code/modules/persistence/travel_hold.dm', 'code/modules/persistence/offline_sleep_protection.dm',
            'code/game/mob/groups/factions.dm', 'code/game/mob/groups/colony_charter.dm')},
    'region_admin_send': {'files': ('tests/region_admin_send/test_sources.py',),
        'paths': ('tests/region_admin_send/', 'code/modules/persistence/region_admin_send.dm',
                  'code/modules/admin/send_player_to_region.dm',
                  'tools/opendream-client/native/RegionPlayers.cs', 'tools/opendream-client/native/Gui/PlayersDialog.cs',
                  'docs/region-admin-send.md'), 'shared_paths': (
            'code/modules/persistence/region_travel.dm',
            'code/modules/persistence/nomads_lifecycle.dm',
            'code/modules/naval/ship_crossing.dm',
            'code/modules/admin/admin_verbs.dm',
            'scripts/shard-group/shard_group.py',
            'tools/opendream-client/native/Gui/LauncherWindow.cs',
            'tools/opendream-client/native/Civ13.Launcher.csproj')},
    'pedal_bicycle': {'files': ('tests/pedal_bicycle/test_bicycle.py', 'tests/pedal_bicycle/test_airship.py'),
        'paths': ('tests/pedal_bicycle/', 'code/game/objects/structures/bicycle.dm',
                  'code/game/objects/structures/pedal_airship.dm', 'code/game/objects/structures/pedal_airship_combat.dm',
                  'icons/obj/vehicles/pedal_airship.dmi'),
        'shared_paths': ('tests/save_movement/source_adapter.py',
                         'code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm',
                         'code/game/objects/structures/transports.dm',
                         'code/modules/research_tree/research_node.dm',
                         'config/crafting/material_recipes_global.txt')},
    'airship_hull': {'files': ('tests/airship_hull/test_air_hull.py',),
        'paths': ('tests/airship_hull/', 'code/modules/naval/air_hull.dm',
                  'icons/obj/vehicles/airship_hull.dmi', 'icons/obj/vehicles/airship_gas_cell.dmi',
                  'tests/gas_works/', 'code/modules/naval/gas_works.dm',
                  'icons/obj/gas_works.dmi', 'icons/obj/gas_holder.dmi'),
        'shared_paths': ('tests/save_movement/source_adapter.py',
                         'code/modules/craft/built_body.dm',
                         'code/game/objects/structures/pedal_airship_combat.dm',
                         'code/modules/projectiles/projectile.dm',
                         'code/modules/projectiles/projectile_lob.dm',
                         'code/game/mob/living/carbon/carbon.dm',
                         'code/modules/1713/factory_pipes.dm',
                         'code/modules/research_tree/research_node.dm',
                         'config/crafting/material_recipes_global.txt')},
    'motorcycle_riding': {'files': ('tests/motorcycle_riding/test_sources.py',),
        'paths': ('tests/motorcycle_riding/',), 'shared_paths': (
            'code/game/objects/buckling.dm',
            'code/game/objects/structures/transports.dm',
            'code/game/objects/structures/carriage.dm')},
    'paint_buckets': {'files': ('tests/paint_buckets/test_colors.py',),
        'paths': ('tests/paint_buckets/',), 'shared_paths': (
            'code/game/objects/items/weapons/paint.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Other.dm',
            'tests/save_movement/source_adapter.py')},
    'sledgehammer': {'files': ('tests/sledgehammer/test_two_hands.py',),
        'paths': ('tests/sledgehammer/',), 'shared_paths': (
            'code/game/objects/items/weapons/sledgehammer.dm', 'tests/save_movement/source_adapter.py')},
    'serving_tray': {'files': ('tests/serving_tray/test_targeting.py', 'tests/serving_tray/test_feedback.py'),
        'paths': ('tests/serving_tray/',), 'shared_paths': (
            'code/game/objects/items/weapons/trays.dm', 'tests/save_movement/source_adapter.py')},
    'mop_cleaning': {'files': ('tests/mop_cleaning/test_completion.py',),
        'paths': ('tests/mop_cleaning/',), 'shared_paths': (
            'code/game/objects/items/weapons/mop.dm', 'code/game/turfs/turf.dm', 'tests/save_movement/source_adapter.py')},
    'extinguisher_cabinet': {'files': ('tests/extinguisher_cabinet/test_alt_click.py',),
        'paths': ('tests/extinguisher_cabinet/',), 'shared_paths': (
            'code/modules/1713/closets.dm', 'tests/save_movement/source_adapter.py')},
    'ration_diets': {'files': ('tests/ration_diets/test_ration_diets.py',),
        'paths': ('tests/ration_diets/',), 'shared_paths': (
            'code/modules/1713/MRE.dm', 'code/modules/reagents/reagent_containers/food/snacks.dm')},
    'newspaper_reading': {'files': ('tests/newspaper_reading/test_reading.py',),
        'paths': ('tests/newspaper_reading/',), 'shared_paths': (
            'code/modules/1713/newspaper.dm', 'tests/save_movement/source_adapter.py')},
    'football_tackle': {'files': ('tests/football_tackle/test_target.py', 'tests/football_tackle/test_catch.py'),
        'paths': ('tests/football_tackle/',), 'shared_paths': (
            'code/modules/1713/football.dm', 'tests/save_movement/source_adapter.py')},
    # Every piano, violin, shamisen and trumpet note resolves to a real .ogg
    # sample, retuned from the nearest one when the note has none of its own.
    'instrument_samples': {'files': ('tests/instrument_samples/test_instrument_samples.py',),
        'paths': ('tests/instrument_samples/',), 'shared_paths': (
            'code/game/objects/items/devices/instrument_song.dm', 'code/game/objects/items/devices/violin.dm',
            'code/game/objects/items/devices/shamisen.dm', 'code/game/objects/items/devices/trombone.dm',
            'code/game/objects/structures/piano.dm', 'sound/piano/', 'sound/violin/', 'sound/shamisen/',
            'sound/trombone/')},
    'microscope_integrity': {'files': ('tests/microscope_integrity/test_integrity.py',),
        'paths': ('tests/microscope_integrity/',), 'shared_paths': (
            'code/modules/1713/forensics.dm', 'code/_helpers/mobs.dm')},
    'book_distribution': {'files': ('tests/book_distribution/test_contract.py',),
        'paths': ('tests/book_distribution/',), 'shared_paths': (
            'code/modules/research_tree/book_distribution.dm',
            'code/modules/research_tree/character_knowledge.dm',
            'code/modules/1713/production.dm',
            'code/modules/persistence/region_travel.dm',
            'code/game/objects/structures/vending/specialist_traders.dm')},
    # Maps copy like books (by hand onto a blank map, or on the press) and
    # carry their ink drawing and written notes with them.
    'map_copying': {'files': ('tests/map_copying/test_contract.py',),
        'paths': ('tests/map_copying/',), 'shared_paths': (
            'code/game/objects/items/cartography.dm',
            'code/game/objects/items/cartography_notes.dm',
            'code/modules/1713/production.dm', 'code/modules/1713/book.dm',
            'code/modules/research_tree/book_printing.dm')},
    'television': {'files': ('tests/television/test_contract.py',),
        'paths': ('tests/television/',), 'shared_paths': (
            'code/modules/1713/television.dm', 'code/modules/1713/modern_telecom.dm',
            'code/modules/1713/cmss13_overwatch.dm',
            'code/modules/research_tree/node_broadcast.dm')},
    'node_broadcast': {'files': ('tests/node_broadcast/test_contract.py',),
        'paths': ('tests/node_broadcast/',), 'shared_paths': (
            'code/modules/research_tree/node_broadcast.dm',
            'code/modules/1713/modern_telecom.dm')},
    'recipe_knowledge': {'files': ('tests/recipe_knowledge/test_contract.py',
                                   'tests/recipe_knowledge/test_material_visibility.py',
                                   'tests/recipe_knowledge/test_admin_research_view.py'),
        'paths': ('tests/recipe_knowledge/',), 'shared_paths': (
            'code/modules/research_tree/character_knowledge.dm',
            'code/modules/admin/verbs/research_knowledge.dm',
            'code/modules/research_tree/research_faction.dm',
            'code/modules/persistence/player_reclaim.dm',
            'code/game/mob/living/carbon/carbon.dm',
            'code/game/mob/living/carbon/human/death.dm')},
    'research_coverage': {'files': ('tests/research_coverage/test_coverage.py',),
        'paths': ('tests/research_coverage/', 'scripts/atlas/research_coverage.py'),
        'shared_paths': ('code/modules/research_tree/', 'config/crafting/',
                         'scripts/build-crafting-atlas.py', 'scripts/atlas/',
                         'UI/crafting-atlas.json', 'code/game/objects/items/stacks/stack.dm',
                         'code/game/objects/items/stacks/civ_recipes.dm')},
    'navigation_tablet': {'files': ('tests/navigation_tablet/test_alt_click.py',),
        'paths': ('tests/navigation_tablet/',), 'shared_paths': (
            'code/game/objects/items/weapons/tools.dm', 'code/_onclick/click.dm')},
    'cane_stance': {'files': ('tests/cane_stance/test_cane_stance.py',),
        'paths': ('tests/cane_stance/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_organs.dm',
            'code/modules/1713/cane.dm', 'code/game/objects/items/weapons/material/misc.dm')},
    'radio_frequency': {'files': ('tests/radio_frequency/test_frequency.py',),
        'paths': ('tests/radio_frequency/',), 'shared_paths': (
            'code/modules/1713/radio.dm', 'tests/save_movement/source_adapter.py')},
    'extinguisher': {'files': ('tests/extinguisher/test_initial_water.py',),
        'paths': ('tests/extinguisher/',), 'shared_paths': (
            'code/game/objects/items/weapons/tools.dm', 'config/crafting/material_recipes_global.txt')},
    # 2026-11-07 gameplay audit: source checks plus run.py's extracted-proc probe text.
    'gameplay_audit': {'files': ('tests/gameplay_audit/test_source.py',),
        'paths': ('tests/gameplay_audit/',), 'shared_paths': (
            'code/game/turfs/floor_attackby.dm', 'code/game/mob/living/carbon/human/emotes/emote.dm',
            'code/modules/1713/machinery/modular_vehicles/movement.dm',
            'code/modules/1713/machinery/modular_vehicles/car_workshop.dm',
            'code/modules/paperwork/lifecycle.dm', 'code/modules/reagents/Chemistry-Holder.dm',
            'code/modules/1713/animal_harvest.dm', 'code/game/mob/living/living.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Medicine.dm')},
    # Complete monitor pipe rows with fake spatial/type boundaries; no native IO.
    'factory_monitor': {'files': ('tests/factory_automation/test_monitor_pipes.py',),
        'paths': ('tests/factory_automation/test_monitor_pipes.py',), 'shared_paths': (
            'code/modules/1713/factory_monitor.dm', 'code/modules/1713/factory_pipes.dm',
            'tests/save_movement/source_adapter.py')},
    # Complete oil-well ownership helpers with fake locations/reagents; no native IO.
    'oilwell_barrels': {'files': ('tests/petroleum_lifecycle/test_barrel_recovery.py',),
        'paths': ('tests/petroleum_lifecycle/test_barrel_recovery.py',),
        'shared_paths': ('code/modules/1713/production.dm',
                         'code/modules/1713/factory_chemistry.dm',
                         'code/modules/1713/factory_pipes.dm',
                         'tests/save_movement/source_adapter.py')},
    # Production movement teardown projected with inert registries; no native world.
    'vehicle_component_teardown': {'files': ('tests/boat_movement/test_component_ownership.py',),
        'paths': ('tests/boat_movement/',), 'shared_paths': (
            'code/modules/1713/machinery/modular_vehicles/movement.dm',
            'code/modules/1713/machinery/modular_vehicles/ships/movement.dm',
            'tests/save_movement/source_adapter.py')},
    # Explosion remains above the ground: production wiring and map level audit.
    'vehicle_hull_damage': {'files': ('tests/vehicle_hull_damage/test_contract.py',),
        'paths': ('tests/vehicle_hull_damage/',), 'shared_paths': (
            'code/game/objects/items/weapons/grenades/grenade.dm',
            'code/game/objects/items/devices/drone.dm')},
    # Explosion remains above the ground: production wiring and map level audit.
    'explosion_remains': {'files': ('tests/explosion_remains/test_explosion_remains.py',),
        'paths': ('tests/explosion_remains/',), 'shared_paths': (
            'code/modules/multiz/explosion_remains.dm', 'code/game/turfs/floor.dm',
            'code/game/turfs/floor_types.dm', 'code/game/turfs/walls.dm',
            'code/game/turfs/floor_attackby.dm', 'code/modules/1713/tools.dm',
            'code/modules/projectiles/__projectiles.dm',
            'code/modules/projectiles/projectile/cannon.dm', 'civ13.dme')},
    'dog_process': {'files': ('tests/dog_process/test_dog_process.py',),
        'paths': ('tests/dog_process/', 'code/processes/dog.dm')},
    # Execution devices recheck occupancy after the placement wait (issue #6499).
    'punishment_race': {'files': ('tests/punishment_race/test_occupancy.py',),
        'paths': ('tests/punishment_race/',), 'shared_paths': (
            'code/modules/1713/punishment.dm',)},
    'cattle_plough': {'files': ('tests/cattle_plough/test_plough.py', 'tests/cattle_plough/test_detach_race.py'),
        'paths': ('tests/cattle_plough/',), 'shared_paths': (
            'code/game/mob/living/simple_animal/friendly/farm_animals.dm',)},
    # Cotton is only food for ruminants: production predicate and call sites.
    'animal_cotton': {'files': ('tests/animal_cotton/test_animal_cotton.py',),
        'paths': ('tests/animal_cotton/',), 'shared_paths': (
            'code/game/mob/living/simple_animal/simple_animal.dm',
            'code/game/mob/living/simple_animal/simple_ai.dm',
            'code/game/mob/living/simple_animal/friendly/farm_animals.dm',
            'code/game/mob/living/simple_animal/friendly/deer.dm',
            'code/game/mob/living/simple_animal/hostile/buffalo.dm',
            'tests/save_movement/source_adapter.py')},
    # Chicken navigation predicates and collision dispatch; fake engine only.
    'chicken_water': {'files': ('tests/chicken_water/test_chicken_water.py',),
        'paths': ('tests/chicken_water/',), 'shared_paths': (
            'code/game/mob/living/simple_animal/simple_animal.dm',
            'code/game/mob/living/simple_animal/friendly/birds.dm',
            'code/game/mob/living/simple_animal/simple_ai.dm',
            'code/game/turfs/floor_types.dm', 'code/game/turfs/turf.dm',
            'code/pathfinding.dm', 'maps/nomads/nomads_gaia.dmm',
            'tests/save_movement/source_adapter.py')},
    # Complete starting-coin helper projection; no native game or save access.
    'nomad_starting_coins': {'files': ('tests/nomad_starting_coins/test_starting_coins.py',),
        'paths': ('tests/nomad_starting_coins/',), 'shared_paths': (
            'code/modules/1713/jobs/nomads.dm', 'code/game/objects/items/stacks/money.dm',
            'code/game/mob/new_player/new_player.dm', 'code/game/gameticker.dm',
            'code/game/mob/living/carbon/human/nomads_spawn.dm',
            'code/modules/persistence/player_reclaim.dm',
            'code/modules/persistence/region_travel.dm',
            'tests/save_movement/source_adapter.py')},
    # Complete bounded Gaia spawn helpers with fake spatial/engine boundaries.
    'gaia_spawn': {'files': ('tests/gaia_spawn/test_spawn.py',),
        'paths': ('tests/gaia_spawn/',), 'shared_paths': (
            'code/game/objects/map_metadata/nomads/nomads_gaia.dm',
            'code/game/mob/new_player/new_player.dm', 'code/game/jobs/job_controller.dm',
            'code/game/mob/living/carbon/human/human.dm',
            'code/game/mob/living/carbon/human/nomads_spawn.dm',
            'maps/nomads/nomads_gaia.dmm', 'tests/save_movement/source_adapter.py')},
    # Chamber transfer projection and action-specific ordering; offline only.
    'gun_chamber': {'files': ('tests/gun_chamber/test_chamber.py',),
        'paths': ('tests/gun_chamber/',), 'shared_paths': (
            'code/modules/1713/weapons/guns/_gun.dm',
            'code/modules/1713/weapons/guns/shotguns.dm',
            'code/modules/1713/weapons/guns/lever_action.dm',
            'code/modules/1713/weapons/guns/revolvers.dm',
            'tests/save_movement/source_adapter.py')},
    # Complete raider firing/reload source projections with fake engine boundaries.
    # Keep production paths shared so existing conservative selection is preserved.
    'nomad_raider_combat': {'files': ('tests/nomad_raids/test_combat.py',),
        'paths': ('tests/nomad_raids/test_combat.py',), 'shared_paths': (
            'code/modules/nomad_raids/nomad_raider.dm',
            'code/modules/nomad_raids/nomad_visit.dm', 'code/modules/nomad_raids/nomad_capture.dm',
            'code/game/mob/living/simple_animal/hostile/humans/human.dm',
            'code/modules/projectiles/gun.dm', 'code/modules/projectiles/guns/projectile.dm',
            'code/modules/1713/weapons/guns/revolvers.dm',
            'code/modules/projectiles/_ammo_casing.dm',
            'tests/save_movement/source_adapter.py')},
    # Pure source catalog and injected build transports; no native or network IO.
    'nomads_persistence': {'files': ('tests/nomads_persistence/test_catalog.py',),
        'paths': ('tests/nomads_persistence/',),
        'shared_paths': ('code/modules/persistence/durable_nomads.dm',
                         'scripts/nomads-lifecycle/supervisor.py',
                         'scripts/nomads-lifecycle/canonical_update.py',
                         'scripts/nomads-lifecycle/bot_consumer.py', 'civ13.dme')},
    'fuel_pump_variants': {'files': ('tests/fuel_pump/test_variants.py',),
        'paths': ('tests/fuel_pump/',), 'shared_paths': (
            'tests/save_movement/source_adapter.py',
            'code/game/objects/structures/vending/fuel_pump.dm')},
    # Complete mood helpers, maintenance and expression projections; no native world.
    # Production paths retain the prior conservative fallback/neighbor selection.
    'mood_sleep': {'files': ('tests/mood_sleep/test_mood_sleep.py',), 'timeout': 120,
        'paths': ('tests/mood_sleep/',), 'shared_paths': (
            'tests/save_movement/source_adapter.py',)},
    'dream_lifecycle': {'files': ('tests/dream_lifecycle/test_dream_lifecycle.py',),
        'paths': ('tests/dream_lifecycle/', 'code/modules/flufftext/Dreaming.dm')},
    # Human form priority and reset-callback projections; no native world.
    'human_life_forms': {'files': ('tests/human_life_forms/test_forms.py',),
        'paths': ('tests/human_life_forms/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/save_movement/source_adapter.py')},
    # Vision-organ short-circuit and side-effect order with fake engine types.
    'human_vision_organ': {'files': ('tests/human_vision_organ/test_vision_organ.py',),
        'paths': ('tests/human_vision_organ/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/save_movement/source_adapter.py')},
    # Worn glasses add their flash protection and tint (issue 5474).
    'glasses_flash_protection': {'files': ('tests/glasses_flash_protection/test_glasses_protection.py',),
        'paths': ('tests/glasses_flash_protection/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_helpers.dm',
            'code/game/objects/items/clothing/glasses/glasses.dm')},
    # Switched-off walkthrough metal detectors keep their off look (issue 5484).
    'metal_detector_power': {'files': ('tests/metal_detector_power/test_power_look.py',),
        'paths': ('tests/metal_detector_power/',), 'shared_paths': ('code/modules/1713/modern_items.dm',)},
    # Centrifuge lids and grid reservations (issues 5514 and 5516).
    'centrifuge_seal_power': {'files': ('tests/centrifuge_seal_power/test_centrifuge.py',),
        'paths': ('tests/centrifuge_seal_power/',), 'shared_paths': ('code/modules/reagents/Chemistry-Machinery.dm',)},
    # Eating refusal follows the stomach size (Gaia 2026-11-15).
    'food_fullness': {'files': ('tests/food_fullness/test_fullness_limit.py',
        'tests/food_fullness/test_overfed_vomit.py'),
        'paths': ('tests/food_fullness/',), 'shared_paths': (
            'code/game/mob/living/carbon/carbon.dm',
            'code/game/mob/living/carbon/human/human.dm',
            'code/modules/reagents/reagent_containers.dm',
            'code/game/mob/living/carbon/carbon_defines.dm',
            'code/modules/reagents/reagent_containers/food/snacks.dm',
            'code/game/objects/items/weapons/material/kitchen.dm')},
    'human_ssd_hunger': {'files': ('tests/human_ssd_hunger/test_ssd_hunger.py',
        'tests/human_ssd_hunger/test_conscious_hunger.py'),
        'paths': ('tests/human_ssd_hunger/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/save_movement/source_adapter.py')},
    'human_thermal_clothing': {'files': ('tests/human_thermal_clothing/test_thermal_clothing.py', 'tests/human_fire_protection/test_fire_protection.py'),
        'paths': ('tests/human_thermal_clothing/', 'tests/human_fire_protection/'), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/save_movement/source_adapter.py')},
    'human_bed_healing': {'files': ('tests/human_bed_healing/test_bed_healing.py',),
        'paths': ('tests/human_bed_healing/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/save_movement/source_adapter.py')},
    # Wildlife plant classification against a frozen pre-change predicate.
    'wild_browse': {'files': ('tests/wild_browse/test_browse.py',),
        'paths': ('tests/wild_browse/',), 'shared_paths': (
            'code/modules/ecology/wild_feeding.dm', 'tests/save_movement/source_adapter.py')},
    # Narrow-cone direction equivalence against fake engine geometry.
    'vision_cone_direction': {'files': ('tests/vision_cone_direction/test_direction.py',),
        'paths': ('tests/vision_cone_direction/',), 'shared_paths': (
            'code/game/mob/vision_cone.dm', 'tests/save_movement/source_adapter.py')},
    # Complete startup observer projections and hook contracts; fake timers/Export.
    'game_ready': {'files': ('tests/game_ready/test_release.py',
                             'tests/game_ready/test_ready.py',
                             'tests/game_ready/test_hooks.py'),
        'paths': ('tests/game_ready/', 'code/modules/webhooks/game_ready.dm',
                  'config/game-ready.example.txt', 'docs/game-ready-webhook.md'),
        'shared_paths': ('code/world.dm', 'code/setup.dm', 'code/datums/configuration.dm',
            'code/modules/persistence/functions.dm',
            'code/modules/persistence/restart_transaction.dm',
            'code/modules/persistence/player_reclaim.dm',
            'code/modules/persistence/nomads_lifecycle.dm',
            'tests/save_movement/source_adapter.py', 'civ13.dme')},

    'animal_tack': {'files': ('tests/animal_tack/test_tack.py',),
        'paths': ('tests/animal_tack/', 'code/game/objects/items/weapons/animal_tack.dm'),
        'shared_paths': ('code/game/mob/living/simple_animal/riding.dm',
            'code/game/mob/living/simple_animal/simple_animal.dm',
            'code/game/objects/structures/transports.dm',
            'code/game/objects/structures/carriage.dm',
            'code/modules/research_tree/research_node.dm',
            'config/crafting/material_recipes_global.txt',
            'code/modules/persistence/saving.dm', 'code/modules/persistence/functions.dm',
            'tests/save_movement/source_adapter.py', 'civ13.dme')},
    # Company stock ledger, stock market and company stall guard projections.
    'company_stock': {'files': ('tests/company_stock/test_company_stock.py',),
        'paths': ('tests/company_stock/', 'code/game/mob/groups/companies.dm',
                  'code/modules/1713/marketplace.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/death.dm',
            'code/game/objects/structures/vending/vending_sales.dm')},
    # Reviewed stdlib-only source/guard projections; no BYOND runtime.
    'stone_brazier': {'files': ('tests/stone_brazier/test_stone_brazier_disposal.py',),
        'paths': ('tests/stone_brazier/',), 'shared_paths': (
            'code/modules/1713/siege/fire.dm',)},
    # Showcase room templates parsed with the runtime reader's rules; no BYOND runtime.
    'showcase_rooms': {'files': ('tests/showcase_rooms/test_templates.py',),
        'paths': ('tests/showcase_rooms/', 'maps/zones/showcase/',
                  'code/modules/admin/showcase_rooms.dm', 'scripts/build_showcase_dme.py'),
        'shared_paths': ('civ13.dme', 'code/modules/admin/admin_verbs.dm')},
    # The vote window updates in place instead of reloading every second; source checks, no BYOND runtime.
    'vote_window': {'files': ('tests/vote_window/test_vote_window.py',),
        'paths': ('tests/vote_window/',), 'shared_paths': ('code/datums/vote.dm',)},
    # TDM servers vote only between team battle epochs; source projection, no BYOND runtime.
    'tdm_map_vote': {'files': ('tests/tdm_map_vote/test_tdm_epochs.py',),
        'paths': ('tests/tdm_map_vote/',), 'shared_paths': ('code/processes/mapswap.dm',)},
    # Windows scheduled-task host control with a fake machine; no BYOND runtime.
    'gaia_host': {'files': ('tests/gaia_host/test_gaia_host.py', 'tests/gaia_host/test_shard_group.py',
                           'tests/gaia_host/test_fresh_world.py',
                           'tests/gaia_host/test_doorman.py', 'tests/gaia_host/test_wait_group.py',
                           'tests/gaia_host/test_relay.py', 'tests/gaia_host/test_mobile_host.py',
                           'tests/gaia_host/test_expedition_slots.py', 'tests/gaia_host/test_underground_migration.py'),
        'paths': ('tests/gaia_host/', 'scripts/gaia-host/', 'scripts/shard-group/', 'scripts/windows/host/'),
        'shared_paths': ('scripts/nomads-lifecycle/supervisor.py',)},
    # Farmer's almanac weather table and crop rule projected from production DM.
    'farmers_almanac': {'files': ('tests/farmers_almanac/test_farmers_almanac.py',),
        'paths': ('tests/farmers_almanac/',), 'shared_paths': (
            'code/modules/1713/farmers_almanac.dm',
            'code/modules/1713/weather.dm',
            'code/game/objects/farming.dm')},
    # Dead animal sprites: reviewed gap list against the DMI files, update_icons()
    # overrides and grow-up timers. run.py (native sweep) is not part of this suite.
    'animal_dead_states': {'files': ('tests/animal_dead_states/test_animal_dead_states.py',),
        'paths': ('tests/animal_dead_states/',),
        'shared_paths': (
            'scripts/fixture_compiler_output.py',
            'scripts/fixture_global_initialization.py',
            'code/game/mob/living/simple_animal/',
            'code/modules/1713/complex_animal/',
            'code/modules/magic/magic_npcs_hostile.dm',
            'code/modules/magic/magic_npcs_friendly.dm',
            'icons/mob/', 'icons/obj/flora/largejungleflora.dmi')},
    # Gun sprite-state fallback: reviewed gap list against the DMI files and the
    # render paths that apply it. run.py (native sweep) is not part of this suite.
    'gun_icon_states': {'files': ('tests/gun_icon_states/test_gun_icon_states.py',),
        'paths': ('tests/gun_icon_states/', 'code/_helpers/sprite_states.dm'),
        'shared_paths': (
            'scripts/fixture_compiler_output.py',
            'scripts/fixture_global_initialization.py',
            'code/game/mob/living/carbon/human/update_icons.dm',
            'code/modules/projectiles/gun.dm',
            'code/modules/projectiles/guns/projectile.dm',
            'icons/obj/guns/', 'icons/mob/items/lefthand_guns.dmi',
            'icons/mob/items/righthand_guns.dmi', 'icons/mob/back.dmi', 'civ13.dme')},
    # Ploughed field sprite selection and load restore projected from production DM.
    'ploughed_field_icon': {'files': ('tests/ploughed_field_icon/test_ploughed_field_icon.py', 'tests/ploughed_field_icon/test_floor_overlay_cache.py'),
        'paths': ('tests/ploughed_field_icon/',), 'shared_paths': (
            'code/game/turfs/flooring/flooring_premade.dm',
            'code/game/turfs/flooring/flooring.dm',
            'code/game/turfs/floor_icon.dm',
            'code/game/turfs/floor.dm',
            'icons/turf/floors.dmi')},
    # Inventory drag-and-drop transfer source contracts; no BYOND runtime.
    'inventory_drag': {'files': ('tests/inventory_drag/test_inventory_drag.py',),
        'paths': ('tests/inventory_drag/',), 'shared_paths': (
            'code/_onclick/inventory_drag.dm',
            'code/game/objects/items/weapons/storage/storage.dm',
            'code/game/objects/items/weapons/storage/internal.dm',
            'code/game/objects/items/clothing/clothing_accessories.dm',
            'code/game/objects/structures/key_doors/keychain.dm',
            'code/game/objects/structures/mail.dm')},
    # Generated Crossroads Mall raid/loot-range map: DMM parse, route flood-fill
    # and loot-table pad coverage projected from source; no BYOND runtime.
    'crossroads_mall': {'files': ('tests/crossroads_mall/test_crossroads_mall.py',),
        'paths': ('tests/crossroads_mall/', 'maps/EFT/crossroads_mall.dmm',
                  'code/game/objects/map_metadata/crossroads_mall.dm'), 'shared_paths': (
            'code/game/objects/random.dm',
            'code/game/objects/effects/spawners/loot.dm',
            'code/game/objects/map_metadata/eft_factory.dm', 'civ13.dme')},
    # Generated Americas region maps (north and south continent): DMM parse,
    # land share, starts, the isthmus edge, file digests and source registration; no BYOND runtime.
    'americas_maps': {'files': ('tests/americas_maps/test_americas_maps.py',), 'timeout': 120,
        'paths': ('tests/americas_maps/', 'maps/heights/nomads_americas_north.txt',
                  'maps/heights/nomads_americas_north.flow.txt',
                  'maps/heights/nomads_americas_north.flood.txt',
                  'maps/heights/nomads_americas_south.txt',
                  'maps/heights/nomads_americas_south.flow.txt',
                  'maps/heights/nomads_americas_south.flood.txt',
                  'maps/nomads/nomads_americas_north.dmm',
                  'maps/nomads/nomads_americas_south.dmm',
                  'code/game/objects/map_metadata/nomads/nomads_americas.dm',
                  'scripts/shard-group/americas.example.json'), 'shared_paths': (
            'code/modules/persistence/region_trails.dm',
            'code/modules/persistence/durable_nomads.dm',
            'code/__defines/maps.dm', 'civ13.dme'),
        # Rebuilding both maps' currents and flood reaches from 1M-cell maps takes
        # about 50 s locally and longer on hosted runners.
        'timeout': 180},
    # The ocean regions: generated maps current, sizes, insets, metadata registered
    # and open water at both ends of every sea link, parsed from the DMMs; no BYOND runtime.
    'ocean_maps': {'files': ('tests/ocean_maps/test_ocean_maps.py', 'tests/ocean_maps/test_reef_fixture.py'),
        'timeout': 180,
        'paths': ('tests/ocean_maps/', 'tools/ocean_maps/', 'tools/world_links/',
                  'code/modules/naval/ocean_regions.dm', 'code/modules/persistence/world_links.dm',
                  'code/modules/naval/ship_edge_crossing.dm', 'code/modules/naval/ship_crossing.dm',
                  'code/modules/naval/built_hull.dm', 'code/modules/persistence/region_travel.dm',
                  'code/modules/persistence/shard_group.dm', 'scripts/shard-group/shard_group.py',
                  'tools/transfer_storage/agent.py',
                  'maps/nomads/nomads_ocean_atlantic.dmm', 'maps/nomads/nomads_ocean_pacific.dmm',
                  'maps/nomads/nomads_ocean_indian.dmm', 'maps/nomads/nomads_ocean_arctic.dmm',
                  'maps/nomads/nomads_ocean_southern.dmm'), 'shared_paths': (
            'code/__defines/maps.dm', 'code/modules/persistence/durable_nomads.dm',
            'code/modules/1713/jobs/nomads.dm', 'scripts/nomads-lifecycle/supervisor.py',
            'maps/nomads/nomads_americas_north.dmm', 'maps/nomads/nomads_americas_south.dmm',
            'maps/nomads/nomads_earth_europe.dmm', 'maps/nomads/nomads_earth_africa.dmm',
            'maps/nomads/nomads_earth_asia.dmm', 'maps/nomads/nomads_earth_oceania.dmm',
            'maps/nomads/nomads_earth_greenland.dmm', 'maps/nomads/nomads_earth_mediterranean.dmm', 'maps/nomads/nomads_earth_antarctica.dmm',
            'maps/nomads/nomads_gaia.dmm')},
    # Walking between lands over shared map edges: links answered on the facing
    # edge with dry ground on both stretches, parsed from the DMMs; no BYOND runtime.
    'edge_crossings': {'files': ('tests/edge_crossings/test_edge_crossings.py',), 'timeout': 120,
        'paths': ('tests/edge_crossings/', 'code/modules/persistence/region_edge.dm',
                  'code/modules/persistence/region_edge_carriage.dm',
                  'code/game/objects/map_metadata/nomads/nomads_europe.dm',
                  'code/game/objects/map_metadata/nomads/nomads_asia.dm',
                  'code/game/objects/map_metadata/nomads/nomads_desert.dm',
                  'code/game/objects/map_metadata/nomads/nomads_jungle.dm',
                  'code/game/objects/map_metadata/nomads/nomads_americas.dm',
                  'code/game/objects/map_metadata/nomads/nomads_earth.dm',
                  'code/modules/persistence/world_links.dm', 'code/modules/naval/sea_lanes.dm',
                  'tools/world_links/'), 'shared_paths': (
            'code/modules/naval/ship_crossing.dm', 'code/modules/naval/built_hull.dm', 'code/modules/craft/under_way.dm',
            'maps/nomads/nomads_europe.dmm', 'maps/nomads/nomads_asia.dmm',
            'maps/nomads/nomads_desert.dmm', 'maps/nomads/nomads_jungle.dmm',
            'maps/nomads/nomads_americas_north.dmm', 'maps/nomads/nomads_americas_south.dmm',
            'maps/nomads/nomads_earth_europe.dmm', 'maps/nomads/nomads_earth_africa.dmm',
            'maps/nomads/nomads_earth_asia.dmm', 'maps/nomads/nomads_earth_oceania.dmm',
            'maps/nomads/nomads_earth_greenland.dmm', 'maps/nomads/nomads_earth_mediterranean.dmm', 'maps/nomads/nomads_earth_antarctica.dmm',
            'maps/nomads/nomads_gaia.dmm')},
    # Draft lands of the rest of the Earth (maps/earth_drafts): DMM parse, sizes,
    # file digests and that no build or region list names them; no BYOND runtime.
    'earth_maps': {'files': ('tests/earth_maps/test_earth_maps.py',), 'timeout': 120,
        'paths': ('tests/earth_maps/', 'maps/earth_drafts/', 'tests/americas_maps/build.py',
                  'maps/nomads/nomads_earth_europe.dmm', 'maps/nomads/nomads_earth_africa.dmm',
                  'maps/nomads/nomads_earth_asia.dmm', 'maps/heights/nomads_earth_asia.txt',
                  'maps/heights/nomads_earth_asia.flow.txt', 'maps/heights/nomads_earth_asia.flood.txt',
                  'maps/nomads/nomads_earth_oceania.dmm', 'maps/nomads/nomads_earth_greenland.dmm', 'maps/nomads/nomads_earth_mediterranean.dmm',
                  'maps/nomads/nomads_earth_antarctica.dmm', 'maps/heights/nomads_earth_oceania.txt',
                  'maps/heights/nomads_earth_greenland.txt', 'maps/heights/nomads_earth_mediterranean.txt', 'maps/heights/nomads_earth_antarctica.txt',
                  'maps/heights/nomads_earth_europe.txt', 'maps/heights/nomads_earth_europe.flow.txt',
                  'maps/heights/nomads_earth_europe.flood.txt', 'maps/heights/nomads_earth_africa.txt',
                  'maps/heights/nomads_earth_africa.flow.txt', 'maps/heights/nomads_earth_africa.flood.txt',
                  'code/game/objects/map_metadata/nomads/nomads_earth.dm',
                  'scripts/shard-group/earth_continents.example.json', 'docs/earth-continents.md'), 'shared_paths': (
            'maps/nomads/nomads_americas_north.dmm', 'maps/nomads/nomads_americas_south.dmm',
            'scripts/shard-group/americas.example.json', 'code/processes/mapswap.dm', 'civ13.dme',
            'code/game/objects/map_metadata/nomads/nomads_asia.dm', 'code/modules/naval/sea_lanes.dm',
            'code/__defines/maps.dm', 'code/modules/persistence/durable_nomads.dm',
            'code/modules/1713/jobs/nomads.dm')},
    # Generated inactive Extraction party safehouse template: DMM parse, airlock
    # topology, room routes, account markers and descriptor; no BYOND runtime.
    'safehouse_map': {'files': ('tests/safehouse_map/test_layout.py',),
        'paths': ('tests/safehouse_map/', 'maps/WIP/extraction_safehouse.dmm',
                  'maps/WIP/extraction_safehouse.layout.json',
                  'maps/WIP/extraction_safehouse.template.json'), 'shared_paths': (
            'code/modules/1713/extraction/instances.dm',
            'code/modules/1713/extraction/mode.dm')},
    # Generated Train Raid map: DMM parse, shuttle/bridge/loot-pad geometry and
    # route flood-fill projected from source; no BYOND runtime.
    'train_raid': {'files': ('tests/train_raid/test_train_raid.py',),
        'paths': ('tests/train_raid/', 'maps/EFT/train_raid.dmm', 'maps/EFT/train_raid.layout.json',
                  'code/game/objects/map_metadata/train_raid.dm'), 'shared_paths': (
            'tests/dagger_map/build_map.py', 'tests/dagger_map/build_raid_train.py',
            'code/game/objects/random.dm',
            'code/game/objects/effects/spawners/loot.dm', 'code/__defines/maps.dm', 'civ13.dme')},
    # Same-type duplicate overrides whose earlier body is dead; source scan of
    # code/, run by full and preflight sweeps (not per-file selection).
    'duplicate_overrides': {'files': ('tests/duplicate_overrides/test_duplicate_overrides.py',),
        'paths': ('tests/duplicate_overrides/',), 'shared_paths': ()},
    # Era helpers keep the statue, anvil and kit options the old per-era
    # branches gave; per-era equality checks only shrink. Source scan of code/.
    'era_helpers': {'files': ('tests/era_helpers/test_era_helpers.py',),
        'paths': ('tests/era_helpers/',), 'shared_paths': ()},
    # Material properties and part roles: frozen ratings, the balance rule
    # and the untouched legacy weapon numbers.
    'material_roles': {'files': ('tests/material_roles/test_material_roles.py',),
        'paths': ('tests/material_roles/', 'code/modules/materials/material_properties.dm',
                  'code/modules/materials/part_roles.dm', 'code/__defines/material_roles.dm'),
        'shared_paths': ('code/modules/materials/materials.dm',)},
    'tool_material_speeds': {'files': ('tests/tool_material_speeds/test_tool_material_speeds.py',),
        'paths': ('tests/tool_material_speeds/', 'code/modules/materials/tool_speeds.dm'),
        'shared_paths': ('code/modules/materials/part_roles.dm', 'code/modules/materials/material_properties.dm',
                         'code/modules/1713/tools.dm', 'code/game/objects/items/weapons/tools.dm',
                         'code/game/objects/items/weapons/material/material_weapons.dm',
                         'code/game/objects/items/weapons/material/misc.dm')},
    'tool_materials': {'files': ('tests/tool_materials/test_tool_materials.py',
                                 'tests/tool_materials/test_tool_wear.py',
                                 'tests/tool_materials/test_farm_tools.py'),
        'paths': ('tests/tool_materials/', 'code/modules/materials/tool_materials.dm',
                  'code/modules/materials/tool_wear.dm', 'code/modules/materials/farm_tools.dm',
                  'tests/sprites/create_farm_tools.py', 'icons/obj/farm_tools.dmi',
                  'config/recipe_variants.json', 'scripts/recipe_variants.py'),
        'shared_paths': ('code/modules/materials/part_roles.dm', 'code/modules/materials/material_properties.dm',
                         'code/modules/1713/tools.dm', 'code/game/objects/items/weapons/tools.dm',
                         'code/game/objects/weapons.dm', 'code/_helpers/tools.dm',
                         'code/modules/reagents/reagent_containers/glass.dm', 'code/_onclick/item_attack.dm',
                         'config/crafting/material_recipes_global.txt')},
    'craft_needs': {'files': ('tests/craft_needs/test_craft_needs.py',),
        'paths': ('tests/craft_needs/', 'code/game/objects/items/stacks/craft_needs.dm',
                  'config/craft_needs.json'),
        'shared_paths': ('code/game/objects/items/stacks/stack.dm', 'code/game/objects/items/stacks/craft_guards.dm',
                         'scripts/build-crafting-atlas.py')},
    'machine_parts': {'files': ('tests/machine_parts/test_machine_parts.py', 'tests/machine_parts/test_lathes.py',
                                'tests/machine_parts/test_machine_slots.py', 'tests/machine_parts/test_pipe_materials.py',
                                'tests/machine_parts/test_wire_materials.py', 'tests/machine_parts/test_vessel_materials.py',
                                'tests/machine_parts/test_barrel_materials.py',
                                'tests/machine_parts/test_rolling_stock.py'),
        'paths': ('tests/machine_parts/', 'code/modules/materials/machine_parts.dm',
                  'code/modules/materials/pipe_materials.dm', 'code/modules/materials/wire_materials.dm',
                  'code/modules/materials/vessel_materials.dm', 'tests/sprites/create_fluid_tanks.py',
                  'code/modules/materials/barrel_materials.dm', 'code/modules/materials/rolling_stock.dm',
                  'icons/obj/fluid_tanks.dmi',
                  'code/modules/materials/lathes.dm', 'tests/sprites/create_lathes.py', 'icons/obj/lathes.dmi',
                  'code/modules/materials/machine_slots.dm',
                  'tests/sprites/create_machine_parts.py', 'icons/obj/machine_parts.dmi'),
        'shared_paths': ('code/modules/materials/part_roles.dm', 'code/modules/materials/material_properties.dm',
                         'code/game/objects/structures/blacksmithing/blacksmithing.dm',
                         'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm',
                         'code/game/objects/structures/blacksmithing/anvil_window.dm',
                         'code/game/objects/structures/blacksmithing/molds.dm',
                         'code/modules/research_tree/research_node.dm', 'config/craft_needs.json',
                         'config/crafting/material_recipes_global.txt', 'code/modules/1713/production.dm',
                         'code/modules/1713/factory_pipes.dm', 'code/modules/1713/machinery/cables.dm',
                         'code/modules/1713/machinery/cables_types.dm')},
    'anvil_mold_costs': {'files': ('tests/anvil_mold_costs/test_anvil_mold_costs.py',),
        'paths': ('tests/anvil_mold_costs/',), 'shared_paths': ()},
    'processing_recipes': {'files': ('tests/processing_recipes/test_processing_recipes.py',),
        'paths': ('tests/processing_recipes/', 'code/modules/1713/processing_recipes.dm'), 'shared_paths': (
            'code/modules/1713/herbalism.dm', 'code/modules/1713/flint_mining.dm', 'code/modules/1713/obsidian.dm',
            'scripts/atlas/interactions.py')},
    'resource_stock': {'files': ('tests/resource_stock/test_resource_stock.py',),
        'paths': ('tests/resource_stock/', 'code/_helpers/resource_stock.dm'), 'shared_paths': (
            'code/game/objects/structures/rocks.dm', 'code/modules/1713/obsidian.dm')},
    'job_loadouts': {'files': ('tests/job_loadouts/test_job_loadouts.py',),
        'paths': ('tests/job_loadouts/', 'code/game/jobs/job.dm'), 'shared_paths': ()},
    'liquid_fuels': {'files': ('tests/liquid_fuels/test_liquid_fuels.py',),
        'paths': ('tests/liquid_fuels/', 'code/_helpers/liquid_fuels.dm', 'code/__defines/liquid_fuels.dm'), 'shared_paths': ()},
    'water_turfs': {'files': ('tests/water_turfs/test_water_turfs.py',),
        'paths': ('tests/water_turfs/', 'code/_helpers/water_turfs.dm'), 'shared_paths': ()},
    'faction_hud': {'files': ('tests/faction_hud/test_faction_hud.py',),
        'paths': ('tests/faction_hud/', 'code/_helpers/faction_hud.dm'), 'shared_paths': ()},
    'structure_damage': {'files': ('tests/structure_damage/test_structure_damage.py',),
        'paths': ('tests/structure_damage/', 'code/_helpers/structure_damage.dm'), 'shared_paths': ()},
    'season_helpers': {'files': ('tests/season_helpers/test_season_helpers.py',),
        'paths': ('tests/season_helpers/', 'code/_helpers/seasons.dm', 'code/__defines/seasons.dm'), 'shared_paths': ()},
    'map_traits': {'files': ('tests/map_traits/test_map_traits.py',),
        'paths': ('tests/map_traits/', 'code/game/objects/map_metadata/'), 'shared_paths': ()},
    'job_stats': {'files': ('tests/job_stats/test_job_stats.py',),
        'paths': ('tests/job_stats/', 'code/modules/1713/jobs/'), 'shared_paths': ('code/game/jobs/job.dm',)},
    'item_wear': {'files': ('tests/item_wear/test_item_wear.py',),
        'paths': ('tests/item_wear/', 'code/_helpers/item_wear.dm'), 'shared_paths': (
            'code/game/objects/items/weapons/material/material_weapons.dm',
            'code/game/objects/items/weapons/shields.dm', 'code/game/objects/items/clothing/clothing.dm')},
    'anchoring': {'files': ('tests/anchoring/test_anchoring.py',),
        'paths': ('tests/anchoring/',), 'shared_paths': ('code/_helpers/tools.dm',)},
    # Solid fuel kinds and per-device rates keep the old hard-coded values.
    'solid_fuel': {'files': ('tests/solid_fuel/test_solid_fuel.py', 'tests/solid_fuel/test_campfire_night.py'),
        'paths': ('tests/solid_fuel/',), 'shared_paths': ()},
    # Stack recipe build guards keep produce_recipe()'s old order and phases;
    # source scan of code/.
    'craft_guards': {'files': ('tests/craft_guards/test_craft_guards.py',),
        'paths': ('tests/craft_guards/', 'code/game/objects/items/stacks/craft_guards.dm'),
        'shared_paths': ('code/modules/1713/dug_wells.dm',)},
    'reused_floor_styles': {'files': ('tests/floor_styles/test_reused_floor_styles.py',),
        'paths': ('tests/floor_styles/test_reused_floor_styles.py',
                  'code/game/objects/covers_types/cover_floortypes.dm',
                  'icons/turf/floors.dmi', 'icons/turf/flooring/wood.dmi',
                  'icons/turf/flooring/decals.dmi'), 'shared_paths': ()},
    'iron_floors': {'files': ('tests/iron_floors/test_iron_floors.py',),
        'paths': ('tests/iron_floors/', 'code/modules/1713/iron_floors.dm',
                  'icons/turf/flooring/iron.dmi'), 'shared_paths': ()},
    'extra_floors': {'files': ('tests/extra_floors/test_extra_floors.py',),
        'paths': ('tests/extra_floors/', 'code/modules/1713/extra_floors.dm',
                  'icons/turf/flooring/extra_floors.dmi', 'icons/obj/pelt_rugs.dmi'), 'shared_paths': ()},
    'terracotta_floors': {'files': ('tests/terracotta_floors/test_terracotta_floors.py',),
        'paths': ('tests/terracotta_floors/', 'code/modules/1713/terracotta_floors.dm',
                  'icons/turf/flooring/terracotta.dmi'),
        'shared_paths': ('code/game/objects/covers_types/cover_floortypes.dm',)},
    'recipe_skill_needs': {'files': ('tests/recipe_skill_needs/test_recipe_skill_needs.py',),
        'paths': ('tests/recipe_skill_needs/', 'code/game/objects/items/stacks/stack_makeable.dm'),
        'shared_paths': ('code/game/objects/items/stacks/recipe_skill_needs.dm',)},
    'skill_guide': {'files': ('tests/skill_guide/test_skill_guide.py',),
        'paths': ('tests/skill_guide/', 'code/modules/research_tree/skill_guide.dm'), 'shared_paths': ()},
    'survival_hints': {'files': ('tests/survival_hints/test_survival_hints.py',),
        'paths': ('tests/survival_hints/', 'code/modules/client/survival_hints.dm'), 'shared_paths': ()},
    'newcomer_start': {'files': ('tests/newcomer_start/test_newcomer_start.py',),
        'paths': ('tests/newcomer_start/', 'code/game/objects/map_metadata/nomads/newcomer_start.dm'), 'shared_paths': ()},
    'first_choices': {'files': ('tests/first_choices/test_first_choices.py',),
        'paths': ('tests/first_choices/', 'code/modules/client/first_choices.dm', 'code/_onclick/hud/hover_name_bottom.dm'), 'shared_paths': ()},
    'use_hints': {'files': ('tests/use_hints/test_use_hints.py',),
        'paths': ('tests/use_hints/', 'code/game/objects/structures/use_hints.dm'), 'shared_paths': (
            'code/game/objects/structures/wild.dm',)},
    'log_runtimes': {'files': ('tests/log_runtimes/test_log_runtimes.py',),
        'paths': ('tests/log_runtimes/', 'code/modules/statpanel/statpanel.dm', 'code/controllers/subsystem/timer.dm'), 'shared_paths': ()},
    'immigration_fires': {'files': ('tests/immigration_fires/test_immigration_fires.py',),
        'paths': ('tests/immigration_fires/', 'code/modules/1713/immigration_fires.dm'), 'shared_paths': ()},
    'craft_products': {'files': ('tests/craft_products/test_craft_products.py',),
        'paths': ('tests/craft_products/', 'code/game/objects/items/stacks/craft_products.dm'), 'shared_paths': ()},
    # Tool quality declarations match the base paths is_tool() replaced, and
    # legacy istype checks on base tool paths only shrink; source scan of code/.
    'tool_qualities': {'files': ('tests/tool_qualities/test_tool_qualities.py',),
        'paths': ('tests/tool_qualities/', 'code/__defines/tools.dm', 'code/_helpers/tools.dm'), 'shared_paths': ()},
    # istype/ispath/locate calls that join type paths with || (only the first
    # path is tested); source scan of code/, run by full and preflight sweeps.
    'istype_or_paths': {'files': ('tests/istype_or_paths/test_istype_or_paths.py',),
        'paths': ('tests/istype_or_paths/',), 'shared_paths': ()},
    # Shared Campaign win condition and Battle Royale / Hunger Games shrinking
    # zone against frozen pre-refactor bodies; source projection only.
    'map_metadata_dedupe': {'files': ('tests/map_metadata_dedupe/test_map_metadata_dedupe.py',),
        'paths': ('tests/map_metadata_dedupe/', 'code/game/objects/map_metadata/shrinking_zone.dm'),
        'shared_paths': ('code/game/objects/map_metadata/campaign_new.dm',
                         'code/game/objects/map_metadata/battleroyale.dm',
                         'code/game/objects/map_metadata/hungergames.dm',
                         'maps/special/hunger_games.dmm')},
    # Wall and jail covers share one utensil-to-shank proc; source checks
    # against the frozen copied block, no BYOND runtime.
    'utensil_shank': {'files': ('tests/utensil_shank/test_utensil_shank.py',),
        'paths': ('tests/utensil_shank/',), 'shared_paths': (
            'code/game/objects/covers.dm', 'code/game/objects/covers_types/')},
    # Folding-stock guns share one toggle; source checks against the frozen
    # copied verb, no BYOND runtime.
    'folding_stock': {'files': ('tests/folding_stock/test_folding_stock.py',),
        'paths': ('tests/folding_stock/',), 'shared_paths': (
            'code/modules/projectiles/guns/projectile.dm', 'code/modules/1713/weapons/guns/mg/smg.dm',
            'code/modules/1713/weapons/guns/mg/aks.dm', 'code/modules/1713/weapons/guns/mg/lmg.dm')},
    # Structure and handheld radios share Topic/broadcast/interact; source
    # parity against the frozen structure bodies, no BYOND runtime.
    'radio_shared': {'files': ('tests/radio_shared/test_radio_shared.py',),
        'paths': ('tests/radio_shared/',), 'shared_paths': ('code/modules/1713/radio.dm',)},
    # Rusty bolt effect: metal near strong AM transmitters hums broadcasts.
    'rusty_bolt': {'files': ('tests/rusty_bolt/test_sources.py',),
        'paths': ('tests/rusty_bolt/', 'code/modules/1713/rusty_bolt.dm'), 'shared_paths': (
            'code/modules/1713/radio.dm', 'code/modules/1713/modern_telecom.dm',
            'code/modules/1713/radio_relay.dm')},
    # Copied capture chains in map update_win_condition use capture_step;
    # source parity against the frozen chains, no BYOND runtime.
    'capture_chain': {'files': ('tests/capture_chain/test_capture_chain.py',), 'paths': ('tests/capture_chain/',), 'shared_paths': ('code/game/objects/map_metadata/_map_metadata.dm',
        'code/game/objects/map_metadata/2Fort.dm',
        'code/game/objects/map_metadata/arab_town.dm',
        'code/game/objects/map_metadata/ardennes.dm',
        'code/game/objects/map_metadata/bank_robbery.dm',
        'code/game/objects/map_metadata/barbarossa.dm',
        'code/game/objects/map_metadata/berlin.dm',
        'code/game/objects/map_metadata/caloocan.dm',
        'code/game/objects/map_metadata/campaign_old.dm',
        'code/game/objects/map_metadata/capitol_hill.dm',
        'code/game/objects/map_metadata/czech_border.dm',
        'code/game/objects/map_metadata/drug_bust.dm',
        'code/game/objects/map_metadata/elaia.dm',
        'code/game/objects/map_metadata/fallujah.dm',
        'code/game/objects/map_metadata/grozny.dm',
        'code/game/objects/map_metadata/hill203.dm',
        'code/game/objects/map_metadata/hill_3234.dm',
        'code/game/objects/map_metadata/holdmadrid.dm',
        'code/game/objects/map_metadata/hotel.dm',
        'code/game/objects/map_metadata/intramuros.dm',
        'code/game/objects/map_metadata/iwojima.dm',
        'code/game/objects/map_metadata/lab.dm',
        'code/game/objects/map_metadata/landing_at_constantinopoli.dm',
        'code/game/objects/map_metadata/long_march.dm',
        'code/game/objects/map_metadata/magistral.dm',
        'code/game/objects/map_metadata/marco_polo_bridge.dm',
        'code/game/objects/map_metadata/missionary_ridge.dm',
        'code/game/objects/map_metadata/moscow194.dm',
        'code/game/objects/map_metadata/nanjing.dm',
        'code/game/objects/map_metadata/nankou.dm',
        'code/game/objects/map_metadata/omaha.dm',
        'code/game/objects/map_metadata/ong_thahn.dm',
        'code/game/objects/map_metadata/osowiec.dm',
        'code/game/objects/map_metadata/pavlov_house.dm',
        'code/game/objects/map_metadata/port_arthur.dm',
        'code/game/objects/map_metadata/red_menace.dm',
        'code/game/objects/map_metadata/reichflakturm.dm',
        'code/game/objects/map_metadata/reichstag.dm',
        'code/game/objects/map_metadata/retreat.dm',
        'code/game/objects/map_metadata/rizal_stadium.dm',
        'code/game/objects/map_metadata/rotstadt.dm',
        'code/game/objects/map_metadata/ruhr_uprising.dm',
        'code/game/objects/map_metadata/syria.dm',
        'code/game/objects/map_metadata/tantiveiv.dm',
        'code/game/objects/map_metadata/tsaritsyn.dm',
        'code/game/objects/map_metadata/waco.dm',
        'code/game/objects/map_metadata/warsaw.dm',
        'code/game/objects/map_metadata/yeltsin.dm',
        'code/game/objects/map_metadata/zhenbao.dm',
    )},
    # Piano, violin, shamisen and trumpet share one song player and editor;
    # source contracts against the frozen copies, no BYOND runtime.
    'instrument_song': {'files': ('tests/instrument_song/test_instrument_song.py',), 'paths': ('tests/instrument_song/',),
        'shared_paths': ('code/game/objects/items/devices/instrument_song.dm', 'code/game/objects/items/devices/violin.dm',
                         'code/game/objects/items/devices/shamisen.dm', 'code/game/objects/items/devices/trombone.dm',
                         'code/game/objects/structures/piano.dm')},
    # Fragment grenades, mines and bomb payloads share one fragment ring;
    # source contracts against a frozen grenade copy, no BYOND runtime.
    'fragment_burst': {'files': ('tests/fragment_burst/test_fragment_burst.py',), 'paths': ('tests/fragment_burst/',),
        'shared_paths': ('code/game/objects/items/weapons/grenades/grenade.dm', 'code/game/objects/items/weapons/mines.dm')},
    # Stack pile sprites share pile_suffix and joining walls share
    # join_neighbours; replays frozen copies, no BYOND runtime.
    'pile_icons': {'files': ('tests/pile_icons/test_pile_icons.py',), 'paths': ('tests/pile_icons/',),
        'shared_paths': ('code/game/objects/items/stacks/stack.dm', 'code/game/objects/items/stacks/money.dm',
                         'code/modules/materials/material_sheets.dm', 'code/modules/1713/ores.dm', 'code/game/atoms.dm',
                         'code/game/objects/covers_types/cover_walltypes.dm', 'code/game/objects/structures/barricades.dm',
                         'code/game/objects/structures/window.dm')},
    # Maps dispatch to the shared faction grace wall; run.py is the native
    # equivalence probe against the frozen legacy bodies (manual).
    'grace_wall': {'files': ('tests/grace_wall/test_grace_wall.py',),
        'paths': ('tests/grace_wall/',), 'shared_paths': (
            'code/game/objects/map_metadata/',)},
    # Per-round battle map variation inserts: generator freshness, slot bounds,
    # open-ground placement against the base maps and loader rules; no BYOND runtime.
    'map_variations': {'files': ('tests/map_variations/test_map_variations.py',),
        'paths': ('tests/map_variations/', 'maps/zones/variations/',
                  'code/modules/map_variations/'), 'shared_paths': (
            'maps/1943/smallingrad.dmm', 'maps/1903/hill_203.dmm',
            'code/game/objects/map_metadata/stalingrad.dm',
            'code/game/objects/map_metadata/hill203.dm',
            'code/game/gameticker.dm', 'code/__defines/maps.dm', 'civ13.dme')},
    # Zombie city generator: base map regeneration, placed-type and contract
    # name projection, checker fixtures; no BYOND runtime.
    'zombie_city': {'files': ('tests/zombie_city/test_zombie_city.py',),
        'paths': ('tests/zombie_city/', 'maps/zombie_city/zombie_city.dmm',
                  'code/modules/zombie_city/'), 'shared_paths': (
            'code/__defines/maps.dm', 'civ13.dme')},
    # Live tactical map wiring, permission guards and the client script run in
    # Node (skipped without it); native_probe.py is developer evidence only.
    'tactical_map': {'files': ('tests/tactical_map/test_tactical_map.py',),
        'paths': ('tests/tactical_map/',), 'shared_paths': (
            'code/modules/1713/tactical_map.dm', 'code/game/jobs/job_controller.dm')},
    # Admin map (players, weather and air in one window): wiring, staff guards
    # and the client script run in Node (skipped without it); native_probe.py
    # is developer evidence only.
    'admin_map': {'files': ('tests/admin_map/test_admin_map.py',),
        'paths': ('tests/admin_map/',), 'shared_paths': (
            'code/modules/admin/verbs/admin_map.dm', 'code/modules/1713/tactical_map.dm',
            'code/modules/admin/admin_verbs.dm', 'code/modules/admin/player_panel_pages.dm')},
    # Admin player list and per-player panel: wiring, rank guards, escaping and
    # the list script run in Node (skipped without it); native_probe.py is
    # developer evidence only.
    'admin_player_panel': {'files': ('tests/admin_player_panel/test_admin_player_panel.py',),
        'paths': ('tests/admin_player_panel/', 'code/modules/admin/player_panel_pages.dm'), 'shared_paths': (
            'code/modules/admin/admin_verbs.dm', 'code/modules/admin/topic.dm', 'code/modules/admin/admin.dm')},
    # Admin Hide Ghost / View As Player wiring and guards; offline only.
    'admin_spectate': {'files': ('tests/admin_spectate/test_admin_spectate.py',),
        'paths': ('tests/admin_spectate/',), 'shared_paths': (
            'code/modules/admin/verbs/admin_spectate.dm', 'code/modules/admin/admin_verbs.dm',
            'code/modules/admin/verbs/admin_map.dm', 'code/game/mob/observer/ghost/ghost.dm',
            'code/game/mob/observer/ghost/login.dm')},
    # Research bench intent routing, timed maintenance and slot cleanup; offline only.
    'research_bench': {'files': ('tests/research_bench/test_maintenance.py',),
        'paths': ('tests/research_bench/',), 'shared_paths': (
            'code/modules/research_tree/research_bench.dm',
            'code/modules/research_tree/research_faction.dm',
            'code/modules/research_tree/_research_tree_defines.dm')},
    # Research bench screen and book window wiring; offline only.
    'research_interface': {'files': ('tests/research_interface/test_contract.py',),
        'paths': ('tests/research_interface/',), 'shared_paths': (
            'code/modules/research_tree/book_interface.dm',
            'code/modules/research_tree/book_research.dm',
            'code/modules/research_tree/book_pages.dm',
            'code/modules/research_tree/research_bench.dm')},
    # Research tree groundwork order: real-need prerequisites, skippable side nodes, civil free of military; offline only.
    'research_tree_order': {'files': ('tests/research_tree_order/test_order.py',),
        'paths': ('tests/research_tree_order/',), 'shared_paths': (
            'code/modules/research_tree/research_node.dm',)},
    # Late research: node effects, field work, teams, rushing and ciphers on book-research worlds; offline only.
    'late_research': {'files': ('tests/late_research/test_contract.py',),
        'paths': ('tests/late_research/',), 'shared_paths': (
            'code/modules/research_tree/node_effects.dm',
            'code/modules/research_tree/field_work.dm',
            'code/modules/research_tree/team_research.dm',
            'code/modules/research_tree/book_cipher.dm',
            'code/modules/research_tree/research_node.dm',
            'code/modules/research_tree/research_faction.dm',
            'code/game/objects/farming.dm',
            'code/modules/research_tree/book_pages.dm',
            'code/modules/research_tree/book_research.dm',
            'code/modules/research_tree/book_interface.dm',
            'code/modules/research_tree/research_bench.dm')},
    # Research bench staff appointments and director title; no BYOND runtime.
    'research_staff': {'files': ('tests/research_staff/test_research_staff.py',),
        'paths': ('tests/research_staff/',), 'shared_paths': (
            'code/modules/research_tree/research_bench.dm',
            'code/modules/research_tree/research_faction.dm',
            'code/_helpers/WWinput.dm')},
    # Door hand-intent ladder projected from production DM; no BYOND runtime.
    # Stdlib source check: stance transforms keep the trait size scale.
    'stance_size_transform': {'files': ('tests/stance_size_transform/test_stance_scale.py',),
        'paths': ('tests/stance_size_transform/',), 'shared_paths': (
            'code/_onclick/hud/base_screen_objects.dm',
            'code/game/mob/mob_movement.dm',
            'code/game/mob/living/carbon/human/inventory.dm',
            'code/game/mob/living/carbon/human/update_icons.dm')},
    # Flint mining/knapping source contracts; run.py's native probe is manual.
    'flint_mining': {'files': ('tests/flint_mining/test_flint_mining.py',),
        'paths': ('tests/flint_mining/',), 'shared_paths': (
            'code/modules/1713/flint_mining.dm', 'code/game/turfs/floor_attackby.dm',
            'code/modules/projectiles/_ammo_casing.dm', 'icons/obj/flint_mining.dmi',
            'code/game/objects/structures/blacksmithing/dedicated_workbenches.dm',
            'code/modules/1713/light_fuel.dm')},
    # Obsidian sources, knapping and tools: source contracts only.
    # Tools built into wearable gear: wiring checks; tests/worn_tools/probe.dm is the native probe.
    'worn_tools': {'files': ('tests/worn_tools/test_source.py',),
        'paths': ('tests/worn_tools/',), 'shared_paths': (
            'code/modules/1713/worn_tools.dm', 'code/modules/1713/flint_mining.dm',
            'code/game/objects/items/clothing/clothing.dm', 'code/modules/1713/rain_gear.dm',
            'code/game/objects/items/clothing/clothing_accessories.dm',
            'config/crafting/material_recipes_global.txt', 'code/modules/research_tree/research_node.dm')},
    # Inlaying diamonds into crowns; tests/crown_inlay/probe.dm is the native probe.
    'crown_inlay': {'files': ('tests/crown_inlay/test_source.py',),
        'paths': ('tests/crown_inlay/',), 'shared_paths': (
            'code/modules/1713/apparel_medieval.dm', 'code/modules/1713/gemstones.dm')},
    'obsidian': {'files': ('tests/obsidian/test_source.py',),
        'paths': ('tests/obsidian/',), 'shared_paths': (
            'code/modules/1713/obsidian.dm', 'code/game/turfs/floor_attackby.dm',
            'icons/obj/obsidian.dmi', 'code/modules/research_tree/research_node.dm')},
    # Mountain seams on the Americas maps: map facts and source contracts;
    # native.py's fixture is manual (needs --byond-bin).
    'mountain_seams': {'files': ('tests/mountain_seams/test_source.py',),
        'paths': ('tests/mountain_seams/',), 'shared_paths': (
            'code/modules/1713/mountain_seams.dm', 'code/_helpers/resource_stock.dm',
            'code/game/objects/map_metadata/nomads/nomads_americas.dm',
            'maps/nomads/nomads_americas_north.dmm', 'maps/nomads/nomads_americas_south.dmm')},
    # Provinces that follow the land: committed files, generator, DM reader.
    'provinces': {'files': ('tests/provinces/test_source.py',),
        'paths': ('tests/provinces/', 'maps/provinces/'), 'shared_paths': (
            'scripts/provinces.py', 'scripts/terrain_heights.py', 'code/modules/provinces/provinces.dm',
            'code/modules/provinces/province_stake.dm', 'code/modules/provinces/province_holding.dm',
            'code/game/mob/groups/recruitment_station.dm', 'code/game/mob/groups/faction_start.dm',
            'code/game/mob/groups/factions.dm',
            'maps/nomads/nomads_gaia.dmm', 'maps/nomads/nomads_americas_north.dmm',
            'maps/nomads/nomads_americas_south.dmm', 'maps/nomads/nomads_europe.dmm',
            'maps/nomads/nomads_asia.dmm', 'maps/nomads/nomads_desert.dmm', 'maps/nomads/nomads_jungle.dmm')},
    # Snares, deadfalls, fish weirs and pit traps: source contracts only.
    'stone_age_traps': {'files': ('tests/stone_age_traps/test_source.py',),
        'paths': ('tests/stone_age_traps/',), 'shared_paths': (
            'code/modules/1713/stone_age_traps.dm', 'icons/obj/stone_age_traps.dmi')},
    # Stdlib-only: ship's draughts cost the hand recipes and weigh like the
    # ledger; every part a vehicle editor offers is described.
    'ship_draught': {'files': ('tests/ship_draught/test_draught_sources.py', 'tests/ship_draught/test_design_checks.py'),
        'paths': ('tests/ship_draught/',), 'shared_paths': (
            'code/modules/naval/ship_draught.dm', 'code/modules/naval/hull_load.dm',
            'code/modules/naval/ship_designer.dm', 'scripts/build_ship_designer_icons.py',
            'code/modules/naval/sub_draught.dm', 'code/modules/naval/draught_part_help.dm',
            'code/modules/naval/draught_checks.dm', 'code/modules/craft/design_checks.dm',
            'code/modules/craft/vehicle_checks.dm', 'code/__defines/design_checks.dm',
            'config/crafting/material_recipes_global.txt', 'code/modules/1713/structures.dm',
            'code/modules/space/station_plan.dm', 'code/modules/space/station_plan_checks.dm',
            'code/modules/space/station_designer.dm', 'scripts/build_station_designer_icons.py',
            'icons/station_designer/')},
    # Stdlib-only: train sheets' stock cars cost their kits, every part is
    # described and the rail works is wired. The native probe is probe.dm.
    'train_draught': {'files': ('tests/train_draught/test_train_sheet.py', 'tests/train_draught/test_designer_pictures.py'),
        'paths': ('tests/train_draught/',), 'shared_paths': (
            'code/modules/1713/train_draught.dm', 'code/modules/1713/train_draught_checks.dm',
            'code/modules/1713/train_works.dm', 'code/modules/1713/train_designer.dm',
            'code/modules/naval/draught_kinds.dm', 'code/modules/research_tree/research_node.dm',
            'config/crafting/material_recipes_global.txt', 'icons/obj/vehicles/train_platforms.dmi',
            'docs/train-sheets.md', 'scripts/build_train_designer_icons.py', 'icons/train_designer/')},
    # Stdlib-only: every part the house planner offers is described and costs
    # its recipe, and the window's page is sound. The native probe is run.py.
    'house_plans': {'files': ('tests/house_plans/test_sources.py',),
        'paths': ('tests/house_plans/',), 'shared_paths': (
            'code/game/objects/house_plan.dm', 'code/game/objects/house_plan_checks.dm',
            'code/game/objects/house_designer.dm', 'code/__defines/house_plans.dm',
            'code/game/objects/house_plan_pegs.dm', 'code/game/objects/build_markers.dm',
            'code/__defines/build_markers.dm', 'icons/obj/build_markers.dmi',
            'code/modules/naval/draught_kinds.dm', 'code/modules/naval/ship_draught.dm',
            'code/modules/paintings/design_codes.dm', 'config/crafting/material_recipes_global.txt')},
    # Dugout canoe log stages, sea rules and recipes: source contracts only.
    'dugout_canoe': {'files': ('tests/dugout_canoe/test_source.py',),
        'paths': ('tests/dugout_canoe/',), 'shared_paths': (
            'code/modules/1713/dugout_canoe.dm', 'icons/obj/vehicles/dugout_canoe.dmi')},
    # Wild and tame farm animals, taming by hand feeding: source contracts only.
    'domestication': {'files': ('tests/domestication/test_source.py',),
        'paths': ('tests/domestication/',), 'shared_paths': (
            'code/modules/1713/domestication.dm', 'code/modules/ecology/ecology_spawning.dm',
            'code/game/objects/effects/spawner.dm')},
    # Rock art on natural rock with ground pigments: source contracts only.
    'rock_art': {'files': ('tests/rock_art/test_source.py',),
        'paths': ('tests/rock_art/',), 'shared_paths': (
            'code/modules/1713/rock_art.dm', 'code/modules/paintings/painting_editor.dm')},
    # Deeds carved into tribal totem poles: source contracts only.
    'tribal_deeds': {'files': ('tests/tribal_deeds/test_source.py',),
        'paths': ('tests/tribal_deeds/',), 'shared_paths': (
            'code/modules/1713/tribal_deeds.dm', 'code/modules/1713/dugout_canoe.dm',
            'code/modules/1713/domestication.dm', 'code/modules/1713/rock_art.dm')},
    # Burial mounds, cairns and feasts: source contracts only.
    'stone_age_rites': {'files': ('tests/stone_age_rites/test_source.py',),
        'paths': ('tests/stone_age_rites/',), 'shared_paths': (
            'code/modules/1713/stone_age_rites.dm', 'icons/obj/stone_age_rites.dmi',
            'code/game/objects/items/stacks/stack.dm')},
    # Money changers and a nation's common money (the native probe is tests/money_changer/probe.dm).
    'money_changer': {'files': ('tests/money_changer/test_source.py',),
        'paths': ('tests/money_changer/',), 'shared_paths': (
            'code/modules/1713/money_changer.dm', 'code/game/mob/groups/faction_treasury.dm',
            'code/game/mob/groups/nation.dm', 'tools/transfer_storage/nations.py',
            'config/crafting/material_recipes_global.txt')},
    # Building permits and trading licences (the native probe is tests/faction_permits/probe.dm).
    'faction_permits': {'files': ('tests/faction_permits/test_source.py',),
        'paths': ('tests/faction_permits/',), 'shared_paths': (
            'code/game/mob/groups/faction_permits.dm', 'code/game/mob/groups/faction_papers.dm',
            'code/game/mob/groups/land_registry.dm', 'code/game/objects/items/stacks/craft_guards.dm')},
    # Treaties between factions (the native probe is tests/faction_treaties/probe.dm).
    'faction_treaties': {'files': ('tests/faction_treaties/test_source.py',),
        'paths': ('tests/faction_treaties/',), 'shared_paths': (
            'code/game/mob/groups/faction_treaties.dm', 'code/game/mob/groups/faction_offices.dm',
            'code/game/mob/groups/faction_roster.dm', 'code/game/mob/groups/factions.dm')},
    # Taking a new name (the native probe is tests/name_change/probe.dm).
    'name_change': {'files': ('tests/name_change/test_source.py',),
        'paths': ('tests/name_change/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/name_change.dm', 'code/game/mob/groups/faction_papers.dm',
            'code/game/mob/living/carbon/human/nomads_adoption.dm', 'code/modules/admin/player_panel_pages.dm',
            'code/game/objects/structures/key_doors/fitted_locks.dm', 'code/modules/1713/stone_age_traps.dm',
            'code/modules/craft/craft_register.dm', 'code/modules/persistence/region_travel.dm')},
    # Census, citizenship papers, passes and border doors (the native probe is tests/faction_papers/probe.dm).
    'faction_papers': {'files': ('tests/faction_papers/test_source.py',),
        'paths': ('tests/faction_papers/',), 'shared_paths': (
            'code/game/mob/groups/faction_papers.dm', 'code/game/mob/groups/faction_permits.dm',
            'code/game/objects/structures/key_doors/key_door.dm',
            'code/game/mob/groups/faction_offices.dm', 'code/game/mob/groups/faction_roster.dm',
            'code/game/mob/groups/factions.dm')},
    # Bills of exchange and treasury notes (the native probe is tests/faction_bills/probe.dm).
    'faction_bills': {'files': ('tests/faction_bills/test_source.py',),
        'paths': ('tests/faction_bills/',), 'shared_paths': (
            'code/game/mob/groups/faction_bills.dm', 'code/game/mob/groups/faction_treasury.dm',
            'code/game/mob/groups/faction_roster.dm')},
    # Faction laws, courts, warrants and fines (the native probe is tests/faction_justice/probe.dm).
    'faction_justice': {'files': ('tests/faction_justice/test_source.py',),
        'paths': ('tests/faction_justice/',), 'shared_paths': (
            'code/game/mob/groups/faction_justice.dm', 'code/modules/1713/cmss13_ops.dm',
            'code/game/mob/groups/faction_treasury.dm', 'code/game/mob/groups/factions.dm')},
    # Faction offices, powers and elections (the native probe is tests/faction_offices/probe.dm).
    'faction_offices': {'files': ('tests/faction_offices/test_source.py',),
        'paths': ('tests/faction_offices/',), 'shared_paths': (
            'code/game/mob/groups/faction_offices.dm', 'code/game/mob/groups/factions.dm',
            'code/game/mob/groups/faction_roster.dm', 'code/modules/paperwork/faction_seals.dm',
            'code/modules/1713/coin_mint.dm')},
    # Land registry, boundary stones and deeds (the native probe is tests/land_registry/probe.dm).
    'land_registry': {'files': ('tests/land_registry/test_source.py',),
        'paths': ('tests/land_registry/',), 'shared_paths': (
            'code/game/mob/groups/land_registry.dm', 'code/game/mob/groups/faction_treasury.dm',
            'code/game/mob/groups/faction_roster.dm')},
    # Faction treasury strongboxes, wages and dues (the native probe is tests/faction_treasury/probe.dm).
    'faction_treasury': {'files': ('tests/faction_treasury/test_source.py',),
        'paths': ('tests/faction_treasury/',), 'shared_paths': (
            'code/game/mob/groups/faction_treasury.dm', 'code/modules/1713/marketplace.dm',
            'code/game/mob/groups/faction_roster.dm')},
    # Coin dies, marked coins and debasement (the native probe is tests/coin_mint/probe.dm).
    'coin_mint': {'files': ('tests/coin_mint/test_source.py',),
        'paths': ('tests/coin_mint/',), 'shared_paths': (
            'code/modules/1713/coin_mint.dm', 'code/game/objects/items/stacks/money.dm',
            'code/game/objects/structures/factory/factory.dm')},
    # Trading balance and weighed money (the native probe is tests/weighed_money/probe.dm).
    'weighed_money': {'files': ('tests/weighed_money/test_source.py',),
        'paths': ('tests/weighed_money/',), 'shared_paths': (
            'code/modules/1713/weighed_money.dm', 'code/modules/1713/barter.dm')},
    # Faction seal matrices and Check Seals (the native probe is tests/faction_seals/probe.dm).
    'faction_seals': {'files': ('tests/faction_seals/test_source.py',),
        'paths': ('tests/faction_seals/',), 'shared_paths': (
            'code/modules/paperwork/faction_seals.dm', 'code/modules/paperwork/stamps.dm',
            'code/game/mob/groups/faction_roster.dm')},
    # Bead trade goods and the two-sided barter mat: source contracts only.
    'barter': {'files': ('tests/barter/test_source.py',),
        'paths': ('tests/barter/',), 'shared_paths': (
            'code/modules/1713/barter.dm', 'icons/obj/barter.dmi')},
    # Aqueducts: source contracts (the native probe is tests/aqueducts/probe.dm).
    'aqueducts': {'files': ('tests/aqueducts/test_source.py',),
        'paths': ('tests/aqueducts/',), 'shared_paths': (
            'code/modules/1713/aqueducts.dm', 'icons/obj/aqueducts.dmi', 'tests/sprites/create_aqueducts.py',
            'code/modules/1713/mechanical_power.dm')},
    # Siege engines and castle defences: source contracts (the native probe is tests/siege_engines/probe.dm).
    'siege_engines': {'files': ('tests/siege_engines/test_source.py',),
        'paths': ('tests/siege_engines/',), 'shared_paths': (
            'code/modules/1713/siege/siege_engines.dm', 'code/modules/1713/siege/catapult.dm',
            'code/modules/1713/siege/portcullis_runs.dm', 'code/game/objects/controls.dm',
            'icons/obj/doors/material_doors.dmi', 'icons/obj/siege_engines.dmi', 'icons/obj/trebuchet.dmi', 'icons/obj/siege_tower.dmi',
            'tests/sprites/create_siege_engines.py')},
    # Horse breaking, breeding and shoeing: source contracts (native probe tests/horse_breeding/probe.dm).
    'horse_breeding': {'files': ('tests/horse_breeding/test_source.py',),
        'paths': ('tests/horse_breeding/',), 'shared_paths': (
            'code/modules/1713/horse_breeding.dm', 'icons/mob/animal_64.dmi', 'icons/obj/horseshoes.dmi',
            'code/game/mob/mob_movement.dm', 'code/modules/agent_control/agent_movement.dm')},
    # Mounted charges, braced spears and shield walls: source contracts (native probe tests/mounted_combat/probe.dm).
    'mounted_combat': {'files': ('tests/mounted_combat/test_source.py',),
        'paths': ('tests/mounted_combat/',), 'shared_paths': (
            'code/modules/1713/mounted_combat.dm', 'code/game/objects/items/weapons/shields.dm',
            'code/game/mob/living/carbon/human/human_defense.dm')},
    # Timekeeping and lighthouses: source contracts (native probe tests/timekeeping/probe.dm).
    'timekeeping': {'files': ('tests/timekeeping/test_source.py',),
        'paths': ('tests/timekeeping/',), 'shared_paths': (
            'code/modules/1713/timekeeping.dm', 'icons/obj/timekeeping.dmi', 'icons/obj/lighthouse.dmi',
            'tests/sprites/create_timekeeping.py')},
    # Canals and pound locks: source contracts (native probe tests/canals/probe.dm).
    'canals': {'files': ('tests/canals/test_source.py',),
        'paths': ('tests/canals/',), 'shared_paths': (
            'code/modules/1713/canals.dm', 'code/modules/1713/trench.dm', 'icons/obj/canal_lock.dmi',
            'tests/sprites/create_canal_lock.py')},
    # Lifts between storeys: source contracts and sprite check (native probe tests/lifts/probe.dm).
    'lifts': {'files': ('tests/lifts/test_source.py',),
        'paths': ('tests/lifts/',), 'shared_paths': (
            'code/modules/multiz/lifts.dm', 'icons/obj/lifts.dmi', 'tests/sprites/create_lifts.py')},
    # Chimneys carrying heat upstairs: source contracts and sprite check (native probe tests/storey_chimney/probe.dm).
    'storey_chimney': {'files': ('tests/storey_chimney/test_source.py',),
        'paths': ('tests/storey_chimney/',), 'shared_paths': (
            'code/game/objects/storey_chimney.dm', 'icons/obj/storey_fittings.dmi', 'tests/sprites/create_storey_fittings.py')},
    # Shooting down from an upper storey: source contracts (native probe tests/storey_fire/probe.dm).
    'storey_fire': {'files': ('tests/storey_fire/test_source.py',),
        'paths': ('tests/storey_fire/',), 'shared_paths': ('code/modules/projectiles/storey_fire.dm',)},
    # Storey stores (loft drying, upstairs mice, flood rot): source contracts (native probe tests/storey_stores/probe.dm).
    'storey_stores': {'files': ('tests/storey_stores/test_source.py',),
        'paths': ('tests/storey_stores/',), 'shared_paths': ('code/modules/1713/storey_stores.dm',)},
    # Cool cellars: source contracts (native probe tests/cool_cellars/probe.dm).
    'cool_cellars': {'files': ('tests/cool_cellars/test_source.py',),
        'paths': ('tests/cool_cellars/',), 'shared_paths': ('code/modules/1713/cool_cellars.dm',)},
    # Animal fat as light fuel, the grease horn and the stone fat lamp: source contracts (native probe tests/fat_lights/probe.dm).
    'fat_lights': {'files': ('tests/fat_lights/test_source.py',),
        'paths': ('tests/fat_lights/',), 'shared_paths': (
            'code/modules/1713/fat_lights.dm', 'code/modules/1713/light_fuel.dm', 'code/modules/1713/lantern.dm',
            'code/modules/1713/animal_harvest.dm', 'icons/obj/fat_lights.dmi', 'tests/sprites/create_fat_lights.py')},
    # Clay tablets, board games and the ice house: source contracts (native probe tests/small_ancient/probe.dm).
    'small_ancient': {'files': ('tests/small_ancient/test_source.py',),
        'paths': ('tests/small_ancient/',), 'shared_paths': (
            'code/modules/1713/small_ancient.dm', 'icons/obj/small_ancient.dmi', 'tests/sprites/create_small_ancient.py')},
    # Sewers phase S1: source contracts (the native probe is tests/sewers/probe.dm).
    'sewers': {'files': ('tests/sewers/test_sewers.py',),
        'paths': ('tests/sewers/',), 'shared_paths': (
            'code/modules/1713/sewers.dm', 'code/modules/1713/flood_hollows.dm', 'icons/obj/sewers.dmi', 'tests/sprites/create_sewers.py',
            'code/game/objects/structures/watercloset.dm', 'code/game/mob/living/carbon/human/shit_piss.dm')},
    # Bone flute, frame drum, flint sickle and bison herds: source contracts only.
    'stone_age_extras': {'files': ('tests/stone_age_extras/test_source.py',),
        'paths': ('tests/stone_age_extras/',), 'shared_paths': (
            'code/modules/1713/stone_age_extras.dm', 'icons/obj/stone_age_extras.dmi',
            'code/modules/1713/processing_recipes.dm')},
    'door_intents': {'files': ('tests/door_intents/test_door_intents.py', 'tests/door_intents/test_jail_keys.py'),
        'paths': ('tests/door_intents/',), 'shared_paths': (
            'code/game/objects/structures/door.dm',
            'code/modules/persistence/world_time_stamps.dm',
            'code/game/objects/structures/key_doors/key_door.dm',
            'tests/save_movement/source_adapter.py')},
    # Map merge/lint tooling ported from CM-SS13 and scripts/maplint.py over
    # every map; standard library only, no BYOND runtime.
    'map_tools': {'files': ('tests/map_tools/test_map_tools.py',),
        'paths': ('tests/map_tools/', 'tools/mapmerge2/', 'tools/UpdatePaths/',
                  'tools/hooks/', 'tools/dmi/', 'scripts/maplint.py'), 'shared_paths': (
            'maps/', '.gitattributes')},
    # Day/night sweep loop-shape contracts; no BYOND runtime.
    # Held-key smooth movement continuation contracts; no BYOND runtime.
    'held_movement': {'files': ('tests/held_movement/test_held_movement.py',),
        'paths': ('tests/held_movement/',), 'shared_paths': (
            'code/movementMachine.dm', 'code/game/mob/mob_movement.dm',
            'code/game/mob/living/carbon/human/subtile_movement.dm')},
    'zombie_spawn_selection': {'files': ('tests/zombie_spawn_selection/test_selection.py',),
        'paths': ('tests/zombie_spawn_selection/',), 'shared_paths': (
            'code/game/objects/effects/spawner.dm', 'tests/save_movement/source_adapter.py')},
    'sweep_loops': {'files': ('tests/sweep_loops/test_sweep_loops.py',),
        'paths': ('tests/sweep_loops/',), 'shared_paths': (
            'code/processes/time_of_day_change.dm',
            'code/game/turfs/flooring/flooring_premade.dm',
            'code/processes/soil_recovery.dm', 'code/processes/__processes.dm',
            'code/game/objects/farming.dm', 'civ13.dme')},
    # Nomads adoption source contracts and surname model; no BYOND runtime.
    'nomads_adoption': {'files': ('tests/nomads_adoption/test_nomads_adoption.py',),
        'paths': ('tests/nomads_adoption/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/nomads_adoption.dm',
            'code/_helpers/unsorted.dm', 'civ13.dme')},
    # Stream save helper (tools/savestream): compiles the 64-bit helper with the
    # host C compiler and drives its pipe protocol; no BYOND runtime.
    'savestream': {'files': ('tests/savestream/test_helper.py',),
        'paths': ('tests/savestream/', 'tools/savestream/'), 'shared_paths': (
            'code/modules/persistence/stream/save_stream.dm', 'savestream.dll', 'savestream_helper.exe')},
    # Agent control client/MCP/catalog and DM source contracts; loopback fake
    # Topic server only, no BYOND runtime.
    'agent_control': {'files': ('tests/agent_control/test_agent_control.py',
            'tests/agent_control/test_perception_replay.py',
            'tests/agent_control/test_visibility.py',
            'tests/agent_control/test_action_contract.py',
            'tests/agent_control/test_navigation_replay.py',
            'tests/agent_control/test_needs_routines.py',
            'tests/agent_control/test_voice.py',
            'tools/agent-control/benchmarks/test_gateway_benchmark.py'),
        'paths': ('tests/agent_control/', 'tools/agent-control/', 'code/modules/agent_control/'), 'shared_paths': (
            'code/_helpers/admin.dm', 'code/world.dm', '.gitignore')},
    # Map and sprite review git/summary logic on a temporary repository; the
    # byond-devtools parts skip here and run in the map-review workflow.
    'map_review': {'files': ('tests/map_review/test_map_review.py',),
        'paths': ('tests/map_review/', 'scripts/map_review.py', 'scripts/sprite_review.py'),
        'shared_paths': ('.github/workflows/map-review.yml', '.github/workflows/sprite-review.yml')},
    # CI digest classifier/renderer and workflow contract; fake GitHub API only,
    # no network or BYOND runtime.
    # Offline forgery checks for the local CI attestation gate; no network.
    'local_ci': {'files': ('tests/local_ci/test_local_ci.py',),
        'paths': ('tests/local_ci/', 'scripts/local_ci.py', 'tools/ci/'), 'shared_paths': (
            '.github/workflows/',)},
    'agent_ci_digest': {'files': ('tests/agent_ci_digest/test_ci_digest.py',),
        'paths': ('tests/agent_ci_digest/', 'scripts/ci_digest.py'), 'shared_paths': (
            '.github/workflows/',)},
    # Water quality by kind, washing fixes and flea typhus; source checks only.
    'water_quality': {'files': ('tests/water_quality/test_water_quality.py',),
        'paths': ('tests/water_quality/', 'code/modules/1713/water_quality.dm'), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_needs.dm',
            'code/game/objects/items/soap.dm',
            'code/game/objects/structures/watercloset.dm',
            'code/game/turfs/floor_attackby.dm',
            'code/modules/1713/factory_pipes.dm',
            'code/__defines/mobs.dm')},
    # Dirt from work and dirty hands; source checks only.
    'hygiene_work': {'files': ('tests/hygiene_work/test_hygiene_work.py',),
        'paths': ('tests/hygiene_work/', 'code/modules/1713/hygiene_work.dm', 'code/modules/1713/bathing.dm', 'code/modules/1713/body_washing.dm'), 'shared_paths': (
            'code/modules/1713/practice_rooms.dm', 'tools/agent-control/autopilot.py',
            'code/game/objects/structures/watercloset.dm',
            'code/modules/reagents/reagent_containers.dm',
            'code/__defines/mobs.dm',
            'code/modules/1713/animal_harvest.dm',
            'code/game/mob/living/carbon/human/human_needs.dm')},
    # Station water tanks and running water feeds; source checks only.
    'station_water': {'files': ('tests/station_water/test_station_water.py',),
        'paths': ('tests/station_water/', 'code/modules/1713/station_water.dm', 'code/modules/1713/quench_tub.dm',
            'code/modules/1713/wash_places.dm', 'code/game/mob/living/carbon/human/home_comfort.dm'), 'shared_paths': (
            'code/modules/1713/aqueducts.dm',
            'code/modules/1713/factory_plumbing.dm',
            'config/craft_needs.json',
            'code/modules/1713/clay_lime_fire.dm')},
    # Reviewed stdlib-only well-odor source projection; no BYOND runtime.
    'well_smell': {'files': ('tests/well_smell/test_well_smell.py',),
        'paths': ('tests/well_smell/',), 'shared_paths': (
            'code/game/objects/structures/watercloset.dm',
            'code/game/mob/living/carbon/human/shit_piss.dm')},
    # Balanced diet taxonomy reachability and source contracts; imports only the
    # side-effect-free native runner for its mutation table, never launches it.
    'balanced_diet': {'files': ('tests/balanced_diet/test_balanced_diet.py',),
        'paths': ('tests/balanced_diet/', 'code/modules/diet/'), 'shared_paths': (
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/objects/structures/kitchen/cooked_meals.dm',
            'code/modules/reagents/reagent_containers/food/grown.dm',
            'code/modules/reagents/reagent_containers/food/snacks.dm',
            'code/modules/reagents/reagent_containers/food/snacks/meat.dm',
            'code/game/objects/structures/berries.dm',
            'code/game/mob/living/simple_animal/friendly/birds.dm',
            'code/modules/1713/beekeeping.dm', 'code/datums/mind.dm', 'civ13.dme')},

    # Explicit stdlib-only crafting policy/source checks; never imports a runner.
    # Shared inputs retain existing conservative offline fallback semantics.
    'crafting_ui_contracts': {'files': ('tests/human_subtile/test_crafting_ui.py',),
        'paths': ('tests/human_subtile/crafting_ui_contracts.json',
                  'tests/human_subtile/crafting_gather_baseline.json'),
        'shared_paths': (
            'code/game/objects/items/stacks/stack.dm', 'code/game/mob/crafting_atlas.dm',
            'code/datums/browser.dm', 'interface/skin.dmf', 'code/_helpers/mobs.dm',
            'code/game/mob/living/carbon/human/subtile_movement.dm',
            'code/game/mob/mob_movement.dm', 'code/game/turfs/floor_attackby.dm',
            'code/modules/gameplay_bridge/bridge.dm',
            'code/modules/gameplay_bridge/mechanics.dm',
            'scripts/gameplay_bridge/gather_context.py', 'tests/human_subtile/crafting_ui.dm')},
    # Complete capacity/wait and selected Sleep-prefix projections; no engine.
    'sleep_resting': {'files': ('tests/sleep_resting/test_sleep_resting.py',),
        'paths': ('tests/sleep_resting/',), 'shared_paths': (
            'code/__defines/mobs.dm', 'code/game/mob/mob.dm',
            'code/_helpers/mobs.dm',
            'code/game/mob/living/carbon/human/human_helpers.dm',
            'tests/save_movement/source_adapter.py')},

    # Source-projected pouch-slot HUD visibility; no BYOND or browser runner.
    'pouch_hud': {'files': ('tests/pouch_hud/test_pouch_hud.py',),
        'paths': ('tests/pouch_hud/',), 'shared_paths': (
            'code/_onclick/hud/base_screen_objects.dm', 'code/_onclick/hud/hud_civstyle.dm',
            'code/game/mob/living/carbon/human/update_icons.dm',
            'code/game/mob/living/carbon/human/inventory.dm', 'code/game/mob/inventory.dm',
            'code/game/mob/living/carbon/human/species/species_hud.dm',
            'code/game/objects/items.dm', 'code/modules/1713/apparel_imperial.dm',
            'interface/skin.dmf', 'scripts/select-ci.py', 'tests/save_movement/source_adapter.py')},

    # Source-projected storage-session and legacy import contracts; no BYOND run.
    'storage_runtime': {'files': ('tests/storage_runtime/test_storage_runtime.py',),
        'paths': ('tests/storage_runtime/',), 'shared_paths': (
            'code/game/objects/items/weapons/storage/storage.dm',
            'code/game/mob/login.dm', 'code/game/mob/living/carbon/human/human_helpers.dm',
            'code/modules/persistence/bed_return.dm', 'code/modules/persistence/functions.dm',
            'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm',
            'tests/save_movement/source_adapter.py', 'scripts/select-ci.py')},

    # Reviewed stdlib-only hand-placement source projection; no native world.
    'axe_active_hand': {'files': ('tests/axe_active_hand/test_axe_active_hand.py',),
        'paths': ('tests/axe_active_hand/',), 'shared_paths': (
            'code/game/objects/items/stacks/stack.dm',
            'code/game/objects/items/weapons/material/ooga_booga_weapons.dm',
            'code/game/objects/items.dm', 'code/game/mob/inventory.dm',
            'code/game/mob/living/carbon/human/human.dm', 'tests/crafting/handles.dm')},

    # Stdlib-only native fixture preparation/protocol/supervisor contracts.
    # No compiler, daemon, client, workflow dispatch or installer execution.
    'tree_refresh_native_preparation': {'files': ('tests/tree_refresh_native/test_harness.py',
                                                  'tests/tree_refresh_native/test_d3dx_data.py'),
        'paths': ('tests/tree_refresh_native/',), 'shared_paths': (
            '.github/workflows/tree-refresh-native.yml',
            'tests/human_subtile/run.py', 'tests/human_subtile/run-npc.py',
            'tests/human_subtile/run-diagonal.py', 'tests/human_subtile/probe.dm',
            'tests/human_subtile/native_1688/windows.py',
            'tests/human_subtile/native_1688/owned_job.py',
            'tests/human_subtile/native_1688/guard_config.py', 'scripts/native_fixture.py',
            'tools/byond/version.json', 'tools/byond/d3dx-package.json',
            'code/game/mob/mob_movement.dm',
            'code/datums/observation/moved.dm', 'code/modules/client/client_procs.dm',
            'code/modules/visibility/los_context.dm', 'code/modules/visibility/los_lifecycle.dm',
            'code/modules/visibility/los_presenter.dm', 'code/modules/visibility/root_tree_presenter.dm',
            'code/modules/visibility/root_light_snapshot.dm',
            'code/modules/lighting/lighting_overlay.dm')},
    # Complete selected anvil admission/message projection; no native world.
    'anvil_feedback': {'files': ('tests/anvil_feedback/test_feedback.py',),
        'paths': ('tests/anvil_feedback/',), 'shared_paths': (
            'code/game/objects/structures/blacksmithing/blacksmithing.dm',
            'code/game/mob/living/carbon/human/human_stats.dm',
            'code/modules/1713/modern_telecom.dm',
            'tests/save_movement/source_adapter.py')},

    # Bone armor stays craftable in every era with its stone-age protection; source checks only.
    'bone_armor': {'files': ('tests/bone_armor/test_bone_armor.py',),
        'paths': ('tests/bone_armor/',), 'shared_paths': (
            'config/crafting/', 'code/modules/1713/apparel_stoneage.dm', 'code/__defines/maps.dm')},

    # Lifetime accolades: catalog, hooks, once-per-account claims, window guard; source checks only.
    'accolades': {'files': ('tests/accolades/test_accolades.py',),
        'paths': ('tests/accolades/',), 'shared_paths': (
            'code/modules/accolades/', 'code/processes/accolades.dm', 'docs/accolades.md',
            'code/modules/client/player_tutorial.dm', 'code/modules/naval/ship_voyage.dm',
            'code/modules/persistence/bed_return.dm', 'code/modules/persistence/region_travel.dm',
            'code/modules/research_tree/character_knowledge.dm', 'code/modules/research_tree/research_faction.dm',
            'code/modules/admin/admin_verbs.dm', 'code/modules/admin/accolades_admin.dm',
            'code/game/objects/items/cartography_notes.dm', 'code/modules/research_tree/book_research.dm',
            'code/modules/1713/book.dm', 'code/game/objects/items/stacks/stack.dm',
            'code/game/objects/structures/blacksmithing/refining.dm', 'code/modules/1713/tatara.dm',
            'code/modules/research_tree/field_work.dm', 'code/modules/1713/domestication.dm',
            'code/modules/1713/complex_animal/_backend.dm', 'code/game/mob/living/simple_animal/simple_animal.dm',
            'code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm',
            'code/modules/1713/machinery/modular_vehicles/aircraft/helicopter.dm',
            'code/game/mob/groups/faction_creation.dm', 'code/modules/provinces/province_siege.dm',
            'code/modules/nomad_raids/nomad_visit.dm')},

    # Character slot owner keys (docs/character-slots.md); source checks only.
    'character_slots': {'files': ('tests/character_slots/test_owner_keys.py', 'tests/character_slots/test_switching.py',
        'tests/character_slots/test_structuring.py',
        'tests/character_slots/test_account_summary.py'),
        'paths': ('tests/character_slots/',), 'shared_paths': (
            'docs/character-slots.md', 'code/modules/persistence/player_reclaim.dm',
            'code/modules/persistence/bed_return.dm', 'code/modules/persistence/region_home.dm',
            'code/modules/persistence/region_travel.dm', 'code/modules/persistence/region_event.dm',
            'code/modules/persistence/party_train.dm', 'code/modules/research_tree/death_legacy.dm',
            'code/game/objects/map_metadata/nomads/nomads_start.dm', 'code/modules/accolades/accolades.dm',
            'code/modules/karma/karma_give.dm', 'code/modules/divine/magic_whitelist.dm',
            'code/modules/player_activity/player_activity.dm', 'code/modules/admin/verbs/research_knowledge.dm',
            'code/game/mob/groups/nation.dm', 'tools/transfer_storage/region.py',
            'code/modules/accolades/character_slots.dm', 'code/game/mob/new_player/login.dm',
            'code/modules/admin/accolades_admin.dm', 'code/game/mob/groups/faction_membership.dm',
            'code/game/mob/groups/faction_creation.dm', 'code/game/mob/groups/faction_justice.dm',
            'code/modules/provinces/province_holding.dm', 'code/modules/provinces/province_blocs.dm',
            'code/modules/admin/province_blocs_admin.dm', 'tools/transfer_storage/records.py',
            'scripts/shard-group/shard_group.py')},

    # Razor grooming guard, hygiene-gated razor recipes and hair regrowth pace; source checks only.
    'razor_grooming': {'files': ('tests/razor_grooming/test_razor.py', 'tests/razor_grooming/test_hair_growth.py'),
        'paths': ('tests/razor_grooming/',), 'shared_paths': (
            'code/game/objects/items/weapons/material/misc.dm',
            'code/game/objects/items/weapons/material/kitchen.dm',
            'code/game/objects/items/weapons/material/haircut_window.dm',
            'config/crafting/material_recipes_global.txt',
            'code/modules/research_tree/research_node.dm',
            'code/modules/research_tree/book_pages.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/modules/persistence/region_travel.dm')},

    # Stdlib-only startup loader projection with inert file/log boundaries.
    # Existing startup/source-adapter coverage is retained additively.
    'crafting_loader': {'files': ('tests/crafting_loader/test_loader.py',
                                'tests/crafting_loader/test_supplied_item_recipes.py',
                                'tests/crafting_loader/test_basic_clothing.py',
                                'tests/crafting_loader/test_production_machines.py',
                                'tests/crafting_loader/test_radio_headset.py'),
        'paths': ('tests/crafting_loader/',), 'shared_paths': (
            'code/setup.dm', 'tests/save_movement/source_adapter.py',
            'code/modules/research_tree/research_node.dm',
            'config/crafting/material_recipes_global.txt',
            'code/modules/1713/radio.dm', 'icons/mob/ears.dmi')},

    # Stdlib-only access-file framing and complete helper-body projection.
    'access_lists': {'files': ('tests/access_lists/test_access_lists.py',),
        'paths': ('tests/access_lists/',),
        'shared_paths': ('code/_helpers/access_lists.dm', 'code/setup.dm', 'code/world.dm',
                   'code/modules/admin/admin.dm', 'code/game/mob/new_player/new_player.dm',
                   'civ13.dme', 'tests/save_movement/source_adapter.py')},

    # Discord account keys (source projection) and the stdlib sign-in service
    # against a fake Discord; the HTTP test binds an ephemeral loopback port.
    'account_signin': {'files': ('tests/account_signin/test_signin.py',
                                 'tests/account_signin/test_account_keys.py',
                                 'tests/account_signin/test_discord_verify.py'),
        'paths': ('tests/account_signin/', 'tools/account_signin/'),
        'shared_paths': ('code/modules/accounts/discord_accounts.dm', 'code/modules/client/discord_verify.dm', 'code/modules/client/client_procs.dm',
                         'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/region_travel.dm',
                         'tests/save_movement/source_adapter.py')},

    'ecology_visibility': {'files': ('tests/ecology_spawning/test_visibility.py',),
        'paths': ('tests/ecology_spawning/test_visibility.py',),
        'shared_paths': ('code/modules/ecology/ecology_spawning.dm', 'tests/save_movement/source_adapter.py')},

    'hostile_patrol_waypoints': {'files': ('tests/hostile_patrol/test_waypoint_selection.py',),
        'paths': ('tests/hostile_patrol/',),
        'shared_paths': ('code/game/mob/living/simple_animal/hostile/humans/human.dm',
                         'tests/save_movement/source_adapter.py')},
    'satellite_station_selection': {'files': ('tests/satellite_station/test_station_selection.py',),
        'paths': ('tests/satellite_station/',), 'shared_paths': (
            'code/modules/space/satellites.dm', 'tests/save_movement/source_adapter.py')},

    # Offline ownership, continuation and source controls; the one Git process
    # runs only against a freshly created synthetic test repository. No BYOND run.
    'wildlife_offline': {'files': (
        'tests/animal_combat/test_predator_feeding.py',
        'tests/ecology_spawning/test_mob_guard.py',
        'tests/human_subtile/test_insect_cadence_candidate.py',
        'tests/human_subtile/test_insect_idle_slot.py',
        'tests/human_subtile/test_npc.py',
        'tests/human_subtile/test_npc_completion.py',
        'tests/human_subtile/test_npc_contact_food.py',
        'tests/human_subtile/test_npc_flee.py',
        'tests/human_subtile/test_npc_follow.py',
        'tests/human_subtile/test_npc_intent.py',
        'tests/human_subtile/test_npc_mutation_hooks.py',
        'tests/human_subtile/test_npc_pending.py',
        'tests/human_subtile/test_npc_pet.py',
        'tests/human_subtile/test_npc_pursuit.py',
        'tests/human_subtile/test_npc_recovery.py',
        'tests/human_subtile/test_npc_species.py',
        'tests/human_subtile/test_npc_wild_walk.py',
        'tests/human_subtile/test_vendor_legacy_integrated.py',
        'tests/human_subtile/test_wild_handoff.py',
        'tests/human_subtile/test_wildlife_integration_reconcile.py',
        'tests/test_wildlife_ci_registration.py',
        'tests/wildlife_arrival/test_check.py',
    ), 'paths': (), 'shared_paths': (
        'code/processes/mob.dm', 'code/game/mob/living/simple_animal/', 'code/game/mob/living/living.dm',
        'code/game/mob/mob_movement.dm', 'code/game/atoms.dm',
        'code/game/mob/living/carbon/human/human.dm',
        'code/game/mob/living/carbon/human/human_life.dm',
        'code/game/objects/structures/vending/npc_vendors.dm',
        'code/game/objects/structures/railing.dm', 'code/game/objects/structures/table.dm',
        'code/game/objects/structures/window.dm',
        'code/modules/1713/machinery/modular_vehicles/frame.dm',
        'code/modules/1713/structures.dm', 'tests/save_movement/source_adapter.py',
        'tests/human_subtile/scheduler_core_draft.dm', 'tests/human_subtile/run-npc.py',
        'tests/human_subtile/run-diagonal.py', 'tests/human_subtile/run.py',
        'tests/human_subtile/probe.dm', 'scripts/native_fixture.py',
        'tests/wildlife_arrival/')},
    # Stdlib-only native-fixture composition/receipt contracts; never launches BYOND.
    'mount_native_preparation': {'files': ('tests/mount_lifecycle_native/test_prepare.py',
                                         'tests/mount_lifecycle_native/test_runner.py',
                                         'tests/mount_lifecycle_native/test_hosted_entry.py'),
        'paths': ('tests/mount_lifecycle_native/',), 'shared_paths': (
            'code/game/mob/living/simple_animal/riding.dm',
            'code/game/mob/living/simple_animal/simple_animal.dm',
            'code/game/mob/living/carbon/human/human.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'tests/human_subtile/run-npc.py', 'tests/human_subtile/run-diagonal.py',
            'tests/human_subtile/run.py', 'tests/human_subtile/probe.dm',
            'scripts/native_fixture.py', 'tools/byond/version.json',
            'tests/movement_save_chunks/human_spatial_run.py',
            'tests/movement_save_chunks/benchmark.py',
            'tests/movement_save_chunks/human_spatial_stage.py',
            'tests/nomads_lifecycle/run_variable_probe_linux.py',
            'tests/nomads_lifecycle/run_variable_probe.py',
            'tests/world_save/current_runtime.py', 'scripts/byond_runtime.py',
            '.github/workflows/mount-lifecycle-native.yml',
            'tests/save_movement/source_adapter.py')},
    # Stdlib-only source contracts and causal omission controls; no native world.
    # Shared game/Atlas/Help sources retain the existing conservative fallback.
    'cloth_substitution': {'files': ('tests/cloth_substitution/test_source.py',), 'paths': (
        'tests/cloth_substitution/', 'tests/crafting/woolcloth.dm', 'code/game/objects/items/stacks/cloth_crafting.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'stone_molds': {'files': ('tests/stone_molds/test_source.py',), 'paths': (
        'tests/stone_molds/',), 'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'legacy_computer_panels': {'files': (
        'tests/legacy_program_session/test_authority.py',
        'tests/legacy_computer_mail/test_defensive_rendering.py',
        'tests/legacy_deepnet_orders/test_seller_authority.py',
        'tests/legacy_nile_orders/test_seller_authority.py'), 'paths': (
        'tests/legacy_program_session/', 'tests/legacy_computer_mail/',
        'tests/legacy_deepnet_orders/', 'tests/legacy_nile_orders/',
        'code/modules/1713/computers/'), 'shared_paths': ('tests/save_movement/source_adapter.py',)},
    # Stdlib-only order checks: prompt paths re-check before paying (lagged repeat clicks).
    'repeat_click_payment': {'files': ('tests/repeat_click_payment/test_source.py',), 'paths': (
        'tests/repeat_click_payment/',), 'shared_paths': ('tests/save_movement/source_adapter.py',
        'code/game/objects/structures/blacksmithing/molds.dm',
        'code/modules/1713/machinery/modular_vehicles/frame_parts.dm',
        'code/modules/1713/machinery/modular_vehicles/ships/frame_parts.dm',
        'code/modules/1713/machinery/engines/engines.dm', 'code/modules/projectiles/ammo_crafting.dm',
        'code/modules/1713/structures.dm', 'code/game/objects/structures/plant_pots.dm',
        'code/modules/1713/computers/programs.dm', 'code/game/objects/map_metadata/pepelsibirsk.dm',
        'code/game/objects/map_metadata/colonia.dm', 'code/modules/1713/researchcost.dm',
        'code/game/objects/structures/bookcase.dm', 'code/game/objects/structures/roulette_table.dm',
        'code/game/objects/covers_types/covers_buildable.dm', 'code/modules/1713/trench.dm',
        'code/game/objects/structures/vending/vending_sales.dm',
        'code/game/objects/items/weapons/grenades/grenade.dm', 'code/modules/1713/production.dm')},
    # Stdlib-only document model/language projections with inert engine seams.
    # No speech/learning callbacks, UI, native process or savefile execution.
    # Production inputs stay unmapped to preserve the all-suite fallback.
    'paper_documents': {'files': ('tests/paper_documents/test_documents.py',
                                  'tests/paper_documents/test_views.py',
                                  'tests/paper_documents/test_mutations.py',
                                  'tests/paper_documents/test_copying.py',
                                  'tests/paper_documents/test_authoring.py',
                                  'tests/paper_documents/test_lifecycle.py',
                                  'tests/paper_documents/test_editor.py',
                                  'tests/paper_documents/test_study.py',
                                  'tests/paper_documents/test_stamps.py',
                                  'tests/paper_documents/test_forms.py',
                                  'tests/paper_documents/test_bundle_actions.py'),
        'paths': ('tests/paper_documents/',)},
    # Stdlib-only human Destroy layers and admission with inert effect boundaries.
    'rider_deletion': {'files': ('tests/rider_deletion/test_destroy.py',),
        'paths': ('tests/rider_deletion/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human.dm', 'code/game/mob/living/carbon/carbon.dm',
            'civ13.dme', 'code/processes/garbage.dm', 'code/__defines/qdel.dm',
            'tests/save_movement/source_adapter.py')},
    # Stdlib-only Destroy, canonical macro and qdel-admission projections.
    'mount_deletion': {'files': ('tests/mount_deletion/test_destroy.py',),
        'paths': ('tests/mount_deletion/',), 'shared_paths': (
            'code/game/mob/living/simple_animal/simple_animal.dm', 'code/processes/garbage.dm',
            'code/__defines/qdel.dm', 'tests/save_movement/source_adapter.py')},
    # Stdlib-only complete distance branch with inert movement/icon boundaries.
    'mount_distance': {'files': ('tests/mount_distance/test_distance.py',),
        'paths': ('tests/mount_distance/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/human_life.dm', 'tests/save_movement/source_adapter.py')},
    # Stdlib-only riding death and admission projections with inert callbacks.
    'mount_lifecycle': {'files': ('tests/mount_lifecycle/test_death.py',),
        'paths': ('tests/mount_lifecycle/',), 'shared_paths': (
            'code/game/mob/living/simple_animal/riding.dm',
            'code/game/mob/living/simple_animal/simple_animal.dm',
            'code/game/mob/living/damage_procs.dm',
            'code/game/mob/living/carbon/human/subtile_movement.dm',
            'code/modules/persistence/bed_return.dm', 'tests/save_movement/source_adapter.py')},
    # Stdlib-only complete destruction-layer projection; frozen source is data.
    'ladder_cleanup': {'files': ('tests/ladder_cleanup/test_destroy.py',),
        'paths': ('tests/ladder_cleanup/',), 'shared_paths': (
            'code/modules/multiz/structures.dm', 'tests/save_movement/source_adapter.py')},
    # Stdlib + reviewed source projection with inert recipients and event queue.
    # No native fixture, process, network or live message transport is imported.
    'flamethrower_fire_guard': {'files': ('tests/flamethrower_fire/test_incapacitated.py',),
        'paths': ('tests/flamethrower_fire/',), 'shared_paths': (
            'code/modules/1713/weapons/flamethrower.dm', 'tests/save_movement/source_adapter.py')},
    'skullisland_grace_transfer': {'files': ('tests/skullisland_grace/test_grace_transfer.py',),
        'paths': ('tests/skullisland_grace/',), 'shared_paths': (
            'code/game/objects/map_metadata/skullisland.dm', 'tests/save_movement/source_adapter.py')},
    'wired_pole_traversal': {'files': ('tests/telephone/test_pole_traversal.py',),
        'paths': ('tests/telephone/test_pole_traversal.py',), 'shared_paths': (
            'code/modules/1713/telegraph.dm', 'tests/save_movement/source_adapter.py')},
    'telephone_recipients': {'files': ('tests/telephone/test_recipients.py',),
        'paths': ('tests/telephone/',), 'shared_paths': (
            'code/modules/1713/telephone.dm', 'tests/save_movement/source_adapter.py')},

    # Stdlib + reviewed source projection only; frozen DM is offline data.
    # No native runner, engine process, socket or network boundary is imported.
    'defibrillator_charge': {'files': ('tests/defibrillator/test_charge_revalidation.py',
                                     'tests/defibrillator/test_revival_outcome.py'),
        'paths': ('tests/defibrillator/',), 'shared_paths': (
            'code/game/objects/items/weapons/defib.dm', 'tests/save_movement/source_adapter.py')},
    'vehicle_hud': {'files': ('tests/vehicle_hud/test_driver_axis.py',),
        'paths': ('tests/vehicle_hud/',), 'shared_paths': (
            'code/_onclick/hud/hud_vehicles.dm', 'tests/save_movement/source_adapter.py')},
    # Stdlib-only admin care/appearance source contracts. Shared inputs retain
    # their existing conservative fallback and other suites' ownership.
    'admin_player_care': {'files': ('tests/admin_player_care/test_player_care.py',
                                   'tests/admin_player_care/test_hud_refresh.py'),
        'paths': ('tests/admin_player_care/',), 'shared_paths': (
            'code/modules/admin/admin_verbs.dm', 'code/modules/admin/verbs/random_verbs.dm',
            'code/game/mob/update_icons.dm',
            'code/game/mob/living/carbon/human/update_icons.dm',
            'code/game/mob/living/carbon/human/human_hud.dm',
            'code/game/mob/living/carbon/human/human.dm',
            'code/game/mob/living/carbon/human/human_organs.dm',
            'code/game/mob/living/carbon/human/human_needs.dm',
            'code/game/mob/living/carbon/carbon_defines.dm',
            'code/game/mob/living/living_hud.dm',
            'code/game/mob/living/living.dm', 'code/game/mob/mob.dm',
            'code/game/mob/observer/ghost/ghost.dm',
            'code/game/objects/items/weapons/defib.dm',
            'code/modules/client/ui_style.dm', 'code/modules/organs/organ_external.dm',
            'code/modules/visibility/root_tree_presenter.dm', '.github/workflows/test.yml')},
    # Stdlib-only source projection and bounded RGBA8 PNG/DMI inspection.
    # No harvest preview helper, external package, native runner or network import.
    # Shared production/art inputs retain conservative all-suite fallback.
    'tanning_rack_appearance': {'files': ('tests/test_tanning_rack_appearance.py',),
        'paths': (), 'shared_paths': (
            'code/game/objects/structures/converters.dm',
            'code/game/objects/items/stacks/sheets/leather.dm',
            'icons/obj/structures.dmi', 'icons/obj/materials.dmi')},
    # Stdlib-only production predicate/worker projections with inert clients.
    # No renderer, native runner, process, clock or network boundary is imported.
    'resource_work_animation': {'files': ('tests/test_resource_work_animation.py',),
        'paths': ('tests/test_resource_work_animation.py',), 'shared_paths': (
            'code/game/mob/animations.dm', 'code/game/objects/structures/wild.dm',
            'code/game/turfs/floor_attackby.dm', 'tests/bump_mining/support.dm')},
    # Inert existing harvest/flax runner imports plus stdlib file/transport
    # adapters only. Tests replace every process boundary; no native execution.
    'harvest_inputs': {'files': ('tests/animal_harvest/test_input_accounting.py',),
        'paths': ('tests/animal_harvest/test_input_accounting.py',), 'shared_paths': (
            'tests/animal_harvest/run.py', 'tests/animal_harvest/hide_recipe_probe.dm',
            'tests/flax_processing/run.py', 'tests/flax_processing/required-inputs.json',
            'code/names.dm', 'config/names/', 'scripts/native_fixture.py',
            'scripts/byond_runtime.py', 'scripts/byond_toolchain.py',
            'tools/byond/version.json')},
    # Stdlib-only admission expressions and fixture wiring; never import a native
    # runner. Shared game/fixture inputs retain conservative all-suite fallback.
    'action_admission': {'files': ('tests/animal_harvest/test_action_admission.py',),
        'paths': ('tests/animal_harvest/test_action_admission.py',), 'shared_paths': (
            'code/game/objects/structures/wild.dm',
            'code/game/turfs/floor_attackby.dm',
            'code/game/objects/items/weapons/material/ooga_booga_weapons.dm',
            'code/game/objects/structures/rocks.dm',
            'code/game/objects/structures/repairing.dm',
            'tests/animal_harvest/probe.dm',
            'tests/animal_harvest/action_admission_probe.dm')},
    # Offline injected transport and temporary wiki fixtures. Shared production
    # inputs remain shared so they do not suppress other suites' fallback.
    # test_wiki_answers reads the guide copies shipped under UI/player-help-wiki
    # and the question set; both belong to this suite alone.
    'help_wiki_guides': {'files': ('tests/player_help/test_wiki_guides.py', 'tests/player_help/test_wiki_answers.py'),
        'paths': ('UI/player-help-wiki/', 'tests/player_help/wiki_eval/'), 'shared_paths': (
            'code/game/mob/living/carbon/human/shit_piss.dm',
            'code/game/mob/living/carbon/human/emotes/emote.dm',
            'code/modules/reagents/reagent_containers/glass.dm',
            'scripts/player_help_bridge.py', 'UI/player-help.json', 'UI/crafting-atlas.json',
            'code/game/objects/structures/blacksmithing/refining.dm',
            'code/game/objects/structures/blacksmithing/molds.dm',
            'code/game/objects/structures/blacksmithing/blacksmithing.dm',
            'code/game/objects/structures/kitchen/oven.dm',
            'code/modules/research_tree/research_node.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_bench.dm',
            'code/modules/materials/materials.dm',
            'code/game/objects/items/weapons/material/shards.dm',
            'code/predefines.dm', 'code/game/objects/items/clothing/clothing.dm',
            'code/modules/reagents/reagent_containers/food/sandwich.dm',
            'code/modules/1713/rain_barrel.dm',
            'code/_onclick/hud/base_screen_objects.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/living/carbon/human/human_needs.dm',
            'code/game/mob/living/carbon/human/mood_living.dm',
            'code/game/mob/living/carbon/human/human_stats.dm',
            'code/modules/reagents/Chemistry-Reagents.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Toxins.dm',
            'code/modules/organs/organ_internal.dm', 'code/modules/organs/organ_external.dm',
            'code/modules/organs/organ.dm', 'code/modules/organs/internal/heart.dm',
            'code/game/objects/items/stacks/medical.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Elements.dm',
            'code/modules/persistence/region_travel.dm')},
    # Exact stdlib/injected transport suite. test_bridge supplies inert setup/
    # teardown helpers; its tests are not discovered. No native runner or model.
    # All production/import inputs stay shared to preserve existing fallback.
    'help_toxin_context': {'files': ('tests/player_help/test_toxin_context.py',),
        'paths': (), 'shared_paths': (
            'tests/player_help/test_bridge.py', 'scripts/player_help_bridge.py',
            'UI/player-help.json', 'UI/crafting-atlas.json',
            'code/game/objects/structures/blacksmithing/refining.dm',
            'code/game/objects/structures/blacksmithing/molds.dm',
            'code/game/objects/structures/blacksmithing/blacksmithing.dm',
            'code/game/objects/structures/kitchen/oven.dm',
            'code/modules/research_tree/research_node.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_bench.dm',
            'code/modules/materials/materials.dm',
            'code/game/objects/items/weapons/material/shards.dm',
            'code/predefines.dm', 'code/game/objects/items/clothing/clothing.dm',
            'code/modules/reagents/reagent_containers/food/sandwich.dm',
            'code/modules/1713/rain_barrel.dm',
            'code/_onclick/hud/base_screen_objects.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/living/carbon/human/human_needs.dm',
            'code/game/mob/living/carbon/human/mood_living.dm',
            'code/game/mob/living/carbon/human/human_stats.dm',
            'code/modules/reagents/Chemistry-Reagents.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Toxins.dm',
            'code/modules/organs/organ_internal.dm', 'code/modules/organs/organ_external.dm',
            'code/modules/organs/organ.dm', 'code/modules/organs/internal/heart.dm',
            'code/game/objects/items/stacks/medical.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Elements.dm',
            'code/modules/persistence/region_travel.dm')},
    # Injected transport and source-only contracts; no BYOND or network calls.
    'help_mood_history': {'files': ('tests/player_help/test_bridge.py',
                                   'tests/player_help/test_question_display_source.py'),
        'paths': ('tests/player_help/test_bridge.py', 'tests/player_help/test_question_display_source.py'),
        'shared_paths': ('scripts/player_help_bridge.py', 'code/game/mob/player_help.dm',
                         'code/_onclick/hud/base_screen_objects.dm',
                         'code/game/mob/living/carbon/human/human_life.dm',
                         'code/game/mob/living/carbon/human/human_needs.dm',
                         'code/game/mob/living/carbon/human/mood_living.dm',
                         'code/game/mob/living/carbon/human/human_stats.dm')},
    # Only stdlib source contracts; the shared DM inputs stay unmapped so their
    # existing all-suite fallback and other owners' coverage remain intact.
    'help_tab_links': {'files': ('tests/player_help/test_help_links.py',),
        'paths': (), 'shared_paths': ('code/modules/client/client_verbs.dm',
                                     'code/game/mob/crafting_atlas.dm')},
    # Full import graph: stdlib source/catalog checks plus the adjacent inert
    # test_foundations specification helper. No native runner or network import.
    # Shared production sources retain their conservative all-suite fallback.
    'character_traits': {'files': ('tests/character_traits/test_foundations.py',
                                   'tests/character_traits/test_random.py'),
        'paths': ('tests/character_traits/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/traits.dm',
            'code/modules/client/preferencesSQLite/character_setup_ui.dm',
            'code/modules/client/preferencesSQLite/preference_setup/general/01_basic.dm',
            'code/game/mob/living/carbon/human/trait_catalog.dm',
            'code/modules/client/preferencesSQLite/preferences.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/living/carbon/human/human_stats.dm',
            'code/game/mob/living/carbon/human/playstyle_traits.dm',
            'code/game/mob/living/carbon/human/sight_traits.dm')},
    # Stdlib-only source contracts for the character setup window; the shared
    # sources keep the character_traits fallback above.
    'character_setup': {'files': ('tests/character_setup/test_setup_window.py',),
        'paths': ('tests/character_setup/',), 'shared_paths': ()},
    # Reviewed stdlib-only projection; shared production changes keep fallback.
    'tablet_press': {'files': ('tests/tablet_press/test_contract.py',),
        'paths': ('tests/tablet_press/',),
        'shared_paths': ('code/modules/reagents/tablet_press.dm',
            'code/modules/persistence/functions.dm',
            'code/game/objects/items/stacks/stack.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_node.dm',
            'code/modules/reagents/laboratory.dm', 'config/crafting/')},
    'sound_listener_dispatch': {'files': ('tests/sound_listener_dispatch/test_dispatch.py',),
        'paths': ('tests/sound_listener_dispatch/',),
        'shared_paths': ('code/game/sound.dm',)},
    'device_hearing': {'files': ('tests/device_hearing/test_contract.py',),
        'paths': ('tests/device_hearing/',),
        'shared_paths': ('code/game/mob/hear_say.dm',)},
    # Source-only pointer inventory/hooks and injected alert counter. Imports are
    # stdlib plus the existing inert save-movement projection, and the link test
    # imports the cross-level runner only to stage files; no native launch.
    'persistence_pointers': {'files': ('tests/persistence_pointers/test_contract.py',
                                    'tests/persistence_pointers/test_restore_dependents.py',
                                    'tests/persistence_pointers/test_action_reconnect.py',
                                    'tests/persistence_pointers/test_inventory_screen_loc.py',
                                    'tests/persistence_pointers/test_level_links.py',
                                    'tests/persistence_pointers/test_world_time_stamps.py',
                                    'tests/persistence_pointers/test_restored_languages.py'),
        'paths': ('tests/persistence_pointers/',),
        'shared_paths': ('code/modules/persistence/',
            'code/game/mob/living/simple_animal/',
            'code/game/mob/living/carbon/human/pull_pair_ownership.dm',
            'code/game/mob/living/carbon/human/human_hud.dm',
            'code/game/mob/living/carbon/human/update_icons.dm',
            'code/game/mob/grab.dm', 'code/game/mob/observer/ghost/ghost.dm',
            'code/game/objects/structures/optable.dm',
            'code/game/objects/items/weapons/explosives.dm',
            'code/modules/multiz/structures.dm', 'code/_onclick/hud/action.dm',
            'tests/world_save/full_game_probe.dm', 'tests/save_movement/source_adapter.py',
            'tests/world_save/run-cross-level.py', 'tests/world_save/stubs.dm',
            'tests/save_movement/test_guard.py', 'code/processes/abandoned_items.dm',
            'code/modules/1713/weapons/zoom.dm', 'code/modules/1713/weapons/attachment.dm',
            'code/modules/1713/gunsmithing/gun_configuration.dm',
            'code/modules/1713/machinery/modular_vehicles/wheels.dm',
            'code/game/mob/living/living_defense.dm',
            'code/game/mob/hear_say.dm', 'code/game/mob/language/language.dm',
            'code/game/mob/living/living_hud.dm',
            'code/game/mob/living/carbon/human/human_hud.dm',
            'code/game/objects/items/weapons/swords_axes_etc.dm')},
    # Inert stdlib-only source/model checks; no native runner or subprocesses.
    # Shared movement sources retain their conservative all-suite fallback.
    'melee_force': {'files': ('tests/melee_force/test_force.py',),
        'paths': ('tests/melee_force/',),
        'shared_paths': ('code/game/objects/items/weapons/swords_axes_etc.dm',
                         'tests/save_movement/source_adapter.py')},
    'destroyed_grab_preflight': {'files': ('tests/test_destroyed_grab_preflight.py',),
        'paths': (), 'shared_paths': ('code/game/mob/mob_movement.dm',
                                     'code/game/mob/living/carbon/human/subtile_movement.dm')},
    # Inert source checks; shared living movement retains all-suite fallback.
    'ordinary_animal_swap': {'files': ('tests/test_ordinary_animal_swap.py',),
        'paths': (), 'shared_paths': ('code/game/mob/living/living.dm',)},
    # Matcher and ratchet contracts for scripts/check_forbidden_patterns.py; stdlib only.
    # The repository-wide check itself is a step of the baseline job, so game
    # source changes do not select this suite.
    'forbidden_patterns': {'files': ('tests/forbidden_patterns/test_forbidden_patterns.py',),
        'paths': ('tests/forbidden_patterns/', 'scripts/check_forbidden_patterns.py',
                  'tools/lint/forbidden_patterns_baseline.json'), 'shared_paths': ()},
    # Dreamchecker output parsing and baseline ratchet; synthetic log, no download.
    'dreamchecker_lint': {'files': ('tests/dreamchecker_lint/test_dreamchecker_lint.py',),
        'paths': ('tests/dreamchecker_lint/', 'scripts/dreamchecker_lint.py', 'tools/lint/dreamchecker.json',
                  'tools/lint/dreamchecker_baseline.json'), 'shared_paths': ('SpacemanDMM.toml',)},
    # Real detached Git/catalog fixture; compiler, daemon and WSL are injected.
    'local_wsl': {'files': ('tests/test_local_wsl.py',),
        'paths': ('tests/test_local_wsl.py', 'scripts/local-wsl.py', 'scripts/local-wsl.ps1'),
        'shared_paths': ('scripts/build-crafting-atlas.py', 'scripts/atlas/',
            'config/crafting/furniture_joinery.json', 'code/game/objects/items/stacks/craft_needs.dm', 'tools/byond/version.json',
            'scripts/byond_toolchain.py', 'code/modules/1713/production.dm',
            'code/modules/1713/rope_making.dm', 'code/modules/1713/primitive_woodworking.dm',
            'code/modules/1713/animal_harvest.dm',
            'code/game/objects/items/stacks/sheets/leather.dm',
            'code/modules/materials/material_sheets.dm', 'code/modules/materials/materials.dm',
            'code/game/objects/structures/converters.dm',
            'code/modules/research_tree/research_node.dm',
            'code/modules/research_tree/book_pages.dm')},
    # The CI policy files grow with every admitted suite and took ~30 s on hosted
    # runners, so the shared 30 s deadline failed master by timing alone.
    'policy': {'files': POLICY_FILES, 'always': True, 'paths': (), 'timeout': 120},
    'bootstrap': {'files': ('tests/test_byond_bootstrap.py', 'tests/test_byond_toolchain.py',
                            'tests/test_byond_runtime.py', 'tests/test_sprite_toolchain.py'), 'always': True, 'paths': ()},
    'progress': {'files': ('tests/world_save/test_progress_sources.py', 'tests/world_save/test_import_hold.py'), 'always': True, 'paths': ()},
    # Build cost vs dismantle/smash refund across every recipe list. It scans
    # all production DM and every recipe file, so it runs on every PR.
    'dismantle_refunds': {'files': ('tests/dismantle_refunds/test_refunds.py',),
                          'always': True, 'paths': (), 'timeout': 120},
    # Source-only inventories the native moving-save lane pins (collision overrides,
    # animal save hooks). They scan all production DM, so they run on every PR: the
    # PR that edits a listed file refreshes the inventory, not the next save PR.
    'movement_save_inventory': {'files': ('tests/movement_save_chunks/test_collision_manifest.py',
                                          'tests/movement_save_chunks/test_chunks.py'),
                                'always': True, 'paths': ()},
    # Stdlib-only scalar/callback projections; no native runner or subprocesses.
    # Shared chemistry/stack sources retain their conservative all-suite fallback.
    'furnace_manual': {'files': ('tests/furnace_manual/test_transaction.py',),
        'paths': ('tests/furnace_manual/',), 'shared_paths': (
            'tests/grinder/test_transaction.py',
            'code/game/objects/structures/blacksmithing/refining.dm')},
    'grinder': {'files': ('tests/grinder/test_transaction.py',),
        'paths': ('tests/grinder/',), 'shared_paths': (
            'code/modules/reagents/Chemistry-Machinery.dm',
            'code/modules/materials/material_sheets.dm',
            'code/game/objects/structures/kitchen/oven.dm',
            'code/modules/1713/wood_ash_compost.dm',
            'code/game/objects/structures.dm',
            'code/game/objects/items/stacks/recipe_skill_needs.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_node.dm',
            'config/crafting/material_recipes_global.txt',
            'config/crafting/material_recipes_camp.txt',
            'config/crafting/material_recipes_carib.txt',
            'code/game/objects/items/stacks/stack.dm')},
    # Stdlib-only source projection; no native runner is imported or executed.
    # Keep shared farming.dm unmapped so its all-suite fallback stays intact.
    'crop_stage_step': {'files': ('tests/crop_stage_step/test_source.py',), 'paths': (
        'tests/crop_stage_step/', 'tests/plant_lifecycle/')},
    # Complete stacked-yield branch with fake construction/merge boundaries.
    # Keep farming.dm unmapped so its conservative all-suite fallback remains.
    # Chitin sources, recipes, research gates, lime kiln and fertiliser wiring.
    # Chitin sources, recipes, research gates, lime kiln and fertiliser wiring.
    # Shared production files stay in shared_paths so their fallbacks remain.
    'chitin_uses': {'files': ('tests/chitin_uses/test_chitin_uses.py',),
        'paths': ('tests/chitin_uses/', 'code/modules/1713/chitin_uses.dm'),
        'shared_paths': ('code/modules/1713/animal_harvest.dm', 'code/modules/1713/clay_lime_fire.dm',
            'config/crafting/material_recipes_global.txt', 'config/crafting/material_recipes_crustacean.txt')},
    'stacked_crop_yields': {'files': ('tests/harvest_skills/test_stacked_crops.py',),
        'paths': ('tests/harvest_skills/',),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'research': {'files': ('tests/research_scheduler/test_resume.py',), 'paths': (
        'tests/research_scheduler/', 'code/processes/research_tree.dm',
        'code/processes/_process.dm', 'code/processes/___defines.dm',
        'code/processes/__processScheduler.dm')},
    'ping': {'files': ('tests/ping_scheduler/test_resume.py',), 'paths': (
        'tests/ping_scheduler/', 'code/processes/ping_track.dm', 'code/processes/_process.dm')},
    'year': {'files': ('tests/persistence_year/test_floor.py',), 'paths': (
        'tests/persistence_year/', 'tests/world_save/', 'code/modules/persistence/', 'code/setup.dm')},
    'evidence': {'files': ('tests/test_game_evidence.py',), 'paths': (
        'tests/test_game_evidence.py', 'scripts/check-game-evidence.py')},
    'ecology_heatmap': {'files': ('tests/ecology_heatmap/test_source_contract.py',), 'paths': (
        'tests/ecology_heatmap/', 'code/modules/ecology/activity_heatmap.dm',
        'docs/ecology-activity-heatmap-prototype.md',
        'code/modules/persistence/functions.dm')},
    'jungle_hiding': {'files': ('tests/jungle_hiding/test_source.py',), 'paths': (
        'tests/jungle_hiding/',)},
    'foraging': {'files': ('tests/foraging/test_contract.py',), 'paths': (
        'tests/foraging/', 'code/modules/ecology/foraging.dm', 'docs/foraging.md')},
    'flora_regressions': {'files': ('tests/flora_regrowth/test_regressions.py', 'tests/flora_regrowth/test_site_occupancy.py'), 'paths': (
        'tests/flora_regrowth/', 'tests/ecology_spawning/', 'code/modules/ecology/flora_regrowth.dm', 'code/modules/ecology/ecology_spawning.dm')},
    'pollution': {'files': ('tests/pollution/test_pollution.py',), 'paths': (
        'tests/pollution/', 'code/modules/ecology/pollution.dm', 'code/processes/pollution.dm',
        'code/modules/reagents/reagent_pollution.dm',
        'icons/effects/pollution.dmi')},
    'hub_status': {'files': ('tests/test_hub_status.py',), 'paths': (
        'tests/test_hub_status.py', 'code/world.dm', 'config/config.txt')},
    # Shared transport/persistence files retain their existing all-suite fallback.
    'carriage_glide': {'files': ('tests/carriage_glide/test_sources.py',), 'paths': (
        'tests/carriage_glide/',), 'shared_paths': ('code/game/objects/structures/carriage.dm',)},
    'throw_launch': {'files': ('tests/throw_launch_clearance/test_launch.py',
                              'tests/throw_launch_clearance/test_mode_guard.py',
                              'tests/throw_launch_clearance/test_runtime_plan.py'), 'paths': (
        'tests/throw_launch_clearance/', 'tests/save_movement/source_adapter.py',
        'code/game/atoms_movable.dm', 'code/game/objects/items.dm',
        'code/processes/throwing.dm', 'code/modules/persistence/functions.dm')},
    'los_context': {'files': ('tests/los_context/test_offline.py',
                              'tests/los_context/test_production.py',
                              'tests/los_context/test_tile_motion.py',
                              'tests/los_context/test_entered_trace.py',
                              'tests/los_context/test_audit_skip.py',
                              'tests/test_geometric_presentation.py',
                              'tests/test_visibility_diagnostics.py'), 'paths': (
        'tests/los_context/', 'code/modules/visibility/', 'civ13.dme',
        'code/_onclick/hud/hover_name.dm', 'code/game/mob/mob.dm',
        'code/game/mob/logout.dm', 'code/modules/client/client_procs.dm'),
        'shared_paths': ('code/game/atoms_movable.dm', 'tests/save_movement/source_adapter.py',
                         'code/game/mob/mob_movement.dm', 'code/datums/observation/moved.dm',
                         'tests/root_tree_presentation/test_contract.py')},
    # Inert source projections and file-only fixture preparation. Import graph:
    # stdlib + existing LOS/save-movement projections; no native runner is imported.
    # Keep shared movement/lighting files unmapped: they retain all-suite fallback.
    'root_tree_presentation': {'files': (
        'tests/root_tree_presentation/test_contract.py',
        'tests/root_tree_presentation/test_noop_refresh.py',
        'tests/root_tree_presentation/test_preparation.py',
        'tests/root_tree_presentation/test_protocol.py'), 'paths': (
        'tests/root_tree_presentation/', 'code/modules/visibility/',
        'code/__defines/_planes+layers.dm', 'civ13.dme',
        'tests/save_movement/source_adapter.py')},
    'character_return_preparation': {'files': ('tests/world_save/character_return/test_prepare.py',
        'tests/world_save/test_roundtrip_compat.py', 'tests/world_save/test_restart_sources.py'),
        'paths': ('tests/world_save/character_return/',),
        # Shared reads must select this suite without claiming exclusive impact
        # ownership and removing the existing all-suite unmapped fallback.
        'shared_paths': ('tests/world_save/', 'tests/save_movement/source_adapter.py',
            'tests/new_z_budget/z_budget_evidence.py',
            'tests/floor_decal_tracking/prepare.py', 'code/predefines.dm', 'code/_macros.dm',
            'code/modules/persistence/', 'code/modules/multiz/world_z_budget.dm',
            'code/game/mob/living/carbon/human/human_helpers.dm', 'code/game/objects/buckling.dm',
            'code/game/atoms_movable.dm', 'code/_helpers/global_lists.dm',
            'code/modules/1713/snowfall_ground.dm', 'code/world.dm')},
    'character_return': {'files': ('tests/save_movement/test_character_return.py',), 'paths': (
        'tests/save_movement/', 'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/bed_return.dm',
        'code/game/mob/new_player/', 'code/game/mob/living/carbon/human/human_helpers.dm'),
        'shared_paths': ('code/game/gameticker.dm', 'code/modules/persistence/functions.dm',
            'code/game/mob/living/carbon/carbon_defines.dm',
            'code/game/mob/living/carbon/human/nomads_spawn.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/objects/structures.dm', 'code/modules/chat/chat.dm',
            'code/modules/client/client_procs.dm')},
    # Fishing grounds source contracts; the native probe beside them runs
    # through tests/ecology_spawning/run_linux.py.
    'fishing_grounds': {'files': ('tests/fishing_grounds/test_source.py',), 'paths': (
        'tests/fishing_grounds/', 'code/modules/1713/fishing_grounds.dm')},
    # Read-only Examine navigation source contracts; no DM runtime is launched.
    'atlas_examine': {'files': ('tests/test_atlas_examine.py',), 'paths': (
        'tests/test_atlas_examine.py', 'code/game/mob/crafting_atlas_examine.dm'),
        'shared_paths': ('code/game/mob/mob.dm', 'code/game/mob/crafting_atlas.dm', 'civ13.dme')},
    # Source-only candidate inventory fixtures; no compiler or native execution.
    'atlas_entity_inventory': {'files': ('tests/atlas_entity_inventory/test_inventory.py',), 'paths': (
        'tests/atlas_entity_inventory/', 'scripts/atlas/entity_inventory.py'),
        'shared_paths': ('scripts/atlas/facts.py', 'scripts/atlas/families.py')},
    # Atlas habitat and hazard rows: reviewed source evidence only; no DM runtime.
    'atlas_habitats': {'files': ('tests/atlas_habitats/test_habitats.py',), 'paths': (
        'tests/atlas_habitats/', 'scripts/atlas/habitats.py', 'scripts/atlas/hazards.json'),
        'shared_paths': ('scripts/atlas/facts.py', 'code/modules/ecology/ecology_spawning.dm',
                         'code/modules/ecology/wild_herbs.dm',
                         'code/modules/1713/machinery/modular_vehicles/ships/sea_life.dm')},
    # Admin-only atlas list stays out of public atlas outputs; source contracts only.
    'atlas_admin_only': {'files': ('tests/atlas_admin_only/test_admin_only.py',), 'paths': (
        'tests/atlas_admin_only/', 'scripts/atlas/admin_only.py', 'code/game/mob/crafting_atlas_admin.dm'),
        'shared_paths': ('scripts/build-crafting-atlas.py', 'code/game/mob/crafting_atlas_tgui.dm', 'UI/crafting-atlas.json', 'civ13.dme',
                         'code/modules/magic/')},
    # Source and injected-help contracts only; this suite does not run DM.
    'mechanical_power': {'files': ('tests/mechanical_power/test_contract.py',), 'paths': (
        'tests/mechanical_power/', 'code/modules/1713/mechanical_power.dm', 'config/craft_needs.json',
        'icons/obj/mechanical_power.dmi', 'tests/sprites/create_mechanical_power.py',
        'code/modules/1713/machine_shop.dm', 'icons/obj/machine_shop.dmi', 'tests/sprites/create_machine_shop.py',
        'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm')},
    'building_site': {'files': ('tests/building_site/test_contract.py',), 'paths': (
        'tests/building_site/', 'code/modules/1713/building_site.dm',
        'icons/obj/building_site.dmi', 'tests/sprites/create_building_site.py')},
    # Source contracts only; this suite does not run DM.
    'power_cranes': {'files': ('tests/power_cranes/test_contract.py',), 'paths': (
        'tests/power_cranes/', 'code/modules/1713/power_cranes.dm', 'code/modules/1713/lifting_machines.dm',
        'config/craft_needs.json', 'icons/obj/power_cranes.dmi', 'tests/sprites/create_power_cranes.py')},
    # Source contracts only; this suite does not run DM.
    'road_garden': {'files': ('tests/road_garden/test_contract.py',), 'paths': ('tests/road_garden/',),
        'shared_paths': ('code/game/objects/covers_types/cover_roads.dm',
                         'code/game/turfs/floor_attackby.dm', 'code/game/turfs/turf_changing.dm')},
    'earthworks': {'files': ('tests/earthworks/test_contract.py',), 'paths': (
        'tests/earthworks/', 'code/modules/1713/earthworks.dm', 'config/craft_needs.json',
        'icons/obj/earthworks.dmi', 'tests/sprites/create_earthworks.py')},
    # Source contracts only; this suite does not run DM.
    'wire_bench': {'files': ('tests/wire_bench/test_contract.py',), 'paths': (
        'tests/wire_bench/', 'code/modules/1713/wire_bench.dm', 'code/modules/materials/wire_materials.dm',
        'code/modules/1713/machinery/cables_types.dm', 'config/craft_needs.json',
        'icons/obj/wire_bench.dmi', 'tests/sprites/create_wire_bench.py')},
    # Source contracts only; this suite does not run DM.
    'rolling_mill': {'files': ('tests/rolling_mill/test_contract.py',), 'paths': (
        'tests/rolling_mill/', 'code/modules/1713/rolling_mill.dm', 'config/craft_needs.json',
        'icons/obj/rolling_mill.dmi', 'tests/sprites/create_rolling_mill.py')},
    'lifting_machines': {'files': ('tests/lifting_machines/test_contract.py',), 'paths': (
        'tests/lifting_machines/', 'code/modules/1713/lifting_machines.dm',
        'icons/obj/lifting_machines.dmi', 'tests/sprites/create_lifting.py')},
    'ramps': {'files': ('tests/ramps/test_contract.py',), 'paths': (
        'tests/ramps/', 'code/modules/multiz/ramps.dm', 'code/__defines/ramps.dm',
        'icons/obj/ramps.dmi', 'tests/sprites/create_ramps.py')},
    'glass_stone_machines': {'files': ('tests/glass_stone_machines/test_contract.py',), 'paths': (
        'tests/glass_stone_machines/', 'code/modules/1713/glass_stone_machines.dm',
        'icons/obj/glass_stone_machines.dmi', 'tests/sprites/create_glass_stone.py')},
    'clay_lime_fire': {'files': ('tests/clay_lime_fire/test_contract.py',), 'paths': (
        'tests/clay_lime_fire/', 'code/modules/1713/clay_lime_fire.dm',
        'icons/obj/workshop_machines.dmi', 'tests/sprites/create_clay_lime_fire.py')},
    'charcoal_clamp': {'files': ('tests/charcoal_clamp/test_contract.py',), 'paths': (
        'tests/charcoal_clamp/', 'code/modules/1713/charcoal_clamp.dm',
        'icons/obj/charcoal_clamp.dmi', 'tests/sprites/create_charcoal_clamp.py')},
    'steelmaking': {'files': ('tests/steelmaking/test_contract.py',), 'paths': (
        'tests/steelmaking/', 'code/modules/1713/steel_grades.dm', 'code/modules/1713/carburizing.dm',
        'code/modules/1713/crucible_steel.dm', 'code/modules/1713/steel_works.dm', 'docs/steelmaking.md')},
    'tatara': {'files': ('tests/tatara/test_contract.py',), 'paths': (
        'tests/tatara/', 'code/modules/1713/tatara.dm', 'docs/tatara.md',
        'icons/obj/tatara.dmi', 'tests/sprites/create_tatara.py', 'tests/sprites/create_tachi.py')},
    'mercury': {'files': ('tests/mercury/test_contract.py',), 'paths': (
        'tests/mercury/', 'code/modules/1713/mercury.dm', 'docs/mercury.md',
        'icons/obj/mercury.dmi', 'tests/sprites/create_mercury.py')},
    'placer': {'files': ('tests/placer/test_contract.py',), 'paths': (
        'tests/placer/', 'code/modules/1713/placer.dm', 'docs/placer.md',
        'icons/obj/placer.dmi', 'tests/sprites/create_placer.py')},
    'lode': {'files': ('tests/lode/test_contract.py',), 'paths': (
        'tests/lode/', 'code/modules/1713/lode.dm', 'docs/lode.md',
        'icons/obj/lode.dmi', 'tests/sprites/create_lode.py')},
    'amalgam': {'files': ('tests/amalgam/test_contract.py',), 'paths': (
        'tests/amalgam/', 'code/modules/1713/amalgam.dm', 'docs/amalgam.md',
        'icons/obj/amalgam.dmi', 'tests/sprites/create_amalgam.py')},
    'milling': {'files': ('tests/milling/test_contract.py',), 'paths': (
        'tests/milling/', 'code/modules/1713/milling.dm', 'docs/milling.md',
        'icons/obj/milling.dmi', 'tests/sprites/create_milling.py')},
    'mercury_crafts': {'files': ('tests/mercury_crafts/test_contract.py',), 'paths': (
        'tests/mercury_crafts/', 'code/modules/1713/mercury_crafts.dm', 'docs/mercury_crafts.md',
        'icons/obj/mercury_crafts.dmi', 'icons/mob/mercury_crafts.dmi',
        'tests/sprites/create_mercury_crafts.py')},
    'late_mining': {'files': ('tests/late_mining/test_contract.py',), 'paths': (
        'tests/late_mining/', 'code/modules/1713/late_mining.dm', 'docs/late_mining.md',
        'icons/obj/late_mining.dmi', 'tests/sprites/create_late_mining.py')},
    # Keep shared production and Atlas sources unmapped so their existing
    # conservative all-suite fallback remains intact.
    'sawmill': {'files': ('tests/sawmill/test_contract.py',
                           'tests/test_atlas_navigation.py',
                           'tests/player_help/test_recipe_context.py'), 'paths': (
        'tests/sawmill/',)},
    # Keep shared game sources unmapped where they previously selected the
    # all-suite fallback; persistence was already mapped by existing suites.
    'water_treatment': {'files': ('tests/stone_boiling/test_source.py',
                                  'tests/stone_kiln/test_source.py'), 'paths': (
        'tests/stone_boiling/', 'tests/stone_kiln/',
        'code/modules/persistence/functions.dm')},
    'lipstick_restore': {'files': ('tests/lipstick_restore/test_restore.py',),
        'paths': ('tests/lipstick_restore/',), 'shared_paths': (
            'code/game/objects/items/weapons/cosmetics.dm',
            'code/modules/persistence/restore_contract.dm', 'tests/save_movement/source_adapter.py')},
    'save_movement': {'files': ('tests/save_movement/test_guard.py',
                                'tests/save_movement/test_whistle_cooldown.py'), 'paths': (
        'tests/save_movement/', 'code/modules/persistence/functions.dm'), 'shared_paths': (
        'code/game/objects/items/weapons/tools.dm',)},
    # Full import graph: stdlib source adapter, catalog-only Atlas builder/projector,
    # and inert Help imports. No native sprite export or engine launch.
    # Shared material/Atlas inputs retain their conservative all-suite fallback.
    # Both files run a full Crafting Atlas build (~14 s each), so the shared
    # 30 s deadline failed master by timing alone (CI run 43766230339).
    'woodworking': {'files': ('tests/primitive_woodworking/test_source.py',
                              'tests/test_atlas_navigation.py'), 'timeout': 120, 'paths': (
        'tests/primitive_woodworking/', 'code/modules/1713/primitive_woodworking.dm',
        'scripts/atlas/woodworking.py', 'scripts/atlas/woodworking-contract.json',
        'code/modules/persistence/functions.dm', 'civ13.dme')},
    # Offline only: reviewed guard projection, catalog generation, inert Help imports.
    # Shared crafting/Atlas files keep the conservative all-suite fallback.
    'furniture_joinery': {'files': ('tests/furniture_joinery/test_grille_construction.py',
                                   'tests/furniture_joinery/test_table_climb.py',
                                  'tests/furniture_joinery/test_contract.py',
                                  'tests/furniture_joinery/test_wooden_shelf.py',
                                  'tests/furniture_joinery/test_bedroll.py',
                                  'tests/furniture_joinery/test_bedroll_occupancy.py',
                                  'tests/furniture_joinery/test_document_drawers.py',
                                  'tests/furniture_joinery/test_sofa_materials.py',
                                  'tests/furniture_joinery/test_canopy.py',
                                  'tests/furniture_joinery/test_cutting_board.py',
                                  'tests/furniture_joinery/test_barrel_ingredients.py',
                                  'tests/furniture_joinery/test_glass_extraction.py',
                                  'tests/furniture_joinery/test_glass_cotton.py'), 'paths': (
        'tests/furniture_joinery/', 'code/game/objects/items/stacks/furniture_joinery.dm',
        'config/crafting/furniture_joinery.json', 'scripts/audit-crafting-recipes.py',
        'code/modules/1713/cutting_board.dm', 'tests/primitive_woodworking/source_adapter.py',
        'code/modules/persistence/functions.dm', 'code/modules/reagents/reagent_containers/food.dm')},
    'dictionary': {'files': ('tests/dictionary_era/test_sources.py',
                             'tests/dictionary_era/test_slang_content.py',
                             'tests/dictionary_era/test_corpus.py'), 'paths': (
        'tests/dictionary_era/', 'code/_helpers/dictionary.dm', 'code/_helpers/text.dm',
        'code/setup.dm', 'code/world.dm', 'code/__defines/__game.dm', 'civ13.dme',
        'code/__defines/_rust_g.dm',
        'code/game/mob/living/carbon/human/say.dm',
        'code/game/mob/living/carbon/human/whisper.dm',
        'config/dictionary.txt', 'tools/byond/version.json')},
    # Save policy: no automatic saves while players are online; 30 minute save votes.
    'save_policy': {'files': ('tests/save_policy/test_policy.py', 'tests/save_policy/test_runtime_var_cache.py',
                              'tests/save_policy/test_save_validator_boot.py',
                              'tests/save_policy/test_private_scratch_savefiles.py',
                              'tests/save_policy/test_stack_recipes_unsaved.py',
                              'tests/save_policy/test_action_locks_unsaved.py',
                              'tests/save_policy/test_occupied_checkpoint.py'), 'paths': (
        'tests/save_policy/', 'code/world.dm', 'code/datums/vote.dm',
        'code/modules/research_tree/scholar_practice.dm', 'code/game/objects/structures/tree_climbing.dm',
        'code/game/mob/living/carbon/human/resuscitation.dm',
        'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
        'code/modules/persistence/occupied_checkpoint.dm',
        'code/modules/persistence/save_validator.dm', 'code/modules/persistence/stream/',
        'code/modules/persistence/train_body_graph.dm', 'code/modules/persistence/derived_assets.dm')},
    # Offline source contracts for the disabled per-use divine approval foundation.
    'divine_approval': {'files': ('tests/divine_approval/test_contract.py', 'tests/divine_approval/test_divine_book.py', 'tests/divine_approval/test_journal.py', 'tests/divine_approval/test_mundane_gear.py', 'tests/divine_approval/test_ritual.py', 'tests/divine_approval/test_covenant.py', 'tests/divine_approval/test_magic_whitelist.py', 'tests/divine_approval/test_arcane_materials.py', 'tests/divine_approval/test_arcane_enchant.py', 'tests/divine_approval/test_arcane_altars.py', 'tests/divine_approval/test_arcane_bless.py', 'tests/divine_approval/test_arcane_spirits.py', 'tests/divine_approval/test_arcane_apostate.py', 'tests/divine_approval/test_arcane_ward.py', 'tests/divine_approval/test_arcane_devotion.py', 'tests/divine_approval/test_arcane_rites.py', 'tests/divine_approval/test_arcane_unbind.py', 'tests/divine_approval/test_arcane_veil.py', 'tests/divine_approval/test_heteromorph.py'), 'paths': (
        'tests/divine_approval/', 'code/modules/divine/', 'code/modules/admin/verbs/divine_book.dm', 'code/modules/admin/verbs/divine_patron.dm', 'code/modules/admin/verbs/divine_repositories.dm', 'code/modules/admin/verbs/magic_whitelist.dm', 'code/modules/magic/', 'config/magic_law_balance.json'), 'shared_paths': ('civ13.dme', 'code/modules/1713/book.dm', 'code/game/objects/items.dm', 'code/game/objects/items/stacks/stack.dm', 'code/modules/1713/coin_mint.dm', 'code/modules/1713/weather_lightning.dm', 'code/game/objects/structures/wild.dm', 'code/game/turfs/floor_attackby.dm')},
    # Offline source contracts for the fireman carry (grab on a downed human).
    'fireman_carry': {'files': ('tests/fireman_carry/test_source.py',), 'paths': (
        'tests/fireman_carry/', 'code/game/mob/grab_carry.dm'),
        'shared_paths': ('code/game/mob/grab.dm', 'code/game/mob/mob_movement.dm')},
    'immunity_empty_decay': {'files': ('tests/disease_immunity/test_decay_projection.py',),
        'paths': ('tests/disease_immunity/before_decay.dm.txt',),
        'shared_paths': ('code/game/mob/living/carbon/human/immunity.dm',
                         'tests/save_movement/source_adapter.py')},
    'injury_recovery': {'files': ('tests/injury_recovery/test_source.py',
        'tests/disease_immunity/test_source.py', 'tests/illness_pain_body_heat/test_source.py',
        'tests/sleep_pain_hold/test_source.py'),
        'paths': ('tests/injury_recovery/', 'tests/disease_immunity/', 'tests/illness_pain_body_heat/',
            'tests/sleep_pain_hold/'),
        'shared_paths': ('code/modules/organs/organ.dm', 'code/modules/organs/organ_external.dm',
            'code/modules/organs/brain.dm', 'code/modules/organs/pain.dm',
            'code/game/mob/living/carbon/human/human_organs.dm',
            'code/game/mob/living/carbon/human/human_disease.dm',
            'code/game/mob/living/carbon/human/severe_disease.dm',
            'code/game/mob/living/carbon/human/immunity.dm',
            'code/game/mob/living/carbon/human/human_life.dm')},
    # Two-handed weapons need an attached, empty offhand to wield.
    'twohanded_wield': {'files': ('tests/twohanded_wield/test_offhand.py',), 'paths': (
        'tests/twohanded_wield/', 'code/game/objects/items/weapons/material/twohanded.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/inventory.dm',
            'code/modules/organs/organ_external.dm')},
    # A finished CPR round is credited before the post-wait recheck.
    'cpr_cycle_credit': {'files': ('tests/cpr_cycle_credit/test_credit_order.py',), 'paths': (
        'tests/cpr_cycle_credit/',),
        'shared_paths': ('code/game/mob/living/carbon/human/resuscitation.dm',)},
    # Emptying a magazine rechecks the player still holds it after the prompt.
    'magazine_empty': {'files': ('tests/magazine_empty/test_held_recheck.py',), 'paths': (
        'tests/magazine_empty/',),
        'shared_paths': ('code/modules/projectiles/ammunition.dm',)},
    # Flying drones break and are wrecked when damage empties their health.
    'drone_destruction': {'files': ('tests/drone_destruction/test_flying_destroy.py',), 'paths': (
        'tests/drone_destruction/', 'code/game/objects/items/devices/drone.dm')},
    # Raising a lowered sterile mask restores its face coverage.
    'sterile_mask_toggle': {'files': ('tests/sterile_mask_toggle/test_toggle_coverage.py',), 'paths': (
        'tests/sterile_mask_toggle/', 'code/game/objects/items/clothing/masks/medical.dm')},
    # Camel pack withdrawal rechecks range after the menu.
    'camel_pack_range': {'files': ('tests/camel_pack_range/test_withdraw_range.py',), 'paths': (
        'tests/camel_pack_range/',),
        'shared_paths': ('code/game/mob/living/simple_animal/friendly/farm_animals.dm',)},
    'powder_loading_container': {'files': ('tests/powder_loading_container/test_powder_loading_container.py',),
        'paths': ('tests/powder_loading_container/',),
        'shared_paths': ('code/modules/projectiles/ammo_crafting.dm',)},
    'tanning_drum_idle_power': {'files': ('tests/tanning_drum_idle_power/test_tanning_drum_idle_power.py',),
        'paths': ('tests/tanning_drum_idle_power/',),
        'shared_paths': ('code/modules/1713/factory_tanning.dm',)},
    'exact_reagent_transfer': {'files': ('tests/exact_reagent_transfer/test_exact_reagent_transfer.py',),
        'paths': ('tests/exact_reagent_transfer/',),
        'shared_paths': ('code/modules/1713/factory_pipes.dm', 'code/modules/reagents/Chemistry-Holder.dm',
                         'code/modules/reagents/reagent_containers/glass.dm', 'code/modules/1713/light_fuel.dm')},
    'canteen_not_glass': {'files': ('tests/canteen_not_glass/test_canteen_not_glass.py',),
        'paths': ('tests/canteen_not_glass/',),
        'shared_paths': ('code/modules/reagents/reagent_containers/food/drinks/canteen.dm',)},
    'launcher_empty_switch': {'files': ('tests/launcher_empty_switch/test_launcher_empty_switch.py',),
        'paths': ('tests/launcher_empty_switch/',),
        'shared_paths': ('code/modules/projectiles/guns/projectile.dm',)},
    'bearcave_aggro': {'files': ('tests/bearcave_aggro/test_bearcave_aggro.py',),
        'paths': ('tests/bearcave_aggro/',),
        'shared_paths': ('code/game/objects/structures/animalspawner/bearcave.dm',)},
    # Force-feeding rechecks reach and mouth coverage after its wait.
    'force_feed': {'files': ('tests/force_feed/test_finish_recheck.py',), 'paths': (
        'tests/force_feed/', 'code/modules/reagents/reagent_containers/pill.dm'),
        'shared_paths': ('code/game/mob/mob_helpers.dm',
            'code/modules/reagents/reagent_containers/food/snacks.dm',
            'code/game/objects/items/weapons/material/kitchen.dm')},
    # Offline source contracts for field treatment and artery repair.
    'medical_care': {'files': ('tests/medical_care/test_source.py',
        'tests/medical_care/test_splints.py'), 'paths': (
        'tests/medical_care/', 'code/game/objects/items/stacks/medical.dm',
        'code/game/mob/living/carbon/human/stripping.dm',
        'code/modules/surgery/other.dm', 'code/modules/surgery/limb_reattach.dm',
        'code/modules/1713/doctor_handbook.dm'),
        'shared_paths': ('code/modules/organs/organ_external.dm', 'code/modules/organs/internal/heart.dm',
            'code/modules/organs/organ.dm', 'code/modules/agent_control/agent_characters.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Elements.dm')},
    # In-game bug reports wiring and safety; tests/bug_reports/native_format.py is the manual native check.
    'bug_reports': {'files': ('tests/bug_reports/test_bug_reports.py',),
        'paths': ('tests/bug_reports/', 'code/modules/bug_reports/'),
        'shared_paths': ('interface/skin.dmf', 'code/datums/configuration.dm', 'code/datums/http.dm',
            'code/modules/admin/admin_verbs.dm', 'code/modules/admin/verbs/adminhelp.dm', 'civ13.dme')},
    # Fit Viewport skin wiring; tests/fit_viewport/native_width.py is the manual native width check.
    'fit_viewport': {'files': ('tests/fit_viewport/test_fit_viewport.py',),
        'paths': ('tests/fit_viewport/', 'code/modules/client/fullscreen.dm', 'code/modules/client/interface.dm'),
        'shared_paths': ('interface/skin.dmf', 'code/modules/client/client_procs.dm')},
    # Customizable HUD wiring; tests/hud_layout/run.py is the manual native fixture.
    'hud_layout': {'files': ('tests/hud_layout/test_layout.py', 'tests/hud_layout/test_console_style.py', 'tests/hud_layout/test_tap_step.py', 'tests/hud_layout/test_slots.py'),
        'paths': ('tests/hud_layout/', 'code/_onclick/hud/hud_layout.dm', 'tools/hud-skin/',
            'icons/mob/screen/ConsoleStyle.dmi', 'icons/mob/screen/needs.dmi',
            'icons/mob/screen/healthdoll_console.dmi', 'icons/mob/screen/zone_sel_console.dmi'),
        'shared_paths': ('code/datums/hud.dm', 'code/modules/client/ui_style.dm',
            'code/_onclick/hud/base_screen_objects.dm', 'icons/mob/screen/1713Style.dmi',
            'icons/mob/screen/healthdoll.dmi', 'icons/mob/screen/zone_sel.dmi',
            'code/game/mob/living/carbon/human/species/species_hud.dm',
            'code/game/mob/living/carbon/human/human_hud.dm',
            'code/game/mob/living/carbon/human/update_icons.dm', 'code/game/mob/inventory.dm',
            'code/_onclick/hud/hud.dm', 'code/_onclick/hud/action.dm',
            'code/game/objects/items/weapons/storage/storage.dm',
            'code/game/objects/items/weapons/storage/bags.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm', 'civ13.dme')},
    # Widescreen 21x15 view, square fallback preference, HUD edge anchoring and the side panel.
    'held_crafting_menu': {'files': ('tests/held_crafting_menu/test_menu.py',),
        'paths': ('tests/held_crafting_menu/', 'code/js/stack_crafting.js'),
        'shared_paths': ('code/game/objects/items/stacks/stack.dm',)},
    'widescreen_view': {'files': ('tests/widescreen_view/test_widescreen.py', 'tests/widescreen_view/test_side_panel.py'),
        'paths': ('tests/widescreen_view/', 'interface/info/info.html', 'code/game/mob/mob_view.dm', 'code/game/mob/new_player/lobby_image.dm',
            'code/_onclick/hud/movable_screen_objects.dm', 'code/modules/nano/interaction/default.dm'),
        'shared_paths': ('code/__defines/__game.dm', 'code/_onclick/hud/hud_layout.dm', 'code/game/mob/login.dm',
            'code/game/mob/living/carbon/human/human.dm', 'code/game/mob/living/carbon/human/human_helpers.dm',
            'code/modules/1713/football.dm',
            'code/modules/client/preferencesSQLite/preference_setup/global/setting_datums.dm')},
    # Inert skin/catalog/guard and account-wiring checks; no native runner import.
    # Existing shared inputs retain their conservative all-suite selection.
    'action_keybindings': {'files': ('tests/action_keybindings/test_keybindings.py',),
        'paths': ('tests/action_keybindings/', 'code/modules/client/action_keybindings.dm'),
        'shared_paths': ('interface/skin.dmf', 'interface/interface.dm',
            'code/modules/client/client_procs.dm', 'code/game/mob/login.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm', 'civ13.dme')},
    # Full read-only status helper projections with inert process/list boundaries.
    # Shared production sources retain their prior conservative CI selection.
    'time_of_day_progress': {'files': ('tests/time_of_day_progress/test_progress.py',),
        'paths': ('tests/time_of_day_progress/', 'code/processes/time_of_day_progress.dm'),
        'shared_paths': ('code/processes/time_of_day.dm', 'code/__defines/time_of_day.dm',
            'code/processes/_process.dm', 'code/game/mob/mob.dm', 'civ13.dme')},
    # Current-world Persistence census and complete largest-faction tally; offline only.
    'persistence_status': {'files': ('tests/persistence_status/test_status.py',),
        'paths': ('tests/persistence_status/',), 'shared_paths': (
            'code/modules/1713/battlereport_variables.dm', 'code/modules/admin/verbs/1713.dm',
            'code/game/mob/groups/factions.dm', 'code/predefines.dm',
            'tests/save_movement/source_adapter.py')},
    # Status tab "Last save" wiring; native round trip via the berry_load fixture.
    'shutdown_notice': {'files': ('tests/shutdown_notice/test_shutdown_notice.py',),
        'paths': ('tests/shutdown_notice/', 'code/modules/persistence/shutdown_notice.dm'),
        'shared_paths': ('code/modules/persistence/restart_transaction.dm', 'code/modules/persistence/nomads_lifecycle.dm',
            'code/modules/persistence/admin.dm', 'code/modules/admin/admin.dm', 'code/modules/admin/admin_verbs.dm',
            'code/modules/agent_control/agent_actions.dm')},
    # A handover's standby clears the map and sets turfs from the last save while it waits.
    'standby_prepare': {'files': ('tests/standby_prepare/test_standby_prepare.py',),
        'paths': ('tests/standby_prepare/', 'code/modules/persistence/standby_prepare.dm'),
        'shared_paths': ('code/setup.dm', 'code/modules/persistence/nomads_lifecycle.dm',
            'code/modules/persistence/functions.dm', 'civ13.dme')},
    # Where players have been; saves leave out wild animals nobody has been near.
    'visited_areas': {'files': ('tests/visited_areas/test_visited_areas.py',),
        'paths': ('tests/visited_areas/', 'code/modules/persistence/visited_areas.dm'),
        'shared_paths': ('code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
            'code/modules/persistence/loading.dm', 'civ13.dme')},
    'last_save_status': {'files': ('tests/last_save_status/test_last_save.py',),
        'paths': ('tests/last_save_status/', 'code/modules/persistence/last_save_status.dm'),
        'shared_paths': ('code/modules/statpanel/statpanel.dm', 'code/modules/persistence/functions.dm',
            'code/modules/persistence/saving.dm', 'civ13.dme')},
    # Save stall watchdog wiring; the native probe tests/save_watchdog/run.py runs by hand.
    'save_watchdog': {'files': ('tests/save_watchdog/test_save_watchdog.py',),
        'paths': ('tests/save_watchdog/', 'code/modules/persistence/save_watchdog.dm'),
        'shared_paths': ('code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
            'civ13.dme', 'tests/save_movement/source_adapter.py')},
    # Server Revision verb and admin Status line; native_server_build.py runs by hand.
    'server_build': {'files': ('tests/server_build/test_server_build.py',),
        'paths': ('tests/server_build/', 'code/modules/server_build/'),
        'shared_paths': ('code/modules/statpanel/statpanel.dm', 'civ13.dme', '.gitignore')},
    # What's New: host collector of PR Changelog: lines and the lobby/Game Menu window.
    'player_changelog': {'files': ('tests/player_changelog/test_player_changelog.py',),
        'paths': ('tests/player_changelog/', 'code/modules/player_changelog/', 'scripts/gaia-host/player_changelog.py'),
        'shared_paths': ('code/game/mob/new_player/new_player.dm', 'code/modules/client/escape_menu.dm',
            'scripts/gaia-host/gaia_host.py', 'scripts/shard-group/shard_group.py', 'civ13.dme', '.gitignore')},
    # Status tab Playing/Observing/Lobby counted from connected clients.
    'player_count_status': {'files': ('tests/player_count_status/test_player_count.py',),
        'paths': ('tests/player_count_status/',), 'shared_paths': ('code/game/mob/mob.dm',)},
    # Handcuff placement races and per-human chew cooldown (#4229, #4230).
    # Faction recruitment applications, offers and their durable field (#4237).
    'faction_recruitment': {'files': ('tests/faction_recruitment/test_source.py',),
        'paths': ('tests/faction_recruitment/', 'code/game/mob/groups/faction_recruitment.dm', 'code/game/mob/groups/recruitment_station.dm'),
        'shared_paths': ('scripts/fixture_source_projection.py', 'code/game/mob/groups/faction_membership.dm', 'code/game/mob/groups/faction_rename.dm',
            'code/game/mob/groups/factions.dm', 'code/modules/persistence/durable_contract.dm',
            'code/game/mob/living/carbon/human/death.dm', 'code/modules/1713/cmss13_squad.dm',
            'civ13.dme')},
    # Faction recruitment authority and the shared enrollment transition (#4237).
    'faction_membership': {'files': ('tests/faction_membership/test_source.py',),
        'paths': ('tests/faction_membership/', 'code/game/mob/groups/faction_membership.dm',
            'code/game/mob/living/carbon/give.dm'),
        'shared_paths': ('scripts/fixture_source_projection.py', 'code/game/mob/groups/factions.dm', 'code/modules/1713/marketplace.dm',
            'code/modules/research_tree/research_faction.dm', 'civ13.dme')},
    'handcuffs': {'files': ('tests/handcuffs/test_source.py',),
        'paths': ('tests/handcuffs/', 'code/game/objects/items/weapons/handcuffs.dm')},
    # Signal-smoke choices must not overwrite a grenade activated by another dialog.
    'signal_smoke_selection': {'files': ('tests/signal_smoke_selection/test_source.py',),
        'paths': ('tests/signal_smoke_selection/',),
        'shared_paths': ('code/game/objects/items/weapons/grenades/smokebomb.dm',)},
    # Spray bottle acceptance, feedback and reagent logging (#4269, #4270).
    'spray': {'files': ('tests/spray/test_source.py',),
        'paths': ('tests/spray/', 'code/modules/reagents/reagent_containers/spray.dm')},
    # Snow barricade completion keeps its own direction (#4290).
    'snow_barricade': {'files': ('tests/snow_barricade/test_source.py',),
        'paths': ('tests/snow_barricade/', 'code/modules/1713/barriers/snow_walls.dm'),
        'shared_paths': ('code/modules/1713/barriers/sandbag.dm',)},
    # Restraint escape dispatch and item identity across the wait.
    'legcuff_escape': {'files': ('tests/legcuff_escape/test_cooldown.py',),
        'paths': ('tests/legcuff_escape/', 'code/game/mob/living/carbon/resist.dm',
                  'code/game/mob/living/living.dm', 'code/_onclick/click.dm',
                  'code/game/objects/items/weapons/legcuffs.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    # Trap disarm recheck, punji animal capture/release and release unanchoring (#4248, #4249, #6223).
    'traps': {'files': ('tests/traps/test_source.py',),
        'paths': ('tests/traps/', 'code/game/objects/items/weapons/traps.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    # Gavel block forwards non-hammer items, so storage bags collect it (#4515).
    'gavel_block': {'files': ('tests/gavel_block/test_source.py',),
        'paths': ('tests/gavel_block/', 'code/game/objects/items/courtitems.dm')},
    # Prefilled belts hold and accept their initial contents (#4544, #4545, #4546).
    'belt_contents': {'files': ('tests/belt_contents/test_source.py',),
        'paths': ('tests/belt_contents/', 'code/game/objects/items/weapons/storage/belt.dm')},
    # Railing dismantling stops if the railing was fastened during the wait (#4413).
    'railing_dismantle': {'files': ('tests/railing_dismantle/test_source.py',),
        'paths': ('tests/railing_dismantle/', 'code/game/objects/structures/railing.dm')},
    'berry_harvest': {'files': ('tests/berry_harvest/test_harvest.py',),
        'paths': ('tests/berry_harvest/', 'code/game/objects/structures/berries.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},
    'barbwire_crossing': {'files': ('tests/barbwire_crossing/test_crossing.py',),
        'paths': ('tests/barbwire_crossing/', 'code/modules/1713/barbwire.dm'),
        'shared_paths': ('tests/save_movement/source_adapter.py',)},    'hay': {'files': ('tests/hay/test_hay.py',),
        'paths': ('tests/hay/', 'code/modules/1713/hay.dm', 'icons/obj/hay.dmi')},
    'log_wall_building': {'files': ('tests/log_wall_building/test_log_walls.py',),
        'paths': ('tests/log_wall_building/', 'code/game/objects/covers_types/log_wall_building.dm',
                  'code/game/objects/covers_types/cover_walltypes.dm', 'code/game/objects/building_insulation.dm',
                  'icons/obj/log_wall_build.dmi', 'tests/sprites/create_log_wall_build.py')},
    'fire_smoke_breathing': {'files': ('tests/fire_smoke/test_breathing.py',),
        'paths': ('tests/fire_smoke/', 'code/modules/1713/fire_smoke.dm')},
    'firefighting': {'files': ('tests/firefighting/test_firefighting.py',),
        'paths': ('tests/firefighting/', 'code/modules/1713/firefighting.dm', 'code/modules/1713/firefighting_water.dm', 'code/modules/1713/firefighting_hook.dm', 'code/modules/1713/firefighting_pump.dm', 'code/game/objects/items/weapons/tools.dm',
                  'code/modules/1713/oil_fires.dm', 'icons/obj/firefighting.dmi',
                  'tests/sprites/create_firefighting.py')},
    'voice_chat': {'files': ('tests/voice_chat/test_voice_chat.py',),
        'paths': ('tests/voice_chat/', 'code/modules/voice/')},
    'lobby_relay': {'files': ('tests/lobby_relay/test_lobby_relay.py',),
        'paths': ('tests/lobby_relay/', 'code/modules/webhooks/', 'code/game/mob/new_player/new_player.dm')},
    'signal_fires': {'files': ('tests/signal_fires/test_signal_fires.py',),
        'paths': ('tests/signal_fires/', 'code/modules/1713/signal_fires.dm',
                  'icons/effects/signal_smoke.dmi', 'tests/sprites/create_signal_smoke.py')},
    'death_legacy': {'files': ('tests/death_legacy/test_death_legacy.py',),
        'paths': ('tests/death_legacy/', 'code/modules/research_tree/death_legacy.dm', 'code/game/mob/living/carbon/human/death.dm',
                  'code/game/mob/groups/faction_start.dm', 'code/modules/persistence/bed_return.dm')},
    'familiarity': {'files': ('tests/familiarity/test_familiarity.py',),
        'paths': ('tests/familiarity/', 'code/modules/research_tree/familiarity.dm')},
    'knowledge_spread': {'files': ('tests/knowledge_spread/test_knowledge_spread.py',),
        'paths': ('tests/knowledge_spread/', 'code/modules/research_tree/knowledge_spread.dm', 'code/modules/research_tree/tech_tree_view.dm',
                  'code/modules/research_tree/book_interface.dm', 'code/modules/research_tree/book_research.dm', 'code/modules/research_tree/era_loss.dm',
                  'code/modules/research_tree/scholar_tools.dm', 'code/modules/research_tree/trade_learning.dm',
                  'code/modules/research_tree/_research_tree_defines.dm')},
    'wild_herbs': {'files': ('tests/wild_herbs/test_wild_herbs.py',),
        'paths': ('tests/wild_herbs/', 'code/modules/ecology/wild_herbs.dm', 'icons/farming/humanity_wild_herbs.dmi',
                  'icons/obj/food/food.dmi')},
    'paintings': {'files': ('tests/paintings/test_paintings.py',),
        'paths': ('tests/paintings/', 'code/modules/paintings/', 'icons/obj/paintings.dmi', 'icons/mob/paintings.dmi', 'icons/obj/paintings_gallery.dmi',
                  'tests/sprites/create_paintings.py')},
    'gun_blueprints': {'files': ('tests/gun_blueprints/test_sources.py',),
        'paths': ('tests/gun_blueprints/', 'code/modules/1713/gunsmithing/gun_design_code.dm'), 'shared_paths': (
            'code/modules/1713/gunsmithing/gunsmith.dm', 'code/modules/1713/blueprint.dm',
            'code/modules/paintings/design_codes.dm')},
    'design_codes': {'files': ('tests/design_codes/test_design_codes.py',),
        'paths': ('tests/design_codes/', 'code/modules/paintings/design_codes.dm'), 'shared_paths': (
            'code/modules/paintings/', 'code/game/objects/structures/sign_flags.dm',
            'code/modules/1713/structures.dm', 'code/modules/1713/dressmaking.dm',
            'code/modules/naval/draught_kinds.dm', 'code/__defines/naval.dm',
            'code/modules/naval/ship_designer.dm', 'code/modules/naval/sub_designer.dm',
            'code/modules/naval/air_designer.dm', 'code/modules/craft/vehicle_designer.dm',
            'code/modules/1713/train_designer.dm', 'code/modules/space/station_designer.dm',
            'code/game/objects/house_designer.dm')},
    'herb_garden': {'files': ('tests/herb_garden/test_herb_garden.py',),
        'paths': ('tests/herb_garden/', 'code/modules/1713/herb_garden.dm', 'code/modules/ecology/flora_regrowth.dm',
                  'code/modules/ecology/foraging.dm', 'icons/farming/plants.dmi', 'icons/farming/seeds.dmi',
                  'icons/obj/food/food.dmi', 'icons/obj/food/dryed.dmi', 'icons/obj/food/dryer.dmi',
                  'code/modules/1713/herbalism.dm', 'icons/obj/herbalism.dmi', 'code/modules/1713/lantern.dm',
                  'code/modules/1713/light_fuel.dm')},
    'preserves': {'files': ('tests/preserves/test_preserves.py',),
        'paths': ('tests/preserves/', 'code/modules/1713/preserves.dm', 'icons/obj/food/preserves.dmi')},
    'drug_preparations': {'files': ('tests/drug_preparations/test_drug_preparations.py',),
        'paths': ('tests/drug_preparations/', 'code/modules/1713/drug_preparations.dm', 'tests/sprites/create_drugs.py')},
    'drug_refining': {'files': ('tests/drug_refining/test_drug_refining.py',),
        'paths': ('tests/drug_refining/', 'code/modules/reagents/drug_refining.dm')},
    'faction_substances': {'files': ('tests/faction_substances/test_source.py',),
        'paths': ('tests/faction_substances/', 'code/game/mob/groups/faction_substances.dm')},
    'drug_classes': {'files': ('tests/drug_classes/test_drug_classes.py',),
        'paths': ('tests/drug_classes/', 'code/modules/reagents/drug_classes.dm')},
    'drug_crops': {'files': ('tests/drug_crops/test_drug_crops.py',),
        'paths': ('tests/drug_crops/',)},
    'coffee': {'files': ('tests/coffee/test_coffee.py',),
        'paths': ('tests/coffee/', 'code/modules/1713/coffee.dm', 'tests/sprites/create_coffee.py')},
    'dentistry': {'files': ('tests/dentistry/test_dentistry.py',),
        'paths': ('tests/dentistry/', 'code/modules/1713/dentistry.dm', 'tests/sprites/create_dentistry.py')},
    'butter': {'files': ('tests/butter/test_butter.py',),
        'paths': ('tests/butter/', 'code/modules/1713/butter.dm', 'tests/sprites/create_butter.py')},
    'syrups': {'files': ('tests/syrups/test_syrups.py',),
        'paths': ('tests/syrups/', 'code/modules/1713/syrups.dm')},
    'weather_sound': {'files': ('tests/weather_sound/test_rain_loop.py',),
        'paths': ('tests/weather_sound/', 'code/game/mob/living/life.dm',
                  'code/game/mob/observer/ghost/ghost.dm', 'code/game/area/areas.dm')},
    # Ghost animal noises preference: animals heard only nearby by choice.
    'spirit_wait': {'files': ('tests/spirit_wait/test_spirit_wait.py',),
        'paths': ('tests/spirit_wait/', 'code/game/mob/observer/ghost/spirit_wait.dm'),
        'shared_paths': ('code/game/mob/observer/ghost/ghost.dm', 'code/game/mob/mob.dm',
            'code/game/mob/living/carbon/human/death.dm', 'code/modules/divine/arcane_spirits.dm',
            'code/modules/admin/verbs/random_verbs.dm')},
    # Divine Sight: how gods observe (hidden mechanic).
    'divine_sight': {'files': ('tests/divine_sight/test_divine_sight.py',),
        'paths': ('tests/divine_sight/', 'code/modules/divine/divine_sight.dm',
            'code/modules/divine/divine_sight_panel.dm', 'icons/mob/divine_presence.dmi'),
        'shared_paths': ('code/game/mob/observer/ghost/ghost.dm', 'code/modules/admin/admin_verbs.dm')},
    # Observing as a spirit on persistent worlds: limited sight, local hearing, haunting.
    'spirit_observe': {'files': ('tests/spirit_observe/test_spirit_observe.py', 'tests/spirit_observe/test_spirit_hud.py'),
        'paths': ('tests/spirit_observe/', 'code/game/mob/observer/ghost/spirit_observe.dm',
            'icons/effects/spirit_sight.dmi', 'code/game/mob/observer/ghost/spirit_hud.dm',
            'icons/mob/screen/spirit_hud.dmi'),
        'shared_paths': ('code/game/mob/observer/ghost/ghost.dm', 'code/game/mob/observer/ghost/login.dm',
            'code/_onclick/ghost.dm', 'code/game/mob/hear_say.dm', 'code/game/mob/living/say.dm',
            'code/game/mob/emote.dm',
            'code/game/mob/mob.dm', 'code/game/mob/mob_movement.dm', 'code/modules/multiz/movement.dm',
            'code/modules/1713/radio.dm', 'code/modules/1713/cmss13_afterlife.dm',
            'code/game/mob/new_player/new_player.dm')},
    'ghost_animal_noises': {'files': ('tests/ghost_animal_noises/test_ghost_animal_noises.py',),
        'paths': ('tests/ghost_animal_noises/', 'code/game/mob/emote.dm'),
        'shared_paths': ('code/game/mob/observer/ghost/ghost.dm',
            'code/modules/client/preferencesSQLite/preference_setup/global/setting_datums.dm',
            'code/modules/client/preferencesSQLite/preferences.dm')},
    # False bottoms: hidden compartments the storage grid, window and searches skip.
    'false_bottom': {'files': ('tests/false_bottom/test_source.py',),
        'paths': ('tests/false_bottom/', 'code/modules/storage_window/false_bottom.dm'),
        'shared_paths': ('code/game/objects/items/weapons/storage/storage.dm',
            'code/modules/storage_window/storage_window.dm',
            'code/modules/persistence/region_travel_gear.dm')},
    'surgery_drinking': {'files': ('tests/surgery_drinking/test_source.py',),
        'paths': ('tests/surgery_drinking/', 'code/modules/surgery/surgery.dm')},
    'surgery_amputation_log': {'files': ('tests/surgery_amputation_log/test_source.py',),
        'paths': ('tests/surgery_amputation_log/', 'code/modules/surgery/generic.dm')},
    # A properly sleeping, logged-off character is safe off Gaia.
    'offline_sleep_protection': {'files': ('tests/offline_sleep_protection/test_source.py',),
        'paths': ('tests/offline_sleep_protection/', 'code/modules/persistence/offline_sleep_protection.dm',
            'code/game/mob/living/carbon/human/human_damage.dm', 'code/game/mob/living/living.dm',
            'code/game/mob/grab.dm', 'code/game/objects/buckling.dm', 'code/game/mob/living/logout.dm',
            'code/game/mob/living/carbon/human/stripping.dm', 'code/game/objects/items/stacks/craft_guards.dm')},
    # Peoples of the Nomads lands: origin table against languages, names, colours.
    'origins': {'files': ('tests/origins/test_origins.py', 'tests/origins/test_travel.py', 'tests/origins/test_peoples.py'),
        'paths': ('tests/origins/', 'code/game/mob/living/carbon/human/origins.dm',
            'code/game/mob/living/carbon/human/peoples.dm', 'code/game/mob/living/carbon/human/peoples_split.dm', 'code/game/mob/living/carbon/human/peoples_blend.dm', 'code/modules/admin/verbs/peoples_admin.dm',
            'config/people_names_blocked.txt', 'code/modules/admin/verbs/origin_languages.dm',
            'code/modules/persistence/region_travel_tongues.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/nomads_spawn.dm',
            'code/modules/persistence/region_travel.dm',
            'code/game/mob/language/earth.dm', 'code/_helpers/global_lists.dm',
            'code/game/mob/living/carbon/human/species/species.dm')},
    # Starting clothes on lands with peoples follow the people and the era.
    'spawn_outfits': {'files': ('tests/spawn_outfits/test_spawn_outfits.py',),
        'paths': ('tests/spawn_outfits/', 'code/modules/1713/jobs/spawn_outfits.dm'),
        'shared_paths': ('code/modules/1713/jobs/nomads.dm', 'code/game/mob/living/carbon/human/origins.dm',
            'code/_helpers/era.dm', 'code/modules/1713/apparel_stoneage.dm')},
    # Research chapters carry a language: recording, reading, translation.
    'book_language': {'files': ('tests/book_language/test_book_language.py',),
        'paths': ('tests/book_language/', 'code/modules/research_tree/book_language.dm'),
        'shared_paths': ('code/modules/research_tree/book_research.dm',
            'code/modules/research_tree/book_pages.dm', 'code/modules/research_tree/book_printing.dm',
            'code/modules/research_tree/book_interface.dm', 'code/modules/research_tree/book_launch.dm',
            'code/modules/research_tree/compare_notes.dm',
            'code/modules/research_tree/subject_prototypes.dm')},
    # Language proficiency: pacing numbers and learn/speak/hear boundaries.
    'language_proficiency': {'files': ('tests/language_proficiency/test_proficiency.py',),
        'paths': ('tests/language_proficiency/', 'code/game/mob/language/proficiency.dm',
                  'code/game/mob/language/teaching.dm', 'code/__defines/species_languages.dm'),
        'shared_paths': ('code/game/mob/language/language.dm', 'code/game/mob/hear_say.dm',
            'code/game/mob/say.dm', 'code/game/mob/living/say.dm',
            'code/modules/1713/language_book.dm', 'code/modules/paperwork/study.dm',
            'code/modules/paperwork/written_languages.dm', 'code/_helpers/global_lists.dm',
            'code/game/mob/language/earth.dm',
            'code/modules/persistence/world_time_stamps.dm')},
    # Integrated circuits: bounded execution, plain port values, checked editor input.
    'wiremod': {'files': ('tests/wiremod/test_wiremod_core.py',),
        'paths': ('tests/wiremod/', 'code/modules/wiremod/', 'code/__defines/wiremod.dm',
                  'tgui/src/interfaces/IntegratedCircuit/', 'tgui/src/interfaces/WiremodCircuit.tsx'),
        'shared_paths': ('civ13.dme', 'tgui/src/interfaces/index.tsx', 'tgui/src/types.ts',
            'tgui/THIRD_PARTY.md', 'UI/tgui/civ13-tgui.css')},
    'chat_translation': {'files': ('tests/chat_translation/test_markers.py', 'tests/chat_translation/test_edge_service.py'),
        'paths': ('tests/chat_translation/', 'code/game/mob/hear_say.dm', 'interface/chat/chat.html',
                  'code/modules/persistence/region_ooc.dm', 'docs/chat-translation.md',
                  'code/modules/chat/chat_translate.dm', 'tools/edge-translator/')},
}
CI_PATHS = ('scripts/select-ci.py', 'scripts/ci_baseline.py', 'scripts/ci_skill_prose.py',
            '.github/workflows/ci-selection.yml', '.github/workflows/test.yml')
TIMEOUT = 30  # per reviewed suite; enclosing job also has a wall-clock limit
MAX_SUITE_TIMEOUT = 300  # a reviewed per-suite 'timeout' can raise TIMEOUT up to this


def suite_deadline(name=None):
    """A reviewed suite may set its own 'timeout' (bounded by MAX_SUITE_TIMEOUT).
    scripts/local_ci.py raises the deadline on slower workstations (git is
    slow on Windows); hosted CI never sets it. Bounded so a typo cannot disable it."""
    base = min(MAX_SUITE_TIMEOUT, max(TIMEOUT, int(SUITES.get(name, {}).get('timeout', TIMEOUT))))
    value = os.environ.get('CIV13_LOCAL_SUITE_TIMEOUT', '')
    return min(600, max(base, int(value))) if value.isdigit() else base
# Reviewed prose/presentation formats only. Script/config suffixes deliberately
# fall back even below docs/; compilation retains its separate existing policy.
DOC_SUFFIXES = {'.md', '.rst', '.html', '.css', '.png', '.jpg', '.jpeg', '.gif',
                '.webp', '.svg', '.ico', '.woff', '.woff2', '.ttf', '.pdf'}
DOC_ASSETS = {'docs/api/search.js', 'docs/api/baseline-diagnostics.txt'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.PIPE,
                                   timeout=15).decode('utf-8').strip()


def revision(value):
    return git('rev-parse', '--verify', value + '^{commit}')


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def provenance(head, base):
    actual = revision('HEAD')
    if revision(head) != actual:
        raise ValueError('Requested head differs from checked-out HEAD')
    resolved_base = None
    if base and set(base) != {'0'}:
        try:
            resolved_base = revision(base)
        except (subprocess.SubprocessError, UnicodeError):
            pass
    return dict(head=actual, base=resolved_base, requested_base=base,
                run_id=os.environ.get('GITHUB_RUN_ID'),
                run_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'))


def documentation(path):
    relative = PurePosixPath(path)
    return (skill_prose(path) or path in DOC_ASSETS or
            (path.startswith('docs/') and relative.suffix.lower() in DOC_SUFFIXES) or
            (len(relative.parts) == 1 and relative.suffix.lower() == '.md'))


def matches(path, pattern):
    return path.startswith(pattern) if pattern.endswith('/') else path == pattern


def impact(paths, comparison='available'):
    """Unknown executable/shared impact runs this small registry, never native work."""
    reasons = {name: ['Always-required offline baseline'] if spec.get('always') else []
               for name, spec in SUITES.items()}
    unknown = []
    if comparison != 'available':
        unknown = ['Comparison unavailable; all reviewed offline suites required']
    for path in paths:
        covered = False
        for name, spec in SUITES.items():
            owned = any(matches(path, pattern) for pattern in (*spec['paths'], *spec['files']))
            if owned:
                covered = True
            if owned or any(matches(path, pattern) for pattern in spec.get('shared_paths', ())):
                reasons[name].append('Affected input: ' + path)
        if path in CI_PATHS or path in POLICY_FILES:
            unknown.append('CI policy/dependency changed: ' + path)
        elif not covered and not documentation(path):
            unknown.append('Unmapped impact: ' + path)
    if unknown:
        for name in reasons:
            reasons[name].append('Conservative fallback: all reviewed offline suites')
    return {'suites': {name: {'selected': bool(why), 'reason': why or [
                'No mapped input changed; native/costly tests remain separately admitted']}
                       for name, why in reasons.items()}, 'fallback_reasons': unknown}


def selection_receipt(base, head, game, extensive, new_tests, reason, event, eligibility=None, payload=None):
    receipt = dict(schema_version=1, kind='selection', status='passed',
                   **provenance(head, base), event=event)
    if eligibility is not None:
        receipt.update(action=eligibility['action'], eligibility=eligibility)
    paths = []
    comparison = 'unavailable'
    if receipt['base']:
        try:
            raw = subprocess.check_output(['git', 'diff', '--name-only', '--no-renames', '-z',
                                           receipt['base'], receipt['head']], cwd=ROOT,
                                          stderr=subprocess.PIPE, timeout=15)
            paths = sorted(p for p in raw.decode('utf-8').split('\0') if p)
            comparison = 'available'
        except (subprocess.SubprocessError, UnicodeError):
            pass
    receipt.update(comparison={'status': comparison, 'paths': paths,
                              'reason': 'Exact base/head comparison' if comparison == 'available'
                              else 'No reliable diff; compile policy and bounded offline fallback apply'},
                   compile={'selected': game, 'reason': reason}, extensive=extensive,
                   new_tests=new_tests, baseline=impact(paths, comparison))
    if event == 'push' and base == ZERO_BASE:
        comparison_refs = comparison_module()
        receipt['source_comparison'] = comparison_refs.new_branch_comparison(
            receipt['head'], payload if payload is not None else comparison_refs.push_event(), cwd=ROOT)
    return receipt


def selection_eligibility(plan):
    policy = plan.get('eligibility', {})
    if policy.get('metadata_valid') is not True or plan.get('action') != policy.get('action'):
        raise ValueError('Missing/invalid event scope evidence')
    for name in ('compile', 'native', 'gating'):
        row = policy.get(name, {})
        if type(row.get('eligible')) is not bool or not row.get('reason'):
            raise ValueError('Missing/invalid eligibility: ' + name)
    if policy['gating']['eligible'] and not policy['native']['eligible']:
        raise ValueError('Incomplete native admission cannot publish a gating verdict')
    return policy


def attempt_number(value):
    if type(value) is not str or not re.fullmatch(r'[1-9][0-9]{0,5}', value):
        raise ValueError('Invalid run attempt: ' + repr(value))
    return int(value)


def validate_source_comparison(plan, *, current_event=False):
    if current_event and (not os.environ.get('GITHUB_EVENT_NAME')
                          or plan.get('event') != os.environ['GITHUB_EVENT_NAME']):
        raise ValueError('Selection event mismatch: GITHUB_EVENT_NAME')
    expected = plan.get('event') == 'push' and plan.get('requested_base') == ZERO_BASE
    proof = plan.get('source_comparison')
    if not expected:
        if proof is not None:
            raise ValueError('Unexpected offline source comparison')
        return
    if plan.get('base') is not None or not isinstance(proof, dict):
        raise ValueError('Missing/invalid new-branch source comparison')
    comparison_refs = comparison_module()
    derived = comparison_refs.new_branch_comparison(plan['head'], proof.get('evidence'), cwd=ROOT)
    if proof != derived:
        raise ValueError('Offline source comparison differs from immutable ancestry')
    if current_event:
        event_proof = comparison_refs.new_branch_comparison(plan['head'], comparison_refs.push_event(), cwd=ROOT)
        if proof != event_proof:
            raise ValueError('Offline source comparison differs from event metadata')


def load_selection(path, head, base, selection_attempt=None):
    """A re-run of failed jobs reuses earlier successful jobs and their artifacts,
    so the selection may come from an earlier attempt of this same run. The
    caller names that attempt from the selection job's own output."""
    plan = json.loads(Path(path).read_text(encoding='utf-8'))
    expected = provenance(head, base)
    for key in ('head', 'base', 'requested_base', 'run_id'):
        if plan.get(key) != expected[key]:
            raise ValueError('Selection provenance mismatch: ' + key)
    if selection_attempt is None:
        if plan.get('run_attempt') != expected['run_attempt']:
            raise ValueError('Selection provenance mismatch: run_attempt')
    elif (plan.get('run_attempt') != selection_attempt
          or attempt_number(selection_attempt) > attempt_number(expected['run_attempt'])):
        raise ValueError('Selection provenance mismatch: run_attempt')
    if plan.get('schema_version') != 1 or plan.get('kind') != 'selection' or plan.get('status') != 'passed':
        raise ValueError('Missing or failed selection receipt')
    suites = plan['baseline']['suites']
    if set(suites) != set(SUITES) or any(type(row['selected']) is not bool for row in suites.values()):
        raise ValueError('Invalid baseline selection')
    if any(not suites[name]['selected'] for name, spec in SUITES.items() if spec.get('always')):
        raise ValueError('Always-required suite omitted')
    if type(plan['compile']['selected']) is not bool:
        raise ValueError('Invalid compilation selection')
    selection_eligibility(plan)
    validate_source_comparison(plan, current_event=True)
    return plan


def run_unit(name, output):
    """Child interpreter emits counts so zero tests or unittest skips cannot pass."""
    suite = unittest.TestSuite()
    # These reviewed suites import adjacent, source-only specification helpers.
    if name in ('save_movement', 'character_traits'):
        sys.path.insert(0, str(ROOT / 'tests' / name))
    elif name == 'movement_save_inventory':
        sys.path.insert(0, str(ROOT / 'tests' / 'movement_save_chunks'))
    elif name == 'help_toxin_context':
        sys.path.insert(0, str(ROOT / 'tests' / 'player_help'))
    for index, relative in enumerate(SUITES[name]['files']):
        path = ROOT / relative
        spec = importlib.util.spec_from_file_location(f'baseline_{name}_{index}', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(module))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    # CI (Linux) still fails on any skip. A Windows developer host may skip
    # tests that need FIFOs, symlink privilege, Bash or Linux BYOND, as long
    # as some tests in the suite still ran.
    allowed_skips = len(result.skipped) if os.name == 'nt' else 0
    passed = (result.wasSuccessful() and result.testsRun > len(result.skipped)
              and len(result.skipped) <= allowed_skips)
    write_json(output, dict(tests=result.testsRun, failures=len(result.failures),
                            errors=len(result.errors), skipped=len(result.skipped),
                            status='passed' if passed else 'failed'))
    return 0 if passed else 1


def suite_environment(name, plan):
    environment = os.environ.copy()
    environment.pop('CIV13_LOCAL_SUITE_TIMEOUT', None)
    if name == 'los_context':
        validate_source_comparison(plan)
        proof = plan.get('source_comparison')
        environment['LOS_EVENT_BASE'] = proof['base'] if proof else (plan['base'] or '')
        environment['LOS_EVENT_HEAD'] = plan['head'] or ''
    return environment


def execute(plan, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema_version=1, kind='baseline', status='running',
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   job_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'),
                   selection_sha256=digest(plan), suites={})
    if 'source_comparison' in plan:
        receipt['source_comparison'] = plan['source_comparison']
    (output / 'source-tree.txt').write_text(git('ls-tree', '-r', 'HEAD') + '\n', encoding='utf-8')
    observed_head_before = revision('HEAD')
    tracked_patch = subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15)
    (output / 'tested.patch').write_bytes(tracked_patch)
    receipt['tracked_dirty'] = bool(tracked_patch)
    receipt['observed_head_before'] = observed_head_before
    write_json(output / 'baseline.json', receipt)
    for name, selected in plan['baseline']['suites'].items():
        row = dict(selected, status='skipped')
        receipt['suites'][name] = row
        if selected['selected']:
            counts = output / (name + '.json')
            counts.unlink(missing_ok=True)
            command = [sys.executable, '-B', str(Path(__file__).resolve()), 'unit',
                       '--suite', name, '--output', str(counts.resolve())]
            deadline = suite_deadline(name)
            row.update(command=command, timeout_seconds=deadline, files=list(SUITES[name]['files']))
            started = time.monotonic()
            with (output / (name + '.log')).open('wb') as log:
                try:
                    result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                            timeout=deadline, env=suite_environment(name, plan))
                    row['exit_code'] = result.returncode
                    row['status'] = 'failed'
                    if counts.is_file():
                        row['counts'] = json.loads(counts.read_text(encoding='utf-8'))
                        if result.returncode == 0 and row['counts']['status'] == 'passed':
                            row['status'] = 'passed'
                except subprocess.TimeoutExpired:
                    row.update(status='failed', reason=['Offline suite deadline exceeded'])
            row['duration_seconds'] = round(time.monotonic() - started, 3)
        write_json(output / 'baseline.json', receipt)
    observed_head_after = revision('HEAD')
    after_patch = subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15)
    (output / 'tested-after.patch').write_bytes(after_patch)
    receipt.update(observed_head_after=observed_head_after, tracked_dirty_after=bool(after_patch),
                   source_unchanged=(observed_head_before == observed_head_after == plan['head']
                                     and tracked_patch == after_patch))
    source_ok = receipt['source_unchanged'] and not tracked_patch and not after_patch
    receipt['status'] = 'passed' if source_ok and all(
        row['status'] == ('passed' if row['selected'] else 'skipped')
        for row in receipt['suites'].values()) else 'failed'
    write_json(output / 'baseline.json', receipt)
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


def compile_receipt(plan, outcome, output):
    directory = Path(output).parent
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'source-tree.txt').write_text(git('ls-tree', '-r', 'HEAD') + '\n', encoding='utf-8')
    (directory / 'source-final.patch').write_bytes(subprocess.check_output(
        ['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15))
    selected = plan['compile']['selected']
    status = 'passed' if outcome == 'success' and selected else 'failed' if selected else 'skipped'
    if not selected and outcome != 'skipped':
        status = 'failed'
    requirement = None
    toolchain_error = None
    acquisition = None
    try:
        requirement = toolchain.load()
        if selected and outcome == 'success':
            if (directory / 'byond-version.txt').read_text().strip() != requirement['version']:
                raise ValueError('Installed compiler version receipt differs from active requirement')
            toolchain.compiler_log((directory / 'compiler.log').read_text(), requirement['version'])
            acquisition = toolchain.read_download_receipt(directory / 'byond-download.json', requirement, 'linux')
    except (OSError, ValueError) as error:
        status = 'failed'
        toolchain_error = str(error)[:300]
    receipt = dict(schema_version=1, kind='compile', status=status, selected=selected,
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   job_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'),
                   selection_sha256=digest(plan), step_outcome=outcome,
                   reason=plan['compile']['reason'],
                   toolchain='BYOND ' + requirement['version'] if requirement else None,
                   toolchain_error=toolchain_error,
                   acquisition=acquisition,
                   archive_authenticity=requirement['integritySource'] if requirement else 'Unavailable')
    if 'source_comparison' in plan:
        receipt['source_comparison'] = plan['source_comparison']
    write_json(output, receipt)
    return 1 if status == 'failed' else 0


def aggregate(plan, baseline, compile_run, jobs, extraction_selected, attempts=None):
    """attempts names the attempt each reused or re-run job actually executed in,
    plus the aggregate's own current attempt; by default all equal the selection's."""
    errors = []
    if attempts is None:
        attempts = dict.fromkeys(('baseline', 'compile', 'current'), plan.get('run_attempt'))
    try:
        selection_eligibility(plan)
        validate_source_comparison(plan)
    except (ValueError, RuntimeError, subprocess.SubprocessError) as error:
        errors.append(str(error))
    if plan['compile']['selected']:
        requirement = toolchain.load()
        if compile_run.get('toolchain') != 'BYOND ' + requirement['version'] or compile_run.get('toolchain_error') is not None:
            errors.append('Compiler receipt differs from active BYOND requirement')
        try:
            toolchain.validate_download_receipt(compile_run.get('acquisition'), requirement, 'linux')
        except ValueError:
            errors.append('Missing/invalid exact-source BYOND acquisition receipt')
    required = {'changes', 'baseline', 'evidence-checker', 'build'}
    if extraction_selected:
        required.add('extraction-instances')
    for name in required:
        if jobs.get(name, {}).get('result') != 'success':
            errors.append('Required job did not succeed: ' + name)
    if not extraction_selected and jobs.get('extraction-instances', {}).get('result') not in {'success', 'skipped'}:
        errors.append('Unexpected extraction job failure or missing outcome')
    for receipt, kind in ((baseline, 'baseline'), (compile_run, 'compile')):
        if receipt.get('schema_version') != 1 or receipt.get('kind') != kind:
            errors.append('Missing/invalid ' + kind + ' receipt')
        for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt'):
            if receipt.get(key) != plan.get(key):
                errors.append(kind + ' provenance mismatch: ' + key)
        if receipt.get('source_comparison') != plan.get('source_comparison'):
            errors.append(kind + ' offline source comparison mismatch')
        if receipt.get('selection_sha256') != digest(plan):
            errors.append(kind + ' selection digest mismatch')
        try:
            if receipt.get('job_attempt') != attempts[kind] or not (
                    attempt_number(plan.get('run_attempt')) <= attempt_number(attempts[kind])
                    <= attempt_number(attempts['current'])):
                raise ValueError('order')
        except ValueError:
            errors.append(kind + ' job attempt mismatch')
    if baseline.get('status') != 'passed':
        errors.append('Baseline did not pass')
    if baseline.get('tracked_dirty') is not False:
        errors.append('Baseline is not evidence from a clean committed head')
    if (baseline.get('tracked_dirty_after') is not False or baseline.get('source_unchanged') is not True
            or baseline.get('observed_head_before') != plan['head']
            or baseline.get('observed_head_after') != plan['head']):
        errors.append('Baseline source changed during tests or post-test source evidence is missing')
    actual = baseline.get('suites', {})
    if set(actual) != set(SUITES):
        errors.append('Baseline suite set differs from selection')
    for name, selection in plan['baseline']['suites'].items():
        row = actual.get(name, {})
        if row.get('selected') != selection['selected'] or row.get('status') != (
                'passed' if selection['selected'] else 'skipped'):
            errors.append('Missing, failed or unexpectedly skipped suite: ' + name)
        if selection['selected']:
            counts = row.get('counts', {})
            if row.get('exit_code') != 0 or counts.get('status') != 'passed' or not counts.get('tests') or any(
                    counts.get(key) != 0 for key in ('errors', 'failures', 'skipped')):
                errors.append('Incomplete test execution: ' + name)
        elif not row.get('reason'):
            errors.append('Unexplained suite skip: ' + name)
    selected = plan['compile']['selected']
    if compile_run.get('selected') != selected or compile_run.get('status') != ('passed' if selected else 'skipped'):
        errors.append('Required compilation missing/failed/skipped, or invalid skip')
    if compile_run.get('step_outcome') != ('success' if selected else 'skipped') or not compile_run.get('reason'):
        errors.append('Incomplete compilation outcome/reason')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('unit', 'run', 'compile', 'aggregate'))
    parser.add_argument('--suite', choices=SUITES)
    parser.add_argument('--selection')
    parser.add_argument('--head')
    parser.add_argument('--base', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--outcome')
    parser.add_argument('--baseline')
    parser.add_argument('--compile-receipt')
    parser.add_argument('--selection-attempt')
    parser.add_argument('--baseline-attempt')
    parser.add_argument('--compile-attempt')
    args = parser.parse_args()
    if args.mode == 'unit':
        return run_unit(args.suite, args.output)
    plan = load_selection(args.selection, args.head, args.base, args.selection_attempt)
    if args.mode == 'run':
        return execute(plan, args.output)
    if args.mode == 'compile':
        return compile_receipt(plan, args.outcome, args.output)
    jobs = json.loads(os.environ['CI_NEEDS'])
    gating = os.environ['GATING_SELECTION']
    if gating not in {'1', '0'} or (gating == '1') != plan['eligibility']['gating']['eligible']:
        raise ValueError('Gating output differs from selection receipt')
    extraction = os.environ['EXTRACTION_SELECTED']
    if extraction not in {'true', 'false'}:
        raise ValueError('Missing extraction selection')
    attempts = dict(baseline=args.baseline_attempt, compile=args.compile_attempt,
                    current=os.environ.get('GITHUB_RUN_ATTEMPT'))
    errors = aggregate(plan, json.loads(Path(args.baseline).read_text(encoding='utf-8')),
                       json.loads(Path(args.compile_receipt).read_text(encoding='utf-8')),
                       jobs, extraction == 'true', attempts)
    receipt = dict(schema_version=1, kind='aggregate', status='failed' if errors else 'passed',
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   job_attempt=attempts['current'], receipt_attempts=attempts,
                   selection_sha256=digest(plan), jobs=jobs, errors=errors,
                   action=plan['action'], eligibility=plan['eligibility'],
                   coverage='gating' if gating == '1' else 'informational')
    write_json(args.output, receipt)
    print(json.dumps(receipt, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())

