import {
  poisonControlByCountry,
  poisonControlForRegion,
  toDialString,
  unknownRegionPoisonControl,
} from '../poisonControl';

// This data sits on the emergency path. The tests below can't verify the
// numbers are *correct* - that requires an authoritative source and is a
// flagged pre-launch task - but they can hold the lookup behaviour to the
// rule that matters: never show a confidently wrong number.

describe('poisonControlForRegion', () => {
  it('returns the matching country entry', () => {
    expect(poisonControlForRegion('RO').country).toBe('Romania');
    expect(poisonControlForRegion('DE').country).toBe('Germany');
    expect(poisonControlForRegion('US').country).toBe('United States');
  });

  it('is case insensitive, since locale region codes vary', () => {
    expect(poisonControlForRegion('gb')).toEqual(poisonControlForRegion('GB'));
    expect(poisonControlForRegion('Se')).toEqual(poisonControlForRegion('SE'));
  });

  it('never silently falls back to a specific country', () => {
    // The original bug: everyone saw Romania regardless of where they
    // were. An unknown region must resolve to the explicit unknown entry,
    // not to some arbitrary country's hotline.
    for (const region of ['JP', 'BR', 'ZZ', 'XX']) {
      const contact = poisonControlForRegion(region);
      expect(contact).toBe(unknownRegionPoisonControl);
      expect(contact.country).not.toBe('Romania');
    }
  });

  it('handles a missing region without throwing', () => {
    // Localization can return null on a device with no region configured.
    expect(poisonControlForRegion(null)).toBe(unknownRegionPoisonControl);
    expect(poisonControlForRegion(undefined)).toBe(unknownRegionPoisonControl);
    expect(poisonControlForRegion('')).toBe(unknownRegionPoisonControl);
  });

  it('tells the user when it does not know their region', () => {
    const contact = poisonControlForRegion('JP');
    expect(contact.note).toBeDefined();
    expect(contact.note).toMatch(/don't have a poison centre listed/i);
  });

  it('still offers a number in the unknown case', () => {
    // An honest gap must not become a dead end - there has to be
    // something to call.
    expect(unknownRegionPoisonControl.emergency.length).toBeGreaterThan(0);
  });
});

describe('poison control catalog', () => {
  const entries = Object.entries(poisonControlByCountry);

  it('covers a broad set of countries', () => {
    expect(entries.length).toBeGreaterThanOrEqual(30);
  });

  it('gives every entry a country name and emergency number', () => {
    for (const [code, entry] of entries) {
      expect(entry.country.trim().length).toBeGreaterThan(0);
      expect(entry.emergency.trim().length).toBeGreaterThan(0);
      expect(code).toMatch(/^[A-Z]{2}$/);
    }
  });

  it('has dialable numbers everywhere', () => {
    for (const [code, entry] of entries) {
      expect(toDialString(entry.emergency)).toMatch(/^\+?\d+$/);
      if (entry.poisonCentre) {
        expect(toDialString(entry.poisonCentre)).toMatch(/^\+?\d+$/);
      }
    }
    expect(toDialString(unknownRegionPoisonControl.emergency)).toMatch(/^\+?\d+$/);
  });

  it('uses 112 for EU/EEA countries', () => {
    // 112 is mandated across the EU/EEA, so these should never drift to
    // something else by accident.
    for (const code of ['RO', 'DE', 'FR', 'IT', 'ES', 'PL', 'SE', 'FI', 'IE']) {
      expect(poisonControlByCountry[code].emergency).toBe('112');
    }
  });

  it('explains itself when a country has no dedicated poison centre', () => {
    // A missing poisonCentre is a deliberate choice for countries with
    // regional-only centres. If we're not giving a specialist number, the
    // user should be told why rather than left wondering.
    const euCountriesWithoutCentre = entries.filter(
      ([code, entry]) => !entry.poisonCentre && ['DE', 'FR', 'IT', 'PL'].includes(code)
    );
    for (const [, entry] of euCountriesWithoutCentre) {
      expect(entry.note).toBeDefined();
    }
  });
});

describe('toDialString', () => {
  it('strips spaces and punctuation', () => {
    expect(toDialString('021 318 3606')).toBe('0213183606');
    expect(toDialString('1-800-222-1222')).toBe('18002221222');
    expect(toDialString('06 80 20 11 99')).toBe('0680201199');
  });

  it('keeps a leading plus for international numbers', () => {
    expect(toDialString('+40 21 318 3606')).toBe('+40213183606');
  });

  it('leaves short emergency numbers untouched', () => {
    expect(toDialString('112')).toBe('112');
    expect(toDialString('911')).toBe('911');
    expect(toDialString('000')).toBe('000');
  });
});
