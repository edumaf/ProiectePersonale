import { useCallback, useState } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { useAuth } from '../lib/auth';
import { fetchCollections, fetchScans } from '../lib/scans';
import { mockCollections, mockScans } from '../data/mockScans';
import { Collection, ScanResult } from '../types/models';

/**
 * Scans/collections for the signed-in user, refetched whenever the owning
 * screen regains focus. Falls back to bundled demo data when there's no
 * session (demo mode or simply not signed in yet) so every screen stays
 * populated and explorable without a backend.
 */
export function useAppData() {
  const { session } = useAuth();
  const [scans, setScans] = useState<ScanResult[]>(mockScans);
  const [collections, setCollections] = useState<Collection[]>(mockCollections);
  const [loading, setLoading] = useState(false);
  const isDemo = !session;

  const refresh = useCallback(async () => {
    if (!session) {
      setScans(mockScans);
      setCollections(mockCollections);
      return;
    }
    setLoading(true);
    try {
      const [realScans, realCollections] = await Promise.all([
        fetchScans(session.user.id),
        fetchCollections(session.user.id),
      ]);
      setScans(realScans);
      setCollections(
        realCollections.map((collection) => ({
          ...collection,
          scanIds: realScans.filter((scan) => scan.collectionId === collection.id).map((scan) => scan.id),
        }))
      );
    } catch (err) {
      console.warn('Failed to load scans/collections', err);
    } finally {
      setLoading(false);
    }
  }, [session]);

  useFocusEffect(
    useCallback(() => {
      refresh();
    }, [refresh])
  );

  return { scans, collections, loading, isDemo, refresh };
}
