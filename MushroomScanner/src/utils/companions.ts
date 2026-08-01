import { Species } from '../types/models';
import { speciesList } from '../data/species';

// Habitat/season/region are free text in the seed data, so overlap is
// scored on shared keywords rather than exact matches. Crude, but it's
// only used to order a "might also be growing here" list - nothing
// safety-critical depends on the ranking.
const STOP_WORDS = new Set([
  'and', 'or', 'the', 'in', 'on', 'at', 'to', 'of', 'near', 'under', 'often',
  'especially', 'with', 'a', 'an', 'their', 'other', 'from', 'by', 'for',
]);

function keywords(text: string): Set<string> {
  return new Set(
    text
      .toLowerCase()
      .split(/[^a-z]+/)
      .filter((word) => word.length > 3 && !STOP_WORDS.has(word))
  );
}

function overlap(a: Set<string>, b: Set<string>): number {
  let shared = 0;
  for (const word of a) if (b.has(word)) shared++;
  return shared;
}

export interface CompanionSpecies {
  species: Species;
  /** True when it shares habitat AND overlaps in season - i.e. you could plausibly meet both on one walk. */
  sameSeason: boolean;
}

export interface Companions {
  /** Toxic/deadly/unknown species sharing this habitat - shown first, always. */
  hazards: CompanionSpecies[];
  /** Edible species sharing this habitat - the "what else can I pick here" list. */
  edibles: CompanionSpecies[];
}

const HAZARD_STATUSES = ['deadly', 'toxic', 'unknown', 'inedible'];

/**
 * Species that plausibly grow in the same place and time as the given one.
 *
 * Returned in two groups rather than one ranked list. Hazards are never
 * crowded out by edibles: knowing a deadly species shares this habitat is
 * exactly what a forager should have in mind while picking, so it gets
 * its own section rather than competing for slots in a single list.
 */
export function findCompanions(species: Species, perGroup = 4): Companions {
  const habitat = keywords(species.habitat);
  const season = keywords(species.season);
  const region = keywords(species.region);

  const scored = speciesList
    .filter((other) => other.id !== species.id)
    // Exclude known look-alikes - they already get their own, more
    // prominent section on the result screen.
    .filter((other) => !species.lookalikeSpeciesIds.includes(other.id))
    .map((other) => ({
      other,
      habitatScore: overlap(habitat, keywords(other.habitat)),
      seasonScore: overlap(season, keywords(other.season)),
      regionScore: overlap(region, keywords(other.region)),
    }))
    .filter((entry) => entry.habitatScore > 0 && entry.regionScore > 0)
    .sort((a, b) => b.habitatScore + b.seasonScore - (a.habitatScore + a.seasonScore));

  const take = (predicate: (status: string) => boolean) =>
    scored
      .filter((entry) => predicate(entry.other.edibilityStatus))
      .slice(0, perGroup)
      .map((entry) => ({ species: entry.other, sameSeason: entry.seasonScore > 0 }));

  return {
    hazards: take((status) => HAZARD_STATUSES.includes(status)),
    edibles: take((status) => !HAZARD_STATUSES.includes(status)),
  };
}
