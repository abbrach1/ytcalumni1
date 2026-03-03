import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Linking,
  Modal,
  Platform,
  RefreshControl,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../constants/Colors';
import { useAuth } from '../../hooks/useAuth';
import {
  fetchApprovedAlumni,
  submitContactInfo,
  updateContactInfo,
  AlumniContact,
} from '../../services/firebase';

type ContactTab = 'rebbeim' | 'alumni';

export default function ContactsScreen() {
  const { user } = useAuth();
  const [selectedTab, setSelectedTab] = useState<ContactTab>('alumni');
  const [alumni, setAlumni] = useState<AlumniContact[]>([]);
  const [searchText, setSearchText] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showEditModal, setShowEditModal] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const scrollRef = useRef<ScrollView>(null);

  // Contact form state
  const [formName, setFormName] = useState('');
  const [formEmail, setFormEmail] = useState('');
  const [formPhone, setFormPhone] = useState('');
  const [formLocation, setFormLocation] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const loadData = async () => {
    try {
      const data = await fetchApprovedAlumni();
      setAlumni(data);
    } catch (error) {
      console.error('Error loading contacts:', error);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const currentUserRecord = useMemo(() => {
    if (!user?.email) return null;
    const email = user.email.toLowerCase();
    return alumni.find((a) => a.email?.toLowerCase() === email) ?? null;
  }, [alumni, user]);

  const filteredAlumni = useMemo(() => {
    if (!searchText) return alumni;
    const q = searchText.toLowerCase();
    return alumni.filter(
      (a) =>
        a.name.toLowerCase().includes(q) ||
        (a.email?.toLowerCase().includes(q) ?? false) ||
        a.location.toLowerCase().includes(q)
    );
  }, [alumni, searchText]);

  const getInitials = (name: string) => {
    const parts = name.split(' ');
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, 2).toUpperCase();
  };

  const handleSubmitContact = async () => {
    if (!formName || !formLocation) {
      Alert.alert('Error', 'Please fill in name and location.');
      return;
    }
    setIsSubmitting(true);
    try {
      await submitContactInfo(
        formName,
        formEmail || null,
        formPhone || null,
        formLocation,
        user?.email ?? 'unknown'
      );
      Alert.alert('Submitted!', 'Your contact info has been submitted and will appear soon.');
      setFormName('');
      setFormEmail('');
      setFormPhone('');
      setFormLocation('');
      await loadData();
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An error occurred');
    }
    setIsSubmitting(false);
  };

  return (
    <ScrollView
      ref={scrollRef}
      style={styles.container}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.gold} />}
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Directory</Text>
        <Text style={styles.headerSubtitle}>Connect with Rebbeim and fellow alumni</Text>
      </View>

      <View style={styles.content}>
        {/* Tab Selector */}
        <View style={styles.tabSelector}>
          {(['rebbeim', 'alumni'] as ContactTab[]).map((tab) => (
            <TouchableOpacity
              key={tab}
              style={[styles.tab, selectedTab === tab && styles.tabActive]}
              onPress={() => setSelectedTab(tab)}
            >
              <Text style={[styles.tabText, selectedTab === tab && styles.tabTextActive]}>
                {tab === 'rebbeim' ? 'Rebbeim' : 'Alumni'}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Rebbeim Tab */}
        {selectedTab === 'rebbeim' && (
          <View style={styles.comingSoonCard}>
            <Ionicons name="book" size={48} color={Colors.navyOpacity(0.3)} />
            <Text style={styles.comingSoonTitle}>Rebbeim Directory Coming Soon</Text>
            <Text style={styles.comingSoonMessage}>
              We are working on building the Rebbeim directory. Check back soon for contact
              information for all the Rebbeim.
            </Text>
          </View>
        )}

        {/* Alumni Tab */}
        {selectedTab === 'alumni' && (
          <>
            {/* Search bar */}
            <View style={styles.searchBar}>
              <Ionicons name="search" size={18} color={Colors.navyOpacity(0.4)} />
              <TextInput
                style={styles.searchInput}
                value={searchText}
                onChangeText={setSearchText}
                placeholder="Search by name, email, or location"
                placeholderTextColor={Colors.navyOpacity(0.4)}
                autoCapitalize="none"
                autoCorrect={false}
              />
              {searchText !== '' && (
                <TouchableOpacity onPress={() => setSearchText('')}>
                  <Ionicons name="close-circle" size={18} color={Colors.navyOpacity(0.4)} />
                </TouchableOpacity>
              )}
            </View>

            {/* Edit/Add button */}
            {currentUserRecord ? (
              <TouchableOpacity
                style={styles.editButton}
                onPress={() => setShowEditModal(true)}
              >
                <Ionicons name="pencil" size={16} color={Colors.gold} />
                <Text style={styles.editButtonText}>Edit Your Info</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity style={styles.editButton}>
                <Ionicons name="add-circle" size={16} color={Colors.gold} />
                <Text style={styles.editButtonText}>Add Your Info</Text>
              </TouchableOpacity>
            )}

            {/* Alumni list */}
            {isLoading ? (
              <ActivityIndicator size="large" color={Colors.navy} style={{ marginTop: 32 }} />
            ) : filteredAlumni.length === 0 ? (
              <View style={styles.emptyState}>
                <Ionicons
                  name={searchText ? 'search' : 'people'}
                  size={36}
                  color={Colors.navyOpacity(0.3)}
                />
                <Text style={styles.emptyTitle}>
                  {searchText ? 'No results found' : 'No alumni listed yet'}
                </Text>
                <Text style={styles.emptyMessage}>
                  {searchText
                    ? 'Try a different search term.'
                    : 'Be the first! Add your contact info below.'}
                </Text>
              </View>
            ) : (
              filteredAlumni.map((alumnus) => (
                <TouchableOpacity
                  key={alumnus.id}
                  style={styles.alumniCard}
                  onPress={() =>
                    setExpandedId(expandedId === alumnus.id ? null : alumnus.id)
                  }
                  activeOpacity={0.7}
                >
                  {/* Header row */}
                  <View style={styles.alumniHeader}>
                    <View style={styles.initialsCircle}>
                      <Text style={styles.initialsText}>{getInitials(alumnus.name)}</Text>
                    </View>
                    <View style={styles.alumniInfo}>
                      <Text style={styles.alumniName}>{alumnus.name}</Text>
                      <Text style={styles.alumniLocation}>{alumnus.location}</Text>
                    </View>
                    <Ionicons
                      name="chevron-down"
                      size={16}
                      color={Colors.navyOpacity(0.4)}
                      style={{
                        transform: [{ rotate: expandedId === alumnus.id ? '180deg' : '0deg' }],
                      }}
                    />
                  </View>

                  {/* Expanded details */}
                  {expandedId === alumnus.id && (
                    <View style={styles.alumniDetails}>
                      <View style={styles.detailDivider} />
                      {alumnus.email ? (
                        <TouchableOpacity
                          style={styles.detailRow}
                          onPress={() => Linking.openURL(`mailto:${alumnus.email}`)}
                        >
                          <Ionicons name="mail" size={16} color={Colors.gold} />
                          <Text style={styles.detailText}>{alumnus.email}</Text>
                        </TouchableOpacity>
                      ) : null}
                      {alumnus.phone ? (
                        <TouchableOpacity
                          style={styles.detailRow}
                          onPress={() =>
                            Linking.openURL(`tel:${alumnus.phone!.replace(/[^\d]/g, '')}`)
                          }
                        >
                          <Ionicons name="call" size={16} color={Colors.gold} />
                          <Text style={styles.detailText}>{alumnus.phone}</Text>
                        </TouchableOpacity>
                      ) : null}
                      <View style={styles.detailRow}>
                        <Ionicons name="location" size={16} color={Colors.gold} />
                        <Text style={styles.detailText}>{alumnus.location}</Text>
                      </View>
                    </View>
                  )}
                </TouchableOpacity>
              ))
            )}
          </>
        )}

        {/* Contact Form */}
        <View style={styles.formSection}>
          <View style={styles.formHeader}>
            <Text style={styles.formHeaderTitle}>Add Your Contact Info</Text>
            <Text style={styles.formHeaderSubtitle}>
              Submit your details to be listed in the alumni directory.
            </Text>
          </View>
          <View style={styles.formBody}>
            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>Full Name <Text style={styles.required}>*</Text></Text>
              <TextInput
                style={styles.input}
                value={formName}
                onChangeText={setFormName}
                placeholder="Enter your full name"
                placeholderTextColor={Colors.navyOpacity(0.4)}
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabelOptional}>Email (Optional)</Text>
              <TextInput
                style={styles.input}
                value={formEmail}
                onChangeText={setFormEmail}
                placeholder="your.email@example.com"
                placeholderTextColor={Colors.navyOpacity(0.4)}
                keyboardType="email-address"
                autoCapitalize="none"
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabelOptional}>Phone Number (Optional)</Text>
              <TextInput
                style={styles.input}
                value={formPhone}
                onChangeText={setFormPhone}
                placeholder="(555) 123-4567"
                placeholderTextColor={Colors.navyOpacity(0.4)}
                keyboardType="phone-pad"
              />
            </View>

            <View style={styles.formField}>
              <Text style={styles.fieldLabel}>Current Location <Text style={styles.required}>*</Text></Text>
              <TextInput
                style={styles.input}
                value={formLocation}
                onChangeText={setFormLocation}
                placeholder="Eretz Yisroel, Chutz Laaretz, etc."
                placeholderTextColor={Colors.navyOpacity(0.4)}
              />
            </View>

            <TouchableOpacity
              style={[
                styles.submitButton,
                (isSubmitting || !formName || !formLocation) && styles.submitDisabled,
              ]}
              onPress={handleSubmitContact}
              disabled={isSubmitting || !formName || !formLocation}
            >
              {isSubmitting && (
                <ActivityIndicator size="small" color={Colors.cream} style={{ marginRight: 8 }} />
              )}
              <Ionicons name="send" size={16} color={Colors.cream} />
              <Text style={styles.submitText}>
                {isSubmitting ? 'Submitting...' : 'Submit My Info'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>

      <View style={{ height: 20 }} />

      {/* Edit Modal */}
      {currentUserRecord && (
        <EditModal
          visible={showEditModal}
          alumnus={currentUserRecord}
          onClose={() => setShowEditModal(false)}
          onSave={async () => {
            setShowEditModal(false);
            await loadData();
          }}
        />
      )}
    </ScrollView>
  );
}

