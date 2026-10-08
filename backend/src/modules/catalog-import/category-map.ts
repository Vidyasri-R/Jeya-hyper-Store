/**
 * Website categories for the GoFrugal stock file, and the rules that place each POS "TYPE"
 * (494 inconsistent sub-groups) into one of them. Vague TYPEs (GROCERY, FOOD PRODUCT, "Nill"…)
 * fall back to the product name. Admin → Upload stock file can override any TYPE (typeMap).
 */

export type WebCategory = { key: string; name: string; parent: string | null };

export const WEB_CATEGORIES: WebCategory[] = [
  { key: 'staples', name: 'Staples', parent: null },
  { key: 'rice', name: 'Rice & Rice Products', parent: 'staples' },
  { key: 'atta', name: 'Atta, Flours & Rava', parent: 'staples' },
  { key: 'dals', name: 'Dals & Pulses', parent: 'staples' },
  { key: 'oils', name: 'Oils & Ghee', parent: 'staples' },
  { key: 'masalas', name: 'Masalas & Spices', parent: 'staples' },
  { key: 'salt_sugar', name: 'Salt, Sugar & Jaggery', parent: 'staples' },
  { key: 'dry_fruits', name: 'Dry Fruits & Nuts', parent: 'staples' },

  { key: 'snacks', name: 'Snacks & Sweets', parent: null },
  { key: 'biscuits', name: 'Biscuits & Cookies', parent: 'snacks' },
  { key: 'chips', name: 'Chips & Namkeen', parent: 'snacks' },
  { key: 'chocolates', name: 'Chocolates & Candy', parent: 'snacks' },
  { key: 'sweets', name: 'Sweets & Mittai', parent: 'snacks' },

  { key: 'instant', name: 'Instant & Ready Food', parent: null },
  { key: 'noodles', name: 'Noodles, Pasta & Soups', parent: 'instant' },
  { key: 'ready_mix', name: 'Ready Mixes', parent: 'instant' },
  { key: 'sauces', name: 'Sauces, Pickles & Spreads', parent: 'instant' },
  { key: 'breakfast', name: 'Breakfast & Health Foods', parent: 'instant' },
  { key: 'papad', name: 'Appalam & Papad', parent: 'instant' },

  { key: 'beverages', name: 'Tea, Coffee & Beverages', parent: null },
  { key: 'tea_coffee', name: 'Tea & Coffee', parent: 'beverages' },
  { key: 'health_drinks', name: 'Health Drinks & Mixes', parent: 'beverages' },
  { key: 'juices', name: 'Juices & Soft Drinks', parent: 'beverages' },

  { key: 'dairy', name: 'Dairy, Bread & Eggs', parent: null },
  { key: 'milk_dairy', name: 'Milk, Curd & Paneer', parent: 'dairy' },
  { key: 'bakery', name: 'Bread & Cakes', parent: 'dairy' },
  { key: 'ice_cream', name: 'Ice Creams', parent: 'dairy' },

  { key: 'personal', name: 'Personal Care', parent: null },
  { key: 'hair', name: 'Hair Care', parent: 'personal' },
  { key: 'skin', name: 'Skin, Face & Cosmetics', parent: 'personal' },
  { key: 'bath', name: 'Bath & Hand Wash', parent: 'personal' },
  { key: 'oral', name: 'Oral Care', parent: 'personal' },
  { key: 'shaving', name: 'Shaving & Grooming', parent: 'personal' },
  { key: 'deo', name: 'Deos & Perfumes', parent: 'personal' },
  { key: 'feminine', name: 'Feminine Care', parent: 'personal' },
  { key: 'wellness', name: 'Health & Wellness', parent: 'personal' },

  { key: 'household', name: 'Household Care', parent: null },
  { key: 'laundry', name: 'Detergents & Laundry', parent: 'household' },
  { key: 'dishwash', name: 'Dishwash', parent: 'household' },
  { key: 'cleaners', name: 'Cleaners', parent: 'household' },
  { key: 'fresheners', name: 'Fresheners & Repellents', parent: 'household' },
  { key: 'home_needs', name: 'Home & Kitchen Needs', parent: 'household' },

  { key: 'pooja', name: 'Pooja Needs', parent: null },
  { key: 'baby', name: 'Baby Care', parent: null },
  { key: 'pet', name: 'Pet Care', parent: null },
  { key: 'stationery', name: 'Stationery', parent: null },
  { key: 'other', name: 'More Items', parent: null },
];

