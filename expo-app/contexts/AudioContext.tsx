import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import { Audio } from 'expo-av';
import { Shiur } from '../types';
import { incrementPlayCount } from '../services/firebase';

interface AudioState {
  currentShiur: Shiur | null;
  isPlaying: boolean;
  position: number;      // seconds
  duration: number;      // seconds
  isLoading: boolean;
}

interface AudioContextValue extends AudioState {
  playShiur: (shiur: Shiur) => Promise<void>;
  pauseResume: () => Promise<void>;
  seek: (seconds: number) => Promise<void>;
  stop: () => Promise<void>;
  skipForward: () => Promise<void>;
  skipBackward: () => Promise<void>;
}

const AudioContext = createContext<AudioContextValue>({
  currentShiur: null,
  isPlaying: false,
  position: 0,
  duration: 0,
  isLoading: false,
  playShiur: async () => {},
  pauseResume: async () => {},
  seek: async () => {},
  stop: async () => {},
  skipForward: async () => {},
  skipBackward: async () => {},
});

export function AudioProvider({ children }: { children: React.ReactNode }) {
  const soundRef = useRef<Audio.Sound | null>(null);
  const [state, setState] = useState<AudioState>({
    currentShiur: null,
    isPlaying: false,
    position: 0,
    duration: 0,
    isLoading: false,
  });

  useEffect(() => {
    Audio.setAudioModeAsync({
      allowsRecordingIOS: false,
      staysActiveInBackground: true,
      playsInSilentModeIOS: true,
    });
    return () => {
      soundRef.current?.unloadAsync();
    };
  }, []);

  const playShiur = async (shiur: Shiur) => {
    if (!shiur.audioUrl) return;

    // Unload existing sound
    if (soundRef.current) {
      await soundRef.current.unloadAsync();
      soundRef.current = null;
    }

    setState((prev) => ({ ...prev, currentShiur: shiur, isLoading: true, isPlaying: false, position: 0, duration: 0 }));

    try {
      const { sound } = await Audio.Sound.createAsync(
        { uri: shiur.audioUrl },
        { shouldPlay: true },
        (status) => {
          if (status.isLoaded) {
            setState((prev) => ({
              ...prev,
              isPlaying: status.isPlaying,
              position: (status.positionMillis ?? 0) / 1000,
              duration: (status.durationMillis ?? 0) / 1000,
              isLoading: false,
            }));
          }
        }
      );
      soundRef.current = sound;
      if (shiur.id) {
        incrementPlayCount(shiur.id).catch(() => {});
      }
    } catch (e) {
      console.error('Audio load error:', e);
      setState((prev) => ({ ...prev, isLoading: false }));
    }
  };

  const pauseResume = async () => {
    if (!soundRef.current) return;
    if (state.isPlaying) {
      await soundRef.current.pauseAsync();
    } else {
      await soundRef.current.playAsync();
    }
  };

  const seek = async (seconds: number) => {
    await soundRef.current?.setPositionAsync(seconds * 1000);
  };

  const stop = async () => {
    await soundRef.current?.stopAsync();
    await soundRef.current?.unloadAsync();
    soundRef.current = null;
    setState({ currentShiur: null, isPlaying: false, position: 0, duration: 0, isLoading: false });
  };

  const skipForward = async () => {
    const newPos = Math.min(state.position + 15, state.duration);
    await seek(newPos);
  };

  const skipBackward = async () => {
    const newPos = Math.max(state.position - 15, 0);
    await seek(newPos);
  };

  return (
    <AudioContext.Provider value={{ ...state, playShiur, pauseResume, seek, stop, skipForward, skipBackward }}>
      {children}
    </AudioContext.Provider>
  );
}

export const useAudio = () => useContext(AudioContext);