// --- Edit Modal ---
function EditModal({
  visible,
  alumnus,
  onClose,
  onSave,
}: {
  visible: boolean;
  alumnus: AlumniContact;
  onClose: () => void;
  onSave: () => void;
}) {
  const [name, setName] = useState(alumnus.name);
  const [phone, setPhone] = useState(alumnus.phone ?? '');
  const [location, setLocation] = useState(alumnus.location);
  const [isSaving, setIsSaving] = useState(false);

  const handleSave = async () => {
    if (!name || !location) {
      Alert.alert('Error', 'Name and location are required.');
      return;
    }
    setIsSaving(true);
    try {
      await updateContactInfo(alumnus.id, name, phone || null, location);
      Alert.alert('Updated!', 'Your contact information has been updated.');
      onSave();
    } catch (error: any) {
      Alert.alert('Error', error.message || 'An error occurred');
    }
    setIsSaving(false);
  };

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet">
      <View style={editStyles.container}>
        <View style={editStyles.header}>
          <TouchableOpacity onPress={onClose}>
            <Text style={editStyles.cancelText}>Cancel</Text>
          </TouchableOpacity>
          <Text style={editStyles.title}>Edit Your Info</Text>
          <View style={{ width: 60 }} />
        </View>

        <ScrollView style={editStyles.form}>
          <View style={editStyles.field}>
            <Text style={editStyles.label}>Full Name</Text>
            <TextInput style={editStyles.input} value={name} onChangeText={setName} />
          </View>

          <View style={editStyles.field}>
            <Text style={editStyles.labelDisabled}>Email (cannot be changed)</Text>
            <View style={editStyles.disabledInput}>
              <Text style={editStyles.disabledText}>{alumnus.email ?? ''}</Text>
            </View>
          </View>

          <View style={editStyles.field}>
            <Text style={editStyles.label}>Phone Number</Text>
            <TextInput
              style={editStyles.input}
              value={phone}
              onChangeText={setPhone}
              keyboardType="phone-pad"
            />
          </View>

          <View style={editStyles.field}>
            <Text style={editStyles.label}>Location</Text>
            <TextInput style={editStyles.input} value={location} onChangeText={setLocation} />
          </View>

          <TouchableOpacity
            style={[editStyles.saveButton, (isSaving || !name || !location) && editStyles.saveDisabled]}
            onPress={handleSave}
            disabled={isSaving || !name || !location}
          >
            {isSaving && <ActivityIndicator size="small" color={Colors.cream} style={{ marginRight: 8 }} />}
            <Text style={editStyles.saveText}>{isSaving ? 'Saving...' : 'Save Changes'}</Text>
          </TouchableOpacity>
        </ScrollView>
      </View>
    </Modal>
  );
}

