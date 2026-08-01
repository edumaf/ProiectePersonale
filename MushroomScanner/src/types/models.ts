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
  /** Reference photos, ordered; first is the cover image. */
  photoUrls: string[];
  confidenceNotes?: string;
  /**
   * Culinary preparation. Only present on edible/edible_cooked species -
   * never populate this for a toxic one. This is flavour/technique advice
   * layered on top of prepInstructions, which carries the safety-critical
   * requirements and always takes precedence.
   */
  cookingMethods?: CookingMethod[];
}

export interface CookingMethod {
  method: string;
  detail: string;
}

export type ScanAngle = 'cap' | 'gills' | 'stem_base';

export interface ScanPhoto {
  angle: ScanAngle;
  url: string;
}

export interface ScanResult {
  id: string;
  /** Photos captured for this scan, ordered; first is the cover image. */
  photos: ScanPhoto[];
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
