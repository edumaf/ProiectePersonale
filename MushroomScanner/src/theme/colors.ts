// Editorial field-guide palette: warm earth tones with high-contrast
// edibility signal colors that must stay legible at a glance.
export const colors = {
  // Core earth tones
  bark: '#3B2A1F',
  barkLight: '#5A4433',
  moss: '#4A5D3A',
  mossDark: '#33422A',
  cream: '#F7F1E3',
  paper: '#FFFBF2',
  capRed: '#B34324',
  clay: '#C97B4A',

  // Neutrals
  ink: '#241C15',
  charcoal: '#4A443C',
  fog: '#8B8375',
  hairline: '#E4DBC8',
  white: '#FFFFFF',

  // Edibility signal colors (never rely on color alone - pair with icon/text)
  edible: '#3E7D32',
  edibleBg: '#E7F2E3',
  edibleCooked: '#8A7A1F',
  edibleCookedBg: '#F5F0DC',
  toxic: '#D2691E',
  toxicBg: '#FBE9DB',
  deadly: '#A11F1F',
  deadlyBg: '#FBE0DE',
  inedible: '#6B6459',
  inedibleBg: '#EDEAE2',
  unknown: '#5C6B7A',
  unknownBg: '#E6EBEF',

  // Confidence badge
  confidenceHigh: '#3E7D32',
  confidenceMedium: '#C08A1E',
  confidenceLow: '#A11F1F',
} as const;

export type EdibilityStatus =
  | 'edible'
  | 'edible_cooked'
  | 'toxic'
  | 'deadly'
  | 'inedible'
  | 'unknown';

export const edibilityPresentation: Record<
  EdibilityStatus,
  { label: string; color: string; background: string; icon: string }
> = {
  edible: { label: 'Edible', color: colors.edible, background: colors.edibleBg, icon: 'check-circle' },
  edible_cooked: {
    label: 'Edible (cooking required)',
    color: colors.edibleCooked,
    background: colors.edibleCookedBg,
    icon: 'local-fire-department',
  },
  toxic: { label: 'Toxic', color: colors.toxic, background: colors.toxicBg, icon: 'warning' },
  deadly: { label: 'Deadly', color: colors.deadly, background: colors.deadlyBg, icon: 'dangerous' },
  inedible: { label: 'Inedible', color: colors.inedible, background: colors.inedibleBg, icon: 'block' },
  unknown: { label: 'Unknown / Uncertain', color: colors.unknown, background: colors.unknownBg, icon: 'help' },
};
