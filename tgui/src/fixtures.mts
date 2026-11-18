// One set of fictional snapshots for every window. The gallery and screenshot
// script and the unit tests read these, so a window's sample data lives in one
// place. Names and text are invented for previews. Node runs this file as it is,
// so it uses only type syntax that can be erased.
import type { AppearanceData, CharacterSetupData, ChemistryData, CrewLogData, KnownLanguagesData, PanelData, PromptData, ReligionListData, ShipStocksData, SpawnMenuData, StorageWindowData, VendingData, WarehouseData } from './data.ts';
import type { Data } from './types.ts';
// Windows with a declared snapshot type; their fixtures are checked against it.
type Typed = {
  'appearance_changer.tmpl': AppearanceData; 'character_setup.tmpl': CharacterSetupData; 'chem_disp.tmpl': ChemistryData; 'crew_log.tmpl': CrewLogData; 'known_languages.tmpl': KnownLanguagesData;
  'panel.tmpl': PanelData; 'prompt.tmpl': PromptData; 'religion_list.tmpl': ReligionListData; 'ship_stocks.tmpl': ShipStocksData; 'spawn_menu.tmpl': SpawnMenuData; 'storage_window.tmpl': StorageWindowData; 'warehouse_book.tmpl': WarehouseData;
  'vending_machine.tmpl': VendingData; 'vending_machine2.tmpl': VendingData; 'vending_machine_gulag.tmpl': VendingData; 'vending_machine_taotd.tmpl': VendingData;
};
export type Fixture = { name: string; template: string; title: string; width: number; height: number; data: Data };
export const screens: Fixture[] = [];
// Window sizes as the game opens them (width, height).
const sizes = {
  'appearance_changer.tmpl': [800, 450], 'book_reader.tmpl': [625, 650], 'character_flavor.tmpl': [500, 200], 'character_notes.tmpl': [625, 650], 'character_setup.tmpl': [860, 720],
  'chem_disp.tmpl': [390, 655], 'crafting_atlas.tmpl': [1000, 700], 'crafting_window.tmpl': [940, 680], 'crew_log.tmpl': [500, 520],
  'faction_creation.tmpl': [620, 900], 'faction_list.tmpl': [420, 520], 'faction_symbol.tmpl': [620, 760], 'known_languages.tmpl': [600, 480],
  'paper_editor.tmpl': [625, 650], 'panel.tmpl': [380, 420], 'photo_viewer.tmpl': [360, 400], 'prompt.tmpl': [420, 240], 'recruitment_station.tmpl': [520, 640],
  'religion_list.tmpl': [450, 450], 'research_bench.tmpl': [900, 680], 'research_book.tmpl': [620, 660], 'ship_stocks.tmpl': [500, 520], 'spawn_menu.tmpl': [640, 640], 'storage_window.tmpl': [760, 600], 'tech_tree.tmpl': [900, 680],
  'vending_machine.tmpl': [540, 600], 'vending_machine2.tmpl': [540, 600], 'vending_machine_gulag.tmpl': [540, 600], 'vending_machine_taotd.tmpl': [540, 600],
  'warehouse_book.tmpl': [400, 500], 'wiremod_circuit.tmpl': [760, 700],
} satisfies Record<string, [number, number]>;
function add<T extends keyof typeof sizes>(name: string, template: T, data: T extends keyof Typed ? Typed[T] : Data, title?: string, size?: [number, number]) {
  const [width, height] = size ?? sizes[template];
  screens.push({ name, template, title: title ?? name.replace(/-/g, ' ').replace(/^./, c => c.toUpperCase()), width, height, data });
}
const node = (id: string, name: string, status_text: string, extra: Data = {}) => ({ id, name, status_text, cost_ticks: 120, progress_percent: 0, era_tier: 1, min_bench_tier: 1, mode_text: 'Study', ...extra });
add('research', 'research_bench.tmpl', {
  bench_tier: 2, max_tier: 3, bench_faction: 'Dawnward Guild', owns_bench: 1,
  has_faction: 1, viewer_role: 'Researcher', viewer_faction: 'Dawnward Guild', viewer_bench_count: 2, viewer_cap: 4,
  assigned_name: 'Bronze working', assigned_status_text: 'Study in progress - 55%', queue_names: ['Iron working'], can_queue: 1,
  trees: [{ idx: 0, tree_name: 'Craft and industry', layers: [
    { layer_name: 'Foundations', nodes: [node('stone', 'Stone tools', 'Done', { progress_percent: 100 }), node('clay', 'Pottery', 'Done', { grid_col: 3, progress_percent: 100 })] },
    { layer_name: 'Bronze age', nodes: [node('bronze', 'Bronze working', 'Available', { prereq_ids: 'stone', progress_percent: 55, assignable: 1, recipe_names: ['Bronze axe', 'Bronze spear'] }), node('kiln', 'Advanced kilns', 'Available', { grid_col: 3, prereq_ids: 'clay', queueable: 1 })] },
    { layer_name: 'Iron age', nodes: [node('iron', 'Iron working', 'Locked', { prereq_ids: 'bronze', is_era_changing: 1, cost_ticks: 240 }), node('masonry', 'Masonry', 'Locked', { grid_col: 3, prereq_ids: 'kiln' })] },
  ] }, { idx: 1, tree_name: 'Agriculture', layers: [] }],
});
const known = (id: string, name: string, state: string, label: string, extra: Data = {}) => node(id, name, ({ known: 'Done', ready: 'Available' } as Record<string, string>)[state] ?? 'Locked', { state, state_label: label, ...extra });
add('tech-tree', 'tech_tree.tmpl', { tech_tree: 1, book_research: 1, focus: 'pillar', focus_seq: 1,
  trees: [{ idx: 0, tree_name: 'Craft and industry', layers: [
    { layer_name: 'Foundations', nodes: [known('stone', 'Stone tools', 'known', 'You know this'), known('clay', 'Pottery', 'ready', 'Ready to learn', { grid_col: 3 })] },
    { layer_name: 'Building', nodes: [known('masonry', 'Stone masonry', 'ready', 'Ready to learn', { prereq_ids: 'stone', groundwork: [{ id: 'stone', name: 'Stone tools', known: 1 }] }), known('kiln', 'Advanced kilns', 'locked', 'Needs groundwork', { grid_col: 3, prereq_ids: 'clay' })] },
    { layer_name: 'Monuments', nodes: [known('pillar', 'Pillars and columns', 'locked', 'Needs groundwork', { prereq_ids: 'masonry', recipe_names: ['stone pillar', 'monumental stone pillar'], groundwork: [{ id: 'masonry', name: 'Stone masonry', known: 0 }] })] },
  ] }, { idx: 1, tree_name: 'Agriculture', layers: [] }],
}, 'Tech tree');
const grid = Array.from({ length: 1024 }, (_, i) => {
  const x = i % 32, y = Math.floor(i / 32);
  if (x < 2 || x > 29 || y < 2 || y > 29) return '#d8ae58';
  if (Math.abs(x - 15.5) + Math.abs(y - 15.5) < 9) return '#f6d77f';
  return '#193c52';
});
add('faction', 'faction_creation.tmpl', { name: 'Dawnward Guild', motto: 'Build together, discover together', flavour: 'A fictional fellowship for this interface preview.', grid, color: '#f6d77f', tool: 'paint' });
add('chemistry', 'chem_disp.tmpl', { amount: 10, chemicals: ['Water', 'Carbon', 'Hydrogen', 'Oxygen', 'Nitrogen', 'Iron', 'Copper', 'Sulfur', 'Potassium', 'Sodium', 'Chlorine', 'Phosphorus'].map(title => ({ title, id: title.toLowerCase() })), isBeakerLoaded: 1, beakerCurrentVolume: 30, beakerMaxVolume: 100, beakerContents: [{ name: 'Water', volume: 20 }, { name: 'Carbon', volume: 10 }] });
add('warehouse', 'warehouse_book.tmpl', { items: [{ name: 'Oak planks', amount: 120 }, { name: 'Stone blocks', amount: 84 }, { name: 'Iron ingots', amount: 36 }, { name: 'Linen cloth', amount: 52 }, { name: 'Wheat sacks', amount: 18 }] });
// The rest of the windows, so a UI change can be compared before and after.
const craftRow = (id: string, name: string, state: string, extra: Data = {}) => ({ id, name, state, category: 'General', purpose: 'Building', pinned: 0, recent: 0, cost: '4 logs', why: '', tools: '', desc: '', built: 0, one_per_turf: 0, on_floor: 0, time: 140, makes: 1, batches: state === 'ready' ? 1 : 0, atlas: 0, image: '', ...extra });
add('religion-list', 'religion_list.tmpl', { religions: [{ name: 'Sun Wardens', points: 340 }, { name: 'River Mothers', points: 215 }, { name: 'Order of the Ash', points: 90 }] });
add('ship-stocks', 'ship_stocks.tmpl', { stocks: ([['Treasury', 1240, 'reales'], ['Wood', 86, 'logs'], ['Cloth', 40, 'sheets'], ['Rope', 22, 'coils'], ['Food', 310, 'doses']] as [string, number, string][]).map(([label, amount, unit]) => ({ label, amount, unit })) });
add('crew-log', 'crew_log.tmpl', { crew: [['Anne Hale', 'Captain'], ['Tom Reed', 'Boatswain'], ['Will Marsh', 'Sailor'], ['Edda Stone', 'Surgeon']].map(([name, job]) => ({ name, job })) });
add('faction-list', 'faction_list.tmpl', { factions: [{ name: 'Dawnward Guild', motto: 'Build together', flavour: 'A fictional fellowship.', members: 4, symbol: '', renamed: '' }, { name: 'Ash Company', members: 1, symbol: '' }] });
add('known-languages', 'known_languages.tmpl', { current_default: 'Common', languages: [{ name: 'Common', prefix: ',0', description: 'Spoken nearly everywhere.', is_default: 1 }, { name: 'Old Tongue', prefix: ',o', description: 'A scholarly language.' }] });
add('panel', 'panel.tmpl', { sections: [
  { title: 'Lock', rows: [{ label: 'Dial', value: 35, buttons: [{ label: '-', action: 'decrement' }, { label: '+', action: 'increment' }] }, { label: 'Door', value: 'Open', tone: 'good' }], buttons: [{ label: 'Close the safe', action: 'open' }] },
  { title: 'Contents', items: [{ name: 'Ledger', detail: 'A bound book of accounts.', buttons: [{ label: 'Read', action: 'read', id: 'a' }, { label: 'Take', action: 'retrieve', id: 'a' }] }, { name: 'Silver coins', buttons: [{ label: 'Take', action: 'retrieve', id: 'b' }] }], empty: 'It is empty.' },
] }, 'Iron safe');
add('panel-readings', 'panel.tmpl', { sections: [
  { title: 'Machines', notes: ['Where is east, north of this monitor.'], table: { columns: ['Machine', 'Where', 'State', 'Items/min', 'Notes'], rows: [
    ['feeder arm', '2, 0', { text: 'running', tone: 'good' }, 12, 'only iron ingots'], ['fabricator', '3, 0', { text: 'starved', tone: 'warn' }, 0, 'Nails, 40%'], ['belts', '', { text: 'idle', tone: 'muted' }, 0, '14 belts, 0 carrying items']] } },
  { title: 'Power', rows: [{ label: 'Supply', value: '100 kW' }, { label: 'Demand', value: '62 kW', tone: 'good' }],
    chart: { slots: 60, top: '100 kW', left: 'one minute ago', right: 'now', series: [
      { label: 'supply', tone: 'good', points: Array.from({ length: 60 }, () => 100) }, { label: 'demand', tone: 'progress', points: Array.from({ length: 60 }, (_, i) => 40 + (i * 7) % 30) }] } },
] }, 'Factory monitor', [680, 560]);
add('prompt', 'prompt.tmpl', { message: 'The tide is coming in.', choices: ['Continue'] });
add('vending', 'vending_machine2.tmpl', { company: 'Dawnward Trading', moneyin: 12, currency_name: 'silver', currency_short: 'sp', mode: 0, products: [{ key: 1, name: 'Bread loaf', price: 2, amount: 8 }, { key: 2, name: 'Iron hatchet', price: 14, amount: 1 }, { key: 3, name: 'Linen shirt', price: 6, amount: 0 }] });
add('recruitment', 'recruitment_station.tmpl', {
  station: 1, bound: 1, supported: 1, faction: 'Dawnward Guild', motto: 'Build together, discover together', summary: 'Open to anyone who speaks Common and has Crafting 3.', expiry_days: 3, can_unbind: 1, can_review: 1,
  queue: [{ id: 4, name: 'Mara Flint', status: 'pending', status_text: 'Waiting for review', submitted: '2 hours', expires: '2 days', intro: 'I can smith and I have my own tools.', results: ['Speaks Common: met', 'Crafting 4/10, needs 3: met'] },
    { id: 5, name: 'Jon Weir', status: 'approved', status_text: 'Approved', submitted: '1 day', expires: '1 day', exception: 1, results: ['Speaks Common: met', 'Crafting 1/10, needs 3: not met'] }],
  policy: { mode: 'manual', open: 1, language: 'Common', nonmatch: 'review', skills: [{ key: 'crafting', label: 'Crafting', level: 3 }, { key: 'farming', label: 'Farming', level: 0 }] },
  audit: ['Leader set Crafting to 3 (1 day ago)'],
});
add('crafting', 'crafting_window.tmpl', { material: 'wood logs', unit: 'log', amount: 6, image: '', makeable_only: 0, categories: ['weapons', 'joinery'], purposes: ['Tools', 'Weapons', 'Building', 'Furniture', 'Other'], working: null, more_images: 0, rows: [
  craftRow('0:1:aaaaaaaa', 'campfire', 'ready', { built: 1, one_per_turf: 1, on_floor: 1, desc: 'A campfire made with wood logs.', atlas: 1 }),
  craftRow('2:1:bbbbbbbb', '3x arrow shaft', 'ready', { category: 'weapons', purpose: 'Weapons', cost: '1 log', makes: 3, batches: 6, time: 40 }),
  craftRow('0:2:cccccccc', 'travois', 'missing', { cost: '8 logs', why: 'Needs 8 logs, you have 6' }),
  craftRow('2:2:eeeeeeee', 'shortbow', 'locked', { category: 'weapons', purpose: 'Weapons', cost: '8 logs', why: 'Needs the Archery manual' }),
] });
add('atlas', 'crafting_atlas.tmpl', { mode: 'graph', query: 'plank', era: '', processor: '', recipe_count: 2, resource_count: 1, recipes: [{ id: 'r2', name: 'Planks', era_label: '0: Stone Age' }, { id: 'r3', name: 'Plank wall', era_label: '0: Stone Age' }], resources: [{ id: 'wood_id', name: 'Wood log' }],
  detail: { id: 'r2', name: 'Planks', kind: 'Material / global', file: 'config/crafting/material_recipes_global.txt', line: 27, conditions: '', era_label: '0: Stone Age', era_basis: 'Research node', inputs: [{ id: '/material/wood', name: 'Log', quantity: '1', image: '' }], outputs: [{ id: '/obj/plank', name: 'Planks', quantity: '4', image: '' }], variants: [] } });

