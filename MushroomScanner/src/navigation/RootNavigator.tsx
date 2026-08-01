import { ActivityIndicator, View } from 'react-native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { RootStackParamList } from './types';
import { MainTabs } from './MainTabs';
import { OnboardingScreen } from '../screens/OnboardingScreen';
import { SignInScreen } from '../screens/SignInScreen';
import { ResultScreen } from '../screens/ResultScreen';
import { SpeciesDetailScreen } from '../screens/SpeciesDetailScreen';
import { CollectionDetailScreen } from '../screens/CollectionDetailScreen';
import { AIAssistantScreen } from '../screens/AIAssistantScreen';
import { PaywallScreen } from '../screens/PaywallScreen';
import { useAuth } from '../lib/auth';
import { useConsent } from '../lib/consent';
import { isSupabaseConfigured } from '../lib/config';
import { colors } from '../theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  const { loading: authLoading, session } = useAuth();
  const { accepted, loading: consentLoading } = useConsent();

  // Both the stored consent flag and the initial Supabase session have to
  // resolve before picking a start route, otherwise the app flashes
  // Onboarding (or SignIn) for a frame before correcting itself.
  if (authLoading || consentLoading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.cream }}>
        <ActivityIndicator size="large" color={colors.moss} />
      </View>
    );
  }

  const initialRouteName = !accepted ? 'Onboarding' : isSupabaseConfigured && !session ? 'SignIn' : 'Main';

  return (
    <Stack.Navigator
      initialRouteName={initialRouteName}
      screenOptions={{
        headerStyle: { backgroundColor: colors.paper },
        headerTintColor: colors.ink,
        headerTitleStyle: { color: colors.ink },
        headerShadowVisible: false,
      }}
    >
      <Stack.Screen name="Onboarding" component={OnboardingScreen} options={{ headerShown: false }} />
      <Stack.Screen name="SignIn" component={SignInScreen} options={{ headerShown: false }} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />
      <Stack.Screen name="Result" component={ResultScreen} options={{ title: 'Result' }} />
      <Stack.Screen name="SpeciesDetail" component={SpeciesDetailScreen} options={{ title: 'Species' }} />
      <Stack.Screen name="CollectionDetail" component={CollectionDetailScreen} options={{ title: 'Collection' }} />
      <Stack.Screen name="AIAssistant" component={AIAssistantScreen} options={{ title: 'Ask the assistant' }} />
      <Stack.Screen
        name="Paywall"
        component={PaywallScreen}
        options={{ title: 'Pro', presentation: 'modal' }}
      />
    </Stack.Navigator>
  );
}
