import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { RootStackParamList } from '../navigation/types';
import { PrimaryButton } from '../components/PrimaryButton';
import { useAuth } from '../lib/auth';
import { useConsent } from '../lib/consent';
import { isSupabaseConfigured } from '../lib/config';
import { colors, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Onboarding'>;

// Non-skippable safety consent. Must be accepted before any scan can run.
// Acceptance persists across launches (see src/lib/consent.tsx) - the
// disclaimer only reappears if the copy version is bumped or the user
// reviews it deliberately from the dashboard.
export function OnboardingScreen({ navigation }: Props) {
  const [accepted, setAccepted] = useState(false);
  const { session } = useAuth();
  const { accept } = useConsent();

  async function handleContinue() {
    await accept();
    if (isSupabaseConfigured && !session) {
      navigation.replace('SignIn');
    } else {
      navigation.replace('Main', { screen: 'Dashboard' });
    }
  }

  return (
    <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.content}>
        <MaterialIcons name="eco" size={40} color={colors.moss} />
        <Text style={[type.display, styles.title]}>Before you forage</Text>
        <Text style={[type.body, styles.paragraph]}>
          MushroomScanner helps you narrow down what a wild mushroom might be. It is not a
          certified mycology tool and it can be wrong.
        </Text>

        <View style={styles.rule} />

        <SafetyPoint
          icon="visibility-off"
          text="Never treat an identification as certain. Every result shows a confidence level - low confidence means the app genuinely doesn't know."
        />
        <SafetyPoint
          icon="block"
          text="When in doubt, don't eat it. This applies even to results the app shows as edible."
        />
        <SafetyPoint
          icon="groups"
          text="Always cross-check with an experienced forager or your local mycological society before consuming anything found in the wild."
        />
        <SafetyPoint
          icon="local-hospital"
          text="If you or someone else may have eaten a toxic mushroom, contact poison control or emergency services immediately - don't wait for symptoms."
        />

        <View style={styles.rule} />

        <Text style={[type.caption, styles.legal]}>
          By continuing you acknowledge MushroomScanner is a decision-support aid, not a
          substitute for expert identification, and that you use any identification at your own
          risk. Full terms are available in Settings.
        </Text>

        <PrimaryButton
          label={accepted ? 'Accepted' : 'I have read and accept the above'}
          variant="outline"
          onPress={() => setAccepted(true)}
          disabled={accepted}
        />
        <View style={{ height: spacing.sm }} />
        <PrimaryButton label="Continue" onPress={handleContinue} disabled={!accepted} />
      </ScrollView>
    </SafeAreaView>
  );
}

function SafetyPoint({ icon, text }: { icon: keyof typeof MaterialIcons.glyphMap; text: string }) {
  return (
    <View style={styles.point}>
      <MaterialIcons name={icon} size={22} color={colors.bark} style={styles.pointIcon} />
      <Text style={[type.body, styles.pointText]}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  title: { color: colors.ink, marginTop: spacing.md, marginBottom: spacing.sm },
  paragraph: { color: colors.charcoal, marginBottom: spacing.md },
  rule: { height: 1, backgroundColor: colors.hairline, marginVertical: spacing.md },
  point: { flexDirection: 'row', marginBottom: spacing.md, alignItems: 'flex-start' },
  pointIcon: { marginRight: spacing.sm, marginTop: 2 },
  pointText: { flex: 1, color: colors.ink },
  legal: { color: colors.fog, marginBottom: spacing.lg },
});
