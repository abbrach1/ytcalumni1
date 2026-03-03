import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  StyleSheet,
  Image,
  ActivityIndicator,
  Alert,
  Platform,
  RefreshControl,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../constants/Colors';
import { useAuth } from '../../hooks/useAuth';
import { fetchEvents, Event } from '../../services/firebase';
import { addDoc, collection } from 'firebase/firestore';
import { db } from '../../services/firebaseConfig';

export default function EventsScreen() {
  const { user } = useAuth();
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Form state
  const [fullName, setFullName] = useState('');
  const [simchaType, setSimchaType] = useState('');
  const [connection, setConnection] = useState('');
  const [message, setMessage] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const loadEvents = async () => {
    try {
      const data = await fetchEvents();
      setEvents(data);
    } catch (error) {
      console.error('Error loading events:', error);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    loadEvents();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadEvents();
    setRefreshing(false);
  };

  const upcomingEvents = events.filter((e) => e.date >= new Date().toISOString().split('T')[0]);
  const pastEvents = events.filter((e) => e.date < new Date().toISOString().split('T')[0]);

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr + 'T00:00:00');
    return date.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
  };

  const getDayNumber = (dateStr: string) => {
    const date = new Date(dateStr + 'T00:00:00');
    return date.getDate().toString();
  };

  const getMonthAbbr = (dateStr: string) => {
    const date = new Date(dateStr + 'T00:00:00');
    return date.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
  };

  const submitSimcha = async () => {
    if (!fullName || !simchaType) {
      Alert.alert('Error', 'Please fill in required fields.');
      return;
    }

    setIsSubmitting(true);
    try {
      await addDoc(collection(db, 'simchaSubmissions'), {
        fullName,
        simchaType,
        date: new Date().toISOString().split('T')[0],
        connection: connection || null,
        message: message || null,
        imageUrl: null,
        submittedBy: user?.email ?? 'unknown',
        submittedAt: new Date().toISOString(),
        status: 'new',
      });
      Alert.alert('Submitted!', 'Thank you! Your simcha has been submitted for review.');
      setFullName('');
      setSimchaType('');
      setConnection('');
      setMessage('');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An error occurred');
    }
    setIsSubmitting(false);
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={Colors.navy} />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.gold} />}
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Yeshiva Simchos</Text>
      </View>

      <View style={styles.content}>
        {/* Upcoming Events */}
        {upcomingEvents.length > 0 ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Upcoming</Text>
            {upcomingEvents.map((event) => (
              <View key={event.id} style={styles.eventCard}>
                {/* Gradient header or image */}
                {event.imageUrl ? (
                  <Image source={{ uri: event.imageUrl }} style={styles.eventImage} resizeMode="cover" />
                ) : (
                  <View style={styles.eventGradient} />
                )}

                <View style={styles.eventContent}>
                  <View style={styles.eventTopRow}>
                    {/* Date badge */}
                    <View style={styles.dateBadge}>
                      <Text style={styles.dateBadgeMonth}>{getMonthAbbr(event.date)}</Text>
                      <Text style={styles.dateBadgeDay}>{getDayNumber(event.date)}</Text>
                    </View>

                    <View style={styles.eventDetails}>
                      <View style={styles.eventTypeBadge}>
                        <Text style={styles.eventTypeText}>{event.type}</Text>
                      </View>
                      <Text style={styles.eventName}>{event.eventName}</Text>
                      <Text style={styles.eventPerson}>{event.personFamily}</Text>
                    </View>
                  </View>

                  <View style={styles.divider} />

                  <View style={styles.eventInfoRows}>
                    <View style={styles.eventInfoRow}>
                      <Ionicons name="location" size={14} color={Colors.gold} />
                      <Text style={styles.eventInfoText}>{event.location}</Text>
                    </View>
                    <View style={styles.eventInfoRow}>
                      <Ionicons name="calendar" size={14} color={Colors.gold} />
                      <Text style={styles.eventInfoText}>{formatDate(event.date)}</Text>
                    </View>
                    {event.time && (
                      <View style={styles.eventInfoRow}>
                        <Ionicons name="time" size={14} color={Colors.gold} />
                        <Text style={styles.eventInfoText}>{event.time}</Text>
                      </View>
                    )}
                  </View>

                  {event.description ? (
                    <Text style={styles.eventDescription} numberOfLines={2}>{event.description}</Text>
                  ) : null}
                </View>
              </View>
            ))}
          </View>
        ) : (
          <View style={styles.emptyEvents}>
            <Ionicons name="calendar" size={40} color={Colors.navyOpacity(0.3)} />
            <Text style={styles.emptyTitle}>No upcoming simchos</Text>
          </View>
        )}

        {/* Past Events */}
        {pastEvents.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionSubtitle}>Past</Text>
            <View style={styles.pastGrid}>
              {pastEvents.slice(0, 8).map((event) => (
                <View key={event.id} style={styles.pastCard}>
                  <View style={styles.pastDateBadge}>
                    <Text style={styles.pastMonth}>{getMonthAbbr(event.date)}</Text>
                    <Text style={styles.pastDay}>{getDayNumber(event.date)}</Text>
                  </View>
                  <View style={styles.pastInfo}>
                    <Text style={styles.pastName} numberOfLines={1}>{event.eventName}</Text>
                    <Text style={styles.pastPerson} numberOfLines={1}>{event.personFamily}</Text>
                  </View>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* Submit Simcha Form */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Share Your Simcha</Text>
          <View style={styles.formCard}>
            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>Full Name <Text style={styles.required}>*</Text></Text>
              <TextInput
                style={styles.input}
                value={fullName}
                onChangeText={setFullName}
                placeholder="Enter full name"
                placeholderTextColor={Colors.navyOpacity(0.4)}
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>Type of Simcha <Text style={styles.required}>*</Text></Text>
              <TextInput
                style={styles.input}
                value={simchaType}
                onChangeText={setSimchaType}
                placeholder="Wedding, Bar Mitzvah, etc."
                placeholderTextColor={Colors.navyOpacity(0.4)}
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabelOptional}>Connection to Yeshiva (Optional)</Text>
              <TextInput
                style={styles.input}
                value={connection}
                onChangeText={setConnection}
                placeholder="Alumnus, Parent, etc."
                placeholderTextColor={Colors.navyOpacity(0.4)}
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabelOptional}>Additional Details (Optional)</Text>
              <TextInput
                style={[styles.input, styles.textArea]}
                value={message}
                onChangeText={setMessage}
                placeholder="Any additional details..."
                placeholderTextColor={Colors.navyOpacity(0.4)}
                multiline
                numberOfLines={4}
                textAlignVertical="top"
              />
            </View>

            <TouchableOpacity
              style={[styles.submitButton, (isSubmitting || !fullName || !simchaType) && styles.submitDisabled]}
              onPress={submitSimcha}
              disabled={isSubmitting || !fullName || !simchaType}
            >
              {isSubmitting && <ActivityIndicator size="small" color={Colors.cream} style={{ marginRight: 8 }} />}
              <Ionicons name="send" size={16} color={Colors.cream} />
              <Text style={styles.submitText}>{isSubmitting ? 'Submitting...' : 'Submit Simcha'}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>

      <View style={{ height: 20 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.cream,
  },
  header: {
    backgroundColor: Colors.navy,
    paddingTop: 60,
    paddingBottom: 32,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Colors.cream,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  content: {
    padding: 16,
    gap: 32,
  },
  section: {
    gap: 16,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: Colors.navy,
  },
  sectionSubtitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.navyOpacity(0.7),
  },
  // Event card
  eventCard: {
    backgroundColor: Colors.white,
    borderRadius: 16,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
    elevation: 3,
  },
  eventImage: {
    width: '100%',
    height: 160,
  },
  eventGradient: {
    height: 12,
    backgroundColor: Colors.gold,
  },
  eventContent: {
    padding: 16,
    gap: 12,
  },
  eventTopRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 16,
  },
  dateBadge: {
    width: 56,
    alignItems: 'center',
    paddingVertical: 8,
    backgroundColor: Colors.navy,
    borderRadius: 8,
  },
  dateBadgeMonth: {
    fontSize: 10,
    fontWeight: '500',
    color: Colors.creamOpacity(0.8),
  },
  dateBadgeDay: {
    fontSize: 22,
    fontWeight: 'bold',
    color: Colors.cream,
  },
  eventDetails: {
    flex: 1,
    gap: 4,
  },
  eventTypeBadge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 2,
    backgroundColor: Colors.goldOpacity(0.15),
    borderRadius: 4,
  },
  eventTypeText: {
    fontSize: 12,
    fontWeight: '500',
    color: Colors.gold,
  },
  eventName: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  eventPerson: {
    fontSize: 15,
    color: Colors.navyOpacity(0.7),
  },
  divider: {
    height: 1,
    backgroundColor: Colors.navyOpacity(0.1),
  },
  eventInfoRows: {
    gap: 8,
  },
  eventInfoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  eventInfoText: {
    fontSize: 14,
    color: Colors.navyOpacity(0.7),
  },
  eventDescription: {
    fontSize: 14,
    color: Colors.navyOpacity(0.6),
  },
  emptyEvents: {
    alignItems: 'center',
    paddingVertical: 40,
    gap: 12,
  },
  emptyTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navyOpacity(0.6),
  },
  // Past events
  pastGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  pastCard: {
    width: '47%',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: Colors.white,
    borderRadius: 10,
    padding: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  pastDateBadge: {
    width: 44,
    alignItems: 'center',
    paddingVertical: 6,
    backgroundColor: Colors.navyOpacity(0.1),
    borderRadius: 6,
  },
  pastMonth: {
    fontSize: 8,
    fontWeight: '500',
    color: Colors.navyOpacity(0.6),
  },
  pastDay: {
    fontSize: 15,
    fontWeight: 'bold',
    color: Colors.navy,
  },
  pastInfo: {
    flex: 1,
  },
  pastName: {
    fontSize: 12,
    fontWeight: '500',
    color: Colors.navy,
  },
  pastPerson: {
    fontSize: 10,
    color: Colors.navyOpacity(0.5),
  },
  // Form
  formCard: {
    backgroundColor: Colors.white,
    borderRadius: 16,
    padding: 20,
    gap: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  formField: {
    gap: 6,
  },
  fieldLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navy,
  },
  fieldLabelOptional: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navyOpacity(0.7),
  },
  required: {
    color: 'red',
  },
  input: {
    backgroundColor: Colors.white,
    borderRadius: 10,
    padding: 14,
    fontSize: 15,
    color: Colors.navy,
    borderWidth: 1,
    borderColor: Colors.goldOpacity(0.3),
  },
  textArea: {
    minHeight: 100,
  },
  submitButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: Colors.navy,
    borderRadius: 12,
    paddingVertical: 16,
  },
  submitDisabled: {
    opacity: 0.5,
  },
  submitText: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.cream,
  },
});
