import type { ComponentType } from 'react';
import type { ScreenProps } from '../types';
import { Appearance, Chemistry, Vending, Warehouse } from './Standard';
import { Faction } from './Faction';
import { Research } from './Research';
import { KnownLanguages } from './KnownLanguages';
import { ShipStocks } from './ShipStocks';
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
};
