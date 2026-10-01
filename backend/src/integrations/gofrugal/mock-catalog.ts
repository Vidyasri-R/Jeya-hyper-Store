/**
 * Deterministic sample catalogue for development until GoFrugal API access is live.
 * Every id is prefixed MOCK- so `npm run catalog:purge-mock` can remove it all before launch.
 */

type Unit = 'NOS' | 'KG' | 'GMS' | 'LTR' | 'ML' | 'PKT';
/** [display name, brand | null, packs: [pack label, MRP, discount %][], POS unit, weighable?] */
type Template = [string, string | null, [string, number, number][], Unit, boolean?];

type CategoryFixture = { id: string; name: string; parent: string | null; hsn: string; gst: number; items: Template[] };

const C: CategoryFixture[] = [
  // ── Staples ──
  { id: 'MOCK-C-STAPLES', name: 'Staples', parent: null, hsn: '', gst: 0, items: [] },
  {
    id: 'MOCK-C-RICE',
    name: 'Rice & Rice Products',
    parent: 'MOCK-C-STAPLES',
    hsn: '1006',
    gst: 5,
    items: [
      ['Ponni Raw Rice', 'Jeya Select', [['1 kg', 72, 8], ['5 kg', 350, 10], ['10 kg', 690, 12]], 'NOS'],
      ['Ponni Boiled Rice', 'Jeya Select', [['1 kg', 68, 7], ['5 kg', 330, 9], ['25 kg', 1600, 12]], 'NOS'],
      ['Seeraga Samba Rice', 'Jeya Select', [['1 kg', 140, 10], ['5 kg', 680, 12]], 'NOS'],
      ['Basmati Rice Classic', 'India Gate', [['1 kg', 210, 15], ['5 kg', 999, 18]], 'NOS'],
      ['Idli Rice', 'Jeya Select', [['1 kg', 58, 5], ['5 kg', 280, 7]], 'NOS'],
      ['Brown Rice', 'Daawat', [['1 kg', 165, 10]], 'NOS'],
      ['Rice Flakes (Aval) Thick', 'Jeya Select', [['500 g', 45, 5]], 'NOS'],
      ['Loose Raw Rice (Sona Masoori)', null, [['per kg', 62, 0]], 'KG', true],
    ],
  },
  {
    id: 'MOCK-C-ATTA',
    name: 'Atta, Flours & Sooji',
    parent: 'MOCK-C-STAPLES',
    hsn: '1101',
    gst: 5,
    items: [
      ['Shudh Chakki Atta', 'Aashirvaad', [['1 kg', 72, 5], ['5 kg', 310, 8], ['10 kg', 590, 10]], 'NOS'],
      ['Maida', 'Aachi', [['500 g', 32, 0], ['1 kg', 58, 5]], 'NOS'],
      ['Rava (Sooji)', 'Aachi', [['500 g', 38, 5], ['1 kg', 72, 6]], 'NOS'],
      ['Ragi Flour', 'Aachi', [['500 g', 48, 5]], 'NOS'],
      ['Besan (Kadalai Maavu)', 'Aachi', [['500 g', 70, 8]], 'NOS'],
      ['Rice Flour', 'Anil', [['1 kg', 64, 6]], 'NOS'],
      ['Idiyappam Flour', 'Anil', [['1 kg', 85, 5]], 'NOS'],
    ],
  },
  {
    id: 'MOCK-C-DAL',
    name: 'Dals & Pulses',
    parent: 'MOCK-C-STAPLES',
    hsn: '0713',
    gst: 0,
    items: [
      ['Toor Dal', 'Jeya Select', [['500 g', 95, 5], ['1 kg', 180, 8]], 'NOS'],
      ['Urad Dal Whole', 'Jeya Select', [['500 g', 82, 5], ['1 kg', 160, 6]], 'NOS'],
      ['Moong Dal', 'Jeya Select', [['500 g', 78, 5]], 'NOS'],
      ['Chana Dal', 'Jeya Select', [['500 g', 58, 4], ['1 kg', 112, 6]], 'NOS'],
      ['Roasted Gram (Pottukadalai)', 'Jeya Select', [['500 g', 70, 5]], 'NOS'],
      ['Kabuli Chana', 'Jeya Select', [['500 g', 85, 6]], 'NOS'],
      ['Green Gram Whole', 'Jeya Select', [['500 g', 72, 5]], 'NOS'],
      ['Loose Toor Dal', null, [['per kg', 165, 0]], 'KG', true],
    ],
  },
  {
    id: 'MOCK-C-OIL',
    name: 'Oils & Ghee',
    parent: 'MOCK-C-STAPLES',
    hsn: '1508',
    gst: 5,
    items: [
      ['Refined Sunflower Oil', 'Gold Winner', [['1 L', 175, 10], ['5 L', 830, 12]], 'NOS'],
      ['Groundnut Oil', 'Idhayam', [['1 L', 230, 8], ['5 L', 1120, 10]], 'NOS'],
      ['Gingelly Oil (Nallennai)', 'Idhayam', [['500 ml', 190, 6], ['1 L', 370, 8]], 'NOS'],
      ['Coconut Oil', 'Parachute', [['500 ml', 140, 5], ['1 L', 270, 7]], 'NOS'],
      ['Cow Ghee', 'Aavin', [['200 ml', 165, 0], ['500 ml', 380, 0], ['1 L', 720, 0]], 'NOS'],
      ['Rice Bran Oil', 'Fortune', [['1 L', 165, 9]], 'NOS'],
    ],
  },
  {
    id: 'MOCK-C-MASALA',
    name: 'Masalas & Spices',
    parent: 'MOCK-C-STAPLES',
    hsn: '0910',
    gst: 5,
    items: [
      ['Sambar Powder', 'Aachi', [['100 g', 40, 5], ['200 g', 76, 6]], 'NOS'],
      ['Chilli Powder', 'Aachi', [['100 g', 38, 5], ['250 g', 88, 6]], 'NOS'],
      ['Turmeric Powder', 'Sakthi', [['100 g', 30, 5], ['200 g', 56, 6]], 'NOS'],
      ['Coriander Powder', 'Sakthi', [['100 g', 28, 5]], 'NOS'],
      ['Chicken 65 Masala', 'Aachi', [['50 g', 30, 0], ['100 g', 55, 5]], 'NOS'],
      ['Rasam Powder', 'Sakthi', [['100 g', 38, 5]], 'NOS'],
      ['Garam Masala', 'Everest', [['50 g', 52, 5]], 'NOS'],
      ['Black Pepper Whole', 'Jeya Select', [['100 g', 95, 8]], 'NOS'],
      ['Cumin Seeds (Jeeragam)', 'Jeya Select', [['100 g', 62, 6]], 'NOS'],
      ['Mustard Seeds (Kadugu)', 'Jeya Select', [['100 g', 22, 5]], 'NOS'],
    ],
  },
  {
    id: 'MOCK-C-SALT',
    name: 'Salt, Sugar & Jaggery',
    parent: 'MOCK-C-STAPLES',
    hsn: '1701',
    gst: 5,
    items: [
      ['Iodised Salt', 'Tata', [['1 kg', 28, 0]], 'NOS'],
      ['Crystal Salt', 'Jeya Select', [['1 kg', 18, 0]], 'NOS'],
      ['Sugar', 'Jeya Select', [['1 kg', 48, 4], ['5 kg', 235, 6]], 'NOS'],
      ['Palm Jaggery (Karupatti)', 'Jeya Select', [['500 g', 160, 8]], 'NOS'],
      ['Jaggery Powder', 'Jeya Select', [['500 g', 75, 5]], 'NOS'],
      ['Loose Sugar', null, [['per kg', 46, 0]], 'KG', true],
    ],
  },

  // ── Fresh ──
  { id: 'MOCK-C-FRESH', name: 'Fruits & Vegetables', parent: null, hsn: '', gst: 0, items: [] },
  {
    id: 'MOCK-C-VEG',
    name: 'Fresh Vegetables',
    parent: 'MOCK-C-FRESH',
    hsn: '0709',
    gst: 0,
    items: [
      ['Tomato', null, [['per kg', 32, 0]], 'KG', true],
      ['Onion (Big)', null, [['per kg', 42, 0]], 'KG', true],
      ['Small Onion (Shallots)', null, [['per kg', 78, 0]], 'KG', true],
      ['Potato', null, [['per kg', 38, 0]], 'KG', true],
      ['Carrot (Ooty)', null, [['per kg', 64, 0]], 'KG', true],
      ['Beans', null, [['per kg', 70, 0]], 'KG', true],
      ['Brinjal', null, [['per kg', 48, 0]], 'KG', true],
      ['Ladies Finger (Vendakkai)', null, [['per kg', 56, 0]], 'KG', true],
      ['Drumstick', null, [['per kg', 90, 0]], 'KG', true],
      ['Green Chilli', null, [['per kg', 80, 0]], 'KG', true],
      ['Curry Leaves', null, [['1 bunch', 10, 0]], 'NOS'],
      ['Coriander Leaves', null, [['1 bunch', 15, 0]], 'NOS'],
      ['Ginger', null, [['per kg', 120, 0]], 'KG', true],
      ['Garlic', null, [['per kg', 180, 0]], 'KG', true],
    ],
  },
  {
    id: 'MOCK-C-FRUIT',
    name: 'Fresh Fruits',
    parent: 'MOCK-C-FRESH',
    hsn: '0803',
    gst: 0,
    items: [
      ['Banana (Poovan)', null, [['per dozen', 60, 0]], 'NOS'],
      ['Banana (Nendran)', null, [['per kg', 72, 0]], 'KG', true],
      ['Apple (Shimla)', null, [['per kg', 180, 0]], 'KG', true],
      ['Orange (Nagpur)', null, [['per kg', 110, 0]], 'KG', true],
      ['Pomegranate', null, [['per kg', 200, 0]], 'KG', true],
      ['Papaya', null, [['per kg', 45, 0]], 'KG', true],
      ['Watermelon', null, [['per kg', 28, 0]], 'KG', true],
      ['Sweet Lime (Mosambi)', null, [['per kg', 85, 0]], 'KG', true],
    ],
  },

  // ── Dairy & Bakery ──
  {
    id: 'MOCK-C-DAIRY',
    name: 'Dairy, Bread & Eggs',
    parent: null,
    hsn: '0401',
    gst: 0,
    items: [
      ['Toned Milk (Blue)', 'Aavin', [['500 ml', 24, 0]], 'NOS'],
      ['Full Cream Milk (Orange)', 'Aavin', [['500 ml', 32, 0]], 'NOS'],
      ['Curd', 'Aavin', [['500 g', 35, 0], ['1 kg', 65, 0]], 'NOS'],
      ['Paneer', 'Milky Mist', [['200 g', 95, 5]], 'NOS'],
      ['Butter Salted', 'Amul', [['100 g', 60, 0], ['500 g', 285, 0]], 'NOS'],
      ['Cheese Slices', 'Amul', [['200 g', 145, 5]], 'NOS'],
      ['Farm Eggs', null, [['6 pcs', 42, 0], ['30 pcs', 195, 5]], 'NOS'],
      ['Milk Bread', 'Britannia', [['400 g', 50, 0]], 'NOS'],
      ['Brown Bread', 'Modern', [['400 g', 55, 0]], 'NOS'],
    ],
  },

  // ── Snacks & Beverages ──
  {
    id: 'MOCK-C-SNACKS',
    name: 'Snacks & Biscuits',
    parent: null,
    hsn: '1905',
    gst: 18,
    items: [
      ['Good Day Cashew Cookies', 'Britannia', [['200 g', 40, 5]], 'NOS'],
      ['Marie Gold', 'Britannia', [['250 g', 35, 5]], 'NOS'],
      ['Parle-G Gold', 'Parle', [['1 kg', 140, 8]], 'NOS'],
      ['Bourbon', 'Britannia', [['150 g', 35, 0]], 'NOS'],
      ['Mixture (Madras)', 'Grand Sweets', [['200 g', 80, 0]], 'NOS'],
      ['Murukku', 'Grand Sweets', [['200 g', 90, 0]], 'NOS'],
      ['Potato Chips Classic Salted', "Lay's", [['52 g', 20, 0], ['90 g', 40, 0]], 'NOS'],
      ['Kurkure Masala Munch', 'Kurkure', [['90 g', 20, 0]], 'NOS'],
      ['Instant Noodles Masala', 'Maggi', [['70 g', 14, 0], ['280 g (4 pack)', 56, 5]], 'NOS'],
      ['Dark Fantasy Choco Fills', 'Sunfeast', [['75 g', 40, 0]], 'NOS'],
    ],
  },
  {
    id: 'MOCK-C-BEV',
    name: 'Tea, Coffee & Beverages',
    parent: null,
    hsn: '0902',
    gst: 5,
    items: [
      ['Filter Coffee Powder', 'Narasus', [['200 g', 160, 5], ['500 g', 390, 8]], 'NOS'],
      ['Instant Coffee', 'Bru', [['100 g', 285, 10]], 'NOS'],
      ['Classic Instant Coffee', 'Nescafe', [['50 g', 190, 5]], 'NOS'],
      ['Tea Powder', '3 Roses', [['250 g', 135, 6], ['500 g', 265, 8]], 'NOS'],
      ['Premium Tea', 'Tata Tea Gold', [['250 g', 160, 7]], 'NOS'],
      ['Health Drink', 'Horlicks', [['500 g', 285, 8]], 'NOS'],
      ['Boost', 'Boost', [['450 g', 260, 6]], 'NOS'],
      ['Soft Drink', 'Coca-Cola', [['750 ml', 40, 0], ['2.25 L', 99, 5]], 'NOS'],
      ['Packaged Drinking Water', 'Bisleri', [['1 L', 20, 0], ['20 L can', 90, 0]], 'NOS'],
    ],
  },

  // ── Home & Personal care ──
  {
    id: 'MOCK-C-HOME',
    name: 'Household Care',
    parent: null,
    hsn: '3402',
    gst: 18,
    items: [
      ['Detergent Powder', 'Surf Excel', [['1 kg', 140, 10], ['3 kg', 400, 12]], 'NOS'],
      ['Detergent Bar', 'Rin', [['250 g', 28, 0]], 'NOS'],
      ['Dishwash Bar', 'Vim', [['300 g', 30, 0]], 'NOS'],
      ['Dishwash Liquid', 'Vim', [['500 ml', 115, 10]], 'NOS'],
      ['Floor Cleaner', 'Lizol', [['975 ml', 199, 12]], 'NOS'],
      ['Toilet Cleaner', 'Harpic', [['500 ml', 98, 8]], 'NOS'],
      ['Mosquito Repellent Refill', 'Good Knight', [['45 ml', 85, 5]], 'NOS'],
      ['Agarbatti', 'Cycle', [['100 g', 70, 0]], 'NOS'],
      ['Camphor', 'Jeya Select', [['50 g', 75, 0]], 'NOS'],
    ],
  },
  {
    id: 'MOCK-C-PERSONAL',
    name: 'Personal Care',
    parent: null,
    hsn: '3401',
    gst: 18,
    items: [
      ['Toothpaste Strong Teeth', 'Colgate', [['100 g', 58, 5], ['200 g', 110, 8]], 'NOS'],
      ['Herbal Toothpaste', 'Dabur Red', [['100 g', 62, 5]], 'NOS'],
      ['Bath Soap', 'Lux', [['4 x 100 g', 160, 10]], 'NOS'],
      ['Sandal Soap', 'Mysore Sandal', [['125 g', 75, 0]], 'NOS'],
      ['Shampoo', 'Clinic Plus', [['175 ml', 120, 8]], 'NOS'],
      ['Coconut Hair Oil', 'Parachute', [['200 ml', 105, 5]], 'NOS'],
      ['Neem Face Wash', 'Himalaya', [['100 ml', 155, 10]], 'NOS'],
      ['Talcum Powder', "Pond's", [['100 g', 90, 5]], 'NOS'],
      ['Sanitary Pads XL', 'Whisper', [['15 pads', 190, 8]], 'NOS'],
    ],
  },
  {
    id: 'MOCK-C-BABY',
    name: 'Baby Care',
    parent: null,
    hsn: '9619',
    gst: 12,
    items: [
      ['Baby Diapers Medium', 'Pampers', [['20 pcs', 399, 15]], 'NOS'],
      ['Baby Wipes', 'Himalaya', [['72 pcs', 199, 10]], 'NOS'],
      ['Cerelac Wheat Apple', 'Nestle', [['300 g', 285, 0]], 'NOS'],
      ['Baby Soap', 'Johnson\'s', [['75 g', 70, 5]], 'NOS'],
    ],
  },
];

