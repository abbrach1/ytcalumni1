import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../constants/Colors';
import { useAuth } from '../hooks/useAuth';

export default function PendingScreen() {
  const { signOut, refreshStatus } = useAuth();
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    await refreshStatus();
    setIsRefreshing(false);
  };

  return (
    <View style={styles.container}>
      <View style={styles.iconContainer}>
        <Ionicons name="time-outline" size={48} color={Colors.gold} />
      </View>

      <Text style={styles.title}>Access Pending</Text>
      <Text style={styles.description}>
        Your account has been created and is awaiting approval from an administrator.
      </Text>

      <View style={styles.infoBox}>
        <View style={styles.infoRow}>
          <Ionicons name="mail" size={20} color={Colors.gold} />
          <Text style={styles.infoText}>You will receive an email once your account is approved</Text>
        </View>
        <View style={styles.infoRow}>
          <Ionicons name="help-circle" size={20} color={Colors.gold} />
          <Text style={styles.infoText}>Questions? Contact alumni@ytchaim.com</Text>
        </View>
      </View>

      <View style={styles.actions}>
        <TouchableOpacity
          style={[styles.primaryButton, isRefreshing && styles.buttonDisabled]}
          onPress={handleRefresh}
          disabled={isRefreshing}
        >
          {isRefreshing ? (
            <ActivityIndicator size="small" color={Colors.cream} />
          ) : (
            <Ionicons name="refresh" size={20} color={Colors.cream} />
          )}
          <Text style={styles.primaryButtonText}>
            {isRefreshing ? 'Checking...' : 'Check Status'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={signOut}>
          <Text style={styles.signOutText}>Sign Out</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  iconContainer: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: Colors.goldOpacity(0.15),
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Colors.navy,
    marginBottom: 12,
  },
  description: {
    fontSize: 16,
    color: Colors.navyOpacity(0.7),
    textAlign: 'center',
    paddingHorizontal: 32,
    marginBottom: 32,
  },
  infoBox: {
    backgroundColor: Colors.navyOpacity(0.05),
    borderRadius: 16,
    padding: 20,
    width: '100%',
    gap: 12,
    marginBottom: 40,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  infoText: {
    flex: 1,
    fontSize: 14,
    color: Colors.navyOpacity(0.8),
  },
  actions: {
    width: '100%',
    gap: 16,
  },
  primaryButton: {
    backgroundColor: Colors.navy,
    borderRadius: 12,
    paddingVertical: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  primaryButtonText: {
    color: Colors.cream,
    fontSize: 17,
    fontWeight: '600',
  },
  signOutText: {
    textAlign: 'center',
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navyOpacity(0.7),
  },
});
