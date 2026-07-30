import { EdibilityStatus } from '../theme/colors';

export interface Species {
  id: string;
  commonName: string;
  latinName: string;
  edibilityStatus: EdibilityStatus;
  requiresCooking: boolean;
  prepInstructions?: string;
  lookalikeSpeciesIds: string[];
  toxicityNotes?: string;
  poisoningHistory?: string;
  habitat: string;
  season: string;
  region: string;
  photoUrl: string;
  confidenceNotes?: string;
}

export interface ScanResult {
  id: string;
  photoUrl: string;
  speciesId: string | null;
  confidencePercent: number;
  timestamp: string;
  locationLabel?: string;
  collectionId?: string;
  userNotes?: string;
}

export interface Collection {
  id: string;
  name: string;
  createdAt: string;
  scanIds: string[];
}
