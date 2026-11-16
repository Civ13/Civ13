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
  chart?: { series?: { label?: string; tone?: string; points?: number[] }[]; slots?: number; top?: string; left?: string; right?: string };
};
export type PanelCell = string | number | { text?: string; tone?: string };
export type PanelData = { notes?: string[]; sections?: PanelSection[] };
export type PromptData = { message?: string; choices?: string[] };
export type KnownLanguagesData = { current_default?: string; languages?: { name?: string; prefix?: string; description?: string; is_default?: Flag }[] };