// Windows that had no preview before.
add('appearance', 'appearance_changer.tmpl', { change_gender: 1, genders: [{ gender_name: 'Male', gender_key: 'male' }, { gender_name: 'Female', gender_key: 'female' }], gender: 'female',
  change_hair: 1, hair_styles: ['Bald', 'Short', 'Ponytail', 'Braid', 'Bun', 'Long', 'Topknot', 'Curls'].map(hairstyle => ({ hairstyle })), hair_style: 'Braid',
  change_facial_hair: 1, facial_hair_styles: ['Shaved', 'Moustache', 'Goatee', 'Full beard'].map(facialhairstyle => ({ facialhairstyle })), facial_hair_style: 'Shaved',
  change_eye_color: 1, change_hair_color: 1, change_facial_hair_color: 1 });
add('vending-payment', 'vending_machine2.tmpl', { company: 'Dawnward Trading', moneyin: 2, currency_name: 'silver', currency_short: 'sp', mode: 1, product: 'Iron hatchet', price: 14, message: 'Please insert money to pay for the item.', message_err: 0 });
add('vending-plain', 'vending_machine.tmpl', { mode: 0, coin: 'silver coin', panel: 1, speaker: 1, products: [{ key: 1, name: 'Water flask', price: 0, amount: 6 }, { key: 2, name: 'Hardtack', price: 1, amount: 0 }] });
add('vending-gulag', 'vending_machine_gulag.tmpl', { moneyin: 30, currency_short: 'rub', mode: 0, products: [{ key: 1, name: 'Black bread', price: 10, amount: 12 }, { key: 2, name: 'Tea brick', price: 25, amount: 3 }] });
add('vending-market', 'vending_machine_taotd.tmpl', { moneyin: 5, currency_short: 'usd', mode: 0, products: [{ key: 1, name: 'Coffee', price: 2, amount: 20 }, { key: 2, name: 'Newspaper', price: 1, amount: 9 }] });
add('faction-symbol', 'faction_symbol.tmpl', { grid, color: '#f6d77f', tool: 'paint', has_saved_icon: 1, shapes: screens.find(screen => screen.name === 'faction')?.data.shapes });
add('research-book', 'research_book.tmpl', { name: 'Founding book', author: 'Mira', has_text: 1, held: 1, busy: 0,
  chapters: [
    { id: 'tools', name: 'Basic Toolmaking', state: 'known', era_name: 'Stone Age', discipline: 'Engineering', groundwork: [], study_minutes: 1, recipe_names: ['hatchet'] },
    { id: 'pottery', name: 'Pottery', state: 'study', era_name: 'Stone Age', discipline: 'Engineering', groundwork: [{ id: 'tools', name: 'Basic Toolmaking', known: 1 }], study_minutes: 1, tutor: 'Odo', recipe_names: ['clay pot', 'kiln'] },
    { id: 'bronze', name: 'Bronze Working', state: 'locked', era_name: 'Bronze Age', discipline: 'Natural Science', groundwork: [{ id: 'masonry', name: 'Stone Masonry', known: 0 }], study_minutes: 1.5, recipe_names: [] },
  ],
  unfinished: [{ id: 'masonry', name: 'Stone Masonry', percent: 30, ticks: 30, cost: 100, prototype: 'copper pickaxe', prototype_done: 0 }],
  writable: [{ id: 'fire', name: 'Firemaking', era_name: 'Stone Age', write_minutes: 2, stamina: 15 }],
  viewer: { pen: 'pencil', sheets: 3, stamina: 80, desk: 1, skills: [] } }, 'Book');