export const WEB_CATEGORY_KEYS = new Set(WEB_CATEGORIES.map((c) => c.key));

/** Ordered: the first match wins, so specific rules (HAIR OIL) come before general ones (OIL). */
const TYPE_RULES: [string, RegExp][] = [
  ['baby', /BABY|DIAPER|JOHNSON|^PANTS$/],
  ['pet', /PET|^DRY FOOD$|^WET FOOD$/],
  ['pooja', /POOJA|AGARBATTI|CAMPHOR|SAMBIRANI|CANDLE/],
  ['stationery', /STATION|^PEN|PENCIL|NOTE|ERASER|SHARPNER|MARKER|CRAYON|CHALK|GLUE|^INK$|STAPLER|^SCALE$|COPIER|^PAPER$|POSTER|WATER COLOUR|PAINT/],
  ['hair', /HAIR|SHAMPOO|CONDITIONER|^DYE$|HENNA|SHIKKAKAI|^COMB$|LOREAL/],
  ['oral', /TOOTH|ORAL|MOUTH/],
  ['shaving', /SHAV|RAZOR|GILLETTE|GROOMING|AFTER SAVE/],
  ['feminine', /NAPKIN|^PAD$|FEMI/],
  ['wellness', /PAIN|BALM|^OTC$|AYURVEDIC|ANTISEPTIC|ANTIDOTE|INHALER|PLASTER|OILMENT|HERBAL POWDER/],
  ['deo', /DEO|PERFUME|ATTAR|BODY SPRAY/],
  ['laundry', /WASHING|DETERGENT|LAUNDRY|FABRIC|STEAM PODS|LIQUID WASH/],
  ['dishwash', /DISH|DISWASH|SCRUBBER/],
  ['fresheners', /FRESH|^MOS|MOSQUITO|REPELLENT|COCKROACH|PESTICIDE|^CAR /],
  ['cleaners', /CLEAN|PHENYIL|FLUSH|POLISH|^BRUSH|TOILET|FLOOR/],
  ['bath', /SOAP|BODY WASH|SHOWER|HAND WASH|SANITIZER|WIPE|TISSUE|COTTON|EAR BUDS/],
  ['skin', /FACE|SKIN|CREAM$|LOTION|MOISTUR|FAIRNESS|SERUM|SCRUB$|^SUN$|LIP|FOUNDATION|KAJAL|EYE|NAIL|COSMETIC|BEAUTY|WAX|REMOVER|FACIAL|TALC|BANJARAS/],
  ['home_needs', /BROOM|^MOP$|BATTERY|MATCH BOX|GARBAGE|ALUMINUM|CONTAINER|KITCHEN|KNIFE|FLASK|BOTTLE|PLASTIC|^LIGHT$|LED |CLOCK|CLOTH DRYER|HOT POT|SCISSORS|CLIPS|HOME NEEDS|REFILL/],
  ['ready_mix', /ICE CREAM MIX|READY|INSTANT FOOD|INSTANT PASTE|PREMIX|BATTER|DESSERT|ESSENCE|FOOD COLOUR/],
  ['ice_cream', /ICE ?CREAMS?$/],
  ['rice', /RICE|AVAL/],
  ['atta', /ATTA|FLOUR|MAIDA|RAVA|MILLET|RAGI|SEMIYA|VERMICELLI|BROKEN WHEAT/],
  ['dals', /DAL|PULSE|GRAM|^SEEDS$/],
  ['salt_sugar', /SALT|SUGAR|JAGG/],
  ['masalas', /MASALA|SPICE|ASAFOETIDA|PERUNGAYAM|TURMERIC|KASURI|TAMARIND|SAFFRON|SAMBAR/],
  ['oils', /^OIL$|COOKING OIL|SUNFLOWER|GHEE/],
  ['dry_fruits', /DRY ?FRUIT|^DATES$|^NUTS$/],
  ['biscuits', /BISCUIT|COOKIE|RUSK|WAFER/],
  ['chips', /CHIPS|SNACK|SNAKES|MURUKKU|SAVOUR|POP ?CORN/],
  ['chocolates', /CHOCO|CANDY|GUM|CONFIC|CHILLERS/],
  ['sweets', /SWEET|MITTAI|SOAN|GULAB|JELLY/],
  ['noodles', /NOODLE|PASTA|PAZZTA|MACARONI|SOUP/],
  ['sauces', /SAUCE|KETCHUP|PICKLE|CHUTNEY|^JAM$|SPREAD|MAYO|VINEGAR|HONEY|PEANUT BUTTER/],
  ['breakfast', /OATS|CEREAL|CORN FLAKES|BREAKFAST|HEALTH MIX|HEALTH FOOD|NUTRITION|SUPPLEMENT|GLUCOSE/],
  ['papad', /APPALAM|PAPPAD|PAPAD/],
  ['tea_coffee', /TEA|COFFEE|COCOA/],
  ['health_drinks', /HEALTH ?DRINK|BOURNVITA|MILK SHAKE|INSTANT DRINK|RASNA|SYRUP|ENERG/],
  ['juices', /JUICE|COOL ?DRINK|BEVERAGE|^WATER$|^POP$/],
  ['milk_dairy', /MILK|CURD|PANEER|^BUTTER$|CHEESE|YOGURT|LASSI|^EGG$|WHITNER/],
  ['bakery', /BREAD|CAKE/],
  ['dryfish', /DRYFISH/],
];

