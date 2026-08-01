import { StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { PrimaryButton } from './PrimaryButton';
import { colors, spacing, type } from '../theme';

export function EmptyState({
  icon,
  title,
  message,
  actionLabel,
  onAction,
}: {
  icon: keyof typeof MaterialIcons.glyphMap;
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <View style={styles.wrap}>
      <MaterialIcons name={icon} size={40} color={colors.hairline} />
      <Text style={[type.h2, styles.title]}>{title}</Text>
      <Text style={[type.body, styles.message]}>{message}</Text>
      {actionLabel && onAction && (
        <View style={styles.action}>
          <PrimaryButton label={actionLabel} onPress={onAction} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', paddingVertical: spacing.xxl, paddingHorizontal: spacing.lg },
  title: { color: colors.charcoal, marginTop: spacing.md, marginBottom: spacing.xs, textAlign: 'center' },
  message: { color: colors.fog, textAlign: 'center' },
  action: { marginTop: spacing.lg, alignSelf: 'stretch' },
});
