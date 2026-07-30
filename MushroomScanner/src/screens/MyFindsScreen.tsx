import { useState } from 'react';
import { FlatList, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { CompositeScreenProps } from '@react-navigation/native';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { Card } from '../components/Card';
import { useAppData } from '../hooks/useAppData';
import { useAuth } from '../lib/auth';
import { createCollection } from '../lib/scans';
import { colors, spacing, type } from '../theme';

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, 'MyFinds'>,
  NativeStackScreenProps<RootStackParamList>
>;

export function MyFindsScreen({ navigation }: Props) {
  const { collections, isDemo, refresh } = useAppData();
  const { session } = useAuth();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');

  async function submitNewCollection() {
    if (!session || !newName.trim()) {
      setCreating(false);
      return;
    }
    await createCollection(session.user.id, newName.trim());
    setNewName('');
    setCreating(false);
    refresh();
  }

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <View style={styles.headerRow}>
        <Text style={[type.display, { color: colors.ink }]}>My Finds</Text>
        {!isDemo && (
          <TouchableOpacity style={styles.newButton} onPress={() => setCreating(true)}>
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

      <FlatList
        data={collections}
        keyExtractor={(c) => c.id}
        contentContainerStyle={styles.list}
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
  collectionCard: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  collectionInfo: { flex: 1, marginLeft: spacing.sm },
});