const editStyles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.navyOpacity(0.1),
  },
  cancelText: {
    fontSize: 16,
    color: Colors.navy,
  },
  title: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  form: {
    padding: 20,
  },
  field: {
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navy,
    marginBottom: 6,
  },
  labelDisabled: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navyOpacity(0.5),
    marginBottom: 6,
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
  disabledInput: {
    backgroundColor: Colors.creamDark,
    borderRadius: 10,
    padding: 14,
    borderWidth: 1,
    borderColor: Colors.goldOpacity(0.15),
  },
  disabledText: {
    fontSize: 16,
    color: Colors.navyOpacity(0.6),
  },
  saveButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.navy,
    borderRadius: 12,
    paddingVertical: 16,
    marginTop: 8,
  },
  saveDisabled: {
    opacity: 0.5,
  },
  saveText: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.cream,
  },
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
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
  headerSubtitle: {
    fontSize: 14,
    color: Colors.creamOpacity(0.7),
    marginTop: 4,
  },
  content: {
    padding: 16,
    gap: 16,
  },
  // Tab selector
  tabSelector: {
    flexDirection: 'row',
    backgroundColor: Colors.white,
    borderRadius: 12,
    padding: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
    elevation: 2,
  },
  tab: {
    flex: 1,
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: 8,
  },
  tabActive: {
    backgroundColor: Colors.navy,
  },
  tabText: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.navyOpacity(0.6),
  },
  tabTextActive: {
    color: Colors.cream,
  },
  // Coming soon
  comingSoonCard: {
    alignItems: 'center',
    padding: 32,
    backgroundColor: Colors.white,
    borderRadius: 16,
    gap: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  comingSoonTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  comingSoonMessage: {
    fontSize: 14,
    color: Colors.navyOpacity(0.6),
    textAlign: 'center',
  },
  // Search
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.white,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
    borderWidth: 1,
    borderColor: Colors.goldOpacity(0.3),
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    color: Colors.navy,
  },
  editButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 6,
  },
  editButtonText: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.gold,
  },
  // Alumni card
  alumniCard: {
    backgroundColor: Colors.white,
    borderRadius: 12,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  alumniHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    gap: 14,
  },
  initialsCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.navyOpacity(0.1),
    alignItems: 'center',
    justifyContent: 'center',
  },
  initialsText: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  alumniInfo: {
    flex: 1,
  },
  alumniName: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  alumniLocation: {
    fontSize: 12,
    color: Colors.navyOpacity(0.6),
  },
  alumniDetails: {
    paddingHorizontal: 16,
    paddingBottom: 16,
    gap: 12,
  },
  detailDivider: {
    height: 1,
    backgroundColor: Colors.navyOpacity(0.1),
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  detailText: {
    fontSize: 15,
    color: Colors.navy,
  },
  // Empty state
  emptyState: {
    alignItems: 'center',
    padding: 32,
    backgroundColor: Colors.white,
    borderRadius: 16,
    gap: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  emptyTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  emptyMessage: {
    fontSize: 14,
    color: Colors.navyOpacity(0.6),
    textAlign: 'center',
  },
  // Contact form
  formSection: {
    backgroundColor: Colors.white,
    borderRadius: 16,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  formHeader: {
    padding: 20,
    backgroundColor: Colors.navy,
  },
  formHeaderTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.cream,
  },
  formHeaderSubtitle: {
    fontSize: 12,
    color: Colors.creamOpacity(0.7),
    marginTop: 4,
  },
  formBody: {
    padding: 20,
    gap: 20,
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
