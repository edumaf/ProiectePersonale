import { StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { edibilityPresentation, EdibilityStatus, radius, spacing, type } from '../theme';

// The single most visually dominant element on the result screen -
// color + icon must read instantly, even without the label text.
export function EdibilityBadge({
  status,
  size = 'large',
}: {
  status: EdibilityStatus;
  size?: 'large' | 'small';
}) {
  const presentation = edibilityPresentation[status];
  const large = size === 'large';

  return (
    <View
      style={[
        styles.badge,
        { backgroundColor: presentation.background },
        large ? styles.badgeLarge : styles.badgeSmall,
      ]}
    >
      <MaterialIcons
        name={presentation.icon as any}
        size={large ? 22 : 16}
        color={presentation.color}
      />
      <Text
        style={[
          large ? type.h2 : type.label,
          { color: presentation.color, marginLeft: spacing.xs },
        ]}
      >
        {presentation.label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderRadius: radius.pill,
  },
  badgeLarge: {
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
  },
  badgeSmall: {
    paddingVertical: 4,
    paddingHorizontal: spacing.sm,
  },
});
