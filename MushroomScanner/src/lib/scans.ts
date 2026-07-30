// expo-file-system's default export is the new File/Directory API (SDK 54+);
// readAsStringAsync/EncodingType still live under the legacy subpath.
import * as FileSystem from 'expo-file-system/legacy';
import { supabase } from './supabase';
import { Collection, ScanPhoto, ScanResult } from '../types/models';

export interface IdentifyResult {
  speciesId: string | null;
  confidencePercent: number;
  reasoning: string;
  notableFeatures: string[];
}

interface CapturedPhoto {
  angle: ScanPhoto['angle'];
  uri: string;
}

function requireSupabase() {
  if (!supabase) throw new Error('Supabase is not configured');
  return supabase;
}

function mimeTypeFor(uri: string) {
  const ext = uri.split('.').pop()?.toLowerCase();
  if (ext === 'png') return 'image/png';
  if (ext === 'webp') return 'image/webp';
  return 'image/jpeg';
}

/** Sends photos to the identify edge function (real Claude vision call). */
export async function identifyPhotos(photos: CapturedPhoto[]): Promise<IdentifyResult> {
  const client = requireSupabase();
  const encoded = await Promise.all(
    photos.map(async (photo) => ({
      angle: photo.angle,
      mediaType: mimeTypeFor(photo.uri),
      base64: await FileSystem.readAsStringAsync(photo.uri, { encoding: FileSystem.EncodingType.Base64 }),
    }))
  );

  const { data, error } = await client.functions.invoke('identify', { body: { photos: encoded } });
  if (error) throw error;
  return data as IdentifyResult;
}

/** Uploads each captured photo to Storage under the user's own folder. */
export async function uploadScanPhotos(userId: string, localScanId: string, photos: CapturedPhoto[]): Promise<ScanPhoto[]> {
  const client = requireSupabase();
  const uploaded: ScanPhoto[] = [];

  for (const photo of photos) {
    const path = `${userId}/${localScanId}/${photo.angle}.jpg`;
    const blob = await (await fetch(photo.uri)).blob();
    const { error } = await client.storage.from('scan-photos').upload(path, blob, {
      contentType: mimeTypeFor(photo.uri),
      upsert: true,
    });
    if (error) throw error;
    const { data } = client.storage.from('scan-photos').getPublicUrl(path);
    uploaded.push({ angle: photo.angle, url: data.publicUrl });
  }

  return uploaded;
}

interface ScanRow {
  id: string;
  user_id: string;
  photos: ScanPhoto[];
  species_id: string | null;
  confidence_score: string | number;
  timestamp: string;
  location_label: string | null;
  collection_id: string | null;
  user_notes: string | null;
}

function mapScanRow(row: ScanRow): ScanResult {
  return {
    id: row.id,
    photos: row.photos,
    speciesId: row.species_id,
    confidencePercent: Number(row.confidence_score),
    timestamp: row.timestamp,
    locationLabel: row.location_label ?? undefined,
    collectionId: row.collection_id ?? undefined,
    userNotes: row.user_notes ?? undefined,
  };
}

export async function insertScan(
  userId: string,
  photos: ScanPhoto[],
  result: IdentifyResult,
  collectionId?: string
): Promise<ScanResult> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('scans')
    .insert({
      user_id: userId,
      photos,
      species_id: result.speciesId,
      confidence_score: result.confidencePercent,
      collection_id: collectionId ?? null,
    })
    .select()
    .single();
  if (error) throw error;
  return mapScanRow(data as ScanRow);
}

export async function fetchScanById(id: string): Promise<ScanResult | null> {
  const client = requireSupabase();
  const { data, error } = await client.from('scans').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data ? mapScanRow(data as ScanRow) : null;
}

export async function fetchScans(userId: string, options?: { limit?: number; collectionId?: string }): Promise<ScanResult[]> {
  const client = requireSupabase();
  let query = client.from('scans').select('*').eq('user_id', userId).order('timestamp', { ascending: false });
  if (options?.collectionId) query = query.eq('collection_id', options.collectionId);
  if (options?.limit) query = query.limit(options.limit);
  const { data, error } = await query;
  if (error) throw error;
  return (data as ScanRow[]).map(mapScanRow);
}

interface CollectionRow {
  id: string;
  user_id: string;
  name: string;
  created_at: string;
}

function mapCollectionRow(row: CollectionRow): Collection {
  return { id: row.id, name: row.name, createdAt: row.created_at, scanIds: [] };
}

export async function fetchCollections(userId: string): Promise<Collection[]> {
  const client = requireSupabase();
  const { data, error } = await client
    .from('collections')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return (data as CollectionRow[]).map(mapCollectionRow);
}

export async function createCollection(userId: string, name: string): Promise<Collection> {
  const client = requireSupabase();
  const { data, error } = await client.from('collections').insert({ user_id: userId, name }).select().single();
  if (error) throw error;
  return mapCollectionRow(data as CollectionRow);
}
