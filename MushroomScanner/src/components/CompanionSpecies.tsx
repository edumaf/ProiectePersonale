import { Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { Card } from './Card';
import { EdibilityBadge } from './EdibilityBadge';
import { ProLock } from './ProLock';
import { Species } from '../types/models';
import { findCompanions, CompanionSpecies as Companion } from '../utils/companions';
import { colors, spacing, type } from '../theme';

/**
 * "What else grows here" for a species.
 *
 * Free users still see the hazard list - a heads-up that something deadly
 * shares this habitat is safety information, not a premium perk. Pro adds
 * the edible companions, which is the foraging-convenience half.
 */
export function CompanionSpeciesSection({ species, isPro }: { species: Species; isPro: boolean }) {
  const { hazards, edibles } = findCompanions(species);
  if (hazards.length === 0 && edibles.length === 0) return null;

  return (
    <Card style={styles.card}>
      <View style={styles.titleRow}>
        <MaterialIcons name="travel-explore" size={18} color={colors.mossDark} />
        <Text style={[type.h2, styles.titleText]}>Also grows here</Text>
      </View>
      <Text style={[type.caption, styles.intro]}>
        Species sharing this habitat and region - you may run into them on the same walk.
      </Text>

      {hazards.length > 0 && (
        <>
          <Text style={[type.label, styles.groupLabel, { color: colors.deadly }]}>Take care</Text>
          {hazards.map((entry) => (
            <CompanionRow key={entry.species.id} entry={entry} />
          ))}
        </>
      )}

      {edibles.length > 0 &&
        (isPro ? (
          <>
            <Text style={[type.label, styles.groupLabel, { color: colors.mossDark }]}>Also edible</Text>
            {edibles.map((entry) => (
              <CompanionRow key={entry.species.id} entry={entry} />
            ))}
          </>
        ) : (
          <View style={{ marginTop: spacing.sm }}>
            <ProLock
              title={`${edibles.length} more edible species grow here`}
              description="Pro shows the other edibles sharing this habitat and season, so you know what else is worth looking for."
            />
          </View>
        ))}
    </Card>
  );
}

function CompanionRow({ entry }: { entry: Companion }) {
  const navigation = useNavigation<any>();
  const { species, sameSeason } = entry;

  return (
    <TouchableOpacity
      style={styles.row}
      onPress={() => navigation.push('SpeciesDetail', { speciesId: species.id })}
    >
      <Image source={{ uri: species.photoUrls[0] }} style={styles.thumb} />
      <View style={styles.info}>
        <Text style={[type.bodyMedium, { color: colors.ink }]}>{species.commonName}</Text>
        <Text style={[type.caption, { color: colors.fog }]}>
          {sameSeason ? 'Same season' : species.season}
        </Text>
        <EdibilityBadge status={species.edibilityStatus} size="small" />
      </View>
      <MaterialIcons name="chevron-right" size={20} color={colors.fog} />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: { marginHorizontal: spacing.lg, marginTop: spacing.md },
  titleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.xs },
  titleText: { color: colors.ink, marginLeft: spacing.xs },
  intro: { color: colors.fog, marginBottom: spacing.sm },
  groupLabel: { marginTop: spacing.sm, marginBottom: spacing.xs },
  row: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  thumb: { width: 48, height: 48, borderRadius: 8, marginRight: spacing.sm },
  info: { flex: 1 },
});
