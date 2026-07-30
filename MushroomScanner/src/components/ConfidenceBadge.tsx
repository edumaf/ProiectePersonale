import { StyleSheet, Text, View } from 'react-native';
import { colors, radius, spacing, type } from '../theme';

export type ConfidenceLevel = 'high' | 'medium' | 'low';

// Confidence is always shown honestly, never hidden inside body text.
export function ConfidenceBadge({
  level,
  percent,
}: {
  level: ConfidenceLevel;
  percent: number;
}) {
  const color =
    level === 'high' ? colors.confidenceHigh : level === 'medium' ? colors.confidenceMedium : colors.confidenceLow;
  const label = level === 'high' ? 'High confidence' : level === 'medium' ? 'Medium confidence' : 'Low confidence';

  return (
    <View style={styles.row}>
      <View style={[styles.dot, { backgroundColor: color }]} />
      <Text style={[type.label, { color }]}>
        {label} · {percent}%
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
  dot: { width: 8, height: 8, borderRadius: radius.pill, marginRight: spacing.xs },
});
