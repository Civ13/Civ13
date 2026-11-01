import type { ComponentType } from 'react';
import type { ScreenProps } from '../types';
import { Appearance, Chemistry, Vending, Warehouse } from './Standard';
import { Faction } from './Faction';
import { Research } from './Research';
import { KnownLanguages } from './KnownLanguages';
import { ShipStocks } from './ShipStocks';
import { ReligionList } from './ReligionList';
import { CrewLog } from './CrewLog';
import { FactionList } from './FactionList';
import { CraftingAtlas } from './CraftingAtlas';
import { CharacterFlavor } from './CharacterFlavor';
import { PhotoViewer } from './PhotoViewer';
export const interfaces: Record<string, ComponentType<ScreenProps>> = {
  'appearance_changer.tmpl': Appearance,
  'chem_disp.tmpl': Chemistry,
  'faction_creation.tmpl': Faction,
  'faction_symbol.tmpl': Faction,
  'research_bench.tmpl': Research,
  'vending_machine.tmpl': Vending,
  'vending_machine2.tmpl': Vending,
  'vending_machine_gulag.tmpl': Vending,
  'vending_machine_taotd.tmpl': Vending,
  'warehouse_book.tmpl': Warehouse,
  'known_languages.tmpl': KnownLanguages,
  'ship_stocks.tmpl': ShipStocks,
  'religion_list.tmpl': ReligionList,
  'crew_log.tmpl': CrewLog,
  'faction_list.tmpl': FactionList,
  'crafting_atlas.tmpl': CraftingAtlas,
  'character_flavor.tmpl': CharacterFlavor,
  'photo_viewer.tmpl': PhotoViewer,
};
