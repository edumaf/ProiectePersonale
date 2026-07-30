// Expo inlines EXPO_PUBLIC_* env vars at build time - see .env.example for
// what to set. Left unset, the app runs in demo mode: browsing and the
// species database work normally, but sign-in and real scans are disabled
// and the Scan screen falls back to a mock identification result.
export const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL ?? '';
export const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? '';

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);
