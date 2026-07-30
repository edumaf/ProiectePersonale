import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from './config';

// Null in demo mode (no EXPO_PUBLIC_SUPABASE_* env vars set) - every call
// site must check isSupabaseConfigured / handle a null client rather than
// assuming it exists.
export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,
      },
    })
  : null;
