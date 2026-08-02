import { useMemo } from 'react';
import * as Localization from 'expo-localization';
import { poisonControlForRegion } from '../data/poisonControl';

/**
 * Emergency contact for the user's device region.
 *
 * Uses the device's configured region rather than GPS: it needs no
 * permission prompt, works offline, and is available instantly - all of
 * which matter for something on the emergency path. The trade-off is a
 * traveller abroad sees their home country's number, so the UI states
 * which region it's showing rather than presenting it as local truth.
 */
export function usePoisonControl() {
  return useMemo(() => {
    const region = Localization.getLocales()[0]?.regionCode ?? null;
    return { region, contact: poisonControlForRegion(region) };
  }, []);
}
