import { findCompanions } from '../companions';
import { getSpeciesById } from '../../data/species';

const HAZARD_STATUSES = ['deadly', 'toxic', 'unknown', 'inedible'];

describe('findCompanions', () => {
  it('separates hazards from edibles', () => {
    const porcini = getSpeciesById('porcini')!;
    const { hazards, edibles } = findCompanions(porcini);

    for (const entry of hazards) {
      expect(HAZARD_STATUSES).toContain(entry.species.edibilityStatus);
    }
    for (const entry of edibles) {
      expect(HAZARD_STATUSES).not.toContain(entry.species.edibilityStatus);
    }
  });

  it('surfaces Death Cap alongside Porcini', () => {
    // Both favour oak/beech woodland in the same season. This is the
    // single most important companion pairing in the dataset - a porcini
    // forager needs Death Cap on their mind.
    const { hazards } = findCompanions(getSpeciesById('porcini')!);
    expect(hazards.map((h) => h.species.id)).toContain('death-cap');
  });

  it('surfaces Deadly Dapperling alongside Field Mushroom', () => {
    // Both grow in grassland; this confusion has killed people.
    const { hazards } = findCompanions(getSpeciesById('field-mushroom')!);
    expect(hazards.map((h) => h.species.id)).toContain('deadly-dapperling');
  });

  it('does not crowd out edibles with hazards', () => {
    // The bug that motivated splitting into two groups: a single ranked
    // list showed six dangerous species and zero edible ones.
    const { edibles } = findCompanions(getSpeciesById('field-mushroom')!);
    expect(edibles.length).toBeGreaterThan(0);
  });

  it('never includes the species itself', () => {
    for (const id of ['porcini', 'chanterelle', 'death-cap', 'morel']) {
      const species = getSpeciesById(id)!;
      const { hazards, edibles } = findCompanions(species);
      const allIds = [...hazards, ...edibles].map((e) => e.species.id);
      expect(allIds).not.toContain(id);
    }
  });

  it('excludes known look-alikes, which have their own section', () => {
    const chanterelle = getSpeciesById('chanterelle')!;
    const { hazards, edibles } = findCompanions(chanterelle);
    const allIds = [...hazards, ...edibles].map((e) => e.species.id);
    for (const lookalikeId of chanterelle.lookalikeSpeciesIds) {
      expect(allIds).not.toContain(lookalikeId);
    }
  });

  it('respects the per-group limit', () => {
    const { hazards, edibles } = findCompanions(getSpeciesById('porcini')!, 3);
    expect(hazards.length).toBeLessThanOrEqual(3);
    expect(edibles.length).toBeLessThanOrEqual(3);
  });

  it('returns something for every species without throwing', () => {
    // Guards the keyword-overlap scoring against edge cases in the data,
    // e.g. a species whose habitat text shares no words with any other.
    const { speciesList } = require('../../data/species');
    for (const species of speciesList) {
      expect(() => findCompanions(species)).not.toThrow();
    }
  });

  it('flags same-season companions', () => {
    const { hazards } = findCompanions(getSpeciesById('porcini')!);
    // Porcini is summer-autumn; Death Cap is late summer to autumn.
    const deathCap = hazards.find((h) => h.species.id === 'death-cap');
    expect(deathCap?.sameSeason).toBe(true);
  });
});
