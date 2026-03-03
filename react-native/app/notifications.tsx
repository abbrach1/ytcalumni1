import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  Switch,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Platform,
  TouchableOpacity,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../constants/Colors';
import { fetchShiurim } from '../services/firebase';
import AsyncStorage from '@react-native-async-storage/async-storage';

export default function NotificationPreferencesScreen() {
  const router = useRouter();
  const [rebbeNames, setRebbeNames] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // Toggle states
  const [announcementsEnabled, setAnnouncementsEnabled] = useState(true);
  const [simchasEnabled, setSimchasEnabled] = useState(true);
  const [newShiurimEnabled, setNewShiurimEnabled] = useState(true);
  const [rebbeToggles, setRebbeToggles] = useState<Record<string, boolean>>({});

  useEffect(() => {
    loadData();
  }, []);

  const sanitizeTopicName = (name: string) =>
    name.toLowerCase().replace(/[^a-z0-9]/g, '_');

  const loadData = async () => {
    setIsLoading(true);

    try {
      const shiurim = await fetchShiurim();
      const unique = [...new Set(shiurim.map((s) => s.rebbe).filter(Boolean))].sort();
      setRebbeNames(unique);

      // Load saved preferences
      const annVal = await AsyncStorage.getItem('notif_announcements');
      const simVal = await AsyncStorage.getItem('notif_simchas');
      const shiurVal = await AsyncStorage.getItem('notif_new_shiurim');

      if (annVal !== null) setAnnouncementsEnabled(annVal === 'true');
      if (simVal !== null) setSimchasEnabled(simVal === 'true');
      if (shiurVal !== null) setNewShiurimEnabled(shiurVal === 'true');

      const toggles: Record<string, boolean> = {};
      for (const name of unique) {
        const key = sanitizeTopicName(name);
        const val = await AsyncStorage.getItem(`notif_rebbe_${key}`);
        toggles[key] = val === 'true';
      }
      setRebbeToggles(toggles);
    } catch (error) {
      console.error('Error loading notification data:', error);
    }

    setIsLoading(false);
  };

  const toggleTopic = async (topic: string, enabled: boolean) => {
    await AsyncStorage.setItem(`notif_${topic}`, String(enabled));
    // In production, subscribe/unsubscribe from FCM topic here
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()}>
          <Ionicons name="arrow-back" size={24} color={Colors.navy} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Notifications</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView style={styles.scrollContent}>
        {/* General Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>General</Text>

          <View style={styles.toggleRow}>
            <View style={styles.toggleInfo}>
              <Ionicons name="megaphone" size={20} color={Colors.navy} />
              <Text style={styles.toggleLabel}>Announcements</Text>
            </View>
            <Switch
              value={announcementsEnabled}
              onValueChange={(val) => {
                setAnnouncementsEnabled(val);
                toggleTopic('announcements', val);
              }}
              trackColor={{ false: Colors.navyOpacity(0.2), true: Colors.gold }}
              thumbColor={Colors.white}
            />
          </View>

          <View style={styles.toggleRow}>
            <View style={styles.toggleInfo}>
              <Ionicons name="sparkles" size={20} color={Colors.navy} />
              <Text style={styles.toggleLabel}>Simchas & Mazel Tovs</Text>
            </View>
            <Switch
              value={simchasEnabled}
              onValueChange={(val) => {
                setSimchasEnabled(val);
                toggleTopic('simchas', val);
              }}
              trackColor={{ false: Colors.navyOpacity(0.2), true: Colors.gold }}
              thumbColor={Colors.white}
            />
          </View>

          <Text style={styles.sectionFooter}>
            Get notified about community announcements and simchas.
          </Text>
        </View>

        {/* Shiurim Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Shiurim</Text>

          <View style={styles.toggleRow}>
            <View style={styles.toggleInfo}>
              <Ionicons name="headset" size={20} color={Colors.navy} />
              <Text style={styles.toggleLabel}>All New Shiurim</Text>
            </View>
            <Switch
              value={newShiurimEnabled}
              onValueChange={(val) => {
                setNewShiurimEnabled(val);
                toggleTopic('new_shiurim', val);
              }}
              trackColor={{ false: Colors.navyOpacity(0.2), true: Colors.gold }}
              thumbColor={Colors.white}
            />
          </View>

          <Text style={styles.sectionFooter}>
            Get notified when any new shiur is uploaded. You can also choose specific Rebbeim below.
          </Text>
        </View>

        {/* Per-Rebbe Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notify by Rebbe</Text>

          {isLoading ? (
            <ActivityIndicator size="small" color={Colors.navy} style={{ marginVertical: 16 }} />
          ) : rebbeNames.length === 0 ? (
            <Text style={styles.emptyText}>No Rebbeim available yet.</Text>
          ) : (
            rebbeNames.map((name) => {
              const key = sanitizeTopicName(name);
              return (
                <View key={key} style={styles.toggleRow}>
                  <Text style={styles.toggleLabel}>{name}</Text>
                  <Switch
                    value={rebbeToggles[key] ?? false}
                    onValueChange={(val) => {
                      setRebbeToggles((prev) => ({ ...prev, [key]: val }));
                      toggleTopic(`rebbe_${key}`, val);
                    }}
                    trackColor={{ false: Colors.navyOpacity(0.2), true: Colors.gold }}
                    thumbColor={Colors.white}
                  />
                </View>
              );
            })
          )}

          <Text style={styles.sectionFooter}>
            Get notified when a specific Rebbe's shiur is uploaded.
          </Text>
        </View>

        <View style={{ height: 40 }} />
      </ScrollView>
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
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'ios' ? 60 : 16,
    paddingBottom: 12,
    backgroundColor: Colors.cream,
    borderBottomWidth: 1,
    borderBottomColor: Colors.navyOpacity(0.1),
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  scrollContent: {
    flex: 1,
  },
  section: {
    paddingHorizontal: 16,
    paddingVertical: 20,
    borderBottomWidth: 1,
    borderBottomColor: Colors.navyOpacity(0.08),
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: Colors.navyOpacity(0.5),
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 12,
  },
  sectionFooter: {
    fontSize: 12,
    color: Colors.navyOpacity(0.5),
    marginTop: 8,
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  toggleInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  toggleLabel: {
    fontSize: 16,
    color: Colors.navy,
  },
  emptyText: {
    fontSize: 14,
    color: Colors.navyOpacity(0.5),
    paddingVertical: 8,
  },
});
