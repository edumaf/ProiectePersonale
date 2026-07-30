import { useMemo, useState } from 'react';
import { FlatList, Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { CompositeScreenProps } from '@react-navigation/native';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { speciesList } from '../data/species';
import { colors, edibilityPresentation, EdibilityStatus, spacing, type } from '../theme';

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, 'Learn'>,
  NativeStackScreenProps<RootStackParamList>
>;

const filters: Array<{ key: EdibilityStatus | 'all'; label: string }> = [
  { key: 'all', label: 'All' },
  ...(Object.keys(edibilityPresentation) as EdibilityStatus[]).map((key) => ({
    key,
    label: edibilityPresentation[key].label,
  })),
];

// Browse the species database directly, not just via scanning.
export function LearnScreen({ navigation }: Props) {
  const [activeFilter, setActiveFilter] = useState<EdibilityStatus | 'all'>('all');

  const filtered = useMemo(
    () => (activeFilter === 'all' ? speciesList : speciesList.filter((s) => s.edibilityStatus === activeFilter)),
    [activeFilter]
  );

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <Text style={[type.display, styles.title]}>Learn</Text>
      <FlatList
        horizontal
        showsHorizontalScrollIndicator={false}
        data={filters}
        keyExtractor={(f) => f.key}
        style={styles.filterList}
        contentContainerStyle={styles.filterListContent}
        renderItem={({ item }) => {
          const active = item.key === activeFilter;
          return (
            <TouchableOpacity
              style={[styles.filterChip, active && styles.filterChipActive]}
              onPress={() => setActiveFilter(item.key)}
            >
              <Text style={[type.label, { color: active ? colors.white : colors.charcoal }]}>{item.label}</Text>
            </TouchableOpacity>
          );
        }}
      />
      <FlatList
        data={filtered}
        keyExtractor={(s) => s.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={styles.row}
            onPress={() => navigation.navigate('SpeciesDetail', { speciesId: item.id })}
          >
            <Image source={{ uri: item.photoUrls[0] }} style={styles.thumb} />
            <View style={styles.info}>
              <Text style={[type.bodyMedium, { color: colors.ink }]}>{item.commonName}</Text>
              <Text style={[type.latin, { color: colors.fog, fontSize: 13 }]}>{item.latinName}</Text>
              <EdibilityBadge status={item.edibilityStatus} size="small" />
            </View>
          </TouchableOpacity>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  title: { color: colors.ink, paddingHorizontal: spacing.lg, paddingTop: spacing.md },
  filterList: { flexGrow: 0, marginTop: spacing.sm },
  filterListContent: { paddingHorizontal: spacing.lg, gap: spacing.sm },
  filterChip: {
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.md,
    borderRadius: 999,
    backgroundColor: colors.paper,
    borderWidth: 1,
    borderColor: colors.hairline,
    marginRight: spacing.sm,
  },
  filterChipActive: { backgroundColor: colors.moss, borderColor: colors.moss },
  list: { padding: spacing.lg, paddingBottom: spacing.xxl },
  row: { flexDirection: 'row', marginBottom: spacing.md },
  thumb: { width: 64, height: 64, borderRadius: 10, marginRight: spacing.md },
  info: { flex: 1, justifyContent: 'center' },
});
