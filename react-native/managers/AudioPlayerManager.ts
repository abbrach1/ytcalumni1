import { Audio, AVPlaybackStatus } from 'expo-av';
import { doc, getDoc, setDoc, updateDoc, deleteField } from 'firebase/firestore';
import { db, auth } from '../services/firebaseConfig';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface AudioState {
  currentShiurId: string | null;
  currentShiurTitle: string;
  currentShiurRebbe: string;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  isLoading: boolean;
  playbackSpeed: number;
  error: string | null;
}

const SPEED_OPTIONS = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

let soundObject: Audio.Sound | null = null;
let playedShiurimIds = new Set<string>();

export { SPEED_OPTIONS };

export async function setupAudioMode() {
  await Audio.setAudioModeAsync({
    allowsRecordingIOS: false,
    staysActiveInBackground: true,
    playsInSilentModeIOS: true,
    shouldDuckAndroid: true,
    playThroughEarpieceAndroid: false,
  });
}

/** Process Google Drive URLs to direct download links */
function processAudioUrl(url: string): string {
  if (url.includes('drive.google.com')) {
    const fileIdMatch = url.match(/\/file\/d\/([^/]+)/);
    if (fileIdMatch) {
      return `https://drive.google.com/uc?export=download&id=${fileIdMatch[1]}`;
    }
    const idMatch = url.match(/id=([^&]+)/);
    if (idMatch) {
      return `https://drive.google.com/uc?export=download&id=${idMatch[1]}`;
    }
  }
  return url;
}

export async function playSoundFromUrl(
  audioUrl: string,
  shiurId: string,
  onStatusUpdate: (status: AVPlaybackStatus) => void,
  playbackSpeed: number = 1.0
): Promise<Audio.Sound> {
  // Stop existing
  if (soundObject) {
    await soundObject.unloadAsync();
    soundObject = null;
  }

  const processedUrl = processAudioUrl(audioUrl);
  const { sound } = await Audio.Sound.createAsync(
    { uri: processedUrl },
    { shouldPlay: true, rate: playbackSpeed, shouldCorrectPitch: true },
    onStatusUpdate
  );

  soundObject = sound;

  // Increment play count once per session
  if (!playedShiurimIds.has(shiurId)) {
    playedShiurimIds.add(shiurId);
    const { incrementPlayCount } = await import('../services/firebase');
    incrementPlayCount(shiurId).catch(console.error);
  }

  return sound;
}

export async function togglePlayPause(isPlaying: boolean) {
  if (!soundObject) return;
  if (isPlaying) {
    await soundObject.pauseAsync();
  } else {
    await soundObject.playAsync();
  }
}

export async function seekTo(positionMs: number) {
  if (!soundObject) return;
  await soundObject.setPositionAsync(positionMs);
}

export async function skipForward(currentMs: number, durationMs: number) {
  const newPos = Math.min(currentMs + 15000, durationMs);
  await seekTo(newPos);
}

export async function skipBackward(currentMs: number) {
  const newPos = Math.max(currentMs - 15000, 0);
  await seekTo(newPos);
}

export async function setPlaybackRate(speed: number) {
  if (!soundObject) return;
  await soundObject.setRateAsync(speed, true);
}

export async function setVolume(vol: number) {
  if (!soundObject) return;
  await soundObject.setVolumeAsync(vol);
}

export async function stopPlayback() {
  if (soundObject) {
    await soundObject.stopAsync();
    await soundObject.unloadAsync();
    soundObject = null;
  }
}

// Playback position persistence
export async function savePlaybackPosition(shiurId: string, positionSeconds: number) {
  // Save locally
  await AsyncStorage.setItem(`playback_position_${shiurId}`, String(positionSeconds));

  // Save to Firebase
  const userId = auth.currentUser?.uid;
  if (!userId) return;

  const docRef = doc(db, 'users', userId, 'preferences', 'playbackPositions');
  const now = Date.now();

  try {
    const snap = await getDoc(docRef);
    if (snap.exists()) {
      await updateDoc(docRef, {
        [`positions.${shiurId}`]: positionSeconds,
        lastUpdated: now,
        syncedAt: now,
      });
    } else {
      await setDoc(docRef, {
        positions: { [shiurId]: positionSeconds },
        lastUpdated: now,
        syncedAt: now,
      });
    }
  } catch (error) {
    console.error('Error saving playback position:', error);
  }
}

export async function getLocalPlaybackPosition(shiurId: string): Promise<number> {
  const val = await AsyncStorage.getItem(`playback_position_${shiurId}`);
  return val ? parseFloat(val) : 0;
}

export async function fetchPlaybackPositionFromFirebase(shiurId: string): Promise<number> {
  const userId = auth.currentUser?.uid;
  if (!userId) return getLocalPlaybackPosition(shiurId);

  try {
    const snap = await getDoc(doc(db, 'users', userId, 'preferences', 'playbackPositions'));
    if (snap.exists()) {
      const positions = snap.data()?.positions;
      if (positions && typeof positions[shiurId] === 'number') {
        await AsyncStorage.setItem(`playback_position_${shiurId}`, String(positions[shiurId]));
        return positions[shiurId];
      }
    }
  } catch (error) {
    console.error('Error fetching playback position:', error);
  }

  return getLocalPlaybackPosition(shiurId);
}

export async function fetchAllPlaybackPositions(): Promise<Record<string, number>> {
  const userId = auth.currentUser?.uid;
  if (!userId) return {};

  try {
    const snap = await getDoc(doc(db, 'users', userId, 'preferences', 'playbackPositions'));
    if (snap.exists()) {
      const positions = snap.data()?.positions ?? {};
      const result: Record<string, number> = {};
      for (const [key, value] of Object.entries(positions)) {
        if (typeof value === 'number') {
          result[key] = value;
          await AsyncStorage.setItem(`playback_position_${key}`, String(value));
        }
      }
      return result;
    }
  } catch (error) {
    console.error('Error fetching all playback positions:', error);
  }

  return {};
}

export async function clearPlaybackPosition(shiurId: string) {
  await AsyncStorage.removeItem(`playback_position_${shiurId}`);

  const userId = auth.currentUser?.uid;
  if (!userId) return;

  try {
    const docRef = doc(db, 'users', userId, 'preferences', 'playbackPositions');
    await updateDoc(docRef, {
      [`positions.${shiurId}`]: deleteField(),
      lastUpdated: Date.now(),
      syncedAt: Date.now(),
    });
  } catch (error) {
    console.error('Error clearing playback position:', error);
  }
}

export function formatTime(seconds: number): string {
  if (isNaN(seconds) || !isFinite(seconds)) return '0:00';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${m}:${String(s).padStart(2, '0')}`;
}
