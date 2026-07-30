import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { MaterialIcons } from '@expo/vector-icons';
import { MainTabParamList } from './types';
import { DashboardScreen } from '../screens/DashboardScreen';
import { ScanScreen } from '../screens/ScanScreen';
import { MyFindsScreen } from '../screens/MyFindsScreen';
import { ScanHistoryScreen } from '../screens/ScanHistoryScreen';
import { LearnScreen } from '../screens/LearnScreen';
import { colors } from '../theme';

const Tab = createBottomTabNavigator<MainTabParamList>();

const icons: Record<keyof MainTabParamList, keyof typeof MaterialIcons.glyphMap> = {
  Dashboard: 'home',
  Scan: 'camera-alt',
  MyFinds: 'collections-bookmark',
  History: 'history',
  Learn: 'menu-book',
};

export function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: colors.moss,
        tabBarInactiveTintColor: colors.fog,
        tabBarStyle: { backgroundColor: colors.paper, borderTopColor: colors.hairline },
        tabBarIcon: ({ color, size }) => (
          <MaterialIcons name={icons[route.name as keyof MainTabParamList]} color={color} size={size} />
        ),
      })}
    >
      <Tab.Screen name="Dashboard" component={DashboardScreen} />
      <Tab.Screen name="Scan" component={ScanScreen} />
      <Tab.Screen name="MyFinds" component={MyFindsScreen} options={{ title: 'My Finds' }} />
      <Tab.Screen name="History" component={ScanHistoryScreen} />
      <Tab.Screen name="Learn" component={LearnScreen} />
    </Tab.Navigator>
  );
}
