import { Tabs } from 'expo-router';
import { View, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../constants/Colors';
import MiniPlayer from '../../components/MiniPlayer';
import { useAudioPlayer } from '../../hooks/useAudioPlayer';

export default function TabLayout() {
  const audioPlayer = useAudioPlayer();

  return (
    <View style={styles.container}>
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: Colors.gold,
          tabBarInactiveTintColor: Colors.navyOpacity(0.4),
          tabBarStyle: {
            backgroundColor: Colors.white,
            borderTopColor: Colors.navyOpacity(0.1),
          },
          tabBarLabelStyle: {
            fontSize: 11,
            fontWeight: '500',
          },
        }}
      >
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
      {audioPlayer.currentShiurId && <MiniPlayer />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
