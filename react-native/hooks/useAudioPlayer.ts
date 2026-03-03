import { useState, useCallback, useRef, createContext, useContext } from 'react';
import { AVPlaybackStatus } from 'expo-av';
import {
  AudioState,
  setupAudioMode,
  playSoundFromUrl,
  togglePlayPause as togglePP,
  seekTo,
  skipForward as sf,
  skipBackward as sb,
  setPlaybackRate,
  stopPlayback,
  savePlaybackPosition,
  fetchPlaybackPositionFromFirebase,
  clearPlaybackPosition,
  formatTime,
  SPEED_OPTIONS,
} from '../managers/AudioPlayerManager';
import { Shiur } from '../services/firebase';

const initialState: AudioState = {
  currentShiurId: null,
  currentShiurTitle: '',
  currentShiurRebbe: '',
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  isLoading: false,
  playbackSpeed: 1.0,
  error: null,
};

export function useAudioPlayerProvider() {
  const [state, setState] = useState<AudioState>(initialState);
  const saveTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const currentShiurRef = useRef<Shiur | null>(null);

  const handleStatusUpdate = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) {
      if ('error' in status && status.error) {
        setState((s) => ({ ...s, error: status.error ?? 'Playback error', isLoading: false }));
      }
      return;
    }

    setState((s) => ({
      ...s,
      isPlaying: status.isPlaying,
      currentTime: (status.positionMillis ?? 0) / 1000,
      duration: (status.durationMillis ?? 0) / 1000,
      isLoading: false,
    }));

    // Handle playback finished
    if (status.didJustFinish) {
      setState((s) => ({ ...s, isPlaying: false, currentTime: 0 }));
      if (currentShiurRef.current?.id) {
        clearPlaybackPosition(currentShiurRef.current.id);
      }
    }
  }, []);

  const play = useCallback(async (shiur: Shiur) => {
    if (!shiur.audioUrl) {
      setState((s) => ({ ...s, error: 'No audio URL' }));
      return;
    }

    // Stop existing save timer
    if (saveTimerRef.current) {
      clearInterval(saveTimerRef.current);
      saveTimerRef.current = null;
    }

    setState((s) => ({
      ...s,
      currentShiurId: shiur.id,
      currentShiurTitle: shiur.title,
      currentShiurRebbe: shiur.rebbe,
      isLoading: true,
      error: null,
      currentTime: 0,
      duration: 0,
    }));
    currentShiurRef.current = shiur;

    try {
      await setupAudioMode();
      const sound = await playSoundFromUrl(
        shiur.audioUrl,
        shiur.id,
        handleStatusUpdate,
        state.playbackSpeed
      );

      // Restore position
      const savedPosition = await fetchPlaybackPositionFromFirebase(shiur.id);
      if (savedPosition > 0) {
        const status = await sound.getStatusAsync();
        if (status.isLoaded) {
          const durationSec = (status.durationMillis ?? 0) / 1000;
          if (savedPosition < durationSec - 5) {
            await sound.setPositionAsync(savedPosition * 1000);
          }
        }
      }

      // Auto-save position every 5 seconds
      saveTimerRef.current = setInterval(() => {
        setState((currentState) => {
          if (currentState.currentShiurId && currentState.isPlaying && currentState.currentTime > 0) {
            savePlaybackPosition(currentState.currentShiurId, currentState.currentTime);
          }
          return currentState;
        });
      }, 5000);
    } catch (error: any) {
      setState((s) => ({
        ...s,
        error: error.message || 'Failed to load audio',
        isLoading: false,
      }));
    }
  }, [state.playbackSpeed, handleStatusUpdate]);

  const togglePlayPause = useCallback(async () => {
    await togglePP(state.isPlaying);
  }, [state.isPlaying]);

  const seek = useCallback(async (seconds: number) => {
    await seekTo(seconds * 1000);
    setState((s) => ({ ...s, currentTime: seconds }));
  }, []);

  const skipForward = useCallback(async () => {
    await sf(state.currentTime * 1000, state.duration * 1000);
  }, [state.currentTime, state.duration]);

  const skipBackward = useCallback(async () => {
    await sb(state.currentTime * 1000);
  }, [state.currentTime]);

  const setSpeed = useCallback(async (speed: number) => {
    await setPlaybackRate(speed);
    setState((s) => ({ ...s, playbackSpeed: speed }));
  }, []);

  const stop = useCallback(async () => {
    if (saveTimerRef.current) {
      clearInterval(saveTimerRef.current);
      saveTimerRef.current = null;
    }
    await stopPlayback();
    currentShiurRef.current = null;
    setState(initialState);
  }, []);

  return {
    ...state,
    play,
    togglePlayPause,
    seek,
    skipForward,
    skipBackward,
    setSpeed,
    stop,
    formatTime,
    speedOptions: SPEED_OPTIONS,
  };
}

export type AudioPlayerContextType = ReturnType<typeof useAudioPlayerProvider>;

export const AudioPlayerContext = createContext<AudioPlayerContextType | null>(null);

export function useAudioPlayer() {
  const context = useContext(AudioPlayerContext);
  if (!context) throw new Error('useAudioPlayer must be within AudioPlayerProvider');
  return context;
}
