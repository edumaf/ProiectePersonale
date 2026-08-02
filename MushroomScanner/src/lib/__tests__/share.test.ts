import { buildShareMessage } from '../share';
import { getSpeciesById } from '../../data/species';
import { LOW_CONFIDENCE_THRESHOLD } from '../../utils/confidence';

// Shared text lands in a chat with no confidence badge, no disclaimer, and
// possibly in front of someone who has never opened the app. It has to
// carry its own hedging - these tests hold it to that.

const chanterelle = getSpeciesById('chanterelle')!;
const deathCap = getSpeciesById('death-cap')!;
const morel = getSpeciesById('morel')!;

describe('buildShareMessage', () => {
  it('always carries the app disclaimer, whatever the result', () => {
    const cases = [
      buildShareMessage(chanterelle, 95),
      buildShareMessage(chanterelle, 20),
      buildShareMessage(deathCap, 99),
      buildShareMessage(null, 10),
    ];
    for (const message of cases) {
      expect(message).toContain('not an expert identification');
      expect(message.toLowerCase()).toContain('mycological society');
    }
  });

  describe('below the confidence threshold', () => {
    const message = buildShareMessage(chanterelle, LOW_CONFIDENCE_THRESHOLD - 1);

    it('says outright that it could not identify the mushroom', () => {
      expect(message).toContain('could not confidently identify');
    });

    it('tells the recipient not to eat it', () => {
      expect(message).toContain('Do not eat this');
    });

    it('does not present the edibility verdict', () => {
      // The species is edible, but at low confidence that must not leak
      // into the shared text as a verdict.
      expect(message).toContain('Unknown / Uncertain');
      expect(message).not.toMatch(/Status: Edible/);
    });

    it('marks the species name as a guess, not a conclusion', () => {
      expect(message).toContain('Closest guess');
      expect(message).toContain(`${LOW_CONFIDENCE_THRESHOLD - 1}% confidence`);
    });
  });

  describe('at or above the confidence threshold', () => {
    const message = buildShareMessage(chanterelle, 95);

    it('names the species and its status', () => {
      expect(message).toContain('Chanterelle');
      expect(message).toContain('Cantharellus cibarius');
      expect(message).toContain('Status: Edible');
    });

    it('still states the confidence figure rather than implying certainty', () => {
      expect(message).toContain('95%');
    });

    it('warns that dangerous look-alikes exist', () => {
      expect(message).toContain('dangerous look-alikes');
    });
  });

  it('carries prep requirements for species that need cooking', () => {
    const message = buildShareMessage(morel, 95);
    expect(message).toContain('Preparation required');
    expect(message).toContain('never eat raw');
  });

  it('warns that a low-confidence deadly match is deadly', () => {
    // Naming "Death Cap" isn't enough - a recipient who doesn't recognise
    // the name needs to be told what it means.
    const message = buildShareMessage(deathCap, 72);
    expect(message).toContain('Death Cap');
    expect(message).toContain('DEADLY');
    expect(message).toContain('keep it away from anything you plan to eat');
  });

  it('warns on a low-confidence toxic match too', () => {
    const jackOLantern = getSpeciesById('jack-o-lantern')!;
    const message = buildShareMessage(jackOLantern, 60);
    expect(message).toContain('TOXIC');
  });

  it('does not add a hazard warning for a low-confidence edible match', () => {
    const message = buildShareMessage(chanterelle, 60);
    expect(message).not.toContain('DEADLY');
    expect(message).not.toContain('TOXIC');
  });

  it('handles an unidentified scan without inventing a species', () => {
    const message = buildShareMessage(null, 30);
    expect(message).toContain('could not confidently identify');
    expect(message).toContain('Do not eat this');
    expect(message).not.toContain('Closest guess');
  });

  it('never claims certainty, at any confidence level', () => {
    for (const percent of [0, 50, 85, 99, 100]) {
      const message = buildShareMessage(chanterelle, percent);
      expect(message.toLowerCase()).not.toMatch(/\b(definitely|certainly|guaranteed|100% safe|safe to eat)\b/);
    }
  });

  it('does not soften a deadly species at high confidence', () => {
    const message = buildShareMessage(deathCap, 96);
    expect(message).toContain('Status: Deadly');
  });
});
