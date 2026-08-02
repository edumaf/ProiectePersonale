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

/** Statuses where the user needs to know a match was suspected, even unconfirmed. */
const HAZARDOUS_STATUSES: EdibilityStatus[] = ['deadly', 'toxic'];

/**
 * Whether a below-threshold guess still needs to be named to the user.
 *
 * `displayEdibilityStatus` deliberately withholds the verdict below the
 * threshold - but withholding it *entirely* creates a worse problem than
 * it solves. If the model's closest match is Death Cap at 72%, the user
 * would otherwise see a bland "Unknown - do not consume" and never learn
 * that a deadly species was suspected.
 *
 * Those two messages produce very different behaviour. "Unknown" leaves a
 * specimen in the basket next to tonight's dinner, to be re-examined
 * later. "This might be a Death Cap" gets it thrown out and hands washed.
 *
 * The asymmetry justifies it: warning wrongly costs the user one mushroom,
 * while staying quiet can cost a life. So the badge stays honestly
 * uncertain, and this adds a named hazard warning alongside it.
 */
export function suspectedHazard(
  rawStatus: EdibilityStatus | null | undefined,
  confidencePercent: number
): { isSuspected: boolean; status: EdibilityStatus | null } {
  if (!rawStatus) return { isSuspected: false, status: null };
  // Above the threshold the real badge already says "Deadly" in full -
  // no extra warning needed.
  if (confidencePercent >= LOW_CONFIDENCE_THRESHOLD) return { isSuspected: false, status: null };
  if (!HAZARDOUS_STATUSES.includes(rawStatus)) return { isSuspected: false, status: null };
  return { isSuspected: true, status: rawStatus };
}
