import { createContext, ReactNode, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Bump this if the disclaimer's wording materially changes - users should
// re-read and re-accept a substantively different safety warning rather
// than silently inheriting consent to older copy.
const CONSENT_VERSION = 1;
const CONSENT_KEY = `mushroomscanner.safety-consent.v${CONSENT_VERSION}`;

interface ConsentContextValue {
  /** Null while still reading from storage. */
  accepted: boolean | null;
  loading: boolean;
  accept: () => Promise<void>;
  /** Clears stored consent - used by the "review safety guidance" action. */
  reset: () => Promise<void>;
}

const ConsentContext = createContext<ConsentContextValue | null>(null);

export function ConsentProvider({ children }: { children: ReactNode }) {
  const [accepted, setAccepted] = useState<boolean | null>(null);

  useEffect(() => {
    let cancelled = false;
    AsyncStorage.getItem(CONSENT_KEY)
      .then((value) => {
        if (!cancelled) setAccepted(value === 'true');
      })
      .catch(() => {
        // Storage failure should never silently skip the disclaimer -
        // fall back to showing it.
        if (!cancelled) setAccepted(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const accept = useCallback(async () => {
    setAccepted(true);
    try {
      await AsyncStorage.setItem(CONSENT_KEY, 'true');
    } catch {
      // Non-fatal: they've consented for this session, they'll just be
      // asked again next launch.
    }
  }, []);

  const reset = useCallback(async () => {
    setAccepted(false);
    try {
      await AsyncStorage.removeItem(CONSENT_KEY);
    } catch {
      // Ignore - in-memory state already reset.
    }
  }, []);

  const value = useMemo<ConsentContextValue>(
    () => ({ accepted, loading: accepted === null, accept, reset }),
    [accepted, accept, reset]
  );

  return <ConsentContext.Provider value={value}>{children}</ConsentContext.Provider>;
}

export function useConsent() {
  const ctx = useContext(ConsentContext);
  if (!ctx) throw new Error('useConsent must be used within ConsentProvider');
  return ctx;
}
