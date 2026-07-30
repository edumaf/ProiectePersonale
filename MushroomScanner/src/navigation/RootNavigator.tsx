import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { RootStackParamList } from './types';
import { MainTabs } from './MainTabs';
import { OnboardingScreen } from '../screens/OnboardingScreen';
import { ResultScreen } from '../screens/ResultScreen';
import { SpeciesDetailScreen } from '../screens/SpeciesDetailScreen';
import { CollectionDetailScreen } from '../screens/CollectionDetailScreen';
import { AIAssistantScreen } from '../screens/AIAssistantScreen';
import { colors } from '../theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  // TODO: read real onboarding-consent state (e.g. AsyncStorage) once auth
  // and persistence land; onboarding always shows first for now.
  return (
    <Stack.Navigator
      initialRouteName="Onboarding"
      screenOptions={{
        headerStyle: { backgroundColor: colors.paper },
        headerTintColor: colors.ink,
        headerTitleStyle: { color: colors.ink },
        headerShadowVisible: false,
      }}
    >
      <Stack.Screen name="Onboarding" component={OnboardingScreen} options={{ headerShown: false }} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />
      <Stack.Screen name="Result" component={ResultScreen} options={{ title: 'Result' }} />
      <Stack.Screen name="SpeciesDetail" component={SpeciesDetailScreen} options={{ title: 'Species' }} />
      <Stack.Screen name="CollectionDetail" component={CollectionDetailScreen} options={{ title: 'Collection' }} />
      <Stack.Screen name="AIAssistant" component={AIAssistantScreen} options={{ title: 'Ask the assistant' }} />
    </Stack.Navigator>
  );
}
