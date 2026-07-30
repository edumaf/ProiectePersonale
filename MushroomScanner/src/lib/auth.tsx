import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from 'react';
import * as Linking from 'expo-linking';
import * as WebBrowser from 'expo-web-browser';
import * as QueryParams from 'expo-auth-session/build/QueryParams';
import { Session } from '@supabase/supabase-js';
import { supabase } from './supabase';
import { isSupabaseConfigured } from './config';

WebBrowser.maybeCompleteAuthSession();

interface AuthContextValue {
  session: Session | null;
  loading: boolean;
  /** True once Supabase has reported an initial session (or demo mode, where there never is one). */
  ready: boolean;
  signInWithEmail: (email: string) => Promise<void>;
  signInWithOAuth: (provider: 'apple' | 'google') => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const redirectTo = Linking.createURL('/auth/callback');

async function createSessionFromUrl(url: string) {
  if (!supabase) return;
  const { params, errorCode } = QueryParams.getQueryParams(url);
  if (errorCode) throw new Error(errorCode);
  const { access_token, refresh_token } = params;
  if (!access_token || !refresh_token) return;
  const { error } = await supabase.auth.setSession({ access_token, refresh_token });
  if (error) throw error;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(!isSupabaseConfigured);

  useEffect(() => {
    if (!supabase) return;

    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
    });

    return () => subscription.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    const sub = Linking.addEventListener('url', (event) => {
      createSessionFromUrl(event.url).catch((err) => console.warn('Auth deep link failed', err));
    });
    return () => sub.remove();
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      loading: !ready,
      ready,
      async signInWithEmail(email: string) {
        if (!supabase) throw new Error('Sign-in is unavailable in demo mode - Supabase is not configured.');
        const { error } = await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: redirectTo } });
        if (error) throw error;
      },
      async signInWithOAuth(provider: 'apple' | 'google') {
        if (!supabase) throw new Error('Sign-in is unavailable in demo mode - Supabase is not configured.');
        const { data, error } = await supabase.auth.signInWithOAuth({
          provider,
          options: { redirectTo, skipBrowserRedirect: true },
        });
        if (error) throw error;
        if (!data?.url) throw new Error('No OAuth URL returned');
        const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
        if (result.type === 'success') {
          await createSessionFromUrl(result.url);
        }
      },
      async signOut() {
        if (!supabase) return;
        await supabase.auth.signOut();
      },
    }),
    [session, ready]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
