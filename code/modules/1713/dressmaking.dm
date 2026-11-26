// Tailoring: players design their own clothes, hats, gloves, footwear and
// belts. A paid tailoring project holds fabric or leather; its owner picks a
// garment body, colours the body and each of its pattern pieces, cuts the
// material (which locks the design) and sews one garment.
//
// A design is plain data: a body id, a "|"-separated list of colours (the
// body first, then each panel and each piece option in catalogue order) and,
// for bodies drawn as mix-and-match pieces, a "|"-separated list of the
// chosen variant of every piece option. The loose item, the worn
// sprite and the live preview are all built from the same coloured image
// overlays. BYOND shares one appearance per icon, state and colour, so no
// /icon is blended at runtime and nothing is added to the resource cache.

#define TAILORING_MAX_FABRIC 8
#define TAILORING_MAX_COLOURS 6
#define TAILORING_BOOK_MAX 20
#define TAILORING_BOOK_FIELDS list("body", "colors", "pieces", "name", "maker", "author")

var/global/list/tailoring_catalogue = null

// Body id -> list(name, slot, base, item_base?, panels (label -> state, in
// draw order), fixed (uncoloured states drawn last), node, cost, covers?,
// fabrics? (the materials it can be made of; woven cloth when unset),
// garment? (the item it is sewn into; the slot's tailored garment when unset)).
// Every state is existing greyscale art in the slot's worn and item icons.
/proc/tailoring_bodies()
	if (tailoring_catalogue)
		return tailoring_catalogue
	var/list/C = list()
	// Clothing (uniform slot).
	C["loincloth"] = list("name" = "loincloth", "slot" = "under", "base" = "customspartan", "panels" = list(), "node" = "weaving", "cost" = 1, "covers" = LOWER_TORSO)
	C["long_tunic"] = list("name" = "long tunic", "slot" = "under", "base" = "customroman", "panels" = list(), "node" = "weaving", "cost" = 4)
	C["tribal_robe"] = list("name" = "tribal robe", "slot" = "under", "base" = "tribalrobe_robe", "item_base" = "tribalrobe", "panels" = list("Robe" = "tribalrobe_robe", "Decoration" = "tribalrobe_decoration"), "fixed" = list("tribalrobe_robebelt"), "node" = "weaving", "cost" = 3)
	C["shendyt"] = list("name" = "shendyt", "slot" = "under", "base" = "customshendyt", "panels" = list(), "node" = "classical_dress", "cost" = 2, "covers" = LOWER_TORSO)
	C["celtic_trousers"] = list("name" = "celtic trousers", "slot" = "under", "base" = "customceltic", "panels" = list(), "node" = "classical_dress", "cost" = 2, "covers" = LOWER_TORSO|LEGS)
	C["toga"] = list("name" = "toga", "slot" = "under", "base" = "customtoga", "panels" = list(), "node" = "classical_dress", "cost" = 3)
	C["stola"] = list("name" = "stola", "slot" = "under", "base" = "fem_roman", "panels" = list(), "node" = "classical_dress", "cost" = 4)
	C["arabic_tunic"] = list("name" = "arabic tunic", "slot" = "under", "base" = "customarabictunic", "panels" = list(), "node" = "tailoring", "cost" = 4)
	C["haori"] = list("name" = "haori", "slot" = "under", "base" = "haori_custom", "panels" = list(), "node" = "tailoring", "cost" = 3)
	C["renaissance"] = list("name" = "renaissance outfit", "slot" = "under", "base" = "customren", "panels" = list("Top" = "customren_top", "Lining" = "customren_lining"), "node" = "tailoring", "cost" = 6)
	C["short_colonial"] = list("name" = "short colonial outfit", "slot" = "under", "base" = "custom_col_short_full", "panels" = list("Shirt" = "custom_col_short_shirt", "Trousers" = "custom_col_short_pants"), "fixed" = list("custom_belt"), "node" = "tailoring", "cost" = 4)
	C["tunic"] = list("name" = "tunic", "slot" = "under", "base" = "customtunic", "panels" = list(), "node" = "fine_garments", "cost" = 4)
	C["layered_dress"] = list("name" = "layered dress", "slot" = "under", "base" = "customdress", "panels" = list("Sleeves" = "customdress_top", "Skirt" = "customdress_under", "Bodice" = "customdress_over"), "node" = "fine_garments", "cost" = 4)
	C["buttoned_dress"] = list("name" = "buttoned dress", "slot" = "under", "base" = "custombuttonup_full", "panels" = list("Sleeves and skirt" = "custombuttonup_bottom", "Bodice and stripes" = "custombuttonup_lines"), "node" = "fine_garments", "cost" = 4)
	C["laced_dress"] = list("name" = "laced dress", "slot" = "under", "base" = "crinoline_dress", "panels" = list("Dress" = "crinoline_dress_dress", "Underskirt" = "crinoline_dress_under"), "fixed" = list("crinoline_dress_lining"), "node" = "fine_garments", "cost" = 4)
	C["pontifical"] = list("name" = "pontifical robes", "slot" = "under", "base" = "custom_pontifical", "panels" = list("Leggings" = "custompont_leggings", "Decoration" = "custompont_decore", "Cuffs" = "custompont_handdecore", "Lines" = "custompont_mclines"), "node" = "fine_garments", "cost" = 6)
	C["pyjamas"] = list("name" = "pyjamas", "slot" = "under", "base" = "custompyjamas", "panels" = list("Cloth" = "custompyjamas_base", "Stripes" = "custompyjamas_stripes"), "node" = "fine_garments", "cost" = 3)
	C["colonial"] = list("name" = "colonial outfit", "slot" = "under", "base" = "custom_col_full", "panels" = list("Shirt" = "custom_col_shirt", "Trousers" = "custom_col_pants"), "fixed" = list("custom_belt"), "node" = "fine_garments", "cost" = 4)
	C["victorian_uniform"] = list("name" = "victorian uniform", "slot" = "under", "base" = "customuni", "panels" = list("Shirt" = "customuni_shirt", "Buttons" = "customuni_buttons", "Belt" = "customuni_belt", "Buckle" = "customuni_buckle", "Trousers" = "customuni_pants"), "node" = "textile_mills", "cost" = 3)
	C["modern"] = list("name" = "modern outfit", "slot" = "under", "base" = "custom_mod_full", "panels" = list("Shirt" = "custom_mod_shirt", "Trousers" = "custom_mod_pants"), "fixed" = list("custom_belt"), "node" = "ready_made", "cost" = 4)
	C["modern_baggy"] = list("name" = "baggy modern outfit", "slot" = "under", "base" = "custom_modbaggy_full", "panels" = list("Shirt" = "custom_modbaggy_shirt", "Trousers" = "custom_modbaggy_pants"), "fixed" = list("custom_belt"), "node" = "ready_made", "cost" = 4)
	C["modern_short"] = list("name" = "short modern outfit", "slot" = "under", "base" = "custom_modshort_full", "panels" = list("Shirt" = "custom_modshort_shirt", "Trousers" = "custom_modshort_pants"), "fixed" = list("custom_belt"), "node" = "ready_made", "cost" = 4)
	// Overclothes (suit slot).
	C["poncho"] = list("name" = "poncho", "slot" = "suit", "base" = "customponcho", "panels" = list(), "node" = "tailoring", "cost" = 2)
	C["haori_jacket"] = list("name" = "haori jacket", "slot" = "suit", "base" = "haori_jacket_custom", "panels" = list(), "node" = "tailoring", "cost" = 4)
	C["colonial_jacket"] = list("name" = "colonial jacket", "slot" = "suit", "base" = "customcolonial_full", "panels" = list("Jacket" = "customcolonial_jacket", "Bandolier" = "customcolonial_cross"), "fixed" = list("customcolonial_plain"), "node" = "tailoring", "cost" = 5)
	C["colonial_coat"] = list("name" = "colonial coat", "slot" = "suit", "base" = "customcolonialcoat_full", "panels" = list("Coat" = "customcolonialcoat_top", "Decorations" = "customcolonialcoat_dec", "Lines" = "customcolonialcoat_lines"), "node" = "tailoring", "cost" = 7)
	C["cloth_jacket"] = list("name" = "cloth jacket", "slot" = "suit", "base" = "customjacket", "panels" = list(), "node" = "ready_made", "cost" = 4)
	C["blazer"] = list("name" = "blazer", "slot" = "suit", "base" = "customblazer", "panels" = list(), "node" = "ready_made", "cost" = 4)
	C["hoodie"] = list("name" = "hoodie", "slot" = "suit", "base" = "customhoodie", "panels" = list(), "node" = "ready_made", "cost" = 3)
	C["tracksuit"] = list("name" = "tracksuit jacket", "slot" = "suit", "base" = "customtracksuit", "panels" = list("Jacket" = "customtracksuit_base", "Stripes" = "customtracksuit_lines"), "node" = "synthetics", "cost" = 3)
	// Headwear (head slot). "hides_hair" bodies cover the hair like a veil.
	C["hood"] = list("name" = "hood", "slot" = "head", "base" = "wool_hood", "panels" = list(), "node" = "weaving", "cost" = 1)
	C["bandana"] = list("name" = "bandana", "slot" = "head", "base" = "custombandana_hat", "panels" = list(), "node" = "weaving", "cost" = 1)
	C["beanie"] = list("name" = "beanie", "slot" = "head", "base" = "custom_beanie", "panels" = list(), "node" = "weaving", "cost" = 1)
	C["taqiyah"] = list("name" = "skullcap", "slot" = "head", "base" = "taqiyah", "panels" = list(), "node" = "classical_dress", "cost" = 1)
	C["hijab"] = list("name" = "veil", "slot" = "head", "base" = "hijab", "panels" = list(), "node" = "classical_dress", "cost" = 2, "hides_hair" = TRUE)
	C["keffiyeh"] = list("name" = "keffiyeh", "slot" = "head", "base" = "keffiyeh_custom", "panels" = list("Checks" = "keffiyeh_custom_color"), "node" = "classical_dress", "cost" = 2)
	C["beret"] = list("name" = "beret", "slot" = "head", "base" = "customberet_hat", "panels" = list(), "node" = "tailoring", "cost" = 1)
	C["feathered_cap"] = list("name" = "feathered cap", "slot" = "head", "base" = "custfeathercap_b_hat", "panels" = list("Feather" = "custfeathercap_f_hat"), "node" = "tailoring", "cost" = 1)
	C["hennin"] = list("name" = "hennin", "slot" = "head", "base" = "custom_hennin_point", "panels" = list(), "fixed" = list("custom_hennin_lining"), "node" = "tailoring", "cost" = 2)
	C["noble_hat"] = list("name" = "noble hat", "slot" = "head", "base" = "customnoblehat_hat", "panels" = list(), "node" = "fine_garments", "cost" = 2)
	C["shako"] = list("name" = "infantry cap", "slot" = "head", "base" = "custom_nap_lea_infantry_cap_f", "panels" = list(), "fixed" = list("custom_nap_lea_infantry_cap_b"), "node" = "fine_garments", "cost" = 2)
	C["peaked_cap"] = list("name" = "peaked cap", "slot" = "head", "base" = "customcap", "panels" = list("Band" = "customcap_l2", "Badge" = "customcap_l3"), "node" = "textile_mills", "cost" = 1)
	C["field_cap"] = list("name" = "field cap", "slot" = "head", "base" = "fieldcap_custom", "panels" = list(), "node" = "ready_made", "cost" = 1)
	// Mix-and-match bodies, drawn on one shared template so every sleeve,
	// neckline and belt fits every body of its layer. Options draw in the
	// order listed (patterns right on the cloth, closures over trim). Each
	// lists its variants in menu order; the first is the default and null
	// draws nothing.
	var/list/sleeves = list("Short" = "tl_sleeve_short", "Long" = "tl_sleeve_long", "None" = null)
	var/list/necks = list("Plain" = null, "Round collar" = "tl_neck_round", "V neck" = "tl_neck_v", "High collar" = "tl_neck_high")
	var/list/waist = list("None" = null, "Belt" = "tl_belt", "Sash" = "tl_sash")
	C["made_shirt"] = list("name" = "shirt", "slot" = "under", "art" = "tailoring", "base" = "tl_shirt", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_shirt_stripes", "Checks" = "tl_shirt_checks", "Hem band" = "tl_shirt_hem"), "Sleeves" = sleeves.Copy(), "Neckline" = necks.Copy(), "Legwear" = list("Trousers" = "tl_legs_trousers", "Shorts" = "tl_legs_shorts", "Breeches" = "tl_legs_breeches", "Skirt" = "tl_legs_skirt"), "Waist" = waist.Copy()), "node" = "weaving", "cost" = 2, "covers" = UPPER_TORSO)
	C["made_tunic"] = list("name" = "knee tunic", "slot" = "under", "art" = "tailoring", "base" = "tl_tunic", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_tunic_stripes", "Checks" = "tl_tunic_checks", "Hem band" = "tl_tunic_hem"), "Sleeves" = sleeves.Copy(), "Neckline" = necks.Copy(), "Waist" = waist.Copy()), "node" = "weaving", "cost" = 3, "covers" = UPPER_TORSO|LOWER_TORSO)
	C["made_gown"] = list("name" = "gown", "slot" = "under", "art" = "tailoring", "base" = "tl_gown", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_gown_stripes", "Checks" = "tl_gown_checks", "Hem band" = "tl_gown_hem"), "Sleeves" = sleeves.Copy(), "Neckline" = necks.Copy(), "Waist" = waist.Copy()), "node" = "classical_dress", "cost" = 4, "covers" = UPPER_TORSO|LOWER_TORSO|LEGS)
	var/list/coat_sleeves = list("Long" = "tl_coat_sleeve_long", "Cuffed" = "tl_coat_sleeve_cuffed", "None" = null)
	var/list/collars = list("None" = null, "Stand collar" = "tl_collar_stand", "Lapels" = "tl_collar_lapels", "Fur collar" = "tl_collar_fur")
	var/list/closures = list("None" = null, "Buttons" = "tl_buttons_single", "Double buttons" = "tl_buttons_double", "Toggles" = "tl_toggles")
	C["made_jacket"] = list("name" = "jacket", "slot" = "suit", "art" = "tailoring", "base" = "tl_jacket", "panels" = list(), "options" = list("Sleeves" = coat_sleeves.Copy(), "Collar" = collars.Copy(), "Trim" = list("None" = null, "Edge trim" = "tl_jacket_trim"), "Closure" = closures.Copy()), "node" = "tailoring", "cost" = 3, "covers" = UPPER_TORSO)
	C["made_coat"] = list("name" = "coat", "slot" = "suit", "art" = "tailoring", "base" = "tl_coat", "panels" = list(), "options" = list("Sleeves" = coat_sleeves.Copy(), "Collar" = collars.Copy(), "Trim" = list("None" = null, "Edge trim" = "tl_coat_trim"), "Closure" = closures.Copy()), "node" = "tailoring", "cost" = 5, "covers" = UPPER_TORSO|LOWER_TORSO)
	C["made_cloak"] = list("name" = "cloak", "slot" = "suit", "art" = "tailoring", "base" = "tl_cloak", "panels" = list(), "options" = list("Hood" = list("None" = null, "Hood" = "tl_cloak_hood"), "Clasp" = list("None" = null, "Clasp" = "tl_cloak_clasp"), "Border" = list("None" = null, "Border" = "tl_cloak_border")), "node" = "weaving", "cost" = 3, "covers" = UPPER_TORSO|LOWER_TORSO|ARMS)
	// Mix-and-match hats. Every crown ends on the same two rows above the
	// eyes, so one band, brim, pair of flaps or decoration fits every crown.
	var/list/hat_bands = list("None" = null, "Band" = "tl_hat_band", "Fur trim" = "tl_hat_band_fur")
	var/list/hat_brims = list("None" = null, "Narrow brim" = "tl_hat_brim_narrow", "Wide brim" = "tl_hat_brim_wide", "Peak" = "tl_hat_peak", "Cocked brim" = "tl_hat_brim_cocked")
	var/list/hat_flaps = list("None" = null, "Ear flaps" = "tl_hat_flaps", "Neck cloth" = "tl_hat_neck_cloth")
	var/list/hat_decorations = list("None" = null, "Feather" = "tl_hat_feather", "Plume" = "tl_hat_plume", "Badge" = "tl_hat_badge", "Ribbons" = "tl_hat_ribbons")
	C["made_round_hat"] = list("name" = "round hat", "slot" = "head", "art" = "tailoring", "base" = "tl_hat_round", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_hat_round_stripes", "Panels" = "tl_hat_round_panels"), "Band" = hat_bands.Copy(), "Brim" = hat_brims.Copy(), "Flaps" = hat_flaps.Copy(), "Decoration" = hat_decorations.Copy()), "node" = "weaving", "cost" = 1)
	C["made_pointed_hat"] = list("name" = "pointed hat", "slot" = "head", "art" = "tailoring", "base" = "tl_hat_pointed", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_hat_pointed_stripes", "Panels" = "tl_hat_pointed_panels"), "Band" = hat_bands.Copy(), "Brim" = hat_brims.Copy(), "Flaps" = hat_flaps.Copy(), "Decoration" = hat_decorations.Copy()), "node" = "weaving", "cost" = 1)
	C["made_soft_hat"] = list("name" = "soft hat", "slot" = "head", "art" = "tailoring", "base" = "tl_hat_soft", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_hat_soft_stripes", "Panels" = "tl_hat_soft_panels"), "Band" = hat_bands.Copy(), "Brim" = hat_brims.Copy(), "Flaps" = hat_flaps.Copy(), "Decoration" = hat_decorations.Copy()), "node" = "tailoring", "cost" = 1)
	C["made_tall_hat"] = list("name" = "tall hat", "slot" = "head", "art" = "tailoring", "base" = "tl_hat_tall", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Stripes" = "tl_hat_tall_stripes", "Panels" = "tl_hat_tall_panels"), "Band" = hat_bands.Copy(), "Brim" = hat_brims.Copy(), "Flaps" = hat_flaps.Copy(), "Decoration" = hat_decorations.Copy()), "node" = "fine_garments", "cost" = 2)
	// Gloves, footwear and belts. They are looks only: each is sewn into an
	// item that protects and carries exactly like the plain one of its kind.
	var/list/glove_fabrics = list("leather", "woolcloth")
	var/list/glove_backs = list("Plain" = null, "Padded" = "tl_glove_knuckles", "Striped" = "tl_glove_stripe")
	var/list/glove_tips = list("Plain" = null, "Capped" = "tl_glove_tips")
	C["made_gloves"] = list("name" = "gloves", "slot" = "gloves", "art" = "tailoring", "base" = "tl_gloves", "panels" = list(), "options" = list("Cuff" = list("None" = null, "Turned" = "tl_glove_cuff", "Gauntlet" = "tl_glove_gauntlet", "Fur" = "tl_glove_cuff_fur"), "Back" = glove_backs.Copy(), "Fingertips" = glove_tips.Copy()), "node" = "weaving", "cost" = 2, "fabrics" = glove_fabrics.Copy())
	C["made_long_gloves"] = list("name" = "long gloves", "slot" = "gloves", "art" = "tailoring", "base" = "tl_gloves_long", "panels" = list(), "options" = list("Top" = list("Plain" = null, "Banded" = "tl_glove_long_band", "Fur" = "tl_glove_long_fur"), "Back" = glove_backs.Copy(), "Fingertips" = glove_tips.Copy()), "node" = "tailoring", "cost" = 3, "fabrics" = glove_fabrics.Copy())
	var/list/soles = list("Plain" = null, "Thick" = "tl_boot_sole")
	var/list/toes = list("Plain" = null, "Capped" = "tl_boot_toecap")
	C["made_shoes"] = list("name" = "shoes", "slot" = "shoes", "art" = "tailoring", "base" = "tl_shoes", "panels" = list(), "options" = list("Sole" = soles.Copy(), "Toe" = toes.Copy(), "Fastening" = list("None" = null, "Laced" = "tl_shoes_laces", "Buckled" = "tl_boot_buckle", "Strapped" = "tl_boot_strap")), "node" = "classical_dress", "cost" = 1, "fabrics" = list("leather"))
	C["made_boots"] = list("name" = "boots", "slot" = "shoes", "art" = "tailoring", "base" = "tl_boots", "panels" = list(), "options" = list("Sole" = soles.Copy(), "Toe" = toes.Copy(), "Fastening" = list("None" = null, "Laced" = "tl_boots_laces", "Buckled" = "tl_boot_buckle", "Strapped" = "tl_boot_strap"), "Cuff" = list("None" = null, "Turned" = "tl_boots_cuff", "Fur" = "tl_boots_fur")), "node" = "fine_garments", "cost" = 2, "fabrics" = list("leather"), "garment" = /obj/item/clothing/shoes/leatherboots/tailored)
	C["made_tall_boots"] = list("name" = "tall boots", "slot" = "shoes", "art" = "tailoring", "base" = "tl_boots_tall", "panels" = list(), "options" = list("Sole" = soles.Copy(), "Toe" = toes.Copy(), "Fastening" = list("None" = null, "Laced" = "tl_boots_tall_laces", "Buckled" = "tl_boot_buckle", "Strapped" = "tl_boot_strap"), "Cuff" = list("None" = null, "Turned" = "tl_boots_tall_cuff", "Fur" = "tl_boots_tall_fur")), "node" = "fine_garments", "cost" = 3, "fabrics" = list("leather"), "garment" = /obj/item/clothing/shoes/leatherboots/tailored)
	var/list/belt_patterns = list("Plain" = null, "Studded" = "tl_waist_studs", "Striped" = "tl_waist_stripe")
	var/list/buckles = list("Square" = "tl_waist_buckle_square", "Round" = "tl_waist_buckle_round", "Plate" = "tl_waist_buckle_plate")
	var/list/belt_ends = list("Tucked" = null, "Hanging" = "tl_waist_end")
	C["made_belt"] = list("name" = "belt", "slot" = "belt", "art" = "tailoring", "base" = "tl_waist_belt", "panels" = list(), "options" = list("Pattern" = belt_patterns.Copy(), "Buckle" = buckles.Copy(), "End" = belt_ends.Copy()), "node" = "weaving", "cost" = 1, "fabrics" = list("leather"))
	C["made_wide_belt"] = list("name" = "wide belt", "slot" = "belt", "art" = "tailoring", "base" = "tl_waist_wide", "panels" = list(), "options" = list("Pattern" = belt_patterns.Copy(), "Buckle" = buckles.Copy(), "End" = belt_ends.Copy()), "node" = "tailoring", "cost" = 1, "fabrics" = list("leather"))
	C["made_sash"] = list("name" = "waist sash", "slot" = "belt", "art" = "tailoring", "base" = "tl_waist_sash", "panels" = list(), "options" = list("Pattern" = list("Plain" = null, "Striped" = "tl_waist_sash_stripes"), "Ends" = list("Plain" = null, "Fringed" = "tl_waist_sash_fringe")), "node" = "classical_dress", "cost" = 1)
	tailoring_catalogue = C
	return C

// Piece state -> list(research node, extra fabric, body parts it covers).
// Pieces not listed need only the body's own knowledge, no extra fabric, and
// cover nothing the body does not.
var/global/list/tailoring_piece_info = list(
	"tl_sleeve_long" = list("weaving", 1, ARMS),
	"tl_neck_v" = list("tailoring", 0, 0),
	"tl_neck_high" = list("fine_garments", 0, 0),
	"tl_legs_trousers" = list("weaving", 2, LOWER_TORSO|LEGS),
	"tl_legs_shorts" = list("weaving", 1, LOWER_TORSO),
	"tl_legs_breeches" = list("tailoring", 1, LOWER_TORSO|LEGS),
	"tl_legs_skirt" = list("weaving", 2, LOWER_TORSO|LEGS),
	"tl_sash" = list("classical_dress", 0, 0),
	"tl_shirt_checks" = list("tailoring", 0, 0),
	"tl_tunic_checks" = list("tailoring", 0, 0),
	"tl_gown_checks" = list("tailoring", 0, 0),
	"tl_coat_sleeve_long" = list("tailoring", 1, ARMS),
	"tl_coat_sleeve_cuffed" = list("fine_garments", 1, ARMS),
	"tl_collar_lapels" = list("fine_garments", 0, 0),
	"tl_buttons_double" = list("fine_garments", 0, 0),
	"tl_cloak_hood" = list("weaving", 1, HEAD),
	"tl_hat_round_panels" = list("tailoring", 0, 0),
	"tl_hat_pointed_panels" = list("tailoring", 0, 0),
	"tl_hat_soft_panels" = list("tailoring", 0, 0),
	"tl_hat_tall_panels" = list("tailoring", 0, 0),
	"tl_hat_brim_wide" = list("tailoring", 1, 0),
	"tl_hat_peak" = list("textile_mills", 0, 0),
	"tl_hat_brim_cocked" = list("fine_garments", 1, 0),
	"tl_hat_flaps" = list("weaving", 1, 0),
	"tl_hat_neck_cloth" = list("classical_dress", 1, 0),
	"tl_hat_feather" = list("tailoring", 0, 0),
	"tl_hat_plume" = list("fine_garments", 0, 0),
	"tl_hat_badge" = list("classical_dress", 0, 0),
	"tl_hat_ribbons" = list("tailoring", 0, 0),
	"tl_glove_gauntlet" = list("fine_garments", 1, 0),
	"tl_glove_knuckles" = list("tailoring", 0, 0),
	"tl_glove_tips" = list("tailoring", 0, 0),
	"tl_boot_toecap" = list("fine_garments", 0, 0),
	"tl_boot_buckle" = list("classical_dress", 0, 0),
	"tl_shoes_laces" = list("tailoring", 0, 0),
	"tl_boots_laces" = list("tailoring", 0, 0),
	"tl_boots_tall_laces" = list("tailoring", 0, 0),
	"tl_waist_buckle_round" = list("classical_dress", 0, 0),
	"tl_waist_buckle_plate" = list("fine_garments", 1, 0),
	"tl_waist_studs" = list("tailoring", 0, 0),
	"tl_waist_end" = list("tailoring", 0, 0),
	"tl_waist_sash_fringe" = list("tailoring", 0, 0))

// The material a project is made of: the stack it takes, its name, the
// coldest temperature it keeps out per layer, its padding against cuts and
// arrows, and a tone multiplied into every dye (wool takes colour darker, and
// leather shows its own tan through every dye). Leather is for gloves,
// footwear and belts only, whose warmth and protection come from the item.
var/global/list/tailoring_fabrics = list(
	"cloth" = list("stack" = /obj/item/stack/material/cloth, "name" = "linen", "under_cold" = 240, "suit_cold" = 225, "padding" = 0, "tone" = "#ffffff"),
	"woolcloth" = list("stack" = /obj/item/stack/material/woolcloth, "name" = "wool", "under_cold" = 225, "suit_cold" = COAT_MIN_COLD_PROTECTION_TEMPERATURE, "padding" = 5, "tone" = "#e6dccb"),
	"leather" = list("stack" = /obj/item/stack/material/leather, "name" = "leather", "under_cold" = 240, "suit_cold" = 225, "padding" = 0, "tone" = "#cfa97c"))

#define TAILORING_WOVEN list("cloth", "woolcloth")

// Whether a body can be made of this material.
/proc/tailoring_body_fits(body_id, fabric_kind)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return FALSE
	var/list/fabrics = body["fabrics"] ? body["fabrics"] : TAILORING_WOVEN
	if (!istext(fabric_kind) || !tailoring_fabrics[fabric_kind])
		fabric_kind = "cloth"
	return (fabric_kind in fabrics)

// "leather or wool": the materials a body can be made of.
/proc/tailoring_body_fabric_names(body_id)
	var/list/body = tailoring_body(body_id)
	var/list/names = list()
	if (body)
		var/list/fabrics = body["fabrics"] ? body["fabrics"] : TAILORING_WOVEN
		for (var/kind in fabrics)
			var/list/F = tailoring_fabrics[kind]
			names += F["name"]
	return jointext(names, " or ")

// The first body in the catalogue this material can make.
/proc/tailoring_default_body(fabric_kind)
	var/list/C = tailoring_bodies()
	for (var/body_id in C)
		if (tailoring_body_fits(body_id, fabric_kind))
			return body_id
	return null

/proc/tailoring_fabric(kind)
	return (istext(kind) && tailoring_fabrics[kind]) ? tailoring_fabrics[kind] : tailoring_fabrics["cloth"]

/proc/tailoring_fabric_kind_of(obj/item/stack/S)
	for (var/kind in tailoring_fabrics)
		var/list/F = tailoring_fabrics[kind]
		if (istype(S) && S.type == F["stack"])
			return kind
	return null

// A dye seen through the fabric: each channel multiplied by the fabric tone.
/proc/tailoring_tint(color, tone)
	if (!tone || tone == "#ffffff")
		return color
	var/list/c = rgb2num(color)
	var/list/t = rgb2num(tone)
	return rgb(round(c[1] * t[1] / 255), round(c[2] * t[2] / 255), round(c[3] * t[3] / 255))

// Dyes by knowledge. Natural dyes come with weaving, mordanted dyes with
// classical dress and costly dyes with fine garments; textile mills mix any
// colour. Colour name -> hex, all lower case.
var/global/list/tailoring_dye_tiers = list(
	"weaving" = list("undyed" = "#ffffff", "oatmeal" = "#d8ccb0", "walnut brown" = "#6e4c30", "ochre yellow" = "#c8962e", "red ochre" = "#9a4a2e", "charcoal grey" = "#4c4a48", "pale woad blue" = "#7890a8", "moss green" = "#74805a"),
	"classical_dress" = list("madder red" = "#a8342c", "weld yellow" = "#d6c050", "woad blue" = "#3e5a86", "forest green" = "#3e6a3a", "lichen purple" = "#7a3e6e", "oak-gall black" = "#2a2826", "rose madder" = "#c8707a", "saffron orange" = "#d88a2a"),
	"fine_garments" = list("kermes crimson" = "#b01c30", "indigo navy" = "#232f58", "royal purple" = "#5e1a48", "cochineal scarlet" = "#d0302a", "verdigris teal" = "#3a8a80", "gold yellow" = "#e0b030", "sky blue" = "#6aa0d8", "rose pink" = "#e0a0b0"))

#define TAILORING_ANY_DYE_NODE "textile_mills"

// Dye name -> hex this person can make, or null when any colour is possible.
/proc/tailoring_known_dyes(mob/living/human/H)
	if (crafting_node_allowed(H, TAILORING_ANY_DYE_NODE))
		return null
	var/list/known = list()
	for (var/node in tailoring_dye_tiers)
		if (crafting_node_allowed(H, node))
			known += tailoring_dye_tiers[node]
	return known

// The knowledge a colour needs: its dye tier, or textile mills for any other.
/proc/tailoring_dye_node(color)
	color = lowertext(color)
	for (var/node in tailoring_dye_tiers)
		var/list/tier = tailoring_dye_tiers[node]
		for (var/dye in tier)
			if (tier[dye] == color)
				return node
	return TAILORING_ANY_DYE_NODE

/proc/tailoring_dye_name(color)
	color = lowertext(color)
	for (var/node in tailoring_dye_tiers)
		var/list/tier = tailoring_dye_tiers[node]
		for (var/dye in tier)
			if (tier[dye] == color)
				return dye
	return null

// Option label -> chosen variant label, fitted to the body: unknown or
// missing choices become the option's first variant.
/proc/tailoring_pieces(body_id, pieces_text)
	var/list/body = tailoring_body(body_id)
	var/list/chosen = list()
	if (!body)
		return chosen
	var/list/options = body["options"]
	var/list/given = istext(pieces_text) && length(pieces_text) ? splittext(pieces_text, "|") : list()
	var/index = 0
	for (var/label in options)
		index++
		var/list/variants = options[label]
		var/value = index <= given.len ? given[index] : null
		chosen[label] = (value && (value in variants)) ? value : variants[1]
	return chosen

/proc/tailoring_pieces_text(list/chosen)
	var/list/values = list()
	for (var/label in chosen)
		values += chosen[label]
	return jointext(values, "|")

// The drawn state of every chosen piece, null where the variant draws nothing.
/proc/tailoring_piece_states(body_id, pieces_text)
	var/list/body = tailoring_body(body_id)
	var/list/states = list()
	if (!body)
		return states
	var/list/options = body["options"]
	var/list/chosen = tailoring_pieces(body_id, pieces_text)
	for (var/label in options)
		var/list/variants = options[label]
		states += variants[chosen[label]]
	return states

/proc/tailoring_piece_node(state)
	var/list/info = state ? tailoring_piece_info[state] : null
	return info ? info[1] : null

/proc/tailoring_variant_allowed(mob/living/human/H, list/body, state)
	var/node = tailoring_piece_node(state)
	return !node || crafting_node_allowed(H, node)

// Fabric for the body and every chosen piece.
/proc/tailoring_design_cost(body_id, pieces_text)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return TAILORING_MAX_FABRIC + 1
	var/cost = body["cost"]
	for (var/state in tailoring_piece_states(body_id, pieces_text))
		var/list/info = state ? tailoring_piece_info[state] : null
		if (info)
			cost += info[2]
	return cost

// The body, every chosen piece and every dye must be known.
/proc/tailoring_design_allowed(mob/living/human/H, body_id, pieces_text, colors_text)
	return tailoring_body(body_id) && !tailoring_missing_node(H, body_id, pieces_text, colors_text)

// Names the knowledge a design still needs, or null when it is all known.
/proc/tailoring_missing_node(mob/living/human/H, body_id, pieces_text, colors_text)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return null
	if (!crafting_node_allowed(H, body["node"]))
		return body["node"]
	for (var/state in tailoring_piece_states(body_id, pieces_text))
		var/node = tailoring_piece_node(state)
		if (node && !crafting_node_allowed(H, node))
			return node
	for (var/color in tailoring_colors(body_id, colors_text))
		var/node = tailoring_dye_node(color)
		if (!crafting_node_allowed(H, node) && !crafting_node_allowed(H, TAILORING_ANY_DYE_NODE))
			return node
	return null

// Body parts the body and its chosen pieces cover.
/proc/tailoring_design_covers(body_id, pieces_text)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return 0
	var/covers = body["covers"]
	for (var/state in tailoring_piece_states(body_id, pieces_text))
		var/list/info = state ? tailoring_piece_info[state] : null
		if (info && info.len >= 3)
			covers |= info[3]
	return covers

/proc/tailoring_set_piece(body_id, pieces_text, label, value)
	var/list/chosen = tailoring_pieces(body_id, pieces_text)
	var/list/body = tailoring_body(body_id)
	var/list/options = body ? body["options"] : null
	if (!options || !(label in options) || !(value in options[label]))
		return pieces_text
	chosen[label] = value
	return tailoring_pieces_text(chosen)

/proc/tailoring_body(body_id)
	if (!istext(body_id))
		return null
	var/list/C = tailoring_bodies()
	return C[body_id]

// The worn and loose icon files for a body's slot.
/proc/tailoring_art(list/body, worn)
	if (body["art"] == "tailoring")
		return worn ? 'icons/mob/tailoring.dmi' : 'icons/obj/clothing/tailoring.dmi'
	if (body["slot"] == "suit")
		return worn ? 'icons/mob/suit.dmi' : 'icons/obj/clothing/suits.dmi'
	if (body["slot"] == "head")
		return worn ? 'icons/mob/head.dmi' : 'icons/obj/clothing/hats.dmi'
	return worn ? 'icons/mob/uniform.dmi' : 'icons/obj/clothing/uniforms.dmi'

// "Body" first, then the pattern pieces in drawing order.
/proc/tailoring_piece_labels(list/body)
	var/list/labels = list("Body")
	var/list/panels = body["panels"]
	labels += panels
	var/list/options = body["options"]
	if (options)
		labels += options
	return labels

/proc/tailoring_body_allowed(mob/living/human/H, body_id)
	var/list/body = tailoring_body(body_id)
	return body && crafting_node_allowed(H, body["node"])

/proc/tailoring_slot_name(list/body)
	switch (body["slot"])
		if ("suit")
			return "overclothes"
		if ("head")
			return "headwear"
		if ("gloves")
			return "gloves"
		if ("shoes")
			return "footwear"
		if ("belt")
			return "belt"
	return "clothing"

// Bodies this person knows how to cut from this material, as display name -> id.
/proc/tailoring_known_bodies(mob/living/human/H, fabric_kind = "cloth")
	var/list/known = list()
	var/list/C = tailoring_bodies()
	for (var/body_id in C)
		var/list/body = C[body_id]
		if (crafting_node_allowed(H, body["node"]) && tailoring_body_fits(body_id, fabric_kind))
			known["[body["name"]] ([tailoring_slot_name(body)], [body["cost"]] fabric)"] = body_id
	return known

// Opaque RGB only: transparent or malformed input must never hide the garment.
/proc/tailoring_color_valid(value)
	if (!istext(value) || length(value) != 7 || copytext(value, 1, 2) != "#")
		return FALSE
	for (var/i = 2, i <= 7, i++)
		if (!findtext("0123456789abcdef", lowertext(copytext(value, i, i + 1))))
			return FALSE
	return TRUE

// The design's colours fitted to the body: one per label, white where unset.
/proc/tailoring_colors(body_id, colors_text)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return null
	var/list/given = istext(colors_text) && length(colors_text) ? splittext(colors_text, "|") : list()
	var/list/colors = list()
	var/count = length(tailoring_piece_labels(body))
	for (var/i = 1, i <= count, i++)
		var/value = i <= given.len ? given[i] : "#ffffff"
		colors += tailoring_color_valid(value) ? lowertext(value) : "#ffffff"
	return colors

/proc/tailoring_design_valid(body_id, colors_text, pieces_text = null)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return FALSE
	var/list/options = body["options"]
	var/list/chosen = istext(pieces_text) && length(pieces_text) ? splittext(pieces_text, "|") : list()
	if (chosen.len > length(options))
		return FALSE
	var/option_index = 0
	for (var/value in chosen)
		var/list/variants = options[options[++option_index]]
		if (!(value in variants))
			return FALSE
	var/list/labels = tailoring_piece_labels(body)
	if (labels.len > TAILORING_MAX_COLOURS)
		return FALSE
	var/list/given = istext(colors_text) && length(colors_text) ? splittext(colors_text, "|") : list()
	if (given.len > labels.len)
		return FALSE
	for (var/value in given)
		if (!tailoring_color_valid(value))
			return FALSE
	return TRUE

// The coloured body, then each coloured piece, then uncoloured fixed parts.
// The same list drives the loose item, the worn sprite and the preview.
/proc/tailoring_layers(body_id, colors_text, worn = FALSE, pieces_text = null, fabric_kind = null)
	if (!tailoring_design_valid(body_id, colors_text, pieces_text))
		return list()
	var/list/body = tailoring_body(body_id)
	var/art = tailoring_art(body, worn)
	var/list/colors = tailoring_colors(body_id, colors_text)
	var/list/fabric = tailoring_fabric(fabric_kind)
	for (var/i = 1, i <= colors.len, i++)
		colors[i] = tailoring_tint(colors[i], fabric["tone"])
	var/list/layers = list()
	var/image/main = image(icon = art, icon_state = (!worn && body["item_base"]) ? body["item_base"] : body["base"])
	main.color = colors[1]
	layers += main
	var/list/panels = body["panels"]
	var/index = 1
	for (var/label in panels)
		var/image/piece = image(icon = art, icon_state = panels[label])
		piece.color = colors[++index]
		layers += piece
	for (var/state in tailoring_piece_states(body_id, pieces_text))
		index++
		if (!state)
			continue
		var/image/piece = image(icon = art, icon_state = state)
		piece.color = colors[index]
		layers += piece
	var/list/fixed = body["fixed"]
	for (var/state in fixed)
		layers += image(icon = art, icon_state = state)
	return layers

/proc/tailoring_set_color(body_id, colors_text, index, value)
	var/list/colors = tailoring_colors(body_id, colors_text)
	if (!colors || index < 1 || index > colors.len || !tailoring_color_valid(value))
		return colors_text
	colors[index] = lowertext(value)
	return jointext(colors, "|")

// Clothing carries the design itself, so any slot can be tailored later.
/obj/item/clothing
	var/design_body = null
	var/design_colors = null
	var/design_pieces = null
	// The woven fabric it was sewn from; null for garments from elsewhere.
	var/design_fabric = null
	// A player's own name for the design, the character who designed it (shown
	// to players) and that player's ckey (shown only to staff).
	var/design_name = null
	var/design_maker = null
	var/design_author = null
	var/tmp/list/tailoring_overlays = null

/obj/item/clothing/persistence_runtime_var(key)
	return key == "tailoring_overlays" || ..()

/obj/item/clothing/proc/tailoring_refresh()
	var/list/body = tailoring_body(design_body)
	if (!body || !tailoring_design_valid(design_body, design_colors, design_pieces))
		return FALSE
	name = design_name ? design_name : body["name"]
	icon = tailoring_art(body, FALSE)
	icon_override = body["art"] ? tailoring_art(body, TRUE) : initial(icon_override)
	icon_state = body["item_base"] ? body["item_base"] : body["base"]
	item_state = body["base"]
	if (body["slot"] == "under")
		if (!item_state_slots)
			item_state_slots = list()
		item_state_slots[slot_w_uniform_str] = body["base"]
	if (body["slot"] == "head")
		flags_inv = body["hides_hair"] ? BLOCKHAIR : initial(flags_inv)
	var/covers = tailoring_design_covers(design_body, design_pieces)
	if (covers)
		body_parts_covered = covers
		cold_protection = covers
		heat_protection = covers
	// Fabric sets warmth and padding only for clothes and hats sewn as
	// tailoring; gloves, footwear and belts keep what their item gives.
	if (design_fabric && (body["slot"] in list("under", "suit", "head")))
		var/list/fabric = tailoring_fabric(design_fabric)
		min_cold_protection_temperature = body["slot"] == "suit" ? fabric["suit_cold"] : fabric["under_cold"]
		armor = armor ? armor.Copy() : list()
		armor["melee"] = fabric["padding"]
		armor["arrow"] = fabric["padding"]
	if (tailoring_overlays)
		overlays -= tailoring_overlays
	tailoring_overlays = tailoring_layers(design_body, design_colors, FALSE, design_pieces, design_fabric)
	overlays = tailoring_overlays + overlays.Copy() // Keep attachments and stains above the design.
	update_clothing_icon()
	return TRUE

/obj/item/clothing/proc/worn_design_layers()
	if (!design_body)
		return null
	return tailoring_layers(design_body, design_colors, TRUE, design_pieces, design_fabric)

// Saved overlays are derived. Rebuild in normal attachment order: design,
// then accessories, then any existing stains.
/obj/item/clothing/proc/tailoring_rebuild_after_load()
	overlays.Cut()
	tailoring_overlays = null
	tailoring_refresh()
	for (var/obj/item/clothing/accessory/accessory in accessories)
		overlays += accessory.get_inv_overlay()
	if (blood_DNA && blood_DNA.len && blood_overlay)
		overlays += blood_overlay
	if (shit_overlay)
		overlays += shit_overlay
	if (piss_overlay)
		overlays += piss_overlay

/obj/item/clothing/under/tailored
	name = "tailored clothing"
	desc = "Clothing sewn to its owner's own design, with every panel coloured by hand. Ordinary accessories can be added."
	icon_state = "customtunic"
	item_state = "customtunic"
	design_body = "tunic"
	design_colors = "#ffffff"

/obj/item/clothing/under/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/under/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/under/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/under/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/under/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/clothing/suit/storage/jacket/tailored
	name = "tailored overclothes"
	desc = "Overclothes sewn to their owner's own design, with every panel coloured by hand. Ordinary accessories can be added."
	icon_state = "customponcho"
	item_state = "customponcho"
	design_body = "poncho"
	design_colors = "#ffffff"

/obj/item/clothing/suit/storage/jacket/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/suit/storage/jacket/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/suit/storage/jacket/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/suit/storage/jacket/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/suit/storage/jacket/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/clothing/head/tailored
	name = "tailored headwear"
	desc = "Headwear sewn to its owner's own design, with every panel coloured by hand."
	icon = 'icons/obj/clothing/hats.dmi'
	icon_state = "customberet_hat"
	item_state = "customberet_hat"
	design_body = "beret"
	design_colors = "#ffffff"
	body_parts_covered = HEAD
	cold_protection = HEAD

/obj/item/clothing/head/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/head/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/head/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/head/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/head/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

// Gloves, footwear and belts: the design is looks only. Each is a subtype of
// the plain item of its kind, so it protects, grips and carries the same.
/obj/item/clothing/gloves/thick/leather/tailored
	name = "tailored gloves"
	desc = "Gloves sewn to their owner's own design. They protect the hands like any thick gloves."
	design_body = "made_gloves"
	design_colors = "#ffffff"

/obj/item/clothing/gloves/thick/leather/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/gloves/thick/leather/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/gloves/thick/leather/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/gloves/thick/leather/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/gloves/thick/leather/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/clothing/shoes/tailored
	name = "tailored shoes"
	desc = "Leather shoes sewn to their owner's own design."
	design_body = "made_shoes"
	design_colors = "#ffffff"
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/shoes/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/shoes/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/shoes/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/shoes/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/clothing/shoes/leatherboots/tailored
	name = "tailored boots"
	desc = "Leather boots sewn to their owner's own design. They protect and grip like any leather boots."
	design_body = "made_boots"
	design_colors = "#ffffff"

/obj/item/clothing/shoes/leatherboots/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/shoes/leatherboots/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/shoes/leatherboots/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/shoes/leatherboots/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/shoes/leatherboots/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/clothing/pouch_belt/tailored
	name = "tailored belt"
	desc = "A belt made to its owner's own design. Hang a pouch or two, a sheath or holster and a tool loop from it, as from any belt."
	design_body = "made_belt"
	design_colors = "#ffffff"

/obj/item/clothing/pouch_belt/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/pouch_belt/tailored/after_load()
	..()
	tailoring_rebuild_after_load()
	tailoring_register(src)

/obj/item/clothing/pouch_belt/tailored/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/clothing/pouch_belt/tailored/examine(mob/user)
	..()
	tailoring_examine_credit(user, design_body, design_maker)

/obj/item/clothing/pouch_belt/tailored/Destroy()
	tailoring_named_items -= src
	return ..()

/proc/tailoring_garment_type(list/body)
	if (body["garment"])
		return body["garment"]
	switch (body["slot"])
		if ("suit")
			return /obj/item/clothing/suit/storage/jacket/tailored
		if ("head")
			return /obj/item/clothing/head/tailored
		if ("gloves")
			return /obj/item/clothing/gloves/thick/leather/tailored
		if ("shoes")
			return /obj/item/clothing/shoes/tailored
		if ("belt")
			return /obj/item/clothing/pouch_belt/tailored
	return /obj/item/clothing/under/tailored

// Live preview: four HUD tiles, one per facing, drawn from the same overlays
// as the worn garment. They belong to the client and are never saved.
/client/var/list/tailoring_preview = null

/obj/screen/tailoring_preview
	name = "design preview"
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "block"
	layer = 20
	mouse_opacity = 0

/client/proc/hide_tailoring_preview()
	if (!tailoring_preview)
		return
	screen -= tailoring_preview
	for (var/obj/screen/tailoring_preview/T in tailoring_preview)
		qdel(T)
	tailoring_preview = null

/client/proc/show_tailoring_preview(body_id, colors_text, pieces_text = null, fabric_kind = null)
	hide_tailoring_preview()
	var/list/body = tailoring_body(body_id)
	if (!body || !tailoring_design_valid(body_id, colors_text, pieces_text))
		return FALSE
	var/list/tiles = list()
	var/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/list/layers = tailoring_layers(body_id, colors_text, TRUE, pieces_text, fabric_kind)
	for (var/i = 1, i <= facings.len, i++)
		var/obj/screen/tailoring_preview/T = new()
		if (prefs && prefs.UI_file)
			T.icon = prefs.UI_file
		T.dir = facings[i]
		T.screen_loc = "WEST+[i * 2 - 1],NORTH-1"
		T.transform = matrix(2, 0, 0, 0, 2, 0)
		T.overlays += layers
		tiles += T
	tailoring_preview = tiles
	screen += tiles
	return TRUE

/obj/item/tailoring_project
	name = "tailoring project"
	desc = "Fabric or leather set aside for one garment. Use it in hand to choose what to make and colour each piece, then cut and sew it. Add more sheets of the same material to it for larger garments. Cloth and woolcloth make clothes and hats; leather makes gloves, footwear and belts. Cutting locks the design. While uncut, hold it in one hand and use a finished bag, quiver or bandolier on it to restyle that, or finished tailored clothing to make a minor alteration, for one sheet."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-cloth"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	var/design_body = "long_tunic"
	var/design_colors = "#ffffff"
	var/design_pieces = null
	var/design_name = null
	var/design_maker = null
	var/design_author = null
	// Which material the project is made of; every added sheet must match.
	var/fabric_kind = "cloth"
	// Sheets of fabric held, including the one the project was made from.
	var/fabric = 1
	// 0: editable fabric; 1: cut pieces; 2: consumed, never usable again.
	var/stage = 0
	var/tmp/tailoring_busy = FALSE

/obj/item/tailoring_project/persistence_runtime_var(key)
	return key == "tailoring_busy" || ..()

/obj/item/tailoring_project/proc/actor_ready(mob/living/human/user, turf/site, datum/save_epoch)
	return istype(user) && !QDELETED(src) && !QDELETED(user) && !gcDestroyed && loc == user && (user.l_hand == src || user.r_hand == src) && isturf(user.loc) && user.loc == site && !user.incapacitated() && user.can_use_hands() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity && crafting_node_allowed(user, "weaving")

/obj/item/tailoring_project/proc/wait_for_tailoring(mob/living/human/user, delay)
	return do_after(user, trade_time(user, delay, "tailor"), src)

/obj/item/tailoring_project/proc/body_cost()
	return tailoring_design_cost(design_body, design_pieces)

// A project starts on a garment its material can make: a leather one on gloves.
/obj/item/tailoring_project/proc/fit_fabric()
	if (stage != 0 || tailoring_body_fits(design_body, fabric_kind))
		return
	var/fitting = tailoring_default_body(fabric_kind)
	if (!fitting)
		return
	design_body = fitting
	design_colors = "#ffffff"
	var/list/body = tailoring_body(design_body)
	design_pieces = length(body["options"]) ? tailoring_pieces_text(tailoring_pieces(design_body, null)) : null

/obj/item/tailoring_project/after_load()
	..()
	tailoring_register(src)

/obj/item/tailoring_project/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/tailoring_project/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	if (istype(W, /obj/item/sewing_pattern))
		load_pattern(user, W)
		return
	// A finished bag or bandolier used on the project is restyled (bag_styling.dm).
	if (bag_style_kind(W))
		style_bag(user, W)
		return
	// Finished tailored clothing used on the project is altered (tailoring_alterations.dm).
	if (istype(W, /obj/item/clothing))
		var/obj/item/clothing/garment = W
		if (tailoring_body(garment.design_body))
			alter_garment(user, garment)
			return
	var/sheet_kind = tailoring_fabric_kind_of(W)
	if (sheet_kind)
		var/obj/item/stack/material/S = W
		if (stage != 0)
			to_chat(user, SPAN_WARNING("The fabric is already cut."))
			return
		if (sheet_kind != fabric_kind)
			var/list/project_fabric = tailoring_fabric(fabric_kind)
			to_chat(user, SPAN_WARNING("\The [src] is [project_fabric["name"]]. Add [project_fabric["name"]] sheets to it, or start another project for this fabric."))
			return
		if (fabric >= TAILORING_MAX_FABRIC)
			to_chat(user, SPAN_WARNING("\The [src] already holds as much fabric as any garment needs."))
			return
		if (!S.use(1))
			return
		fabric++
		to_chat(user, SPAN_NOTICE("You add a sheet of fabric. \The [src] now holds [fabric]."))
		return
	return ..()

/obj/item/tailoring_project/attack_self(mob/living/human/user)
	var/turf/site = get_turf(user)
	var/datum/save_epoch = persistence_admission_identity
	if (tailoring_busy || stage >= 2)
		return
	fit_fabric()
	// Say which knowledge is missing: a project can be handed to someone untrained.
	if (!crafting_node_allowed_or_warn(user, "weaving") || !actor_ready(user, site, save_epoch))
		return
	tailoring_busy = TRUE
	design_menu(user, site, save_epoch)
	if (user.client)
		user.client.hide_tailoring_preview()
	tailoring_busy = FALSE

/obj/item/tailoring_project/proc/design_menu(mob/living/human/user, turf/site, datum/save_epoch)
	while (actor_ready(user, site, save_epoch) && (stage == 0 || stage == 1))
		var/list/body = tailoring_body(design_body)
		if (user.client)
			user.client.show_tailoring_preview(design_body, design_colors, design_pieces, fabric_kind)
		var/garment = body ? body["name"] : "garment"
		var/list/material = tailoring_fabric(fabric_kind)
		var/list/options = stage == 0 ? list("Choose garment", "Colours", "Name", "Cut fabric", "Close") : list("Sew", "Close")
		if (stage == 0 && body && length(body["options"]))
			options.Insert(2, "Pieces")
		if (stage == 0 && user.ckey)
			options.Insert(options.len, "Pattern book")
		var/status = stage == 0 ? "Designing in [material["name"]]: [garment]. The design needs [body_cost()] sheet\s and the project holds [fabric]." : "The pieces of the [garment] are cut and ready to sew."
		var/choice = WWinput(user, status, "Tailoring", "Close", options)
		if (!actor_ready(user, site, save_epoch) || !choice || choice == "Close")
			return
		switch (choice)
			if ("Choose garment")
				if (stage != 0)
					return
				var/list/known = tailoring_known_bodies(user, fabric_kind)
				if (!known.len)
					to_chat(user, SPAN_WARNING("You don't know anything to make from [material["name"]] yet."))
					return
				var/selected = WWinput(user, "Choose what to make from [material["name"]]. Cloth and woolcloth make clothes and hats; leather makes gloves, footwear and belts. The list grows as you learn more tailoring.", "Garment", null, known)
				if (actor_ready(user, site, save_epoch) && stage == 0 && (selected in known) && tailoring_body_allowed(user, known[selected]) && tailoring_body_fits(known[selected], fabric_kind))
					design_body = known[selected]
					design_colors = jointext(tailoring_colors(design_body, design_colors), "|")
					var/list/new_body = tailoring_body(design_body)
					design_pieces = length(new_body["options"]) ? tailoring_pieces_text(tailoring_pieces(design_body, null)) : null
					claim_design(user)
			if ("Pieces")
				if (stage != 0 || !body)
					return
				choose_piece(user, site, save_epoch)
			if ("Colours")
				if (stage != 0 || !body)
					return
				var/list/labels = tailoring_piece_labels(body)
				var/piece = WWinput(user, "Choose a piece to colour. Body colours everything the other pieces leave uncovered.", "Pieces", null, labels)
				if (!actor_ready(user, site, save_epoch) || stage != 0 || !piece || !(piece in labels))
					continue
				var/index = labels.Find(piece)
				var/list/colors = tailoring_colors(design_body, design_colors)
				var/selected_color = choose_dye(user, piece, colors[index])
				if (!actor_ready(user, site, save_epoch) || stage != 0 || !tailoring_color_valid(selected_color))
					continue
				design_colors = tailoring_set_color(design_body, design_colors, index, selected_color)
				claim_design(user)
			if ("Name")
				if (stage != 0)
					return
				choose_name(user, site, save_epoch)
			if ("Pattern book")
				if (stage != 0)
					return
				pattern_book_menu(user, site, save_epoch)
			if ("Cut fabric")
				if (fabric < body_cost())
					to_chat(user, SPAN_WARNING("This design needs [body_cost()] sheet\s. Add [material["name"]] sheets to the project first."))
					continue
				var/confirm = WWinput(user, "Cut this design? You can no longer change the garment or colours afterward.", "Cut fabric", "Keep designing", list("Keep designing", "Cut fabric"))
				if (confirm == "Cut fabric")
					cut_fabric(user, site, save_epoch)
			if ("Sew")
				sew_garment(user, site, save_epoch)
				return

// Dyes this person knows, or any colour once they know textile mills.
/obj/item/tailoring_project/proc/choose_dye(mob/living/human/user, piece, current)
	var/list/dyes = tailoring_known_dyes(user)
	if (!dyes)
		return WWinput(user, "Choose the [lowertext(piece)] colour.", "Colour", current, "color")
	var/list/menu = list()
	for (var/dye in dyes)
		menu["[dye][dyes[dye] == lowertext(current) ? " (current)" : ""]"] = dyes[dye]
	var/picked = WWinput(user, "Choose a dye for the [lowertext(piece)]. Learning more tailoring brings more dyes.", "Dye", null, menu)
	return (picked in menu) ? menu[picked] : null

// Pick a piece option, then one of its variants this person knows.
/obj/item/tailoring_project/proc/choose_piece(mob/living/human/user, turf/site, datum/save_epoch)
	var/list/body = tailoring_body(design_body)
	var/list/options = body["options"]
	if (!length(options))
		return
	var/list/chosen = tailoring_pieces(design_body, design_pieces)
	var/list/menu = list()
	for (var/label in options)
		menu["[label]: [lowertext(chosen[label])]"] = label
	var/picked = WWinput(user, "Choose a piece to change.", "Pieces", null, menu)
	if (!actor_ready(user, site, save_epoch) || stage != 0 || !(picked in menu))
		return
	var/label = menu[picked]
	var/list/variants = options[label]
	var/list/known = list()
	for (var/variant in variants)
		var/state = variants[variant]
		if (!tailoring_variant_allowed(user, body, state))
			continue
		var/list/info = state ? tailoring_piece_info[state] : null
		known[info && info[2] ? "[variant] (+[info[2]] fabric)" : variant] = variant
	var/selected = WWinput(user, "Choose the [lowertext(label)].", label, null, known)
	if (!actor_ready(user, site, save_epoch) || stage != 0 || !(selected in known))
		return
	design_pieces = tailoring_set_piece(design_body, design_pieces, label, known[selected])
	claim_design(user)

/obj/item/tailoring_project/proc/cut_fabric(mob/living/human/user, turf/site, datum/save_epoch)
	if (!actor_ready(user, site, save_epoch) || stage != 0 || !tailoring_design_valid(design_body, design_colors, design_pieces) || !tailoring_design_allowed(user, design_body, design_pieces, design_colors) || !tailoring_body_fits(design_body, fabric_kind) || fabric < body_cost())
		return FALSE
	to_chat(user, SPAN_NOTICE("You start cutting the pattern pieces."))
	if (!wait_for_tailoring(user, 30) || !actor_ready(user, site, save_epoch) || stage != 0 || fabric < body_cost())
		return FALSE
	var/spare = fabric - body_cost()
	stage = 1
	fabric = body_cost()
	var/list/body = tailoring_body(design_body)
	name = "cut [body["name"]] pieces"
	if (spare > 0)
		var/list/spare_fabric = tailoring_fabric(fabric_kind)
		var/spare_type = spare_fabric["stack"]
		new spare_type(site, spare)
	to_chat(user, SPAN_NOTICE("The pieces are cut[spare > 0 ? " and you set aside [spare] spare sheet\s" : ""]. Use the project in hand to sew them together."))
	return TRUE

/obj/item/tailoring_project/proc/sew_garment(mob/living/human/user, turf/site, datum/save_epoch)
	if (!actor_ready(user, site, save_epoch) || stage != 1 || !tailoring_design_valid(design_body, design_colors, design_pieces) || !tailoring_design_allowed(user, design_body, design_pieces, design_colors))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start sewing the pieces together."))
	if (!wait_for_tailoring(user, 60) || !actor_ready(user, site, save_epoch) || stage != 1)
		return FALSE
	// Clear the actual inventory slot before replacing the paid project. There
	// are no yields from retirement through output, so competing finishers fail.
	if (!user.transfer_held_item_to(src, site))
		return FALSE
	stage = 2
	if (!design_maker)
		claim_design(user)
	var/garment_type = tailoring_garment_type(tailoring_body(design_body))
	var/obj/item/clothing/garment = new garment_type(site)
	garment.design_body = design_body
	garment.design_colors = design_colors
	garment.design_pieces = design_pieces
	garment.design_fabric = fabric_kind
	garment.design_name = design_name
	garment.design_maker = design_maker
	garment.design_author = design_author
	garment.tailoring_refresh()
	tailoring_register(garment)
	qdel(src)
	user.put_in_any_hand_if_possible(garment)
	to_chat(user, SPAN_NOTICE("You finish sewing the [garment.name]."))
	return TRUE

/obj/item/tailoring_project/examine(mob/user)
	..()
	fit_fabric()
	var/list/body = tailoring_body(design_body)
	if (!body)
		return
	var/list/project_fabric = tailoring_fabric(fabric_kind)
	if (stage == 0)
		to_chat(user, "Design: [body["name"]] in [project_fabric["name"]]. It needs [body_cost()] fabric and holds [fabric].")
	else
		to_chat(user, "Design: [body["name"]]. The cut pieces are ready to sew.")

// Projects and dresses from the earlier dress-only version restore as tailoring.
/proc/tailoring_legacy_dress(cut, primary, secondary, accent)
	var/list/ids = list("Layered" = "layered_dress", "Buttoned" = "buttoned_dress", "Laced" = "laced_dress")
	var/body_id = ids[cut]
	if (!body_id)
		return null
	var/list/colors = list("#ffffff", primary, secondary, accent)
	var/list/body = tailoring_body(body_id)
	colors.len = length(tailoring_piece_labels(body))
	for (var/i = 1, i <= colors.len, i++)
		if (!tailoring_color_valid(colors[i]))
			colors[i] = "#ffffff"
	return list(body_id, lowertext(jointext(colors, "|")))

/obj/item/dressmaking_project
	parent_type = /obj/item/tailoring_project
	var/dress_cut = null
	var/primary_color = null
	var/secondary_color = null
	var/accent_color = null

/obj/item/dressmaking_project/after_load()
	..()
	var/list/converted = tailoring_legacy_dress(dress_cut, primary_color, secondary_color, accent_color)
	if (converted)
		design_body = converted[1]
		design_colors = converted[2]
		fabric = max(fabric, body_cost())
		dress_cut = null

/obj/item/clothing/under/tailored_dress
	parent_type = /obj/item/clothing/under/tailored
	var/dress_cut = null
	var/primary_color = null
	var/secondary_color = null
	var/accent_color = null

/obj/item/clothing/under/tailored_dress/after_load()
	var/list/converted = tailoring_legacy_dress(dress_cut, primary_color, secondary_color, accent_color)
	if (converted)
		design_body = converted[1]
		design_colors = converted[2]
		dress_cut = null
	..()

// Sewing patterns, design names and staff moderation.
//
// A design can be traced onto a blank sheet of paper or parchment from a
// tailoring project or a tailored garment. A pattern can be copied onto
// another blank sheet, traded like any item, and used on an uncut project to
// load its design. Names are the only free text in a design: they are
// sanitised and short, and staff can rename them or stop an account naming.

#define TAILORING_NAME_MAX 32
#define TAILORING_TRACE_TIME 30
#define TAILORING_BLOCK_FILE "data/tailoring_name_blocks.sav"

// Every live item carrying a player-chosen design name, for the staff panel.
var/global/list/tailoring_named_items = list()
var/global/list/tailoring_name_block_list = null

/proc/tailoring_register(obj/item/I)
	if (istype(I) && !QDELETED(I) && ("design_name" in I.vars) && I.vars["design_name"])
		tailoring_named_items |= I

/proc/tailoring_clean_name(text)
	if (!istext(text))
		return null
	text = sanitizeSafe(text, TAILORING_NAME_MAX + 1)
	if (!text || length(text) < 2)
		return null
	return text

/proc/tailoring_name_blocks()
	if (!tailoring_name_block_list)
		tailoring_name_block_list = list()
		if (fexists(TAILORING_BLOCK_FILE))
			var/savefile/S = new(TAILORING_BLOCK_FILE)
			var/list/saved
			S["ckeys"] >> saved
			if (islist(saved))
				for (var/key in saved)
					if (istext(key))
						tailoring_name_block_list |= ckey(key)
	return tailoring_name_block_list

/proc/tailoring_name_blocked(key)
	return key && (ckey(key) in tailoring_name_blocks())

/proc/tailoring_set_name_block(key, blocked)
	key = ckey(key)
	if (!key)
		return
	var/list/blocks = tailoring_name_blocks()
	if (blocked)
		blocks |= key
	else
		blocks -= key
	var/savefile/S = new(TAILORING_BLOCK_FILE)
	S["ckeys"] << blocks

// "Body" and each panel with its colour, then each piece option's chosen
// variant; options left plain are not listed.
/proc/tailoring_describe(body_id, colors_text, pieces_text)
	var/list/body = tailoring_body(body_id)
	var/list/labels = tailoring_piece_labels(body)
	var/list/colors = tailoring_colors(body_id, colors_text)
	var/list/chosen = tailoring_pieces(body_id, pieces_text)
	var/list/options = body["options"]
	var/list/lines = list()
	for (var/i = 1, i <= labels.len, i++)
		var/label = labels[i]
		var/text = lowertext(label)
		if (options && (label in options))
			var/list/variants = options[label]
			if (!variants[chosen[label]])
				continue
			text = "[lowertext(chosen[label])] [lowertext(label)]"
		var/dye = tailoring_dye_name(colors[i])
		lines += "<font color='[colors[i]]'>&#9632;</font> [text][dye ? " ([dye])" : ""]"
	return jointext(lines, ", ")

/proc/tailoring_examine_credit(mob/user, body_id, maker)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return
	to_chat(user, "It is a [body["name"]][maker ? ", designed by [maker]" : ""].")

/obj/item/tailoring_project/proc/claim_design(mob/living/human/user)
	design_maker = user.real_name
	design_author = user.ckey

/obj/item/tailoring_project/proc/choose_name(mob/living/human/user, turf/site, datum/save_epoch)
	if (tailoring_name_blocked(user.ckey))
		to_chat(user, SPAN_WARNING("Staff have stopped you naming designs."))
		return
	var/typed = WWinput(user, "Name this design (up to [TAILORING_NAME_MAX] letters), or leave it empty to use the garment's own name.", "Design name", design_name ? html_decode(design_name) : "", "text")
	if (!actor_ready(user, site, save_epoch) || stage != 0)
		return
	if (!typed || !length(trim("[typed]")))
		design_name = null
		tailoring_named_items -= src
		return
	var/clean = tailoring_clean_name("[typed]")
	if (!clean)
		to_chat(user, SPAN_WARNING("That name can't be used."))
		return
	design_name = clean
	claim_design(user)
	tailoring_register(src)

/obj/item/tailoring_project/proc/load_pattern(mob/living/human/user, obj/item/sewing_pattern/P)
	return load_design(user, P.design_body, P.design_colors, P.design_pieces, P.design_name, P.design_maker, P.design_author, "pattern")

// Copies a saved design (from a pattern or the pattern book) onto the uncut project.
/obj/item/tailoring_project/proc/load_design(mob/living/human/user, body_id, colors_text, pieces_text, new_name, maker, author, source = "pattern")
	if (stage != 0)
		to_chat(user, SPAN_WARNING("The fabric is already cut."))
		return FALSE
	if (!crafting_node_allowed_or_warn(user, "weaving") || !tailoring_design_valid(body_id, colors_text, pieces_text))
		return FALSE
	var/list/body = tailoring_body(body_id)
	if (!tailoring_body_fits(body_id, fabric_kind))
		var/list/material = tailoring_fabric(fabric_kind)
		to_chat(user, SPAN_WARNING("This project is [material["name"]], and a design for [body["name"]] is made of [tailoring_body_fabric_names(body_id)]. Start a project from that instead."))
		return FALSE
	if (!tailoring_design_allowed(user, body_id, pieces_text, colors_text))
		var/datum/research_node/N = get_research_node(tailoring_missing_node(user, body_id, pieces_text, colors_text))
		to_chat(user, SPAN_WARNING("You don't know how to make this [body["name"]] yet[N ? ". It needs <b>[N.name]</b>" : ""]."))
		return FALSE
	design_body = body_id
	design_colors = colors_text
	design_pieces = pieces_text
	design_name = new_name
	design_maker = maker
	design_author = author
	if (design_name && tailoring_name_blocked(design_author))
		design_name = null
	if (design_name)
		tailoring_register(src)
	else
		tailoring_named_items -= src
	to_chat(user, SPAN_NOTICE("You copy the [design_name ? "\"[design_name]\"" : body["name"]] [source] onto the project. It needs [body_cost()] fabric."))
	return TRUE

/mob/living/human/proc/tailoring_trace_wait(obj/item/source)
	return do_after(src, trade_time(src, TAILORING_TRACE_TIME, "tailor"), source)

// Traces a design onto a blank sheet the user holds, which becomes a pattern.
/proc/tailoring_trace_pattern(mob/living/human/user, obj/item/weapon/paper/sheet, obj/item/source, body_id, colors_text, design_name, maker, author, pieces_text = null)
	if (!istype(user) || !recipe_blank_paper(sheet) || sheet.loc != user || !source)
		return FALSE
	if (!tailoring_design_valid(body_id, colors_text, pieces_text))
		to_chat(user, SPAN_WARNING("There is no finished design on \the [source] to trace yet."))
		return FALSE
	if (!crafting_node_allowed_or_warn(user, "weaving"))
		return FALSE
	var/parchment = istype(sheet, /obj/item/weapon/paper/parchment)
	to_chat(user, SPAN_NOTICE("You start tracing the pattern pieces onto \the [sheet]."))
	if (!user.tailoring_trace_wait(source) || QDELETED(source) || !recipe_blank_paper(sheet) || sheet.loc != user)
		return FALSE
	if (!user.transfer_held_item_to(sheet, get_turf(user)))
		return FALSE
	qdel(sheet)
	var/obj/item/sewing_pattern/P = new(get_turf(user))
	P.set_design(body_id, colors_text, design_name, maker, author, parchment, pieces_text)
	user.put_in_any_hand_if_possible(P)
	to_chat(user, SPAN_NOTICE("You finish \the [P]."))
	return P

/obj/item/sewing_pattern
	name = "sewing pattern"
	desc = "Pattern pieces traced on a sheet, with the colour of every piece noted. Use it on an uncut tailoring project to copy the design, or use a blank sheet on it to copy the pattern."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper_words"
	w_class = ITEM_SIZE_TINY
	flammable = TRUE
	var/design_body = null
	var/design_colors = null
	var/design_pieces = null
	var/design_name = null
	var/design_maker = null
	var/design_author = null

/obj/item/sewing_pattern/proc/set_design(body_id, colors_text, new_name, maker, author, parchment, pieces_text = null)
	design_body = body_id
	design_colors = colors_text
	design_pieces = pieces_text
	design_name = new_name
	design_maker = maker
	design_author = author
	if (parchment)
		color = "#e8d8b0"
	update_pattern_name()
	tailoring_register(src)

/obj/item/sewing_pattern/proc/update_pattern_name()
	var/list/body = tailoring_body(design_body)
	name = "sewing pattern ([design_name ? design_name : (body ? body["name"] : "blank")])"

/obj/item/sewing_pattern/after_load()
	..()
	tailoring_register(src)

/obj/item/sewing_pattern/Destroy()
	tailoring_named_items -= src
	return ..()

/obj/item/sewing_pattern/attackby(obj/item/W, mob/user)
	if (recipe_blank_paper(W))
		tailoring_trace_pattern(user, W, src, design_body, design_colors, design_name, design_maker, design_author, design_pieces)
		return
	return ..()

/obj/item/sewing_pattern/examine(mob/user)
	..()
	var/list/body = tailoring_body(design_body)
	if (!body)
		return
	tailoring_examine_credit(user, design_body, design_maker)
	to_chat(user, "Pieces: [tailoring_describe(design_body, design_colors, design_pieces)]. It needs [tailoring_design_cost(design_body, design_pieces)] fabric.")

/obj/item/sewing_pattern/attack_self(mob/user)
	examine(user)
	if (!user.ckey || !tailoring_design_valid(design_body, design_colors, design_pieces))
		return
	var/choice = WWinput(user, "Copy this pattern into your own pattern book? Your book keeps up to [TAILORING_BOOK_MAX] designs for every character you play here.", "Sewing pattern", "Close", list("Copy into pattern book", "Show design code", "Close"))
	if (choice == "Show design code")
		var/code = tailoring_design_code(design_body, design_colors, design_pieces, design_name)
		if (code)
			design_code_show(user, "Clothing design code", code, "Paste it in a tailoring project: Pattern book, Paste a design code.")
		return
	if (choice != "Copy into pattern book" || QDELETED(src) || loc != user)
		return
	tailoring_book_add_feedback(user, user.ckey, design_body, design_colors, design_pieces, design_name, design_maker, design_author)

// Pattern book: each account keeps up to TAILORING_BOOK_MAX designs that any
// of its characters on this server can load onto a project. Books live in the
// account's player save folder, which every region keeps separately.

// Account key -> list of saved designs, each list("body" = ..., "colors" = ..., ...).
var/global/list/tailoring_books = list()

/proc/tailoring_book_path(key)
	key = ckey(key)
	if (!key)
		return null
	return "[get_player_notes_file_dir()][copytext(key, 1, 2)]/[key]/tailoring_patterns.sav"

/proc/tailoring_book_entry(body_id, colors_text, pieces_text, design_name, maker, author)
	if (!tailoring_design_valid(body_id, colors_text, pieces_text))
		return null
	var/list/body = tailoring_body(body_id)
	if (!length(body["options"]))
		pieces_text = null
	return list("body" = body_id, "colors" = lowertext(colors_text), "pieces" = pieces_text, "name" = istext(design_name) ? tailoring_clean_name(html_decode(design_name)) : null, "maker" = istext(maker) ? copytext(maker, 1, MAX_NAME_LEN + 1) : null, "author" = istext(author) ? ckey(author) : null)

// The account's book, read once from disk; entries that no longer fit the
// catalogue are dropped.
/proc/tailoring_book(key)
	key = ckey(key)
	if (!key)
		return null
	if (tailoring_books[key])
		return tailoring_books[key]
	var/list/book = list()
	var/path = tailoring_book_path(key)
	if (fexists(path))
		var/savefile/S = new(path)
		var/list/saved
		S["designs"] >> saved
		if (islist(saved))
			for (var/list/E in saved)
				if (book.len >= TAILORING_BOOK_MAX)
					break
				if (!istype(E))
					continue
				var/list/entry = tailoring_book_entry(E["body"], E["colors"], E["pieces"], E["name"], E["maker"], E["author"])
				if (entry)
					book += list(entry)
	tailoring_books[key] = book
	return book

/proc/tailoring_book_write(key)
	key = ckey(key)
	var/list/book = tailoring_books[key]
	var/path = tailoring_book_path(key)
	if (!path || !islist(book))
		return FALSE
	if (fexists(path))
		fdel(path)
	var/savefile/S = new(path)
	S["designs"] << book
	return TRUE

/proc/tailoring_book_same(list/A, list/B)
	for (var/field in TAILORING_BOOK_FIELDS)
		if (A[field] != B[field])
			return FALSE
	return TRUE

// Adds a design; returns the entry, "full", "duplicate" or null when invalid.
/proc/tailoring_book_add(key, body_id, colors_text, pieces_text, design_name, maker, author)
	var/list/book = tailoring_book(key)
	var/list/entry = tailoring_book_entry(body_id, colors_text, pieces_text, design_name, maker, author)
	if (!book || !entry)
		return null
	for (var/list/E in book)
		if (tailoring_book_same(E, entry))
			return "duplicate"
	if (book.len >= TAILORING_BOOK_MAX)
		return "full"
	book += list(entry)
	tailoring_book_write(key)
	return entry

/proc/tailoring_book_add_feedback(mob/user, key, body_id, colors_text, pieces_text, design_name, maker, author)
	var/result = tailoring_book_add(key, body_id, colors_text, pieces_text, design_name, maker, author)
	if (result == "full")
		to_chat(user, SPAN_WARNING("Your pattern book is full. Remove a design from it first (use a tailoring project in hand and open Pattern book)."))
	else if (result == "duplicate")
		to_chat(user, SPAN_NOTICE("That design is already in your pattern book."))
	else if (islist(result))
		to_chat(user, SPAN_NOTICE("You note \"[tailoring_book_label(result)]\" in your pattern book."))
	else
		to_chat(user, SPAN_WARNING("There is no finished design to note down."))
	return islist(result)

/proc/tailoring_book_remove(key, list/entry)
	var/list/book = tailoring_book(key)
	if (!book || !(entry in book))
		return FALSE
	book -= list(entry)
	tailoring_book_write(key)
	return TRUE

/proc/tailoring_book_label(list/entry)
	var/list/body = tailoring_body(entry["body"])
	var/garment = body ? body["name"] : "garment"
	if (entry["name"] && !tailoring_name_blocked(entry["author"]))
		return "[entry["name"]] ([garment])"
	return garment

/obj/item/tailoring_project/proc/pattern_book_menu(mob/living/human/user, turf/site, datum/save_epoch)
	var/list/book = tailoring_book(user.ckey)
	if (!book)
		return
	var/list/menu = list()
	var/list/entries = list()
	for (var/i = 1, i <= book.len, i++)
		var/label = "[i]. [tailoring_book_label(book[i])]"
		menu += label
		entries[label] = book[i]
	menu += "Save this design"
	if (book.len)
		menu += "Remove a design"
	menu += "Copy a design code"
	menu += "Paste a design code"
	var/picked = WWinput(user, "Your pattern book holds [book.len] of [TAILORING_BOOK_MAX] designs, shared by every character you play here. Choose one to copy onto the project.", "Pattern book", null, menu)
	if (!actor_ready(user, site, save_epoch) || stage != 0 || !(picked in menu))
		return
	if (picked == "Save this design")
		tailoring_book_add_feedback(user, user.ckey, design_body, design_colors, design_pieces, design_name, design_maker, design_author)
		return
	if (picked == "Paste a design code")
		paste_design_code(user, site, save_epoch)
		return
	if (picked == "Copy a design code")
		var/list/code_menu = list()
		if (tailoring_design_valid(design_body, design_colors, design_pieces))
			code_menu["This design"] = list("body" = design_body, "colors" = design_colors, "pieces" = design_pieces, "name" = design_name)
		for (var/label in entries)
			code_menu[label] = entries[label]
		if (!code_menu.len)
			return
		var/list/code_labels = list()
		for (var/label in code_menu)
			code_labels += label
		var/chosen = WWinput(user, "Copy the design code of which design? Paste it into any tailoring project's pattern book to make it again.", "Pattern book", null, code_labels)
		if (!(chosen in code_menu))
			return
		var/list/E = code_menu[chosen]
		var/code = tailoring_design_code(E["body"], E["colors"], E["pieces"], E["name"])
		if (code)
			design_code_show(user, "Clothing design code", code, "Paste it in a tailoring project: Pattern book, Paste a design code.")
		return
	if (picked == "Remove a design")
		var/list/remove_menu = list()
		for (var/label in entries)
			remove_menu += label
		var/removed = WWinput(user, "Remove which design from your pattern book?", "Pattern book", null, remove_menu)
		if (actor_ready(user, site, save_epoch) && (removed in entries) && tailoring_book_remove(user.ckey, entries[removed]))
			to_chat(user, SPAN_NOTICE("You strike \"[tailoring_book_label(entries[removed])]\" from your pattern book."))
		return
	var/list/entry = entries[picked]
	load_design(user, entry["body"], entry["colors"], entry["pieces"], entry["name"], entry["maker"], entry["author"], "design")

// Design codes (design_codes.dm): C13CLOTH/1/<body>/<colours>/<pieces>/<name>.
// Colours are hex without "#" joined by ".", pieces are the 1-based variant
// number of every option, and the name has "_" for spaces; "-" is empty.
/proc/tailoring_design_code(body_id, colors_text, pieces_text, design_name)
	if (!tailoring_design_valid(body_id, colors_text, pieces_text))
		return null
	var/list/body = tailoring_body(body_id)
	var/list/colours = list()
	for (var/value in (istext(colors_text) && length(colors_text) ? splittext(colors_text, "|") : list()))
		colours += lowertext(copytext(value, 2))
	var/list/numbers = list()
	if (length(body["options"]) && istext(pieces_text) && length(pieces_text))
		var/list/options = body["options"]
		var/list/chosen = splittext(pieces_text, "|")
		for (var/i = 1, i <= chosen.len, i++)
			var/list/variants = options[options[i]]
			numbers += "[variants.Find(chosen[i])]"
	var/name_field = "-"
	if (istext(design_name) && length(design_name))
		name_field = replacetext(replacetext(html_decode(design_name), "/", ""), " ", "_")
		if (!length(name_field))
			name_field = "-"
	return "C13CLOTH/1/[body_id]/[colours.len ? jointext(colours, ".") : "-"]/[numbers.len ? jointext(numbers, ".") : "-"]/[name_field]"

// A clothing code -> list("body", "colors", "pieces", "name"), or null.
/proc/tailoring_parse_design_code(code)
	var/list/F = design_code_fields(code, "CLOTH")
	if (!F || F.len != 4)
		return null
	var/body_id = lowertext(F[1])
	var/list/body = tailoring_body(body_id)
	if (!body)
		return null
	var/list/colours = list()
	if (F[2] != "-")
		for (var/value in splittext(F[2], "."))
			var/hex = design_code_colour_in(value)
			if (!hex)
				return null
			colours += hex
	var/pieces_text = null
	if (F[3] != "-")
		var/list/options = body["options"]
		var/list/numbers = splittext(F[3], ".")
		if (numbers.len > length(options))
			return null
		var/list/values = list()
		for (var/i = 1, i <= numbers.len, i++)
			var/list/variants = options[options[i]]
			var/n = text2num(numbers[i])
			if (!isnum(n) || n != round(n) || n < 1 || n > variants.len)
				return null
			values += variants[n]
		pieces_text = jointext(values, "|")
	var/colors_text = colours.len ? jointext(colours, "|") : null
	if (!tailoring_design_valid(body_id, colors_text, pieces_text))
		return null
	var/design_name = F[4] == "-" ? null : tailoring_clean_name(replacetext(F[4], "_", " "))
	return list("body" = body_id, "colors" = colors_text, "pieces" = pieces_text, "name" = design_name)

/obj/item/tailoring_project/proc/paste_design_code(mob/living/human/user, turf/site, datum/save_epoch)
	var/code = design_code_ask(user, "Pattern book", "Paste the clothing design code (it starts with C13CLOTH/).")
	if (!code || !actor_ready(user, site, save_epoch) || stage != 0)
		return FALSE
	var/list/design = tailoring_parse_design_code(code)
	if (!design)
		to_chat(user, SPAN_WARNING(design_code_refusal(code, "CLOTH")))
		return FALSE
	var/design_name = tailoring_name_blocked(user.ckey) ? null : design["name"]
	if (!load_design(user, design["body"], design["colors"], design["pieces"], design_name, user.real_name, user.ckey, "design code"))
		return FALSE
	design_code_log(user, "clothing", "[src]", code)
	return TRUE

// Staff panel: every named design in the world, its designer and account.
/proc/tailoring_admin_allowed(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_MOD))

var/global/datum/tailoring_admin_panel/tailoring_admin = new

/datum/tailoring_admin_panel

/client/proc/admin_clothing_designs()
	set category = "Admin"
	set name = "Clothing Designs"
	set desc = "List player-named clothing designs, rename or clear them, and stop an account naming designs."
	if (!tailoring_admin_allowed(src))
		return
	tailoring_admin.open(src)

/datum/tailoring_admin_panel/proc/open(client/C)
	if (!tailoring_admin_allowed(C))
		return
	var/page = "<html><head><title>Clothing Designs</title></head><body style='font-family:Verdana;font-size:12px'>"
	page += "<h2>Named clothing designs</h2><table border='1' cellpadding='3' style='border-collapse:collapse'><tr><th>Name</th><th>Item</th><th>Designer</th><th>Account</th><th>Where</th><th></th></tr>"
	var/count = 0
	for (var/obj/item/I in tailoring_named_items)
		if (QDELETED(I) || !I.vars["design_name"])
			tailoring_named_items -= I
			continue
		count++
		var/author = I.vars["design_author"]
		var/turf/T = get_turf(I)
		var/holder = ismob(I.loc) ? "held by [I.loc]" : (T ? "[T.x],[T.y],[T.z]" : "nowhere")
		page += "<tr><td>[I.vars["design_name"]]</td><td>[I.type]</td><td>[html_encode("[I.vars["design_maker"]]")]</td><td>[author ? author : "-"]</td><td>[html_encode(holder)]</td>"
		page += "<td><a href='?src=\ref[src];tailoring=rename;item=\ref[I]'>Rename</a> <a href='?src=\ref[src];tailoring=clear;item=\ref[I]'>Clear name</a>"
		if (author)
			page += " <a href='?src=\ref[src];tailoring=block;key=[author]'>Stop naming</a>"
		page += "</td></tr>"
	page += "</table>[count ? "" : "<p>No named designs exist right now.</p>"]"
	var/list/blocks = tailoring_name_blocks()
	page += "<h3>Accounts that can't name designs</h3>"
	if (!blocks.len)
		page += "<p>None.</p>"
	for (var/key in blocks)
		page += "<div>[key] <a href='?src=\ref[src];tailoring=unblock;key=[key]'>Allow again</a></div>"
	page += "</body></html>"
	show_browse(C, page, "window=tailoring_designs;size=820x520")

/datum/tailoring_admin_panel/Topic(href, href_list)
	var/client/C = usr ? usr.client : null
	if (!tailoring_admin_allowed(C))
		return
	var/obj/item/I = href_list["item"] ? locate(href_list["item"]) : null
	if (I && !(I in tailoring_named_items))
		I = null
	switch (href_list["tailoring"])
		if ("rename")
			if (!I)
				return
			var/typed = WWinput(C, "New name for this design:", "Rename design", html_decode(I.vars["design_name"]), "text")
			var/clean = tailoring_clean_name("[typed]")
			if (!clean || QDELETED(I))
				return
			log_admin("[key_name(C)] renamed the clothing design \"[I.vars["design_name"]]\" by [I.vars["design_author"]] to \"[clean]\".")
			message_admins("[key_name_admin(C)] renamed the clothing design \"[I.vars["design_name"]]\" to \"[clean]\".")
			tailoring_apply_name(I, clean)
		if ("clear")
			if (!I)
				return
			log_admin("[key_name(C)] cleared the clothing design name \"[I.vars["design_name"]]\" by [I.vars["design_author"]].")
			message_admins("[key_name_admin(C)] cleared the clothing design name \"[I.vars["design_name"]]\".")
			tailoring_apply_name(I, null)
		if ("block", "unblock")
			var/key = ckey(href_list["key"])
			if (!key)
				return
			var/blocked = href_list["tailoring"] == "block"
			tailoring_set_name_block(key, blocked)
			log_admin("[key_name(C)] [blocked ? "stopped" : "allowed"] [key] [blocked ? "from naming" : "to name"] clothing designs.")
			message_admins("[key_name_admin(C)] [blocked ? "stopped" : "allowed"] [key] [blocked ? "from naming" : "to name"] clothing designs.")
	open(C)

/proc/tailoring_apply_name(obj/item/I, new_name)
	I.vars["design_name"] = new_name
	if (istype(I, /obj/item/clothing))
		var/obj/item/clothing/C = I
		C.tailoring_refresh()
	else if (istype(I, /obj/item/sewing_pattern))
		var/obj/item/sewing_pattern/P = I
		P.update_pattern_name()
	if (new_name)
		tailoring_register(I)
	else
		tailoring_named_items -= I

#undef TAILORING_NAME_MAX
#undef TAILORING_TRACE_TIME
#undef TAILORING_BOOK_MAX
#undef TAILORING_BOOK_FIELDS
#undef TAILORING_BLOCK_FILE

#undef TAILORING_ANY_DYE_NODE
#undef TAILORING_WOVEN
#undef TAILORING_MAX_FABRIC
#undef TAILORING_MAX_COLOURS
