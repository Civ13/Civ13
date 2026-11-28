// The snapshot each window receives from the server. Every field is optional:
// a screen must cope with a missing one rather than trust the server's shape.
// A window's sample data in src/fixtures.mts is checked against these types.
export type Flag = boolean | number;

export type WarehouseData = { items?: { name?: string; amount?: number }[] };
export type ChemistryData = {
  amount?: number; glass?: Flag; isBeakerLoaded?: Flag; beakerCurrentVolume?: number | null; beakerMaxVolume?: number | null;
  chemicals?: { id?: string; title?: string }[]; beakerContents?: { name?: string; volume?: number }[];
};
export type AppearanceData = {
  change_race?: Flag; change_gender?: Flag; change_hair?: Flag; change_facial_hair?: Flag;
  change_eye_color?: Flag; change_skin_tone?: Flag; change_skin_color?: Flag; change_hair_color?: Flag; change_facial_hair_color?: Flag;
  species?: { specimen?: string }[]; specimen?: string;
  genders?: { gender_name?: string; gender_key?: string }[]; gender?: string;
  hair_styles?: { hairstyle?: string }[]; hair_style?: string;
  facial_hair_styles?: { facialhairstyle?: string }[]; facial_hair_style?: string;
};
export type VendingProduct = { key?: number; name?: string; price?: number; amount?: number; color?: string | null };
export type VendingData = {
  mode?: number; modern?: Flag; company?: string; products?: VendingProduct[];
  moneyin?: number; currency_name?: string; currency_short?: string; coin?: string | null;
  product?: string; price?: number; message?: string; message_err?: Flag; panel?: Flag; speaker?: Flag;
};
export type CrewLogData = { crew?: { name?: string; job?: string }[] };
export type ShipStocksData = { stocks?: { label?: string; amount?: number; unit?: string }[] };
export type ReligionListData = { religions?: { name?: string; points?: number }[] };
// The generic panel: sections of notes, labelled rows, item lists and buttons.
// A button sends its action with id as the value.
export type PanelButton = { label?: string; action?: string; id?: string | number; disabled?: Flag; selected?: Flag };
export type PanelSection = {
  title?: string; notes?: string[]; empty?: string; buttons?: PanelButton[];
  rows?: { label?: string; value?: string | number; tone?: string; buttons?: PanelButton[] }[];
  items?: { name?: string; detail?: string; image?: string; buttons?: PanelButton[] }[];
  table?: { columns?: string[]; rows?: PanelCell[][] };
  forms?: PanelForm[];
  chart?: { series?: { label?: string; tone?: string; points?: number[] }[]; slots?: number; top?: string; left?: string; right?: string };
};
export type PanelForm = { label?: string; action?: string; id?: string | number; button?: string;
  fields?: { name?: string; label?: string; value?: string | number; kind?: string; options?: { id?: string | number; label?: string }[] }[] };
