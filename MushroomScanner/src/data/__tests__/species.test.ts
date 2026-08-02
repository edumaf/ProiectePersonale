import { speciesList, getSpeciesById } from '../species';
import { EdibilityStatus } from '../../theme/colors';

// Data-integrity checks on the species catalog. These were being run by
// hand during development; codifying them means a bad edit to
// species.json fails the test run instead of shipping.

const VALID_STATUSES: EdibilityStatus[] = [
  'edible',
  'edible_cooked',
  'toxic',
  'deadly',
  'inedible',
  'unknown',
];

const EDIBLE_STATUSES: EdibilityStatus[] = ['edible', 'edible_cooked'];

describe('species catalog', () => {
  it('has a meaningful number of species', () => {
    expect(speciesList.length).toBeGreaterThanOrEqual(40);
  });

  it('has unique ids', () => {
    const ids = speciesList.map((s) => s.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('has no dangling look-alike references', () => {
    const ids = new Set(speciesList.map((s) => s.id));
    const dangling: string[] = [];
    for (const species of speciesList) {
      for (const lookalikeId of species.lookalikeSpeciesIds) {
        if (!ids.has(lookalikeId)) dangling.push(`${species.id} -> ${lookalikeId}`);
      }
    }
    // A dangling reference silently drops a look-alike from the result
    // screen - i.e. a dangerous species the user is never warned about.
    expect(dangling).toEqual([]);
  });

  it('never lists itself as its own look-alike', () => {
    const selfReferential = speciesList.filter((s) => s.lookalikeSpeciesIds.includes(s.id));
    expect(selfReferential.map((s) => s.id)).toEqual([]);
  });

  it('uses only valid edibility statuses', () => {
    for (const species of speciesList) {
      expect(VALID_STATUSES).toContain(species.edibilityStatus);
    }
  });

  it('has the required descriptive fields populated', () => {
    for (const species of speciesList) {
      expect(species.commonName.trim().length).toBeGreaterThan(0);
      expect(species.latinName.trim().length).toBeGreaterThan(0);
      expect(species.habitat.trim().length).toBeGreaterThan(0);
      expect(species.season.trim().length).toBeGreaterThan(0);
      expect(species.region.trim().length).toBeGreaterThan(0);
      expect(species.photoUrls.length).toBeGreaterThan(0);
    }
  });

  it('includes the deadly species that actually kill people', () => {
    // Regression guard: these are the whole reason the app exists. If a
    // data refactor drops them, that should be a loud failure.
    for (const id of ['death-cap', 'destroying-angel', 'deadly-dapperling', 'funeral-bell']) {
      const species = getSpeciesById(id);
      expect(species).not.toBeNull();
      expect(species!.edibilityStatus).toBe('deadly');
    }
  });

  it('gives every deadly species toxicity notes', () => {
    for (const species of speciesList.filter((s) => s.edibilityStatus === 'deadly')) {
      expect(species.toxicityNotes?.trim().length ?? 0).toBeGreaterThan(0);
    }
  });
});

describe('cooking methods safety constraint', () => {
  it('only ever appear on edible species', () => {
    const violations = speciesList
      .filter((s) => (s.cookingMethods?.length ?? 0) > 0)
      .filter((s) => !EDIBLE_STATUSES.includes(s.edibilityStatus))
      .map((s) => `${s.id} (${s.edibilityStatus})`);

    // The single most dangerous data error possible in this app:
    // preparation advice attached to something that can kill you.
    expect(violations).toEqual([]);
  });

  it('never appear on a deadly species', () => {
    for (const species of speciesList.filter((s) => s.edibilityStatus === 'deadly')) {
      expect(species.cookingMethods ?? []).toEqual([]);
    }
  });

  it('are present for every edible species', () => {
    const missing = speciesList
      .filter((s) => EDIBLE_STATUSES.includes(s.edibilityStatus))
      .filter((s) => (s.cookingMethods?.length ?? 0) === 0)
      .map((s) => s.id);
    expect(missing).toEqual([]);
  });

  it('have both a method name and detail', () => {
    for (const species of speciesList) {
      for (const entry of species.cookingMethods ?? []) {
        expect(entry.method.trim().length).toBeGreaterThan(0);
        expect(entry.detail.trim().length).toBeGreaterThan(0);
      }
    }
  });
});

describe('cooking-required species', () => {
  it('carry prep instructions when requiresCooking is set', () => {
    for (const species of speciesList.filter((s) => s.requiresCooking)) {
      expect(species.prepInstructions?.trim().length ?? 0).toBeGreaterThan(0);
    }
  });

  it('mark every edible_cooked species as requiring cooking', () => {
    for (const species of speciesList.filter((s) => s.edibilityStatus === 'edible_cooked')) {
      expect(species.requiresCooking).toBe(true);
    }
  });
});

describe('poisoning history', () => {
  it('avoids invented precise death tolls', () => {
    // The brief explicitly forbids fabricated figures - history should be
    // qualitative ("responsible for the majority of fatal poisonings")
    // rather than "killed 47 people".
    const numericDeathClaim = /\b\d[\d,]*\s+(deaths|fatalities|people\s+(have\s+)?died)/i;
    const offenders = speciesList
      .filter((s) => s.poisoningHistory && numericDeathClaim.test(s.poisoningHistory))
      .map((s) => s.id);
    expect(offenders).toEqual([]);
  });
});

describe('getSpeciesById', () => {
  it('finds a known species', () => {
    expect(getSpeciesById('chanterelle')?.commonName).toBe('Chanterelle');
  });

  it('returns null for unknown, null, and undefined ids', () => {
    expect(getSpeciesById('not-a-real-species')).toBeNull();
    expect(getSpeciesById(null)).toBeNull();
    expect(getSpeciesById(undefined)).toBeNull();
  });
});
