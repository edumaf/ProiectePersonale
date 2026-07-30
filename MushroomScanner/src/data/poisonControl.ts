// Minimal starting set - expand per user locale before launch.
// Numbers are official national poison-control lines, not app-specific.
export const poisonControlByCountry: Record<string, { country: string; phone: string }> = {
  RO: { country: 'Romania', phone: '021 318 3606' },
  GB: { country: 'United Kingdom', phone: '111' },
  US: { country: 'United States', phone: '1-800-222-1222' },
  DE: { country: 'Germany', phone: '030 19240' },
  FR: { country: 'France', phone: '01 40 05 48 48' },
};

export const defaultPoisonControl = poisonControlByCountry.RO;
