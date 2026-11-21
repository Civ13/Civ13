import type { ComponentType } from 'react';
import type { ScreenProps } from '../types';
import { Appearance, Chemistry, Vending, Warehouse } from './Standard';
import { Faction } from './Faction';
import { Research } from './Research';
import { ResearchBook } from './ResearchBook';
import { KnownLanguages } from './KnownLanguages';
import { ShipStocks } from './ShipStocks';
import { ReligionList } from './ReligionList';
import { CrewLog } from './CrewLog';
import { FactionList } from './FactionList';
import { CraftingAtlas } from './CraftingAtlas';
import { CharacterFlavor } from './CharacterFlavor';
import { CharacterNotes } from './CharacterNotes';
import { PhotoViewer } from './PhotoViewer';
import { BookReader } from './BookReader';
import { PaperEditor } from './PaperEditor';
import { Prompt } from './Prompt';
import { RecruitmentStation } from './RecruitmentStation';
import { CraftingWindow } from './CraftingWindow';
import { Panel } from './Panel';
import { CharacterSetup } from './CharacterSetup';
import { StorageWindow } from './StorageWindow';
import { SpawnMenu } from './SpawnMenu';
import { WiremodCircuit } from './WiremodCircuit';
import { Haircut } from './Haircut';
export const interfaces: Record<string, ComponentType<ScreenProps>> = {
  'appearance_changer.tmpl': Appearance,
  'chem_disp.tmpl': Chemistry,
  'faction_creation.tmpl': Faction,
  'faction_symbol.tmpl': Faction,
  'research_bench.tmpl': Research,
  'research_book.tmpl': ResearchBook,
  'tech_tree.tmpl': Research,
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
  'character_notes.tmpl': CharacterNotes,
  'photo_viewer.tmpl': PhotoViewer,
  'book_reader.tmpl': BookReader,
  'paper_editor.tmpl': PaperEditor,
  'prompt.tmpl': Prompt,
  'recruitment_station.tmpl': RecruitmentStation,
  'crafting_window.tmpl': CraftingWindow,
  'panel.tmpl': Panel,
  'character_setup.tmpl': CharacterSetup,
  'storage_window.tmpl': StorageWindow,
  'spawn_menu.tmpl': SpawnMenu,
  'wiremod_circuit.tmpl': WiremodCircuit,
  'haircut.tmpl': Haircut,
};
