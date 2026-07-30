import { Species } from '../types/models';
import speciesSeed from '../../db/seed/species.json';

// Single source of truth: db/seed/species.json (also used to generate the
// Postgres seed via db/seed/generate-sql.mjs). ~45 European foraging
// species with real, sourced qualitative data - see README.md for the
// pre-launch note on replacing placeholder photoUrls with real photography.
export const speciesList: Species[] = speciesSeed as Species[];

export function getSpeciesById(id: string | null | undefined) {
  return speciesList.find((s) => s.id === id) ?? null;
}
