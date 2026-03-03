import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../constants/Colors';
import { useAudio } from '../contexts/AudioContext';

export default function MiniPlayer() {
  const { currentShiur, isPlaying, isLoading, pauseResume, stop } = useAudio();

  if (!currentShiur) return null;

  return (
    <View style={styles.container}>
      <View style={styles.info}>
        <Text style={styles.title} numberOfLines={1}>
          {currentShiur.title}
        </Text>
        <Text style={styles.rebbe} numberOfLines={1}>
          {currentShiur.rebbe}
        </Text>
      </View>

      <View style={styles.controls}>
        {isLoading ? (
          <ActivityIndicator color={Colors.cream} size="small" />
        ) : (
          <TouchableOpacity onPress={pauseResume} style={styles.btn}>
            <Ionicons
              name={isPlaying ? 'pause' : 'play'}
              size={24}
              color={Colors.cream}
            />
          </TouchableOpacity>
        )}
        <TouchableOpacity onPress={stop} style={styles.btn}>
          <Ionicons name="close" size={24} color={Colors.cream} />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.navy,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: Colors.navyLight,
  },
  info: { flex: 1, marginRight: 12 },
  title: { color: Colors.cream, fontSize: 14, fontWeight: '600' },
  rebbe: { color: Colors.creamOpacity70, fontSize: 12, marginTop: 2 },
  controls: { flexDirection: 'row', gap: 8 },
  btn: { padding: 6 },
});
