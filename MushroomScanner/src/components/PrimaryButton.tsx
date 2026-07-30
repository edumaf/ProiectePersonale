import { Pressable, StyleSheet, Text } from 'react-native';
import { colors, radius, spacing, type } from '../theme';

export function PrimaryButton({
  label,
  onPress,
  variant = 'solid',
  disabled,
}: {
  label: string;
  onPress: () => void;
  variant?: 'solid' | 'outline';
  disabled?: boolean;
}) {
  const outline = variant === 'outline';
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [
        styles.button,
        outline ? styles.outline : styles.solid,
        disabled && styles.disabled,
        pressed && !disabled && styles.pressed,
      ]}
    >
      <Text style={[type.bodyMedium, outline ? styles.outlineText : styles.solidText]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    borderRadius: radius.pill,
    paddingVertical: spacing.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  solid: { backgroundColor: colors.moss },
  outline: { backgroundColor: 'transparent', borderWidth: 1.5, borderColor: colors.moss },
  solidText: { color: colors.white },
  outlineText: { color: colors.moss },
  disabled: { opacity: 0.5 },
  pressed: { opacity: 0.85 },
});
