import {
  confidenceLevel,
  displayEdibilityStatus,
  suspectedHazard,
  LOW_CONFIDENCE_THRESHOLD,
} from '../confidence';
import { EdibilityStatus } from '../../theme/colors';

// These tests guard the app's central safety rule: below the confidence
// threshold, the user must never be shown an edibility verdict. A silent
// regression here (an inverted comparison, an off-by-one) would show
// "Edible" for a guess the model wasn't confident about.

const ALL_STATUSES: EdibilityStatus[] = [
  'edible',
  'edible_cooked',
  'toxic',
  'deadly',
  'inedible',
  'unknown',
];

describe('displayEdibilityStatus', () => {
  it('forces unknown for every status below the threshold', () => {
    for (const status of ALL_STATUSES) {
      expect(displayEdibilityStatus(status, LOW_CONFIDENCE_THRESHOLD - 1)).toBe('unknown');
    }
  });

  it('passes the real status through at or above the threshold', () => {
    for (const status of ALL_STATUSES) {
      expect(displayEdibilityStatus(status, LOW_CONFIDENCE_THRESHOLD)).toBe(status);
      expect(displayEdibilityStatus(status, 100)).toBe(status);
    }
  });

  it('treats the threshold itself as confident, not uncertain', () => {
    expect(displayEdibilityStatus('edible', LOW_CONFIDENCE_THRESHOLD)).toBe('edible');
  });

  it('never reveals an edible verdict at low confidence', () => {
    // The specific failure that matters most: a user seeing "Edible" on a
    // guess the app isn't sure about.
    for (const percent of [0, 1, 42, 60, 84]) {
      expect(displayEdibilityStatus('edible', percent)).toBe('unknown');
      expect(displayEdibilityStatus('edible_cooked', percent)).toBe('unknown');
    }
  });

  it('also withholds deadly at low confidence, so the badge matches the warning', () => {
    // Showing "Deadly" at 40% would be a *safe* error, but it contradicts
    // the "we don't know" message shown alongside it. Consistency matters:
    // the badge and the warning text must tell the same story.
    expect(displayEdibilityStatus('deadly', 40)).toBe('unknown');
  });
});

describe('confidenceLevel', () => {
  it('labels at-or-above threshold as high', () => {
    expect(confidenceLevel(LOW_CONFIDENCE_THRESHOLD)).toBe('high');
    expect(confidenceLevel(100)).toBe('high');
  });

  it('labels the 60-84 band as medium', () => {
    expect(confidenceLevel(60)).toBe('medium');
    expect(confidenceLevel(LOW_CONFIDENCE_THRESHOLD - 1)).toBe('medium');
  });

  it('labels below 60 as low', () => {
    expect(confidenceLevel(59)).toBe('low');
    expect(confidenceLevel(0)).toBe('low');
  });

  it('never reports high for anything the threshold would reject', () => {
    // These two must stay in lockstep - a "high confidence" badge next to
    // a forced-uncertain result would be incoherent.
    for (let percent = 0; percent < LOW_CONFIDENCE_THRESHOLD; percent++) {
      expect(confidenceLevel(percent)).not.toBe('high');
      expect(displayEdibilityStatus('edible', percent)).toBe('unknown');
    }
  });
});

describe('suspectedHazard', () => {
  it('flags a deadly species guessed below the threshold', () => {
    // The case this exists for: the model's closest match is a Death Cap
    // at 72%. The badge stays "Uncertain", but the user must still be
    // told a deadly species was suspected.
    const result = suspectedHazard('deadly', 72);
    expect(result.isSuspected).toBe(true);
    expect(result.status).toBe('deadly');
  });

  it('flags a toxic species guessed below the threshold', () => {
    expect(suspectedHazard('toxic', 50).isSuspected).toBe(true);
  });

  it('stays quiet above the threshold, where the real badge already says it', () => {
    expect(suspectedHazard('deadly', LOW_CONFIDENCE_THRESHOLD).isSuspected).toBe(false);
    expect(suspectedHazard('deadly', 99).isSuspected).toBe(false);
  });

  it('does not fire for non-hazardous species', () => {
    for (const status of ['edible', 'edible_cooked', 'inedible', 'unknown'] as EdibilityStatus[]) {
      expect(suspectedHazard(status, 50).isSuspected).toBe(false);
    }
  });

  it('handles a missing species without throwing', () => {
    expect(suspectedHazard(null, 50).isSuspected).toBe(false);
    expect(suspectedHazard(undefined, 50).isSuspected).toBe(false);
  });

  it('fires across the whole low-confidence range for deadly species', () => {
    // There is no confidence so low that "it might be a Death Cap" stops
    // being worth saying.
    for (let percent = 0; percent < LOW_CONFIDENCE_THRESHOLD; percent++) {
      expect(suspectedHazard('deadly', percent).isSuspected).toBe(true);
    }
  });

  it('complements displayEdibilityStatus rather than contradicting it', () => {
    // The badge must stay honestly uncertain even while the hazard
    // warning names the species - these two work together.
    const percent = 70;
    expect(displayEdibilityStatus('deadly', percent)).toBe('unknown');
    expect(suspectedHazard('deadly', percent).isSuspected).toBe(true);
  });
});

describe('LOW_CONFIDENCE_THRESHOLD', () => {
  it('is within a sane range', () => {
    // Guards against someone "tuning" it to 0 (everything confident) or
    // above 100 (nothing ever confident) while chasing a demo.
    expect(LOW_CONFIDENCE_THRESHOLD).toBeGreaterThan(50);
    expect(LOW_CONFIDENCE_THRESHOLD).toBeLessThanOrEqual(100);
  });
});
