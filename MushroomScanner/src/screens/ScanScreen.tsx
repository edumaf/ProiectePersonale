import { useState } from 'react';
import { ActivityIndicator, Image, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { CompositeScreenProps } from '@react-navigation/native';
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { MainTabParamList, RootStackParamList } from '../navigation/types';
import { PrimaryButton } from '../components/PrimaryButton';
import { mockScans } from '../data/mockScans';
import { ScanAngle } from '../types/models';
import { colors, radius, spacing, type } from '../theme';

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, 'Scan'>,
  NativeStackScreenProps<RootStackParamList>
>;

type Status = 'idle' | 'loading';

// Guided multi-angle capture: the cap alone is enough to run identification,
// but gill/spore pattern and stem base (volva!) are often what separates a
// prized edible from its deadly look-alike, so we ask for them explicitly
// rather than accepting a single photo like most competing scanner apps.
const angleSteps: Array<{ angle: ScanAngle; title: string; hint: string; required: boolean }> = [
  { angle: 'cap', title: 'Cap (top)', hint: 'Full mushroom from above, in good light', required: true },
  { angle: 'gills', title: 'Gills / underside', hint: 'Flip it over - gill color and spacing matter', required: false },
  { angle: 'stem_base', title: 'Stem base', hint: 'Dig gently - a hidden volva (sac) is a deadly-Amanita sign', required: false },
];

// The identification call itself (multimodal LLM vision request over all
// captured angles) is wired up in build step 3; for now completing the
// capture jumps to a mock result after a short fake delay.
export function ScanScreen({ navigation }: Props) {
  const [status, setStatus] = useState<Status>('idle');
  const [photos, setPhotos] = useState<Partial<Record<ScanAngle, string>>>({});

  async function captureAngle(angle: ScanAngle, source: 'camera' | 'library') {
    const permission =
      source === 'camera'
        ? await ImagePicker.requestCameraPermissionsAsync()
        : await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;

    const result =
      source === 'camera'
        ? await ImagePicker.launchCameraAsync({ quality: 0.8 })
        : await ImagePicker.launchImageLibraryAsync({ quality: 0.8 });

    if (result.canceled) return;
    setPhotos((prev) => ({ ...prev, [angle]: result.assets[0].uri }));
  }

  function identify() {
    setStatus('loading');
    setTimeout(() => {
      setStatus('idle');
      setPhotos({});
      navigation.navigate('Result', { scanId: mockScans[0].id });
    }, 1200);
  }

  const hasRequiredPhotos = angleSteps.filter((s) => s.required).every((s) => photos[s.angle]);
  const capturedCount = Object.keys(photos).length;

  if (status === 'loading') {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.center}>
          {photos.cap && <Image source={{ uri: photos.cap }} style={styles.loadingPreview} />}
          <ActivityIndicator size="large" color={colors.moss} style={{ marginTop: spacing.lg }} />
          <Text style={[type.body, styles.loadingText]}>Identifying your mushroom...</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={[type.h1, styles.title]}>Scan a mushroom</Text>
        <Text style={[type.body, styles.subtitle]}>
          More angles mean a more reliable result. The cap is required; gills and stem base are
          highly recommended - they're often the only way to tell a safe species from a deadly one.
        </Text>

        {angleSteps.map((step) => {
          const uri = photos[step.angle];
          return (
            <View key={step.angle} style={styles.slot}>
              <TouchableOpacity
                style={styles.slotImageWrap}
                onPress={() => captureAngle(step.angle, 'camera')}
                onLongPress={() => captureAngle(step.angle, 'library')}
              >
                {uri ? (
                  <Image source={{ uri }} style={styles.slotImage} />
                ) : (
                  <View style={styles.slotPlaceholder}>
                    <MaterialIcons name="add-a-photo" size={26} color={colors.moss} />
                  </View>
                )}
              </TouchableOpacity>
              <View style={styles.slotInfo}>
                <View style={styles.slotTitleRow}>
                  <Text style={[type.bodyMedium, { color: colors.ink }]}>{step.title}</Text>
                  {step.required ? (
                    <Text style={[type.caption, styles.requiredTag]}>Required</Text>
                  ) : (
                    <Text style={[type.caption, styles.recommendedTag]}>Recommended</Text>
                  )}
                </View>
                <Text style={[type.caption, styles.slotHint]}>{step.hint}</Text>
                {!uri && (
                  <TouchableOpacity onPress={() => captureAngle(step.angle, 'library')}>
                    <Text style={[type.caption, styles.libraryLink]}>Choose from library instead</Text>
                  </TouchableOpacity>
                )}
              </View>
            </View>
          );
        })}

        <PrimaryButton
          label={capturedCount > 0 ? `Identify (${capturedCount} photo${capturedCount > 1 ? 's' : ''})` : 'Identify'}
          onPress={identify}
          disabled={!hasRequiredPhotos}
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.lg },
  title: { color: colors.ink, marginBottom: spacing.sm },
  subtitle: { color: colors.charcoal, marginBottom: spacing.lg },
  slot: { flexDirection: 'row', marginBottom: spacing.md },
  slotImageWrap: { marginRight: spacing.md },
  slotImage: { width: 84, height: 84, borderRadius: radius.md },
  slotPlaceholder: {
    width: 84,
    height: 84,
    borderRadius: radius.md,
    backgroundColor: colors.paper,
    borderWidth: 1.5,
    borderColor: colors.hairline,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  slotInfo: { flex: 1, justifyContent: 'center' },
  slotTitleRow: { flexDirection: 'row', alignItems: 'center' },
  requiredTag: { color: colors.deadly, marginLeft: spacing.sm },
  recommendedTag: { color: colors.mossDark, marginLeft: spacing.sm },
  slotHint: { color: colors.fog, marginTop: 2 },
  libraryLink: { color: colors.moss, marginTop: spacing.xs },
  loadingPreview: { width: 220, height: 220, borderRadius: 16 },
  loadingText: { color: colors.charcoal, marginTop: spacing.sm },
});
