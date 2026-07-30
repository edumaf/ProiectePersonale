import { useEffect, useState } from 'react';
import { useAuth } from '../lib/auth';
import { fetchScanById } from '../lib/scans';
import { mockScans } from '../data/mockScans';
import { ScanResult } from '../types/models';

/**
 * A single scan by id. Mock ids (the fixed demo dataset) resolve
 * synchronously; anything else is treated as a real Supabase scan id and
 * fetched from the scans table.
 */
export function useScan(scanId: string) {
  const { session } = useAuth();
  const mockMatch = mockScans.find((s) => s.id === scanId) ?? null;
  const [scan, setScan] = useState<ScanResult | null>(mockMatch);
  const [loading, setLoading] = useState(!mockMatch && Boolean(session));

  useEffect(() => {
    if (mockMatch) {
      setScan(mockMatch);
      return;
    }
    if (!session) return;

    let cancelled = false;
    setLoading(true);
    fetchScanById(scanId)
      .then((result) => {
        if (!cancelled) setScan(result);
      })
      .catch((err) => console.warn('Failed to load scan', err))
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scanId, session]);

  return { scan, loading };
}
