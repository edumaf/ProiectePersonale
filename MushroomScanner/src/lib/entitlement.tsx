import { createContext, ReactNode, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { supabase } from './supabase';
import { useAuth } from './auth';

export type SubscriptionTier = 'free' | 'pro';

export interface Entitlement {
  tier: SubscriptionTier;
  scansUsed: number;
  scansLimit: number | null;
  isPro: boolean;
}

interface EntitlementContextValue extends Entitlement {
  loading: boolean;
  refresh: () => Promise<void>;
}

const FREE_SCAN_LIMIT = 5;

// Demo mode has no backend to ask, so it shows the app as it looks to a
// free user - the paywall is part of the product and should be visible
// when demoing it.
const demoEntitlement: Entitlement = { tier: 'free', scansUsed: 0, scansLimit: FREE_SCAN_LIMIT, isPro: false };

const EntitlementContext = createContext<EntitlementContextValue | null>(null);

export function EntitlementProvider({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const [entitlement, setEntitlement] = useState<Entitlement>(demoEntitlement);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    if (!supabase || !session) {
      setEntitlement(demoEntitlement);
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('tier, scans_this_period, pro_expires_at')
        .eq('id', session.user.id)
        .maybeSingle();
      if (error) throw error;

      // An expired pro subscription is treated as free, matching what
      // consume_scan_credit does server-side.
      const notExpired = !data?.pro_expires_at || new Date(data.pro_expires_at) > new Date();
      const isPro = data?.tier === 'pro' && notExpired;
      setEntitlement({
        tier: isPro ? 'pro' : 'free',
        scansUsed: data?.scans_this_period ?? 0,
        scansLimit: isPro ? null : FREE_SCAN_LIMIT,
        isPro,
      });
    } catch (err) {
      console.warn('Failed to load entitlement', err);
    } finally {
      setLoading(false);
    }
  }, [session]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const value = useMemo<EntitlementContextValue>(
    () => ({ ...entitlement, loading, refresh }),
    [entitlement, loading, refresh]
  );

  return <EntitlementContext.Provider value={value}>{children}</EntitlementContext.Provider>;
}

export function useEntitlement() {
  const ctx = useContext(EntitlementContext);
  if (!ctx) throw new Error('useEntitlement must be used within EntitlementProvider');
  return ctx;
}