/** TYPEs that say nothing useful: classify these by the product name instead. */
const VAGUE_TYPES = new Set(['', '0', 'X', 'NIL', 'NILL', 'GROCERY', 'FOOD PRODUCT', 'HERBAL', 'POWDER', 'LIQUID', 'SUPERMARKET', 'FANCY', 'FANCY ITEMS', 'FREE GIFT', 'OIL', 'CREAM', 'SPRAY', 'GEL', 'P&G', 'NESTLE', 'MTR', 'AMUL FOODS', 'PERSONAL CARE', 'GENERAL ITEMS', 'CLEANER', 'BRUSHES', 'HOME NEEDS']);

const NAME_RULES: [string, RegExp][] = [
  ['baby', /\bBABY\b|DIAPER|\bPAMPERS\b|HUGGIES/],
  ['pet', /PEDIGREE|WHISKAS|DROOLS|\bDOG\b|\bCAT FOOD/],
  ['hair', /HAIR ?OIL|SHAMPOO|CONDITIONER|HAIR|HENNA|\bDYE\b/],
  ['oral', /TOOTH|PASTE\b.*(COLGATE|CLOSE)|COLGATE|PEPSODENT|SENSODYNE|MOUTH ?WASH/],
  ['pooja', /AGARBATT|CAMPHOR|KARPOORAM|SAMBRANI|SAMBIRANI|KUMKUM|VIBHUTHI|THIRUNEER|POOJA|DEEPAM|VILAKKU|GINGELLY OIL.*LAMP/],
  ['bath', /\bSOAP\b|HAND ?WASH|BODY ?WASH|SANITI[SZ]ER/],
  ['skin', /\bFACE\b|CREAM|LOTION|POWDER.*(TALC|PONDS|COOL)|TALC|LIP|KAJAL/],
  ['wellness', /BALM|IODEX|AMRUTANJAN|VICKS|\bPAIN\b|CHOORNAM|LEHYAM|KASHAYAM/],
  ['laundry', /DETERGENT|WASHING|SURF|RIN\b|TIDE\b|ARIEL|COMFORT/],
  ['dishwash', /\bVIM\b|DISH|EXO\b/],
  ['cleaners', /PHENYL|HARPIC|LIZOL|COLIN|CLEANER/],
  ['rice', /\bRICE\b|\bAVAL\b|POHA|IDLI RICE|PONNI|SONA ?MASOORI|BASMATI/],
  ['dals', /PARUPPU|\bDAL+\b|GRAM|PAYIRU|PATTANI|RAJMA|CHANNA|CHANA|KADALAI|MOONG|URAD|TOOR/],
  ['atta', /\bATTA\b|MAIDA|\bRAVA\b|SOOJI|FLOUR|\bMAVU\b|SEMIYA|VERMICELLI|RAGI|MILLET|JAVVARISI|SAGO/],
  ['oils', /\bGHEE\b|\bOIL\b|ENNAI|ENNEI/],
  ['salt_sugar', /\bSALT\b|SUGAR|JAGGERY|VELLAM|KARKANDU|KALKANDU|NATTU SAKKARAI/],
  ['masalas', /MASALA|CHILLI|MILAGU|PEPPER|JEERAGAM|JEERA|SOMBU|KADUGU|MUSTARD|METHI|VENTHAYAM|TURMERIC|MANJAL|CORIANDER|MALLI|PERUNGAYAM|HING|CARDAMOM|ELAKKAI|CLOVE|CINNAMON|PATTAI|SUKKU|GINGER|TAMARIND|PULI|POWDER|SAMBAR|RASAM/],
  ['dry_fruits', /CASHEW|BADAM|ALMOND|KISMIS|RAISIN|PISTA|DATES|WALNUT|DRY ?FRUIT|NUTS?\b/],
  ['tea_coffee', /\bTEA\b|COFFEE|\bBRU\b|NESCAFE/],
  ['biscuits', /BISCUIT|COOKIE|\bBIKIS\b|MARIE|RUSK|WAFER/],
  ['chips', /CHIPS|MURUKKU|MIXTURE|NAMKEEN|SEV\b|THATTAI|PAKODA|KARA|BHUJIA/],
  ['chocolates', /CHOCO|DAIRY MILK|KITKAT|\bGUM\b|CANDY|LOLLI|TOFFEE/],
  ['sweets', /SWEET|MITTAI|LADDU|LADOO|MYSORE PAK|HALWA|ADHIRASAM|JAMUN/],
  ['noodles', /NOODLE|PASTA|MACARONI|MAGGI|YIPPEE|SOUP/],
  ['ready_mix', /\bMIX\b|BATTER|INSTANT|READY|YEAST|ESSENCE|BAKING|CUSTARD|JELLY/],
  ['sauces', /SAUCE|KETCHUP|PICKLE|THOKKU|CHUTNEY|\bJAM\b|HONEY|VINEGAR|MAYO/],
  ['papad', /APPALAM|PAPAD|VADAM|VATHAL/],
  ['milk_dairy', /\bMILK\b|CURD|PANEER|BUTTER|CHEESE|\bGHEE\b|EGG/],
  ['juices', /JUICE|DRINK|\bWATER\b|SODA|COLA/],
  ['home_needs', /BUCKET|\bMUG\b|BROOM|\bMOP\b|BATTERY|MATCH|FOIL|BOTTLE|CONTAINER|\bTIN\b|BOX\b/],
];

