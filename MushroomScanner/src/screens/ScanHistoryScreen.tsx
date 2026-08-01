import { ActivityIndicator, FlatList, Image, RefreshControl, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { CompositeScreenProps } from '@react-navigation/native';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { EmptyState } from '../components/EmptyState';
import { ProLock } from '../components/ProLock';
import { useScanHistory } from '../hooks/useScanHistory';
import { useEntitlement } from '../lib/entitlement';
import { getSpeciesById } from '../data/species';
import { colors, spacing, type } from '../theme';

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, 'History'>,
  NativeStackScreenProps<RootStackParamList>
>;

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

// Chronological log of every scan, independent of collections.
// Free tier sees a recent window of their history; Pro sees the full
// archive. The cap is presentational only - nothing is deleted, and the
// scans are still the user's own data, so it's restored the moment they
// upgrade.
const FREE_HISTORY_LIMIT = 5;

export function ScanHistoryScreen({ navigation }: Props) {
  const { scans, refreshing, loadingMore, isDemo, refresh, loadMore } = useScanHistory();
  const { isPro } = useEntitlement();

  const visibleScans = isPro ? scans : scans.slice(0, FREE_HISTORY_LIMIT);
  const hiddenCount = scans.length - visibleScans.length;

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <Text style={[type.display, styles.title]}>Scan History</Text>
      {isDemo && <Text style={[type.caption, styles.demoTag]}>Showing demo data.</Text>}
      <FlatList
        data={visibleScans}
        keyExtractor={(s) => s.id}
        contentContainerStyle={visibleScans.length === 0 ? styles.emptyList : styles.list}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.moss} />
        }
        onEndReached={isPro ? loadMore : undefined}
        onEndReachedThreshold={0.4}
        ListEmptyComponent={
          refreshing ? null : (
            <EmptyState
              icon="history"
              title="No scans yet"
              message="Every mushroom you identify shows up here, newest first."
              actionLabel="Scan a mushroom"
              onAction={() => navigation.navigate('Scan')}
            />
          )
        }
        ListFooterComponent={
          !isPro && hiddenCount > 0 ? (
            <ProLock
              title={`${hiddenCount} older ${hiddenCount === 1 ? 'scan' : 'scans'} hidden`}
              description={`Free keeps your ${FREE_HISTORY_LIMIT} most recent scans visible. Pro opens the full archive - nothing has been deleted.`}
            />
          ) : loadingMore ? (
            <ActivityIndicator style={styles.footer} color={colors.moss} />
          ) : null
        }
        renderItem={({ item }) => {
          const species = getSpeciesById(item.speciesId);
          return (
            <TouchableOpacity
              style={styles.row}
              onPress={() => navigation.navigate('Result', { scanId: item.id })}
            >
              <Image source={{ uri: item.photos[0].url }} style={styles.thumb} />
              <View style={styles.info}>
                <Text style={[type.bodyMedium, { color: colors.ink }]}>
                  {species ? species.commonName : 'Unidentified'}
                </Text>
                <Text style={[type.caption, { color: colors.fog }]}>{formatDate(item.timestamp)}</Text>
                {species && <EdibilityBadge status={species.edibilityStatus} size="small" />}
              </View>
            </TouchableOpacity>
          );
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  title: { color: colors.ink, paddingHorizontal: spacing.lg, paddingTop: spacing.md },
  demoTag: { color: colors.fog, paddingHorizontal: spacing.lg, marginTop: spacing.xs },
  list: { padding: spacing.lg, paddingBottom: spacing.xxl },
  emptyList: { flexGrow: 1, justifyContent: 'center' },
  row: { flexDirection: 'row', marginBottom: spacing.md },
  thumb: { width: 64, height: 64, borderRadius: 10, marginRight: spacing.md },
  info: { flex: 1, justifyContent: 'center' },
  footer: { paddingVertical: spacing.lg },
});