export type PanelCell = string | number | { text?: string; tone?: string };
export type PanelData = { notes?: string[]; sections?: PanelSection[] };
export type PromptData = { message?: string; choices?: string[] };
// Admin Spawn picker: the server searches its cached type list; results are the best matches.
export type SpawnMenuEntry = { path?: string; name?: string; kind?: string };
export type SpawnMenuData = { query?: string; kind?: string; results?: SpawnMenuEntry[]; matches?: number; limit?: number; types?: number; max_amount?: number; last?: string };
// A family is a root language and the daughters that grew out of it on this world; links say how much two members follow of each other.
export type LanguageFamilyMember = { name?: string; parent?: string; nation?: string; era?: string; depth?: number; known?: Flag; learning?: Flag; mother?: Flag };
export type LanguageFamily = { root?: string; members?: LanguageFamilyMember[]; links?: { a?: string; b?: string; percent?: number }[] };
export type KnownLanguagesData = { current_default?: string; languages?: { name?: string; prefix?: string; description?: string; is_default?: Flag }[]; families?: LanguageFamily[]; people?: PeopleFamily | null };
// The viewer's own people: where it came from (lineage, root first, ending with their own people), the peoples related to it,
// and the peoples they were raised among or welcomed by. formed is 0 for an old people; year is the calendar year or 0.
export type PeopleRow = { name?: string; language?: string; formed?: Flag; year?: number; nation?: string; homeland?: string; parents?: string[]; relation?: string };
export type PeopleFamily = { name?: string; language?: string; land?: string; lineage?: PeopleRow[]; kin?: PeopleRow[]; raised_among?: string[]; welcomed_by?: string[] };
// Character setup: appearance, traits and personal settings.
export type SetupTrait = { name?: string; cost?: number; desc?: string; note?: string; block?: string; taken?: Flag; conflicts?: string[] };
export type SetupColor = { name?: string; hex?: string };
export type CharacterSetupData = {
  // tab: the tab a newly opened window starts on (character, traits or settings).
  tab?: string; locked?: Flag; notice?: string | null;
  character?: {
    name?: string; name_max?: number; random_name?: Flag; random_body?: Flag; summary?: string; gender?: string;
    age?: number; age_min?: number; age_max?: number; blood?: string; blood_types?: string[]; skin_tone?: number;
    hair_style?: string; hair_styles?: string[]; facial_style?: string; facial_styles?: string[];
    hair_color?: string; facial_color?: string; hair_colors?: SetupColor[]; eye_color?: string; eye_colors?: SetupColor[];
    previews?: { label?: string; front?: string; east?: string; back?: string; west?: string }[];
  };
  traits?: {
    spent?: number; earned?: number; chosen?: string[]; invalid?: string[]; error?: string | null;
    categories?: { id?: string; title?: string; note?: string; pick_one?: Flag; traits?: SetupTrait[] }[];
  };
  // chart: the birth sign. choice is "random" or a sign id; current is the living character's own sign.
  chart?: {
    choice?: string; verified?: Flag; current?: string;
    signs?: { id?: string; name?: string; season?: string; calling?: string; strengths?: string; weaknesses?: string; image?: string }[];
  };
  settings?: {
    ui_style?: string; ui_styles?: string[]; cursor?: string; cursors?: string[]; client_fps?: number; fps_choices?: number[]; tutorial?: string;
    tap_step?: Flag; hover_text?: number; hover_text_scale?: string; hud_scale?: string; scales?: string[]; hud_editing?: Flag;
    toggles?: { key?: string; label?: string; on?: Flag; on_label?: string; off_label?: string }[];
  };
};
// Haircut: eligible styles as rows of the shared style sheet, and the figure they are drawn on.
export type HaircutStyle = { name?: string; length?: number; row?: number; tint?: Flag };
export type HairZone = [number, number, number, number, number];
export type HairDesign = [string, string, string];
export type HaircutData = {
  sheet?: string; body?: string; self?: Flag; name?: string; hair?: string; beard?: string; hair_color?: string; beard_color?: string;
  hair_styles?: HaircutStyle[]; beard_styles?: HaircutStyle[]; seconds?: number;
  design_styles?: HaircutStyle[]; design?: HairDesign; design_regions?: HairZone[][];
  patterns?: { name: string; design: HairDesign }[];
};
// The storage window: hands, worn bags and pockets, storages nearby, the queue of moves.
export type StorageItem = { id?: string; name?: string; size?: string; size_class?: number; cost?: number; image?: string; count?: number; queued?: Flag; moving?: Flag };
export type StorageGroup = {
  id?: string; kind?: string; name?: string; image?: string; focus?: number; locked?: Flag; owner?: string; items?: StorageItem[];
  used?: number; space?: number; slots?: number | null; max_size?: number; can_dump?: Flag; can_take?: Flag; unit?: string;
  // Searching: size classes of things not seen yet, the one being looked at, and how many it holds.
  unseen?: number[]; search?: { size_class?: number; time?: number; done?: number } | null; total?: number;
};
export type StorageWindowData = {
  hands_id?: string; hands?: { side?: string; active?: Flag; item?: StorageItem }[]; you?: StorageGroup[]; near?: StorageGroup[];
  queue?: { name?: string; image?: string; to?: string; time?: number; done?: number }[]; more_images?: Flag; move_limit?: number;
};
// The modular computer. shell picks the look ("cli" today; "desktop" and "mobile" later) and every shell reads this one snapshot.
// index fields are the values the server expects back; files is present while the Files program is the active one.
export type ComputerModule = { index?: number; slot?: string; slot_label?: string; name?: string; detail?: string; icon?: string };
export type ComputerProgram = { id?: string; name?: string; desc?: string; available?: Flag; reason?: string };
export type ComputerFile = { index?: number; name?: string; size_kb?: number };
export type ComputerStore = { name?: string; used_kb?: number; capacity_kb?: number };
export type ComputerFiles = {
  drive?: ComputerStore | null; list?: ComputerFile[]; open?: { index?: number; name?: string; body?: string } | null;
  disk?: (ComputerStore & { list?: ComputerFile[] }) | null; printer?: { paper?: number } | null; max_chars?: number; max_name?: number;
};
export type ComputerData = {
  name?: string; shell?: string; os_name?: string; os_version?: string; boot_lines?: string[]; powered?: Flag; case_open?: Flag; status?: string;
  // tab: optional; the tab a newly opened window starts on (terminal or hardware).
  tab?: string;
  hardware?: ComputerModule[]; empty_slots?: { slot?: string; slot_label?: string }[];
  programs?: ComputerProgram[]; active?: string; files?: ComputerFiles | null;
};
