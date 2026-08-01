import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { PrimaryButton } from '../components/PrimaryButton';
import { Card } from '../components/Card';
import { useEntitlement } from '../lib/entitlement';
import { colors, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'Paywall'>;

const proFeatures: Array<{ icon: keyof typeof MaterialIcons.glyphMap; title: string; detail: string }> = [
  { icon: 'all-inclusive', title: 'Unlimited scans', detail: 'Free plan covers 5 identifications a month.' },
  {
    icon: 'compare',
    title: 'Full look-alike comparisons',
    detail: 'Side-by-side photos and the details that separate a safe find from a dangerous one.',
  },
  {
    icon: 'history-edu',
    title: 'Complete toxicity & poisoning history',
    detail: 'Sourced notes on what each species has actually been responsible for.',
  },
  { icon: 'forum', title: 'AI assistant', detail: 'Ask follow-up questions about any species you look at.' },
  { icon: 'collections-bookmark', title: 'Unlimited collections', detail: 'Free plan includes one saved collection.' },
];

export function PaywallScreen({ route, navigation }: Props) {
  const { scansUsed, scansLimit } = useEntitlement();
  const [purchaseNotice, setPurchaseNotice] = useState(false);
  const hitLimit = route.params?.reason === 'scan_limit';

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <ScrollView contentContainerStyle={styles.content}>
        <MaterialIcons name="workspace-premium" size={40} color={colors.clay} />
        <Text style={[type.display, styles.title]}>MushroomScanner Pro</Text>

        {hitLimit ? (
          <Card style={styles.limitCard}>
            <Text style={[type.bodyMedium, { color: colors.bark }]}>
              You've used all {scansLimit ?? 5} free scans this month.
            </Text>
            <Text style={[type.body, { color: colors.charcoal, marginTop: spacing.xs }]}>
              Your free scans reset at the start of next month, or upgrade for unlimited access now.
            </Text>
          </Card>
        ) : (
          <Text style={[type.body, styles.subtitle]}>
            {scansLimit === null
              ? 'You have unlimited scans.'
              : `You've used ${scansUsed} of ${scansLimit} free scans this month.`}
          </Text>
        )}

        {proFeatures.map((feature) => (
          <View key={feature.title} style={styles.feature}>
            <MaterialIcons name={feature.icon} size={22} color={colors.moss} style={styles.featureIcon} />
            <View style={styles.featureText}>
              <Text style={[type.bodyMedium, { color: colors.ink }]}>{feature.title}</Text>
              <Text style={[type.caption, { color: colors.fog }]}>{feature.detail}</Text>
            </View>
          </View>
        ))}

        <Card style={styles.safetyCard}>
          <MaterialIcons name="info" size={18} color={colors.charcoal} />
          <Text style={[type.caption, styles.safetyText]}>
            Pro unlocks more detail and more scans - it does not make an identification any more
            certain. The same safety rules apply on every plan: when in doubt, don't eat it.
          </Text>
        </Card>

        {/* TODO(pre-launch): wire to real in-app purchases (RevenueCat, or
            StoreKit 2 + Play Billing directly). Nothing here charges money
            yet - see README's monetization section. */}
        <PrimaryButton label="Upgrade to Pro" onPress={() => setPurchaseNotice(true)} />
        {purchaseNotice && (
          <Text style={[type.caption, styles.notice]}>
            In-app purchases aren't connected yet. To test Pro features, set your profile's tier to
            'pro' in the Supabase dashboard.
          </Text>
        )}
        <View style={{ height: spacing.sm }} />
        <PrimaryButton label="Not now" variant="outline" onPress={() => navigation.goBack()} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  title: { color: colors.ink, marginTop: spacing.sm, marginBottom: spacing.sm },
  subtitle: { color: colors.charcoal, marginBottom: spacing.lg },
  limitCard: { backgroundColor: colors.edibleCookedBg, borderColor: colors.edibleCookedBg, marginBottom: spacing.lg },
  feature: { flexDirection: 'row', alignItems: 'flex-start', marginBottom: spacing.md },
  featureIcon: { marginRight: spacing.sm, marginTop: 2 },
  featureText: { flex: 1 },
  safetyCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: colors.inedibleBg,
    borderColor: colors.inedibleBg,
    marginTop: spacing.sm,
    marginBottom: spacing.lg,
  },
  safetyText: { flex: 1, color: colors.charcoal, marginLeft: spacing.sm },
  notice: { color: colors.fog, textAlign: 'center', marginTop: spacing.sm },
});
