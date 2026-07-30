import { EdibilityStatus } from '../theme/colors';
import { ConfidenceLevel } from '../components/ConfidenceBadge';

// Configurable low-confidence safety threshold. Below this, the app forces
// an "uncertain, do not consume" state regardless of the model's raw guess.
export const LOW_CONFIDENCE_THRESHOLD = 85;

export function confidenceLevel(percent: number): ConfidenceLevel {
  if (percent >= LOW_CONFIDENCE_THRESHOLD) return 'high';
  if (percent >= 60) return 'medium';
  return 'low';
}

// The edibility status actually shown to the user: below the safety
// threshold, real status is withheld and the result is forced to unknown.
export function displayEdibilityStatus(rawStatus: EdibilityStatus, confidencePercent: number): EdibilityStatus {
  if (confidencePercent < LOW_CONFIDENCE_THRESHOLD) return 'unknown';
  return rawStatus;
}