/** Name rules match from a word start ("METHI" must not match inside "SOMETHING"). */
const NAME_WORD_RULES: [string, RegExp][] = NAME_RULES.map(([key, re]) => [key, new RegExp(`\\b(?:${re.source})`)]);

export type CategoryKey = string;

/** The website category for a POS TYPE (+ product name for vague TYPEs). Overrides win. */
/** Ice-cream makers: GoFrugal files their items under groups like "CREAM", which read as cosmetics. */
const ICE_CREAM_BRANDS = /^(ARUN|ARUN ICE ?CREAMS?|DAIRY ?DAY|KWALITY( WALLS?)?|IBACO|HAVMOR|VADILAL|CREAM BELL|BASKIN.*)$/;

export function classify(type: string, name: string, overrides: Record<string, string> = {}, brand: string | null = null): CategoryKey {
  const t = type.trim().toUpperCase();
  const override = overrides[t];
  if (override && WEB_CATEGORY_KEYS.has(override)) return override;
  const key = classifyByRules(t, name.toUpperCase());
  if ((key === 'skin' || key === 'other') && brand && ICE_CREAM_BRANDS.test(brand.trim().toUpperCase())) return 'ice_cream';
  return key;
}

function classifyByRules(t: string, n: string): CategoryKey {
  if (!VAGUE_TYPES.has(t)) {
    for (const [key, re] of TYPE_RULES) if (re.test(t)) return key === 'dryfish' ? 'other' : key;
  }
  for (const [key, re] of NAME_WORD_RULES) if (re.test(n)) return key;
  return 'other';
}
