import { Collection, ScanResult } from '../types/models';

// Placeholder mock data for the static-mockup phase (build step 1).
export const mockScans: ScanResult[] = [
  {
    id: 'scan-1',
    photoUrl: 'https://picsum.photos/seed/chanterelle/800/800',
    speciesId: 'chanterelle',
    confidencePercent: 92,
    timestamp: '2026-07-28T09:14:00Z',
    locationLabel: 'Bucegi foothills',
    collectionId: 'trip-bucegi',
  },
  {
    id: 'scan-2',
    photoUrl: 'https://picsum.photos/seed/porcini/800/800',
    speciesId: 'porcini',
    confidencePercent: 88,
    timestamp: '2026-07-28T09:40:00Z',
    locationLabel: 'Bucegi foothills',
    collectionId: 'trip-bucegi',
  },
  {
    id: 'scan-3',
    photoUrl: 'https://picsum.photos/seed/death-cap/800/800',
    speciesId: 'death-cap',
    confidencePercent: 79,
    timestamp: '2026-07-20T16:02:00Z',
    locationLabel: 'Home garden',
  },
  {
    id: 'scan-4',
    photoUrl: 'https://picsum.photos/seed/mystery/800/800',
    speciesId: null,
    confidencePercent: 41,
    timestamp: '2026-07-15T11:22:00Z',
  },
];

export const mockCollections: Collection[] = [
  { id: 'trip-bucegi', name: 'Bucegi Weekend Trip', createdAt: '2026-07-28T08:00:00Z', scanIds: ['scan-1', 'scan-2'] },
  { id: 'backyard', name: 'Backyard Watch', createdAt: '2026-06-01T08:00:00Z', scanIds: [] },
];
