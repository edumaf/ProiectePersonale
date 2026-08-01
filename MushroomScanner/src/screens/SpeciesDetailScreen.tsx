import { Image, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { Card } from '../components/Card';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { PrimaryButton } from '../components/PrimaryButton';
import { CookingMethodsSection } from '../components/CookingMethods';
import { CompanionSpeciesSection } from '../components/CompanionSpecies';
import { useEntitlement } from '../lib/entitlement';
import { getSpeciesById } from '../data/species';
import { colors, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'SpeciesDetail'>;

// Reference view of a species from the Learn/Explore tab or from a
// look-alike link on the Result screen - no scan/confidence involved.
export function SpeciesDetailScreen({ route, navigation }: Props) {
  const species = getSpeciesById(route.params.speciesId);
  const { isPro } = useEntitlement();
  if (!species) return null;

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Image source={{ uri: species.photoUrls[0] }} style={styles.photo} />
        <View style={styles.header}>
          <Text style={[type.h1, { color: colors.ink }]}>{species.commonName}</Text>
          <Text style={[type.latin, { color: colors.charcoal, marginTop: 2 }]}>{species.latinName}</Text>
          <View style={{ marginTop: spacing.sm }}>
            <EdibilityBadge status={species.edibilityStatus} size="large" />
          </View>
        </View>

        {species.requiresCooking && species.prepInstructions && (
          <Card style={styles.section}>
            <SectionTitle icon="local-fire-department" title="Prep required" />
            <Text style={[type.body, { color: colors.ink }]}>{species.prepInstructions}</Text>
          </Card>
        )}

        {species.toxicityNotes && (
          <Card style={styles.section}>
            <SectionTitle icon="science" title="Toxicity notes" />
            <Text style={[type.body, { color: colors.ink }]}>{species.toxicityNotes}</Text>
          </Card>
        )}

        {species.poisoningHistory && (
          <Card style={styles.section}>
            <SectionTitle icon="history-edu" title="Poisoning history" />
            <Text style={[type.body, { color: colors.ink }]}>{species.poisoningHistory}</Text>
          </Card>
        )}

        <CookingMethodsSection species={species} isPro={isPro} />

        <Card style={styles.section}>
          <SectionTitle icon="park" title="Habitat & season" />
          <InfoRow label="Habitat" value={species.habitat} />
          <InfoRow label="Season" value={species.season} />
          <InfoRow label="Region" value={species.region} />
        </Card>

        <CompanionSpeciesSection species={species} isPro={isPro} />

        <View style={styles.section}>
          <PrimaryButton
            label="Ask the AI assistant about this species"
            variant="outline"
            onPress={() => navigation.navigate('AIAssistant', { speciesId: species.id })}
          />
        </View>
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
  header: { padding: spacing.lg },
  section: { marginHorizontal: spacing.lg, marginTop: spacing.md },
  sectionTitleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  sectionTitleText: { color: colors.ink, marginLeft: spacing.xs },
  infoRow: { marginBottom: spacing.sm },
});