// Document windows keep their snapshot exactly as sent, so these are in the server's own shape.
const run = (text: string, bold = 0, italic = 0) => ({ text, bold, italic });
add('character-flavor', 'character_flavor.tmpl', { name: 'Mara Flint', text: 'A tall woman with soot on her sleeves.\nShe carries a smith&#39;s hammer at her belt.' }, 'Mara Flint');
add('character-notes', 'character_notes.tmpl', { character: [run('Mara Flint')],
  sections: [{ title: [run('Role')], entries: [{ runs: [run('Smith ', 1), run('of the Dawnward Guild', 1, 1), { br: 1 }, run('Keep the forge lit.')] }] }],
  memory: [run('Owes Tom Reed two iron ingots.')], discoveries: [{ br: 1 }, run('Discoveries', 1), { br: 1 }, run('No discoveries recorded.', 0, 1)] }, 'Notes');
add('photo', 'photo_viewer.tmpl', { name: 'Harbour at dawn', image: '', width: 192, scribble: 'The first ship of the season.' }, 'Photograph');
const ink = (text: string, extra: Data = {}) => ({ text, face: 'times', ink: '#000000', bold: false, italic: false, ...extra });
add('book', 'book_reader.tmpl', { runs: [ink('On the Working of Bronze', { bold: true }), ink('\n\nTin is scarce and copper is not. '), ink('Nine parts copper to one of tin', { italic: true }), ink(' makes a blade that holds its edge.')] }, 'Book');
add('paper', 'paper_editor.tmpl', { lease: 'a'.repeat(32), document_id: 'b'.repeat(32), revision: 1, free_space: 2900,
  languages: [{ id: 'civ13:english:v1', name: 'English' }], default_language_id: 'civ13:english:v1',
  view: { legacy_name: 'Paper', legacy_body_html: '', revision: 1, legacy_policy: 'legacy_unclassified',
    sections: [{ id: 'section-1', kind: 'body', language_id: 'civ13:english:v1', text: 'Delivered: forty oak planks and six iron ingots.', ink: '#000000', tool: 'pen' }] },
  draft_ink: 'black', draft_tool: 'pen', draft_signature: 'Mara Flint', response_serial: 1, result: 'saved' }, 'Paper');
