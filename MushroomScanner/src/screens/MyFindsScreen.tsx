import { useState } from 'react';
import { FlatList, RefreshControl, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { CompositeScreenProps } from '@react-navigation/native';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { Card } from '../components/Card';
import { EmptyState } from '../components/EmptyState';
import { useAppData } from '../hooks/useAppData';
import { useAuth } from '../lib/auth';
import { createCollection } from '../lib/scans';
import { useEntitlement } from '../lib/entitlement';
import { colors, spacing, type } from '../theme';

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, 'MyFinds'>,
  NativeStackScreenProps<RootStackParamList>
>;

export function MyFindsScreen({ navigation }: Props) {
  const { collections, isDemo, loading, refresh } = useAppData();
  const { session } = useAuth();
  const { isPro } = useEntitlement();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [error, setError] = useState('');

  function startNewCollection() {
    // Free tier allows one collection; the DB trigger enforces this too,
    // this just avoids making the user type a name only to be refused.
    if (!isPro && collections.length >= 1) {
      navigation.navigate('Paywall', { reason: 'collection_limit' });
      return;
    }
    setCreating(true);
  }

  async function submitNewCollection() {
    if (!session || !newName.trim()) {
      setCreating(false);
      return;
    }
    setError('');
    try {
      await createCollection(session.user.id, newName.trim());
      setNewName('');
      setCreating(false);
      refresh();
    } catch (err) {
      const message = err instanceof Error ? err.message : '';
      if (message.includes('collection_limit_reached')) {
        setCreating(false);
        navigation.navigate('Paywall', { reason: 'collection_limit' });
        return;
      }
      setError('Could not create that collection - try again.');
    }
  }

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <View style={styles.headerRow}>
        <Text style={[type.display, { color: colors.ink }]}>My Finds</Text>
        {!isDemo && (
          <TouchableOpacity style={styles.newButton} onPress={startNewCollection}>
            <MaterialIcons name="add" size={20} color={colors.white} />
          </TouchableOpacity>
        )}
      </View>

      {isDemo && (
        <Text style={[type.caption, styles.demoTag]}>Demo data - sign in to create your own collections.</Text>
      )}

      {creating && (
        <View style={styles.newRow}>
          <TextInput
            style={styles.newInput}
            placeholder="Collection name"
            placeholderTextColor={colors.fog}
            value={newName}
            onChangeText={setNewName}
            autoFocus
            onSubmitEditing={submitNewCollection}
          />
          <TouchableOpacity onPress={submitNewCollection}>
            <MaterialIcons name="check" size={22} color={colors.moss} />
          </TouchableOpacity>
        </View>
      )}

      {error ? <Text style={[type.caption, styles.error]}>{error}</Text> : null}

      <FlatList
        data={collections}
        keyExtractor={(c) => c.id}
        contentContainerStyle={collections.length === 0 ? styles.emptyList : styles.list}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={refresh} tintColor={colors.moss} />}
        ListEmptyComponent={
          loading ? null : (
            <EmptyState
              icon="collections-bookmark"
              title="No collections yet"
              message="Group your finds by trip or location so you can look back at them together."
              actionLabel={isDemo ? undefined : 'New collection'}
              onAction={isDemo ? undefined : startNewCollection}
            />
          )
        }
        renderItem={({ item }) => (
          <TouchableOpacity onPress={() => navigation.navigate('CollectionDetail', { collectionId: item.id })}>
            <Card style={styles.collectionCard}>
              <MaterialIcons name="collections-bookmark" size={22} color={colors.moss} />
              <View style={styles.collectionInfo}>
                <Text style={[type.bodyMedium, { color: colors.ink }]}>{item.name}</Text>
                <Text style={[type.caption, { color: colors.fog }]}>{item.scanIds.length} finds</Text>
              </View>
              <MaterialIcons name="chevron-right" size={22} color={colors.fog} />
            </Card>
          </TouchableOpacity>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  demoTag: { color: colors.fog, paddingHorizontal: spacing.lg, marginTop: spacing.xs },
  newButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.moss,
    alignItems: 'center',
    justifyContent: 'center',
  },
  newRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.lg,
    marginTop: spacing.sm,
    backgroundColor: colors.paper,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.hairline,
    paddingHorizontal: spacing.md,
  },
  newInput: { flex: 1, paddingVertical: spacing.sm, color: colors.ink, marginRight: spacing.sm },
  list: { padding: spacing.lg, paddingBottom: spacing.xxl },
  emptyList: { flexGrow: 1, justifyContent: 'center' },
  error: { color: colors.deadly, paddingHorizontal: spacing.lg, marginTop: spacing.sm },
  collectionCard: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  collectionInfo: { flex: 1, marginLeft: spacing.sm },
});
