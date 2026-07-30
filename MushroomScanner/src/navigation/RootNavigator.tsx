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
import { useAuth } from '../lib/auth';
import { colors } from '../theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  // TODO: read real onboarding-consent state (e.g. AsyncStorage) once
  // persistence lands; onboarding always shows first for now. SignIn is
  // only reachable when Supabase is configured (OnboardingScreen decides
  // where "Continue" goes) - in demo mode it's registered but unused.
  const { loading } = useAuth();

  if (loading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.cream }}>
        <ActivityIndicator size="large" color={colors.moss} />
      </View>
    );
  }

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
      <Stack.Screen name="SignIn" component={SignInScreen} options={{ headerShown: false }} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />
      <Stack.Screen name="Result" component={ResultScreen} options={{ title: 'Result' }} />
      <Stack.Screen name="SpeciesDetail" component={SpeciesDetailScreen} options={{ title: 'Species' }} />
      <Stack.Screen name="CollectionDetail" component={CollectionDetailScreen} options={{ title: 'Collection' }} />
      <Stack.Screen name="AIAssistant" component={AIAssistantScreen} options={{ title: 'Ask the assistant' }} />
    </Stack.Navigator>
  );
}
