import { NavigationContainer } from '@react-navigation/native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { RootNavigator } from './src/navigation/RootNavigator';
import { AuthProvider } from './src/lib/auth';
import { ConsentProvider } from './src/lib/consent';
import { EntitlementProvider } from './src/lib/entitlement';

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ConsentProvider>
          <AuthProvider>
            <EntitlementProvider>
              <NavigationContainer>
                <RootNavigator />
                <StatusBar style="dark" />
              </NavigationContainer>
            </EntitlementProvider>
          </AuthProvider>
        </ConsentProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
