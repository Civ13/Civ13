// Curated source metadata, not a runner or filesystem discovery mechanism.
export const fixtureCatalog = Object.freeze([
  {
    id: 'character-return', guide: 'tests/world_save/character_return/prepare.py',
    scope: 'Saved character return and admission cases',
    prerequisites: 'Verified Python, current repository sources, and a fresh output directory for preparation.',
    evidence: 'Source preparation and hashes only; preparation neither compiles nor launches BYOND.'
  },
  {
    id: 'season-transition', guide: 'tests/season_transition/README.md',
    scope: 'Season transition parity and request scenarios',
    prerequisites: 'Verified Python and a fresh directory for prepare-only; native cases require the documented BYOND version and separate authorization.',
    evidence: 'Prepare-only creates an unrun fixture; native parity and runtime evidence are separate.'
  },
  {
    id: 'seasonal-construction', guide: 'tests/seasonal_construction/README.md',
    scope: 'Seasonal construction decay and persistence',
    prerequisites: 'Verified Python and a fresh output directory for preparation.',
    evidence: 'Offline source models and uncompiled native packet; neither proves native gameplay.'
  },
  {
    id: 'zone-persistence', guide: 'tests/zone_persistence/README.md',
    scope: 'Zone topology persistence and malformed input',
    prerequisites: 'Verified Python and isolated temporary fixture storage for preparation; native execution requires the documented adapter and separate authorization.',
    evidence: 'Offline source checks and preparation; native acceptance is separately versioned in the guide.'
  }
]);
