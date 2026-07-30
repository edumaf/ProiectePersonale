import { supabase } from './supabase';

export interface AssistantMessage {
  role: 'user' | 'assistant';
  text: string;
}

/** Calls the ask-species edge function (real Claude chat scoped to one species). */
export async function askSpecies(speciesId: string, messages: AssistantMessage[]): Promise<string> {
  if (!supabase) throw new Error('Supabase is not configured');
  const { data, error } = await supabase.functions.invoke('ask-species', {
    body: { speciesId, messages },
  });
  if (error) throw error;
  return (data as { reply: string }).reply;
}
