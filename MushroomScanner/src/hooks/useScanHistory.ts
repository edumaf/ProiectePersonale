import { useCallback, useState } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { useAuth } from '../lib/auth';
import { fetchScans } from '../lib/scans';
import { mockScans } from '../data/mockScans';
import { ScanResult } from '../types/models';

const PAGE_SIZE = 20;

/**
 * Paginated scan history with infinite scroll. Demo mode returns the
 * bundled mock scans in one page - there's nothing to page through.
 */
export function useScanHistory() {
  const { session } = useAuth();
  const [scans, setScans] = useState<ScanResult[]>(mockScans);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const isDemo = !session;

  const load = useCallback(
    async (mode: 'refresh' | 'more') => {
      if (!session) {
        setScans(mockScans);
        setHasMore(false);
        return;
      }
      if (mode === 'refresh') setRefreshing(true);
      else setLoadingMore(true);

      try {
        const offset = mode === 'refresh' ? 0 : scans.length;
        const page = await fetchScans(session.user.id, { limit: PAGE_SIZE, offset });
        setScans((prev) => (mode === 'refresh' ? page : [...prev, ...page]));
        setHasMore(page.length === PAGE_SIZE);
      } catch (err) {
        console.warn('Failed to load scan history', err);
      } finally {
        setRefreshing(false);
        setLoadingMore(false);
      }
    },
    [session, scans.length]
  );

  const refresh = useCallback(() => load('refresh'), [load]);

  const loadMore = useCallback(() => {
    if (hasMore && !loadingMore && !refreshing) load('more');
  }, [hasMore, loadingMore, refreshing, load]);

  useFocusEffect(
    useCallback(() => {
      // Deliberately only depends on the session: re-running on every
      // `scans.length` change (which `load` closes over) would refetch in
      // a loop as pages come in.
      load('refresh');
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [session])
  );

  return { scans, refreshing, loadingMore, hasMore, isDemo, refresh, loadMore };
}