// Character setup. Trait wording here is sample text for previews.
const trait = (name: string, cost: number, desc: string, extra: Data = {}) => ({ name, cost, desc, taken: 0, conflicts: [], ...extra });
const setup: CharacterSetupData = {
  character: {
    name: 'Maren Holt', name_max: 45, random_name: 0, random_body: 0, summary: 'Young adult, tan, female.', gender: 'female', age: 27, age_min: 18, age_max: 80,
    blood: 'O+', blood_types: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], skin_tone: 52,
    hair_style: 'Braid', hair_styles: ['Bald', 'Short Hair', 'Ponytail', 'Braid', 'Bun', 'Long Hair', 'Topknot', 'Curls', 'Bob', 'Crew Cut', 'Side Part', 'Undercut', 'Pigtails', 'Bedhead', 'Dreadlocks', 'Mohawk', 'Beehive', 'Parted'],
    facial_style: 'Shaved', facial_styles: ['Shaved'], hair_color: 'Brown', facial_color: 'Brown', eye_color: 'Green',
    hair_colors: [{ name: 'Black', hex: '#090806' }, { name: 'Light Brown', hex: '#6A4E42' }, { name: 'Brown', hex: '#4F3B2E' }, { name: 'Dark Brown', hex: '#3B3024' }, { name: 'Red', hex: '#B55239' }, { name: 'Blond', hex: '#E5C8A8' }, { name: 'Grey', hex: '#808080' }],
    eye_colors: [{ name: 'Black', hex: '#000000' }, { name: 'Brown', hex: '#542A0E' }, { name: 'Green', hex: '#4B7248' }, { name: 'Blue', hex: '#5EA4E7' }],
    previews: [{ label: 'Body' }, { label: 'Clothed' }],
  },
  traits: {
    spent: 5, earned: 3, chosen: ['Green Thumb', 'Agile', 'Light Eater', 'Deaf'], invalid: [], error: 'Your traits are not balanced. The sum must be 0 or less.',
    categories: [
      { id: 'playstyle', title: 'Playstyle', note: 'A way of playing. Each has its own strength and its own price.', pick_one: 1, traits: [
        trait('Green Thumb', 0, 'Playstyle. Farming trains faster and harvests yield a little more. Hunting and combat skills train slower.', { taken: 1 }),
        trait('Tinkerer', 0, 'Playstyle. Better crafting and faster engineering study. Less strength.', { conflicts: ['Green Thumb'] }),
        trait('Wanderer', 0, 'Playstyle. Stamina returns faster on the move. Your mood sinks when you stay in one place.', { conflicts: ['Green Thumb'] })] },
      { id: 'study', title: 'Field of study', note: 'The branch of learning you give yourself to.', pick_one: 1, traits: [
        trait('Naturalist', 0, 'Natural science comes quicker to you and other branches slower.', { note: 'A new field can be chosen 7 days after the last change.' }),
        trait('Physician', 0, 'Medicine comes quicker to you and other branches slower.', { block: 'You can choose again in 5 days.' })] },
      { id: 'body', title: 'Body and build', traits: [
        trait('Agile', 3, 'You move 15% faster.', { taken: 1 }), trait('Slowness', -2, 'You move 15% slower.', { conflicts: ['Agile'] }),
        trait('Tall', 1, 'More strength, less dexterity.'), trait('Short', -1, 'Less strength, better crafting.')] },
      { id: 'health', title: 'Health and diet', traits: [trait('Light Eater', 2, 'You need less food.', { taken: 1 }), trait('Glutton', -2, 'You need more food.', { conflicts: ['Light Eater'] }), trait('Hemophilia', -2, 'You bleed more.')] },
      { id: 'senses', title: 'Senses and speech', traits: [trait('Deaf', -3, 'You cannot hear at all.', { taken: 1 }), trait('Stutter', -1, 'You have a permanent stutter.')] },
    ],
  },
  settings: {
    ui_style: 'ConsoleStyle', ui_styles: ['ConsoleStyle', '1713Style', 'NewStyle'], cursor: 'Default', cursors: ['Default', 'Red Crosshair', 'Green Crosshair', 'White Crosshair'],
    client_fps: 60, fps_choices: [30, 60, 100, 120, 144], tutorial: 'in progress (3 of 9 steps done)',
    toggles: [{ key: 'SOUND_LOBBY', label: 'Lobby music', on: 1, on_label: 'Yes', off_label: 'No' }, { key: 'CHAT_OOC', label: 'OOC chat', on: 0, on_label: 'Show', off_label: 'Hide' }],
  },
};
add('character-setup', 'character_setup.tmpl', setup, 'Character Setup');
add('character-setup-traits', 'character_setup.tmpl', { ...setup, tab: 'traits' }, 'Character Setup');
add('character-setup-settings', 'character_setup.tmpl', { ...setup, tab: 'settings' }, 'Character Setup');
// Storage window: your things on the left, a basket, a chest and the floor on the right, one move running.
const stor = (id: string, name: string, size_class: number, extra: Data = {}) => ({ id, name, size_class, size: ['', 'tiny', 'small', 'normal', 'large', 'bulky'][size_class], cost: [0, 1, 2, 4, 8, 16][size_class], image: '', ...extra });
const storage: StorageWindowData = {
  hands_id: 'hands:a', hands: [{ side: 'left', active: 0, item: stor('i1', 'flint knife', 2) }, { side: 'right', active: 1 }],
  you: [
    { id: 'worn:b', kind: 'worn', name: 'leather backpack', used: 10, space: 16, slots: null, max_size: 3, can_dump: 1, can_take: 0, items: [stor('i2', 'rope', 3), stor('i3', 'dried meat', 2, { count: 3 }), stor('i4', 'waterskin', 2, { moving: 1 })] },
    { id: 'pockets:a', kind: 'pockets', name: 'pockets', can_dump: 1, unit: 'slots', items: [stor('i5', 'flint', 1)] },
  ],
  near: [
    { id: 'near:c', kind: 'near', name: 'woven basket', focus: 1, used: 6, space: 14, slots: 7, max_size: 3, can_dump: 1, can_take: 1, items: [stor('i6', 'wheat grain', 2, { count: 12 }), stor('i7', 'clay bowl', 2), stor('i8', 'berries', 1, { queued: 1 })] },
    { id: 'near:d', kind: 'near', name: 'hewn log chest', locked: 1, items: [] },
    { id: 'near:h', kind: 'near', name: 'wooden crate', used: 1, slots: 10, unit: 'things', can_dump: 1, can_take: 1, total: 1, items: [stor('i11', 'iron hatchet', 3)] },
    { id: 'body:f', kind: 'body', name: 'hide sling bag', owner: 'Body of Tomas Reed', used: 9, space: 16, slots: null, max_size: 3, can_dump: 0, can_take: 1, total: 5,
      items: [stor('i10', 'bone needle', 1)], search: { size_class: 2, time: 7, done: 3 }, unseen: [3, 1, 2] },
    { id: 'near:g', kind: 'near', name: 'clay storage jar', used: 4, space: 12, slots: 6, max_size: 2, can_dump: 0, can_take: 1, total: 2, items: [], unseen: [2, 2] },
    { id: 'floor:e', kind: 'floor', name: 'Floor', can_take: 1, items: [stor('i9', 'wood log', 4, { count: 2 })] },
  ],
  queue: [{ name: 'waterskin', image: '', to: 'your hands', time: 4, done: 2 }, { name: 'berries', image: '', to: 'leather backpack', time: 5, done: 0 }],
};
add('storage-window', 'storage_window.tmpl', storage, 'Storage');
add('spawn-menu', 'spawn_menu.tmpl', { query: 'rifle', kind: 'obj', matches: 212, limit: 150, types: 41873, max_amount: 50, last: '/obj/item/weapon/gun/projectile/boltaction/mosin', results: [
  { path: '/obj/item/weapon/gun/projectile/boltaction/mosin', name: 'Mosin-Nagant', kind: 'obj' },
  { path: '/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry', name: 'Martini-Henry rifle', kind: 'obj' },
  { path: '/obj/item/weapon/gun/projectile/semiautomatic/svt', name: 'SVT-40', kind: 'obj' },
  { path: '/obj/structure/closet/crate/rifles', name: 'rifle crate', kind: 'obj' },
] }, 'Spawn');
// A compact remote's circuit: each press rolls a die, multiplies or adds a bonus, reports who
// pressed it and finds a marked key. The texts and colours are the ones the game sends.
const port = (name: string, type: string, ref: string, extra: Data = {}) =>
  ({ name, type, color: ({ any: 'blue', number: 'green', string: 'orange', signal: 'teal', boolean: 'bad', list: 'white', option: 'violet', entity: 'purple' } as Record<string, string>)[type], ref, ...extra });
