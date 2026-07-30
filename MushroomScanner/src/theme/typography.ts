import { Platform } from 'react-native';

// Humanist serif for species names (editorial field-guide feel),
// system sans for UI chrome/body copy.
export const fonts = {
  serif: Platform.select({ ios: 'Georgia', android: 'serif', default: 'serif' }),
  sans: Platform.select({ ios: 'System', android: 'sans-serif', default: 'System' }),
  sansMedium: Platform.select({ ios: 'System', android: 'sans-serif-medium', default: 'System' }),
};

export const type = {
  display: { fontFamily: fonts.serif, fontSize: 32, lineHeight: 38, fontWeight: '700' as const },
  h1: { fontFamily: fonts.serif, fontSize: 26, lineHeight: 32, fontWeight: '700' as const },
  h2: { fontFamily: fonts.serif, fontSize: 20, lineHeight: 26, fontWeight: '600' as const },
  latin: { fontFamily: fonts.serif, fontSize: 16, lineHeight: 22, fontStyle: 'italic' as const },
  body: { fontFamily: fonts.sans, fontSize: 15, lineHeight: 22, fontWeight: '400' as const },
  bodyMedium: { fontFamily: fonts.sansMedium, fontSize: 15, lineHeight: 22, fontWeight: '500' as const },
  label: { fontFamily: fonts.sansMedium, fontSize: 12, lineHeight: 16, fontWeight: '600' as const },
  caption: { fontFamily: fonts.sans, fontSize: 12, lineHeight: 16, fontWeight: '400' as const },
};
