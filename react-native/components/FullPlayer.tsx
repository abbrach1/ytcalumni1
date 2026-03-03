import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import Slider from '@react-native-community/slider';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../constants/Colors';
import { useAudioPlayer } from '../hooks/useAudioPlayer';

interface Props {
  onClose: () => void;
}

export default function FullPlayer({ onClose }: Props) {
  const player = useAudioPlayer();

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose}>
          <Ionicons name="chevron-down" size={24} color={Colors.navy} />
        </TouchableOpacity>
        <View style={{ flex: 1 }} />
        <TouchableOpacity onPress={() => { player.stop(); onClose(); }}>
          <Ionicons name="close-circle" size={24} color={Colors.navyOpacity(0.5)} />
        </TouchableOpacity>
      </View>

      <View style={styles.content}>
        {/* Album art placeholder */}
        <View style={styles.artworkContainer}>
          <View style={styles.artwork}>
            <Ionicons name="headset" size={60} color={Colors.navyOpacity(0.3)} />
          </View>
        </View>

        {/* Shiur info */}
        <Text style={styles.title} numberOfLines={2}>
          {player.currentShiurTitle}
        </Text>
        <Text style={styles.rebbe}>{player.currentShiurRebbe}</Text>

        {/* Progress slider */}
        <View style={styles.sliderContainer}>
          <Slider
            style={styles.slider}
            minimumValue={0}
            maximumValue={Math.max(player.duration, 1)}
            value={player.currentTime}
            onSlidingComplete={(val) => player.seek(val)}
            minimumTrackTintColor={Colors.gold}
            maximumTrackTintColor={Colors.navyOpacity(0.2)}
            thumbTintColor={Colors.gold}
          />
          <View style={styles.timeRow}>
            <Text style={styles.timeText}>{player.formatTime(player.currentTime)}</Text>
            <Text style={styles.timeText}>{player.formatTime(player.duration)}</Text>
          </View>
        </View>

        {/* Main controls */}
        <View style={styles.mainControls}>
          <TouchableOpacity onPress={player.skipBackward}>
            <Ionicons name="play-back" size={32} color={Colors.navy} />
          </TouchableOpacity>

          <TouchableOpacity onPress={player.togglePlayPause} style={styles.bigPlayButton}>
            <Ionicons
              name={player.isPlaying ? 'pause' : 'play'}
              size={36}
              color={Colors.cream}
            />
          </TouchableOpacity>

          <TouchableOpacity onPress={player.skipForward}>
            <Ionicons name="play-forward" size={32} color={Colors.navy} />
          </TouchableOpacity>
        </View>

        {/* Speed control */}
        <View style={styles.speedRow}>
          {player.speedOptions.map((speed) => (
            <TouchableOpacity
              key={speed}
              style={[
                styles.speedButton,
                player.playbackSpeed === speed && styles.speedButtonActive,
              ]}
              onPress={() => player.setSpeed(speed)}
            >
              <Text
                style={[
                  styles.speedText,
                  player.playbackSpeed === speed && styles.speedTextActive,
                ]}
              >
                {speed}x
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  artworkContainer: {
    marginBottom: 32,
  },
  artwork: {
    width: 200,
    height: 200,
    borderRadius: 100,
    backgroundColor: Colors.navyOpacity(0.1),
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 20,
    fontWeight: '600',
    color: Colors.navy,
    textAlign: 'center',
    marginBottom: 8,
  },
  rebbe: {
    fontSize: 16,
    color: Colors.navyOpacity(0.7),
    marginBottom: 32,
  },
  sliderContainer: {
    width: '100%',
    marginBottom: 32,
  },
  slider: {
    width: '100%',
    height: 40,
  },
  timeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  timeText: {
    fontSize: 12,
    color: Colors.navyOpacity(0.6),
    fontVariant: ['tabular-nums'],
  },
  mainControls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 40,
    marginBottom: 32,
  },
  bigPlayButton: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: Colors.navy,
    alignItems: 'center',
    justifyContent: 'center',
  },
  speedRow: {
    flexDirection: 'row',
    gap: 8,
  },
  speedButton: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: Colors.navyOpacity(0.1),
  },
  speedButtonActive: {
    backgroundColor: Colors.navy,
  },
  speedText: {
    fontSize: 13,
    fontWeight: '500',
    color: Colors.navy,
  },
  speedTextActive: {
    color: Colors.cream,
  },
});
