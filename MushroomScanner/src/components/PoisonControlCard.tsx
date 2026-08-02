import { Alert, Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { Card } from './Card';
import { usePoisonControl } from '../hooks/usePoisonControl';
import { toDialString } from '../data/poisonControl';
import { colors, radius, spacing, type } from '../theme';

async function dial(phone: string) {
  const url = `tel:${toDialString(phone)}`;
  try {
    const supported = await Linking.canOpenURL(url);
    if (!supported) {
      // Tablets and simulators can't place calls. Show the number so it
      // can still be dialled from another device rather than failing
      // silently, which is what the old dead TouchableOpacity did.
      Alert.alert('Call not supported on this device', `Dial ${phone} from a phone.`);
      return;
    }
    await Linking.openURL(url);
  } catch {
    Alert.alert('Could not start the call', `Dial ${phone} manually.`);
  }
}

/**
 * Emergency contact card. Used on the dashboard and every result screen.
 *
 * Every number here is tappable and actually dials - the previous version
 * was wrapped in a TouchableOpacity with no handler, so it looked like a
 * button, dimmed on press, and did nothing.
 */
export function PoisonControlCard({ compact = false }: { compact?: boolean }) {
  const { contact } = usePoisonControl();

  return (
    <Card style={styles.card}>
      <View style={styles.header}>
        <MaterialIcons name="local-hospital" size={22} color={colors.deadly} />
        <Text style={[type.bodyMedium, styles.headerText]}>Emergency - {contact.country}</Text>
      </View>

      {contact.poisonCentre && (
        <DialRow
          label="Poison centre"
          phone={contact.poisonCentre}
          emphasis
          onPress={() => dial(contact.poisonCentre!)}
        />
      )}

      <DialRow
        label={contact.poisonCentre ? 'Emergency services' : 'Emergency services (ask for toxicology)'}
        phone={contact.emergency}
        emphasis={!contact.poisonCentre}
        onPress={() => dial(contact.emergency)}
      />

      {contact.note && <Text style={[type.caption, styles.note]}>{contact.note}</Text>}

      {!compact && (
        <Text style={[type.caption, styles.advice]}>
          If someone may have eaten a toxic mushroom, call now - don't wait for symptoms. The most
          dangerous species cause no symptoms for 6-24 hours, by which point treatment is harder.
        </Text>
      )}
    </Card>
  );
}

function DialRow({
  label,
  phone,
  emphasis,
  onPress,
}: {
  label: string;
  phone: string;
  emphasis?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`Call ${label}, ${phone}`}
      style={({ pressed }) => [styles.row, pressed && styles.rowPressed]}
    >
      <View style={styles.rowText}>
        <Text style={[type.caption, { color: colors.charcoal }]}>{label}</Text>
        <Text style={[emphasis ? type.h2 : type.bodyMedium, { color: colors.deadly }]}>{phone}</Text>
      </View>
      <MaterialIcons name="call" size={20} color={colors.deadly} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.deadlyBg, borderColor: colors.deadlyBg },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  headerText: { color: colors.deadly, marginLeft: spacing.sm },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.sm,
    borderRadius: radius.sm,
    backgroundColor: colors.paper,
    marginBottom: spacing.xs,
  },
  rowPressed: { opacity: 0.7 },
  rowText: { flex: 1 },
  note: { color: colors.charcoal, marginTop: spacing.xs },
  advice: { color: colors.charcoal, marginTop: spacing.sm },
});
