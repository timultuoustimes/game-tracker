// Hollow Knight tracker config — hand-authored Phase 2 seed data.
//
// This is a small 20-item subset covering every StructuredTracker
// category type (checklist, collectibles, leveled, sequence) to
// stress-test the renderer before the full ~200-item version lands.
//
// Schema: see docs/structured-tracker-schema.md

export const HOLLOW_KNIGHT_CONFIG = {
  name: 'Hollow Knight',
  icon: '🗡️',
  color: 'from-slate-900 via-blue-950 to-black',
  accent: 'slate',
  description: 'Metroidvania soulslike by Team Cherry',
  structuredData: {
    schemaVersion: 1,
    generatedAt: '2026-04-11T00:00:00Z',
    generatedBy: 'user',
    sources: [{
      type: 'user',
      title: 'Hand-authored Phase 2 seed data',
    }],

    categories: [
      // ─── checklist ───────────────────────────────────────────────────
      {
        id: 'main-bosses',
        name: 'Main Bosses',
        description: 'Required bosses along the main path to an ending.',
        type: 'checklist',
        items: [
          { id: 'boss-false-knight',  name: 'False Knight',
            location: 'Forgotten Crossroads' },
          { id: 'boss-hornet-1',      name: 'Hornet Protector',
            location: 'Greenpath' },
          { id: 'boss-mantis-lords',  name: 'Mantis Lords',
            location: 'Fungal Wastes' },
          { id: 'boss-soul-master',   name: 'Soul Master',
            location: 'City of Tears' },
          { id: 'boss-dung-defender', name: 'Dung Defender',
            location: 'Royal Waterways' },
          { id: 'boss-hollow-knight', name: 'The Hollow Knight',
            location: 'Temple of the Black Egg' },
        ],
      },

      // ─── collectibles, with missable + metadata ──────────────────────
      {
        id: 'charms',
        name: 'Charms',
        description: 'A tiny slice of the full 45-charm set — just enough to exercise the schema.',
        type: 'collectibles',
        items: [
          { id: 'charm-wayward-compass', name: 'Wayward Compass',
            location: 'Forgotten Crossroads',
            source: 'Purchased from Iselda',
            metadata: { notchCost: 1 } },
          { id: 'charm-gathering-swarm', name: 'Gathering Swarm',
            location: 'Forgotten Crossroads',
            source: 'Purchased from Salubra',
            metadata: { notchCost: 1 } },
          { id: 'charm-grubsong', name: 'Grubsong',
            location: 'Forgotten Crossroads (Grubfather)',
            source: 'Rescue 10 grubs',
            metadata: { notchCost: 1 } },
          { id: 'charm-mark-of-pride', name: 'Mark of Pride',
            location: 'Mantis Village',
            source: 'Reward from Mantis Lords',
            metadata: { notchCost: 3 } },
          { id: 'charm-grimmchild', name: 'Grimmchild',
            location: 'Howling Cliffs',
            source: 'Start the Grimm Troupe ritual',
            missable: true,
            tags: ['dlc:grimm-troupe', 'route-exclusive'],
            metadata: { notchCost: 2 } },
          { id: 'charm-carefree-melody', name: 'Carefree Melody',
            location: 'Howling Cliffs (Nymm)',
            source: 'Banish the Grimm Troupe',
            missable: true,
            tags: ['dlc:grimm-troupe', 'route-exclusive'],
            metadata: { notchCost: 3 } },
        ],
      },

      // ─── leveled, single item with named ranks ───────────────────────
      {
        id: 'nail-upgrades',
        name: 'Nail Upgrades',
        description: 'Upgraded at the Nailsmith with pale ore + geo.',
        type: 'leveled',
        items: [{
          id: 'nail',
          name: 'Nail',
          maxRank: 4,
          rankNames: ['Old Nail', 'Sharpened Nail', 'Channelled Nail', 'Coiled Nail', 'Pure Nail'],
        }],
      },

      // ─── leveled, multi-item with named per-rank tiers ───────────────
      {
        id: 'spells',
        name: 'Spells',
        description: 'Each spell has a base and an upgraded form.',
        type: 'leveled',
        items: [
          { id: 'spell-fireball',
            name: 'Vengeful Spirit → Shade Soul',
            maxRank: 2,
            rankNames: ['Not acquired', 'Vengeful Spirit', 'Shade Soul'],
            location: 'Forgotten Crossroads / City of Tears' },
          { id: 'spell-quake',
            name: 'Desolate Dive → Descending Dark',
            maxRank: 2,
            rankNames: ['Not acquired', 'Desolate Dive', 'Descending Dark'],
            location: 'Soul Sanctum / Crystal Peak' },
          { id: 'spell-scream',
            name: 'Howling Wraiths → Abyss Shriek',
            maxRank: 2,
            rankNames: ['Not acquired', 'Howling Wraiths', 'Abyss Shriek'],
            location: "Howling Cliffs / King's Pass" },
        ],
      },

      // ─── sequence, with spoiler hiding ───────────────────────────────
      {
        id: 'endings',
        name: 'Endings',
        description: 'Ending names are hidden until you reveal or reach them.',
        type: 'sequence',
        items: [
          { id: 'ending-hollow-knight', name: 'The Hollow Knight',
            description: 'The default ending — defeat The Hollow Knight without Void Heart.',
            hideUntilDiscovered: true },
          { id: 'ending-sealed-siblings', name: 'Sealed Siblings',
            description: 'Acquire Void Heart, then defeat The Hollow Knight.',
            hideUntilDiscovered: true },
          { id: 'ending-dream-no-more', name: 'Dream No More',
            description: 'Acquire Void Heart and the Awoken Dream Nail, then defeat The Radiance.',
            hideUntilDiscovered: true },
          { id: 'ending-embrace-the-void', name: 'Embrace the Void',
            description: 'Complete the Pantheon of Hallownest.',
            tags: ['dlc:godmaster'],
            hideUntilDiscovered: true },
        ],
      },
    ],

    estimatedHours: 40,
    completionNotes: '112% completion requires all charms including the mutually-exclusive Grimm Troupe path items and the Godmaster DLC pantheons.',
    tags: ['metroidvania', 'soulslike', 'indie'],
  },
};
