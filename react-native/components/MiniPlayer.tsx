import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Modal } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../constants/Colors';
import { useAudioPlayer } from '../hooks/useAudioPlayer';
import FullPlayer from './FullPlayer';

export default function MiniPlayer() {
  const player = useAudioPlayer();
  const [showFullPlayer, setShowFullPlayer] = useState(false);

  if (!player.currentShiurId) return null;

  const progress = player.duration > 0 ? player.currentTime / player.duration : 0;

  return (
    <>
      <TouchableOpacity
        style={styles.container}
        onPress={() => setShowFullPlayer(true)}
        activeOpacity={0.9}
      >
        {/* Progress bar */}
        <View style={styles.progressBar}>
          <View style={[styles.progressFill, { width: `${progress * 100}%` }]} />
        </View>

        <View style={styles.content}>
          {/* Info */}
          <View style={styles.info}>
            <Text style={styles.title} numberOfLines={1}>
              {player.currentShiurTitle}
            </Text>
            <Text style={styles.rebbe} numberOfLines={1}>
              {player.currentShiurRebbe}
            </Text>
          </View>

          {/* Time */}
          <Text style={styles.time}>{player.formatTime(player.currentTime)}</Text>

          {/* Controls */}
          <View style={styles.controls}>
            <TouchableOpacity onPress={player.skipBackward}>
              <Ionicons name="play-back" size={20} color={Colors.cream} />
            </TouchableOpacity>

            <TouchableOpacity onPress={player.togglePlayPause} style={styles.playButton}>
              <Ionicons
                name={player.isPlaying ? 'pause' : 'play'}
                size={20}
                color={Colors.navy}
              />
            </TouchableOpacity>

            <TouchableOpacity onPress={player.skipForward}>
              <Ionicons name="play-forward" size={20} color={Colors.cream} />
            </TouchableOpacity>

            <TouchableOpacity onPress={player.stop}>
              <Ionicons name="close" size={16} color={Colors.creamOpacity(0.7)} />
            </TouchableOpacity>
          </View>
        </View>
      </TouchableOpacity>

      <Modal
        visible={showFullPlayer}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowFullPlayer(false)}
      >
        <FullPlayer onClose={() => setShowFullPlayer(false)} />
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 49, // tab bar height
    left: 0,
    right: 0,
    backgroundColor: Colors.navy,
  },
  progressBar: {
    height: 3,
    backgroundColor: Colors.navyOpacity(0.3),
  },
  progressFill: {
    height: '100%',
    backgroundColor: Colors.gold,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 12,
  },
  info: {
    flex: 1,
  },
  title: {
    color: Colors.cream,
    fontSize: 14,
    fontWeight: '600',
  },
  rebbe: {
    color: Colors.creamOpacity(0.7),
    fontSize: 12,
  },
  time: {
    color: Colors.creamOpacity(0.7),
    fontSize: 12,
    fontVariant: ['tabular-nums'],
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  playButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Colors.gold,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
