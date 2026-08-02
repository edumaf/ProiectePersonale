/**
 * Emergency contacts shown on the dashboard and every result screen.
 *
 * ===========================================================================
 * PRE-LAUNCH: EVERY NUMBER IN THIS FILE MUST BE VERIFIED AGAINST AN
 * OFFICIAL SOURCE BEFORE RELEASE.
 *
 * These were compiled during development and are NOT authoritative. A
 * wrong number here costs someone minutes during amatoxin poisoning,
 * where the treatable window is measured in hours. Verify against each
 * country's health ministry or national poison centre, and re-check
 * periodically - poison centre numbers do change.
 * ===========================================================================
 *
 * Design: `emergency` is the number we are confident about (112 across the
 * EU/EEA, which is mandated and reaches a dispatcher who can route to
 * toxicology). `poisonCentre` is a direct specialist line where a single
 * national one exists, and is treated as a bonus - never the only number
 * shown. Countries with regional-only poison centres deliberately carry
 * no `poisonCentre` rather than an arbitrary city's number.
 */

export interface PoisonControlEntry {
  country: string;
  /** Always shown. General emergency services for the region. */
  emergency: string;
  /** Optional direct line to a national poison centre. */
  poisonCentre?: string;
  /** Shown under the numbers when there's a caveat worth stating. */
  note?: string;
}

const EU_EMERGENCY = '112';

/** 112 reaches emergency services across the EU/EEA and the UK. */
function european(country: string, poisonCentre?: string, note?: string): PoisonControlEntry {
  return { country, emergency: EU_EMERGENCY, poisonCentre, note };
}

export const poisonControlByCountry: Record<string, PoisonControlEntry> = {
  RO: european('Romania', '021 318 3606'),
  GB: european('United Kingdom', '111', 'NHS 111 for advice; 999 or 112 if someone is seriously unwell.'),
  IE: european('Ireland', '01 809 2166'),
  DE: european('Germany', undefined, 'Germany has regional Giftnotruf centres - 112 will route you to the right one.'),
  FR: european('France', undefined, 'France has regional centres antipoison - 112 will route you.'),
  IT: european('Italy', undefined, 'Italy has regional centri antiveleni - 112 will route you.'),
  ES: european('Spain', '91 562 04 20'),
  PT: european('Portugal', '808 250 143'),
  NL: european('Netherlands', '030 274 88 88'),
  BE: european('Belgium', '070 245 245'),
  AT: european('Austria', '01 406 43 43'),
  CH: { country: 'Switzerland', emergency: '144', poisonCentre: '145' },
  PL: european('Poland', undefined, 'Poland has regional toxicology centres - 112 will route you.'),
  CZ: european('Czechia', '224 919 293'),
  SK: european('Slovakia', '02 5477 4166'),
  HU: european('Hungary', '06 80 20 11 99'),
  BG: european('Bulgaria', '02 9154 233'),
  HR: european('Croatia', '01 2348 342'),
  SI: european('Slovenia'),
  RS: { country: 'Serbia', emergency: '112', poisonCentre: '011 3608 440' },
  GR: european('Greece', '210 779 3777'),
  SE: european('Sweden', '010 456 6700', 'Call 112 and ask for Giftinformation in an emergency.'),
  NO: { country: 'Norway', emergency: '113', poisonCentre: '22 59 13 00' },
  DK: european('Denmark', '82 12 12 12'),
  FI: european('Finland', '0800 147 111'),
  IS: european('Iceland', '543 2222'),
  EE: european('Estonia', '16662'),
  LV: european('Latvia', '67042473'),
  LT: european('Lithuania', '8 5 236 20 52'),
  LU: european('Luxembourg'),
  CY: european('Cyprus'),
  MT: european('Malta'),
  UA: { country: 'Ukraine', emergency: '112' },
  US: { country: 'United States', emergency: '911', poisonCentre: '1-800-222-1222' },
  CA: { country: 'Canada', emergency: '911', poisonCentre: '1-844-764-7669' },
  AU: { country: 'Australia', emergency: '000', poisonCentre: '13 11 26' },
  NZ: { country: 'New Zealand', emergency: '111', poisonCentre: '0800 764 766' },
};

/**
 * Shown when we have no listing for the user's region.
 *
 * Deliberately does NOT fall back to a specific country. Silently showing
 * Romania's number to someone in Japan is worse than admitting we don't
 * know: a confidently wrong number wastes the time that matters, whereas
 * an honest gap sends them straight to local emergency services.
 */
export const unknownRegionPoisonControl: PoisonControlEntry = {
  country: 'your region',
  emergency: '112',
  note: "We don't have a poison centre listed for your region. 112 works across Europe; elsewhere, call your local emergency number.",
};

export function poisonControlForRegion(regionCode: string | null | undefined): PoisonControlEntry {
  if (!regionCode) return unknownRegionPoisonControl;
  return poisonControlByCountry[regionCode.toUpperCase()] ?? unknownRegionPoisonControl;
}

/** Strips spaces and punctuation for a tel: URL. */
export function toDialString(phone: string): string {
  return phone.replace(/[^\d+]/g, '');
}
