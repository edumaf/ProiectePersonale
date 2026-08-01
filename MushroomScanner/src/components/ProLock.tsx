import { Pressable, StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { Card } from './Card';
import { colors, spacing, type } from '../theme';

/**
 * Placeholder shown in place of a Pro-only section.
 *
 * Deliberately states what's behind the lock rather than hiding that it
 * exists - for safety content especially, a user needs to know there's
 * more to check before eating something, even if they won't pay for it.
 */
export function ProLock({ title, description }: { title: string; description: string }) {
  const navigation = useNavigation<any>();

  return (
    <Card style={styles.card}>
      <View style={styles.header}>
        <MaterialIcons name="lock" size={18} color={colors.clay} />
        <Text style={[type.bodyMedium, styles.title]}>{title}</Text>
      </View>
      <Text style={[type.body, styles.description]}>{description}</Text>
      <Pressable onPress={() => navigation.navigate('Paywall', {})}>
        <Text style={[type.bodyMedium, styles.link]}>See what Pro includes</Text>
      </Pressable>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.paper, borderStyle: 'dashed', borderColor: colors.clay },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.xs },
  title: { color: colors.bark, marginLeft: spacing.xs },
  description: { color: colors.charcoal, marginBottom: spacing.sm },
  link: { color: colors.moss },
});
