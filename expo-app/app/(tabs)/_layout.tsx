import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../constants/Colors';
import { View, StyleSheet } from 'react-native';
import { useAudio } from '../../contexts/AudioContext';
import MiniPlayer from '../../components/MiniPlayer';

export default function TabLayout() {
  const { currentShiur } = useAudio();

  return (
    <View style={{ flex: 1 }}>
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: Colors.gold,
          tabBarInactiveTintColor: Colors.navyOpacity50,
          tabBarStyle: {
            backgroundColor: Colors.white,
            borderTopColor: Colors.creamDark,
            borderTopWidth: 1,
            height: 56,
            paddingBottom: 6,
          },
          tabBarLabelStyle: { fontSize: 11, fontWeight: '500' },
        }}>
        <Tabs.Screen
          name="index"
          options={{
            title: 'Home',
            tabBarIcon: ({ color, size }) => (
              <Ionicons name="home" size={size} color={color} />
            ),
          }}
        />
        <Tabs.Screen
          name="shiurim"
          options={{
            title: 'Shiurim',
            tabBarIcon: ({ color, size }) => (
              <Ionicons name="headset" size={size} color={color} />
            ),
          }}
        />
        <Tabs.Screen
          name="events"
          options={{
            title: 'Events',
            tabBarIcon: ({ color, size }) => (
              <Ionicons name="calendar" size={size} color={color} />
            ),
          }}
        />
        <Tabs.Screen
          name="contacts"
          options={{
            title: 'Contacts',
            tabBarIcon: ({ color, size }) => (
              <Ionicons name="people" size={size} color={color} />
            ),
          }}
        />
      </Tabs>

      {/* Mini Player floats above the tab bar */}
      {currentShiur && (
        <View style={styles.miniPlayerWrapper}>
          <MiniPlayer />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  miniPlayerWrapper: {
    position: 'absolute',
    bottom: 56,
    left: 0,
    right: 0,
  },
});
