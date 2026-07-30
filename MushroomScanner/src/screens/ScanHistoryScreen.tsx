import { FlatList, Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { CompositeScreenProps } from '@react-navigation/native';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { EdibilityBadge } from '../components/EdibilityBadge';
import { mockScans } from '../data/mockScans';
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
export function ScanHistoryScreen({ navigation }: Props) {
  const sorted = [...mockScans].sort((a, b) => (a.timestamp < b.timestamp ? 1 : -1));

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <Text style={[type.display, styles.title]}>Scan History</Text>
      <FlatList
        data={sorted}
        keyExtractor={(s) => s.id}
        contentContainerStyle={styles.list}
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
  list: { padding: spacing.lg, paddingBottom: spacing.xxl },
  row: { flexDirection: 'row', marginBottom: spacing.md },
  thumb: { width: 64, height: 64, borderRadius: 10, marginRight: spacing.md },
  info: { flex: 1, justifyContent: 'center' },
});
