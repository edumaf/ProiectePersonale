import { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { getSpeciesById } from '../data/species';
import { askSpecies, AssistantMessage } from '../lib/assistant';
import { isSupabaseConfigured } from '../lib/config';
import { useEntitlement } from '../lib/entitlement';
import { PrimaryButton } from '../components/PrimaryButton';
import { colors, radius, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'AIAssistant'>;

interface Message {
  id: string;
  from: 'user' | 'assistant';
  text: string;
}

// Chat scoped to a single species (habitat, prep, look-alikes) - not a
// general-purpose chatbot. Calls the ask-species edge function (real
// Claude chat) when Supabase is configured; otherwise falls back to a
// canned placeholder so the screen still demos without a backend.
export function AIAssistantScreen({ route, navigation }: Props) {
  const species = getSpeciesById(route.params.speciesId);
  const { isPro } = useEntitlement();
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      from: 'assistant',
      text: species
        ? `Ask me anything about ${species.commonName} (${species.latinName}) - habitat, prep, or how to tell it apart from look-alikes.`
        : 'Ask me anything about this species.',
    },
  ]);

  async function send() {
    const text = input.trim();
    if (!text || sending || !species) return;

    const userMessage: Message = { id: `${Date.now()}-u`, from: 'user', text };
    const nextMessages = [...messages, userMessage];
    setMessages(nextMessages);
    setInput('');

    if (!isSupabaseConfigured) {
      setMessages((prev) => [
        ...prev,
        {
          id: `${Date.now()}-a`,
          from: 'assistant',
          text: 'This is demo mode - connect Supabase (see supabase/README.md) to talk to the real assistant.',
        },
      ]);
      return;
    }

    setSending(true);
    try {
      const history: AssistantMessage[] = nextMessages.map((m) => ({
        role: m.from,
        text: m.text,
      }));
      const reply = await askSpecies(species.id, history);
      setMessages((prev) => [...prev, { id: `${Date.now()}-a`, from: 'assistant', text: reply }]);
    } catch (err) {
      setMessages((prev) => [
        ...prev,
        {
          id: `${Date.now()}-a`,
          from: 'assistant',
          text: err instanceof Error ? `Something went wrong: ${err.message}` : 'Something went wrong - try again.',
        },
      ]);
    } finally {
      setSending(false);
    }
  }

  if (!isPro) {
    return (
      <SafeAreaView style={styles.safe} edges={['bottom']}>
        <View style={styles.lockedWrap}>
          <MaterialIcons name="forum" size={40} color={colors.clay} />
          <Text style={[type.h1, styles.lockedTitle]}>Ask about this species</Text>
          <Text style={[type.body, styles.lockedBody]}>
            {species
              ? `Pro lets you ask follow-up questions about ${species.commonName} - how to tell it apart from its look-alikes, where it grows, how it needs to be prepared.`
              : 'Pro lets you ask follow-up questions about any species in the guide.'}
          </Text>
          <PrimaryButton label="See what Pro includes" onPress={() => navigation.navigate('Paywall', {})} />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={styles.messages}>
          {messages.map((m) => (
            <View key={m.id} style={[styles.bubble, m.from === 'user' ? styles.userBubble : styles.assistantBubble]}>
              <Text style={[type.body, m.from === 'user' ? styles.userText : styles.assistantText]}>{m.text}</Text>
            </View>
          ))}
          {sending && (
            <View style={[styles.bubble, styles.assistantBubble]}>
              <ActivityIndicator size="small" color={colors.moss} />
            </View>
          )}
        </ScrollView>
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            placeholder={species ? `Ask about ${species.commonName}...` : 'Ask a question...'}
            placeholderTextColor={colors.fog}
            value={input}
            onChangeText={setInput}
            onSubmitEditing={send}
            editable={!sending}
          />
          <TouchableOpacity style={styles.sendButton} onPress={send} disabled={sending}>
            <MaterialIcons name="send" size={20} color={colors.white} />
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
  lockedWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.lg },
  lockedTitle: { color: colors.ink, marginTop: spacing.md, marginBottom: spacing.sm, textAlign: 'center' },
  lockedBody: { color: colors.charcoal, textAlign: 'center', marginBottom: spacing.xl },
  messages: { padding: spacing.lg, gap: spacing.sm },
  bubble: { maxWidth: '85%', borderRadius: radius.md, padding: spacing.md, marginBottom: spacing.sm },
  assistantBubble: { backgroundColor: colors.paper, borderWidth: 1, borderColor: colors.hairline, alignSelf: 'flex-start' },
  userBubble: { backgroundColor: colors.moss, alignSelf: 'flex-end' },
  assistantText: { color: colors.ink },
  userText: { color: colors.white },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.hairline,
  },
  input: {
    flex: 1,
    backgroundColor: colors.paper,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.hairline,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    color: colors.ink,
    marginRight: spacing.sm,
  },
  sendButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.moss,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