const circuitPart = (id: number, type: string, name: string, category: string, x: number, y: number, description: string, input_ports: Data[], output_ports: Data[], extra: Data = {}) =>
  ({ id, type: `/obj/item/circuit_component/${type}`, name, description, category, x, y, removable: 1, input_ports, output_ports, ...extra });
const operations = ['Add', 'Subtract', 'Multiply', 'Divide', 'Modulo', 'Power', 'Minimum', 'Maximum'];
const circuitParts = [
  circuitPart(1, 'compact_remote', 'Compact Remote', 'General', 20, 40, "The remote's button. Each press sends a signal on Signal, and User becomes the person who pressed it. Wire User into a text input to get their name.",
    [], [port('User', 'entity', 'output-1-1'), port('Signal', 'signal', 'output-1-2')], { removable: 0 }),
  circuitPart(2, 'random', 'Random', 'Math', 230, 40, 'Each signal on Trigger picks a whole number from Minimum to Maximum, both included. Nothing happens if Minimum is above Maximum or either is not set. The bounds are limited to 1,000,000 either side of zero.', [
    port('Minimum', 'number', 'input-2-1', { connected_to: [], current_data: 1 }), port('Maximum', 'number', 'input-2-2', { connected_to: [], current_data: 6 }),
    port('Trigger', 'signal', 'input-2-3', { connected_to: ['output-1-2'], current_data: null })], [port('Result', 'number', 'output-2-1')]),
  circuitPart(3, 'operator/arithmetic', 'Arithmetic', 'Math', 40, 290, 'Works out a number from A and B with the chosen Operation: add, subtract, multiply, divide, modulo (the remainder), power, minimum or maximum. It waits until both A and B are set. Dividing by zero, or a power with no real answer, leaves Result empty.', [
    port('A', 'number', 'input-3-1', { connected_to: ['output-2-1'], current_data: 4 }), port('B', 'number', 'input-3-2', { connected_to: [], current_data: 2 }),
    port('Operation', 'option', 'input-3-3', { connected_to: [], current_data: 'Add', datatype_data: operations })], [port('Result', 'number', 'output-3-1')]),
  circuitPart(4, 'operator/string_concat', 'String Concat', 'String', 490, 40, 'Joins text A and text B end to end. An input that is not set counts as empty text, and a number is joined as its digits. The result is cut at 5,000 characters.', [
    port('A', 'string', 'input-4-1', { connected_to: ['output-1-1'], current_data: 'Mara Voss' }), port('B', 'string', 'input-4-2', { connected_to: [], current_data: ' rolled ' })],
    [port('Result', 'string', 'output-4-1')]),
  circuitPart(5, 'variable/setter', 'Setter: last roll', 'Utility', 440, 250, 'Stores its Input in its variable whenever Input changes. Every getter of that variable then gives the new value.', [port('Input', 'number', 'input-5-1', { connected_to: ['output-3-1'], current_data: 6 })], []),
  circuitPart(6, 'direction', 'Direction', 'Entity', 400, 400, 'Finds Target from where the circuit is: the compass direction to it and the distance in tiles. It looks when Target changes and at every signal on Trigger. A target more than 7 tiles away, on another level or gone leaves both outputs empty. On the same tile Distance is 0 and Direction is empty.', [
    port('Target', 'entity', 'input-6-1', { connected_to: [], current_data: null }), port('Trigger', 'signal', 'input-6-2', { connected_to: [], current_data: null })],
    [port('Direction', 'string', 'output-6-1'), port('Distance', 'number', 'output-6-2')]),
];
add('circuit-editor', 'wiremod_circuit.tmpl', {
  on: 1, display_name: 'Dice roller', grid_mode: 1, screen_x: 0, screen_y: 0, is_admin: 0, components: circuitParts,
  component_catalog: [circuitParts[2], circuitParts[1], circuitParts[3], circuitParts[5]].map(part => ({ id: 0, type: part.type, name: part.name, description: part.description, category: part.category, x: 0, y: 0, removable: 1, input_ports: part.input_ports.map(p => ({ ...p, ref: '', connected_to: [] })), output_ports: part.output_ports.map(p => ({ ...p, ref: '' })) })),
  global_basic_types: ['number', 'boolean', 'string', 'any', 'entity'], variables: [{ name: 'last roll', datatype: 'number', color: 'green', is_list: 0 }],
  examined_name: null, examined_desc: null, examined_notices: [], examined_rel_x: 0, examined_rel_y: 0,
}, 'integrated circuit');
