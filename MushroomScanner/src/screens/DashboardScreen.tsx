import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { CompositeScreenProps } from '@react-navigation/native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { Card } from '../components/Card';
import { useAppData } from '../hooks/useAppData';
import { useCollectionProgress } from '../hooks/useCollectionProgress';
import { useAuth } from '../lib/auth';
import { isSupabaseConfigured } from '../lib/config';
import { getSpeciesById } from '../data/species';
import { PoisonControlCard } from '../components/PoisonControlCard';
import { colors, spacing, type } from '../theme';

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, 'Dashboard'>,
  NativeStackScreenProps<RootStackParamList>
>;

const safetyTip = 'Always check the base of the stem for a volva or sac - many deadly Amanita species hide it underground.';

export function DashboardScreen({ navigation }: Props) {
  const { scans, isDemo, loading, refresh } = useAppData();
  const { session, signOut } = useAuth();
  const progress = useCollectionProgress();
  const recentScans = scans.slice(0, 3);

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={refresh} tintColor={colors.moss} />}
      >
        <View style={styles.headerRow}>
          <Text style={[type.display, styles.title]}>MushroomScanner</Text>
          {isSupabaseConfigured && session && (
            <TouchableOpacity onPress={() => signOut()}>
              <MaterialIcons name="logout" size={22} color={colors.fog} />
            </TouchableOpacity>
          )}
        </View>

        {isDemo && (
          <Text style={[type.caption, styles.demoTag]}>
            {isSupabaseConfigured ? 'Showing demo data - sign in to save your own scans.' : 'Demo mode - backend not configured.'}
          </Text>
        )}

        <View style={styles.statsRow}>
          <Card style={styles.statCard}>
            <Text style={[type.h1, styles.statNumber]}>{progress.found}</Text>
            <Text style={[type.caption, styles.statLabel]}>Species found</Text>
          </Card>
          <Card style={styles.statCard}>
            <Text style={[type.h1, styles.statNumber]}>{scans.length}</Text>
            <Text style={[type.caption, styles.statLabel]}>Total scans</Text>
          </Card>
        </View>

        <TouchableOpacity onPress={() => navigation.navigate('Learn')} activeOpacity={0.85}>
          <Card style={styles.progressCard}>
            <View style={styles.progressHeader}>
              <Text style={[type.bodyMedium, { color: colors.ink }]}>Your collection</Text>
              <Text style={[type.caption, { color: colors.fog }]}>
                {progress.found} of {progress.total}
              </Text>
            </View>
            <View style={styles.progressTrack}>
              <View style={[styles.progressFill, { width: `${progress.percent}%` }]} />
            </View>
            <Text style={[type.caption, styles.progressHint]}>
              {progress.found === 0
                ? 'Species you confidently identify get added here.'
                : `${progress.percent}% of the species in the guide. Only confident identifications count.`}
            </Text>
          </Card>
        </TouchableOpacity>

        <TouchableOpacity onPress={() => navigation.navigate('Scan')} activeOpacity={0.85}>
          <Card style={styles.scanAgainCard}>
            <MaterialIcons name="camera-alt" size={26} color={colors.white} />
            <Text style={[type.bodyMedium, styles.scanAgainText]}>Scan a mushroom</Text>
          </Card>
        </TouchableOpacity>

        <Card style={styles.tipCard}>
          <View style={styles.tipHeader}>
            <MaterialIcons name="lightbulb" size={18} color={colors.mossDark} />
            <Text style={[type.label, styles.tipLabel]}>Safety tip of the day</Text>
          </View>
          <Text style={[type.body, styles.tipText]}>{safetyTip}</Text>
        </Card>

        <View style={styles.poisonWrap}>
          <PoisonControlCard />
        </View>

        <Text style={[type.h2, styles.sectionTitle]}>Recent scans</Text>
        {recentScans.length === 0 && (
          <Text style={[type.body, styles.noScans]}>
            Nothing scanned yet. Your recent identifications will appear here.
          </Text>
        )}
        {recentScans.map((scan) => {
          const species = getSpeciesById(scan.speciesId);
          return (
            <TouchableOpacity key={scan.id} onPress={() => navigation.navigate('Result', { scanId: scan.id })}>
              <Card style={styles.scanRow}>
                <Text style={[type.bodyMedium, { color: colors.ink }]}>
                  {species ? species.commonName : 'Unidentified'}
                </Text>
                <Text style={[type.caption, { color: colors.fog }]}>{scan.confidencePercent}% confidence</Text>
              </Card>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.sm },
  title: { color: colors.ink },
  demoTag: { color: colors.fog, marginBottom: spacing.md },
  statsRow: { flexDirection: 'row', gap: spacing.md, marginBottom: spacing.md },
  statCard: { flex: 1, alignItems: 'center' },
  statNumber: { color: colors.moss },
  statLabel: { color: colors.fog, marginTop: spacing.xs },
  scanAgainCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.moss,
    borderColor: colors.moss,
    marginBottom: spacing.md,
  },
  scanAgainText: { color: colors.white, marginLeft: spacing.sm },
  progressCard: { marginBottom: spacing.md },
  progressHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.sm },
  progressTrack: { height: 8, borderRadius: 4, backgroundColor: colors.hairline, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: 4, backgroundColor: colors.moss },
  progressHint: { color: colors.fog, marginTop: spacing.xs },
  tipCard: { backgroundColor: colors.edibleBg, borderColor: colors.edibleBg, marginBottom: spacing.md },
  tipHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.xs },
  tipLabel: { color: colors.mossDark, marginLeft: spacing.xs },
  tipText: { color: colors.mossDark },
  poisonWrap: { marginBottom: spacing.lg },
  sectionTitle: { color: colors.ink, marginBottom: spacing.sm },
  noScans: { color: colors.fog },
  scanRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
});
