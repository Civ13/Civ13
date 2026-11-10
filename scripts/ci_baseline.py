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
    'gong_fastening': {'files': ('tests/gong_fastening/test_fastening.py',), 'paths': (
        'tests/gong_fastening/', 'code/game/objects/structures/gong.dm'), 'shared_paths': (
        'tests/save_movement/source_adapter.py',)},
    'kitchen_spike': {'files': ('tests/kitchen_spike/test_kitchen_spike.py',), 'paths': (
        'tests/kitchen_spike/', 'code/game/objects/structures/kitchen_spike.dm')},
    'statue_appearance': {'files': ('tests/statue_appearance/test_statue_appearance.py',), 'paths': (
        'tests/statue_appearance/', 'code/game/objects/structures/religious.dm')},
    'weightlifter': {'files': ('tests/weightlifter/test_weightlifter.py',), 'paths': (
        'tests/weightlifter/', 'code/game/objects/structures/fitness.dm')},
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
    'glass_jar': {'files': ('tests/glass_jar/test_capture.py',), 'paths': (
        'tests/glass_jar/', 'code/game/objects/items/glassjar.dm', 'tests/save_movement/source_adapter.py')},
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
    'smokables': {'files': ('tests/smokables/test_burn_state.py',),
        'paths': ('tests/smokables/',), 'shared_paths': (
            'code/game/objects/items/weapons/cigs_lighters.dm',
            'tests/save_movement/source_adapter.py')},
    'river_flow': {'files': ('tests/river_flow/test_generation.py',),
        'paths': ('tests/river_flow/', 'scripts/river_flow.py'),
        'shared_paths': ('code/modules/1713/river_flow.dm',
                         'code/processes/river_current.dm',
                         'code/modules/1713/machinery/renewable_generation.dm',
                         'scripts/terrain_heights.py', 'maps/heights/',
                         'maps/nomads/nomads_gaia.dmm', 'maps/nomads/nomads_europe.dmm',
                         'maps/nomads/nomads_jungle.dmm', 'maps/nomads/nomads_asia.dmm')},
    'cleaning_rag': {'files': ('tests/cleaning_rag/test_targets.py',),
        'paths': ('tests/cleaning_rag/',), 'shared_paths': (
            'code/game/objects/items/weapons/detective.dm', 'code/_helpers/mobs.dm',
            'tests/save_movement/source_adapter.py')},
    'lipstick_application': {'files': ('tests/lipstick_application/test_completion.py',),
        'paths': ('tests/lipstick_application/',), 'shared_paths': (
            'code/game/objects/items/weapons/cosmetics.dm', 'code/_helpers/mobs.dm',
            'tests/save_movement/source_adapter.py')},
    'centre_tile': {'files': ('tests/centre_tile/test_sources.py',),
        'paths': ('tests/centre_tile/',), 'shared_paths': (
            'code/game/mob/living/carbon/human/subtile_movement.dm',
            'code/game/mob/mob_movement.dm',
            'code/game/mob/living/simple_animal/riding.dm',
            'code/game/mob/living/living.dm',
            'code/game/turfs/floor_attackby.dm',
            'code/modules/1713/trench.dm')},
    'motorcycle_riding': {'files': ('tests/motorcycle_riding/test_sources.py',),
        'paths': ('tests/motorcycle_riding/',), 'shared_paths': (
            'code/game/objects/buckling.dm',
            'code/game/objects/structures/transports.dm')},
    'paint_buckets': {'files': ('tests/paint_buckets/test_colors.py',),
        'paths': ('tests/paint_buckets/',), 'shared_paths': (
            'code/game/objects/items/weapons/paint.dm',
            'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Other.dm',
            'tests/save_movement/source_adapter.py')},
    'sledgehammer': {'files': ('tests/sledgehammer/test_two_hands.py',),
        'paths': ('tests/sledgehammer/',), 'shared_paths': (
            'code/game/objects/items/weapons/sledgehammer.dm', 'tests/save_movement/source_adapter.py')},
    'serving_tray': {'files': ('tests/serving_tray/test_targeting.py',),
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
    'football_tackle': {'files': ('tests/football_tackle/test_target.py',),
        'paths': ('tests/football_tackle/',), 'shared_paths': (
            'code/modules/1713/football.dm', 'tests/save_movement/source_adapter.py')},
    'trumpet_notes': {'files': ('tests/trumpet_notes/test_notes.py',),
        'paths': ('tests/trumpet_notes/',), 'shared_paths': (
            'code/game/objects/items/devices/trombone.dm', 'sound/trombone/')},
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
    'television': {'files': ('tests/television/test_contract.py',),
        'paths': ('tests/television/',), 'shared_paths': (
            'code/modules/1713/television.dm', 'code/modules/1713/modern_telecom.dm',
            'code/modules/1713/cmss13_overwatch.dm',
            'code/modules/research_tree/node_broadcast.dm')},
    'node_broadcast': {'files': ('tests/node_broadcast/test_contract.py',),
        'paths': ('tests/node_broadcast/',), 'shared_paths': (
            'code/modules/research_tree/node_broadcast.dm',
            'code/modules/1713/modern_telecom.dm')},
    'recipe_knowledge': {'files': ('tests/recipe_knowledge/test_contract.py',),
        'paths': ('tests/recipe_knowledge/',), 'shared_paths': (
            'code/modules/research_tree/character_knowledge.dm',
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
    # Complete oil-well ownership helpers with fake locations/reagents; no native IO.
    'oilwell_barrels': {'files': ('tests/petroleum_lifecycle/test_barrel_recovery.py',),
        'paths': ('tests/petroleum_lifecycle/test_barrel_recovery.py',),
        'shared_paths': ('code/modules/1713/production.dm',
                         'code/modules/1713/factory_chemistry.dm',
                         'code/modules/1713/factory_pipes.dm',
                         'tests/save_movement/source_adapter.py')},
    # Explosion remains above the ground: production wiring and map level audit.
    'explosion_remains': {'files': ('tests/explosion_remains/test_explosion_remains.py',),
        'paths': ('tests/explosion_remains/',), 'shared_paths': (
            'code/modules/multiz/explosion_remains.dm', 'code/game/turfs/floor.dm',
            'code/game/turfs/floor_types.dm', 'code/game/turfs/walls.dm',
            'code/game/turfs/floor_attackby.dm', 'code/modules/1713/tools.dm',
            'code/modules/projectiles/__projectiles.dm',
            'code/modules/projectiles/projectile/cannon.dm', 'civ13.dme')},
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
    # Complete mood helpers, maintenance and expression projections; no native world.
    # Production paths retain the prior conservative fallback/neighbor selection.
    'mood_sleep': {'files': ('tests/mood_sleep/test_mood_sleep.py',),
        'paths': ('tests/mood_sleep/',), 'shared_paths': (
            'tests/save_movement/source_adapter.py',)},
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
    # TDM servers vote only between team battle epochs; source projection, no BYOND runtime.
    'tdm_map_vote': {'files': ('tests/tdm_map_vote/test_tdm_epochs.py',),
        'paths': ('tests/tdm_map_vote/',), 'shared_paths': ('code/processes/mapswap.dm',)},
    # Windows scheduled-task host control with a fake machine; no BYOND runtime.
    'gaia_host': {'files': ('tests/gaia_host/test_gaia_host.py', 'tests/gaia_host/test_shard_group.py',
                           'tests/gaia_host/test_doorman.py', 'tests/gaia_host/test_wait_group.py',
                           'tests/gaia_host/test_relay.py', 'tests/gaia_host/test_mobile_host.py'),
        'paths': ('tests/gaia_host/', 'scripts/gaia-host/', 'scripts/shard-group/', 'scripts/windows/host/'),
        'shared_paths': ('scripts/nomads-lifecycle/supervisor.py',)},
    # Farmer's almanac weather table and crop rule projected from production DM.
    'farmers_almanac': {'files': ('tests/farmers_almanac/test_farmers_almanac.py',),
        'paths': ('tests/farmers_almanac/',), 'shared_paths': (
            'code/modules/1713/farmers_almanac.dm',
            'code/modules/1713/weather.dm',
            'code/game/objects/farming.dm')},
    # Gun sprite-state fallback: reviewed gap list against the DMI files and the
    # render paths that apply it. run.py (native sweep) is not part of this suite.
    'gun_icon_states': {'files': ('tests/gun_icon_states/test_gun_icon_states.py',),
        'paths': ('tests/gun_icon_states/', 'code/_helpers/sprite_states.dm'),
        'shared_paths': (
            'code/game/mob/living/carbon/human/update_icons.dm',
            'code/modules/projectiles/gun.dm',
            'code/modules/projectiles/guns/projectile.dm',
            'icons/obj/guns/', 'icons/mob/items/lefthand_guns.dmi',
            'icons/mob/items/righthand_guns.dmi', 'icons/mob/back.dmi', 'civ13.dme')},
    # Ploughed field sprite selection and load restore projected from production DM.
    'ploughed_field_icon': {'files': ('tests/ploughed_field_icon/test_ploughed_field_icon.py',),
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
    # Research bench intent routing, timed maintenance and slot cleanup; offline only.
    'research_bench': {'files': ('tests/research_bench/test_maintenance.py',),
        'paths': ('tests/research_bench/',), 'shared_paths': (
            'code/modules/research_tree/research_bench.dm',
            'code/modules/research_tree/research_faction.dm',
            'code/modules/research_tree/_research_tree_defines.dm')},
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
    'door_intents': {'files': ('tests/door_intents/test_door_intents.py',),
        'paths': ('tests/door_intents/',), 'shared_paths': (
            'code/game/objects/structures/door.dm',
            'code/modules/persistence/world_time_stamps.dm',
            'code/game/objects/structures/key_doors/key_door.dm')},
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

    # Razor grooming guard and hygiene-gated razor recipes; source checks only.
    'razor_grooming': {'files': ('tests/razor_grooming/test_razor.py',),
        'paths': ('tests/razor_grooming/',), 'shared_paths': (
            'code/game/objects/items/weapons/material/kitchen.dm',
            'config/crafting/material_recipes_global.txt',
            'code/modules/research_tree/research_node.dm')},

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
                                 'tests/account_signin/test_account_keys.py'),
        'paths': ('tests/account_signin/', 'tools/account_signin/'),
        'shared_paths': ('code/modules/accounts/discord_accounts.dm', 'code/modules/client/client_procs.dm',
                         'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/region_travel.dm',
                         'tests/save_movement/source_adapter.py')},

    # Offline ownership, continuation and source controls; the one Git process
    # runs only against a freshly created synthetic test repository. No BYOND run.
    'wildlife_offline': {'files': (
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
        'code/game/mob/living/simple_animal/', 'code/game/mob/living/living.dm',
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
                                  'tests/paper_documents/test_study.py'),
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
    'telephone_recipients': {'files': ('tests/telephone/test_recipients.py',),
        'paths': ('tests/telephone/',), 'shared_paths': (
            'code/modules/1713/telephone.dm', 'tests/save_movement/source_adapter.py')},

    # Stdlib + reviewed source projection only; frozen DM is offline data.
    # No native runner, engine process, socket or network boundary is imported.
    'defibrillator_charge': {'files': ('tests/defibrillator/test_charge_revalidation.py',),
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
    'help_wiki_guides': {'files': ('tests/player_help/test_wiki_guides.py',),
        'paths': (), 'shared_paths': (
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
            'code/modules/client/preferencesSQLite/preference_setup/general/01_basic.dm',
            'code/modules/client/preferencesSQLite/preferences.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm',
            'code/game/mob/living/carbon/human/human_life.dm',
            'code/game/mob/living/carbon/human/human_stats.dm')},
    # Reviewed stdlib-only projection; shared production changes keep fallback.
    'tablet_press': {'files': ('tests/tablet_press/test_contract.py',),
        'paths': ('tests/tablet_press/',),
        'shared_paths': ('code/modules/reagents/tablet_press.dm',
            'code/game/objects/items/stacks/stack.dm',
            'code/game/objects/items/stacks/civ_recipes.dm',
            'code/modules/research_tree/research_node.dm',
            'code/modules/reagents/laboratory.dm', 'config/crafting/')},
    # Source-only pointer inventory/hooks and injected alert counter. Imports are
    # stdlib plus the existing inert save-movement projection, and the link test
    # imports the cross-level runner only to stage files; no native launch.
    'persistence_pointers': {'files': ('tests/persistence_pointers/test_contract.py',
                                    'tests/persistence_pointers/test_restore_dependents.py',
                                    'tests/persistence_pointers/test_action_reconnect.py',
                                    'tests/persistence_pointers/test_level_links.py',
                                    'tests/persistence_pointers/test_world_time_stamps.py',
                                    'tests/persistence_pointers/test_restored_languages.py'),
        'paths': ('tests/persistence_pointers/',),
        'shared_paths': ('code/modules/persistence/',
            'code/game/mob/living/simple_animal/',
            'code/game/mob/living/carbon/human/pull_pair_ownership.dm',
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
    'policy': {'files': POLICY_FILES, 'always': True, 'paths': ()},
    'bootstrap': {'files': ('tests/test_byond_bootstrap.py', 'tests/test_byond_toolchain.py',
                            'tests/test_byond_runtime.py', 'tests/test_sprite_toolchain.py'), 'always': True, 'paths': ()},
    'progress': {'files': ('tests/world_save/test_progress_sources.py',), 'always': True, 'paths': ()},
    # Source-only inventories the native moving-save lane pins (collision overrides,
    # animal save hooks). They scan all production DM, so they run on every PR: the
    # PR that edits a listed file refreshes the inventory, not the next save PR.
    'movement_save_inventory': {'files': ('tests/movement_save_chunks/test_collision_manifest.py',
                                          'tests/movement_save_chunks/test_chunks.py'),
                                'always': True, 'paths': ()},
    # Stdlib-only scalar/callback projections; no native runner or subprocesses.
    # Shared chemistry/stack sources retain their conservative all-suite fallback.
    'grinder': {'files': ('tests/grinder/test_transaction.py',),
        'paths': ('tests/grinder/',), 'shared_paths': (
            'code/modules/reagents/Chemistry-Machinery.dm',
            'code/modules/materials/material_sheets.dm',
            'code/game/objects/structures/kitchen/oven.dm',
            'code/modules/1713/wood_ash_compost.dm',
            'code/game/objects/structures.dm',
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
    'flora_regressions': {'files': ('tests/flora_regrowth/test_regressions.py',), 'paths': (
        'tests/flora_regrowth/', 'code/modules/ecology/flora_regrowth.dm')},
    'pollution': {'files': ('tests/pollution/test_pollution.py',), 'paths': (
        'tests/pollution/', 'code/modules/ecology/pollution.dm', 'code/processes/pollution.dm',
        'code/modules/reagents/reagent_pollution.dm',
        'icons/effects/pollution.dmi')},
    'hub_status': {'files': ('tests/test_hub_status.py',), 'paths': (
        'tests/test_hub_status.py', 'code/world.dm', 'config/config.txt')},
    # Shared transport/persistence files retain their existing all-suite fallback.
    'carriage_glide': {'files': ('tests/carriage_glide/test_sources.py',), 'paths': (
        'tests/carriage_glide/',)},
    'throw_launch': {'files': ('tests/throw_launch_clearance/test_launch.py',
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
            'code/game/mob/living/carbon/human/human_life.dm')},
    # Keep mixed production static.dm unmapped: its existing all-suite fallback
    # must still cover changes to fish, piranhas and ants, not just fishing.
    'fishing_stock': {'files': ('tests/fishing_stock/test_source_contract.py',
                                'tests/fishing_stock/test_preparation.py',
                                'tests/fishing_stock/test_native_runner.py',
                                'tests/fishing_stock/test_ocean_fishing.py'), 'paths': (
        'tests/fishing_stock/',)},
    # Source and injected-help contracts only; this suite does not run DM.
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
    'save_movement': {'files': ('tests/save_movement/test_guard.py',), 'paths': (
        'tests/save_movement/', 'code/modules/persistence/functions.dm')},
    # Full import graph: stdlib source adapter, catalog-only Atlas builder/projector,
    # and inert Help imports. No native sprite export or engine launch.
    # Shared material/Atlas inputs retain their conservative all-suite fallback.
    'woodworking': {'files': ('tests/primitive_woodworking/test_source.py',
                              'tests/test_atlas_navigation.py'), 'paths': (
        'tests/primitive_woodworking/', 'code/modules/1713/primitive_woodworking.dm',
        'scripts/atlas/woodworking.py', 'scripts/atlas/woodworking-contract.json',
        'code/modules/persistence/functions.dm', 'civ13.dme')},
    # Offline only: reviewed guard projection, catalog generation, inert Help imports.
    # Shared crafting/Atlas files keep the conservative all-suite fallback.
    'furniture_joinery': {'files': ('tests/furniture_joinery/test_contract.py',
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
                              'tests/save_policy/test_save_validator_boot.py'), 'paths': (
        'tests/save_policy/', 'code/world.dm', 'code/datums/vote.dm',
        'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
        'code/modules/persistence/save_validator.dm')},
    # Offline source contracts for the fireman carry (grab on a downed human).
    'fireman_carry': {'files': ('tests/fireman_carry/test_source.py',), 'paths': (
        'tests/fireman_carry/', 'code/game/mob/grab_carry.dm'),
        'shared_paths': ('code/game/mob/grab.dm', 'code/game/mob/mob_movement.dm')},
    # Offline source contracts for field treatment and artery repair.
    'medical_care': {'files': ('tests/medical_care/test_source.py',), 'paths': (
        'tests/medical_care/', 'code/game/objects/items/stacks/medical.dm',
        'code/modules/surgery/other.dm', 'code/modules/1713/doctor_handbook.dm'),
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
    'hud_layout': {'files': ('tests/hud_layout/test_layout.py',),
        'paths': ('tests/hud_layout/', 'code/_onclick/hud/hud_layout.dm'),
        'shared_paths': ('code/game/mob/living/carbon/human/human_hud.dm',
            'code/game/mob/living/carbon/human/update_icons.dm', 'code/game/mob/inventory.dm',
            'code/_onclick/hud/hud.dm', 'code/_onclick/hud/action.dm',
            'code/game/objects/items/weapons/storage/storage.dm',
            'code/game/objects/items/weapons/storage/bags.dm',
            'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm', 'civ13.dme')},
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
    'last_save_status': {'files': ('tests/last_save_status/test_last_save.py',),
        'paths': ('tests/last_save_status/', 'code/modules/persistence/last_save_status.dm'),
        'shared_paths': ('code/modules/statpanel/statpanel.dm', 'code/modules/persistence/functions.dm',
            'code/modules/persistence/saving.dm', 'civ13.dme')},
    # Handcuff placement races and per-human chew cooldown (#4229, #4230).
    # Faction recruitment applications, offers and their durable field (#4237).
    'faction_recruitment': {'files': ('tests/faction_recruitment/test_source.py',),
        'paths': ('tests/faction_recruitment/', 'code/game/mob/groups/faction_recruitment.dm'),
        'shared_paths': ('code/game/mob/groups/faction_membership.dm', 'code/game/mob/groups/faction_rename.dm',
            'code/game/mob/groups/factions.dm', 'code/modules/persistence/durable_contract.dm',
            'code/game/mob/living/carbon/human/death.dm', 'code/modules/1713/cmss13_squad.dm',
            'civ13.dme')},
    # Faction recruitment authority and the shared enrollment transition (#4237).
    'faction_membership': {'files': ('tests/faction_membership/test_source.py',),
        'paths': ('tests/faction_membership/', 'code/game/mob/groups/faction_membership.dm',
            'code/game/mob/living/carbon/give.dm'),
        'shared_paths': ('code/game/mob/groups/factions.dm', 'code/modules/1713/marketplace.dm',
            'code/modules/research_tree/research_faction.dm', 'civ13.dme')},
    'handcuffs': {'files': ('tests/handcuffs/test_source.py',),
        'paths': ('tests/handcuffs/', 'code/game/objects/items/weapons/handcuffs.dm')},
    # Spray bottle acceptance, feedback and reagent logging (#4269, #4270).
    'spray': {'files': ('tests/spray/test_source.py',),
        'paths': ('tests/spray/', 'code/modules/reagents/reagent_containers/spray.dm')},
    # Snow barricade completion keeps its own direction (#4290).
    'snow_barricade': {'files': ('tests/snow_barricade/test_source.py',),
        'paths': ('tests/snow_barricade/', 'code/modules/1713/barriers/snow_walls.dm'),
        'shared_paths': ('code/modules/1713/barriers/sandbag.dm',)},
    # Trap disarm recheck and punji animal capture/release (#4248, #4249).
    'traps': {'files': ('tests/traps/test_source.py',),
        'paths': ('tests/traps/', 'code/game/objects/items/weapons/traps.dm')},
}
CI_PATHS = ('scripts/select-ci.py', 'scripts/ci_baseline.py',
            '.github/workflows/ci-selection.yml', '.github/workflows/test.yml')
TIMEOUT = 30  # per reviewed suite; enclosing job also has a wall-clock limit


def suite_deadline():
    """scripts/local_ci.py raises the deadline on slower workstations (git is
    slow on Windows); hosted CI never sets it. Bounded so a typo cannot disable it."""
    value = os.environ.get('CIV13_LOCAL_SUITE_TIMEOUT', '')
    return min(600, max(TIMEOUT, int(value))) if value.isdigit() else TIMEOUT
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


def skill_prose(path):
    parts = path.split('/')
    return (len(parts) >= 4 and parts[:2] == ['.agents', 'skills']
            and all(part not in ('', '.', '..') for part in parts)
            and (parts[-1] == 'SKILL.md'
                 or ('references' in parts[3:-1] and parts[-1].endswith('.md'))))


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
            deadline = suite_deadline()
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

