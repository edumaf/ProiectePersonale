import { useMemo } from 'react';
import { useAppData } from './useAppData';
import { speciesList } from '../data/species';
import { LOW_CONFIDENCE_THRESHOLD } from '../utils/confidence';

/**
 * "You've found 12 of 45 species" - collection progress across the guide.
 *
 * Only confident identifications count. A low-confidence guess doesn't
 * mark a species as found: the app told the user it didn't know, so
 * ticking it off the list would contradict that and quietly reward
 * uncertain results.
 */
export function useCollectionProgress() {
  const { scans } = useAppData();

  return useMemo(() => {
    const foundIds = new Set(
      scans
        .filter((scan) => scan.speciesId && scan.confidencePercent >= LOW_CONFIDENCE_THRESHOLD)
        .map((scan) => scan.speciesId as string)
    );

    const total = speciesList.length;
    const found = foundIds.size;

    return {
      foundIds,
      found,
      total,
      percent: total === 0 ? 0 : Math.round((found / total) * 100),
      isFound: (speciesId: string) => foundIds.has(speciesId),
    };
  }, [scans]);
}
