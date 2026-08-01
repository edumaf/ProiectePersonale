import { StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { Card } from './Card';
import { ProLock } from './ProLock';
import { Species } from '../types/models';
import { colors, spacing, type } from '../theme';

/**
 * Culinary preparation, Pro-gated.
 *
 * Only rendered for species the data marks edible - the seed generator and
 * a DB check constraint both refuse to attach cookingMethods to anything
 * else, and this guards a third time at render. Safety-critical prep
 * (prepInstructions) is shown separately and is never gated.
 */
export function CookingMethodsSection({ species, isPro }: { species: Species; isPro: boolean }) {
  const isEdible = species.edibilityStatus === 'edible' || species.edibilityStatus === 'edible_cooked';
  if (!isEdible || !species.cookingMethods?.length) return null;

  if (!isPro) {
    return (
      <View style={styles.lockWrap}>
        <ProLock
          title="How to cook it"
          description={`Pro includes ${species.cookingMethods.length} preparation methods for ${species.commonName}, from technique to storage.`}
        />
      </View>
    );
  }

  return (
    <Card style={styles.card}>
      <View style={styles.titleRow}>
        <MaterialIcons name="restaurant" size={18} color={colors.mossDark} />
        <Text style={[type.h2, styles.titleText]}>How to cook it</Text>
      </View>

      {species.cookingMethods.map((entry) => (
        <View key={entry.method} style={styles.method}>
          <Text style={[type.bodyMedium, { color: colors.ink }]}>{entry.method}</Text>
          <Text style={[type.body, styles.detail]}>{entry.detail}</Text>
        </View>
      ))}

      <Text style={[type.caption, styles.footnote]}>
        Cooking advice assumes the identification is correct and the specimen is in good condition.
        It does not make an uncertain find safe to eat.
      </Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { marginHorizontal: spacing.lg, marginTop: spacing.md },
  lockWrap: { marginHorizontal: spacing.lg, marginTop: spacing.md },
  titleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  titleText: { color: colors.ink, marginLeft: spacing.xs },
  method: { marginBottom: spacing.md },
  detail: { color: colors.charcoal, marginTop: 2 },
  footnote: { color: colors.fog, borderTopWidth: 1, borderTopColor: colors.hairline, paddingTop: spacing.sm },
});
