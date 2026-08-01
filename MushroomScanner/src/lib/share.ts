import { Share } from 'react-native';
import { Species } from '../types/models';
import { edibilityPresentation } from '../theme/colors';
import { confidenceLevel, displayEdibilityStatus, LOW_CONFIDENCE_THRESHOLD } from '../utils/confidence';

/**
 * Builds the text for a shared find.
 *
 * Shared text leaves the app and lands somewhere with no disclaimer, no
 * confidence badge, and no context - possibly in front of someone who has
 * never used MushroomScanner. So it carries its own hedging: the
 * confidence figure, the same forced-uncertain rule the Result screen
 * applies, and an explicit "don't eat based on this" line. It must never
 * read as a confident verdict.
 */
export function buildShareMessage(species: Species | null, confidencePercent: number): string {
  const lines: string[] = [];

  if (!species || confidencePercent < LOW_CONFIDENCE_THRESHOLD) {
    const shown = species ? displayEdibilityStatus(species.edibilityStatus, confidencePercent) : 'unknown';
    lines.push('MushroomScanner could not confidently identify this mushroom.');
    if (species) {
      lines.push(`Closest guess: ${species.commonName} (${species.latinName}) - only ${confidencePercent}% confidence.`);
    }
    lines.push(`Status: ${edibilityPresentation[shown].label}`);
    lines.push('');
    lines.push('Do not eat this. A low-confidence result means the app does not know what it is.');
  } else {
    lines.push(`${species.commonName} (${species.latinName})`);
    lines.push(`Status: ${edibilityPresentation[species.edibilityStatus].label}`);
    lines.push(`Confidence: ${confidencePercent}% (${confidenceLevel(confidencePercent)})`);
    if (species.requiresCooking && species.prepInstructions) {
      lines.push('');
      lines.push(`Preparation required: ${species.prepInstructions}`);
    }
    if (species.lookalikeSpeciesIds.length > 0) {
      lines.push('');
      lines.push('This species has dangerous look-alikes - check them before eating anything.');
    }
  }

  lines.push('');
  lines.push(
    'Identified with MushroomScanner. This is a suggestion from an app, not an expert identification - never eat a wild mushroom without confirming it with an experienced forager or a mycological society.'
  );

  return lines.join('\n');
}

export async function shareFind(species: Species | null, confidencePercent: number) {
  await Share.share({ message: buildShareMessage(species, confidencePercent) });
}
