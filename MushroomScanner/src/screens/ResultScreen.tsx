import { ActivityIndicator, Dimensions, Image, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { Card } from '../components/Card';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { ConfidenceBadge } from '../components/ConfidenceBadge';
import { PrimaryButton } from '../components/PrimaryButton';
import { useScan } from '../hooks/useScan';
import { getSpeciesById } from '../data/species';
import { defaultPoisonControl } from '../data/poisonControl';
import { confidenceLevel, displayEdibilityStatus, LOW_CONFIDENCE_THRESHOLD } from '../utils/confidence';
import { colors, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Result'>;

const angleLabels: Record<string, string> = {
  cap: 'Cap',
  gills: 'Gills / underside',
  stem_base: 'Stem base',
};

export function ResultScreen({ route, navigation }: Props) {
  const { scan, loading } = useScan(route.params.scanId);

  if (loading || !scan) {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.loadingCenter}>
          <ActivityIndicator size="large" color={colors.moss} />
        </View>
      </SafeAreaView>
    );
  }

  const species = getSpeciesById(scan.speciesId);
  const isUncertain = !species || scan.confidencePercent < LOW_CONFIDENCE_THRESHOLD;
  const shownStatus = species ? displayEdibilityStatus(species.edibilityStatus, scan.confidencePercent) : 'unknown';
  const lookalikes = species
    ? species.lookalikeSpeciesIds.map((id) => getSpeciesById(id)).filter(Boolean)
    : [];

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <ScrollView contentContainerStyle={styles.content}>
        <ScrollView horizontal pagingEnabled showsHorizontalScrollIndicator={false}>
          {scan.photos.map((photo, i) => (
            <View key={i} style={styles.photoSlide}>
              <Image source={{ uri: photo.url }} style={styles.photo} />
              <View style={styles.angleTag}>
                <Text style={[type.label, { color: colors.white }]}>{angleLabels[photo.angle] ?? photo.angle}</Text>
              </View>
            </View>
          ))}
        </ScrollView>

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
            <Text style={[type.caption, styles.lookalikeIntro]}>
              Compare your photo (left) against each look-alike before deciding anything.
            </Text>
            {lookalikes.map((look) => (
              <TouchableOpacity
                key={look!.id}
                style={styles.lookalikeCard}
                onPress={() => navigation.push('SpeciesDetail', { speciesId: look!.id })}
              >
                <View style={styles.compareRow}>
                  <View style={styles.compareSide}>
                    <Image source={{ uri: scan.photos[0].url }} style={styles.compareThumb} />
                    <Text style={[type.caption, styles.compareCaption]}>Your find</Text>
                  </View>
                  <MaterialIcons name="compare-arrows" size={20} color={colors.fog} style={styles.compareIcon} />
                  <View style={styles.compareSide}>
                    <Image source={{ uri: look!.photoUrls[0] }} style={styles.compareThumb} />
                    <Text style={[type.caption, styles.compareCaption]} numberOfLines={1}>
                      {look!.commonName}
                    </Text>
                  </View>
                </View>
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

const screenWidth = Dimensions.get('window').width;

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  loadingCenter: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  content: { paddingBottom: spacing.xxl },
  photoSlide: { width: screenWidth, height: 280 },
  photo: { width: '100%', height: 280 },
  angleTag: {
    position: 'absolute',
    left: spacing.md,
    bottom: spacing.md,
    backgroundColor: 'rgba(36,28,21,0.72)',
    borderRadius: 999,
    paddingVertical: 4,
    paddingHorizontal: spacing.sm,
  },
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
  lookalikeIntro: { color: colors.fog, marginBottom: spacing.sm },
  lookalikeCard: {
    marginBottom: spacing.md,
    paddingBottom: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.hairline,
  },
  compareRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.xs },
  compareSide: { flex: 1, alignItems: 'center' },
  compareThumb: { width: '100%', aspectRatio: 1, borderRadius: 10, maxWidth: 120 },
  compareCaption: { color: colors.fog, marginTop: 4 },
  compareIcon: { marginHorizontal: spacing.sm },
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
