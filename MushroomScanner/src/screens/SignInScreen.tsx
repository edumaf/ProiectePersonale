import { useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { PrimaryButton } from '../components/PrimaryButton';
import { useAuth } from '../lib/auth';
import { colors, radius, spacing, type } from '../theme';

// Only reachable when Supabase is configured (see RootNavigator) - demo
// mode skips straight to Main instead.
export function SignInScreen() {
  const { signInWithEmail, signInWithOAuth } = useAuth();
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');
  const [errorMessage, setErrorMessage] = useState('');
  const [oauthLoading, setOauthLoading] = useState<'apple' | 'google' | null>(null);

  async function sendMagicLink() {
    if (!email.trim()) return;
    setStatus('sending');
    try {
      await signInWithEmail(email.trim());
      setStatus('sent');
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Something went wrong');
      setStatus('error');
    }
  }

  async function oauth(provider: 'apple' | 'google') {
    setOauthLoading(provider);
    try {
      await signInWithOAuth(provider);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Something went wrong');
      setStatus('error');
    } finally {
      setOauthLoading(null);
    }
  }

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.content}>
        <MaterialIcons name="eco" size={40} color={colors.moss} />
        <Text style={[type.h1, styles.title]}>Sign in</Text>
        <Text style={[type.body, styles.subtitle]}>
          Save your scans and collections across devices. You can still browse the species
          database without an account.
        </Text>

        {status === 'sent' ? (
          <View style={styles.sentCard}>
            <MaterialIcons name="mark-email-read" size={22} color={colors.mossDark} />
            <Text style={[type.body, styles.sentText]}>
              Check your email for a sign-in link, then open it on this device.
            </Text>
          </View>
        ) : (
          <>
            <TextInput
              style={styles.input}
              placeholder="you@example.com"
              placeholderTextColor={colors.fog}
              autoCapitalize="none"
              autoComplete="email"
              keyboardType="email-address"
              value={email}
              onChangeText={setEmail}
            />
            <PrimaryButton
              label={status === 'sending' ? 'Sending link...' : 'Send magic link'}
              onPress={sendMagicLink}
              disabled={status === 'sending' || !email.trim()}
            />

            <View style={styles.divider}>
              <View style={styles.dividerLine} />
              <Text style={[type.caption, styles.dividerText]}>or</Text>
              <View style={styles.dividerLine} />
            </View>

            <PrimaryButton
              label={oauthLoading === 'apple' ? 'Opening Apple sign-in...' : 'Continue with Apple'}
              variant="outline"
              onPress={() => oauth('apple')}
              disabled={oauthLoading !== null}
            />
            <View style={{ height: spacing.sm }} />
            <PrimaryButton
              label={oauthLoading === 'google' ? 'Opening Google sign-in...' : 'Continue with Google'}
              variant="outline"
              onPress={() => oauth('google')}
              disabled={oauthLoading !== null}
            />
          </>
        )}

        {status === 'sending' && <ActivityIndicator style={{ marginTop: spacing.md }} color={colors.moss} />}
        {status === 'error' && <Text style={[type.caption, styles.errorText]}>{errorMessage}</Text>}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  content: { flex: 1, padding: spacing.lg, justifyContent: 'center' },
  title: { color: colors.ink, marginTop: spacing.md, marginBottom: spacing.sm },
  subtitle: { color: colors.charcoal, marginBottom: spacing.xl },
  input: {
    backgroundColor: colors.paper,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.hairline,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    color: colors.ink,
    marginBottom: spacing.md,
  },
  divider: { flexDirection: 'row', alignItems: 'center', marginVertical: spacing.lg },
  dividerLine: { flex: 1, height: 1, backgroundColor: colors.hairline },
  dividerText: { color: colors.fog, marginHorizontal: spacing.sm },
  sentCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: colors.edibleBg,
    borderRadius: radius.md,
    padding: spacing.md,
  },
  sentText: { flex: 1, color: colors.mossDark, marginLeft: spacing.sm },
  errorText: { color: colors.deadly, marginTop: spacing.md, textAlign: 'center' },
});
