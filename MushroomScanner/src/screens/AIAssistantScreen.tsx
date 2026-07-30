import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { getSpeciesById } from '../data/species';
import { colors, radius, spacing, type } from '../theme';

type Props = NativeStackScreenProps<RootStackParamList, 'AIAssistant'>;

interface Message {
  id: string;
  from: 'user' | 'assistant';
  text: string;
}

// Chat scoped to a single species (habitat, prep, look-alikes) - not a
// general-purpose chatbot. Wiring to a real model call lands in build step 6.
export function AIAssistantScreen({ route }: Props) {
  const species = getSpeciesById(route.params.speciesId);
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      from: 'assistant',
      text: species
        ? `Ask me anything about ${species.commonName} (${species.latinName}) - habitat, prep, or how to tell it apart from look-alikes.`
        : 'Ask me anything about this species.',
    },
  ]);

  function send() {
    if (!input.trim()) return;
    const userMessage: Message = { id: `${Date.now()}-u`, from: 'user', text: input.trim() };
    const reply: Message = {
      id: `${Date.now()}-a`,
      from: 'assistant',
      text: 'This is a placeholder response - the assistant will be connected to a live model in a later build step.',
    };
    setMessages((prev) => [...prev, userMessage, reply]);
    setInput('');
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
        </ScrollView>
        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            placeholder={species ? `Ask about ${species.commonName}...` : 'Ask a question...'}
            placeholderTextColor={colors.fog}
            value={input}
            onChangeText={setInput}
            onSubmitEditing={send}
          />
          <TouchableOpacity style={styles.sendButton} onPress={send}>
            <MaterialIcons name="send" size={20} color={colors.white} />
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.cream },
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
