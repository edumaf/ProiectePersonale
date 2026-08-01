import { ActivityIndicator, FlatList, Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { useAppData } from '../hooks/useAppData';
import { getSpeciesById } from '../data/species';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { EmptyState } from '../components/EmptyState';
import { colors, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'CollectionDetail'>;

export function CollectionDetailScreen({ route, navigation }: Props) {
  const { scans: allScans, collections, loading } = useAppData();
  const collection = collections.find((c) => c.id === route.params.collectionId);

  if (loading && !collection) {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.loadingCenter}>
          <ActivityIndicator size="large" color={colors.moss} />
        </View>
      </SafeAreaView>
    );
  }
  if (!collection) return null;
  const scans = allScans.filter((s) => collection.scanIds.includes(s.id));

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <View style={styles.header}>
        <Text style={[type.h1, { color: colors.ink }]}>{collection.name}</Text>
        <Text style={[type.caption, { color: colors.fog }]}>{scans.length} finds</Text>
      </View>
      <FlatList
        data={scans}
        keyExtractor={(s) => s.id}
        numColumns={2}
        contentContainerStyle={scans.length === 0 ? styles.emptyGrid : styles.grid}
        ListEmptyComponent={
          <EmptyState
            icon="photo-library"
            title="Nothing saved here yet"
            message="Scans you add to this collection will show up here."
          />
        }
        renderItem={({ item }) => {
          const species = getSpeciesById(item.speciesId);
          return (
            <TouchableOpacity
              style={styles.tile}
              onPress={() => navigation.navigate('Result', { scanId: item.id })}
            >
              <Image source={{ uri: item.photos[0].url }} style={styles.thumb} />
              <Text style={[type.bodyMedium, styles.thumbLabel]} numberOfLines={1}>
                {species ? species.commonName : 'Unidentified'}
              </Text>
              {species && <EdibilityBadge status={species.edibilityStatus} size="small" />}
            </TouchableOpacity>
          );
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  loadingCenter: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { padding: spacing.lg, paddingBottom: spacing.sm },
  grid: { paddingHorizontal: spacing.md, paddingBottom: spacing.xxl },
  emptyGrid: { flexGrow: 1, justifyContent: 'center' },
  tile: { flex: 1, margin: spacing.sm, maxWidth: '47%' },
  thumb: { width: '100%', aspectRatio: 1, borderRadius: 12, marginBottom: spacing.xs },
  thumbLabel: { color: colors.ink, marginBottom: 4 },
});
