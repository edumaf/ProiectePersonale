import { NavigatorScreenParams } from '@react-navigation/native';

export type MainTabParamList = {
  Dashboard: undefined;
  Scan: undefined;
  MyFinds: undefined;
  History: undefined;
  Learn: undefined;
};

export type RootStackParamList = {
  Onboarding: undefined;
  Main: NavigatorScreenParams<MainTabParamList>;
  Result: { scanId: string };
  SpeciesDetail: { speciesId: string };
  CollectionDetail: { collectionId: string };
  AIAssistant: { speciesId: string };
};

declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