export const MOCK_BASE_TIME = new Date('2026-09-30T00:30:00.000Z');

function packToUnitPack(label: string): string | null {
  return label.startsWith('per ') ? null : label;
}

/** Deterministic pseudo-random in [0,1) from an integer seed. */
function seeded(seed: number): number {
  const x = Math.sin(seed * 9301 + 49297) * 233280;
  return x - Math.floor(x);
}

export type MockItem = {
  externalId: string;
  itemCode: string;
  barcode: string | null;
  name: string;
  brand: string | null;
  categoryExternalId: string;
  mrp: number;
  sellingPrice: number;
  hsnCode: string | null;
  gstRate: number;
  stock: number;
  unit: string;
  packSize: string | null;
  isActive: boolean;
  isWeighable: boolean;
  updatedAt: string;
};

export function buildMockCatalog(): {
  categories: { externalId: string; name: string; parentExternalId: string | null; sortOrder: number }[];
  items: MockItem[];
} {
  const categories = C.map((category, index) => ({
    externalId: category.id,
    name: category.name,
    parentExternalId: category.parent,
    sortOrder: index,
  }));

  const items: MockItem[] = [];
  let counter = 1000;
  for (const category of C) {
    for (const [name, brand, packs, unit, weighable] of category.items) {
      for (const [pack, mrp, discount] of packs) {
        counter += 1;
        const seed = counter;
        const sellingPrice = Math.max(1, Math.round(mrp * (1 - discount / 100)));
        const packLabel = packToUnitPack(pack);
        const isLoose = weighable === true;
        // ~8% out of stock, ~10% low stock — so the app's stock states can be designed.
        const roll = seeded(seed);
        const stock = isLoose
          ? Number((roll < 0.08 ? 0 : 5 + seeded(seed + 1) * 120).toFixed(3))
          : roll < 0.08
            ? 0
            : roll < 0.18
              ? 1 + Math.floor(seeded(seed + 2) * 3)
              : 10 + Math.floor(seeded(seed + 3) * 150);
        items.push({
          externalId: `MOCK-I-${counter}`,
          itemCode: `MK${counter}`,
          barcode: isLoose ? null : `890${String(1000000000 + counter * 7919).slice(0, 10)}`,
          name: packLabel ? `${brand ? `${brand} ` : ''}${name} ${packLabel}` : `${name}`,
          brand,
          categoryExternalId: category.id,
          mrp,
          sellingPrice,
          hsnCode: category.hsn || null,
          gstRate: category.gst,
          stock,
          unit,
          packSize: packLabel,
          isActive: true,
          isWeighable: isLoose,
          updatedAt: MOCK_BASE_TIME.toISOString(),
        });
      }
    }
  }
  return { categories, items };
}
