import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { ActivityIndicator, View, StyleSheet } from 'react-native';
import { AuthContext, useAuthProvider } from '../hooks/useAuth';
import { AudioPlayerContext, useAudioPlayerProvider } from '../hooks/useAudioPlayer';
import { Colors } from '../constants/Colors';

export default function RootLayout() {
  const authValue = useAuthProvider();
  const audioValue = useAudioPlayerProvider();

  if (authValue.isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={Colors.gold} />
        <StatusBar style="light" />
      </View>
    );
  }

  return (
    <AuthContext.Provider value={authValue}>
      <AudioPlayerContext.Provider value={audioValue}>
        <StatusBar style="light" />
        <Stack screenOptions={{ headerShown: false }}>
          {!authValue.user ? (
            <Stack.Screen name="auth" options={{ headerShown: false }} />
          ) : !authValue.isApproved ? (
            <Stack.Screen name="pending" options={{ headerShown: false }} />
          ) : (
            <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          )}
        </Stack>
      </AudioPlayerContext.Provider>
    </AuthContext.Provider>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.navy,
  },
});
