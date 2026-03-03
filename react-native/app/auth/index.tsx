import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Colors } from '../../constants/Colors';
import { useAuth } from '../../hooks/useAuth';

export default function LoginScreen() {
  const { signIn, signUp } = useAuth();

  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleAuth = async () => {
    if (isSignUp) {
      if (!firstName.trim() || !lastName.trim()) {
        Alert.alert('Error', 'Please enter your first and last name.');
        return;
      }
      if (password !== confirmPassword) {
        Alert.alert('Error', "Passwords don't match.");
        return;
      }
    }
    if (!email || !password) {
      Alert.alert('Error', 'Please fill in all required fields.');
      return;
    }

    setIsLoading(true);
    try {
      if (isSignUp) {
        await signUp(email, password, firstName.trim(), lastName.trim());
      } else {
        await signIn(email, password);
      }
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        {/* Logo and Title */}
        <View style={styles.header}>
          <Text style={styles.title}>Yeshiva Toras Chaim Alumni</Text>
          <Text style={styles.subtitle}>
            {isSignUp ? 'Create your account' : 'Sign in to access the alumni portal'}
          </Text>
        </View>

        {/* Sign Up Info */}
        {isSignUp && (
          <View style={styles.infoBox}>
            <Text style={styles.infoTitle}>How approval works:</Text>
            <Text style={styles.infoBullet}>
              {'\u2022'} If your email is in our alumni database, you will be approved automatically
            </Text>
            <Text style={styles.infoBullet}>
              {'\u2022'} Otherwise, your request will be reviewed by an administrator
            </Text>
            <Text style={styles.infoBullet}>
              {'\u2022'} You will receive access once approved
            </Text>
          </View>
        )}

        {/* Form */}
        <View style={styles.form}>
          {isSignUp && (
            <View style={styles.nameRow}>
              <View style={styles.nameField}>
                <Text style={styles.label}>First Name <Text style={styles.required}>*</Text></Text>
                <TextInput
                  style={styles.input}
                  value={firstName}
                  onChangeText={setFirstName}
                  placeholder="Moshe"
                  placeholderTextColor={Colors.navyOpacity(0.4)}
                  autoCapitalize="words"
                />
              </View>
              <View style={styles.nameField}>
                <Text style={styles.label}>Last Name <Text style={styles.required}>*</Text></Text>
                <TextInput
                  style={styles.input}
                  value={lastName}
                  onChangeText={setLastName}
                  placeholder="Cohen"
                  placeholderTextColor={Colors.navyOpacity(0.4)}
                  autoCapitalize="words"
                />
              </View>
            </View>
          )}

          <View>
            <Text style={styles.label}>Email <Text style={styles.required}>*</Text></Text>
            <TextInput
              style={styles.input}
              value={email}
              onChangeText={setEmail}
              placeholder="email@example.com"
              placeholderTextColor={Colors.navyOpacity(0.4)}
              autoCapitalize="none"
              keyboardType="email-address"
              autoCorrect={false}
            />
          </View>

          <View>
            <Text style={styles.label}>Password <Text style={styles.required}>*</Text></Text>
            <TextInput
              style={styles.input}
              value={password}
              onChangeText={setPassword}
              placeholder="Password"
              placeholderTextColor={Colors.navyOpacity(0.4)}
              secureTextEntry
            />
          </View>

          {isSignUp && (
            <View>
              <Text style={styles.label}>Confirm Password <Text style={styles.required}>*</Text></Text>
              <TextInput
                style={styles.input}
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                placeholder="Confirm Password"
                placeholderTextColor={Colors.navyOpacity(0.4)}
                secureTextEntry
              />
            </View>
          )}
        </View>

        {/* Submit Button */}
        <TouchableOpacity
          style={[styles.primaryButton, isLoading && styles.buttonDisabled]}
          onPress={handleAuth}
          disabled={isLoading}
        >
          {isLoading && <ActivityIndicator size="small" color={Colors.cream} style={{ marginRight: 8 }} />}
          <Text style={styles.primaryButtonText}>
            {isLoading
              ? (isSignUp ? 'Creating Account...' : 'Signing In...')
              : (isSignUp ? 'Sign Up' : 'Sign In')}
          </Text>
        </TouchableOpacity>

        {/* Toggle */}
        <TouchableOpacity onPress={() => setIsSignUp(!isSignUp)} disabled={isLoading}>
          <Text style={styles.toggleText}>
            {isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"}
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
  },
  scrollContent: {
    paddingHorizontal: 24,
    paddingBottom: 40,
  },
  header: {
    alignItems: 'center',
    paddingTop: 60,
    marginBottom: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Colors.navy,
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  subtitle: {
    fontSize: 15,
    color: Colors.navyOpacity(0.7),
    marginTop: 8,
  },
  infoBox: {
    backgroundColor: Colors.navyOpacity(0.05),
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: Colors.navyOpacity(0.1),
  },
  infoTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.navy,
    marginBottom: 8,
  },
  infoBullet: {
    fontSize: 12,
    color: Colors.navyOpacity(0.8),
    marginBottom: 4,
    paddingLeft: 8,
  },
  form: {
    gap: 16,
    marginBottom: 24,
  },
  nameRow: {
    flexDirection: 'row',
    gap: 12,
  },
  nameField: {
    flex: 1,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navy,
    marginBottom: 6,
  },
  required: {
    color: 'red',
  },
  input: {
    backgroundColor: Colors.white,
    borderRadius: 10,
    padding: 14,
    fontSize: 16,
    color: Colors.navy,
    borderWidth: 1,
    borderColor: Colors.goldOpacity(0.3),
  },
  primaryButton: {
    backgroundColor: Colors.navy,
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 16,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  primaryButtonText: {
    color: Colors.cream,
    fontSize: 17,
    fontWeight: '600',
  },
  toggleText: {
    textAlign: 'center',
    fontSize: 14,
    color: Colors.navy,
  },
});
