import { Image, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { Card } from '../components/Card';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { ConfidenceBadge } from '../components/ConfidenceBadge';
import { PrimaryButton } from '../components/PrimaryButton';
import { mockScans } from '../data/mockScans';
import { getSpeciesById } from '../data/mockSpecies';
import { defaultPoisonControl } from '../data/poisonControl';
import { confidenceLevel, displayEdibilityStatus, LOW_CONFIDENCE_THRESHOLD } from '../utils/confidence';
import { colors, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Result'>;

export function ResultScreen({ route, navigation }: Props) {
  const scan = mockScans.find((s) => s.id === route.params.scanId) ?? mockScans[0];
  const species = getSpeciesById(scan.speciesId);
  const isUncertain = !species || scan.confidencePercent < LOW_CONFIDENCE_THRESHOLD;
  const shownStatus = species ? displayEdibilityStatus(species.edibilityStatus, scan.confidencePercent) : 'unknown';
  const lookalikes = species
    ? species.lookalikeSpeciesIds.map((id) => getSpeciesById(id)).filter(Boolean)
    : [];

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Image source={{ uri: scan.photoUrl }} style={styles.photo} />

        <View style={styles.header}>
          {species ? (
            <>
              <Text style={[type.h1, styles.commonName]}>{species.commonName}</Text>
              <Text style={[type.latin, styles.latinName]}>{species.latinName}</Text>
            </>
          ) : (
            <Text style={[type.h1, styles.commonName]}>Unidentified species</Text>
          )}
          <View style={styles.confidenceRow}>
            <ConfidenceBadge level={confidenceLevel(scan.confidencePercent)} percent={scan.confidencePercent} />
          </View>
        </View>

        <EdibilityBadge status={shownStatus} size="large" />

        {isUncertain && (
          <Card style={styles.warningCard}>
            <MaterialIcons name="report-problem" size={20} color={colors.deadly} />
            <Text style={[type.body, styles.warningText]}>
              Confidence is below {LOW_CONFIDENCE_THRESHOLD}%. Do not consume this specimen based on
              this result - get it checked by an experienced forager or mycological society.
            </Text>
          </Card>
        )}

        {species && species.requiresCooking && species.prepInstructions && (
          <Card style={styles.section}>
            <SectionTitle icon="local-fire-department" title="Prep required" />
            <Text style={[type.body, { color: colors.ink }]}>{species.prepInstructions}</Text>
          </Card>
        )}

        {lookalikes.length > 0 && (
          <Card style={styles.section}>
            <SectionTitle icon="compare" title="Dangerous look-alikes" />
            {lookalikes.map((look) => (
              <TouchableOpacity
                key={look!.id}
                style={styles.lookalikeRow}
                onPress={() => navigation.push('SpeciesDetail', { speciesId: look!.id })}
              >
                <Image source={{ uri: look!.photoUrl }} style={styles.lookalikeThumb} />
                <View style={styles.lookalikeInfo}>
                  <Text style={[type.bodyMedium, { color: colors.ink }]}>{look!.commonName}</Text>
                  <Text style={[type.latin, { color: colors.fog, fontSize: 13 }]}>{look!.latinName}</Text>
                  <EdibilityBadge status={look!.edibilityStatus} size="small" />
                </View>
              </TouchableOpacity>
            ))}
          </Card>
        )}

        {species?.poisoningHistory && (
          <Card style={styles.section}>
            <SectionTitle icon="history-edu" title="Poisoning history" />
            <Text style={[type.body, { color: colors.ink }]}>{species.poisoningHistory}</Text>
            <Text style={[type.caption, styles.sourceCaption]}>
              Source: mycological literature and poison-control publications.
            </Text>
          </Card>
        )}

        {species && (
          <Card style={styles.section}>
            <SectionTitle icon="park" title="Habitat & season" />
            <InfoRow label="Habitat" value={species.habitat} />
            <InfoRow label="Season" value={species.season} />
            <InfoRow label="Region" value={species.region} />
          </Card>
        )}

        <Card style={styles.poisonCard}>
          <MaterialIcons name="local-hospital" size={22} color={colors.deadly} />
          <View style={{ marginLeft: spacing.sm }}>
            <Text style={[type.bodyMedium, { color: colors.deadly }]}>
              Poison Control - {defaultPoisonControl.country}
            </Text>
            <Text style={[type.body, { color: colors.ink }]}>{defaultPoisonControl.phone}</Text>
          </View>
        </Card>

        {species && (
          <PrimaryButton
            label="Ask the AI assistant about this species"
            variant="outline"
            onPress={() => navigation.navigate('AIAssistant', { speciesId: species.id })}
          />
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

function SectionTitle({ icon, title }: { icon: keyof typeof MaterialIcons.glyphMap; title: string }) {
  return (
    <View style={styles.sectionTitleRow}>
      <MaterialIcons name={icon} size={18} color={colors.mossDark} />
      <Text style={[type.h2, styles.sectionTitleText]}>{title}</Text>
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={[type.label, { color: colors.fog }]}>{label}</Text>
      <Text style={[type.body, { color: colors.ink }]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  content: { paddingBottom: spacing.xxl },
  photo: { width: '100%', height: 280 },
  header: { padding: spacing.lg, paddingBottom: spacing.md },
  commonName: { color: colors.ink },
  latinName: { color: colors.charcoal, marginTop: 2 },
  confidenceRow: { marginTop: spacing.sm },
  warningCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: colors.deadlyBg,
    borderColor: colors.deadlyBg,
    marginHorizontal: spacing.lg,
    marginTop: spacing.md,
  },
  warningText: { flex: 1, color: colors.ink, marginLeft: spacing.sm },
  section: { marginHorizontal: spacing.lg, marginTop: spacing.md },
  sectionTitleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  sectionTitleText: { color: colors.ink, marginLeft: spacing.xs },
  sourceCaption: { color: colors.fog, marginTop: spacing.xs },
  lookalikeRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.md },
  lookalikeThumb: { width: 56, height: 56, borderRadius: 10, marginRight: spacing.sm },
  lookalikeInfo: { flex: 1 },
  infoRow: { marginBottom: spacing.sm },
  poisonCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.deadlyBg,
    borderColor: colors.deadlyBg,
    marginHorizontal: spacing.lg,
    marginTop: spacing.md,
    marginBottom: spacing.lg,
  },
});
